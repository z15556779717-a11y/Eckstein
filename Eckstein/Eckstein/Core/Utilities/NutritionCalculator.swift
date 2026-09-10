//
//  NutritionCalculator.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation

/// **Partly deprecated in phase 2.**
///
/// The goal/energy-expenditure helpers (`calculateDailyCalorieNeeds`,
/// `MacroTargets`, `MealTiming`, `NutritionGoal`) are still general-purpose and
/// remain in use. The meal-macro helpers — `calculateNutritionForMeals(_:)` and
/// anything else that takes `CDMeal` / `CDMealItem` / `CDFood` — belong to the
/// orphaned entity set. The official equivalents operate on plain values:
/// `NutritionAggregator` and `NutritionSnapshot`. See NUTRITION_MIGRATION_PLAN.md §11.
struct NutritionCalculator {
    // Calculate daily calorie needs based on user stats and activity level
    static func calculateDailyCalorieNeeds(
        weight: Double, // in kg
        height: Double, // in cm
        age: Int,
        gender: Gender,
        activityLevel: ActivityLevel
    ) -> Int {
        // Basal Metabolic Rate (BMR) using Mifflin-St Jeor equation
        let bmr: Double
        
        switch gender {
        case .male:
            bmr = (10 * weight) + (6.25 * height) - (5 * Double(age)) + 5
        case .female:
            bmr = (10 * weight) + (6.25 * height) - (5 * Double(age)) - 161
        }
        
        // Total Daily Energy Expenditure (TDEE)
        let tdee = bmr * activityLevel.multiplier
        
        return Int(tdee)
    }
    
    // Calculate macro targets based on goals
    static func calculateMacroTargets(
        dailyCalories: Int,
        goal: NutritionGoal
    ) -> MacroTargets {
        let proteinRatio: Double
        let carbRatio: Double
        let fatRatio: Double
        
        switch goal {
        case .loseFat:
            proteinRatio = 0.35
            carbRatio = 0.35
            fatRatio = 0.30
        case .buildMuscle:
            proteinRatio = 0.30
            carbRatio = 0.45
            fatRatio = 0.25
        case .maintain:
            proteinRatio = 0.25
            carbRatio = 0.45
            fatRatio = 0.30
        case .custom(let p, let c, let f):
            proteinRatio = p
            carbRatio = c
            fatRatio = f
        }
        
        // Calculate grams from ratios
        // Protein: 4 cal/g, Carbs: 4 cal/g, Fat: 9 cal/g
        let proteinCalories = Double(dailyCalories) * proteinRatio
        let carbCalories = Double(dailyCalories) * carbRatio
        let fatCalories = Double(dailyCalories) * fatRatio
        
        return MacroTargets(
            protein: Int(proteinCalories / 4),
            carbs: Int(carbCalories / 4),
            fat: Int(fatCalories / 9),
            calories: dailyCalories
        )
    }
    
    // Calculate nutrition for a collection of meals
    static func calculateNutritionForMeals(_ meals: [CDMeal]) -> NutritionInfo {
        var totalCalories = 0
        var totalProtein = 0.0
        var totalCarbs = 0.0
        var totalFat = 0.0
        var totalFiber = 0.0
        
        for meal in meals {
            if let items = meal.items as? Set<CDMealItem> {
                for item in items {
                    if let food = item.food {
                        let nutrition = ServingSizeCalculator.calculateNutrition(
                            for: food,
                            servingGrams: item.quantityGrams
                        )
                        totalCalories += nutrition.calories
                        totalProtein += nutrition.protein
                        totalCarbs += nutrition.carbs
                        totalFat += nutrition.fat
                        totalFiber += nutrition.fiber
                    }
                }
            }
        }
        
        return NutritionInfo(
            calories: totalCalories,
            protein: totalProtein,
            carbs: totalCarbs,
            fat: totalFat,
            fiber: totalFiber
        )
    }
    
    // Calculate meal timing recommendations
    static func calculateMealTiming(
        wakeTime: Date,
        sleepTime: Date,
        mealCount: Int
    ) -> [MealTiming] {
        let calendar = Calendar.current
        var timings: [MealTiming] = []
        
        // Calculate awake hours
        let awakeHours = calendar.dateComponents([.hour], from: wakeTime, to: sleepTime).hour ?? 16
        let intervalHours = Double(awakeHours) / Double(mealCount + 1)
        
        for i in 1...mealCount {
            let mealTime = calendar.date(
                byAdding: .hour,
                value: Int(intervalHours * Double(i)),
                to: wakeTime
            ) ?? wakeTime
            
            let mealType: String
            switch i {
            case 1:
                mealType = "breakfast"
            case mealCount where mealCount >= 3:
                mealType = "dinner"
            case 2 where mealCount == 3:
                mealType = "lunch"
            default:
                mealType = "snack"
            }
            
            timings.append(MealTiming(
                mealType: mealType,
                recommendedTime: mealTime
            ))
        }
        
        return timings
    }
    
    // Calculate nutrient density score
    static func calculateNutrientDensityScore(nutrition: NutritionInfo) -> Double {
        guard nutrition.calories > 0 else { return 0 }
        
        // Simple scoring based on protein and fiber per calorie
        let proteinPerCalorie = nutrition.protein / Double(nutrition.calories) * 1000
        let fiberPerCalorie = nutrition.fiber / Double(nutrition.calories) * 1000
        
        // Score from 0-100
        let proteinScore = min(proteinPerCalorie * 50, 50)
        let fiberScore = min(fiberPerCalorie * 20, 50)
        
        return proteinScore + fiberScore
    }
}

// MARK: - Supporting Types

enum Gender {
    case male
    case female
}

enum ActivityLevel {
    case sedentary
    case lightlyActive
    case moderatelyActive
    case veryActive
    case extraActive
    
    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .lightlyActive: return 1.375
        case .moderatelyActive: return 1.55
        case .veryActive: return 1.725
        case .extraActive: return 1.9
        }
    }
}

enum NutritionGoal {
    case loseFat
    case buildMuscle
    case maintain
    case custom(protein: Double, carbs: Double, fat: Double)
}

struct MacroTargets {
    let protein: Int // grams
    let carbs: Int // grams
    let fat: Int // grams
    let calories: Int
}

struct MealTiming {
    let mealType: String
    let recommendedTime: Date
}