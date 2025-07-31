//
//  FoodData.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation
import CoreData

struct FoodTemplate {
    let name: String
    let category: String
    let barcode: String?
    let caloriesPer100g: Int
    let proteinPer100g: Double
    let carbsPer100g: Double
    let fatPer100g: Double
    let fiberPer100g: Double?
    let brand: String?
    let servingSize: Double? // in grams
    let servingUnit: String?
}

struct FoodData {
    static let foods: [FoodTemplate] = [
        // Protein Sources
        FoodTemplate(name: "Chicken Breast (Cooked)", category: "Protein", barcode: nil, caloriesPer100g: 165, proteinPer100g: 31.0, carbsPer100g: 0, fatPer100g: 3.6, fiberPer100g: 0, brand: nil, servingSize: 100, servingUnit: "g"),
        FoodTemplate(name: "Salmon (Cooked)", category: "Protein", barcode: nil, caloriesPer100g: 208, proteinPer100g: 20.4, carbsPer100g: 0, fatPer100g: 13.4, fiberPer100g: 0, brand: nil, servingSize: 100, servingUnit: "g"),
        FoodTemplate(name: "Eggs", category: "Protein", barcode: nil, caloriesPer100g: 155, proteinPer100g: 13.0, carbsPer100g: 1.1, fatPer100g: 11.0, fiberPer100g: 0, brand: nil, servingSize: 50, servingUnit: "g (1 large)"),
        FoodTemplate(name: "Greek Yogurt (Plain)", category: "Dairy", barcode: nil, caloriesPer100g: 59, proteinPer100g: 10.0, carbsPer100g: 3.6, fatPer100g: 0.4, fiberPer100g: 0, brand: nil, servingSize: 150, servingUnit: "g"),
        FoodTemplate(name: "Cottage Cheese", category: "Dairy", barcode: nil, caloriesPer100g: 98, proteinPer100g: 11.1, carbsPer100g: 3.4, fatPer100g: 4.3, fiberPer100g: 0, brand: nil, servingSize: 113, servingUnit: "g"),
        FoodTemplate(name: "Tuna (Canned in Water)", category: "Protein", barcode: nil, caloriesPer100g: 116, proteinPer100g: 25.5, carbsPer100g: 0, fatPer100g: 0.8, fiberPer100g: 0, brand: nil, servingSize: 85, servingUnit: "g"),
        FoodTemplate(name: "Lean Ground Beef (Cooked)", category: "Protein", barcode: nil, caloriesPer100g: 250, proteinPer100g: 26.0, carbsPer100g: 0, fatPer100g: 15.0, fiberPer100g: 0, brand: nil, servingSize: 100, servingUnit: "g"),
        FoodTemplate(name: "Tofu", category: "Protein", barcode: nil, caloriesPer100g: 76, proteinPer100g: 8.0, carbsPer100g: 1.9, fatPer100g: 4.8, fiberPer100g: 0.3, brand: nil, servingSize: 100, servingUnit: "g"),
        
        // Carbohydrates
        FoodTemplate(name: "White Rice (Cooked)", category: "Carbs", barcode: nil, caloriesPer100g: 130, proteinPer100g: 2.7, carbsPer100g: 28.2, fatPer100g: 0.3, fiberPer100g: 0.4, brand: nil, servingSize: 150, servingUnit: "g"),
        FoodTemplate(name: "Brown Rice (Cooked)", category: "Carbs", barcode: nil, caloriesPer100g: 111, proteinPer100g: 2.6, carbsPer100g: 23.0, fatPer100g: 0.9, fiberPer100g: 1.8, brand: nil, servingSize: 150, servingUnit: "g"),
        FoodTemplate(name: "Oatmeal (Dry)", category: "Carbs", barcode: nil, caloriesPer100g: 389, proteinPer100g: 16.9, carbsPer100g: 66.3, fatPer100g: 6.9, fiberPer100g: 10.6, brand: nil, servingSize: 40, servingUnit: "g"),
        FoodTemplate(name: "Whole Wheat Bread", category: "Carbs", barcode: nil, caloriesPer100g: 247, proteinPer100g: 9.0, carbsPer100g: 41.0, fatPer100g: 3.4, fiberPer100g: 6.0, brand: nil, servingSize: 28, servingUnit: "g (1 slice)"),
        FoodTemplate(name: "Sweet Potato (Cooked)", category: "Carbs", barcode: nil, caloriesPer100g: 86, proteinPer100g: 1.6, carbsPer100g: 20.1, fatPer100g: 0.1, fiberPer100g: 3.0, brand: nil, servingSize: 130, servingUnit: "g"),
        FoodTemplate(name: "Quinoa (Cooked)", category: "Carbs", barcode: nil, caloriesPer100g: 120, proteinPer100g: 4.4, carbsPer100g: 21.3, fatPer100g: 1.9, fiberPer100g: 2.8, brand: nil, servingSize: 185, servingUnit: "g"),
        FoodTemplate(name: "Pasta (Cooked)", category: "Carbs", barcode: nil, caloriesPer100g: 131, proteinPer100g: 5.0, carbsPer100g: 25.0, fatPer100g: 1.1, fiberPer100g: 1.8, brand: nil, servingSize: 140, servingUnit: "g"),
        
        // Fruits
        FoodTemplate(name: "Apple", category: "Fruit", barcode: nil, caloriesPer100g: 52, proteinPer100g: 0.3, carbsPer100g: 14.0, fatPer100g: 0.2, fiberPer100g: 2.4, brand: nil, servingSize: 182, servingUnit: "g (1 medium)"),
        FoodTemplate(name: "Banana", category: "Fruit", barcode: nil, caloriesPer100g: 89, proteinPer100g: 1.1, carbsPer100g: 23.0, fatPer100g: 0.3, fiberPer100g: 2.6, brand: nil, servingSize: 118, servingUnit: "g (1 medium)"),
        FoodTemplate(name: "Orange", category: "Fruit", barcode: nil, caloriesPer100g: 47, proteinPer100g: 0.9, carbsPer100g: 12.0, fatPer100g: 0.1, fiberPer100g: 2.4, brand: nil, servingSize: 154, servingUnit: "g (1 medium)"),
        FoodTemplate(name: "Strawberries", category: "Fruit", barcode: nil, caloriesPer100g: 32, proteinPer100g: 0.7, carbsPer100g: 7.7, fatPer100g: 0.3, fiberPer100g: 2.0, brand: nil, servingSize: 152, servingUnit: "g (1 cup)"),
        FoodTemplate(name: "Blueberries", category: "Fruit", barcode: nil, caloriesPer100g: 57, proteinPer100g: 0.7, carbsPer100g: 14.5, fatPer100g: 0.3, fiberPer100g: 2.4, brand: nil, servingSize: 148, servingUnit: "g (1 cup)"),
        
        // Vegetables
        FoodTemplate(name: "Broccoli (Cooked)", category: "Vegetable", barcode: nil, caloriesPer100g: 35, proteinPer100g: 2.4, carbsPer100g: 7.2, fatPer100g: 0.4, fiberPer100g: 3.3, brand: nil, servingSize: 156, servingUnit: "g (1 cup)"),
        FoodTemplate(name: "Spinach (Raw)", category: "Vegetable", barcode: nil, caloriesPer100g: 23, proteinPer100g: 2.9, carbsPer100g: 3.6, fatPer100g: 0.4, fiberPer100g: 2.2, brand: nil, servingSize: 30, servingUnit: "g (1 cup)"),
        FoodTemplate(name: "Carrots (Raw)", category: "Vegetable", barcode: nil, caloriesPer100g: 41, proteinPer100g: 0.9, carbsPer100g: 10.0, fatPer100g: 0.2, fiberPer100g: 2.8, brand: nil, servingSize: 128, servingUnit: "g (1 cup)"),
        FoodTemplate(name: "Bell Peppers", category: "Vegetable", barcode: nil, caloriesPer100g: 26, proteinPer100g: 1.0, carbsPer100g: 6.0, fatPer100g: 0.3, fiberPer100g: 2.1, brand: nil, servingSize: 119, servingUnit: "g (1 medium)"),
        FoodTemplate(name: "Tomatoes", category: "Vegetable", barcode: nil, caloriesPer100g: 18, proteinPer100g: 0.9, carbsPer100g: 3.9, fatPer100g: 0.2, fiberPer100g: 1.2, brand: nil, servingSize: 123, servingUnit: "g (1 medium)"),
        
        // Fats & Oils
        FoodTemplate(name: "Olive Oil", category: "Fats", barcode: nil, caloriesPer100g: 884, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 100.0, fiberPer100g: 0, brand: nil, servingSize: 14, servingUnit: "g (1 tbsp)"),
        FoodTemplate(name: "Avocado", category: "Fats", barcode: nil, caloriesPer100g: 160, proteinPer100g: 2.0, carbsPer100g: 9.0, fatPer100g: 15.0, fiberPer100g: 7.0, brand: nil, servingSize: 100, servingUnit: "g (½ avocado)"),
        FoodTemplate(name: "Almonds", category: "Nuts", barcode: nil, caloriesPer100g: 579, proteinPer100g: 21.2, carbsPer100g: 21.6, fatPer100g: 49.9, fiberPer100g: 12.5, brand: nil, servingSize: 28, servingUnit: "g (1 oz)"),
        FoodTemplate(name: "Walnuts", category: "Nuts", barcode: nil, caloriesPer100g: 654, proteinPer100g: 15.2, carbsPer100g: 13.7, fatPer100g: 65.2, fiberPer100g: 6.7, brand: nil, servingSize: 28, servingUnit: "g (1 oz)"),
        FoodTemplate(name: "Peanut Butter", category: "Nuts", barcode: nil, caloriesPer100g: 588, proteinPer100g: 25.0, carbsPer100g: 20.0, fatPer100g: 50.0, fiberPer100g: 6.0, brand: nil, servingSize: 32, servingUnit: "g (2 tbsp)"),
        
        // Common Packaged Foods (with example barcodes)
        FoodTemplate(name: "Protein Bar - Quest", category: "Snack", barcode: "888849000456", caloriesPer100g: 380, proteinPer100g: 33.0, carbsPer100g: 36.0, fatPer100g: 15.0, fiberPer100g: 25.0, brand: "Quest", servingSize: 60, servingUnit: "g (1 bar)"),
        FoodTemplate(name: "Protein Powder - Whey", category: "Supplement", barcode: "748927028737", caloriesPer100g: 400, proteinPer100g: 80.0, carbsPer100g: 10.0, fatPer100g: 6.0, fiberPer100g: 0, brand: "ON", servingSize: 30, servingUnit: "g (1 scoop)"),
        FoodTemplate(name: "Milk (Whole)", category: "Dairy", barcode: "070470003146", caloriesPer100g: 61, proteinPer100g: 3.2, carbsPer100g: 4.8, fatPer100g: 3.3, fiberPer100g: 0, brand: nil, servingSize: 244, servingUnit: "g (1 cup)"),
        FoodTemplate(name: "Almond Milk (Unsweetened)", category: "Dairy", barcode: "036632026279", caloriesPer100g: 17, proteinPer100g: 0.7, carbsPer100g: 0.6, fatPer100g: 1.5, fiberPer100g: 0.5, brand: "Almond Breeze", servingSize: 240, servingUnit: "g (1 cup)")
    ]
    
    static func seedFoodsIfNeeded(context: NSManagedObjectContext) {
        let request: NSFetchRequest<CDFood> = CDFood.fetchRequest()
        request.fetchLimit = 1
        
        do {
            let count = try context.count(for: request)
            if count == 0 {
                for template in foods {
                    let food = CDFood(context: context)
                    food.id = UUID()
                    food.name = template.name
                    food.category = template.category
                    food.barcode = template.barcode
                    food.caloriesPer100g = Int32(template.caloriesPer100g)
                    food.proteinPer100g = template.proteinPer100g
                    food.carbsPer100g = template.carbsPer100g
                    food.fatPer100g = template.fatPer100g
                    food.fiberPer100g = template.fiberPer100g ?? 0
                    food.brand = template.brand
                    food.servingSize = template.servingSize ?? 100
                    food.servingUnit = template.servingUnit ?? "g"
                    food.isCustom = false
                    food.isVerified = true
                }
                try context.save()
            }
        } catch {
            print("Error seeding foods: \(error)")
        }
    }
}