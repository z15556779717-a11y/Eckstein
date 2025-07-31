//
//  WeightChartView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI
import Charts

struct WeightChartView: View {
    @ObservedObject var viewModel: WeightViewModel
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var selectedDateRange: DateRange = .month
    @State private var showingGoalLine = true
    @State private var selectedEntry: CDWeightEntry?
    
    private var chartData: [CDWeightEntry] {
        viewModel.repository.fetchWeightEntries(for: selectedDateRange)
            .sorted { ($0.date ?? Date()) < ($1.date ?? Date()) }
    }
    
    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: UserDefaults.standard.string(forKey: "weightUnit") ?? "kg") ?? .kg
    }
    
    private var yAxisDomain: ClosedRange<Double> {
        guard !chartData.isEmpty else { return 0...100 }
        
        let weights = chartData.map { 
            weightUnit == .lbs ? $0.weightKg * 2.20462 : $0.weightKg 
        }
        let minWeight = (weights.min() ?? 0) * 0.95
        let maxWeight = (weights.max() ?? 100) * 1.05
        
        return minWeight...maxWeight
    }
    
    private var xAxisDomain: ClosedRange<Date> {
        guard !chartData.isEmpty else { 
            let now = Date()
            return now.addingTimeInterval(-7*24*60*60)...now
        }
        
        let dates = chartData.compactMap { $0.date }
        let minDate = dates.min() ?? Date()
        let maxDate = dates.max() ?? Date()
        
        // Add some padding to the dates
        let padding = (maxDate.timeIntervalSince(minDate)) * 0.05
        return minDate.addingTimeInterval(-padding)...maxDate.addingTimeInterval(padding)
    }
    
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with controls
            VStack(spacing: 12) {
                HStack {
                    Text("progress_chart".localized)
                        .font(.headline)
                    
                    Spacer()
                    
                    Menu {
                        Toggle("goal_line".localized, isOn: $showingGoalLine)
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title3)
                    }
                }
                
                // Date Range Selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach([DateRange.week, .month, .threeMonths, .sixMonths, .year], id: \.self) { range in
                            FilterChip(
                                title: range.displayName,
                                isSelected: selectedDateRange == range,
                                action: { selectedDateRange = range }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            if chartData.isEmpty {
                EmptyChartView()
            } else {
                Chart {
                    // Weight entries
                    ForEach(chartData) { entry in
                        let weight = weightUnit == .lbs ? entry.weightKg * 2.20462 : entry.weightKg
                        
                        LineMark(
                            x: .value("Date", entry.date ?? Date()),
                            y: .value("Weight", weight)
                        )
                        .foregroundStyle(Color.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        
                        PointMark(
                            x: .value("Date", entry.date ?? Date()),
                            y: .value("Weight", weight)
                        )
                        .foregroundStyle(Color.blue)
                        .symbolSize(selectedEntry == entry ? 150 : 100)
                    }
                    
                    // Goal line
                    if showingGoalLine, let goal = viewModel.goalWeight {
                        let goalWeight = weightUnit == .lbs ? goal * 2.20462 : goal
                        RuleMark(y: .value("Goal", goalWeight))
                            .foregroundStyle(Color.green)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("goal".localized)
                                    .font(.caption)
                                    .foregroundColor(.green)
                                    .padding(4)
                                    .background(Color(.systemGray6))
                            }
                    }
                    
                }
                .frame(height: 300)
                .padding(.horizontal)
                .chartYScale(domain: yAxisDomain)
                .chartXScale(domain: xAxisDomain)
                .environment(\.layoutDirection, .leftToRight)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: localizationManager.isRTL ? .trailing : .leading) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let weight = value.as(Double.self), weight.isFinite {
                                Text("\(Int(weight)) \(weightUnit.rawValue)")
                            }
                        }
                    }
                }
                .chartBackground { chartProxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                handleChartTap(location: location, geometry: geometry, chartProxy: chartProxy)
                            }
                    }
                }
                
                // Statistics
                if !chartData.isEmpty {
                    WeightStatisticsView(
                        entries: chartData,
                        trend: viewModel.repository.getWeightTrend(),
                        unit: weightUnit
                    )
                    .padding(.horizontal)
                }
            }
            
            Spacer()
        }
    }
    
    private func handleChartTap(location: CGPoint, geometry: GeometryProxy, chartProxy: ChartProxy) {
        let xPosition = location.x - geometry.frame(in: .local).minX
        
        // Find the closest data point
        var closestEntry: CDWeightEntry?
        var minDistance = Double.infinity
        
        for entry in chartData {
            guard let date = entry.date,
                  let plotX = chartProxy.position(forX: date) else { continue }
            
            let distance = abs(Double(plotX) - Double(xPosition))
            if distance < minDistance {
                minDistance = distance
                closestEntry = entry
            }
        }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedEntry = closestEntry
        }
    }
}

struct EmptyChartView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("no_data_available".localized)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("add_weight_entries_chart".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(height: 300)
    }
}

struct WeightStatisticsView: View {
    let entries: [CDWeightEntry]
    let trend: WeightTrend
    let unit: WeightUnit
    
    private var statistics: (min: Double, max: Double, avg: Double, change: Double) {
        let weights = entries.map { 
            unit == .lbs ? $0.weightKg * 2.20462 : $0.weightKg 
        }
        
        let min = weights.min() ?? 0
        let max = weights.max() ?? 0
        let avg = weights.isEmpty ? 0 : weights.reduce(0, +) / Double(weights.count)
        
        let change: Double
        if let first = entries.first?.weightKg,
           let last = entries.last?.weightKg {
            let firstWeight = unit == .lbs ? first * 2.20462 : first
            let lastWeight = unit == .lbs ? last * 2.20462 : last
            change = lastWeight - firstWeight
        } else {
            change = 0
        }
        
        return (min, max, avg, change)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label("statistics".localized, systemImage: "chart.bar")
                    .font(.headline)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: trend.icon)
                    Text(trend.description)
                }
                .font(.caption)
                .foregroundColor(trend.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(trend.color.opacity(0.1))
                .cornerRadius(8)
            }
            
            HStack(spacing: 16) {
                StatItem(
                    title: "min".localized,
                    value: String(format: "%.1f", statistics.min),
                    unit: unit.rawValue,
                    color: .blue
                )
                
                StatItem(
                    title: "max".localized,
                    value: String(format: "%.1f", statistics.max),
                    unit: unit.rawValue,
                    color: .red
                )
                
                StatItem(
                    title: "avg".localized,
                    value: String(format: "%.1f", statistics.avg),
                    unit: unit.rawValue,
                    color: .orange
                )
                
                StatItem(
                    title: "change".localized,
                    value: String(format: "%+.1f", statistics.change),
                    unit: unit.rawValue,
                    color: statistics.change < 0 ? .green : .red
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline)
                .foregroundColor(color)
            
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}