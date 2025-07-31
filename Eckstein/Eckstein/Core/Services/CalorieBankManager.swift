//
//  CalorieBankManager.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation
import CoreData
import Combine

class CalorieBankManager: ObservableObject {
    @Published var currentBalance: Int = 0
    @Published var todayAvailable: Int = 150 // Today's 150 calories
    @Published var todayUsed: Int = 0
    @Published var transactionHistory: [CalorieBankTransaction] = []
    
    private let context: NSManagedObjectContext
    private let dailyFreeCalories = 150
    private let maxBankBalance = 1500 // 10 days worth
    private var cancellables = Set<AnyCancellable>()
    
    static let shared = CalorieBankManager()
    
    private init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        loadCurrentBalance()
        setupDailyDepositTimer()
    }
    
    func loadCurrentBalance() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Check if there's a reset date
        let resetDate = UserDefaults.standard.object(forKey: "calorieBankResetDate") as? Date
        
        // Get all transactions
        let allTransactionsRequest: NSFetchRequest<CDCalorieBank> = CDCalorieBank.fetchRequest()
        allTransactionsRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CDCalorieBank.date, ascending: true)]
        
        do {
            var allTransactions = try context.fetch(allTransactionsRequest)
            
            // Filter transactions if reset date exists
            if let reset = resetDate {
                let resetStart = calendar.startOfDay(for: reset)
                allTransactions = allTransactions.filter { transaction in
                    guard let date = transaction.date else { return false }
                    return date >= resetStart
                }
            }
            
            // Find the first day with any activity (deposit or withdrawal) after reset
            var firstActivityDate: Date? = nil
            for transaction in allTransactions {
                if let date = transaction.date {
                    firstActivityDate = calendar.startOfDay(for: date)
                    break
                }
            }
            
            // Determine start date: reset date, first activity, or today
            let startDate: Date
            if let reset = resetDate {
                startDate = calendar.startOfDay(for: reset)
            } else if let firstActivity = firstActivityDate {
                startDate = firstActivity
            } else {
                startDate = today
            }
            
            // Calculate total days since start (excluding today for saved balance)
            let daysSinceStart = calendar.dateComponents([.day], from: startDate, to: today).day ?? 0
            
            // Calculate saved balance (days before today × 150, max 1500)
            // Don't include today's allowance in the saved balance
            let savedCalories = min(daysSinceStart * dailyFreeCalories, maxBankBalance)
            
            // Calculate total withdrawals (only from filtered transactions)
            let totalWithdrawals = allTransactions
                .filter { $0.caloriesSaved < 0 }
                .reduce(0) { $0 + abs(Int($1.caloriesSaved)) }
            
            // Current balance = saved calories - total withdrawals
            let calculatedBalance = max(0, savedCalories - totalWithdrawals)
            currentBalance = min(calculatedBalance, maxBankBalance)
            
            // Calculate today's usage
            let todayRequest: NSFetchRequest<CDCalorieBank> = CDCalorieBank.fetchRequest()
            todayRequest.predicate = NSPredicate(
                format: "date >= %@ AND date < %@",
                today as NSDate,
                calendar.date(byAdding: .day, value: 1, to: today)! as NSDate
            )
            
            let todayTransactions = try context.fetch(todayRequest)
            
            // Today's used calories (withdrawals)
            todayUsed = abs(todayTransactions
                .filter { $0.caloriesSaved < 0 }
                .reduce(0) { $0 + Int($1.caloriesSaved) })
            
            // Always have 150 available today (unless already used)
            todayAvailable = max(0, dailyFreeCalories - todayUsed)
            
            // Build transaction history
            var history: [CalorieBankTransaction] = []
            let historyTransactions = try context.fetch(CDCalorieBank.fetchRequest())
            
            for transaction in historyTransactions {
                history.append(CalorieBankTransaction(
                    id: transaction.id ?? UUID(),
                    date: transaction.date ?? Date(),
                    amount: abs(Int(transaction.caloriesSaved)),
                    type: transaction.caloriesSaved > 0 ? .deposit : .withdrawal,
                    balance: 0, // We'll calculate running balance if needed
                    foodName: transaction.foodName
                ))
            }
            
            transactionHistory = history.sorted { $0.date > $1.date }
            
        } catch {
            print("Error loading calorie bank: \(error)")
        }
    }
    
    private func setupDailyDepositTimer() {
        // Check if daily deposit has been made
        Timer.publish(every: 3600, on: .main, in: .common) // Check every hour
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkAndMakeDailyDeposit()
            }
            .store(in: &cancellables)
        
        // Initial check
        checkAndMakeDailyDeposit()
    }
    
    private func checkAndMakeDailyDeposit() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Check if deposit already made today
        let request: NSFetchRequest<CDCalorieBank> = CDCalorieBank.fetchRequest()
        request.predicate = NSPredicate(
            format: "date >= %@ AND date < %@ AND caloriesSaved == %d",
            today as NSDate,
            calendar.date(byAdding: .day, value: 1, to: today)! as NSDate,
            dailyFreeCalories
        )
        
        do {
            let count = try context.count(for: request)
            if count == 0 {
                // Make daily deposit
                deposit(calories: dailyFreeCalories, isAutomatic: true)
            }
        } catch {
            print("Error checking daily deposit: \(error)")
        }
    }
    
    func deposit(calories: Int, isAutomatic: Bool = false) {
        guard calories > 0 else { return }
        
        let transaction = CDCalorieBank(context: context)
        transaction.id = UUID()
        transaction.date = Date()
        transaction.caloriesSaved = Int32(calories)
        transaction.syncStatus = "pending"
        
        // Ensure we don't exceed max balance
        let newBalance = currentBalance + calories
        if newBalance > maxBankBalance {
            transaction.caloriesSaved = Int32(maxBankBalance - currentBalance)
        }
        
        do {
            try context.save()
            loadCurrentBalance()
        } catch {
            print("Error saving deposit: \(error)")
        }
    }
    
    func withdraw(calories: Int) -> Bool {
        let totalAvailable = todayAvailable + currentBalance
        guard calories > 0, calories <= totalAvailable else { return false }
        
        let transaction = CDCalorieBank(context: context)
        transaction.id = UUID()
        transaction.date = Date()
        transaction.caloriesSaved = -Int32(calories)
        transaction.syncStatus = "pending"
        
        do {
            try context.save()
            loadCurrentBalance()
            return true
        } catch {
            print("Error saving withdrawal: \(error)")
            return false
        }
    }
    
    func logCalorieConsumption(foodName: String, calories: Int) -> Bool {
        let totalAvailable = todayAvailable + currentBalance
        guard calories > 0, calories <= totalAvailable else { return false }
        
        let transaction = CDCalorieBank(context: context)
        transaction.id = UUID()
        transaction.date = Date()
        transaction.caloriesSaved = -Int32(calories)
        transaction.foodName = foodName
        transaction.syncStatus = "pending"
        
        do {
            try context.save()
            loadCurrentBalance()
            return true
        } catch {
            print("Error saving calorie consumption: \(error)")
            return false
        }
    }
    
    func getTodayTransactions() -> [CalorieBankTransaction] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return transactionHistory.filter { transaction in
            calendar.isDate(transaction.date, inSameDayAs: today) && transaction.type == .withdrawal
        }
    }
    
    func deleteTransaction(_ transaction: CalorieBankTransaction) {
        let request: NSFetchRequest<CDCalorieBank> = CDCalorieBank.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", transaction.id as CVarArg)
        
        do {
            let results = try context.fetch(request)
            if let toDelete = results.first {
                context.delete(toDelete)
                try context.save()
                loadCurrentBalance()
            }
        } catch {
            print("Error deleting transaction: \(error)")
        }
    }
    
    func calculateUnusedCalories(targetCalories: Int, consumedCalories: Int) -> Int {
        let unusedCalories = targetCalories - consumedCalories
        return max(0, unusedCalories)
    }
    
    func endOfDayProcessing(targetCalories: Int, consumedCalories: Int) {
        let unusedCalories = calculateUnusedCalories(
            targetCalories: targetCalories,
            consumedCalories: consumedCalories
        )
        
        if unusedCalories > 0 {
            deposit(calories: unusedCalories, isAutomatic: false)
        }
    }
    
    func getTransactionHistory(days: Int = 30) -> [CalorieBankTransaction] {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        return transactionHistory.filter { $0.date >= startDate }
    }
    
    func loadBalanceForDate(_ date: Date) -> (todayAvailable: Int, todayUsed: Int) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // For historical dates, always return the standard daily allowance
        let todayRequest: NSFetchRequest<CDCalorieBank> = CDCalorieBank.fetchRequest()
        todayRequest.predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        do {
            let todayTransactions = try context.fetch(todayRequest)
            
            // Calculate used calories (withdrawals)
            let todayUsed = abs(todayTransactions
                .filter { $0.caloriesSaved < 0 }
                .reduce(0) { $0 + Int($1.caloriesSaved) })
            
            // For historical dates, available is always the daily allowance minus what was used
            let todayAvailable = max(0, dailyFreeCalories - todayUsed)
            
            return (todayAvailable, todayUsed)
        } catch {
            print("Error loading balance for date: \(error)")
            return (dailyFreeCalories, 0)
        }
    }
    
    func resetFromDate(_ date: Date) {
        let calendar = Calendar.current
        let resetDate = calendar.startOfDay(for: date)
        
        // Store the reset date in UserDefaults
        UserDefaults.standard.set(resetDate, forKey: "calorieBankResetDate")
        
        // Reload the balance with the new reset date
        loadCurrentBalance()
    }
    
    func getWeeklyStats() -> CalorieBankStats {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        let today = calendar.startOfDay(for: Date())
        
        // Count days with activity in the last week
        var daysWithActivity = 0
        for dayOffset in 0..<7 {
            guard let dayToCheck = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let dayStart = calendar.startOfDay(for: dayToCheck)
            
            let hasActivity = transactionHistory.contains { transaction in
                calendar.isDate(transaction.date, inSameDayAs: dayStart)
            }
            
            if hasActivity {
                daysWithActivity += 1
            }
        }
        
        // Total deposits = days with activity * 150
        let totalDeposits = daysWithActivity * dailyFreeCalories
        
        // Total withdrawals from actual transactions
        let weekTransactions = transactionHistory.filter { $0.date >= weekAgo }
        let totalWithdrawals = weekTransactions
            .filter { $0.type == .withdrawal }
            .reduce(0) { $0 + abs($1.amount) }
        
        return CalorieBankStats(
            totalDeposits: totalDeposits,
            totalWithdrawals: totalWithdrawals,
            netChange: totalDeposits - totalWithdrawals,
            averageDailyDeposit: daysWithActivity > 0 ? totalDeposits / daysWithActivity : 0
        )
    }
}

struct CalorieBankTransaction: Identifiable {
    let id: UUID
    let date: Date
    let amount: Int
    let type: TransactionType
    let balance: Int
    let foodName: String?
    
    enum TransactionType {
        case deposit
        case withdrawal
    }
}

struct CalorieBankStats {
    let totalDeposits: Int
    let totalWithdrawals: Int
    let netChange: Int
    let averageDailyDeposit: Int
}