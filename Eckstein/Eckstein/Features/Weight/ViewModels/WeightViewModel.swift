//
//  WeightViewModel.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation
import Combine
import CoreData

@MainActor
class WeightViewModel: ObservableObject {
    @Published var weightEntries: [CDWeightEntry] = []
    @Published var goalWeight: Double?
    @Published var goalDate: Date?
    @Published var startWeight: Double?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    let repository: WeightRepository
    private var cancellables = Set<AnyCancellable>()
    
    init(repository: WeightRepository? = nil) {
        let context = PersistenceController.shared.container.viewContext
        self.repository = repository ?? WeightRepository(context: context)
        setupObservers()
        loadData()
    }
    
    private func setupObservers() {
        // Observe Core Data changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadData()
            }
            .store(in: &cancellables)
        
        // Load goal from UserDefaults
        UserDefaults.standard.publisher(for: \.goalWeight)
            .map { $0 as Double? }
            .assign(to: &$goalWeight)
        
        UserDefaults.standard.publisher(for: \.goalDate)
            .map { $0 as Date? }
            .assign(to: &$goalDate)
        
        UserDefaults.standard.publisher(for: \.startWeight)
            .map { $0 as Double? }
            .assign(to: &$startWeight)
        
        // Listen for scale weight measurements
        NotificationCenter.default.publisher(for: .scaleWeightReceived)
            .sink { [weak self] notification in
                self?.handleScaleWeight(notification)
            }
            .store(in: &cancellables)
    }
    
    func loadData() {
        isLoading = true
        
        Task {
            do {
                // Fetch all weight entries
                weightEntries = repository.fetchAllWeightEntries()
                    .sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }
                
                // Load goal data from UserDefaults (already loaded via publishers)
                // The goal data is automatically loaded through the UserDefaults publishers set up in setupObservers()
                
                isLoading = false
            } catch {
                errorMessage = "Failed to load weight data: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    func refresh() {
        loadData()
    }
    
    func setGoal(weight: Double, targetDate: Date) {
        repository.setGoal(targetWeight: weight, targetDate: targetDate)
        loadData()
    }
    
    func removeGoal() {
        repository.removeGoal()
        loadData()
    }
    
    func deleteEntry(_ entry: CDWeightEntry) {
        repository.deleteWeightEntry(entry)
        loadData()
    }
    
    // MARK: - Scale Integration
    
    private func handleScaleWeight(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let weight = userInfo["weight"] as? Double,
              let source = userInfo["source"] as? String else { return }
        
        let notes = userInfo["notes"] as? String
        
        // Create new weight entry from scale
        let entry = repository.createWeightEntry(
            weight: weight,
            date: Date(),
            bodyFatPercentage: nil,
            muscleMass: nil,
            notes: notes,
            source: source
        )
        
        // Export to HealthKit if enabled
        if UserDefaults.standard.bool(forKey: "autoSyncHealthKit") {
            Task {
                let unit = WeightUnit(rawValue: UserDefaults.standard.string(forKey: "weightUnit") ?? "kg") ?? .kg
                _ = await HealthKitService.shared.exportWeightToHealthKit(
                    weight: weight,
                    date: entry.date ?? Date(),
                    unit: unit
                )
            }
        }
        
        // Reload data to show the new entry
        loadData()
    }
    
    // MARK: - Statistics
    
    var currentWeight: Double? {
        repository.fetchLatestWeightEntry()?.weightKg
    }
    
    var weeklyAverage: Double {
        repository.getAverageWeight(for: .week) ?? 0.0
    }
    
    var monthlyAverage: Double {
        repository.getAverageWeight(for: .month) ?? 0.0
    }
    
    var weightTrend: WeightTrend {
        repository.getWeightTrend()
    }
    
    var weeklyChange: Double {
        repository.getAverageWeeklyChange() ?? 0.0
    }
    
    var progressPercentage: Double? {
        guard let current = currentWeight,
              let goal = goalWeight,
              let start = startWeight else {
            return nil
        }
        
        let totalDistance = abs(goal - start)
        guard totalDistance > 0 else { return 0 }
        
        // Calculate progress based on direction
        if start > goal {
            // Losing weight: start is higher than goal
            let progress = start - current
            let percentage = (progress / totalDistance) * 100
            return max(0, min(100, percentage))
        } else {
            // Gaining weight: start is lower than goal
            let progress = current - start
            let percentage = (progress / totalDistance) * 100
            return max(0, min(100, percentage))
        }
    }
    
    var daysToGoal: Int? {
        guard let targetDate = goalDate else { return nil }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: targetDate)
        return components.day
    }
    
    var estimatedCompletionDate: Date? {
        guard let current = currentWeight,
              let goal = goalWeight else {
            return nil
        }
        
        let weeklyChange = abs(repository.getAverageWeeklyChange() ?? 0.0)
        guard weeklyChange > 0.1 else { return nil } // Need at least 0.1 kg/week progress
        
        let remaining = abs(goal - current)
        let weeksNeeded = remaining / weeklyChange
        
        return Date().addingTimeInterval(weeksNeeded * 7 * 24 * 60 * 60)
    }
    
    // MARK: - Chart Data
    
    func chartData(for range: DateRange) -> [CDWeightEntry] {
        repository.fetchWeightEntries(for: range)
            .sorted { ($0.date ?? Date()) < ($1.date ?? Date()) }
    }
    
    // MARK: - Entry Management
    
    func createEntry(weight: Double, date: Date, notes: String? = nil) {
        _ = repository.createWeightEntry(
            weight: weight,
            date: date,
            notes: notes
        )
        loadData()
    }
    
    func updateEntry(_ entry: CDWeightEntry, weight: Double, notes: String?) {
        repository.updateWeightEntry(entry, weight: weight, notes: notes)
        loadData()
    }
}

// MARK: - UserDefaults Extensions

extension UserDefaults {
    @objc dynamic var goalWeight: Double {
        get { double(forKey: "goalWeight") }
        set { set(newValue, forKey: "goalWeight") }
    }
    
    @objc dynamic var goalDate: Date? {
        get { object(forKey: "goalDate") as? Date }
        set { set(newValue, forKey: "goalDate") }
    }
    
    @objc dynamic var startWeight: Double {
        get { double(forKey: "startWeight") }
        set { set(newValue, forKey: "startWeight") }
    }
}