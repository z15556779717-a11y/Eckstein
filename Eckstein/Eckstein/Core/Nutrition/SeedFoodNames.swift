//
//  SeedFoodNames.swift
//  Eckstein
//
//  What the app's own foods are called in the user's language.
//
//  Every food the app ships is stored under its English name, and that
//  name is an *identity*, not a label: the picker matches a food by name,
//  `DietRuleNutrition` looks its per-100 g values up by name, a logged meal
//  entry keeps a copy of the name it was logged under, and the sync payload
//  keys on it. Renaming the column would break every one of those lookups
//  and rewrite the user's own history, so the stored name stays exactly
//  where it is and the translation happens on the way to the screen.
//
//  This is a lookup, not a translator: a name with no table entry falls back
//  to the English one, nothing is guessed, and a name the user typed or a
//  scanned product's label is never touched.
//

import Foundation

enum SeedFoodNames {

    /// The name to show for a food row.
    ///
    /// - Parameters:
    ///   - name: the stored name, English for every food the app ships.
    ///   - source: the row's provenance. `nil` — a row written before the
    ///     column existed — counts as "not ours" and is left alone, because
    ///     a guess is the one thing here that cannot be undone.
    static func displayName(for name: String?, source: String?) -> String {
        let stored = name ?? ""
        guard NutritionSource(storedValue: source) == .seed,
              let key = keys[stored] else { return stored }
        return resolve(key, fallback: stored)
    }

    /// The label to show for a catalog food's `foodCategory`.
    ///
    /// The same rule as the name: only a shipped row is renamed, so a scanned
    /// product keeps the aisle its own database put it in.
    static func categoryName(for category: String?, source: String?) -> String {
        let stored = category ?? ""
        guard NutritionSource(storedValue: source) == .seed,
              let key = categoryKeys[stored] else { return stored }
        return resolve(key, fallback: stored)
    }

    /// The table's text for `key`, or `fallback` when the table has no entry.
    ///
    /// `String.localized` hands the key back when it finds nothing, so the miss
    /// is detectable — and the English name, not `food_seed_…`, is what a
    /// language this build has not been translated into should show.
    private static func resolve(_ key: String, fallback: String) -> String {
        let translated = key.localized
        return translated == key ? fallback : translated
    }

    /// Stored name -> string-table key.
    ///
    /// Spelled out rather than derived by slugging the name at runtime: a slug
    /// function would have to guess at punctuation twice, once in the lookup
    /// and once when the table was written.
    private static let keys: [String: String] = [
        "Almond Milk (Unsweetened)": "food_seed_almond_milk_unsweetened",
        "Almonds": "food_seed_almonds",
        "Apple": "food_seed_apple",
        "Avocado": "food_seed_avocado",
        "Banana": "food_seed_banana",
        "Bell Peppers": "food_seed_bell_peppers",
        "Blueberries": "food_seed_blueberries",
        "Broccoli (Cooked)": "food_seed_broccoli_cooked",
        "Brown Rice (Cooked)": "food_seed_brown_rice_cooked",
        "Carrots (Raw)": "food_seed_carrots_raw",
        "Chicken Breast (Cooked)": "food_seed_chicken_breast_cooked",
        "Cottage Cheese": "food_seed_cottage_cheese",
        "Eggs": "food_seed_eggs",
        "Greek Yogurt (Plain)": "food_seed_greek_yogurt_plain",
        "Lean Ground Beef (Cooked)": "food_seed_lean_ground_beef_cooked",
        "Milk (Whole)": "food_seed_milk_whole",
        "Oatmeal (Dry)": "food_seed_oatmeal_dry",
        "Olive Oil": "food_seed_olive_oil",
        "Orange": "food_seed_orange",
        "Pasta (Cooked)": "food_seed_pasta_cooked",
        "Peanut Butter": "food_seed_peanut_butter",
        "Protein Bar - Quest": "food_seed_protein_bar_quest",
        "Protein Powder - Whey": "food_seed_protein_powder_whey",
        "Quinoa (Cooked)": "food_seed_quinoa_cooked",
        "Salmon (Cooked)": "food_seed_salmon_cooked",
        "Spinach (Raw)": "food_seed_spinach_raw",
        "Strawberries": "food_seed_strawberries",
        "Sweet Potato (Cooked)": "food_seed_sweet_potato_cooked",
        "Tofu": "food_seed_tofu",
        "Tomatoes": "food_seed_tomatoes",
        "Tuna (Canned in Water)": "food_seed_tuna_canned_in_water",
        "Walnuts": "food_seed_walnuts",
        "White Rice (Cooked)": "food_seed_white_rice_cooked",
        "Whole Wheat Bread": "food_seed_whole_wheat_bread",
        "Approved Snack 1": "food_seed_approved_snack_1",
        "Approved Snack 2": "food_seed_approved_snack_2",
        "Beef (Fat)": "food_seed_beef_fat",
        "Bread": "food_seed_bread",
        "Burger & Fries": "food_seed_burger_and_fries",
        "Burrito": "food_seed_burrito",
        "Cheese": "food_seed_cheese",
        "Chicken (No Skin)": "food_seed_chicken_no_skin",
        "Chicken (with skin)": "food_seed_chicken_with_skin",
        "Chinese Food": "food_seed_chinese_food",
        "Cottage Cheese (Low Fat)": "food_seed_cottage_cheese_low_fat",
        "Fish (Fat)": "food_seed_fish_fat",
        "Fish (Non-Fat)": "food_seed_fish_non_fat",
        "French Toast": "food_seed_french_toast",
        "Oatmeal": "food_seed_oatmeal",
        "Pad Thai": "food_seed_pad_thai",
        "Pancakes": "food_seed_pancakes",
        "Pasta": "food_seed_pasta",
        "Pasta with Sauce": "food_seed_pasta_with_sauce",
        "Pizza": "food_seed_pizza",
        "Potato": "food_seed_potato",
        "Ramen": "food_seed_ramen",
        "Rice": "food_seed_rice",
        "Sushi": "food_seed_sushi",
        "Tuna (in water)": "food_seed_tuna_in_water",
        "Turkey": "food_seed_turkey",
    ]

    /// Stored `foodCategory` -> string-table key.
    private static let categoryKeys: [String: String] = [
        "Carbs": "food_category_carbs",
        "Dairy": "food_category_dairy",
        "Fats": "food_category_fats",
        "Fruit": "food_category_fruit",
        "Nuts": "food_category_nuts",
        "Protein": "food_category_protein",
        "Snack": "food_category_snack",
        "Supplement": "food_category_supplement",
        "Vegetable": "food_category_vegetable",
    ]
}

// MARK: - Bringing it to the types that get displayed

extension CDEcksteinFood {
    /// The name to show a user. See `SeedFoodNames`.
    var displayName: String { SeedFoodNames.displayName(for: name, source: source) }

    /// The category label to show a user. See `SeedFoodNames`.
    var displayCategory: String {
        SeedFoodNames.categoryName(for: foodCategory, source: source)
    }
}

extension CDEcksteinMealEntry {
    /// The name to show a user for a logged food.
    ///
    /// The entry keeps its own copy of the name it was logged under, so the
    /// provenance is read from the food it points at — which is `nil` once
    /// that food has been deleted, and then the name shows as it was logged.
    var displayFoodName: String {
        SeedFoodNames.displayName(for: foodName, source: food?.source)
    }
}

