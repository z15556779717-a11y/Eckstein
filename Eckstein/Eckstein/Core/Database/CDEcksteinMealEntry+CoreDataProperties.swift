//
//  CDEcksteinMealEntry+CoreDataProperties.swift
//  Eckstein
//
//  Created by Eliad Shahar on 14/07/2025.
//

import Foundation
import CoreData

extension CDEcksteinMealEntry {
    @NSManaged public var id: UUID?
    @NSManaged public var foodName: String?
    @NSManaged public var category: String?
    @NSManaged public var gramsConsumed: Int32

    // MARK: - Nutrition snapshot (added in "Eckstein 2")
    //
    // The entry stores its own nutrition values rather than reading them through
    // `food`, so a historical record does not change when the catalog entry is
    // later edited. The entry already denormalised `foodName` and `category`, so
    // this matches the existing design rather than fighting it.
    //
    // Optional: entries logged before nutrition tracking have `nil`, meaning
    // "unknown", not "zero". See NUTRITION_MIGRATION_PLAN.md §5.2.
    //
    // `NSNumber?` rather than `Double?`: a nullable numeric attribute has no
    // optional Swift scalar representation under `@NSManaged`, and the column
    // has to stay nullable so "unknown" and "zero" remain distinguishable.

    @NSManaged public var calories: NSNumber?
    @NSManaged public var protein: NSNumber?
    @NSManaged public var carbs: NSNumber?
    @NSManaged public var fat: NSNumber?
    @NSManaged public var fiber: NSNumber?

    @NSManaged public var updatedAt: Date?

    /// Optional convenience link to the catalog entry. Never the source of truth
    /// for nutrition — a pre-migration row keeps this `nil` and stays fully
    /// readable through `foodName` + the snapshot. Nullify on both sides, so
    /// deleting a catalog food never deletes history.
    @NSManaged public var food: CDEcksteinFood?

    @NSManaged public var meal: CDEcksteinMeal?
}

extension CDEcksteinMealEntry {
    /// The entry's nutrition as a value, with unknown (`nil`) fields read as
    /// zero so totals stay additive.
    var nutritionSnapshot: NutritionSnapshot {
        NutritionSnapshot(
            calories: calories?.doubleValue ?? 0,
            protein: protein?.doubleValue ?? 0,
            carbs: carbs?.doubleValue ?? 0,
            fat: fat?.doubleValue ?? 0,
            fiber: fiber?.doubleValue ?? 0
        )
    }

    /// Whether any nutrition value was recorded. Distinguishes an entry logged
    /// before nutrition tracking from one logged as genuinely zero.
    var hasNutritionData: Bool {
        calories != nil || protein != nil || carbs != nil || fat != nil || fiber != nil
    }
}
