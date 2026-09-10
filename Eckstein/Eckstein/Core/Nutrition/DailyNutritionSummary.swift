//
//  DailyNutritionSummary.swift
//  Eckstein
//
//  The aggregate the Dashboard and the AI Coach read. See
//  NUTRITION_MIGRATION_PLAN.md §7 and §8.
//

import Foundation

/// A user's daily nutrition targets.
///
/// `nil` on a component means the target is not set — distinct from a target of
/// zero, which a caller may want to render as a full ring rather than an empty
/// one. `CDUserPreferences` stores these as `Int32` for the three goals that
/// predate this phase and optional `Double` for fat and fiber.
struct DailyNutritionGoals: Equatable {
    var calories: Double?
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var fiber: Double?

    init(
        calories: Double? = nil,
        protein: Double? = nil,
        carbs: Double? = nil,
        fat: Double? = nil,
        fiber: Double? = nil
    ) {
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
    }

    /// No targets set.
    static let unset = DailyNutritionGoals()
}

/// One calendar day's nutrition.
///
/// Everything a dashboard or an AI prompt needs, computed outside any `View`.
struct DailyNutritionSummary: Equatable {
    /// The day this summary covers, as given to the aggregator. Not necessarily
    /// midnight — compare days with `Calendar.isDate(_:inSameDayAs:)`, never
    /// with `==`.
    let date: Date

    /// The day's totals across every meal.
    let totals: NutritionSnapshot

    /// Totals per meal slot. Entries with no recorded slot are keyed
    /// `.unspecified`.
    let byMealType: [MealType: NutritionSnapshot]

    /// The targets these totals should be read against.
    let goals: DailyNutritionGoals

    /// How many entries contributed. Zero for a day with no logging.
    let entryCount: Int

    // MARK: - Named totals
    //
    // The five values the brief requires the aggregation layer to expose.

    var dailyCalories: Double { totals.calories }
    var dailyProtein: Double { totals.protein }
    var dailyCarbohydrates: Double { totals.carbs }
    var dailyFat: Double { totals.fat }
    var dailyFiber: Double { totals.fiber }

    /// Whether anything was logged for this day.
    var isEmpty: Bool { entryCount == 0 }

    /// A day with no logging at all.
    static func empty(on date: Date, goals: DailyNutritionGoals = .unset) -> DailyNutritionSummary {
        DailyNutritionSummary(
            date: date,
            totals: .zero,
            byMealType: Dictionary(uniqueKeysWithValues: MealType.allCases.map { ($0, .zero) }),
            goals: goals,
            entryCount: 0
        )
    }
}
