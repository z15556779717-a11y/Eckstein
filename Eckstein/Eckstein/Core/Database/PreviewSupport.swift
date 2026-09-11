//
//  PreviewSupport.swift
//  Eckstein
//
//  An in-memory store with sample data, for SwiftUI previews.
//
//  Two deliberate constraints, because a preview that can corrupt real state is
//  worse than no preview at all:
//
//    * The store is `PersistenceController(inMemory: true)` — `/dev/null`. A
//      preview cannot read, write or migrate the store on disk.
//    * Nothing here touches `UserDefaults`. Height, fitness goal, target weight
//      and unit preference all live there and all persist across a simulator
//      session, so a preview writing one would change the app the next time it
//      launched. The screens that read those therefore render their "not set"
//      branch in a preview, which is a real state and worth looking at.
//
//  The sample data is written through the same `NutritionService` and
//  `WeightRepository` calls the app makes, so a preview exercises the real write
//  path rather than a hand-assembled object graph that could differ from it.
//
//  The whole file is `#if DEBUG`: none of it compiles into a release build.
//

#if DEBUG

import CoreData
import Foundation

@MainActor
enum PreviewSupport {

    /// The preview store. Created once, so every preview in a session sees the
    /// same sample data rather than a fresh empty store each time.
    static let controller = PersistenceController(inMemory: true)

    static var context: NSManagedObjectContext { controller.container.viewContext }

    /// A nutrition service over the preview store, seeded on first use.
    static func nutritionService() -> NutritionService {
        seedIfNeeded()
        return NutritionService(context: context)
    }

    /// A weight repository over the preview store, seeded on first use.
    static func weightRepository() -> WeightRepository {
        seedIfNeeded()
        return WeightRepository(context: context)
    }

    /// Seeds the sample data, once.
    ///
    /// `didSeed` is set *before* `seed()` runs: `seed()` asks for the services
    /// above, and a flag set afterwards would send it back round for ever.
    private static func seedIfNeeded() {
        guard !didSeed else { return }
        didSeed = true
        seed()
    }

    private static var didSeed = false

    private static func seed() {
        let nutrition = nutritionService()
        let weights = weightRepository()
        let calendar = Calendar.current
        let now = Date()

        // The targets the Dashboard's cards are read against.
        try? nutrition.setGoals(
            DailyNutritionGoals(calories: 2200, protein: 160, carbs: 240, fat: 70, fiber: 30)
        )

        // A day that uses the four slots, so each section of the Diet screen has
        // something in it and the totals are not all zero.
        let day: [(name: String, category: String, calories: Int, protein: Double, carbs: Double, fat: Double, fiber: Double, grams: Double, slot: MealType)] = [
            ("Oatmeal (Dry)", "Carbs", 389, 16.9, 66.3, 6.9, 10.6, 60, .breakfast),
            ("Greek Yogurt (Plain)", "Dairy", 59, 10.0, 3.6, 0.4, 0, 150, .breakfast),
            ("Chicken (No Skin)", "Protein", 165, 31.0, 0, 3.6, 0, 180, .lunch),
            ("White Rice (Cooked)", "Carbs", 130, 2.7, 28.2, 0.3, 0.4, 150, .lunch),
            ("Salmon (Cooked)", "Protein", 208, 20.4, 0, 13.4, 0, 140, .dinner),
            ("Sweet Potato (Cooked)", "Carbs", 86, 1.6, 20.1, 0.1, 3.0, 130, .dinner),
            ("Apple", "Fruit", 52, 0.3, 14.0, 0.2, 2.4, 182, .snack)
        ]

        for item in day {
            guard let food = try? nutrition.upsertFood(
                from: FoodTemplate(
                    name: item.name,
                    category: item.category,
                    barcode: nil,
                    caloriesPer100g: item.calories,
                    proteinPer100g: item.protein,
                    carbsPer100g: item.carbs,
                    fatPer100g: item.fat,
                    fiberPer100g: item.fiber,
                    brand: nil,
                    servingSize: item.grams,
                    servingUnit: "g"
                ),
                source: .seed
            ) else { continue }

            try? nutrition.logEntry(
                foodName: item.name,
                category: food.category,
                grams: item.grams,
                mealNumber: item.slot.slotMealNumber,
                mealType: item.slot,
                date: now,
                food: food,
                calendar: calendar
            )
            try? nutrition.markUsed(food)
        }

        // A fortnight of weigh-ins, so the trend chart has a shape to draw
        // instead of a single point. `setGoalWeight` is deliberately not called:
        // it writes `UserDefaults`, and a preview has no business changing a
        // setting the app will read on its next launch.
        let weighIns: [(daysAgo: Int, kilograms: Double)] = [
            (14, 82.4), (12, 82.1), (10, 81.6), (9, 81.9), (7, 81.2),
            (5, 80.8), (4, 80.9), (2, 80.3), (1, 80.5), (0, 80.1)
        ]

        for weighIn in weighIns {
            let date = calendar.date(byAdding: .day, value: -weighIn.daysAgo, to: now) ?? now
            _ = weights.createWeightEntry(weight: weighIn.kilograms, date: date, source: "manual")
        }
        weights.refresh()
    }
}

#endif
