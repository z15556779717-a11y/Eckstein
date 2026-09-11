//
//  DietRuleNutrition.swift
//  Eckstein
//
//  Per-100 g nutrition for the Eckstein diet rules.
//
//  See NUTRITION_MIGRATION_PLAN.md §2.
//
//  Why this exists: the official Diet UI logs `DietRule` values, not catalog
//  rows. A rule is a *gram allowance* ("240 g of Chicken (with skin) a day"),
//  not a food record, and the rules are hard-coded in `EcksteinDietRules` rather
//  than stored in `CDEcksteinFood`. Without this table a diet-rule entry has no
//  per-100 g values to snapshot, and the whole day's calories would read zero.
//
//  Provenance, per entry:
//
//    * Values marked `isApproximate == false` come from a USDA FoodData Central
//      generic entry, rounded to one decimal. Where the repository already
//      shipped an equivalent food in `FoodData`, that project value is reused
//      verbatim rather than a second number being introduced for the same food
//      (reused: Salmon, Lean Ground Beef, Eggs, Chicken Breast, Tuna,
//      Cottage Cheese, White Rice, Pasta, Whole Wheat Bread, Oatmeal).
//    * Values marked `isApproximate == true` are composite dishes with no single
//      generic composition — a pizza slice is not a USDA food. They are rounded
//      to the nearest 5 kcal and 0.5 g on purpose: the figure is an estimate and
//      is not pretending otherwise.
//    * `Approved Snack 1` and `Approved Snack 2` have no value at all. They are
//      placeholders for a snack the user picks, so any number here would be
//      invented. Their entries keep a `nil` snapshot — "unknown", not "zero".
//
//  None of this is persisted: it is a static fixture, so the app never needs the
//  network to log a meal, and editing a value is a code change with a test.
//

import Foundation

/// Static per-100 g nutrition for a diet rule.
enum DietRuleNutrition {

    /// One documented per-100 g value.
    struct Reference: Equatable {
        let foodName: String
        let category: DietRule.DietCategory
        /// Values for 100 g of the food as eaten.
        let per100g: NutritionSnapshot
        /// Whether the figure is a rounded estimate for a composite dish.
        let isApproximate: Bool
    }

    // MARK: - Protein (Fat)

    private static let proteinFat: [Reference] = [
        Reference(
            foodName: "Fish (Fat)",
            category: .proteinFat,
            // Reused from FoodData's "Salmon (Cooked)".
            per100g: NutritionSnapshot(calories: 208, protein: 20.4, carbs: 0, fat: 13.4, fiber: 0),
            isApproximate: false
        ),
        Reference(
            foodName: "Chicken (with skin)",
            category: .proteinFat,
            // USDA: chicken, meat and skin, cooked, roasted.
            per100g: NutritionSnapshot(calories: 239, protein: 27.3, carbs: 0, fat: 13.6, fiber: 0),
            isApproximate: false
        ),
        Reference(
            foodName: "Beef (Fat)",
            category: .proteinFat,
            // Reused from FoodData's "Lean Ground Beef (Cooked)".
            per100g: NutritionSnapshot(calories: 250, protein: 26.0, carbs: 0, fat: 15.0, fiber: 0),
            isApproximate: false
        ),
        Reference(
            foodName: "Cheese",
            category: .proteinFat,
            // USDA: cheese, cheddar.
            per100g: NutritionSnapshot(calories: 402, protein: 24.9, carbs: 1.3, fat: 33.1, fiber: 0),
            isApproximate: false
        ),
        Reference(
            foodName: "Eggs",
            category: .proteinFat,
            // Reused from FoodData's "Eggs".
            per100g: NutritionSnapshot(calories: 155, protein: 13.0, carbs: 1.1, fat: 11.0, fiber: 0),
            isApproximate: false
        )
    ]

    // MARK: - Protein (Non-Fat)

    private static let proteinNonFat: [Reference] = [
        Reference(
            foodName: "Fish (Non-Fat)",
            category: .proteinNonFat,
            // USDA: cod, cooked, dry heat.
            per100g: NutritionSnapshot(calories: 105, protein: 22.8, carbs: 0, fat: 0.9, fiber: 0),
            isApproximate: false
        ),
        Reference(
            foodName: "Chicken (No Skin)",
            category: .proteinNonFat,
            // Reused from FoodData's "Chicken Breast (Cooked)".
            per100g: NutritionSnapshot(calories: 165, protein: 31.0, carbs: 0, fat: 3.6, fiber: 0),
            isApproximate: false
        ),
        Reference(
            foodName: "Turkey",
            category: .proteinNonFat,
            // USDA: turkey, breast, cooked, roasted.
            per100g: NutritionSnapshot(calories: 189, protein: 28.6, carbs: 0, fat: 7.4, fiber: 0),
            isApproximate: false
        ),
        Reference(
            foodName: "Tuna (in water)",
            category: .proteinNonFat,
            // Reused from FoodData's "Tuna (Canned in Water)".
            per100g: NutritionSnapshot(calories: 116, protein: 25.5, carbs: 0, fat: 0.8, fiber: 0),
            isApproximate: false
        ),
        Reference(
            foodName: "Cottage Cheese (Low Fat)",
            category: .proteinNonFat,
            // USDA: cottage cheese, lowfat, 1% milkfat.
            per100g: NutritionSnapshot(calories: 72, protein: 12.4, carbs: 2.7, fat: 1.0, fiber: 0),
            isApproximate: false
        )
    ]

    // MARK: - Carbs

    private static let carbs: [Reference] = [
        Reference(
            foodName: "Rice",
            category: .carbs,
            // Reused from FoodData's "White Rice (Cooked)".
            per100g: NutritionSnapshot(calories: 130, protein: 2.7, carbs: 28.2, fat: 0.3, fiber: 0.4),
            isApproximate: false
        ),
        Reference(
            foodName: "Pasta",
            category: .carbs,
            // Reused from FoodData's "Pasta (Cooked)".
            per100g: NutritionSnapshot(calories: 131, protein: 5.0, carbs: 25.0, fat: 1.1, fiber: 1.8),
            isApproximate: false
        ),
        Reference(
            foodName: "Bread",
            category: .carbs,
            // Reused from FoodData's "Whole Wheat Bread".
            per100g: NutritionSnapshot(calories: 247, protein: 9.0, carbs: 41.0, fat: 3.4, fiber: 6.0),
            isApproximate: false
        ),
        Reference(
            foodName: "Potato",
            category: .carbs,
            // USDA: potato, baked, flesh and skin.
            per100g: NutritionSnapshot(calories: 93, protein: 2.5, carbs: 21.2, fat: 0.1, fiber: 2.2),
            isApproximate: false
        ),
        Reference(
            foodName: "Oatmeal",
            category: .carbs,
            // Reused from FoodData's "Oatmeal (Dry)". The rule's 80 g allowance
            // is dry weight, which is how the oats are weighed out.
            per100g: NutritionSnapshot(calories: 389, protein: 16.9, carbs: 66.3, fat: 6.9, fiber: 10.6),
            isApproximate: false
        )
    ]

    // MARK: - Snacks

    private static let snacks: [Reference] = [
        // "Approved Snack 1" and "Approved Snack 2" are deliberately absent:
        // they are placeholders for whatever snack the user chooses, so there is
        // nothing to look up. `snapshot(for:)` returns `nil` for them, which the
        // entry records as unknown rather than zero.
    ]

    // MARK: - Carb load

    private static let carbLoad: [Reference] = [
        Reference(
            foodName: "Sushi",
            category: .carbLoad,
            per100g: NutritionSnapshot(calories: 145, protein: 6.5, carbs: 26.0, fat: 2.0, fiber: 1.0),
            isApproximate: true
        ),
        Reference(
            foodName: "Pizza",
            category: .carbLoad,
            per100g: NutritionSnapshot(calories: 265, protein: 11.0, carbs: 33.0, fat: 10.0, fiber: 2.5),
            isApproximate: true
        ),
        Reference(
            foodName: "Pasta with Sauce",
            category: .carbLoad,
            per100g: NutritionSnapshot(calories: 130, protein: 5.0, carbs: 22.0, fat: 2.5, fiber: 2.0),
            isApproximate: true
        ),
        Reference(
            foodName: "Burrito",
            category: .carbLoad,
            per100g: NutritionSnapshot(calories: 205, protein: 8.0, carbs: 26.0, fat: 7.5, fiber: 2.5),
            isApproximate: true
        ),
        Reference(
            foodName: "Chinese Food",
            category: .carbLoad,
            per100g: NutritionSnapshot(calories: 150, protein: 7.0, carbs: 18.0, fat: 6.0, fiber: 1.5),
            isApproximate: true
        ),
        Reference(
            foodName: "Pancakes",
            category: .carbLoad,
            per100g: NutritionSnapshot(calories: 225, protein: 6.5, carbs: 28.5, fat: 8.5, fiber: 1.0),
            isApproximate: true
        ),
        Reference(
            foodName: "French Toast",
            category: .carbLoad,
            per100g: NutritionSnapshot(calories: 230, protein: 7.5, carbs: 25.0, fat: 10.5, fiber: 1.0),
            isApproximate: true
        ),
        Reference(
            foodName: "Burger & Fries",
            category: .carbLoad,
            per100g: NutritionSnapshot(calories: 270, protein: 11.0, carbs: 27.0, fat: 13.5, fiber: 2.0),
            isApproximate: true
        ),
        Reference(
            foodName: "Ramen",
            category: .carbLoad,
            per100g: NutritionSnapshot(calories: 130, protein: 6.0, carbs: 17.0, fat: 4.5, fiber: 1.0),
            isApproximate: true
        ),
        Reference(
            foodName: "Pad Thai",
            category: .carbLoad,
            per100g: NutritionSnapshot(calories: 175, protein: 8.0, carbs: 22.0, fat: 6.5, fiber: 1.5),
            isApproximate: true
        )
    ]

    /// Every documented value, in `EcksteinDietRules` order.
    static var references: [Reference] {
        proteinFat + proteinNonFat + carbs + snacks + carbLoad
    }

    // MARK: - Lookup

    /// The value for a diet rule, or `nil` when none is documented.
    static func reference(for rule: DietRule) -> Reference? {
        reference(foodName: rule.foodName, category: rule.category.rawValue)
    }

    /// The value for a stored name and category, or `nil` when none is documented.
    ///
    /// `category` is the stored `DietCategory` raw value, which is what
    /// `CDEcksteinMealEntry.category` holds. A `nil` category means the row was
    /// written by a caller that had no rule — a catalog entry, for instance — and
    /// never matches here.
    static func reference(foodName: String, category: String?) -> Reference? {
        guard let category = category else { return nil }
        return references.first {
            $0.foodName == foodName && $0.category.rawValue == category
        }
    }

    /// The nutrition in `grams` of a diet rule, or `nil` when none is documented.
    static func snapshot(for rule: DietRule, grams: Double) -> NutritionSnapshot? {
        reference(for: rule)?.per100g.scaled(toGrams: grams)
    }

    /// The nutrition in `grams` of a stored food name and category.
    static func snapshot(foodName: String, category: String?, grams: Double) -> NutritionSnapshot? {
        reference(foodName: foodName, category: category)?.per100g.scaled(toGrams: grams)
    }
}
