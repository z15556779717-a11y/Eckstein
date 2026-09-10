//
//  AIContextBuilder.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation
import CoreData

@MainActor
class AIContextBuilder {
    private let workoutRepository: WorkoutRepository
    private let weightRepository: WeightRepository
    private let nutritionService: NutritionService
    private let context: NSManagedObjectContext

    init() {
        self.workoutRepository = ServiceContainer.shared.workoutRepository
        self.weightRepository = ServiceContainer.shared.weightRepository
        self.nutritionService = NutritionService()
        self.context = PersistenceController.shared.container.viewContext
    }
    
    func buildContext() async -> AIContext {
        // Fetch user preferences
        let userPreferences = await fetchUserPreferences()
        
        // Fetch recent data
        let recentWorkouts = await fetchRecentWorkouts()
        let recentMeals = await fetchRecentMeals()
        let weightData = await fetchWeightData()
        
        // Build summaries
        let activitySummary = buildActivitySummary(from: recentWorkouts)
        let currentStats = buildCurrentStats(
            weight: weightData.current,
            goalWeight: weightData.goal,
            weeklyWorkouts: recentWorkouts.count,
            averageCalories: calculateAverageCalories(from: recentMeals)
        )
        
        return AIContext(
            userGoals: userPreferences.goals,
            recentActivitySummary: activitySummary,
            currentStats: currentStats,
            recentWorkouts: recentWorkouts,
            recentMeals: recentMeals,
            weightTrend: weightData.trend,
            currentWeight: weightData.current,
            goalWeight: weightData.goal
        )
    }
    
    private func fetchUserPreferences() async -> (goals: [String], preferences: [String: Any]) {
        let goals = UserDefaults.standard.stringArray(forKey: "userGoals") ?? ["General fitness"]
        let preferences: [String: Any] = [
            "preferredWorkoutTime": UserDefaults.standard.string(forKey: "preferredWorkoutTime") ?? "Morning",
            "fitnessLevel": UserDefaults.standard.string(forKey: "fitnessLevel") ?? "Intermediate",
            "dietaryRestrictions": UserDefaults.standard.stringArray(forKey: "dietaryRestrictions") ?? []
        ]
        return (goals, preferences)
    }
    
    private func fetchRecentWorkouts() async -> [CDWorkout] {
        let request: NSFetchRequest<CDWorkout> = CDWorkout.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDWorkout.date, ascending: false)]
        request.fetchLimit = 10
        
        do {
            return try workoutRepository.context.fetch(request)
        } catch {
            print("Error fetching workouts: \(error)")
            return []
        }
    }
    
    /// The user's most recent meals, read through the official nutrition service.
    ///
    /// This used to fetch `CDMeal` directly. That entity receives no user writes
    /// — every logged meal lives in `CDEcksteinMealEntry` — so the result was
    /// always empty and the coach was told the user had never eaten. See
    /// NUTRITION_MIGRATION_PLAN.md §13.
    private func fetchRecentMeals() async -> [NutritionMealSummary] {
        do {
            return try nutritionService.recentMeals(limit: 20)
        } catch {
            print("Error fetching recent meals: \(error)")
            return []
        }
    }
    
    private func fetchWeightData() async -> (current: Double?, goal: Double?, trend: WeightTrend) {
        let current = weightRepository.currentWeight
        let goal = weightRepository.goalWeight
        let trend = weightRepository.getWeightTrend()
        
        return (current, goal, trend)
    }
    
    private func buildActivitySummary(from workouts: [CDWorkout]) -> String {
        guard !workouts.isEmpty else {
            return "No recent workout activity"
        }
        
        let workoutCount = workouts.count
        let totalVolume: Double = workouts.reduce(0) { total, workout in
            let sets = (workout.sets?.allObjects as? [CDWorkoutSet]) ?? []
            let workoutVolume = sets.reduce(0) { setTotal, set in
                setTotal + (set.weightKg * Double(set.reps))
            }
            return total + workoutVolume
        }
        
        let exerciseTypes = Set(workouts.compactMap { workout in
            (workout.sets?.allObjects as? [CDWorkoutSet])?.compactMap { $0.exercise?.category }
        }.flatMap { $0 })
        
        return "Completed \(workoutCount) workouts in the past week. Total volume: \(Int(totalVolume))kg. Focused on: \(exerciseTypes.joined(separator: ", "))"
    }
    
    private func buildCurrentStats(weight: Double?, goalWeight: Double?, weeklyWorkouts: Int, averageCalories: Int) -> String {
        var stats: [String] = []
        
        if let weight = weight {
            stats.append("Weight: \(String(format: "%.1f", weight))kg")
        }
        
        if let goal = goalWeight, let current = weight {
            let toGo = goal - current
            stats.append("Goal: \(String(format: "%.1f", abs(toGo)))kg to \(toGo > 0 ? "gain" : "lose")")
        }
        
        stats.append("Weekly workouts: \(weeklyWorkouts)")
        stats.append("Avg daily calories: \(averageCalories)")
        
        return stats.joined(separator: ", ")
    }
    
    /// Mean daily calories across the days the given meals cover.
    ///
    /// Reads the nutrition snapshots the service already computed instead of
    /// re-deriving them from `CDMeal` relationships.
    private func calculateAverageCalories(from meals: [NutritionMealSummary]) -> Int {
        guard !meals.isEmpty else { return 0 }

        let calendar = Calendar.current
        let byDay = Dictionary(grouping: meals) { meal in
            calendar.startOfDay(for: meal.date)
        }

        let totalCalories = byDay.values.reduce(0.0) { running, mealsThatDay in
            running + mealsThatDay.reduce(0.0) { $0 + $1.nutrition.calories }
        }

        return Int((totalCalories / Double(byDay.count)).rounded())
    }
}

// MARK: - Quick Context Builders

extension AIContextBuilder {
    func buildWorkoutContext(for exercise: String?) -> String {
        guard let exercise = exercise else {
            return "General workout advice requested"
        }
        
        // Fetch exercise history
        let request: NSFetchRequest<CDWorkoutSet> = CDWorkoutSet.fetchRequest()
        request.predicate = NSPredicate(format: "exercise.name == %@", exercise)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDWorkoutSet.workout?.date, ascending: false)]
        request.fetchLimit = 10
        
        do {
            let sets = try workoutRepository.context.fetch(request)
            if !sets.isEmpty {
                let maxWeight = sets.map { $0.weightKg }.max() ?? 0
                let avgReps = sets.reduce(0) { $0 + Int($1.reps) } / sets.count
                return "Previous \(exercise) performance: Max weight \(maxWeight)kg, average \(avgReps) reps"
            }
        } catch {
            print("Error fetching exercise history: \(error)")
        }
        
        return "First time performing \(exercise)"
    }
    
    func buildDietContext(for mealType: String?) -> String {
        // Read the official nutrition path rather than `CDMeal`, which receives
        // no user writes — see NUTRITION_MIGRATION_PLAN.md §13.
        let slot = mealType.map { MealType(storedValue: $0) }

        do {
            let meals = try nutritionService.recentMeals(limit: 21).filter { meal in
                guard let slot = slot else { return true }
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
        } catch {
            print("Error fetching meal history: \(error)")
            return "No recent \(mealType ?? "meal") data available"
        }
    }
}