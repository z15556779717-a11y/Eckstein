//
//  HealthKitService.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation
import HealthKit
import Combine

@MainActor
class HealthKitService: ObservableObject {
    static let shared = HealthKitService()
    
    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false
    @Published var isSyncing = false
    
    private var cancellables = Set<AnyCancellable>()
    
    // HealthKit types we're interested in
    private let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass)!
    private let bodyFatType = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!
    private let muscleMassType = HKObjectType.quantityType(forIdentifier: .leanBodyMass)!
    private let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)!
    
    private let typesToRead: Set<HKObjectType> = {
        return Set([
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!,
            HKObjectType.quantityType(forIdentifier: .leanBodyMass)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!
        ])
    }()
    
    private let typesToWrite: Set<HKSampleType> = {
        return Set([
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!,
            HKObjectType.quantityType(forIdentifier: .leanBodyMass)!
        ])
    }()
    
    private init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return false
        }
        
        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            checkAuthorizationStatus()
            return true
        } catch {
            print("HealthKit authorization failed: \(error)")
            return false
        }
    }
    
    private func checkAuthorizationStatus() {
        let weightStatus = healthStore.authorizationStatus(for: weightType)
        isAuthorized = weightStatus == .sharingAuthorized
    }
    
    // MARK: - Import from HealthKit
    
    func importWeightData(from startDate: Date, to endDate: Date = Date()) async -> [HKQuantitySample] {
        guard isAuthorized else { return [] }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: weightType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    print("Error fetching weight samples: \(error)")
                    continuation.resume(returning: [])
                    return
                }
                
                let weightSamples = samples as? [HKQuantitySample] ?? []
                continuation.resume(returning: weightSamples)
            }
            
            healthStore.execute(query)
        }
    }
    
    func importBodyFatData(from startDate: Date, to endDate: Date = Date()) async -> [HKQuantitySample] {
        guard isAuthorized else { return [] }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: bodyFatType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    print("Error fetching body fat samples: \(error)")
                    continuation.resume(returning: [])
                    return
                }
                
                let bodyFatSamples = samples as? [HKQuantitySample] ?? []
                continuation.resume(returning: bodyFatSamples)
            }
            
            healthStore.execute(query)
        }
    }
    
    func syncWithHealthKit(repository: WeightRepository) async {
        print("HealthKitService.syncWithHealthKit called")
        print("Is authorized: \(isAuthorized)")
        
        if !isAuthorized {
            print("Not authorized, requesting authorization...")
            let granted = await requestAuthorization()
            print("Authorization granted: \(granted)")
            guard granted else { 
                print("Authorization not granted, exiting sync")
                await MainActor.run {
                    isSyncing = false
                }
                return 
            }
        }
        
        await MainActor.run {
            isSyncing = true
        }
        
        // Get last sync date or default to 30 days ago
        let lastSync = UserDefaults.standard.object(forKey: "lastHealthKitSync") as? Date ?? Date().addingTimeInterval(-30 * 24 * 60 * 60)
        
        // Import weight data from HealthKit
        let weightSamples = await importWeightData(from: lastSync)
        let bodyFatSamples = await importBodyFatData(from: lastSync)
        
        // Create a dictionary of body fat by date for quick lookup
        // Also create a list to find closest body fat measurement
        var bodyFatByDate: [Date: Double] = [:]
        var bodyFatList: [(date: Date, percentage: Double)] = []
        
        for sample in bodyFatSamples {
            let date = Calendar.current.startOfDay(for: sample.startDate)
            let bodyFatPercentage = sample.quantity.doubleValue(for: .percent()) * 100
            bodyFatByDate[date] = bodyFatPercentage
            bodyFatList.append((date: sample.startDate, percentage: bodyFatPercentage))
        }
        
        // Convert and save to Core Data
        for sample in weightSamples {
            let weightInKg = sample.quantity.doubleValue(for: .gram()) / 1000.0
            let sampleDate = Calendar.current.startOfDay(for: sample.startDate)
            
            // Check if we already have this entry (by date)
            let existingEntries = repository.fetchAllWeightEntries().filter { entry in
                guard let entryDate = entry.date else { return false }
                return Calendar.current.isDate(entryDate, inSameDayAs: sample.startDate)
            }
            
            if existingEntries.isEmpty {
                // Get body fat for this date if available
                var bodyFat = bodyFatByDate[sampleDate]
                
                // If no exact date match, find the closest body fat measurement within 24 hours
                if bodyFat == nil && !bodyFatList.isEmpty {
                    let closestBodyFat = bodyFatList
                        .map { (date: $0.date, percentage: $0.percentage, timeDiff: abs($0.date.timeIntervalSince(sample.startDate))) }
                        .filter { $0.timeDiff <= 24 * 60 * 60 } // Within 24 hours
                        .min(by: { $0.timeDiff < $1.timeDiff })
                    
                    bodyFat = closestBodyFat?.percentage
                }
                
                // Create new entry
                _ = repository.createWeightEntry(
                    weight: weightInKg,
                    date: sample.startDate,
                    bodyFatPercentage: bodyFat,
                    muscleMass: nil,
                    notes: "Imported from \(sample.sourceRevision.source.name)",
                    source: "HealthKit"
                )
            }
        }
        
        // Update last sync date
        UserDefaults.standard.set(Date(), forKey: "lastHealthKitSync")
        
        await MainActor.run {
            isSyncing = false
        }
    }
    
    // MARK: - Export to HealthKit
    
    func exportWeightToHealthKit(weight: Double, date: Date, unit: WeightUnit) async -> Bool {
        guard isAuthorized else { return false }
        
        let weightInKg = unit == .lbs ? weight / 2.20462 : weight
        let quantity = HKQuantity(unit: .gram(), doubleValue: weightInKg * 1000)
        
        let sample = HKQuantitySample(
            type: weightType,
            quantity: quantity,
            start: date,
            end: date
        )
        
        do {
            try await healthStore.save(sample)
            return true
        } catch {
            print("Error saving weight to HealthKit: \(error)")
            return false
        }
    }
    
    func exportBodyCompositionToHealthKit(bodyFat: Double?, muscleMass: Double?, date: Date) async {
        guard isAuthorized else { return }
        
        var samples: [HKQuantitySample] = []
        
        if let bodyFat = bodyFat {
            let quantity = HKQuantity(unit: .percent(), doubleValue: bodyFat / 100)
            let sample = HKQuantitySample(
                type: bodyFatType,
                quantity: quantity,
                start: date,
                end: date
            )
            samples.append(sample)
        }
        
        if let muscleMass = muscleMass {
            let quantity = HKQuantity(unit: .gram(), doubleValue: muscleMass * 1000)
            let sample = HKQuantitySample(
                type: muscleMassType,
                quantity: quantity,
                start: date,
                end: date
            )
            samples.append(sample)
        }
        
        if !samples.isEmpty {
            do {
                try await healthStore.save(samples)
            } catch {
                print("Error saving body composition to HealthKit: \(error)")
            }
        }
    }
    
    // MARK: - Steps Data
    
    func fetchStepsData(for date: Date) async -> Double {
        guard isAuthorized else { return 0 }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    print("Error fetching steps: \(error)")
                    continuation.resume(returning: 0)
                    return
                }
                
                let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: steps)
            }
            
            healthStore.execute(query)
        }
    }
    
    func fetchAverageSteps(for dateRange: DateRange) async -> Double {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate: Date
        
        switch dateRange {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: endDate) ?? endDate
        case .threeMonths:
            startDate = calendar.date(byAdding: .month, value: -3, to: endDate) ?? endDate
        case .sixMonths:
            startDate = calendar.date(byAdding: .month, value: -6, to: endDate) ?? endDate
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: endDate) ?? endDate
        case .all:
            startDate = calendar.date(byAdding: .year, value: -10, to: endDate) ?? endDate
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: calendar.startOfDay(for: Date()),
                intervalComponents: DateComponents(day: 1)
            )
            
            query.initialResultsHandler = { _, results, error in
                if let error = error {
                    print("Error fetching step statistics: \(error)")
                    continuation.resume(returning: 0)
                    return
                }
                
                var totalSteps: Double = 0
                var dayCount = 0
                
                results?.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    if let sum = statistics.sumQuantity() {
                        totalSteps += sum.doubleValue(for: .count())
                        dayCount += 1
                    }
                }
                
                let average = dayCount > 0 ? totalSteps / Double(dayCount) : 0
                continuation.resume(returning: average)
            }
            
            healthStore.execute(query)
        }
    }
}