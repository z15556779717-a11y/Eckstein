//
//  DietRepository.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import CoreData
import Combine

class DietRepository: ObservableObject {
    private let context: NSManagedObjectContext
    @Published var meals: [CDMeal] = []
    @Published var foods: [CDFood] = []
    @Published var todayMeals: [CDMeal] = []
    @Published var calorieBankBalance: Int = 0
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        seedFoodsIfNeeded()
        fetchTodayMeals()
        fetchFoods()
        updateCalorieBankBalance()
    }
    
    func fetchTodayMeals() {
        let request: NSFetchRequest<CDMeal> = CDMeal.fetchRequest()
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDMeal.date, ascending: true)]
        
        do {
            todayMeals = try context.fetch(request)
        } catch {
            print("Error fetching today's meals: \(error)")
        }
    }
    
    func fetchMeals() {
        let request: NSFetchRequest<CDMeal> = CDMeal.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDMeal.date, ascending: false)]
        
        do {
            meals = try context.fetch(request)
        } catch {
            print("Error fetching meals: \(error)")
        }
    }
    
    func fetchFoods() {
        let request: NSFetchRequest<CDFood> = CDFood.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDFood.name, ascending: true)]
        
        do {
            foods = try context.fetch(request)
        } catch {
            print("Error fetching foods: \(error)")
        }
    }
    
    func fetchMeals(from startDate: Date, to endDate: Date) -> [CDMeal] {
        let request: NSFetchRequest<CDMeal> = CDMeal.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date <= %@", startDate as NSDate, endDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDMeal.date, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching meals for date range: \(error)")
            return []
        }
    }
    
    func createMeal(mealType: String, date: Date) -> CDMeal {
        let meal = CDMeal(context: context)
        meal.id = UUID()
        meal.mealType = mealType
        meal.date = date
        meal.syncStatus = "pending"
        save()
        fetchTodayMeals()
        return meal
    }
    
    func addFoodToMeal(_ meal: CDMeal, food: CDFood, quantityGrams: Double) {
        let mealItem = CDMealItem(context: context)
        mealItem.id = UUID()
        mealItem.quantityGrams = quantityGrams
        mealItem.food = food
        mealItem.meal = meal
        save()
        fetchTodayMeals()
    }
    
    func createFood(name: String, caloriesPer100g: Int32, proteinPer100g: Double, carbsPer100g: Double, fatPer100g: Double) -> CDFood {
        let food = CDFood(context: context)
        food.id = UUID()
        food.name = name
        food.caloriesPer100g = caloriesPer100g
        food.proteinPer100g = proteinPer100g
        food.carbsPer100g = carbsPer100g
        food.fatPer100g = fatPer100g
        food.isCustom = true
        save()
        fetchFoods()
        return food
    }
    
    func delete(_ object: NSManagedObject) {
        context.delete(object)
        save()
        fetchTodayMeals()
        fetchFoods()
    }
    
    private func seedFoodsIfNeeded() {
        FoodData.seedFoodsIfNeeded(context: context)
    }
    
    private func updateCalorieBankBalance() {
        calorieBankBalance = CalorieBankManager.shared.currentBalance
    }
    
    func calculateTodayCalories() -> Int {
        var totalCalories = 0
        
        for meal in todayMeals {
            if let items = meal.items as? Set<CDMealItem> {
                for item in items {
                    if let food = item.food {
                        let nutrition = ServingSizeCalculator.calculateNutrition(
                            for: food,
                            servingGrams: item.quantityGrams
                        )
                        totalCalories += nutrition.calories
                    }
                }
            }
        }
        
        return totalCalories
    }
    
    private func save() {
        do {
            try context.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
}