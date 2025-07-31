//
//  CustomFoodManager.swift
//  Eckstein
//
//  Created by Eliad Shahar on 14/07/2025.
//

import Foundation
import CoreData

@MainActor
class CustomFoodManager: ObservableObject {
    static let shared = CustomFoodManager()
    
    @Published var customFoods: [CDEcksteinFood] = []
    private let context = PersistenceController.shared.container.viewContext
    
    private init() {
        fetchCustomFoods()
    }
    
    // MARK: - Fetch Methods
    
    func fetchCustomFoods() {
        let request: NSFetchRequest<CDEcksteinFood> = CDEcksteinFood.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDEcksteinFood.name, ascending: true)]
        
        do {
            customFoods = try context.fetch(request)
        } catch {
            print("Error fetching custom foods: \(error)")
        }
    }
    
    func fetchFoodsByCategory(_ category: String) -> [CDEcksteinFood] {
        let request: NSFetchRequest<CDEcksteinFood> = CDEcksteinFood.fetchRequest()
        request.predicate = NSPredicate(format: "category == %@", category)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDEcksteinFood.name, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching foods by category: \(error)")
            return []
        }
    }
    
    // MARK: - Create Methods
    
    func createCustomFood(name: String, category: DietRule.DietCategory, dailyGrams: Int, isFat: Bool = false) -> CDEcksteinFood? {
        let food = CDEcksteinFood(context: context)
        food.id = UUID()
        food.name = name
        food.category = category.rawValue
        food.dailyGrams = Int32(dailyGrams)
        food.isFat = isFat
        food.createdAt = Date()
        food.isCustom = true
        
        do {
            try context.save()
            fetchCustomFoods()
            return food
        } catch {
            print("Error creating custom food: \(error)")
            return nil
        }
    }
    
    // MARK: - Update Methods
    
    func updateFood(_ food: CDEcksteinFood, name: String? = nil, dailyGrams: Int? = nil, isFat: Bool? = nil) {
        if let name = name {
            food.name = name
        }
        if let dailyGrams = dailyGrams {
            food.dailyGrams = Int32(dailyGrams)
        }
        if let isFat = isFat {
            food.isFat = isFat
        }
        
        do {
            try context.save()
            fetchCustomFoods()
        } catch {
            print("Error updating food: \(error)")
        }
    }
    
    // MARK: - Delete Methods
    
    func deleteFood(_ food: CDEcksteinFood) {
        context.delete(food)
        
        do {
            try context.save()
            fetchCustomFoods()
        } catch {
            print("Error deleting food: \(error)")
        }
    }
    
    // MARK: - Convert to DietRule
    
    func convertToDietRule(_ food: CDEcksteinFood) -> DietRule? {
        guard let categoryStr = food.category,
              let category = DietRule.DietCategory(rawValue: categoryStr) else { return nil }
        
        return DietRule(
            foodName: food.name ?? "Unknown",
            category: category,
            dailyGrams: Int(food.dailyGrams),
            isSnack: category == .snack
        )
    }
    
    // MARK: - Default Foods
    
    func seedDefaultFoodsIfNeeded() {
        let request: NSFetchRequest<CDEcksteinFood> = CDEcksteinFood.fetchRequest()
        
        do {
            let count = try context.count(for: request)
            if count == 0 {
                seedDefaultFoods()
            }
        } catch {
            print("Error checking food count: \(error)")
        }
    }
    
    private func seedDefaultFoods() {
        // Seed protein fat foods
        let proteinFatFoods = [
            ("Fish (Fat)", 240),
            ("Chicken (with skin)", 240),
            ("Beef (Fat)", 240),
            ("Cheese", 560),
            ("Eggs", 400)
        ]
        
        for (name, grams) in proteinFatFoods {
            _ = createCustomFood(name: name, category: .proteinFat, dailyGrams: grams, isFat: true)
        }
        
        // Seed protein non-fat foods
        let proteinNonFatFoods = [
            ("Fish (Non-Fat)", 320),
            ("Chicken (No Skin)", 320),
            ("Turkey", 320),
            ("Tuna (in water)", 320),
            ("Cottage Cheese (Low Fat)", 480)
        ]
        
        for (name, grams) in proteinNonFatFoods {
            _ = createCustomFood(name: name, category: .proteinNonFat, dailyGrams: grams, isFat: false)
        }
        
        // Seed carb foods
        let carbFoods = [
            ("Rice", 250),
            ("Pasta", 200),
            ("Bread", 100),
            ("Potato", 300),
            ("Oatmeal", 80)
        ]
        
        for (name, grams) in carbFoods {
            _ = createCustomFood(name: name, category: .carbs, dailyGrams: grams)
        }
        
        // Seed snack foods
        let snackFoods = [
            ("Approved Snack 1", 100),
            ("Approved Snack 2", 100)
        ]
        
        for (name, grams) in snackFoods {
            _ = createCustomFood(name: name, category: .snack, dailyGrams: grams)
        }
    }
}

