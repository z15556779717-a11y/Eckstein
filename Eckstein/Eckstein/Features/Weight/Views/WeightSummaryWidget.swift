//
//  WeightSummaryWidget.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

struct WeightSummaryWidget: View {
    @StateObject private var viewModel = WeightViewModel()
    var onTap: (() -> Void)?
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: UserDefaults.standard.string(forKey: "weightUnit") ?? "kg") ?? .kg
    }
    
    private var currentWeightDisplay: String {
        guard let weight = viewModel.currentWeight else { return "--" }
        let display = weightUnit == .lbs ? weight * 2.20462 : weight
        return String(format: "%.1f", display)
    }
    
    private var changeDisplay: String {
        let change = viewModel.weeklyChange
        let display = weightUnit == .lbs ? change * 2.20462 : change
        return String(format: "%+.1f", display)
    }
    
    var body: some View {
        Button(action: {
            onTap?()
        }) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: "scalemass")
                    .font(.title2)
                    .foregroundColor(themeManager.accentColor == .defaultMix ? 
                                   themeManager.accentColor.contextColor(for: .weight) : 
                                   themeManager.accentColor.color)
                    .frame(width: 50, height: 50)
                    .background((themeManager.accentColor == .defaultMix ? 
                               themeManager.accentColor.contextColor(for: .weight) : 
                               themeManager.accentColor.color).opacity(0.1))
                    .cornerRadius(12)
                
                // Weight Info
                VStack(alignment: .leading, spacing: 4) {
                    Text("current_weight".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Text(currentWeightDisplay)
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text(weightUnit.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Trend
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.weightTrend.icon)
                            .font(.caption)
                        Text(changeDisplay)
                            .font(.caption)
                    }
                    .foregroundColor(viewModel.weeklyChange < 0 ? .green : viewModel.weeklyChange > 0 ? .red : .secondary)
                    
                    Text("per_week".localized)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Compact version for smaller spaces
struct WeightSummaryCompactWidget: View {
    @StateObject private var viewModel = WeightViewModel()
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: UserDefaults.standard.string(forKey: "weightUnit") ?? "kg") ?? .kg
    }
    
    private var currentWeightDisplay: String {
        guard let weight = viewModel.currentWeight else { return "--" }
        let display = weightUnit == .lbs ? weight * 2.20462 : weight
        return String(format: "%.1f", display)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "scalemass")
                .font(.title3)
                .foregroundColor(themeManager.accentColor == .defaultMix ? 
                               themeManager.accentColor.contextColor(for: .weight) : 
                               themeManager.accentColor.color)
            
            Text(currentWeightDisplay)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(weightUnit.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 2) {
                Image(systemName: viewModel.weightTrend.icon)
                    .font(.caption2)
                Text(viewModel.weightTrend.description)
                    .font(.caption2)
            }
            .foregroundColor(viewModel.weightTrend.color)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// Weight Progress for Goal Widget
struct WeightGoalProgressWidget: View {
    @StateObject private var viewModel = WeightViewModel()
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        if viewModel.goalWeight != nil {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("weight_goal".localized, systemImage: "target")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    if let percentage = viewModel.progressPercentage {
                        Text("\(Int(percentage))%")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.accentColor == .defaultMix ? 
                                           themeManager.accentColor.contextColor(for: .weight) : 
                                           themeManager.accentColor.color)
                    }
                }
                
                // Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray5))
                            .frame(height: 8)
                        
                        if let percentage = viewModel.progressPercentage {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [themeManager.accentColor == .defaultMix ? 
                                                              themeManager.accentColor.contextColor(for: .weight) : 
                                                              themeManager.accentColor.color, 
                                                              themeManager.accentColor == .defaultMix ? 
                                                              Color.green : 
                                                              themeManager.accentColor.color]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(width: geometry.size.width * (percentage / 100), height: 8)
                        }
                    }
                }
                .frame(height: 8)
                
                if let days = viewModel.daysToGoal {
                    Text("days_remaining".localized(days))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}