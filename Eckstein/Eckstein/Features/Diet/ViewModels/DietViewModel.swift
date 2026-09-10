//
//  DietViewModel.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation
import Combine
import CoreData

/// **Deprecated in phase 2.**
///
/// Drives the orphaned `CDFood` / `CDMeal` / `CDMealItem` view suite rooted at
/// `DietDashboardView`, which has no external caller. No user data lives in those
/// entities and the live Diet tab writes through `EcksteinDietViewModel` instead.
/// The official read/write path is `NutritionService`; the official aggregation
/// is `NutritionAggregator`. Nothing here is deleted in phase 2 — the types stay
/// so the frozen views still compile. See NUTRITION_MIGRATION_PLAN.md §11.
@MainActor
class DietViewModel: ObservableObject {
    @Published var todayMeals: [CDMeal] = []
    @Published var todayCalories: Int = 0
    @Published var todayProtein: Double = 0
    @Published var todayCarbs: Double = 0
    @Published var todayFat: Double = 0
    @Published var calorieBankBalance: Int = 0
    @Published var todayDeposit: Int = 0
    @Published var isLoading = false
    @Published var error: Error?
    @Published var searchResults: [CDFood] = []
    
    // Daily Goals (from UserDefaults)
    @Published var dailyCalorieGoal: Int = UserDefaults.standard.integer(forKey: "dailyCalorieGoal") == 0 ? 2000 : UserDefaults.standard.integer(forKey: "dailyCalorieGoal")
    @Published var dailyProteinGoal: Int = UserDefaults.standard.integer(forKey: "dailyProteinGoal") == 0 ? 150 : UserDefaults.standard.integer(forKey: "dailyProteinGoal")
    @Published var dailyCarbsGoal: Int = UserDefaults.standard.integer(forKey: "dailyCarbsGoal") == 0 ? 250 : UserDefaults.standard.integer(forKey: "dailyCarbsGoal")
    @Published var dailyFatGoal: Int = UserDefaults.standard.integer(forKey: "dailyFatGoal") == 0 ? 65 : UserDefaults.standard.integer(forKey: "dailyFatGoal")
    
    let repository: DietRepository
    let persistenceController = PersistenceController.shared
    private var cancellables = Set<AnyCancellable>()
    
    init(repository: DietRepository? = nil) {
        let context = persistenceController.container.viewContext
        self.repository = repository ?? DietRepository(context: context)
        setupBindings()
        refreshData()
    }
    
    private func setupBindings() {
        repository.$todayMeals
            .sink { [weak self] meals in
                self?.todayMeals = meals
                self?.calculateDailySummary()
            }
            .store(in: &cancellables)
        
        repository.$calorieBankBalance
            .sink { [weak self] balance in
                self?.calorieBankBalance = balance
            }
            .store(in: &cancellables)
        
        CalorieBankManager.shared.$currentBalance
            .sink { [weak self] balance in
                self?.calorieBankBalance = balance
            }
            .store(in: &cancellables)
    }
    
    func refreshData() {
        repository.fetchTodayMeals()
        repository.fetchFoods()
        calculateDailySummary()
        updateCalorieBankInfo()
    }
    
    func getMeals(for mealType: MealType) -> [CDMeal] {
        todayMeals.filter { $0.mealType == mealType.rawValue }
    }
    
    func createMeal(type: String) -> CDMeal {
        repository.createMeal(mealType: type, date: Date())
    }
    
    func addFoodToMeal(_ meal: CDMeal, food: CDFood, quantityGrams: Double) {
        repository.addFoodToMeal(meal, food: food, quantityGrams: quantityGrams)
        // Calorie bank updates will be handled by end-of-day processing
    }
    
    func removeMealItem(_ item: CDMealItem) {
        repository.delete(item)
    }
    
    func searchFoods(query: String) {
        let request: NSFetchRequest<CDFood> = CDFood.fetchRequest()
        request.predicate = NSPredicate(format: "name CONTAINS[cd] %@", query)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CDFood.isFavorite, ascending: false),
            NSSortDescriptor(keyPath: \CDFood.lastUsed, ascending: false),
            NSSortDescriptor(keyPath: \CDFood.name, ascending: true)
        ]
        
        do {
            searchResults = try persistenceController.container.viewContext.fetch(request)
        } catch {
            print("Error searching foods: \(error)")
            searchResults = []
        }
    }
    
    func createCustomFood(name: String, calories: Int, protein: Double, carbs: Double, fat: Double) -> CDFood {
        repository.createFood(
            name: name,
            caloriesPer100g: Int32(calories),
            proteinPer100g: protein,
            carbsPer100g: carbs,
            fatPer100g: fat
        )
    }
    
    func toggleFavorite(_ food: CDFood) {
        food.isFavorite.toggle()
        saveContext()
    }
    
    func saveContext() {
        do {
            try persistenceController.container.viewContext.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
    
    func getNutritionForMeal(_ meal: CDMeal) -> NutritionInfo {
        NutritionCalculator.calculateNutritionForMeals([meal])
    }
    
    private func calculateDailySummary() {
        let nutrition = NutritionCalculator.calculateNutritionForMeals(todayMeals)
        
        self.todayCalories = nutrition.calories
        self.todayProtein = nutrition.protein
        self.todayCarbs = nutrition.carbs
        self.todayFat = nutrition.fat
        
        updateCalorieBankInfo()
    }
    
    private func updateCalorieBankInfo() {
        let unusedCalories = max(0, dailyCalorieGoal - todayCalories)
        todayDeposit = min(unusedCalories, 150) // Cap at 150 for display
    }
    
    // MARK: - Macro Breakdown Methods
    
    func getTodayMacroBreakdown() -> MacroBreakdown {
        let nutrition = NutritionCalculator.calculateNutritionForMeals(todayMeals)
        return MacroBreakdown(
            totalCalories: Double(nutrition.calories),
            proteinCalories: nutrition.protein * 4,
            carbsCalories: nutrition.carbs * 4,
            fatCalories: nutrition.fat * 9,
            proteinGrams: nutrition.protein,
            carbsGrams: nutrition.carbs,
            fatGrams: nutrition.fat
        )
    }
    
    func getWeekMacroBreakdown() -> MacroBreakdown {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let meals = repository.fetchMeals(from: weekAgo, to: Date())
        let nutrition = NutritionCalculator.calculateNutritionForMeals(meals)
        
        return MacroBreakdown(
            totalCalories: Double(nutrition.calories),
            proteinCalories: nutrition.protein * 4,
            carbsCalories: nutrition.carbs * 4,
            fatCalories: nutrition.fat * 9,
            proteinGrams: nutrition.protein,
            carbsGrams: nutrition.carbs,
            fatGrams: nutrition.fat
        )
    }
    
    func getMonthMacroBreakdown() -> MacroBreakdown {
        let calendar = Calendar.current
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let meals = repository.fetchMeals(from: monthAgo, to: Date())
        let nutrition = NutritionCalculator.calculateNutritionForMeals(meals)
        
        return MacroBreakdown(
            totalCalories: Double(nutrition.calories),
            proteinCalories: nutrition.protein * 4,
            carbsCalories: nutrition.carbs * 4,
            fatCalories: nutrition.fat * 9,
            proteinGrams: nutrition.protein,
            carbsGrams: nutrition.carbs,
            fatGrams: nutrition.fat
        )
    }
    
    func addFoodToMeal(_ food: CDFood, mealType: String?) {
        guard let mealType = mealType else { return }
        
        // Find or create meal for the type
        var meal = todayMeals.first { $0.mealType == mealType }
        if meal == nil {
            meal = createMeal(type: mealType)
            refreshData()
        }
        
        if let meal = meal {
            addFoodToMeal(meal, food: food, quantityGrams: 100) // Default 100g
        }
    }
}

// MARK: - Supporting Types

struct MacroBreakdown {
    let totalCalories: Double
    let proteinCalories: Double
    let carbsCalories: Double
    let fatCalories: Double
    let proteinGrams: Double
    let carbsGrams: Double
    let fatGrams: Double
}