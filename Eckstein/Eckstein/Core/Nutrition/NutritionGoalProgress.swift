//
//  NutritionGoalProgress.swift
//  Eckstein
//
//  A day's totals read against the user's targets: current, target, remaining
//  and progress, per component.
//
//  See NUTRITION_MIGRATION_PLAN.md §10.
//
//  Two rules this type exists to keep:
//
//    * `remaining` is **not** clamped at zero. A user with a 2200 kcal target who
//      has logged 2450 is 250 kcal over, and `-250` is the honest number. A
//      caller that wants to render "0 left" clamps at the point of display, where
//      it still has the sign available to draw a different ring.
//    * A component with no target is `nil` throughout, not zero. "No goal set"
//      and "a goal of zero" are different states, and only one of them means the
//      user is over budget the moment they eat anything.
//

import Foundation

/// One component's progress: what has been consumed, what was aimed for, and the
/// two derived figures.
struct NutrientGoalProgress: Equatable {
    /// How much has been consumed today, in the component's unit (kcal or g).
    let current: Double

    /// The user's target, or `nil` when none is set.
    let target: Double?

    init(current: Double, target: Double?) {
        self.current = current
        self.target = target
    }

    /// How much is left. **Negative when over target** — never clamped.
    /// `nil` when no target is set, because "remaining against nothing" is not a
    /// quantity.
    var remaining: Double? {
        target.map { $0 - current }
    }

    /// `current / target`. Unclamped, so a caller charting overshoot can see it.
    ///
    /// `nil` when no target is set, and also when the target is zero: dividing by
    /// it is not a ratio, and inventing `0` or `1` here would be a lie the caller
    /// cannot detect.
    var progress: Double? {
        guard let target = target, target != 0 else { return nil }
        return current / target
    }

    /// `progress` confined to `0...1`, for a ring or a bar that cannot draw past
    /// full. Only for display — the unclamped figures stay on this type.
    var displayProgress: Double {
        guard let progress = progress else { return 0 }
        return min(max(progress, 0), 1)
    }

    /// Whether a target is set at all.
    var hasTarget: Bool { target != nil }

    /// Whether the day is over target. `false` when no target is set.
    var isOverTarget: Bool {
        guard let remaining = remaining else { return false }
        return remaining < 0
    }

    /// Whether the target has been reached exactly or exceeded.
    var isTargetMet: Bool {
        guard let target = target else { return false }
        return current >= target
    }
}

/// A day's totals against the day's goals.
///
/// The five components are reachable both as `NutrientGoalProgress` values
/// (`progress.calories.current`) and as the flat names the brief uses
/// (`progress.caloriesCurrent`). The flat names are one-liners over the nested
/// ones, so the two can never disagree.
struct NutritionGoalProgress: Equatable {
    /// The day these figures cover. Compare days with `Calendar`, never `==`.
    let date: Date

    /// What was consumed that day.
    let consumed: NutritionSnapshot

    /// The targets the totals are read against.
    let goals: DailyNutritionGoals

    init(date: Date, consumed: NutritionSnapshot, goals: DailyNutritionGoals) {
        self.date = date
        self.consumed = consumed
        self.goals = goals
    }

    /// Builds from a day's summary — the shape `NutritionService` already
    /// produces, so this type adds no second aggregation.
    init(summary: DailyNutritionSummary) {
        self.init(date: summary.date, consumed: summary.totals, goals: summary.goals)
    }

    // MARK: - Nested values

    var calories: NutrientGoalProgress {
        NutrientGoalProgress(current: consumed.calories, target: goals.calories)
    }

    var protein: NutrientGoalProgress {
        NutrientGoalProgress(current: consumed.protein, target: goals.protein)
    }

    var carbohydrates: NutrientGoalProgress {
        NutrientGoalProgress(current: consumed.carbs, target: goals.carbs)
    }

    var fat: NutrientGoalProgress {
        NutrientGoalProgress(current: consumed.fat, target: goals.fat)
    }

    var fiber: NutrientGoalProgress {
        NutrientGoalProgress(current: consumed.fiber, target: goals.fiber)
    }

    /// Every component, in a fixed order, for a caller that iterates rather than
    /// naming each one.
    var allComponents: [(name: String, progress: NutrientGoalProgress)] {
        [
            ("calories", calories),
            ("protein", protein),
            ("carbohydrates", carbohydrates),
            ("fat", fat),
            ("fiber", fiber)
        ]
    }

    // MARK: - Flat names

    var caloriesCurrent: Double { calories.current }
    var caloriesTarget: Double? { calories.target }
    var caloriesRemaining: Double? { calories.remaining }
    var caloriesProgress: Double? { calories.progress }

    var proteinCurrent: Double { protein.current }
    var proteinTarget: Double? { protein.target }
    var proteinRemaining: Double? { protein.remaining }
    var proteinProgress: Double? { protein.progress }

    var carbohydratesCurrent: Double { carbohydrates.current }
    var carbohydratesTarget: Double? { carbohydrates.target }
    var carbohydratesRemaining: Double? { carbohydrates.remaining }
    var carbohydratesProgress: Double? { carbohydrates.progress }

    var fatCurrent: Double { fat.current }
    var fatTarget: Double? { fat.target }
    var fatRemaining: Double? { fat.remaining }
    var fatProgress: Double? { fat.progress }

    var fiberCurrent: Double { fiber.current }
    var fiberTarget: Double? { fiber.target }
    var fiberRemaining: Double? { fiber.remaining }
    var fiberProgress: Double? { fiber.progress }
}
