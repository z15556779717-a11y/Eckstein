//
//  FatMealManager.swift
//  Eckstein
//
//  Created by Assistant on 17/01/2025.
//

import Foundation
import CoreData
import Combine

@MainActor
class FatMealManager: ObservableObject {
    static let shared = FatMealManager()
    
    @Published var currentWeekFatMeals: Int = 0
    @Published var canAddFatMeal: Bool = true
    @Published var fatMealDates: Set<String> = [] // Track which meal dates have fat proteins
    
    private let context = PersistenceController.shared.container.viewContext
    private let maxFatMealsPerWeek = 2
    private var cancellables = Set<AnyCancellable>()
    private var customFoods: [CDEcksteinFood] = []
    
    private init() {
        loadCurrentWeekData()
        setupWeeklyReset()
    }
    
    // MARK: - Public Methods
    
    func loadCurrentWeekData() {
        let weekStart = getWeekStartDate()
        
        let request = NSFetchRequest<CDFatMealTracker>(entityName: "CDFatMealTracker")
        request.predicate = NSPredicate(format: "weekStartDate == %@ AND user == %@", 
                                       weekStart as NSDate, 
                                       getCurrentUser() as CVarArg)
        request.fetchLimit = 1
        
        do {
            let trackers = try context.fetch(request)
            if let tracker = trackers.first {
                currentWeekFatMeals = Int(tracker.fatMealsConsumed)
            } else {
                // Create new tracker for this week
                createNewWeekTracker()
                currentWeekFatMeals = 0
            }
            
            canAddFatMeal = currentWeekFatMeals < maxFatMealsPerWeek
        } catch {
            print("Error loading fat meal tracker: \(error)")
        }
    }
    
    func updateFatMealTracking(customFoods: [CDEcksteinFood]) {
        // Store custom foods for reference
        self.customFoods = customFoods
        
        // This method will be called to recalculate fat meals based on actual meal data
        let calendar = Calendar.current
        let weekStart = getWeekStartDate()
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? Date()
        
        // Fetch all Eckstein meals for this week
        let request = NSFetchRequest<CDEcksteinMeal>(entityName: "CDEcksteinMeal")
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@ AND user == %@",
                                       weekStart as NSDate,
                                       weekEnd as NSDate,
                                       getCurrentUser() as CVarArg)
        
        do {
            let meals = try context.fetch(request)
            var fatMealIdentifiers = Set<String>()
            
            // Check each meal for fat proteins
            for meal in meals {
                if let entries = meal.entries as? Set<CDEcksteinMealEntry> {
                    for entry in entries {
                        if let foodName = entry.foodName,
                           let category = entry.category,
                           (category == DietRule.DietCategory.proteinFat.rawValue || 
                            category == DietRule.DietCategory.proteinNonFat.rawValue) {
                            
                            // Check if this food is a fat protein
                            if let customFood = customFoods.first(where: { $0.name == foodName }) {
                                if customFood.isFat {
                                    // Create a unique identifier for this meal (date + meal number)
                                    let mealDate = calendar.startOfDay(for: meal.date ?? Date())
                                    let mealIdentifier = "\(mealDate.timeIntervalSince1970)-\(meal.mealNumber)"
                                    fatMealIdentifiers.insert(mealIdentifier)
                                    break // Only count once per meal
                                }
                            }
                        }
                    }
                }
            }
            
            // Update the tracker with the actual count
            fatMealDates = fatMealIdentifiers
            let newCount = fatMealIdentifiers.count
            
            let trackerRequest = NSFetchRequest<CDFatMealTracker>(entityName: "CDFatMealTracker")
            trackerRequest.predicate = NSPredicate(format: "weekStartDate == %@ AND user == %@",
                                                 weekStart as NSDate,
                                                 getCurrentUser() as CVarArg)
            
            let trackers = try context.fetch(trackerRequest)
            let tracker: CDFatMealTracker
            
            if let existingTracker = trackers.first {
                tracker = existingTracker
            } else {
                tracker = createNewWeekTracker()
            }
            
            tracker.fatMealsConsumed = Int32(newCount)
            tracker.updatedAt = Date()
            
            try context.save()
            
            currentWeekFatMeals = newCount
            canAddFatMeal = newCount < maxFatMealsPerWeek
            
        } catch {
            print("Error updating fat meal tracking: \(error)")
        }
    }
    
    func canSelectFatProtein() -> Bool {
        return canAddFatMeal
    }
    
    func getRemainingFatMeals() -> Int {
        return max(0, maxFatMealsPerWeek - currentWeekFatMeals)
    }
    
    // MARK: - Private Methods
    
    private func getWeekStartDate() -> Date {
        let calendar = Calendar.current
        let today = Date()
        
        // Get the start of today
        let startOfToday = calendar.startOfDay(for: today)
        
        // Find the most recent Sunday (week starts on Sunday)
        let weekday = calendar.component(.weekday, from: startOfToday)
        let daysToSubtract = weekday - 1 // Sunday is 1
        
        return calendar.date(byAdding: .day, value: -daysToSubtract, to: startOfToday) ?? startOfToday
    }
    
    private func createNewWeekTracker() -> CDFatMealTracker {
        let tracker = CDFatMealTracker(context: context)
        tracker.id = UUID()
        tracker.weekStartDate = getWeekStartDate()
        tracker.fatMealsConsumed = 0
        tracker.createdAt = Date()
        tracker.updatedAt = Date()
        tracker.syncStatus = "pending"
        tracker.user = getCurrentUser()
        
        do {
            try context.save()
        } catch {
            print("Error creating new week tracker: \(error)")
        }
        
        return tracker
    }
    
    private func getCurrentUser() -> CDUser {
        let request = NSFetchRequest<CDUser>(entityName: "CDUser")
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
            // Return a default user as fallback
            let user = CDUser(context: context)
            user.id = UUID()
            user.email = "user@example.com"
            return user
        }
    }
    
    private func setupWeeklyReset() {
        // Check every hour if we need to reset for a new week
        Timer.publish(every: 3600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkAndResetIfNewWeek()
            }
            .store(in: &cancellables)
    }
    
    private func checkAndResetIfNewWeek() {
        let currentWeekStart = getWeekStartDate()
        
        // Check if we have a tracker for the current week
        let request = NSFetchRequest<CDFatMealTracker>(entityName: "CDFatMealTracker")
        request.predicate = NSPredicate(format: "weekStartDate == %@ AND user == %@", 
                                       currentWeekStart as NSDate, 
                                       getCurrentUser() as CVarArg)
        
        do {
            let count = try context.count(for: request)
            if count == 0 {
                // New week, reload data
                loadCurrentWeekData()
            }
        } catch {
            print("Error checking for new week: \(error)")
        }
    }
    
    // MARK: - History Methods
    
    func getFatMealHistory(weeks: Int = 4) -> [(weekStart: Date, fatMealsUsed: Int)] {
        let calendar = Calendar.current
        var history: [(weekStart: Date, fatMealsUsed: Int)] = []
        
        for weekOffset in 0..<weeks {
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: getWeekStartDate()) ?? Date()
            
            let request = NSFetchRequest<CDFatMealTracker>(entityName: "CDFatMealTracker")
            request.predicate = NSPredicate(format: "weekStartDate == %@ AND user == %@", 
                                           weekStart as NSDate, 
                                           getCurrentUser() as CVarArg)
            
            do {
                let trackers = try context.fetch(request)
                let fatMeals = trackers.first?.fatMealsConsumed ?? 0
                history.append((weekStart: weekStart, fatMealsUsed: Int(fatMeals)))
            } catch {
                print("Error fetching fat meal history: \(error)")
                history.append((weekStart: weekStart, fatMealsUsed: 0))
            }
        }
        
        return history
    }
    
    // Get fat meals count for a specific date's week
    func getFatMealsForWeek(of date: Date) -> Int {
        let weekStart = getWeekStartDate(for: date)
        let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? Date()
        
        // Count actual fat meals in that week
        let request = NSFetchRequest<CDEcksteinMeal>(entityName: "CDEcksteinMeal")
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@ AND user == %@",
                                       weekStart as NSDate,
                                       weekEnd as NSDate,
                                       getCurrentUser() as CVarArg)
        
        do {
            let meals = try context.fetch(request)
            var fatMealIdentifiers = Set<String>()
            
            for meal in meals {
                if let entries = meal.entries as? Set<CDEcksteinMealEntry> {
                    for entry in entries {
                        if let foodName = entry.foodName,
                           let category = entry.category,
                           (category == DietRule.DietCategory.proteinFat.rawValue || 
                            category == DietRule.DietCategory.proteinNonFat.rawValue) {
                            
                            if let customFood = customFoods.first(where: { $0.name == foodName }) {
                                if customFood.isFat {
                                    let mealDate = Calendar.current.startOfDay(for: meal.date ?? Date())
                                    let mealIdentifier = "\(mealDate.timeIntervalSince1970)-\(meal.mealNumber)"
                                    fatMealIdentifiers.insert(mealIdentifier)
                                    break
                                }
                            }
                        }
                    }
                }
            }
            
            return fatMealIdentifiers.count
        } catch {
            print("Error getting fat meals for week: \(error)")
            return 0
        }
    }
    
    // Update fat meal tracking for a specific week
    func updateFatMealTrackingForWeek(of date: Date, customFoods: [CDEcksteinFood]) {
        self.customFoods = customFoods
        
        let weekStart = getWeekStartDate(for: date)
        let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? Date()
        
        // Fetch all Eckstein meals for this week
        let request = NSFetchRequest<CDEcksteinMeal>(entityName: "CDEcksteinMeal")
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@ AND user == %@",
                                       weekStart as NSDate,
                                       weekEnd as NSDate,
                                       getCurrentUser() as CVarArg)
        
        do {
            let meals = try context.fetch(request)
            var fatMealIdentifiers = Set<String>()
            
            // Check each meal for fat proteins
            for meal in meals {
                if let entries = meal.entries as? Set<CDEcksteinMealEntry> {
                    for entry in entries {
                        if let foodName = entry.foodName,
                           let category = entry.category,
                           (category == DietRule.DietCategory.proteinFat.rawValue || 
                            category == DietRule.DietCategory.proteinNonFat.rawValue) {
                            
                            // Check if this food is a fat protein
                            if let customFood = customFoods.first(where: { $0.name == foodName }) {
                                if customFood.isFat {
                                    // Create a unique identifier for this meal (date + meal number)
                                    let mealDate = Calendar.current.startOfDay(for: meal.date ?? Date())
                                    let mealIdentifier = "\(mealDate.timeIntervalSince1970)-\(meal.mealNumber)"
                                    fatMealIdentifiers.insert(mealIdentifier)
                                    break // Only count once per meal
                                }
                            }
                        }
                    }
                }
            }
            
            // Update the tracker with the actual count
            let newCount = fatMealIdentifiers.count
            
            let trackerRequest = NSFetchRequest<CDFatMealTracker>(entityName: "CDFatMealTracker")
            trackerRequest.predicate = NSPredicate(format: "weekStartDate == %@ AND user == %@",
                                                 weekStart as NSDate,
                                                 getCurrentUser() as CVarArg)
            
            let trackers = try context.fetch(trackerRequest)
            let tracker: CDFatMealTracker
            
            if let existingTracker = trackers.first {
                tracker = existingTracker
            } else {
                tracker = CDFatMealTracker(context: context)
                tracker.id = UUID()
                tracker.weekStartDate = weekStart
                tracker.fatMealsConsumed = 0
                tracker.createdAt = Date()
                tracker.updatedAt = Date()
                tracker.syncStatus = "pending"
                tracker.user = getCurrentUser()
            }
            
            tracker.fatMealsConsumed = Int32(newCount)
            tracker.updatedAt = Date()
            
            try context.save()
            
            // If this is the current week, update published properties
            if Calendar.current.isDate(weekStart, equalTo: getWeekStartDate(), toGranularity: .day) {
                currentWeekFatMeals = newCount
                canAddFatMeal = newCount < maxFatMealsPerWeek
                fatMealDates = fatMealIdentifiers
            }
            
        } catch {
            print("Error updating fat meal tracking for week: \(error)")
        }
    }
    
    // Get week start date for a specific date
    private func getWeekStartDate(for date: Date) -> Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let daysToSubtract = weekday - 1 // Sunday is 1
        return calendar.date(byAdding: .day, value: -daysToSubtract, to: startOfDay) ?? startOfDay
    }
}