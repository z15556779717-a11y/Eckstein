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
                Section(header: Text("food_details".localized)) {
                    TextField("food_name".localized, text: $foodName)

                    HStack {
                        TextField("add_custom_food_daily_grams".localized, text: $dailyGrams)
                            .keyboardType(.numberPad)
                        Text("grams")
                            .foregroundColor(.secondary)
                    }
                    
                    if category == .proteinFat || category == .proteinNonFat {
                        Toggle("add_custom_food_is_fat_protein".localized, isOn: $isFat)
                    }
                }
                
                Section(header: Text("diet_food_category".localized)) {
                    Text(categoryTitle)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Text("add_custom_food_footer".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("add_custom_food_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save".localized) {
                        saveFood()
                    }
                    .disabled(foodName.isEmpty || dailyGrams.isEmpty)
                }
            }
            .alert("error".localized, isPresented: $showError) {
                Button("ok".localized) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var categoryTitle: String {
        category.displayName
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