//
//  WorkoutMetrics.swift
//  Eckstein
//
//  The arithmetic behind the training screens: how much work a set is, and how
//  much a lifter might move once.
//

import Foundation

/// Volume and estimated one-rep max.
///
/// Both were being computed inline in several places — `CDWorkout.totalVolume`,
/// `AnalyticsView` and `ExerciseProgressionView` — each written slightly
/// differently, with no test under any of them. Three implementations of one
/// formula is three chances for the number on a chart, the number in an AI
/// prompt and the number in a test to disagree, so the formulas live here.
///
/// Pure functions over the objects the callers already have: no fetching, no
/// context, nothing that needs a main actor.
enum WorkoutMetrics {

    // MARK: - Which sets count

    /// The sets that were actually performed.
    ///
    /// `ExerciseSetCard` marks a set complete the moment reps are entered, so in
    /// practice this is "the user did it".
    static func completedSets(_ sets: [CDWorkoutSet]) -> [CDWorkoutSet] {
        sets.filter { $0.completed }
    }

    /// How many sets were performed.
    static func completedSetCount(_ sets: [CDWorkoutSet]) -> Int {
        completedSets(sets).count
    }

    // MARK: - Volume

    /// `weight × reps` for one set.
    ///
    /// Zero when either side is missing or nonsensical: a set logged with no
    /// load moves no external weight, and a set with no reps is not a set.
    ///
    /// The `isFinite` guard is what keeps one corrupt row from taking a whole
    /// workout's total with it — an infinity or a `nan` propagates through
    /// `reduce(+)`, and from there into the chart, the weekly average and the
    /// AI summary.
    static func setVolume(weightKg: Double, reps: Int32) -> Double {
        guard weightKg.isFinite, weightKg > 0, reps > 0 else { return 0 }
        return weightKg * Double(reps)
    }

    static func setVolume(_ set: CDWorkoutSet) -> Double {
        setVolume(weightKg: set.weightKg, reps: set.reps)
    }

    /// The volume of a collection of sets — **every** set, complete or not.
    ///
    /// This is the number the app already reported before this type existed:
    /// `CDWorkout.totalVolume`, the analytics chart, the workout history row.
    /// `WorkoutTests.testTotalVolumeIsSumOfRepsTimesWeight` pins that contract,
    /// and a total somebody may have screenshotted is not something to quietly
    /// redefine during a refactor.
    ///
    /// The distinction is mostly theoretical in practice: a set only gets a
    /// weight and reps once the user enters them, and entering reps is what
    /// marks it complete. Where the difference matters — reporting to the AI
    /// coach how much work was really done — use `completedVolume(of:)`.
    static func volume(of sets: [CDWorkoutSet]) -> Double {
        let total = sets.reduce(0) { $0 + setVolume($1) }
        return total.isFinite ? total : 0
    }

    /// Only the sets that were marked complete.
    static func completedVolume(of sets: [CDWorkoutSet]) -> Double {
        volume(of: completedSets(sets))
    }

    /// One workout's volume: every completed set it holds.
    static func workoutVolume(_ workout: CDWorkout) -> Double {
        volume(of: workout.setsArray)
    }

    /// One workout's completed volume — what the AI coach is told the user did,
    /// as opposed to what was on the screen.
    static func completedWorkoutVolume(_ workout: CDWorkout) -> Double {
        completedVolume(of: workout.setsArray)
    }

    /// One exercise's volume *within one workout*.
    ///
    /// Deliberately scoped to a single workout: an exercise's volume across all
    /// history is a different question, and `ExerciseProgressionView` asks that
    /// one.
    static func exerciseVolume(_ exercise: CDExercise, in workout: CDWorkout) -> Double {
        volume(of: workout.setsArray.filter { $0.exercise == exercise })
    }

    // MARK: - Estimated one-rep max

    /// Epley: `weight × (1 + reps / 30)`.
    ///
    /// `nil`, not zero, when the set cannot have one. "No estimate" and "an
    /// estimate of zero" are different answers, and only one of them belongs on
    /// a chart's y-axis.
    ///
    /// A single rep comes back as a little *over* the weight itself — `1 + 1/30`
    /// is 1.03, so a 100 kg single estimates 103 kg. That is the formula's own
    /// answer rather than a rounding error, and returning the weight exactly for
    /// a single would be easier to read but would disagree with every other
    /// Epley implementation the user might compare the app against.
    static func estimatedOneRepMax(weightKg: Double, reps: Int32) -> Double? {
        guard weightKg.isFinite, weightKg > 0, reps > 0 else { return nil }
        let estimate = weightKg * (1 + Double(reps) / 30)
        return estimate.isFinite ? estimate : nil
    }

    static func estimatedOneRepMax(_ set: CDWorkoutSet) -> Double? {
        estimatedOneRepMax(weightKg: set.weightKg, reps: set.reps)
    }

    /// The best estimated max across a collection of sets, ignoring the ones
    /// that have none. `nil` when no set does.
    static func bestEstimatedOneRepMax(in sets: [CDWorkoutSet]) -> Double? {
        sets.compactMap { estimatedOneRepMax($0) }.max()
    }
}

// MARK: - Formatting

/// How the training screens write a weight or a volume.
///
/// Formatting lives next to the arithmetic for the same reason
/// `NutrientFormat` sits in `Core/Nutrition`: the two have to agree about what
/// counts as a number before either can decide how to print it.
enum WorkoutFormat {

    /// "80 kg", "82.5 kg", or an em dash when there is no number to show.
    ///
    /// `kg` is a unit symbol rather than a word, so it is not translated — the
    /// same call the nutrition screens made for `g` and `kcal`. The em dash is
    /// for absent, which is not the same as zero and should not read as it.
    static func weight(_ value: Double?) -> String {
        guard let value, value.isFinite, value >= 0 else { return "—" }

        // Whole kilos print without a decimal — "80 kg" rather than "80.0 kg" —
        // because that is how a lifter writes it. The tolerance absorbs the
        // float noise that a 2.5 kg plate added to 77.5 leaves behind.
        let rounded = value.rounded()
        let number = abs(value - rounded) < 0.05
            ? String(format: "%.0f", rounded)
            : String(format: "%.1f", value)

        return "\(number) kg"
    }
}
