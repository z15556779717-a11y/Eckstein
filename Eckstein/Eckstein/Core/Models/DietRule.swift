//
//  DietRule.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation

// Diet rule configuration for Eckstein method
struct DietRule {
    let foodName: String
    let category: DietCategory
    let dailyGrams: Int
    let isSnack: Bool
    
    enum DietCategory: String, CaseIterable {
        case proteinFat = "Protein (Fat)"
        case proteinNonFat = "Protein (Non-Fat)"
        case carbs = "Carbs"
        case snack = "Snack"
        case carbLoad = "Carb Load"
    }
}

// Predefined diet rules based on Eckstein method
struct EcksteinDietRules {
    static let proteinFatRules = [
        DietRule(foodName: "Fish (Fat)", category: .proteinFat, dailyGrams: 240, isSnack: false),
        DietRule(foodName: "Chicken (with skin)", category: .proteinFat, dailyGrams: 240, isSnack: false),
        DietRule(foodName: "Beef (Fat)", category: .proteinFat, dailyGrams: 240, isSnack: false),
        DietRule(foodName: "Cheese", category: .proteinFat, dailyGrams: 560, isSnack: false),
        DietRule(foodName: "Eggs", category: .proteinFat, dailyGrams: 400, isSnack: false) // ~8 eggs
    ]
    
    static let proteinNonFatRules = [
        DietRule(foodName: "Fish (Non-Fat)", category: .proteinNonFat, dailyGrams: 320, isSnack: false),
        DietRule(foodName: "Chicken (No Skin)", category: .proteinNonFat, dailyGrams: 320, isSnack: false),
        DietRule(foodName: "Turkey", category: .proteinNonFat, dailyGrams: 320, isSnack: false),
        DietRule(foodName: "Tuna (in water)", category: .proteinNonFat, dailyGrams: 320, isSnack: false),
        DietRule(foodName: "Cottage Cheese (Low Fat)", category: .proteinNonFat, dailyGrams: 480, isSnack: false)
    ]
    
    static let carbRules = [
        DietRule(foodName: "Rice", category: .carbs, dailyGrams: 250, isSnack: false),
        DietRule(foodName: "Pasta", category: .carbs, dailyGrams: 200, isSnack: false),
        DietRule(foodName: "Bread", category: .carbs, dailyGrams: 100, isSnack: false),
        DietRule(foodName: "Potato", category: .carbs, dailyGrams: 300, isSnack: false),
        DietRule(foodName: "Oatmeal", category: .carbs, dailyGrams: 80, isSnack: false)
    ]
    
    static let snackRules = [
        DietRule(foodName: "Approved Snack 1", category: .snack, dailyGrams: 100, isSnack: true),
        DietRule(foodName: "Approved Snack 2", category: .snack, dailyGrams: 100, isSnack: true)
    ]
    
    static let carbLoadRules = [
        DietRule(foodName: "Sushi", category: .carbLoad, dailyGrams: 500, isSnack: false),
        DietRule(foodName: "Pizza", category: .carbLoad, dailyGrams: 400, isSnack: false),
        DietRule(foodName: "Pasta with Sauce", category: .carbLoad, dailyGrams: 500, isSnack: false),
        DietRule(foodName: "Burrito", category: .carbLoad, dailyGrams: 450, isSnack: false),
        DietRule(foodName: "Chinese Food", category: .carbLoad, dailyGrams: 500, isSnack: false),
        DietRule(foodName: "Pancakes", category: .carbLoad, dailyGrams: 300, isSnack: false),
        DietRule(foodName: "French Toast", category: .carbLoad, dailyGrams: 300, isSnack: false),
        DietRule(foodName: "Burger & Fries", category: .carbLoad, dailyGrams: 400, isSnack: false),
        DietRule(foodName: "Ramen", category: .carbLoad, dailyGrams: 500, isSnack: false),
        DietRule(foodName: "Pad Thai", category: .carbLoad, dailyGrams: 450, isSnack: false)
    ]
    
    static var allRules: [DietRule] {
        proteinFatRules + proteinNonFatRules + carbRules + snackRules + carbLoadRules
    }
}

// Track daily consumption
struct DietMealEntry {
    let id: UUID
    let date: Date
    let mealNumber: Int // 1 or 2
    let proteinFoods: [DietFoodEntry]  // Changed to array for multiple foods
    let carbFoods: [DietFoodEntry]      // Changed to array for multiple foods
    let snacks: [DietFoodEntry]
    
    struct DietFoodEntry {
        let food: DietRule
        let gramsConsumed: Int
        
        var percentageOfDaily: Double {
            Double(gramsConsumed) / Double(food.dailyGrams) * 100
        }
        
        var remainingGrams: Int {
            food.dailyGrams - gramsConsumed
        }
    }
    
    // Calculate carry-over for next meal based on percentage system
    func calculateCarryOver() -> (proteinPercentage: Double, carbPercentage: Double) {
        // Calculate total percentage consumed for each category
        let proteinPercentage = totalPercentage(for: .proteinNonFat) // Works for both fat and non-fat
        let carbPercentage = totalPercentage(for: .carbs)
        
        // Calculate remaining percentage (can be negative if over 100%)
        // Negative values mean meal 1 borrowed from meal 2
        // This represents how much meal 1's consumption affects meal 2's allowance
        let proteinRemaining = 100 - proteinPercentage
        let carbRemaining = 100 - carbPercentage
        
        return (proteinRemaining, carbRemaining)
    }
    
    // Calculate total percentage for a category using unified percentage system
    func totalPercentage(for category: DietRule.DietCategory) -> Double {
        let foods: [DietFoodEntry]
        switch category {
        case .carbs, .carbLoad:
            foods = carbFoods
        case .proteinFat, .proteinNonFat:
            foods = proteinFoods
        case .snack:
            foods = snacks
        }
        
        guard !foods.isEmpty else { return 0 }
        
        // Sum up the percentage contribution from each food
        let totalPercentage = foods.reduce(0.0) { total, entry in
            // Each food contributes: (grams consumed / food's daily grams) * 100
            let foodPercentage = Double(entry.gramsConsumed) / Double(entry.food.dailyGrams) * 100
            return total + foodPercentage
        }
        
        return totalPercentage
    }
}