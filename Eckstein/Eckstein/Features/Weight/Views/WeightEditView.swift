//
//  WeightEditView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

struct WeightEditView: View {
    let entry: CDWeightEntry
    @ObservedObject var viewModel: WeightViewModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @State private var weightString: String = ""
    @State private var notes: String = ""
    @State private var bodyFatString: String = ""
    @State private var muscleMassString: String = ""
    @State private var entryDate: Date = Date()
    
    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: UserDefaults.standard.string(forKey: "weightUnit") ?? "kg") ?? .kg
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("weight".localized) {
                    HStack {
                        TextField("weight".localized, text: $weightString)
                            .keyboardType(.decimalPad)
                        
                        Text(weightUnit.rawValue)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("body_composition".localized) {
                    HStack {
                        TextField("\("body_fat".localized) \("percentage_symbol".localized)", text: $bodyFatString)
                            .keyboardType(.decimalPad)
                        
                        Text("percentage_symbol".localized)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        TextField("muscle_mass".localized, text: $muscleMassString)
                            .keyboardType(.decimalPad)
                        
                        Text(weightUnit.rawValue)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("notes".localized) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
                
                Section("entry_details".localized) {
                    DatePicker(
                        "date".localized,
                        selection: $entryDate,
                        in: ...Date(),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    
                    if let source = entry.source {
                        HStack {
                            Text("source".localized)
                            Spacer()
                            Text(localizedSource(source))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("edit_entry".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save".localized) {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadData()
        }
    }
    
    private func loadData() {
        let displayWeight = weightUnit == .lbs ? entry.weightKg * 2.20462 : entry.weightKg
        weightString = String(format: "%.1f", displayWeight)
        notes = entry.notes ?? ""
        entryDate = entry.date ?? Date()
        
        // Safely read body composition data
        if let bodyFat = try? entry.value(forKey: "bodyFatPercentage") as? Double,
           bodyFat > 0 {
            bodyFatString = String(format: "%.1f", bodyFat)
        }
        
        if let muscleMassKg = try? entry.value(forKey: "muscleMass") as? Double,
           muscleMassKg > 0 {
            let muscleMass = weightUnit == .lbs ? muscleMassKg * 2.20462 : muscleMassKg
            muscleMassString = String(format: "%.1f", muscleMass)
        }
    }
    
    private func saveChanges() {
        guard let weight = Double(weightString.replacingOccurrences(of: ",", with: ".")) else { return }
        
        let weightInKg = weightUnit == .lbs ? weight * 0.453592 : weight
        let bodyFat = Double(bodyFatString)
        let muscleMass = Double(muscleMassString)
        let muscleMassInKg = weightUnit == .lbs ? (muscleMass ?? 0) * 0.453592 : (muscleMass ?? 0)
        
        entry.weightKg = weightInKg
        
        // Safely set body composition data
        do {
            entry.setValue(bodyFat ?? 0, forKey: "bodyFatPercentage")
            entry.setValue(muscleMassInKg, forKey: "muscleMass")
        } catch {
            print("Warning: Unable to set body composition data")
        }
        
        entry.notes = notes.isEmpty ? nil : notes
        entry.date = entryDate
        
        viewModel.repository.updateWeightEntry(entry, weight: weightInKg, notes: notes.isEmpty ? nil : notes)
        
        dismiss()
    }
    
    private func localizedSource(_ source: String) -> String {
        switch source.lowercased() {
        case "manual":
            return "manual".localized
        case "scale", "xiaomi":
            return "xiaomi_scale".localized
        case "health", "healthkit":
            return "apple_health".localized
        default:
            return source.capitalized
        }
    }
}