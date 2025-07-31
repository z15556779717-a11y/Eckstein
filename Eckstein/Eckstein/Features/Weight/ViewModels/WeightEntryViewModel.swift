//
//  WeightEntryViewModel.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation
import Combine

@MainActor
class WeightEntryViewModel: ObservableObject {
    @Published var weightString = ""
    @Published var selectedDate = Date()
    @Published var notes = ""
    @Published var bodyFatString = ""
    @Published var muscleMassString = ""
    @Published var isShowingError = false
    @Published var errorMessage = ""
    
    private let repository: WeightRepository
    private let unit: WeightUnit
    
    var weightPlaceholder: String {
        switch unit {
        case .kg:
            return "70.5"
        case .lbs:
            return "155.0"
        }
    }
    
    var unitLabel: String {
        unit.rawValue
    }
    
    init(repository: WeightRepository? = nil) {
        self.repository = repository ?? ServiceContainer.shared.weightRepository
        self.unit = WeightUnit(rawValue: UserDefaults.standard.string(forKey: "weightUnit") ?? "kg") ?? .kg
    }
    
    func saveWeight(completion: @escaping (Bool) -> Void) {
        guard let weight = validateWeight() else {
            showError("Please enter a valid weight")
            completion(false)
            return
        }
        
        let bodyFat = Double(bodyFatString)
        let muscleMass = Double(muscleMassString)
        
        // Validate body fat percentage if provided
        if let bodyFat = bodyFat, (bodyFat < 0 || bodyFat > 100) {
            showError("Body fat percentage must be between 0 and 100")
            completion(false)
            return
        }
        
        let weightInKg = unit == .lbs ? weight * 0.453592 : weight
        
        let entry = repository.createWeightEntry(
            weight: weightInKg,
            date: selectedDate,
            bodyFatPercentage: bodyFat,
            muscleMass: muscleMass,
            notes: notes.isEmpty ? nil : notes
        )
        
        // Export to HealthKit if enabled
        if UserDefaults.standard.bool(forKey: "autoSyncHealthKit") {
            Task {
                let exported = await HealthKitService.shared.exportWeightToHealthKit(
                    weight: weight,
                    date: selectedDate,
                    unit: unit
                )
                
                if exported && (bodyFat != nil || muscleMass != nil) {
                    await HealthKitService.shared.exportBodyCompositionToHealthKit(
                        bodyFat: bodyFat,
                        muscleMass: muscleMass,
                        date: selectedDate
                    )
                }
            }
        }
        
        completion(true)
    }
    
    private func validateWeight() -> Double? {
        let cleanedString = weightString.replacingOccurrences(of: ",", with: ".")
        guard let weight = Double(cleanedString) else { return nil }
        
        // Reasonable weight range: 20-300 kg (44-661 lbs)
        let minWeight: Double = unit == .kg ? 20 : 44
        let maxWeight: Double = unit == .kg ? 300 : 661
        
        guard weight >= minWeight && weight <= maxWeight else {
            showError("Weight must be between \(Int(minWeight)) and \(Int(maxWeight)) \(unitLabel)")
            return nil
        }
        
        return weight
    }
    
    func quickSetToday() {
        selectedDate = Date()
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        isShowingError = true
    }
}

enum WeightUnit: String, CaseIterable {
    case kg = "kg"
    case lbs = "lbs"
    
    var displayName: String {
        switch self {
        case .kg:
            return "Kilograms"
        case .lbs:
            return "Pounds"
        }
    }
}