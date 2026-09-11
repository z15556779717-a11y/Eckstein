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
    
    /// Creates a diet-rule food.
    ///
    /// `source` defaults to `.manual` because the only other caller is the user's
    /// own "add custom food" screen. `seedDefaultFoodsIfNeeded` passes `.seed`
    /// instead, so a shipped default stays distinguishable from a food the user
    /// typed.
    ///
    /// Per-100 g values are filled in from `DietRuleNutrition` when the name and
    /// category have a documented value, and left `nil` otherwise. Nothing is
    /// invented for a food the fixture does not know — see DietRuleNutrition.swift
    /// for the provenance of each entry.
    @discardableResult
    func createCustomFood(
        name: String,
        category: DietRule.DietCategory,
        dailyGrams: Int,
        isFat: Bool = false,
        source: NutritionSource = .manual
    ) -> CDEcksteinFood? {
        let food = CDEcksteinFood(context: context)
        food.id = UUID()
        food.name = name
        food.category = category.rawValue
        food.dailyGrams = Int32(dailyGrams)
        food.isFat = isFat
        food.createdAt = Date()
        food.updatedAt = Date()
        food.isCustom = true
        food.nutritionSource = source

        if let reference = DietRuleNutrition.reference(foodName: name, category: category.rawValue) {
            NutritionCatalogSeed.apply(reference.per100g, to: food)
        }

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
    
    /// Inserts any diet-rule default the store does not hold yet.
    ///
    /// This used to seed only when the whole `CDEcksteinFood` table was empty.
    /// That guard stopped holding once `NutritionCatalogSeed` began populating
    /// the same table from the shipped `FoodData` templates, so a store could end
    /// up with the catalog and no diet rules at all. The check is per food now,
    /// which is idempotent for the same reason, and it also brings a store seeded
    /// before the nutrition values existed up to date.
    func seedDefaultFoodsIfNeeded() {
        do {
            let existing = try context.fetch(CDEcksteinFood.fetchRequest()).map {
                ($0.name ?? "", $0.category ?? "")
            }
            seedDefaultFoods(skipping: existing)
        } catch {
            print("Error checking existing foods: \(error)")
        }
    }
    
    private func seedDefaultFoods(skipping existing: [(name: String, category: String)]) {
        /// Whether the store already holds this food, keyed on name and category —
        /// the pair the diet pickers identify a food by.
        func isKnown(_ name: String, _ category: DietRule.DietCategory) -> Bool {
            existing.contains { $0.name == name && $0.category == category.rawValue }
        }

        // Seed protein fat foods
        let proteinFatFoods = [
            ("Fish (Fat)", 240),
            ("Chicken (with skin)", 240),
            ("Beef (Fat)", 240),
            ("Cheese", 560),
            ("Eggs", 400)
        ]
        
        for (name, grams) in proteinFatFoods where !isKnown(name, .proteinFat) {
            _ = createCustomFood(name: name, category: .proteinFat, dailyGrams: grams, isFat: true, source: .seed)
        }
        
        // Seed protein non-fat foods
        let proteinNonFatFoods = [
            ("Fish (Non-Fat)", 320),
            ("Chicken (No Skin)", 320),
            ("Turkey", 320),
            ("Tuna (in water)", 320),
            ("Cottage Cheese (Low Fat)", 480)
        ]
        
        for (name, grams) in proteinNonFatFoods where !isKnown(name, .proteinNonFat) {
            _ = createCustomFood(name: name, category: .proteinNonFat, dailyGrams: grams, isFat: false, source: .seed)
        }
        
        // Seed carb foods
        let carbFoods = [
            ("Rice", 250),
            ("Pasta", 200),
            ("Bread", 100),
            ("Potato", 300),
            ("Oatmeal", 80)
        ]
        
        for (name, grams) in carbFoods where !isKnown(name, .carbs) {
            _ = createCustomFood(name: name, category: .carbs, dailyGrams: grams, source: .seed)
        }
        
        // Seed snack foods
        let snackFoods = [
            ("Approved Snack 1", 100),
            ("Approved Snack 2", 100)
        ]
        
        for (name, grams) in snackFoods where !isKnown(name, .snack) {
            _ = createCustomFood(name: name, category: .snack, dailyGrams: grams, source: .seed)
        }
    }
}

