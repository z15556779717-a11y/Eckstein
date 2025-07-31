//
//  FoodDetailView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

struct FoodDetailView: View {
    let food: CDFood
    @State private var servingAmount: String = "100"
    @State private var selectedUnit = "g"
    @Environment(\.dismiss) private var dismiss
    
    let onAdd: (Double) -> Void
    
    private var multiplier: Double {
        guard let amount = Double(servingAmount) else { return 1 }
        if selectedUnit == food.servingUnit {
            return amount / food.servingSize
        } else {
            return amount / 100
        }
    }
    
    private var adjustedCalories: Int {
        Int(Double(food.caloriesPer100g) * multiplier)
    }
    
    private var adjustedProtein: Double {
        food.proteinPer100g * multiplier
    }
    
    private var adjustedCarbs: Double {
        food.carbsPer100g * multiplier
    }
    
    private var adjustedFat: Double {
        food.fatPer100g * multiplier
    }
    
    private var adjustedFiber: Double {
        food.fiberPer100g * multiplier
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Food Info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(food.name ?? "Unknown")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if food.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                        }
                    }
                    
                    if let brand = food.brand, !brand.isEmpty {
                        Text(brand)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let category = food.category {
                        Label(category, systemImage: "tag.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Serving Size Input
                VStack(alignment: .leading, spacing: 12) {
                    Text("Serving Size")
                        .font(.headline)
                    
                    HStack {
                        TextField("100", text: $servingAmount)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 100)
                        
                        Picker("Unit", selection: $selectedUnit) {
                            Text("g").tag("g")
                            if let unit = food.servingUnit, unit != "g" {
                                Text(unit).tag(unit)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        Spacer()
                    }
                    
                    if let unit = food.servingUnit, unit != "g" {
                        Text("\(Int(food.servingSize))\(unit) = \(Int(food.servingSize))g")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                
                // Nutrition Facts
                VStack(spacing: 0) {
                    Text("Nutrition Facts")
                        .font(.headline)
                        .padding(.bottom)
                    
                    NutritionRow(label: "Calories", value: "\(adjustedCalories)", unit: "cal", color: .orange)
                    NutritionRow(label: "Protein", value: String(format: "%.1f", adjustedProtein), unit: "g", color: .red)
                    NutritionRow(label: "Carbohydrates", value: String(format: "%.1f", adjustedCarbs), unit: "g", color: .blue)
                    NutritionRow(label: "Fat", value: String(format: "%.1f", adjustedFat), unit: "g", color: .green)
                    
                    if food.fiberPer100g > 0 {
                        NutritionRow(label: "Fiber", value: String(format: "%.1f", adjustedFiber), unit: "g", color: .brown)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
                
                // Add Button
                Button(action: addFood) {
                    Text("Add to Meal")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Food Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func addFood() {
        guard let amount = Double(servingAmount) else { return }
        
        let gramsToAdd: Double
        if selectedUnit == food.servingUnit && selectedUnit != "g" {
            gramsToAdd = (amount / food.servingSize) * 100
        } else {
            gramsToAdd = amount
        }
        
        onAdd(gramsToAdd)
        dismiss()
    }
}

struct NutritionRow: View {
    let label: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(label)
                .font(.body)
            
            Spacer()
            
            Text("\(value) \(unit)")
                .font(.body)
                .fontWeight(.medium)
        }
        .padding(.vertical, 8)
        
        if label != "Fiber" {
            Divider()
        }
    }
}