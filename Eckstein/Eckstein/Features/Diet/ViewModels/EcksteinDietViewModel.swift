//
//  EcksteinDietViewModel.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI
import CoreData

@MainActor
class EcksteinDietViewModel: ObservableObject {
    @Published var todayMeal1: DietMealEntry?
    @Published var todayMeal2: DietMealEntry?
    @Published var todaySnacks: [DietMealEntry.DietFoodEntry] = []
    @Published var selectedProteinType: DietRule.DietCategory = .proteinNonFat
    @Published var customFoods: [CDEcksteinFood] = []
    @Published var calorieBankBalance: Int = 0
    @Published var isCarbLoadDay: Bool = false
    @Published var carbLoadMealNumber: Int? = nil
    @Published var combineMealsForCarbLoad: Bool = false
    
    internal let context = PersistenceController.shared.container.viewContext
    private let customFoodManager = CustomFoodManager.shared
    private let fatMealManager = FatMealManager.shared
    private let carbLoadManager = CarbLoadManager.shared
    
    init() {
        loadTodaysMeals()
        loadCustomFoods()
        seedDefaultFoodsIfNeeded()
        fatMealManager.loadCurrentWeekData()
        carbLoadManager.loadCurrentWeekData()
        checkIfTodayIsCarbLoadDay()
    }
    
    var meal1Complete: Bool {
        guard let meal = todayMeal1 else { return false }
        return !meal.proteinFoods.isEmpty && !meal.carbFoods.isEmpty
    }
    
    var meal2Complete: Bool {
        guard let meal = todayMeal2 else { return false }
        return !meal.proteinFoods.isEmpty && !meal.carbFoods.isEmpty
    }
    
    var snacksComplete: Bool {
        !todaySnacks.isEmpty
    }
    
    func toggleProteinType() {
        selectedProteinType = selectedProteinType == .proteinFat ? .proteinNonFat : .proteinFat
    }
    
    // MARK: - Carb Load Methods
    
    func checkIfTodayIsCarbLoadDay() {
        isCarbLoadDay = carbLoadManager.isCarbLoadDay(date: Date())
        
        // Check which meal is marked as carb load
        if isCarbLoadDay {
            let request: NSFetchRequest<CDEcksteinMeal> = CDEcksteinMeal.fetchRequest()
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            request.predicate = NSPredicate(format: "date >= %@ AND date < %@ AND isCarbLoad == YES", 
                                           today as NSDate, 
                                           calendar.date(byAdding: .day, value: 1, to: today)! as NSDate)
            
            do {
                let meals = try context.fetch(request)
                if let carbLoadMeal = meals.first {
                    carbLoadMealNumber = Int(carbLoadMeal.mealNumber)
                }
            } catch {
                print("Error checking carb load meal: \(error)")
            }
        }
    }
    
    func toggleCarbLoadDay() {
        if isCarbLoadDay {
            // Remove carb load day (cancelling doesn't need the canUseCarbLoad check)
            carbLoadManager.removeCarbLoadDay(date: Date())
            isCarbLoadDay = false
            carbLoadMealNumber = nil
            combineMealsForCarbLoad = false
            
            // Update meal to remove carb load flag
            if let meal2 = todayMeal2 {
                updateMealCarbLoadStatus(mealNumber: 2, isCarbLoad: false)
            }
        } else {
            // Set carb load day (only check when activating)
            guard carbLoadManager.canUseCarbLoad else { return }
            carbLoadManager.setCarbLoadDay(date: Date())
            isCarbLoadDay = true
            carbLoadMealNumber = 2 // Default to meal 2
            
            // Update meal to add carb load flag
            updateMealCarbLoadStatus(mealNumber: 2, isCarbLoad: true)
        }
    }
    
    func setCarbLoadMealNumber(_ mealNumber: Int) {
        guard isCarbLoadDay else { return }
        
        // Remove carb load flag from previous meal
        if let previousMealNumber = carbLoadMealNumber {
            updateMealCarbLoadStatus(mealNumber: previousMealNumber, isCarbLoad: false)
        }
        
        // Set new carb load meal
        carbLoadMealNumber = mealNumber
        updateMealCarbLoadStatus(mealNumber: mealNumber, isCarbLoad: true)
    }
    
    func toggleMealCombination() {
        combineMealsForCarbLoad.toggle()
        
        if combineMealsForCarbLoad {
            // When combining meals, meal 2 becomes the carb load meal
            carbLoadMealNumber = 2
            updateMealCarbLoadStatus(mealNumber: 2, isCarbLoad: true)
        }
    }
    
    func updateMealCarbLoadStatus(mealNumber: Int, isCarbLoad: Bool) {
        let request: NSFetchRequest<CDEcksteinMeal> = CDEcksteinMeal.fetchRequest()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@ AND mealNumber == %d", 
                                       today as NSDate, 
                                       calendar.date(byAdding: .day, value: 1, to: today)! as NSDate,
                                       mealNumber)
        
        do {
            let meals = try context.fetch(request)
            if let meal = meals.first {
                meal.isCarbLoad = isCarbLoad
                try context.save()
            }
        } catch {
            print("Error updating meal carb load status: \(error)")
        }
    }
    
    func canUseCarbLoad() -> Bool {
        return carbLoadManager.canUseCarbLoad
    }
    
    func getCarbLoadInfo() -> (used: Bool, date: Date?) {
        return (used: carbLoadManager.hasUsedCarbLoadThisWeek, date: carbLoadManager.carbLoadDate)
    }
    
    func loadTodaysMeals() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let request: NSFetchRequest<CDEcksteinMeal> = CDEcksteinMeal.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", today as NSDate, calendar.date(byAdding: .day, value: 1, to: today)! as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDEcksteinMeal.mealNumber, ascending: true)]
        
        do {
            let meals = try context.fetch(request)
            
            // Convert Core Data meals to DietMealEntry
            for meal in meals {
                let entries = (meal.entries as? Set<CDEcksteinMealEntry>) ?? []
                
                var proteinFoods: [DietMealEntry.DietFoodEntry] = []
                var carbFoods: [DietMealEntry.DietFoodEntry] = []
                var snacks: [DietMealEntry.DietFoodEntry] = []
                
                // Group entries by food name to combine duplicates
                var foodGroups: [String: [CDEcksteinMealEntry]] = [:]
                for entry in entries {
                    if let foodName = entry.foodName {
                        foodGroups[foodName, default: []].append(entry)
                    }
                }
                
                for (foodName, groupedEntries) in foodGroups {
                    guard let firstEntry = groupedEntries.first,
                          let category = firstEntry.category,
                          let categoryEnum = DietRule.DietCategory(rawValue: category) else { continue }
                    
                    // Sum up grams for same food
                    let totalGrams = groupedEntries.reduce(0) { $0 + Int($1.gramsConsumed) }
                    
                    // Find the food rule
                    let food = findFoodRule(name: foodName, category: categoryEnum)
                    let foodEntry = DietMealEntry.DietFoodEntry(food: food, gramsConsumed: totalGrams)
                    
                    switch categoryEnum {
                    case .proteinFat, .proteinNonFat:
                        proteinFoods.append(foodEntry)
                    case .carbs, .carbLoad:
                        carbFoods.append(foodEntry)
                    case .snack:
                        snacks.append(foodEntry)
                    }
                }
                
                let mealEntry = DietMealEntry(
                    id: meal.id ?? UUID(),
                    date: meal.date ?? Date(),
                    mealNumber: Int(meal.mealNumber),
                    proteinFoods: proteinFoods,
                    carbFoods: carbFoods,
                    snacks: snacks
                )
                
                if meal.mealNumber == 1 {
                    todayMeal1 = mealEntry
                } else if meal.mealNumber == 2 {
                    todayMeal2 = mealEntry
                }
                
                // Collect all snacks
                todaySnacks.append(contentsOf: snacks)
            }
            
            // Update fat meal tracking after loading meals
            fatMealManager.updateFatMealTracking(customFoods: customFoods)
        } catch {
            print("Error loading meals: \(error)")
        }
    }
    
    private func loadCustomFoods() {
        customFoodManager.fetchCustomFoods()
        customFoods = customFoodManager.customFoods
    }
    
    private func seedDefaultFoodsIfNeeded() {
        customFoodManager.seedDefaultFoodsIfNeeded()
        loadCustomFoods()
    }
    
    internal func findFoodRule(name: String, category: DietRule.DietCategory) -> DietRule {
        // First check custom foods
        if let customFood = customFoods.first(where: { $0.name == name && $0.category == category.rawValue }),
           let rule = customFoodManager.convertToDietRule(customFood) {
            return rule
        }
        
        // Fallback to default
        return DietRule(foodName: name, category: category, dailyGrams: 100, isSnack: category == .snack)
    }
    
    func addFoodToMeal(mealNumber: Int, food: DietRule, gramsConsumed: Int, date: Date? = nil) {
        let entry = DietMealEntry.DietFoodEntry(food: food, gramsConsumed: gramsConsumed)
        
        // Save to Core Data
        if let date = date {
            saveFoodEntryForDate(date: date, mealNumber: mealNumber, food: food, gramsConsumed: gramsConsumed)
            // For historical dates, just return after saving to Core Data
            // The loadMealsForDate will update the UI
            return
        } else {
            saveFoodEntry(mealNumber: mealNumber, food: food, gramsConsumed: gramsConsumed)
        }
        
        if mealNumber == 1 {
            if todayMeal1 == nil {
                todayMeal1 = DietMealEntry(
                    id: UUID(),
                    date: Date(),
                    mealNumber: 1,
                    proteinFoods: [],
                    carbFoods: [],
                    snacks: []
                )
            }
            
            var proteinFoods = todayMeal1!.proteinFoods
            var carbFoods = todayMeal1!.carbFoods
            var snacks = todayMeal1!.snacks
            
            switch food.category {
            case .proteinFat, .proteinNonFat:
                // Check if this food already exists
                if let index = proteinFoods.firstIndex(where: { $0.food.foodName == food.foodName }) {
                    // Update existing food entry
                    let existing = proteinFoods[index]
                    proteinFoods[index] = DietMealEntry.DietFoodEntry(
                        food: food,
                        gramsConsumed: existing.gramsConsumed + gramsConsumed
                    )
                } else {
                    // Add new food entry
                    proteinFoods.append(entry)
                }
            case .carbs, .carbLoad:
                // Check if this food already exists
                if let index = carbFoods.firstIndex(where: { $0.food.foodName == food.foodName }) {
                    // Update existing food entry
                    let existing = carbFoods[index]
                    carbFoods[index] = DietMealEntry.DietFoodEntry(
                        food: food,
                        gramsConsumed: existing.gramsConsumed + gramsConsumed
                    )
                } else {
                    // Add new food entry
                    carbFoods.append(entry)
                }
            case .snack:
                snacks.append(entry)
                todaySnacks.append(entry)
            }
            
            todayMeal1 = DietMealEntry(
                id: todayMeal1!.id,
                date: todayMeal1!.date,
                mealNumber: 1,
                proteinFoods: proteinFoods,
                carbFoods: carbFoods,
                snacks: snacks
            )
            
            // Force UI update
            objectWillChange.send()
        } else {
            if todayMeal2 == nil {
                todayMeal2 = DietMealEntry(
                    id: UUID(),
                    date: Date(),
                    mealNumber: 2,
                    proteinFoods: [],
                    carbFoods: [],
                    snacks: []
                )
            }
            
            var proteinFoods = todayMeal2!.proteinFoods
            var carbFoods = todayMeal2!.carbFoods
            var snacks = todayMeal2!.snacks
            
            switch food.category {
            case .proteinFat, .proteinNonFat:
                // Check if this food already exists
                if let index = proteinFoods.firstIndex(where: { $0.food.foodName == food.foodName }) {
                    // Update existing food entry
                    let existing = proteinFoods[index]
                    proteinFoods[index] = DietMealEntry.DietFoodEntry(
                        food: food,
                        gramsConsumed: existing.gramsConsumed + gramsConsumed
                    )
                } else {
                    // Add new food entry
                    proteinFoods.append(entry)
                }
            case .carbs, .carbLoad:
                // Check if this food already exists
                if let index = carbFoods.firstIndex(where: { $0.food.foodName == food.foodName }) {
                    // Update existing food entry
                    let existing = carbFoods[index]
                    carbFoods[index] = DietMealEntry.DietFoodEntry(
                        food: food,
                        gramsConsumed: existing.gramsConsumed + gramsConsumed
                    )
                } else {
                    // Add new food entry
                    carbFoods.append(entry)
                }
            case .snack:
                snacks.append(entry)
                todaySnacks.append(entry)
            }
            
            todayMeal2 = DietMealEntry(
                id: todayMeal2!.id,
                date: todayMeal2!.date,
                mealNumber: 2,
                proteinFoods: proteinFoods,
                carbFoods: carbFoods,
                snacks: snacks
            )
            
            // Force UI update
            objectWillChange.send()
        }
        
        // Update fat meal tracking for current date only
        if date == nil {
            fatMealManager.updateFatMealTracking(customFoods: customFoods)
        }
    }
    
    private func saveFoodEntry(mealNumber: Int, food: DietRule, gramsConsumed: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Find or create meal
        let request: NSFetchRequest<CDEcksteinMeal> = CDEcksteinMeal.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@ AND mealNumber == %d", 
                                       today as NSDate, 
                                       calendar.date(byAdding: .day, value: 1, to: today)! as NSDate,
                                       mealNumber)
        
        do {
            let meals = try context.fetch(request)
            let meal: CDEcksteinMeal
            
            if let existingMeal = meals.first {
                meal = existingMeal
            } else {
                meal = CDEcksteinMeal(context: context)
                meal.id = UUID()
                meal.date = Date()
                meal.mealNumber = Int32(mealNumber)
                meal.user = getCurrentUser()
            }
            
            // Check if entry for this food already exists
            let existingEntries = (meal.entries as? Set<CDEcksteinMealEntry>) ?? []
            if let existingEntry = existingEntries.first(where: { 
                $0.foodName == food.foodName && $0.category == food.category.rawValue 
            }) {
                // Update existing entry by adding to current amount
                existingEntry.gramsConsumed += Int32(gramsConsumed)
            } else {
                // Create new entry
                let entry = CDEcksteinMealEntry(context: context)
                entry.id = UUID()
                entry.foodName = food.foodName
                entry.category = food.category.rawValue
                entry.gramsConsumed = Int32(gramsConsumed)
                entry.meal = meal
            }
            
            try context.save()
        } catch {
            print("Error saving meal entry: \(error)")
        }
    }
    
    internal func getCurrentUser() -> CDUser? {
        let request: NSFetchRequest<CDUser> = CDUser.fetchRequest()
        request.fetchLimit = 1
        
        do {
            let users = try context.fetch(request)
            if let user = users.first {
                return user
            } else {
                // Create default user
                let user = CDUser(context: context)
                user.id = UUID()
                user.email = "user@example.com"
                user.createdAt = Date()
                user.updatedAt = Date()
                user.syncStatus = "pending"
                try context.save()
                return user
            }
        } catch {
            print("Error getting user: \(error)")
            return nil
        }
    }
    
    func getCarryOverFromPreviousMeal(for mealNumber: Int) -> (proteinPercentage: Double, carbPercentage: Double)? {
        guard mealNumber == 2 else { return nil }
        
        // Calculate how much of the 200% pool is left for meal 2
        let proteinUsedInMeal1 = todayMeal1?.totalPercentage(for: .proteinNonFat) ?? 0
        let carbsUsedInMeal1 = todayMeal1?.totalPercentage(for: .carbs) ?? 0
        
        // Meal 2 gets whatever is left from the 200% pool
        let proteinRemainingForMeal2 = 200 - proteinUsedInMeal1
        let carbsRemainingForMeal2 = 200 - carbsUsedInMeal1
        
        // Return as carry-over (this represents meal 2's share of the pool)
        // Subtract 100 because the UI expects carry-over relative to meal 2's base 100%
        return (proteinRemainingForMeal2 - 100, carbsRemainingForMeal2 - 100)
    }
    
    func getDailySummary() -> DailySummary? {
        var totalProteinGrams = 0
        var totalProteinTarget = 0
        var totalCarbGrams = 0
        var totalCarbTarget = 0
        
        // Add meal 1
        if let meal1 = todayMeal1 {
            totalProteinGrams += meal1.proteinFoods.reduce(0) { $0 + $1.gramsConsumed }
            if let firstProtein = meal1.proteinFoods.first {
                totalProteinTarget = firstProtein.food.dailyGrams
            }
            
            totalCarbGrams += meal1.carbFoods.reduce(0) { $0 + $1.gramsConsumed }
            if let firstCarb = meal1.carbFoods.first {
                totalCarbTarget = firstCarb.food.dailyGrams
            }
        }
        
        // Add meal 2
        if let meal2 = todayMeal2 {
            totalProteinGrams += meal2.proteinFoods.reduce(0) { $0 + $1.gramsConsumed }
            totalCarbGrams += meal2.carbFoods.reduce(0) { $0 + $1.gramsConsumed }
        }
        
        guard totalProteinTarget > 0 || totalCarbTarget > 0 else { return nil }
        
        return DailySummary(
            totalProteinGrams: totalProteinGrams,
            totalCarbGrams: totalCarbGrams,
            proteinPercentage: totalProteinTarget > 0 ? Double(totalProteinGrams) / Double(totalProteinTarget) * 100 : 0,
            carbPercentage: totalCarbTarget > 0 ? Double(totalCarbGrams) / Double(totalCarbTarget) * 100 : 0,
            hasCarryOver: totalProteinGrams < totalProteinTarget || totalCarbGrams < totalCarbTarget
        )
    }
    
    func getRemainingAllowance(for food: DietRule, currentGrams: Int, mealNumber: Int) -> Int {
        let dailyAllowance = food.dailyGrams
        
        // For snacks, use simple calculation
        if food.category == .snack {
            return dailyAllowance - currentGrams
        }
        
        // Get total percentage used across both meals for this category
        let totalUsedPercentage = getTotalCategoryPercentage(for: food.category)
        
        // Calculate current meal's contribution to ensure we're not double counting
        var currentMealPercentage: Double = 0
        let meal = mealNumber == 1 ? todayMeal1 : todayMeal2
        if let meal = meal {
            switch food.category {
            case .proteinFat, .proteinNonFat:
                currentMealPercentage = meal.totalPercentage(for: .proteinNonFat)
            case .carbs, .carbLoad:
                currentMealPercentage = meal.totalPercentage(for: .carbs)
            case .snack:
                break
            }
        }
        
        // Calculate how much this specific food would contribute
        let currentFoodPercentage = Double(currentGrams) / Double(food.dailyGrams) * 100
        
        // Total percentage if we add this food
        let projectedTotalPercentage = totalUsedPercentage + currentFoodPercentage
        
        // Check if adding this food would exceed 200% limit
        if projectedTotalPercentage <= 200 {
            // Calculate remaining percentage available from the 200% pool
            let remainingPoolPercentage = 200 - totalUsedPercentage
            
            // Convert to grams for this specific food
            let maxGramsFromPool = Int(Double(food.dailyGrams) * remainingPoolPercentage / 100.0)
            
            // Return the maximum grams available
            return max(0, maxGramsFromPool)
        } else {
            // Calculate exactly how much we can add to reach 200%
            let remainingToReach200 = max(0, 200 - totalUsedPercentage)
            return max(0, Int(Double(food.dailyGrams) * remainingToReach200 / 100.0))
        }
    }
    
    func getTotalConsumedForCategory(mealNumber: Int, category: DietRule.DietCategory) -> Int {
        let meal = mealNumber == 1 ? todayMeal1 : todayMeal2
        guard let meal = meal else { return 0 }
        
        switch category {
        case .proteinFat, .proteinNonFat:
            return meal.proteinFoods.reduce(0) { $0 + $1.gramsConsumed }
        case .carbs, .carbLoad:
            return meal.carbFoods.reduce(0) { $0 + $1.gramsConsumed }
        case .snack:
            return 0 // Snacks are tracked separately
        }
    }
    
    // Calculate total percentage used across both meals for a category
    func getTotalCategoryPercentage(for category: DietRule.DietCategory) -> Double {
        var totalPercentage: Double = 0
        
        // Add meal 1 percentage
        if let meal1 = todayMeal1 {
            switch category {
            case .proteinFat, .proteinNonFat:
                totalPercentage += meal1.totalPercentage(for: .proteinNonFat)
            case .carbs, .carbLoad:
                totalPercentage += meal1.totalPercentage(for: .carbs)
            case .snack:
                break
            }
        }
        
        // Add meal 2 percentage
        if let meal2 = todayMeal2 {
            switch category {
            case .proteinFat, .proteinNonFat:
                totalPercentage += meal2.totalPercentage(for: .proteinNonFat)
            case .carbs, .carbLoad:
                totalPercentage += meal2.totalPercentage(for: .carbs)
            case .snack:
                break
            }
        }
        
        return totalPercentage
    }
    
    struct DailySummary {
        let totalProteinGrams: Int
        let totalCarbGrams: Int
        let proteinPercentage: Double
        let carbPercentage: Double
        let hasCarryOver: Bool
    }
    
    // MARK: - Custom Food Management
    
    func getAllFoodsForCategory(_ category: DietRule.DietCategory) -> [DietRule] {
        var allFoods: [DietRule] = []
        var foodNames = Set<String>() // Track unique food names
        
        // Helper function to add foods without duplicates
        func addUniqueFood(_ food: DietRule) {
            if !foodNames.contains(food.foodName) {
                foodNames.insert(food.foodName)
                allFoods.append(food)
            }
        }
        
        // For protein, return both fat and non-fat options
        if category == .proteinFat || category == .proteinNonFat {
            // Add predefined protein foods
            EcksteinDietRules.proteinFatRules.forEach { addUniqueFood($0) }
            EcksteinDietRules.proteinNonFatRules.forEach { addUniqueFood($0) }
            
            // Add custom protein foods (avoiding duplicates)
            let customFatFoods = customFoodManager.fetchFoodsByCategory(DietRule.DietCategory.proteinFat.rawValue)
            let customNonFatFoods = customFoodManager.fetchFoodsByCategory(DietRule.DietCategory.proteinNonFat.rawValue)
            let allCustomProteinFoods = customFatFoods + customNonFatFoods
            let customRules = allCustomProteinFoods.compactMap { customFoodManager.convertToDietRule($0) }
            customRules.forEach { addUniqueFood($0) }
            
            return allFoods
        } else if category == .carbLoad {
            // Add predefined carb load foods
            EcksteinDietRules.carbLoadRules.forEach { addUniqueFood($0) }
            
            // Add custom carb load foods (avoiding duplicates)
            let customCarbLoadFoods = customFoodManager.fetchFoodsByCategory(category.rawValue)
            let customRules = customCarbLoadFoods.compactMap { customFoodManager.convertToDietRule($0) }
            customRules.forEach { addUniqueFood($0) }
            
            return allFoods
        } else if category == .snack {
            // Add predefined snack foods
            EcksteinDietRules.snackRules.forEach { addUniqueFood($0) }
            
            // Add custom snack foods (avoiding duplicates)
            let customSnackFoods = customFoodManager.fetchFoodsByCategory(category.rawValue)
            let customRules = customSnackFoods.compactMap { customFoodManager.convertToDietRule($0) }
            customRules.forEach { addUniqueFood($0) }
            
            return allFoods
        } else if category == .carbs {
            // Add predefined carb foods
            EcksteinDietRules.carbRules.forEach { addUniqueFood($0) }
            
            // Add custom carb foods (avoiding duplicates)
            let customCarbFoods = customFoodManager.fetchFoodsByCategory(category.rawValue)
            let customRules = customCarbFoods.compactMap { customFoodManager.convertToDietRule($0) }
            customRules.forEach { addUniqueFood($0) }
            
            return allFoods
        } else {
            let customFoods = customFoodManager.fetchFoodsByCategory(category.rawValue)
            return customFoods.compactMap { customFoodManager.convertToDietRule($0) }
        }
    }
    
    func canSelectFood(_ food: DietRule, mealNumber: Int, date: Date? = nil) -> Bool {
        // Check if this is a fat protein
        if food.category == .proteinFat || food.category == .proteinNonFat {
            if let customFood = customFoods.first(where: { $0.name == food.foodName }) {
                if customFood.isFat {
                    let selectedDate = date ?? Date()
                    let weekFatMeals = fatMealManager.getFatMealsForWeek(of: selectedDate)
                    
                    // Check if we've reached the weekly limit
                    if weekFatMeals >= 2 {
                        // Check if this specific meal already has a fat protein
                        // If it does, allow adding more fat proteins to the same meal
                        return mealAlreadyHasFatProtein(mealNumber: mealNumber, date: selectedDate)
                    }
                    return true
                }
            }
        }
        return true
    }
    
    private func mealAlreadyHasFatProtein(mealNumber: Int, date: Date? = nil) -> Bool {
        // If a specific date is provided and it's not today, we need to check that date's meals
        if let date = date, !Calendar.current.isDateInToday(date) {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            let request: NSFetchRequest<CDEcksteinMeal> = CDEcksteinMeal.fetchRequest()
            request.predicate = NSPredicate(format: "date >= %@ AND date < %@ AND mealNumber == %d",
                                           startOfDay as NSDate,
                                           endOfDay as NSDate,
                                           mealNumber)
            
            do {
                let meals = try context.fetch(request)
                if let meal = meals.first,
                   let entries = meal.entries as? Set<CDEcksteinMealEntry> {
                    for entry in entries {
                        if let foodName = entry.foodName,
                           let category = entry.category,
                           (category == DietRule.DietCategory.proteinFat.rawValue || 
                            category == DietRule.DietCategory.proteinNonFat.rawValue) {
                            if let customFood = customFoods.first(where: { $0.name == foodName }) {
                                if customFood.isFat {
                                    return true
                                }
                            }
                        }
                    }
                }
            } catch {
                print("Error checking historical meal for fat protein: \(error)")
            }
            return false
        }
        
        // For today's date, use the current meal data
        let meal = mealNumber == 1 ? todayMeal1 : todayMeal2
        guard let meal = meal else { return false }
        
        for proteinFood in meal.proteinFoods {
            if let customFood = customFoods.first(where: { $0.name == proteinFood.food.foodName }) {
                if customFood.isFat {
                    return true
                }
            }
        }
        return false
    }
    
    func isFatProtein(_ food: DietRule) -> Bool {
        if food.category == .proteinFat || food.category == .proteinNonFat {
            if let customFood = customFoods.first(where: { $0.name == food.foodName }) {
                return customFood.isFat
            }
        }
        return false
    }
    
    func getFatMealsInfo() -> (used: Int, remaining: Int) {
        return (used: fatMealManager.currentWeekFatMeals, 
                remaining: fatMealManager.getRemainingFatMeals())
    }
    
    func createCustomFood(name: String, category: DietRule.DietCategory, dailyGrams: Int, isFat: Bool = false) {
        _ = customFoodManager.createCustomFood(name: name, category: category, dailyGrams: dailyGrams, isFat: isFat)
        loadCustomFoods()
    }
    
    func deleteCustomFood(_ food: CDEcksteinFood) {
        customFoodManager.deleteFood(food)
        loadCustomFoods()
    }
    
    // MARK: - Snack Management
    
    func addSnack(_ food: DietRule, gramsConsumed: Int, date: Date? = nil) {
        // Snacks are not meal-specific, just add to the list
        if let date = date {
            saveFoodEntryForDate(date: date, mealNumber: 0, food: food, gramsConsumed: gramsConsumed) // Use 0 for snacks
            // For historical dates, just return after saving to Core Data
            // The loadMealsForDate will update the UI
            return
        } else {
            saveFoodEntry(mealNumber: 0, food: food, gramsConsumed: gramsConsumed) // Use 0 for snacks
        }
        
        let entry = DietMealEntry.DietFoodEntry(food: food, gramsConsumed: gramsConsumed)
        todaySnacks.append(entry)
        
        // Force UI update
        objectWillChange.send()
    }
    
    func removeSnack(_ food: DietRule, date: Date? = nil) {
        if let date = date {
            // For historical dates, remove from Core Data with specific date
            removeFoodEntryFromCoreData(mealNumber: 0, foodName: food.foodName, date: date)
            // Reload data for that date
            loadMealsForDate(date)
        } else {
            // Remove from today's snacks list
            todaySnacks.removeAll { $0.food.foodName == food.foodName }
            
            // Remove from Core Data
            removeFoodEntryFromCoreData(mealNumber: 0, foodName: food.foodName)
            
            // Force UI update
            objectWillChange.send()
        }
    }
    
    // MARK: - Remove Food
    
    func removeFoodFromMeal(mealNumber: Int, food: DietRule, category: DietRule.DietCategory, date: Date? = nil) {
        if let date = date {
            // For historical dates, remove from Core Data with specific date
            removeFoodEntryFromCoreData(mealNumber: mealNumber, foodName: food.foodName, date: date)
            // Reload data for that date
            loadMealsForDate(date)
            return
        }
        
        if mealNumber == 1 {
            guard var meal = todayMeal1 else { return }
            
            var proteinFoods = meal.proteinFoods
            var carbFoods = meal.carbFoods
            var snacks = meal.snacks
            
            switch category {
            case .proteinFat, .proteinNonFat:
                proteinFoods.removeAll { $0.food.foodName == food.foodName }
            case .carbs, .carbLoad:
                carbFoods.removeAll { $0.food.foodName == food.foodName }
            case .snack:
                snacks.removeAll { $0.food.foodName == food.foodName }
                todaySnacks.removeAll { $0.food.foodName == food.foodName }
            }
            
            todayMeal1 = DietMealEntry(
                id: meal.id,
                date: meal.date,
                mealNumber: 1,
                proteinFoods: proteinFoods,
                carbFoods: carbFoods,
                snacks: snacks
            )
            
            // Force UI update
            objectWillChange.send()
        } else {
            guard var meal = todayMeal2 else { return }
            
            var proteinFoods = meal.proteinFoods
            var carbFoods = meal.carbFoods
            var snacks = meal.snacks
            
            switch category {
            case .proteinFat, .proteinNonFat:
                proteinFoods.removeAll { $0.food.foodName == food.foodName }
            case .carbs, .carbLoad:
                carbFoods.removeAll { $0.food.foodName == food.foodName }
            case .snack:
                snacks.removeAll { $0.food.foodName == food.foodName }
                todaySnacks.removeAll { $0.food.foodName == food.foodName }
            }
            
            todayMeal2 = DietMealEntry(
                id: meal.id,
                date: meal.date,
                mealNumber: 2,
                proteinFoods: proteinFoods,
                carbFoods: carbFoods,
                snacks: snacks
            )
            
            // Force UI update
            objectWillChange.send()
        }
        
        // Remove from Core Data
        removeFoodEntryFromCoreData(mealNumber: mealNumber, foodName: food.foodName)
        
        // Update fat meal tracking for current date only
        if date == nil {
            fatMealManager.updateFatMealTracking(customFoods: customFoods)
        }
    }
    
    private func removeFoodEntryFromCoreData(mealNumber: Int, foodName: String, date: Date? = nil) {
        let calendar = Calendar.current
        let targetDate = date != nil ? calendar.startOfDay(for: date!) : calendar.startOfDay(for: Date())
        
        let request: NSFetchRequest<CDEcksteinMealEntry> = CDEcksteinMealEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "meal.date >= %@ AND meal.date < %@ AND meal.mealNumber == %d AND foodName == %@",
            targetDate as NSDate,
            calendar.date(byAdding: .day, value: 1, to: targetDate)! as NSDate,
            mealNumber,
            foodName
        )
        
        do {
            let entries = try context.fetch(request)
            for entry in entries {
                context.delete(entry)
            }
            try context.save()
        } catch {
            print("Error removing food entry: \(error)")
        }
    }
    
    // MARK: - Day Management
    
    func resetDay() {
        // Clear today's meals from memory
        todayMeal1 = nil
        todayMeal2 = nil
        todaySnacks = []
        
        // Note: We don't delete from Core Data as we want to keep history
        // The next day's loadTodaysMeals will naturally filter to new date
    }
    
    // MARK: - Analytics Methods
    
    func fetchMealsForDateRange(from startDate: Date, to endDate: Date) -> [DietMealEntry] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startDate)
        let endOfDay = calendar.dateInterval(of: .day, for: endDate)?.end ?? endDate
        
        let request: NSFetchRequest<CDEcksteinMeal> = CDEcksteinMeal.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CDEcksteinMeal.date, ascending: true),
            NSSortDescriptor(keyPath: \CDEcksteinMeal.mealNumber, ascending: true)
        ]
        
        do {
            let meals = try context.fetch(request)
            return meals.compactMap { meal in
                let entries = (meal.entries as? Set<CDEcksteinMealEntry>) ?? []
                
                var proteinFoods: [DietMealEntry.DietFoodEntry] = []
                var carbFoods: [DietMealEntry.DietFoodEntry] = []
                var snacks: [DietMealEntry.DietFoodEntry] = []
                
                // Group entries by food name
                var foodGroups: [String: [CDEcksteinMealEntry]] = [:]
                for entry in entries {
                    if let foodName = entry.foodName {
                        foodGroups[foodName, default: []].append(entry)
                    }
                }
                
                for (foodName, groupedEntries) in foodGroups {
                    guard let firstEntry = groupedEntries.first,
                          let category = firstEntry.category,
                          let categoryEnum = DietRule.DietCategory(rawValue: category) else { continue }
                    
                    let totalGrams = groupedEntries.reduce(0) { $0 + Int($1.gramsConsumed) }
                    let food = findFoodRule(name: foodName, category: categoryEnum)
                    let foodEntry = DietMealEntry.DietFoodEntry(food: food, gramsConsumed: totalGrams)
                    
                    switch categoryEnum {
                    case .proteinFat, .proteinNonFat:
                        proteinFoods.append(foodEntry)
                    case .carbs, .carbLoad:
                        carbFoods.append(foodEntry)
                    case .snack:
                        snacks.append(foodEntry)
                    }
                }
                
                return DietMealEntry(
                    id: meal.id ?? UUID(),
                    date: meal.date ?? Date(),
                    mealNumber: Int(meal.mealNumber),
                    proteinFoods: proteinFoods,
                    carbFoods: carbFoods,
                    snacks: snacks
                )
            }
        } catch {
            print("Error fetching meals for date range: \(error)")
            return []
        }
    }
    
    func getWeeklyAnalytics() -> WeeklyAnalytics {
        let calendar = Calendar.current
        let today = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        
        let meals = fetchMealsForDateRange(from: weekAgo, to: today)
        
        // Group meals by date
        var mealsByDate: [Date: [DietMealEntry]] = [:]
        for meal in meals {
            let dayStart = calendar.startOfDay(for: meal.date)
            mealsByDate[dayStart, default: []].append(meal)
        }
        
        // Calculate daily stats
        var dailyStats: [DailyMealStats] = []
        var totalProteinConsumed = 0
        var totalCarbConsumed = 0
        var daysWithData = 0
        var completedMeal1Count = 0
        var completedMeal2Count = 0
        
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            let dayMeals = mealsByDate[dayStart] ?? []
            
            var dayProtein = 0
            var dayCarbs = 0
            var meal1Complete = false
            var meal2Complete = false
            
            for meal in dayMeals {
                let proteinGrams = meal.proteinFoods.reduce(0) { $0 + $1.gramsConsumed }
                let carbGrams = meal.carbFoods.reduce(0) { $0 + $1.gramsConsumed }
                
                dayProtein += proteinGrams
                dayCarbs += carbGrams
                
                if meal.mealNumber == 1 && !meal.proteinFoods.isEmpty && !meal.carbFoods.isEmpty {
                    meal1Complete = true
                } else if meal.mealNumber == 2 && !meal.proteinFoods.isEmpty && !meal.carbFoods.isEmpty {
                    meal2Complete = true
                }
            }
            
            if dayProtein > 0 || dayCarbs > 0 {
                daysWithData += 1
                totalProteinConsumed += dayProtein
                totalCarbConsumed += dayCarbs
                if meal1Complete { completedMeal1Count += 1 }
                if meal2Complete { completedMeal2Count += 1 }
            }
            
            dailyStats.append(DailyMealStats(
                date: dayStart,
                proteinGrams: dayProtein,
                carbGrams: dayCarbs,
                meal1Complete: meal1Complete,
                meal2Complete: meal2Complete
            ))
        }
        
        // Calculate most used foods
        var proteinFrequency: [String: Int] = [:]
        var carbFrequency: [String: Int] = [:]
        
        for meal in meals {
            for protein in meal.proteinFoods {
                proteinFrequency[protein.food.foodName, default: 0] += 1
            }
            for carb in meal.carbFoods {
                carbFrequency[carb.food.foodName, default: 0] += 1
            }
        }
        
        let topProteins = proteinFrequency.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
        let topCarbs = carbFrequency.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
        
        // Get target values (assuming same protein/carb target for all days)
        let proteinTarget = selectedProteinType == .proteinFat ? 240 : 320
        let carbTarget = 250 // Default to rice
        
        return WeeklyAnalytics(
            dailyStats: dailyStats.reversed(), // Reverse to show oldest first
            averageProteinGrams: daysWithData > 0 ? totalProteinConsumed / daysWithData : 0,
            averageCarbGrams: daysWithData > 0 ? totalCarbConsumed / daysWithData : 0,
            proteinTarget: proteinTarget,
            carbTarget: carbTarget,
            meal1CompletionRate: daysWithData > 0 ? Double(completedMeal1Count) / Double(daysWithData) : 0,
            meal2CompletionRate: daysWithData > 0 ? Double(completedMeal2Count) / Double(daysWithData) : 0,
            mostUsedProteins: topProteins,
            mostUsedCarbs: topCarbs,
            daysWithData: daysWithData,
            compliantDays: completedMeal1Count // Use meal1 completion as compliance metric
        )
    }
    
    func getComplianceStats() -> ComplianceStats {
        let calendar = Calendar.current
        let today = Date()
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: today) ?? today
        
        let meals = fetchMealsForDateRange(from: monthAgo, to: today)
        
        // Group meals by date
        var mealsByDate: [Date: [DietMealEntry]] = [:]
        for meal in meals {
            let dayStart = calendar.startOfDay(for: meal.date)
            mealsByDate[dayStart, default: []].append(meal)
        }
        
        // Calculate compliance
        var totalDays = 0
        var compliantDays = 0
        var currentStreak = 0
        var longestStreak = 0
        var lastCompliantDate: Date?
        
        // Check each day from oldest to newest
        var currentDate = monthAgo
        while currentDate <= today {
            let dayStart = calendar.startOfDay(for: currentDate)
            let dayMeals = mealsByDate[dayStart] ?? []
            
            totalDays += 1
            
            // Check if both meals are complete
            let meal1 = dayMeals.first { $0.mealNumber == 1 }
            let meal2 = dayMeals.first { $0.mealNumber == 2 }
            
            let meal1Complete = meal1 != nil && !meal1!.proteinFoods.isEmpty && !meal1!.carbFoods.isEmpty
            let meal2Complete = meal2 != nil && !meal2!.proteinFoods.isEmpty && !meal2!.carbFoods.isEmpty
            
            if meal1Complete && meal2Complete {
                compliantDays += 1
                currentStreak += 1
                longestStreak = max(longestStreak, currentStreak)
                lastCompliantDate = dayStart
            } else if dayMeals.count > 0 {
                // Partial compliance - reset streak
                currentStreak = 0
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? today
        }
        
        // Check if streak is still active
        if let lastDate = lastCompliantDate {
            let daysSinceLastCompliant = calendar.dateComponents([.day], from: lastDate, to: today).day ?? 0
            if daysSinceLastCompliant > 1 {
                currentStreak = 0
            }
        }
        
        return ComplianceStats(
            totalDays: totalDays,
            compliantDays: compliantDays,
            complianceRate: totalDays > 0 ? Double(compliantDays) / Double(totalDays) : 0,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            averageDailyProtein: 0, // Will be calculated from weekly stats
            averageDailyCarbs: 0    // Will be calculated from weekly stats
        )
    }
    
    // MARK: - Analytics Models
    
    struct WeeklyAnalytics {
        let dailyStats: [DailyMealStats]
        let averageProteinGrams: Int
        let averageCarbGrams: Int
        let proteinTarget: Int
        let carbTarget: Int
        let meal1CompletionRate: Double
        let meal2CompletionRate: Double
        let mostUsedProteins: [String]
        let mostUsedCarbs: [String]
        let daysWithData: Int
        let compliantDays: Int
    }
    
    struct DailyMealStats {
        let date: Date
        let proteinGrams: Int
        let carbGrams: Int
        let meal1Complete: Bool
        let meal2Complete: Bool
    }
    
    struct ComplianceStats {
        let totalDays: Int
        let compliantDays: Int
        let complianceRate: Double
        let currentStreak: Int
        let longestStreak: Int
        let averageDailyProtein: Int
        let averageDailyCarbs: Int
    }
}