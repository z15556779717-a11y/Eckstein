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
                Text("No items added")
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
            Text("Meal items will be displayed here")
                .font(.subheadline)
            
            Text("0 calories")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}