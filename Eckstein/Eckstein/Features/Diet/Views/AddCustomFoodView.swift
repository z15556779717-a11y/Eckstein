//
//  AddCustomFoodView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 14/07/2025.
//

import SwiftUI

struct AddCustomFoodView: View {
    let category: DietRule.DietCategory
    @ObservedObject var viewModel: EcksteinDietViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var foodName = ""
    @State private var dailyGrams = ""
    @State private var isFat = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Food Details")) {
                    TextField("Food Name", text: $foodName)
                    
                    HStack {
                        TextField("Daily Grams", text: $dailyGrams)
                            .keyboardType(.numberPad)
                        Text("grams")
                            .foregroundColor(.secondary)
                    }
                    
                    if category == .proteinFat || category == .proteinNonFat {
                        Toggle("Is Fat Protein", isOn: $isFat)
                    }
                }
                
                Section(header: Text("Category")) {
                    Text(categoryTitle)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Text("This food will be added to your personal food list and can be used for meal tracking.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add Custom Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveFood()
                    }
                    .disabled(foodName.isEmpty || dailyGrams.isEmpty)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var categoryTitle: String {
        switch category {
        case .proteinFat:
            return "Protein (Fat)"
        case .proteinNonFat:
            return "Protein (Non-Fat)"
        case .carbs:
            return "Carbs"
        case .snack:
            return "Snack"
        case .carbLoad:
            return "Carb Load"
        }
    }
    
    private func saveFood() {
        guard !foodName.isEmpty,
              let grams = Int(dailyGrams),
              grams > 0 else {
            errorMessage = "Please enter a valid food name and grams"
            showError = true
            return
        }
        
        viewModel.createCustomFood(
            name: foodName,
            category: category,
            dailyGrams: grams,
            isFat: isFat
        )
        
        dismiss()
    }
}