//
//  WeightAnalyticsView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI
import Charts

struct WeightAnalyticsView: View {
    @ObservedObject var viewModel: WeightViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var selectedPeriod: AnalyticsPeriod = .month
    @State private var showingDetailedStats = false
    
    enum AnalyticsPeriod: String, CaseIterable {
        case week = "week"
        case month = "month"
        case threeMonths = "threeMonths"
        case sixMonths = "sixMonths"
        case year = "year"
        case all = "all"
        
        var localizedName: String {
            switch self {
            case .week: return "week".localized
            case .month: return "month".localized
            case .threeMonths: return "3_months".localized
            case .sixMonths: return "6_months".localized
            case .year: return "year".localized
            case .all: return "all_time".localized
            }
        }
        
        var dateRange: DateRange {
            switch self {
            case .week: return .week
            case .month: return .month
            case .threeMonths: return .threeMonths
            case .sixMonths: return .sixMonths
            case .year: return .year
            case .all: return .all
            }
        }
    }
    
    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: UserDefaults.standard.string(forKey: "weightUnit") ?? "kg") ?? .kg
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Period Selector
                PeriodSelectorView(selectedPeriod: $selectedPeriod)
                    .padding(.horizontal)
                
                // Key Metrics
                KeyMetricsGrid(
                        viewModel: viewModel,
                        period: selectedPeriod,
                        unit: weightUnit
                    )
                    .padding(.horizontal)
                    
                    // Achievements
                    WeightAchievementsView(
                        viewModel: viewModel,
                        period: selectedPeriod
                    )
                    .padding(.horizontal)
                    
                    // Progress Over Time
                    ProgressTimelineChart(
                        viewModel: viewModel,
                        period: selectedPeriod,
                        unit: weightUnit
                    )
                    .padding(.horizontal)
                    
                    // Body Composition Trends
                    if hasBodyCompositionData(for: selectedPeriod) {
                        BodyCompositionChart(
                            viewModel: viewModel,
                            period: selectedPeriod
                        )
                        .padding(.horizontal)
                    }
                    
                    // Patterns & Insights
                    PatternsInsightsCard(
                        viewModel: viewModel,
                        period: selectedPeriod
                    )
                    .padding(.horizontal)
                    
                    // Detailed Statistics
                    DetailedStatsCard(
                        viewModel: viewModel,
                        period: selectedPeriod,
                        unit: weightUnit
                    )
                    .padding(.horizontal)
                    
                    Spacer(minLength: 50)
                }
                .padding(.vertical)
            }
            .navigationTitle("analytics".localized)
            .navigationBarTitleDisplayMode(.large)
    }
    
    private func hasBodyCompositionData(for period: AnalyticsPeriod) -> Bool {
        let entries = viewModel.repository.fetchWeightEntries(for: period.dateRange)
        return entries.contains { entry in
            let bodyFat = (try? entry.value(forKey: "bodyFatPercentage") as? Double) ?? 0
            let muscleMass = (try? entry.value(forKey: "muscleMass") as? Double) ?? 0
            return bodyFat > 0 || muscleMass > 0
        }
    }
}

struct PeriodSelectorView: View {
    @Binding var selectedPeriod: WeightAnalyticsView.AnalyticsPeriod
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(WeightAnalyticsView.AnalyticsPeriod.allCases, id: \.self) { period in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedPeriod = period
                        }
                    }) {
                        Text(period.localizedName)
                            .font(.subheadline)
                            .fontWeight(selectedPeriod == period ? .semibold : .regular)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedPeriod == period ? 
                                      (themeManager.accentColor == .defaultMix ? 
                                       themeManager.accentColor.contextColor(for: .weight) : 
                                       themeManager.accentColor.color) : 
                                      Color(.systemGray6))
                            .foregroundColor(selectedPeriod == period ? .white : .primary)
                            .cornerRadius(20)
                    }
                }
            }
        }
    }
}

struct KeyMetricsGrid: View {
    @ObservedObject var viewModel: WeightViewModel
    let period: WeightAnalyticsView.AnalyticsPeriod
    let unit: WeightUnit
    
    private var periodData: [CDWeightEntry] {
        viewModel.repository.fetchWeightEntries(for: period.dateRange)
    }
    
    private var metrics: (total: Double, average: Double, highest: Double, lowest: Double, variance: Double) {
        let weights = periodData.map { $0.weightKg }
        guard !weights.isEmpty else {
            return (0, 0, 0, 0, 0)
        }
        
        let total = weights.reduce(0, +)
        let average = total / Double(weights.count)
        let highest = weights.max() ?? 0
        let lowest = weights.min() ?? 0
        
        // Calculate variance
        let squaredDifferences = weights.map { pow($0 - average, 2) }
        let variance = squaredDifferences.reduce(0, +) / Double(weights.count)
        
        return (total, average, highest, lowest, variance)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("key_metrics".localized)
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(
                    title: "total_change".localized,
                    value: formatWeightChange(),
                    unit: unit.rawValue,
                    icon: "arrow.up.arrow.down",
                    color: totalChangeColor(),
                    viewModel: viewModel
                )
                
                MetricCard(
                    title: "average".localized,
                    value: formatWeight(metrics.average),
                    unit: unit.rawValue,
                    icon: "chart.line.uptrend.xyaxis",
                    color: .blue,
                    viewModel: viewModel
                )
                
                MetricCard(
                    title: "highest".localized,
                    value: formatWeight(metrics.highest),
                    unit: unit.rawValue,
                    icon: "arrow.up",
                    color: .red,
                    viewModel: viewModel
                )
                
                MetricCard(
                    title: "lowest".localized,
                    value: formatWeight(metrics.lowest),
                    unit: unit.rawValue,
                    icon: "arrow.down",
                    color: .green,
                    viewModel: viewModel
                )
                
                MetricCard(
                    title: "consistency".localized,
                    value: consistencyScore(),
                    unit: "%",
                    icon: "checkmark.seal",
                    color: consistencyColor(),
                    viewModel: viewModel
                )
                
                MetricCard(
                    title: "entries".localized,
                    value: "\(periodData.count)",
                    unit: "",
                    icon: "list.bullet",
                    color: .orange,
                    viewModel: viewModel
                )
            }
        }
    }
    
    private func formatWeight(_ weight: Double) -> String {
        let display = unit == .lbs ? weight * 2.20462 : weight
        return String(format: "%.1f", display)
    }
    
    private func formatWeightChange() -> String {
        guard let first = periodData.last?.weightKg,
              let last = periodData.first?.weightKg else {
            return "0"
        }
        
        let change = last - first
        let display = unit == .lbs ? change * 2.20462 : change
        return String(format: "%+.1f", display)
    }
    
    private func totalChangeColor() -> Color {
        guard let first = periodData.last?.weightKg,
              let last = periodData.first?.weightKg else {
            return .secondary
        }
        
        let change = last - first
        return change < 0 ? .green : change > 0 ? .red : .secondary
    }
    
    private func consistencyScore() -> String {
        guard !periodData.isEmpty else { return "0" }
        
        // Calculate expected entries based on period
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date
        
        switch period {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .threeMonths:
            startDate = calendar.date(byAdding: .month, value: -3, to: now) ?? now
        case .sixMonths:
            startDate = calendar.date(byAdding: .month, value: -6, to: now) ?? now
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        case .all:
            startDate = periodData.last?.date ?? now
        }
        
        let days = calendar.dateComponents([.day], from: startDate, to: now).day ?? 1
        let expectedEntries = max(1, days / 3) // Expect entry every 3 days
        let consistency = min(100, (Double(periodData.count) / Double(expectedEntries)) * 100)
        
        return String(format: "%.0f", consistency)
    }
    
    private func consistencyColor() -> Color {
        guard let score = Double(consistencyScore()) else { return .secondary }
        
        if score >= 80 {
            return .green
        } else if score >= 60 {
            return .orange
        } else {
            return .red
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    @ObservedObject var viewModel: WeightViewModel
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


struct ProgressTimelineChart: View {
    @ObservedObject var viewModel: WeightViewModel
    let period: WeightAnalyticsView.AnalyticsPeriod
    let unit: WeightUnit
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private var timelineData: [(date: Date, weight: Double, goalDiff: Double?)] {
        let entries = viewModel.repository.fetchWeightEntries(for: period.dateRange)
            .sorted { ($0.date ?? Date()) < ($1.date ?? Date()) }
        
        return entries.compactMap { entry in
            guard let date = entry.date else { return nil }
            let weight = unit == .lbs ? entry.weightKg * 2.20462 : entry.weightKg
            
            var goalDiff: Double?
            if let goal = viewModel.goalWeight {
                let goalDisplay = unit == .lbs ? goal * 2.20462 : goal
                goalDiff = weight - goalDisplay
            }
            
            return (date: date, weight: weight, goalDiff: goalDiff)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("progress_timeline".localized)
                    .font(.headline)
                
                Spacer()
                
                if let goal = viewModel.goalWeight {
                    let goalDisplay = unit == .lbs ? goal * 2.20462 : goal
                    Label("\("goal".localized): \(String(format: "%.1f", goalDisplay)) \(unit.rawValue)", systemImage: "target")
                        .font(.caption)
                        .foregroundColor(themeManager.accentColor == .defaultMix ? 
                                       Color.green : 
                                       themeManager.accentColor.color)
                }
            }
            
            if !timelineData.isEmpty {
                Chart {
                    ForEach(timelineData, id: \.date) { data in
                        LineMark(
                            x: .value("Date", data.date),
                            y: .value("Weight", data.weight)
                        )
                        .foregroundStyle(themeManager.accentColor == .defaultMix ? 
                                       themeManager.accentColor.contextColor(for: .weight) : 
                                       themeManager.accentColor.color)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        
                        AreaMark(
                            x: .value("Date", data.date),
                            y: .value("Weight", data.weight)
                        )
                        .foregroundStyle((themeManager.accentColor == .defaultMix ? 
                                       themeManager.accentColor.contextColor(for: .weight) : 
                                       themeManager.accentColor.color).opacity(0.1))
                    }
                    
                    if let goal = viewModel.goalWeight {
                        let goalDisplay = unit == .lbs ? goal * 2.20462 : goal
                        RuleMark(y: .value("Goal", goalDisplay))
                            .foregroundStyle(themeManager.accentColor == .defaultMix ? 
                                          Color.green : 
                                          themeManager.accentColor.color)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    }
                }
                .frame(height: 250)
                .environment(\.layoutDirection, .leftToRight)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
            } else {
                Text("no_data_available".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(height: 250)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray5))
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct BodyCompositionChart: View {
    @ObservedObject var viewModel: WeightViewModel
    let period: WeightAnalyticsView.AnalyticsPeriod
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private var compositionData: [(date: Date, bodyFat: Double?, muscleMass: Double?)] {
        let entries = viewModel.repository.fetchWeightEntries(for: period.dateRange)
            .sorted { ($0.date ?? Date()) < ($1.date ?? Date()) }
            .filter { entry in
                let bodyFat = (try? entry.value(forKey: "bodyFatPercentage") as? Double) ?? 0
                let muscleMass = (try? entry.value(forKey: "muscleMass") as? Double) ?? 0
                return bodyFat > 0 || muscleMass > 0
            }
        
        return entries.compactMap { entry in
            guard let date = entry.date else { return nil }
            return (
                date: date,
                bodyFat: {
                    let value = (try? entry.value(forKey: "bodyFatPercentage") as? Double) ?? 0
                    return value > 0 ? value : nil
                }(),
                muscleMass: {
                    let value = (try? entry.value(forKey: "muscleMass") as? Double) ?? 0
                    return value > 0 ? value : nil
                }()
            )
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("body_composition_trends".localized)
                .font(.headline)
            
            if !compositionData.isEmpty {
                Chart {
                    ForEach(compositionData, id: \.date) { data in
                        if let bodyFat = data.bodyFat {
                            LineMark(
                                x: .value("Date", data.date),
                                y: .value("Body Fat %", bodyFat)
                            )
                            .foregroundStyle(Color.orange)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .symbol {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        
                        if let muscleMass = data.muscleMass {
                            LineMark(
                                x: .value("Date", data.date),
                                y: .value("Muscle Mass", muscleMass / 2) // Scale for display
                            )
                            .foregroundStyle(themeManager.accentColor == .defaultMix ? 
                                          themeManager.accentColor.contextColor(for: .weight) : 
                                          themeManager.accentColor.color)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .symbol {
                                Circle()
                                    .fill(themeManager.accentColor == .defaultMix ? 
                                         themeManager.accentColor.contextColor(for: .weight) : 
                                         themeManager.accentColor.color)
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                }
                .frame(height: 200)
                .environment(\.layoutDirection, .leftToRight)
                .chartLegend {
                    HStack(spacing: 20) {
                        Label("\("body_fat".localized) \("percentage_symbol".localized)", systemImage: "circle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        
                        Label("muscle_mass".localized, systemImage: "circle.fill")
                            .foregroundColor(themeManager.accentColor == .defaultMix ? 
                                          themeManager.accentColor.contextColor(for: .weight) : 
                                          themeManager.accentColor.color)
                            .font(.caption)
                    }
                }
            } else {
                Text("no_body_composition_data".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray5))
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct PatternsInsightsCard: View {
    @ObservedObject var viewModel: WeightViewModel
    let period: WeightAnalyticsView.AnalyticsPeriod
    
    private var patterns: [String] {
        var insights: [String] = []
        let entries = viewModel.repository.fetchWeightEntries(for: period.dateRange)
        
        // Day of week pattern
        if let mostCommonDay = findMostCommonWeighInDay(entries) {
            insights.append(String(format: "most_often_weigh_on".localized, mostCommonDay))
        }
        
        // Time of day pattern
        if let mostCommonTime = findMostCommonWeighInTime(entries) {
            insights.append("typical_weigh_in_time".localized(mostCommonTime))
        }
        
        // Streak pattern
        if let streak = calculateLongestStreak(entries) {
            insights.append("longest_tracking_streak".localized(String(streak)))
        }
        
        // Volatility insight
        let volatility = calculateVolatility(entries)
        if volatility > 2.0 {
            insights.append("high_variability_insight".localized)
        } else if volatility < 0.5 {
            insights.append("stable_weight_insight".localized)
        }
        
        return insights
    }
    
    var body: some View {
        if !patterns.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("patterns_insights".localized, systemImage: "brain")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(patterns, id: \.self) { pattern in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            
                            Text(pattern)
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
    
    private func findMostCommonWeighInDay(_ entries: [CDWeightEntry]) -> String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: LocalizationManager.shared.currentLanguage)
        
        let days = entries.compactMap { entry -> String? in
            guard let date = entry.date else { return nil }
            return formatter.string(from: date)
        }
        
        let dayCounts = Dictionary(days.map { ($0, 1) }, uniquingKeysWith: +)
        return dayCounts.max(by: { $0.value < $1.value })?.key
    }
    
    private func findMostCommonWeighInTime(_ entries: [CDWeightEntry]) -> String? {
        let calendar = Calendar.current
        let hours = entries.compactMap { entry -> Int? in
            guard let date = entry.date else { return nil }
            return calendar.component(.hour, from: date)
        }
        
        let hourCounts = Dictionary(hours.map { ($0, 1) }, uniquingKeysWith: +)
        guard let mostCommonHour = hourCounts.max(by: { $0.value < $1.value })?.key else {
            return nil
        }
        
        if mostCommonHour < 10 {
            return "morning".localized
        } else if mostCommonHour < 14 {
            return "midday".localized
        } else if mostCommonHour < 18 {
            return "afternoon".localized
        } else {
            return "evening".localized
        }
    }
    
    private func calculateLongestStreak(_ entries: [CDWeightEntry]) -> Int? {
        guard !entries.isEmpty else { return nil }
        
        let sortedDates = entries.compactMap { $0.date }.sorted()
        var longestStreak = 1
        var currentStreak = 1
        
        for i in 1..<sortedDates.count {
            let daysDiff = Calendar.current.dateComponents([.day], from: sortedDates[i-1], to: sortedDates[i]).day ?? 0
            
            if daysDiff <= 3 { // Allow up to 3 days gap
                currentStreak += 1
                longestStreak = max(longestStreak, currentStreak)
            } else {
                currentStreak = 1
            }
        }
        
        return longestStreak > 1 ? longestStreak : nil
    }
    
    private func calculateVolatility(_ entries: [CDWeightEntry]) -> Double {
        let weights = entries.map { $0.weightKg }
        guard weights.count > 1 else { return 0 }
        
        let mean = weights.reduce(0, +) / Double(weights.count)
        let squaredDifferences = weights.map { pow($0 - mean, 2) }
        let variance = squaredDifferences.reduce(0, +) / Double(weights.count)
        
        return sqrt(variance)
    }
}

struct DetailedStatsCard: View {
    @ObservedObject var viewModel: WeightViewModel
    let period: WeightAnalyticsView.AnalyticsPeriod
    let unit: WeightUnit
    
    private var stats: DetailedStatistics {
        let entries = viewModel.repository.fetchWeightEntries(for: period.dateRange)
        return calculateDetailedStats(entries)
    }
    
    struct DetailedStatistics {
        let median: Double
        let standardDeviation: Double
        let percentile25: Double
        let percentile75: Double
        let range: Double
        let averageDailyChange: Double
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("detailed_statistics".localized)
                .font(.headline)
            
            VStack(spacing: 12) {
                HStack {
                    StatRow(title: "median".localized, value: formatWeight(stats.median), unit: unit.rawValue)
                    Spacer()
                    StatRow(title: "std_dev".localized, value: formatWeight(stats.standardDeviation), unit: unit.rawValue)
                }
                
                Divider()
                
                HStack {
                    StatRow(title: "percentile_25".localized, value: formatWeight(stats.percentile25), unit: unit.rawValue)
                    Spacer()
                    StatRow(title: "percentile_75".localized, value: formatWeight(stats.percentile75), unit: unit.rawValue)
                }
                
                Divider()
                
                HStack {
                    StatRow(title: "range".localized, value: formatWeight(stats.range), unit: unit.rawValue)
                    Spacer()
                    StatRow(title: "avg_daily_change".localized, value: String(format: "%+.2f", formatWeightValue(stats.averageDailyChange)), unit: unit.rawValue)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private func formatWeight(_ weight: Double) -> String {
        let display = unit == .lbs ? weight * 2.20462 : weight
        return String(format: "%.1f", display)
    }
    
    private func formatWeightValue(_ weight: Double) -> Double {
        return unit == .lbs ? weight * 2.20462 : weight
    }
    
    private func calculateDetailedStats(_ entries: [CDWeightEntry]) -> DetailedStatistics {
        let weights = entries.map { $0.weightKg }.sorted()
        
        guard !weights.isEmpty else {
            return DetailedStatistics(
                median: 0,
                standardDeviation: 0,
                percentile25: 0,
                percentile75: 0,
                range: 0,
                averageDailyChange: 0
            )
        }
        
        // Median
        let median: Double
        if weights.count % 2 == 0 {
            median = (weights[weights.count/2 - 1] + weights[weights.count/2]) / 2
        } else {
            median = weights[weights.count/2]
        }
        
        // Standard Deviation
        let mean = weights.reduce(0, +) / Double(weights.count)
        let squaredDifferences = weights.map { pow($0 - mean, 2) }
        let variance = squaredDifferences.reduce(0, +) / Double(weights.count)
        let standardDeviation = sqrt(variance)
        
        // Percentiles
        let percentile25 = weights[max(0, Int(Double(weights.count) * 0.25) - 1)]
        let percentile75 = weights[min(weights.count - 1, Int(Double(weights.count) * 0.75))]
        
        // Range
        let range = (weights.last ?? 0) - (weights.first ?? 0)
        
        // Average Daily Change
        var dailyChanges: [Double] = []
        let sortedEntries = entries.sorted { ($0.date ?? Date()) < ($1.date ?? Date()) }
        
        for i in 1..<sortedEntries.count {
            if let prevDate = sortedEntries[i-1].date,
               let currDate = sortedEntries[i].date {
                let daysDiff = Calendar.current.dateComponents([.day], from: prevDate, to: currDate).day ?? 1
                let weightChange = sortedEntries[i].weightKg - sortedEntries[i-1].weightKg
                dailyChanges.append(weightChange / Double(max(1, daysDiff)))
            }
        }
        
        let averageDailyChange = dailyChanges.isEmpty ? 0 : dailyChanges.reduce(0, +) / Double(dailyChanges.count)
        
        return DetailedStatistics(
            median: median,
            standardDeviation: standardDeviation,
            percentile25: percentile25,
            percentile75: percentile75,
            range: range,
            averageDailyChange: averageDailyChange
        )
    }
}

struct StatRow: View {
    let title: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 2) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}