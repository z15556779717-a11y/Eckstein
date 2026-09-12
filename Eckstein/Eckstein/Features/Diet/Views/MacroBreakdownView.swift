//
//  MacroBreakdownView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI
import Charts

struct MacroBreakdownView: View {
    @ObservedObject var viewModel: DietViewModel
    @State private var selectedTimeRange = TimeRange.today
    @State private var showPercentages = true
    @ObservedObject private var themeManager = ThemeManager.shared
    
    enum TimeRange: String, CaseIterable {
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
    }
    
    private var macroData: MacroBreakdown {
        switch selectedTimeRange {
        case .today:
            return viewModel.getTodayMacroBreakdown()
        case .week:
            return viewModel.getWeekMacroBreakdown()
        case .month:
            return viewModel.getMonthMacroBreakdown()
        }
    }
    
    private var pieChartData: [(macro: String, value: Double, color: Color)] {
        let total = macroData.totalCalories
        guard total > 0 else { return [] }
        
        return [
            ("Protein", macroData.proteinCalories, themeManager.proteinColor),
            ("Carbs", macroData.carbsCalories, themeManager.carbsColor),
            ("Fat", macroData.fatCalories, themeManager.fatColor)
        ]
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("macro_breakdown_title".localized)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("macro_breakdown_subtitle".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // Time Range Picker
                Picker("time_range".localized, selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Pie Chart
                if macroData.totalCalories > 0 {
                    VStack(spacing: 16) {
                        ZStack {
                            // Pie Chart
                            GeometryReader { geometry in
                                let center = CGPoint(
                                    x: geometry.size.width / 2,
                                    y: geometry.size.height / 2
                                )
                                let radius = min(geometry.size.width, geometry.size.height) / 2 - 20
                                
                                ZStack {
                                    ForEach(Array(pieChartData.enumerated()), id: \.offset) { index, data in
                                        PieSlice(
                                            startAngle: startAngle(for: index),
                                            endAngle: endAngle(for: index),
                                            color: data.color
                                        )
                                    }
                                    
                                    // Center circle with total calories
                                    Circle()
                                        .fill(Color(.systemGray6))
                                        .frame(width: radius * 0.6, height: radius * 0.6)
                                    
                                    VStack {
                                        Text("\(macroData.totalCalories)")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                        Text("calories")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .frame(width: geometry.size.width, height: geometry.size.height)
                            }
                            .frame(height: 250)
                        }
                        
                        // Legend
                        HStack(spacing: 20) {
                            ForEach(pieChartData, id: \.macro) { data in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(data.color)
                                        .frame(width: 12, height: 12)
                                    
                                    Text(data.macro)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Toggle View
                Toggle("macro_breakdown_show_percentages".localized, isOn: $showPercentages)
                    .padding(.horizontal)
                
                // Macro Details
                VStack(spacing: 12) {
                    MacroDetailRow(
                        title: "Protein",
                        grams: macroData.proteinGrams,
                        calories: macroData.proteinCalories,
                        percentage: macroData.proteinPercentage,
                        color: themeManager.proteinColor,
                        showPercentages: showPercentages
                    )
                    
                    MacroDetailRow(
                        title: "Carbohydrates",
                        grams: macroData.carbsGrams,
                        calories: macroData.carbsCalories,
                        percentage: macroData.carbsPercentage,
                        color: themeManager.carbsColor,
                        showPercentages: showPercentages
                    )
                    
                    MacroDetailRow(
                        title: "Fat",
                        grams: macroData.fatGrams,
                        calories: macroData.fatCalories,
                        percentage: macroData.fatPercentage,
                        color: themeManager.fatColor,
                        showPercentages: showPercentages
                    )
                }
                .padding(.horizontal)
                
                // Recommendations
                if macroData.totalCalories > 0 {
                    RecommendationsCard(macroData: macroData)
                        .padding(.horizontal)
                }
                
                Spacer(minLength: 20)
            }
            .padding(.vertical)
        }
    }
    
    private func startAngle(for index: Int) -> Angle {
        guard macroData.totalCalories > 0 else { return .zero }
        
        var angle: Double = -90
        for i in 0..<index {
            angle += (pieChartData[i].value / Double(macroData.totalCalories)) * 360
        }
        return Angle(degrees: angle)
    }
    
    private func endAngle(for index: Int) -> Angle {
        guard macroData.totalCalories > 0 else { return .zero }
        
        var angle: Double = -90
        for i in 0...index {
            angle += (pieChartData[i].value / Double(macroData.totalCalories)) * 360
        }
        return Angle(degrees: angle)
    }
}

struct PieSlice: Shape {
    var startAngle: Angle
    var endAngle: Angle
    var color: Color
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.closeSubpath()
        
        return path
    }
}

struct MacroDetailRow: View {
    let title: String
    let grams: Double
    let calories: Double
    let percentage: Double
    let color: Color
    let showPercentages: Bool
    
    var body: some View {
        HStack {
            HStack(spacing: 12) {
                Circle()
                    .fill(color)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text("\(Int(percentage))%")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    
                    if showPercentages {
                        Text("macro_breakdown_percent_of_total_calories".localized(Int(percentage)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("macro_breakdown_grams_and_calories".localized(Int(grams), Int(calories)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(grams))g")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("macro_breakdown_calories".localized(Int(calories)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct RecommendationsCard: View {
    let macroData: MacroBreakdown
    
    private var recommendation: String {
        if macroData.proteinPercentage < 20 {
            return "Consider increasing protein intake for better satiety and muscle maintenance."
        } else if macroData.carbsPercentage > 60 {
            return "Your carb intake is quite high. Consider balancing with more protein and healthy fats."
        } else if macroData.fatPercentage < 20 {
            return "Don't forget healthy fats! They're important for hormone production and nutrient absorption."
        } else {
            return "Your macro distribution looks well-balanced. Keep up the good work!"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("macro_breakdown_recommendation".localized, systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundColor(.orange)
            
            Text(recommendation)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Supporting Types
// MacroBreakdown struct is now defined in DietViewModel
extension MacroBreakdown {
    var proteinPercentage: Double {
        guard totalCalories > 0 else { return 0 }
        return (proteinCalories / totalCalories) * 100
    }
    
    var carbsPercentage: Double {
        guard totalCalories > 0 else { return 0 }
        return (carbsCalories / totalCalories) * 100
    }
    
    var fatPercentage: Double {
        guard totalCalories > 0 else { return 0 }
        return (fatCalories / totalCalories) * 100
    }
}