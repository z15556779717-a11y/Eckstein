//
//  NutritionCatalogSeed.swift
//  Eckstein
//
//  Seeds the official food catalog (`CDEcksteinFood` rows with an empty
//  `category`) from the templates the app already shipped in `FoodData`.
//
//  See NUTRITION_MIGRATION_PLAN.md §3.3. These rows replace the `CDFood` catalog
//  the launch path used to seed: the values are the project's own, copied
//  verbatim, and each row is stamped `source = "seed"` so it is distinguishable
//  from a user-created or scanned food.
//
//  Only FoodData's own foods are seeded. The Eckstein diet-rule foods
//  ("Chicken (with skin)", "Rice", "Bread", …) are a different vocabulary and
//  are deliberately left without nutrition values rather than having numbers
//  guessed for them — `nil` means unknown, and curating those values is
//  follow-up content work, not an architecture change.
//

import Foundation
import CoreData

enum NutritionCatalogSeed {

    /// The provenance written to `CDEcksteinFood.source` for seeded rows.
    static let source: NutritionSource = .seed

    /// Seeds the catalog if it has never been seeded.
    ///
    /// Idempotent: it checks for an existing seeded row first, so launching the
    /// app repeatedly does not duplicate the catalog. Returns how many rows were
    /// written, which is `0` on every launch after the first.
    @discardableResult
    static func seedIfNeeded(
        context: NSManagedObjectContext = PersistenceController.shared.container.viewContext
    ) throws -> Int {
        guard try !hasSeededCatalog(context: context) else { return 0 }

        let service = NutritionService(context: context)
        var written = 0

        for template in FoodData.foods {
            try service.upsertFood(from: template, source: source)
            written += 1
        }

        return written
    }

    private static func hasSeededCatalog(context: NSManagedObjectContext) throws -> Bool {
        let request: NSFetchRequest<CDEcksteinFood> = CDEcksteinFood.fetchRequest()
        request.predicate = NSPredicate(format: "source == %@", source.storedValue)
        request.fetchLimit = 1
        return try context.count(for: request) > 0
    }

    // MARK: - Diet-rule nutrition

    /// Fills in per-100 g values for the diet-rule foods already in the store.
    ///
    /// `CustomFoodManager.seedDefaultFoodsIfNeeded` writes these values when it
    /// creates a row, but a store seeded before this phase already holds the rows
    /// with every nutrition column `NULL`. This brings those rows up to date
    /// without a model change and without a data migration.
    ///
    /// Non-destructive and idempotent: a row is touched only when it has no
    /// per-100 g values at all, so a value the user corrected, a scanned product
    /// or a food the user typed is never overwritten, and re-running writes
    /// nothing. Returns how many rows it filled.
    @discardableResult
    static func backfillDietRuleNutrition(
        context: NSManagedObjectContext = PersistenceController.shared.container.viewContext
    ) throws -> Int {
        let request: NSFetchRequest<CDEcksteinFood> = CDEcksteinFood.fetchRequest()
        var filled = 0

        for food in try context.fetch(request) {
            guard let reference = DietRuleNutrition.reference(
                foodName: food.name ?? "",
                category: food.category
            ) else { continue }

            // Only a row with nothing recorded at all: a partial value means
            // somebody already decided what this food is.
            guard food.caloriesPer100g == nil,
                  food.proteinPer100g == nil,
                  food.carbsPer100g == nil,
                  food.fatPer100g == nil,
                  food.fiberPer100g == nil else { continue }

            apply(reference.per100g, to: food)
            food.nutritionSource = .seed
            food.updatedAt = Date()
            filled += 1
        }

        if filled > 0 {
            try context.save()
        }
        return filled
    }

    /// Writes a per-100 g value onto a food row.
    ///
    /// Shared with `CustomFoodManager` so a seeded row and a backfilled row end
    /// up with the same columns set.
    static func apply(_ per100g: NutritionSnapshot, to food: CDEcksteinFood) {
        food.caloriesPer100g = NSNumber(value: per100g.calories)
        food.proteinPer100g = NSNumber(value: per100g.protein)
        food.carbsPer100g = NSNumber(value: per100g.carbs)
        food.fatPer100g = NSNumber(value: per100g.fat)
        food.fiberPer100g = NSNumber(value: per100g.fiber)
    }
}
