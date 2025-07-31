//
//  CarbLoadManager.swift
//  Eckstein
//
//  Created by Assistant on 17/01/2025.
//

import Foundation
import CoreData
import Combine

@MainActor
class CarbLoadManager: ObservableObject {
    static let shared = CarbLoadManager()
    
    @Published var hasUsedCarbLoadThisWeek: Bool = false
    @Published var carbLoadDate: Date? = nil
    @Published var canUseCarbLoad: Bool = true
    
    private let context = PersistenceController.shared.container.viewContext
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadCurrentWeekData()
        setupWeeklyReset()
    }
    
    // MARK: - Public Methods
    
    func loadCurrentWeekData() {
        let weekStart = getWeekStartDate()
        
        let request = NSFetchRequest<CDCarbLoadTracker>(entityName: "CDCarbLoadTracker")
        request.predicate = NSPredicate(format: "weekStartDate == %@ AND user == %@", 
                                       weekStart as NSDate, 
                                       getCurrentUser() as CVarArg)
        request.fetchLimit = 1
        
        do {
            let trackers = try context.fetch(request)
            if let tracker = trackers.first {
                hasUsedCarbLoadThisWeek = tracker.carbLoadDate != nil
                carbLoadDate = tracker.carbLoadDate
                canUseCarbLoad = !hasUsedCarbLoadThisWeek
            } else {
                // Create new tracker for this week
                createNewWeekTracker()
                hasUsedCarbLoadThisWeek = false
                carbLoadDate = nil
                canUseCarbLoad = true
            }
        } catch {
            print("Error loading carb load tracker: \(error)")
        }
    }
    
    func setCarbLoadDay(date: Date) {
        // Check if carb load can be used for the specific week of the date
        guard canUseCarbLoadForWeek(of: date) else { return }
        
        let weekStart = getWeekStartDate(for: date)
        
        let request = NSFetchRequest<CDCarbLoadTracker>(entityName: "CDCarbLoadTracker")
        request.predicate = NSPredicate(format: "weekStartDate == %@ AND user == %@",
                                       weekStart as NSDate,
                                       getCurrentUser() as CVarArg)
        
        do {
            let trackers = try context.fetch(request)
            let tracker: CDCarbLoadTracker
            
            if let existingTracker = trackers.first {
                tracker = existingTracker
            } else {
                tracker = createNewWeekTracker(weekStart: weekStart)
            }
            
            tracker.carbLoadDate = date
            tracker.updatedAt = Date()
            
            try context.save()
            
            // Update published properties if this is the current week
            if Calendar.current.isDate(weekStart, equalTo: getWeekStartDate(), toGranularity: .day) {
                hasUsedCarbLoadThisWeek = true
                carbLoadDate = date
                canUseCarbLoad = false
            }
            
        } catch {
            print("Error setting carb load day: \(error)")
        }
    }
    
    func removeCarbLoadDay(date: Date) {
        let weekStart = getWeekStartDate(for: date)
        
        let request = NSFetchRequest<CDCarbLoadTracker>(entityName: "CDCarbLoadTracker")
        request.predicate = NSPredicate(format: "weekStartDate == %@ AND user == %@",
                                       weekStart as NSDate,
                                       getCurrentUser() as CVarArg)
        
        do {
            let trackers = try context.fetch(request)
            if let tracker = trackers.first {
                tracker.carbLoadDate = nil
                tracker.updatedAt = Date()
                
                try context.save()
                
                // Update published properties if this is the current week
                if Calendar.current.isDate(weekStart, equalTo: getWeekStartDate(), toGranularity: .day) {
                    hasUsedCarbLoadThisWeek = false
                    carbLoadDate = nil
                    canUseCarbLoad = true
                }
            }
        } catch {
            print("Error removing carb load day: \(error)")
        }
    }
    
    func canUseCarbLoadForWeek(of date: Date) -> Bool {
        let weekStart = getWeekStartDate(for: date)
        
        let request = NSFetchRequest<CDCarbLoadTracker>(entityName: "CDCarbLoadTracker")
        request.predicate = NSPredicate(format: "weekStartDate == %@ AND user == %@",
                                       weekStart as NSDate,
                                       getCurrentUser() as CVarArg)
        
        do {
            let trackers = try context.fetch(request)
            if let tracker = trackers.first {
                return tracker.carbLoadDate == nil
            }
            return true // No tracker means carb load hasn't been used
        } catch {
            print("Error checking carb load availability: \(error)")
            return true
        }
    }
    
    nonisolated func getCarbLoadDateForWeek(of date: Date) -> Date? {
        let weekStart = getWeekStartDate(for: date)
        let context = PersistenceController.shared.container.viewContext
        
        let request = NSFetchRequest<CDCarbLoadTracker>(entityName: "CDCarbLoadTracker")
        request.predicate = NSPredicate(format: "weekStartDate == %@ AND user == %@",
                                       weekStart as NSDate,
                                       getCurrentUser() as CVarArg)
        
        do {
            let trackers = try context.fetch(request)
            return trackers.first?.carbLoadDate
        } catch {
            print("Error getting carb load date: \(error)")
            return nil
        }
    }
    
    nonisolated func isCarbLoadDay(date: Date) -> Bool {
        let calendar = Calendar.current
        let dateStart = calendar.startOfDay(for: date)
        
        if let carbLoadDate = getCarbLoadDateForWeek(of: date) {
            let carbLoadStart = calendar.startOfDay(for: carbLoadDate)
            return calendar.isDate(dateStart, equalTo: carbLoadStart, toGranularity: .day)
        }
        
        return false
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
    
    nonisolated private func getWeekStartDate(for date: Date) -> Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let daysToSubtract = weekday - 1 // Sunday is 1
        return calendar.date(byAdding: .day, value: -daysToSubtract, to: startOfDay) ?? startOfDay
    }
    
    private func createNewWeekTracker(weekStart: Date? = nil) -> CDCarbLoadTracker {
        let tracker = CDCarbLoadTracker(context: context)
        tracker.id = UUID()
        tracker.weekStartDate = weekStart ?? getWeekStartDate()
        tracker.carbLoadDate = nil
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
    
    nonisolated private func getCurrentUser() -> CDUser {
        let context = PersistenceController.shared.container.viewContext
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
        let request = NSFetchRequest<CDCarbLoadTracker>(entityName: "CDCarbLoadTracker")
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
    
    func getCarbLoadHistory(weeks: Int = 4) -> [(weekStart: Date, carbLoadDate: Date?)] {
        let calendar = Calendar.current
        var history: [(weekStart: Date, carbLoadDate: Date?)] = []
        
        for weekOffset in 0..<weeks {
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: getWeekStartDate()) ?? Date()
            
            let request = NSFetchRequest<CDCarbLoadTracker>(entityName: "CDCarbLoadTracker")
            request.predicate = NSPredicate(format: "weekStartDate == %@ AND user == %@", 
                                           weekStart as NSDate, 
                                           getCurrentUser() as CVarArg)
            
            do {
                let trackers = try context.fetch(request)
                let carbLoadDate = trackers.first?.carbLoadDate
                history.append((weekStart: weekStart, carbLoadDate: carbLoadDate))
            } catch {
                print("Error fetching carb load history: \(error)")
                history.append((weekStart: weekStart, carbLoadDate: nil))
            }
        }
        
        return history
    }
}