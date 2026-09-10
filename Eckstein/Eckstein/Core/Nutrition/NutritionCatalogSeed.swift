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

    /// The value written to `CDEcksteinFood.source` for seeded rows.
    static let source = "seed"

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
        request.predicate = NSPredicate(format: "source == %@", source)
        request.fetchLimit = 1
        return try context.count(for: request) > 0
    }
}
