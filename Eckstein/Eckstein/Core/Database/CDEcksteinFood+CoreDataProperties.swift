//
//  CDEcksteinFood+CoreDataProperties.swift
//  Eckstein
//
//  Created by Eliad Shahar on 14/07/2025.
//

import Foundation
import CoreData

extension CDEcksteinFood {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var category: String?
    @NSManaged public var dailyGrams: Int32
    @NSManaged public var isFat: Bool
    @NSManaged public var isCustom: Bool
    @NSManaged public var createdAt: Date?

    // MARK: - Nutrition (added in "Eckstein 2")
    //
    // All optional on purpose: existing rows written before nutrition tracking
    // existed have no values, and `nil` means "unknown" rather than "zero".
    // See NUTRITION_MIGRATION_PLAN.md §4.2 and §5.1.

    /// Energy per 100 g. Kept as `NSNumber?` rather than `Double`: the attribute
    /// is `usesScalarValueType="NO"` so the store can hold a real `NULL`, and an
    /// optional Swift scalar cannot be `@NSManaged` (it has no Objective-C
    /// representation). `nil` means "unknown", which is why the column is not a
    /// scalar defaulting to zero — a food with no declared values must not claim
    /// to be zero-calorie. See NUTRITION_MIGRATION_PLAN.md §4.2 and §5.1.
    @NSManaged public var caloriesPer100g: NSNumber?
    @NSManaged public var proteinPer100g: NSNumber?
    @NSManaged public var carbsPer100g: NSNumber?
    @NSManaged public var fatPer100g: NSNumber?
    @NSManaged public var fiberPer100g: NSNumber?

    /// Barcode and brand, so the Open Food Facts scanner can serve this entity.
    @NSManaged public var barcode: String?
    @NSManaged public var brand: String?

    /// Default serving. `servingSize` is in grams.
    @NSManaged public var servingSize: NSNumber?
    @NSManaged public var servingUnit: String?

    /// The free-form food group ("Protein", "Dairy", …).
    ///
    /// Deliberately separate from `category`, which keeps its `DietCategory`
    /// meaning and is matched exactly by the Eckstein diet UI. Merging the two
    /// would make catalog rows appear in the diet-rule pickers.
    @NSManaged public var foodCategory: String?

    @NSManaged public var isFavorite: Bool
    @NSManaged public var isVerified: Bool

    /// Stamped on every log write; "recent foods" is a query over this, not a
    /// separate table.
    @NSManaged public var lastUsed: Date?

    @NSManaged public var updatedAt: Date?

    /// Provenance, as a `NutritionSource` raw value (`"seed"`, `"manual"`,
    /// `"barcode"`, …). Read and written through `nutritionSource`, which decodes
    /// an unrecognised stored string to `nil` rather than to a guess. A row
    /// written before this field existed has `nil`.
    @NSManaged public var source: String?

    @NSManaged public var entries: NSSet?
}

// MARK: Generated accessors for entries
extension CDEcksteinFood {
    @objc(addEntriesObject:)
    @NSManaged public func addToEntries(_ value: CDEcksteinMealEntry)

    @objc(removeEntriesObject:)
    @NSManaged public func removeFromEntries(_ value: CDEcksteinMealEntry)

    @objc(addEntries:)
    @NSManaged public func addToEntries(_ values: NSSet)

    @objc(removeEntries:)
    @NSManaged public func removeFromEntries(_ values: NSSet)
}
