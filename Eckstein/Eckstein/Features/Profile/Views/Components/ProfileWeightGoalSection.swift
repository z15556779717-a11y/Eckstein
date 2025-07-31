//
//  ProfileWeightGoalSection.swift
//  Eckstein
//
//  Created by Assistant on 23/07/2025.
//

import SwiftUI

struct ProfileWeightGoalSection: View {
    @ObservedObject var themeManager: ThemeManager
    @ObservedObject var weightRepository: WeightRepository
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var showingGoalSettings = false
    
    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: UserDefaults.standard.string(forKey: "weightUnit") ?? "kg") ?? .kg
    }
    
    private var currentWeight: Double? {
        weightRepository.latestEntry?.weightKg
    }
    
    private var goalWeight: Double? {
        UserDefaults.standard.object(forKey: "goalWeight") as? Double
    }
    
    private var goalDate: Date? {
        UserDefaults.standard.object(forKey: "goalDate") as? Date
    }
    
    @ViewBuilder
    var body: some View {
        Section {
            if let goal = goalWeight, let current = currentWeight {
                HStack {
                    Label("goal_weight".localized, systemImage: "target")
                        .themedForegroundColor(themeManager.accentColor, context: .general)
                    Spacer()
                    let displayGoal = weightUnit == .lbs ? goal * 2.20462 : goal
                    Text("\(displayGoal, specifier: "%.1f") \(weightUnit.rawValue)")
                        .font(.headline)
                }
                
                HStack {
                    Label("progress".localized, systemImage: "chart.line.uptrend.xyaxis")
                        .themedForegroundColor(themeManager.accentColor, context: .general)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        let difference = goal - current
                        let displayDiff = weightUnit == .lbs ? abs(difference) * 2.20462 : abs(difference)
                        Text("\(displayDiff, specifier: "%.1f") \(weightUnit.rawValue) \("to_go".localized)")
                            .font(.headline)
                            .foregroundColor(difference > 0 ? .orange : .green)
                        
                        if let targetDate = goalDate {
                            let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: targetDate).day ?? 0
                            Text("\(daysRemaining) \("days".localized)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Button(action: {
                showingGoalSettings = true
            }) {
                HStack {
                    Image(systemName: "target")
                    Text(goalWeight == nil ? "set_goal".localized : "update_goal".localized)
                }
                .themedForegroundColor(themeManager.accentColor)
            }
        } header: {
            Text("weight_goal".localized)
        }
        .sheet(isPresented: $showingGoalSettings) {
            WeightGoalView(viewModel: WeightViewModel())
        }
        .id(localizationManager.currentLanguage)
    }
}