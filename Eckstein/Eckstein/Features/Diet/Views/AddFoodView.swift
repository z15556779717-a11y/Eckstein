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
                Section(header: Text("Basic Information")) {
                    TextField("Food Name", text: $name)
                    TextField("Brand (Optional)", text: $brand)
                    TextField("Barcode (Optional)", text: $barcode)
                        .keyboardType(.numberPad)
                    
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                }
                
                Section(header: Text("Nutrition per 100g")) {
                    HStack {
                        Text("Calories")
                        Spacer()
                        TextField("0", text: $caloriesPer100g)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("cal")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Protein")
                        Spacer()
                        TextField("0", text: $proteinPer100g)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("g")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Carbohydrates")
                        Spacer()
                        TextField("0", text: $carbsPer100g)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("g")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Fat")
                        Spacer()
                        TextField("0", text: $fatPer100g)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("g")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Fiber (Optional)")
                        Spacer()
                        TextField("0", text: $fiberPer100g)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("g")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Serving Information")) {
                    HStack {
                        Text("Serving Size")
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
                        Text("Please fill in all required fields")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
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