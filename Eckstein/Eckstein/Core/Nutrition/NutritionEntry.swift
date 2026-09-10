//
//  NutritionEntry.swift
//  Eckstein
//
//  Value-typed inputs and outputs for the nutrition layer. Nothing here is an
//  `NSManagedObject`, so the aggregation maths can be tested without a store.
//
//  See NUTRITION_MIGRATION_PLAN.md §7 and §13.
//

import Foundation

/// One logged item, reduced to the values the aggregator needs.
///
/// `NutritionService` maps `CDEcksteinMealEntry` onto this; the aggregator never
/// sees an entity.
struct NutritionEntry: Equatable {
    /// The date of the meal this entry belongs to. `CDEcksteinMealEntry` has no
    /// date of its own — the date lives on `CDEcksteinMeal`.
    let date: Date

    let mealType: MealType

    /// The food name as recorded on the entry, not a catalog reference.
    let foodName: String

    let grams: Double

    /// What this entry contributed. `.zero` for entries logged before nutrition
    /// tracking existed; `hasNutritionData` on the entry distinguishes the two.
    let nutrition: NutritionSnapshot
}

/// A meal, summarised for a caller that wants a list rather than a total.
///
/// This is the only shape the AI Coach reads. No `NSManagedObject` escapes the
/// service, so the AI layer cannot start fetching entities of its own.
struct NutritionMealSummary: Equatable {
    let date: Date
    let mealType: MealType
    let foodNames: [String]
    let totalGrams: Double
    let nutrition: NutritionSnapshot

    var isEmpty: Bool { foodNames.isEmpty }
}
