//
//  AddFoodView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI
import CoreData

struct AddFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    
    @State private var name = ""
    @State private var brand = ""
    @State private var barcode = ""
    @State private var category = "External"
    @State private var caloriesPer100g = ""
    @State private var proteinPer100g = ""
    @State private var carbsPer100g = ""
    @State private var fatPer100g = ""
    @State private var fiberPer100g = ""
    @State private var servingSize = "100"
    @State private var servingUnit = "g"
    @State private var showValidationError = false
    
    let categories = ["Protein", "Carbs", "Vegetable", "Fruit", "Dairy", "Fats", "Nuts", "Snack", "Supplement", "External"]
    let onSave: (CDFood) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("add_food_basic_info".localized)) {
                    TextField("food_name".localized, text: $name)
                    TextField("brand_optional".localized, text: $brand)
                    TextField("add_food_barcode_optional".localized, text: $barcode)
                        .keyboardType(.numberPad)

                    Picker("diet_food_category".localized, selection: $category) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                }
                
                Section(header: Text("add_food_nutrition_per_100g".localized)) {
                    HStack {
                        Text("calories".localized)
                        Spacer()
                        TextField("0", text: $caloriesPer100g)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("cal")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("protein".localized)
                        Spacer()
                        TextField("0", text: $proteinPer100g)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("g")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("add_food_carbohydrates".localized)
                        Spacer()
                        TextField("0", text: $carbsPer100g)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("g")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("fat".localized)
                        Spacer()
                        TextField("0", text: $fatPer100g)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("g")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("add_food_fiber_optional".localized)
                        Spacer()
                        TextField("0", text: $fiberPer100g)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("g")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("serving_info".localized)) {
                    HStack {
                        Text("serving_size".localized)
                        Spacer()
                        TextField("100", text: $servingSize)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        TextField("g", text: $servingUnit)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                }
                
                if showValidationError {
                    Section {
                        Text("add_food_fill_required".localized)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
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
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func saveFood() {
        guard !name.isEmpty,
              let calories = Int32(caloriesPer100g),
              let protein = Double(proteinPer100g),
              let carbs = Double(carbsPer100g),
              let fat = Double(fatPer100g) else {
            showValidationError = true
            return
        }
        
        let food = CDFood(context: context)
        food.id = UUID()
        food.name = name
        food.brand = brand.isEmpty ? nil : brand
        food.barcode = barcode.isEmpty ? nil : barcode
        food.category = category
        food.caloriesPer100g = calories
        food.proteinPer100g = protein
        food.carbsPer100g = carbs
        food.fatPer100g = fat
        food.fiberPer100g = Double(fiberPer100g) ?? 0
        food.servingSize = Double(servingSize) ?? 100
        food.servingUnit = servingUnit.isEmpty ? "g" : servingUnit
        food.isCustom = true
        food.isVerified = false
        food.isFavorite = false
        
        do {
            try context.save()
            onSave(food)
            dismiss()
        } catch {
            print("Error saving food: \(error)")
        }
    }
}