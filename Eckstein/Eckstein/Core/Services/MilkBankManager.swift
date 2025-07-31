//
//  MilkBankManager.swift
//  Eckstein
//
//  Created by Assistant on 16/01/2025.
//

import Foundation
import CoreData

class MilkBankManager: ObservableObject {
    static let shared = MilkBankManager()
    
    @Published var todayConsumption: Double = 0
    @Published var availableMilk: Double = 200
    
    private let maxDailyMilk: Double = 200
    private let persistence = PersistenceController.shared
    
    private init() {
        loadTodayConsumption()
    }
    
    // MARK: - Public Methods
    
    func consumeMilk(amount: Double) {
        guard amount > 0 && amount <= availableMilk else { return }
        
        let context = persistence.container.viewContext
        
        // Create new consumption entry
        let consumption = CDMilkConsumption(context: context)
        consumption.id = UUID()
        consumption.amount = amount
        consumption.date = Date()
        consumption.syncStatus = "pending"
        // User will be set by the parent context if needed
        
        do {
            try context.save()
            loadTodayConsumption()
        } catch {
            print("Failed to save milk consumption: \(error)")
        }
    }
    
    func loadTodayConsumption() {
        let context = persistence.container.viewContext
        let request = CDMilkConsumption.fetchRequest()
        
        // Get today's date range
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        request.predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        do {
            let consumptions = try context.fetch(request)
            todayConsumption = consumptions.reduce(0) { $0 + $1.amount }
            availableMilk = max(0, maxDailyMilk - todayConsumption)
        } catch {
            print("Failed to fetch milk consumptions: \(error)")
        }
    }
    
    func getTodayConsumptions() -> [CDMilkConsumption] {
        let context = persistence.container.viewContext
        let request = CDMilkConsumption.fetchRequest()
        
        // Get today's date range
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        request.predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDMilkConsumption.date, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch milk consumptions: \(error)")
            return []
        }
    }
    
    func deleteConsumption(_ consumption: CDMilkConsumption) {
        let context = persistence.container.viewContext
        context.delete(consumption)
        
        do {
            try context.save()
            loadTodayConsumption()
        } catch {
            print("Failed to delete milk consumption: \(error)")
        }
    }
}