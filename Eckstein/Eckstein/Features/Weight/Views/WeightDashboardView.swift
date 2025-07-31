//
//  WeightDashboardView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

struct WeightDashboardView: View {
    @ObservedObject var viewModel: WeightViewModel
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var healthKitTimer: Timer?
    
    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: UserDefaults.standard.string(forKey: "weightUnit") ?? "kg") ?? .kg
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Current Weight Card
                if let current = viewModel.currentWeight {
                    DashboardWeightCard(
                        weight: current,
                        unit: weightUnit,
                        trend: viewModel.weightTrend,
                        weeklyChange: viewModel.weeklyChange
                    )
                    .padding(.horizontal)
                }
                
                // Steps Counter
                StepsCounterCard()
                    .padding(.horizontal)
                
                // Goal Progress Card
                if viewModel.goalWeight != nil {
                    WeightGoalProgressCard(viewModel: viewModel, unit: weightUnit)
                        .padding(.horizontal)
                }
                
                // Quick Stats
                QuickStatsGrid(viewModel: viewModel, unit: weightUnit)
                    .padding(.horizontal)
                
                // Insights
                InsightsCard(viewModel: viewModel)
                    .padding(.horizontal)
                
                Spacer(minLength: 50)
            }
            .padding(.vertical)
        }
        .onAppear {
            startHealthKitSync()
        }
        .onDisappear {
            stopHealthKitSync()
        }
    }
    
    private func startHealthKitSync() {
        // Initial sync
        if UserDefaults.standard.bool(forKey: "autoSyncHealthKit") {
            Task {
                await HealthKitService.shared.syncWithHealthKit(
                    repository: viewModel.repository
                )
            }
        }
        
        // Set up timer for periodic sync every 30 seconds
        healthKitTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            if UserDefaults.standard.bool(forKey: "autoSyncHealthKit") {
                Task {
                    await HealthKitService.shared.syncWithHealthKit(
                        repository: viewModel.repository
                    )
                }
            }
        }
    }
    
    private func stopHealthKitSync() {
        healthKitTimer?.invalidate()
        healthKitTimer = nil
    }
}

struct DashboardWeightCard: View {
    let weight: Double?
    let unit: WeightUnit
    let trend: WeightTrend
    let weeklyChange: Double
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    private var displayWeight: String {
        guard let weight = weight else { return "--" }
        let displayValue = unit == .lbs ? weight * 2.20462 : weight
        return String(format: "%.1f", displayValue)
    }
    
    private var changeText: String {
        let change = unit == .lbs ? weeklyChange * 2.20462 : weeklyChange
        return String(format: "%+.1f %@/%@", change, unit.rawValue, "week".localized)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("current_weight".localized)
                        .font(.headline)
                    
                    HStack(spacing: 4) {
                        Text(displayWeight)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                        
                        Text(unit.rawValue)
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: trend.icon)
                            .foregroundColor(trend.color)
                        
                        Text(changeText)
                            .font(.subheadline)
                            .foregroundColor(weeklyChange < 0 ? themeManager.accentColor.color : weeklyChange > 0 ? (themeManager.accentColor == .red ? .red : .red) : .secondary)
                    }
                }
                
                Spacer()
                
                // Trend Indicator
                VStack {
                    Image(systemName: trend.icon)
                        .font(.title)
                        .foregroundColor(trend.color)
                    
                    Text(trend.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(trend.color.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct WeightGoalProgressCard: View {
    @ObservedObject var viewModel: WeightViewModel
    let unit: WeightUnit
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    private var remainingWeight: Double? {
        guard let current = viewModel.currentWeight,
              let goal = viewModel.goalWeight else { return nil }
        return abs(goal - current)
    }
    
    private var remainingDisplay: String {
        guard let remaining = remainingWeight else { return "--" }
        let display = unit == .lbs ? remaining * 2.20462 : remaining
        return String(format: "%.1f", display)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("goal_progress".localized, systemImage: "target")
                    .font(.headline)
                
                Spacer()
                
                if let percentage = viewModel.progressPercentage {
                    Text("\(Int(percentage))%")
                        .font(.headline)
                        .foregroundColor(themeManager.accentColor == .defaultMix ? 
                                       themeManager.accentColor.contextColor(for: .weight) : 
                                       themeManager.accentColor.color)
                }
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(height: 12)
                    
                    if let percentage = viewModel.progressPercentage {
                        RoundedRectangle(cornerRadius: 8)
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
                            .frame(width: geometry.size.width * (percentage / 100), height: 12)
                    }
                }
            }
            .frame(height: 12)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(remainingDisplay) \(unit.rawValue) " + "to_go".localized)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    if let days = viewModel.daysToGoal {
                        Text("\(days) " + "days_remaining".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if let estimatedDate = viewModel.estimatedCompletionDate {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("est_completion".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(estimatedDate, style: .date)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(estimatedDate <= viewModel.goalDate ?? Date() ? .green : .orange)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct QuickStatsGrid: View {
    @ObservedObject var viewModel: WeightViewModel
    let unit: WeightUnit
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            QuickStatCard(
                title: "weekly_average".localized,
                value: formatWeight(viewModel.weeklyAverage),
                unit: unit.rawValue,
                icon: "calendar",
                color: .blue
            )
            
            QuickStatCard(
                title: "monthly_average".localized,
                value: formatWeight(viewModel.monthlyAverage),
                unit: unit.rawValue,
                icon: "calendar.badge.clock",
                color: .purple
            )
            
            QuickStatCard(
                title: "total_entries".localized,
                value: "\(viewModel.weightEntries.count)",
                unit: "",
                icon: "list.bullet",
                color: .orange
            )
            
            if let latestEntry = viewModel.weightEntries.first {
                QuickStatCard(
                    title: "last_entry".localized,
                    value: daysAgo(from: latestEntry.date ?? Date()),
                    unit: "",
                    icon: "clock",
                    color: .green
                )
            }
        }
    }
    
    private func formatWeight(_ weight: Double) -> String {
        let display = unit == .lbs ? weight * 2.20462 : weight
        return String(format: "%.1f", display)
    }
    
    private func daysAgo(from date: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: date, to: Date())
        let days = components.day ?? 0
        
        switch days {
        case 0:
            return "today".localized
        case 1:
            return "yesterday".localized
        default:
            return "\(days) " + "days_ago".localized
        }
    }
}

struct QuickStatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(themeManager.accentColor == .defaultMix ? 
                                   themeManager.accentColor.contextColor(for: .weight) : 
                                   themeManager.accentColor.color)
                    .font(.title3)
                
                Spacer()
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}


struct InsightsCard: View {
    @ObservedObject var viewModel: WeightViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    private var insights: [String] {
        var insights: [String] = []
        
        // Trend insight
        switch viewModel.weightTrend {
        case .losing:
            insights.append("losing_weight_insight".localized)
        case .gaining:
            insights.append("gaining_weight_insight".localized)
        case .stable:
            insights.append("stable_weight_insight".localized)
        }
        
        // Progress insight
        if let percentage = viewModel.progressPercentage {
            if percentage >= 75 {
                insights.append("goal_75_percent_insight".localized)
            } else if percentage >= 50 {
                insights.append("goal_50_percent_insight".localized)
            }
        }
        
        // Frequency insight
        if let lastEntry = viewModel.weightEntries.first,
           let daysSince = Calendar.current.dateComponents([.day], from: lastEntry.date ?? Date(), to: Date()).day,
           daysSince > 3 {
            insights.append("days_since_last_entry_insight".localized(String(daysSince)))
        }
        
        return insights
    }
    
    var body: some View {
        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("insights".localized, systemImage: "lightbulb")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(insights, id: \.self) { insight in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundColor(themeManager.accentColor == .defaultMix ? 
                                               themeManager.accentColor.contextColor(for: .weight) : 
                                               themeManager.accentColor.color)
                                .font(.caption)
                                .padding(.top, 2)
                            
                            Text(insight)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
    }
}

