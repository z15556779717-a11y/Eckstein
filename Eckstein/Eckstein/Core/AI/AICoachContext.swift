//
//  AICoachContext.swift
//  Eckstein
//
//  What the AI coach is told about the user.
//

import Foundation

/// The facts the coach is allowed to see, and nothing else.
///
/// This is deliberately a small, closed value type rather than a bundle of
/// managed objects. The previous shape handed the prompt builder `[CDWorkout]`
/// and `[NutritionMealSummary]` — live Core Data rows — so what reached the
/// provider depended on which relationships those rows happened to have loaded,
/// and every field on them was one careless interpolation away from being sent.
/// Here the boundary is explicit: these properties are the whole surface.
///
/// **What is never in here**, and why each one is a risk rather than a
/// nicety:
/// - `NSManagedObjectID` and the app's `UUID`s — opaque to the model, and a
///   stable handle into the user's store if anything logs or retains them.
/// - Row counts, database file paths, table names — nothing the coach can use,
///   and each one describes the app's internals rather than the user.
/// - The user's email, name, or any account identifier — the coach does not
///   need to know who it is talking to, only what they are training for.
/// - Individual meals, sets and weigh-ins — the averages and the latest values
///   answer every question the coach is asked, and a diet log for a week is a
///   lot of tokens for no extra advice.
struct AICoachContext: Equatable {

    // MARK: - Nutrition

    /// The last seven days of eating, as averages.
    ///
    /// Averaged over the days that have any logging, not over all seven: a user
    /// who logged four days has a four-day average, and telling the coach they
    /// ate 1,100 kcal a day because three days were empty would be a lie the
    /// coach then advises on.
    struct NutritionWindow: Equatable {
        let daysCovered: Int
        let daysLogged: Int
        let averageCalories: Int
        let averageProteinGrams: Int
        let averageCarbsGrams: Int
        let averageFatGrams: Int
        let averageFiberGrams: Int
        let goals: DailyNutritionGoals

        var hasData: Bool { daysLogged > 0 }
    }

    // MARK: - Training

    /// One workout, described by position rather than by identity.
    ///
    /// `daysAgo` instead of a date: the coach reasons in "yesterday" and "three
    /// days ago", and an absolute timestamp is a second, finer-grained record of
    /// when the user was in the gym than the advice needs.
    struct TrainingSession: Equatable {
        let name: String
        let daysAgo: Int
        let durationMinutes: Int
        let completedSets: Int
        let volumeKg: Double
    }

    /// Where an exercise is now, rather than everything ever done on it.
    struct ExerciseProgress: Equatable {
        let name: String
        let bestWeightKg: Double
        let bestEstimatedOneRepMaxKg: Double
        let daysAgo: Int
    }

    struct WorkoutWindow: Equatable {
        let sessionsThisWeek: Int
        let volumeThisWeekKg: Double
        let recentSessions: [TrainingSession]
        let exerciseProgress: [ExerciseProgress]
    }

    // MARK: - Body weight

    struct WeightWindow: Equatable {
        let currentKg: Double?
        let targetKg: Double?
        /// Change across the last 30 days of weigh-ins. `nil` when fewer than two
        /// days have a value — a change measured from one point is not a change.
        let changeOverMonthKg: Double?
        let trend: WeightTrend
    }

    // MARK: - Profile

    /// The user's stated training intention, already a display string.
    let fitnessGoal: String

    let nutrition: NutritionWindow
    let workout: WorkoutWindow
    let weight: WeightWindow

    /// The one thing with no data behind it: a fresh install has no goal set.
    static let defaultFitnessGoal = "General fitness"

    // MARK: - The prompt's view of this

    /// The goals, as the two prompt builders that predate this type expect them.
    var userGoals: [String] { [fitnessGoal] }

    var goalWeight: Double? { weight.targetKg }

    /// The training half of the summary, in one sentence.
    var recentActivitySummary: String {
        guard workout.sessionsThisWeek > 0 else {
            return "No workouts logged in the past seven days"
        }
        let sessions = workout.sessionsThisWeek == 1 ? "1 workout" : "\(workout.sessionsThisWeek) workouts"
        return "\(sessions) in the past seven days, \(Int(workout.volumeThisWeekKg.rounded())) kg total volume"
    }

    /// The body-composition half, in one line.
    var currentStats: String {
        var parts: [String] = []

        if let current = weight.currentKg {
            parts.append("Current weight \(String(format: "%.1f", current)) kg")
        }
        if let target = weight.targetKg {
            parts.append("Target \(String(format: "%.1f", target)) kg")
        }
        if let change = weight.changeOverMonthKg, abs(change) >= WeightMetrics.tolerance {
            parts.append("\(change < 0 ? "Down" : "Up") \(String(format: "%.1f", abs(change))) kg over 30 days")
        }

        parts.append(nutrition.hasData
            ? "Averaging \(nutrition.averageCalories) kcal and \(nutrition.averageProteinGrams) g protein over the last \(nutrition.daysLogged) logged days"
            : "No nutrition logged in the last seven days")

        parts.append(recentActivitySummary)

        return parts.joined(separator: ". ")
    }
}
