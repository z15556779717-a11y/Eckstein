//
//  ServingSizeCalculator.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation

struct ServingSizeCalculator {
    // Common serving units and their gram equivalents
    static let servingUnits: [String: Double] = [
        "cup": 240,        // 1 cup = 240g (for liquids)
        "tbsp": 15,        // 1 tablespoon = 15g
        "tsp": 5,          // 1 teaspoon = 5g
        "oz": 28.35,       // 1 ounce = 28.35g
        "lb": 453.59,      // 1 pound = 453.59g
        "slice": 28,       // 1 slice (bread) = ~28g
        "piece": 100,      // 1 piece = ~100g (generic)
        "small": 80,       // Small serving
        "medium": 120,     // Medium serving
        "large": 180,      // Large serving
        "scoop": 30,       // 1 scoop (protein powder) = ~30g
        "handful": 30      // 1 handful = ~30g
    ]
    
    static func convertToGrams(amount: Double, unit: String) -> Double {
        if unit == "g" || unit == "grams" {
            return amount
        }
        
        if let conversionFactor = servingUnits[unit.lowercased()] {
            return amount * conversionFactor
        }
        
        // If unit not found, assume it's already in grams
        return amount
    }
    
    static func calculateNutrition(for food: CDFood, servingGrams: Double) -> NutritionInfo {
        let multiplier = servingGrams / 100.0
        
        return NutritionInfo(
            calories: Int(Double(food.caloriesPer100g) * multiplier),
            protein: food.proteinPer100g * multiplier,
            carbs: food.carbsPer100g * multiplier,
            fat: food.fatPer100g * multiplier,
            fiber: food.fiberPer100g * multiplier
        )
    }
    
    static func formatServing(_ amount: Double, unit: String) -> String {
        if amount == floor(amount) {
            return "\(Int(amount)) \(unit)"
        } else {
            return String(format: "%.1f %@", amount, unit)
        }
    }
    
    static func suggestedServings(for category: String?) -> [(amount: Double, unit: String)] {
        guard let category = category else {
            return [(100, "g")]
        }
        
        switch category.lowercased() {
        case "protein":
            return [(100, "g"), (3.5, "oz"), (1, "piece")]
        case "carbs":
            return [(100, "g"), (0.5, "cup"), (1, "slice")]
        case "vegetable", "fruit":
            return [(100, "g"), (1, "cup"), (1, "piece")]
        case "dairy":
            return [(240, "g"), (1, "cup"), (8, "oz")]
        case "fats", "nuts":
            return [(30, "g"), (1, "oz"), (1, "handful")]
        case "supplement":
            return [(30, "g"), (1, "scoop")]
        default:
            return [(100, "g")]
        }
    }
}

struct NutritionInfo {
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    
    var totalMacros: Double {
        protein + carbs + fat
    }
    
    var proteinPercentage: Double {
        guard totalMacros > 0 else { return 0 }
        return (protein / totalMacros) * 100
    }
    
    var carbsPercentage: Double {
        guard totalMacros > 0 else { return 0 }
        return (carbs / totalMacros) * 100
    }
    
    var fatPercentage: Double {
        guard totalMacros > 0 else { return 0 }
        return (fat / totalMacros) * 100
    }
}