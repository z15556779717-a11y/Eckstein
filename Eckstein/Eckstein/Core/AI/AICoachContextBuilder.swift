//
//  AICoachContextBuilder.swift
//  Eckstein
//
//  Assembles `AICoachContext` from the app's own services.
//

import Foundation
import CoreData

/// Reads the app's stores and reduces them to what the coach is told.
///
/// Every number here comes from the same service the screens use —
/// `NutritionService` for the diet, `WorkoutMetrics` for the training,
/// `WeightMetrics` for the body weight — so the coach cannot be told something
/// the user is not also being shown. Nothing in this file writes: there is one
/// `fetch`-only path through it, which is what makes "the AI never changes the
/// user's data" a property of the code rather than a promise in a prompt.
@MainActor
final class AICoachContextBuilder {

    private let workoutRepository: WorkoutRepository
    private let weightRepository: WeightRepository
    private let nutritionService: NutritionService
    private let calendar: Calendar
    private let now: () -> Date

    /// - Parameters:
    ///   - now: injected so "this week" and "days ago" are testable without
    ///     waiting for the clock.
    init(
        workoutRepository: WorkoutRepository = ServiceContainer.shared.workoutRepository,
        weightRepository: WeightRepository = ServiceContainer.shared.weightRepository,
        nutritionService: NutritionService = .shared,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.workoutRepository = workoutRepository
        self.weightRepository = weightRepository
        self.nutritionService = nutritionService
        self.calendar = calendar
        self.now = now
    }

    /// How much history the coach is given. Small on purpose — the advice does
    /// not change between the fourth and the tenth recent workout, and every
    /// extra one is tokens.
    private static let nutritionWindowDays = 7
    private static let trainingWindowDays = 7
    private static let exerciseWindowDays = 30
    private static let recentSessionLimit = 5
    private static let exerciseProgressLimit = 5

    func buildContext() async -> AICoachContext {
        AICoachContext(
            // The label the user sees in Profile, so the coach is told the goal
            // in the same words the user picked it in.
            fitnessGoal: FitnessGoal.stored.map { $0.titleKey.localized }
                ?? AICoachContext.defaultFitnessGoal,
            nutrition: buildNutritionWindow(),
            workout: buildWorkoutWindow(),
            weight: buildWeightWindow()
        )
    }

    // MARK: - Nutrition

    private func buildNutritionWindow() -> AICoachContext.NutritionWindow {
        let summaries = (try? nutritionService.summaries(
            inRangeEndingOn: now(),
            days: Self.nutritionWindowDays,
            calendar: calendar
        )) ?? []

        let logged = summaries.filter { !$0.isEmpty }
        let goals = (try? nutritionService.goals()) ?? .unset

        guard !logged.isEmpty else {
            return AICoachContext.NutritionWindow(
                daysCovered: summaries.count,
                daysLogged: 0,
                averageCalories: 0,
                averageProteinGrams: 0,
                averageCarbsGrams: 0,
                averageFatGrams: 0,
                averageFiberGrams: 0,
                goals: goals
            )
        }

        // Averaged over the days that were logged, never over all seven — an
        // empty day is a day the app knows nothing about, not a day of fasting.
        let count = Double(logged.count)
        func average(_ value: (DailyNutritionSummary) -> Double) -> Int {
            Int((logged.reduce(0.0) { $0 + value($1) } / count).rounded())
        }

        return AICoachContext.NutritionWindow(
            daysCovered: summaries.count,
            daysLogged: logged.count,
            averageCalories: average(\.dailyCalories),
            averageProteinGrams: average(\.dailyProtein),
            averageCarbsGrams: average(\.dailyCarbohydrates),
            averageFatGrams: average(\.dailyFat),
            averageFiberGrams: average(\.dailyFiber),
            goals: goals
        )
    }

    // MARK: - Training

    private func buildWorkoutWindow() -> AICoachContext.WorkoutWindow {
        let today = calendar.startOfDay(for: now())
        let trainingCutoff = calendar.date(byAdding: .day, value: -(Self.trainingWindowDays - 1), to: today)
        let exerciseCutoff = calendar.date(byAdding: .day, value: -(Self.exerciseWindowDays - 1), to: today)

        let workouts = fetchWorkouts(limit: 20)

        let thisWeek = workouts.filter { workout in
            guard let date = workout.date, let cutoff = trainingCutoff else { return false }
            return date >= cutoff
        }

        let sessions = thisWeek.prefix(Self.recentSessionLimit).map { workout in
            AICoachContext.TrainingSession(
                name: workout.name ?? "Workout",
                daysAgo: daysAgo(since: workout.date),
                durationMinutes: Int(workout.durationMinutes),
                completedSets: WorkoutMetrics.completedSetCount(workout.setsArray),
                volumeKg: WorkoutMetrics.workoutVolume(workout)
            )
        }

        return AICoachContext.WorkoutWindow(
            sessionsThisWeek: thisWeek.count,
            volumeThisWeekKg: thisWeek.reduce(0) { $0 + WorkoutMetrics.workoutVolume($1) },
            recentSessions: Array(sessions),
            exerciseProgress: exerciseProgress(since: exerciseCutoff)
        )
    }

    /// The best estimated max for each movement trained recently.
    ///
    /// Grouped by name rather than by `CDExercise` identity: the coach is told
    /// "Squat", and two rows that a user typed as "Squat" and "squat" are the
    /// same movement to the person reading the advice.
    private func exerciseProgress(since cutoff: Date?) -> [AICoachContext.ExerciseProgress] {
        guard let cutoff else { return [] }

        let request: NSFetchRequest<CDWorkoutSet> = CDWorkoutSet.fetchRequest()
        request.predicate = NSPredicate(format: "exercise != nil AND workout.date >= %@", cutoff as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDWorkoutSet.workout?.date, ascending: false)]

        guard let sets = try? workoutRepository.context.fetch(request) else { return [] }

        struct Entry {
            var name: String
            var bestWeight: Double
            var bestOneRM: Double
            var mostRecent: Date
        }

        var byName: [String: Entry] = [:]
        for set in sets {
            guard let name = set.exercise?.name, !name.isEmpty,
                  let date = set.workout?.date else { continue }

            let key = name.lowercased()
            let oneRM = WorkoutMetrics.estimatedOneRepMax(set) ?? 0
            let weight = max(set.weightKg, 0)

            if var entry = byName[key] {
                entry.bestWeight = max(entry.bestWeight, weight)
                entry.bestOneRM = max(entry.bestOneRM, oneRM)
                entry.mostRecent = max(entry.mostRecent, date)
                byName[key] = entry
            } else {
                byName[key] = Entry(name: name, bestWeight: weight, bestOneRM: oneRM, mostRecent: date)
            }
        }

        return byName.values
            .sorted { $0.bestOneRM > $1.bestOneRM }
            .prefix(Self.exerciseProgressLimit)
            .map { entry in
                AICoachContext.ExerciseProgress(
                    name: entry.name,
                    bestWeightKg: entry.bestWeight,
                    bestEstimatedOneRepMaxKg: entry.bestOneRM,
                    daysAgo: daysAgo(since: entry.mostRecent)
                )
            }
    }

    // MARK: - Body weight

    private func buildWeightWindow() -> AICoachContext.WeightWindow {
        weightRepository.refresh()

        let entries = weightRepository.weightEntries.compactMap { entry -> (date: Date, weightKg: Double, id: UUID)? in
            guard let date = entry.date, let id = entry.id else { return nil }
            return (date: date, weightKg: entry.weightKg, id: id)
        }

        let series = WeightMetrics.dailySeries(
            from: entries,
            endingOn: now(),
            range: .month,
            calendar: calendar
        )

        return AICoachContext.WeightWindow(
            currentKg: WeightMetrics.currentWeight(from: entries),
            targetKg: weightRepository.goalWeight,
            changeOverMonthKg: WeightMetrics.changeOverRange(series),
            trend: weightRepository.getWeightTrend()
        )
    }

    // MARK: - Shared

    private func fetchWorkouts(limit: Int) -> [CDWorkout] {
        let request: NSFetchRequest<CDWorkout> = CDWorkout.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDWorkout.date, ascending: false)]
        request.fetchLimit = limit
        return (try? workoutRepository.context.fetch(request)) ?? []
    }

    private func daysAgo(since date: Date?) -> Int {
        guard let date else { return 0 }
        let from = calendar.startOfDay(for: date)
        let to = calendar.startOfDay(for: now())
        return max(0, calendar.dateComponents([.day], from: from, to: to).day ?? 0)
    }
}

/// The name this type had before phase 5 gave the context a shape worth naming.
///
/// Kept as an alias, not a second class: the phase-4 tests instantiate the old
/// name, and a duplicate would be a second implementation to keep in step.
typealias AIContextBuilder = AICoachContextBuilder

// MARK: - One-meal context

extension AICoachContextBuilder {

    /// What the user usually eats at one meal slot.
    ///
    /// Narrower than the seven-day window, and deliberately so: asked for
    /// breakfast suggestions, the coach is more useful knowing the user's own
    /// breakfasts than their weekly average. Read through `NutritionService`,
    /// the same path the Diet screen reads — see NUTRITION_MIGRATION_PLAN.md §13
    /// for why this must not go to `CDMeal`.
    func buildDietContext(for mealType: String?) -> String {
        let slot = mealType.map { MealType(storedValue: $0) }
        let meals = ((try? nutritionService.recentMeals(limit: 21)) ?? []).filter { meal in
            guard let slot else { return true }
            return meal.mealType == slot
        }

        guard !meals.isEmpty else {
            return "No recent \(mealType ?? "meal") data available"
        }

        let totals = meals.reduce(NutritionSnapshot.zero) { $0 + $1.nutrition }
        let count = Double(meals.count)
        let avgCalories = Int((totals.calories / count).rounded())
        let avgProtein = Int((totals.protein / count).rounded())
        return "Recent \(mealType ?? "meal") averages: \(avgCalories) calories, \(avgProtein)g protein"
    }
}
