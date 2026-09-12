//
//  MealSection.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

struct MealSection: View {
    let mealType: MealType
    let meals: [CDMeal]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(mealType.displayName)
                    .font(.headline)
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.accentColor)
                }
            }
            
            if meals.isEmpty {
                Text("meal_section_no_items".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(meals) { meal in
                    MealItemRow(meal: meal)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}

struct MealItemRow: View {
    let meal: CDMeal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("meal_section_placeholder".localized)
                .font(.subheadline)

            Text("meal_section_zero_calories".localized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}