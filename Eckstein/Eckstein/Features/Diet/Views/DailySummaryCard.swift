//
//  DailySummaryCard.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

struct DailySummaryCard: View {
    let calories: Int
    let protein: Double
    let carbs: Double
    let calorieBankBalance: Int
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Today's Summary")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 20) {
                NutrientView(
                    title: "Calories",
                    value: "\(calories)",
                    unit: "kcal",
                    color: themeManager.accentColor.color
                )
                
                NutrientView(
                    title: "Protein",
                    value: String(format: "%.1f", protein),
                    unit: "g",
                    color: themeManager.accentColor.color
                )
                
                NutrientView(
                    title: "Carbs",
                    value: String(format: "%.1f", carbs),
                    unit: "g",
                    color: themeManager.accentColor.color
                )
            }
            
            Divider()
            
            HStack {
                Label("Calorie Bank", systemImage: "banknote")
                    .font(.subheadline)
                
                Spacer()
                
                Text("\(calorieBankBalance > 0 ? "+" : "")\(calorieBankBalance)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(calorieBankBalance >= 0 ? themeManager.accentColor.color : (themeManager.accentColor == .red ? .red : .red))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct NutrientView: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(unit)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}