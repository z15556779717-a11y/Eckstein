//
//  ProfileDietProgressSection.swift
//  Eckstein
//
//  Created by Eliad Shahar on 23/07/2025.
//

import SwiftUI

struct ProfileDietProgressSection: View {
    @ObservedObject var themeManager: ThemeManager
    @ObservedObject var weightRepository: WeightRepository
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @Binding var showingDietSettings: Bool
    
    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: UserDefaults.standard.string(forKey: "weightUnit") ?? "kg") ?? .kg
    }
    
    @ViewBuilder
    var body: some View {
        Section {
            HStack {
                Label("days_on_diet".localized, systemImage: "calendar")
                    .themedForegroundColor(themeManager.accentColor, context: .general)
                Spacer()
                Text("\(themeManager.daysOnDiet)")
                    .font(.headline)
            }
            
            if themeManager.startingWeight > 0,
               let currentWeight = weightRepository.latestEntry?.weightKg {
                HStack {
                    Label("starting_weight".localized, systemImage: "scalemass")
                        .themedForegroundColor(themeManager.accentColor, context: .general)
                    Spacer()
                    let displayStartWeight = weightUnit == .lbs ? themeManager.startingWeight * 2.20462 : themeManager.startingWeight
                    Text("\(displayStartWeight, specifier: "%.1f") \(weightUnit.rawValue)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Label("current_weight".localized, systemImage: "scalemass.fill")
                        .themedForegroundColor(themeManager.accentColor, context: .general)
                    Spacer()
                    let displayCurrentWeight = weightUnit == .lbs ? currentWeight * 2.20462 : currentWeight
                    Text("\(displayCurrentWeight, specifier: "%.1f") \(weightUnit.rawValue)")
                        .font(.headline)
                }
                
                HStack {
                    Label("progress".localized, systemImage: "chart.line.uptrend.xyaxis")
                        .themedForegroundColor(themeManager.accentColor, context: .general)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        let weightDifference = currentWeight - themeManager.startingWeight
                        let displayDiff = weightUnit == .lbs ? weightDifference * 2.20462 : weightDifference
                        Text("\(weightDifference > 0 ? "+" : "")\(displayDiff, specifier: "%.1f") \(weightUnit.rawValue)")
                            .font(.headline)
                            .foregroundColor(weightDifference < 0 ? .green : weightDifference > 0 ? .red : .secondary)
                        
                        // Add fat percentage loss if available
                        if let latestEntry = weightRepository.latestEntry,
                           latestEntry.bodyFatPercentage > 0,
                           let startingFatPercentage = getStartingFatPercentage() {
                            let fatDifference = latestEntry.bodyFatPercentage - startingFatPercentage
                            Text("\(fatDifference > 0 ? "+" : "")\(fatDifference, specifier: "%.1f")% \("fat_suffix".localized)")
                                .font(.caption)
                                .foregroundColor(fatDifference < 0 ? .green : fatDifference > 0 ? .red : .secondary)
                        }
                    }
                }
            }
            
            Button(action: {
                showingDietSettings = true
            }) {
                HStack {
                    Image(systemName: "pencil.circle")
                    Text(themeManager.dietStartDate == nil ? "set_diet_start_info".localized : "edit_diet_info".localized)
                }
                .themedForegroundColor(themeManager.accentColor)
            }
        } header: {
            Text("diet_progress".localized)
        }
        .id(localizationManager.currentLanguage)
    }
    
    private func getStartingFatPercentage() -> Double? {
        guard let dietStartDate = themeManager.dietStartDate else { return nil }
        
        // Find the weight entry closest to the diet start date
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: dietStartDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? dietStartDate
        
        // Look for entries within a week of the start date
        let weekBefore = calendar.date(byAdding: .day, value: -7, to: dietStartDate) ?? dietStartDate
        let weekAfter = calendar.date(byAdding: .day, value: 7, to: dietStartDate) ?? dietStartDate
        
        let relevantEntries = weightRepository.weightEntries
            .filter { entry in
                guard let entryDate = entry.date else { return false }
                return entryDate >= weekBefore && entryDate <= weekAfter
            }
            .sorted { ($0.date ?? Date()) < ($1.date ?? Date()) }
        
        // Find the entry closest to the diet start date
        return relevantEntries
            .min(by: { abs(($0.date ?? Date()).timeIntervalSince(dietStartDate)) < abs(($1.date ?? Date()).timeIntervalSince(dietStartDate)) })?
            .bodyFatPercentage
    }
}