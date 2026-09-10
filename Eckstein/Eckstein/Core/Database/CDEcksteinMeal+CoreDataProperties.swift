//
//  CDEcksteinMeal+CoreDataProperties.swift
//  Eckstein
//
//  Created by Eliad Shahar on 14/07/2025.
//

import Foundation
import CoreData

extension CDEcksteinMeal {
    @NSManaged public var id: UUID?
    @NSManaged public var date: Date?

    /// The Eckstein method's two-meal partition (1 or 2). Unchanged; it is not
    /// a relabelling of `mealType` and neither can be derived from the other.
    @NSManaged public var mealNumber: Int32

    @NSManaged public var isCarbLoad: Bool

    // MARK: - Nutrition (added in "Eckstein 2")

    /// `breakfast` / `lunch` / `dinner` / `snack`, or `nil` for rows written
    /// before this field existed. Stored as an optional `String` rather than an
    /// enum so persistence never depends on declaration order and an unknown
    /// value from a newer client cannot trap. See NUTRITION_MIGRATION_PLAN.md §6.
    @NSManaged public var mealType: String?

    /// Denormalised roll-ups of `entries`, written by `NutritionService` so a
    /// day list does not have to walk every entry. Never the source of truth —
    /// `NutritionAggregator` recomputes from the entries themselves.
    ///
    /// `NSNumber?` for the same reason as the food columns: a nullable numeric
    /// attribute cannot be an optional Swift scalar under `@NSManaged`.
    @NSManaged public var totalCalories: NSNumber?
    @NSManaged public var totalProtein: NSNumber?
    @NSManaged public var totalCarbs: NSNumber?
    @NSManaged public var totalFat: NSNumber?
    @NSManaged public var totalFiber: NSNumber?

    @NSManaged public var updatedAt: Date?

    @NSManaged public var user: CDUser?
    @NSManaged public var entries: NSSet?
}

// MARK: Generated accessors for entries
extension CDEcksteinMeal {
    @objc(addEntriesObject:)
    @NSManaged public func addToEntries(_ value: CDEcksteinMealEntry)

    @objc(removeEntriesObject:)
    @NSManaged public func removeFromEntries(_ value: CDEcksteinMealEntry)

    @objc(addEntries:)
    @NSManaged public func addToEntries(_ values: NSSet)

    @objc(removeEntries:)
    @NSManaged public func removeFromEntries(_ values: NSSet)
}

extension CDEcksteinMeal {
    /// `entries` as a Swift array. `NSSet` has no ordering, so callers that need
    /// a stable order sort explicitly.
    var entriesArray: [CDEcksteinMealEntry] {
        (entries?.allObjects as? [CDEcksteinMealEntry]) ?? []
    }
}
