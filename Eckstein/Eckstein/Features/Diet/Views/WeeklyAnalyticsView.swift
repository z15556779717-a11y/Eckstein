//
//  WeeklyAnalyticsView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI
import Charts

struct WeeklyAnalyticsView: View {
    @ObservedObject var viewModel: DietViewModel
    @State private var selectedMetric = NutritionMetric.calories
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private func colorForMetric(_ metric: NutritionMetric) -> Color {
        switch metric {
        case .calories: return .orange
        case .protein: return themeManager.proteinColor
        case .carbs: return themeManager.carbsColor
        case .fat: return themeManager.fatColor
        }
    }
    
    enum NutritionMetric: String, CaseIterable {
        case calories = "Calories"
        case protein = "Protein"
        case carbs = "Carbs"
        case fat = "Fat"
        
        var unit: String {
            switch self {
            case .calories: return "cal"
            case .protein, .carbs, .fat: return "g"
            }
        }
        
        var color: Color {
            switch self {
            case .calories: return .orange
            case .protein: return .red
            case .carbs: return .blue
            case .fat: return .green
            }
        }
    }
    
    private var weeklyData: [DailyNutrition] {
        // Get meals from the last 7 days
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Group meals by day and calculate nutrition
        var dailyData: [DailyNutrition] = []
        
        for dayOffset in 0...6 {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                let dayMeals = viewModel.todayMeals.filter { meal in
                    guard let mealDate = meal.date else { return false }
                    return calendar.isDate(mealDate, inSameDayAs: date)
                }
                
                let nutrition = NutritionCalculator.calculateNutritionForMeals(dayMeals)
                dailyData.append(DailyNutrition(
                    date: date,
                    calories: nutrition.calories,
                    protein: nutrition.protein,
                    carbs: nutrition.carbs,
                    fat: nutrition.fat
                ))
            }
        }
        
        return dailyData.reversed()
    }
    
    private var chartData: [(date: Date, value: Double)] {
        weeklyData.map { daily in
            let value: Double
            switch selectedMetric {
            case .calories:
                value = Double(daily.calories)
            case .protein:
                value = daily.protein
            case .carbs:
                value = daily.carbs
            case .fat:
                value = daily.fat
            }
            return (date: daily.date, value: value)
        }
    }
    
    private var averageValue: Double {
        guard !chartData.isEmpty else { return 0 }
        return chartData.map { $0.value }.reduce(0, +) / Double(chartData.count)
    }
    
    private var weeklyTotal: Double {
        chartData.map { $0.value }.reduce(0, +)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Weekly Analytics")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Track your nutrition trends over the past week")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // Metric Picker
                Picker("Metric", selection: $selectedMetric) {
                    ForEach(NutritionMetric.allCases, id: \.self) { metric in
                        Text(metric.rawValue).tag(metric)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Summary Stats
                HStack(spacing: 16) {
                    DietStatCard(
                        title: "Daily Average",
                        value: String(format: "%.0f", averageValue),
                        unit: selectedMetric.unit,
                        color: colorForMetric(selectedMetric)
                    )
                    
                    DietStatCard(
                        title: "Weekly Total",
                        value: String(format: "%.0f", weeklyTotal),
                        unit: selectedMetric.unit,
                        color: colorForMetric(selectedMetric)
                    )
                }
                .padding(.horizontal)
                
                // Chart
                if !chartData.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Daily Trend")
                            .font(.headline)
                        
                        Chart(chartData, id: \.date) { item in
                            LineMark(
                                x: .value("Date", item.date),
                                y: .value(selectedMetric.rawValue, item.value)
                            )
                            .foregroundStyle(colorForMetric(selectedMetric))
                            .lineStyle(StrokeStyle(lineWidth: 3))
                            
                            AreaMark(
                                x: .value("Date", item.date),
                                y: .value(selectedMetric.rawValue, item.value)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        colorForMetric(selectedMetric).opacity(0.3),
                                        colorForMetric(selectedMetric).opacity(0.1)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            
                            PointMark(
                                x: .value("Date", item.date),
                                y: .value(selectedMetric.rawValue, item.value)
                            )
                            .foregroundStyle(colorForMetric(selectedMetric))
                            .symbolSize(100)
                        }
                        .frame(height: 250)
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 7)) { _ in
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                            }
                        }
                        .chartYAxis {
                            AxisMarks { _ in
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel()
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Daily Breakdown
                VStack(alignment: .leading, spacing: 12) {
                    Text("Daily Breakdown")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(weeklyData) { daily in
                        DailyNutritionRow(
                            daily: daily,
                            selectedMetric: selectedMetric,
                            goal: getGoalForMetric(selectedMetric),
                            metricColor: colorForMetric(selectedMetric)
                        )
                    }
                }
                
                Spacer(minLength: 20)
            }
            .padding(.vertical)
        }
    }
    
    private func getGoalForMetric(_ metric: NutritionMetric) -> Double {
        switch metric {
        case .calories:
            return Double(viewModel.dailyCalorieGoal)
        case .protein:
            return Double(viewModel.dailyProteinGoal)
        case .carbs:
            return Double(viewModel.dailyCarbsGoal)
        case .fat:
            return Double(viewModel.dailyFatGoal)
        }
    }
}

struct DietStatCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct DailyNutritionRow: View {
    let daily: DailyNutrition
    let selectedMetric: WeeklyAnalyticsView.NutritionMetric
    let goal: Double
    let metricColor: Color
    
    private var value: Double {
        switch selectedMetric {
        case .calories:
            return Double(daily.calories)
        case .protein:
            return daily.protein
        case .carbs:
            return daily.carbs
        case .fat:
            return daily.fat
        }
    }
    
    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(value / goal, 1.5)
    }
    
    private var isOverGoal: Bool {
        value > goal
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(daily.date, format: .dateTime.weekday(.wide))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(daily.date, format: .dateTime.month().day())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 100, alignment: .leading)
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 24)
                        .cornerRadius(12)
                    
                    Rectangle()
                        .fill(isOverGoal ? Color.red : metricColor)
                        .frame(
                            width: geometry.size.width * min(progress, 1.0),
                            height: 24
                        )
                        .cornerRadius(12)
                }
            }
            .frame(height: 24)
            
            // Value
            Text("\(Int(value)) \(selectedMetric.unit)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isOverGoal ? .red : .primary)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Supporting Types
struct DailyNutrition: Identifiable {
    let id = UUID()
    let date: Date
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
}