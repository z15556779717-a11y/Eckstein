//
//  MealDetailView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI
import CoreData

struct MealDetailView: View {
    @ObservedObject var meal: CDMeal
    @State private var showAddFood = false
    @State private var showPhotoOptions = false
    @State private var mealPhoto: UIImage?
    @State private var notes = ""
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    private var mealItems: [CDMealItem] {
        if let items = meal.items as? Set<CDMealItem> {
            return items.sorted { 
                ($0.food?.name ?? "") < ($1.food?.name ?? "") 
            }
        }
        return []
    }
    
    private var totalNutrition: NutritionInfo {
        var calories = 0
        var protein = 0.0
        var carbs = 0.0
        var fat = 0.0
        var fiber = 0.0
        
        for item in mealItems {
            if let food = item.food {
                let nutrition = ServingSizeCalculator.calculateNutrition(
                    for: food,
                    servingGrams: item.quantityGrams
                )
                calories += nutrition.calories
                protein += nutrition.protein
                carbs += nutrition.carbs
                fat += nutrition.fat
                fiber += nutrition.fiber
            }
        }
        
        return NutritionInfo(
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: fiber
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Meal Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(meal.mealType?.capitalized ?? "diet_entry_meal".localized)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        if let date = meal.date {
                            Text(date, style: .time)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Nutrition Summary
                    HStack(spacing: 20) {
                        NutritionBadge(
                            value: "\(totalNutrition.calories)",
                            label: "cal",
                            color: .orange
                        )
                        
                        NutritionBadge(
                            value: String(format: "%.0f", totalNutrition.protein),
                            label: "P",
                            color: .red
                        )
                        
                        NutritionBadge(
                            value: String(format: "%.0f", totalNutrition.carbs),
                            label: "C",
                            color: .blue
                        )
                        
                        NutritionBadge(
                            value: String(format: "%.0f", totalNutrition.fat),
                            label: "F",
                            color: .green
                        )
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Meal Photo
                if let photo = mealPhoto {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(12)
                        .onTapGesture {
                            showPhotoOptions = true
                        }
                } else {
                    Button(action: { showPhotoOptions = true }) {
                        Label("meal_detail_add_photo".localized, systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                }
                
                // Food Items
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("meal_detail_foods".localized)
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: { showAddFood = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                    }
                    
                    if mealItems.isEmpty {
                        Text("meal_detail_no_foods_added".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    } else {
                        ForEach(Array(mealItems.enumerated()), id: \.element.id) { index, item in
                            MealDetailItemRow(item: item) {
                                deleteMealItem(item)
                            }
                            .if(index == 0) { view in
                                view.tooltip(
                                    "Swipe left to delete food items",
                                    tipId: TipManager.TipID.mealSwipe,
                                    position: .below
                                )
                            }
                        }
                    }
                }
                
                // Notes
                VStack(alignment: .leading, spacing: 8) {
                    Text("notes".localized)
                        .font(.headline)
                    
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .onAppear {
                            // Notes can be loaded from user preferences or stored elsewhere if needed
                        }
                        .onChange(of: notes) { newValue in
                            // Notes can be saved to user preferences or stored elsewhere if needed
                            // For now, they're just in the local view state
                        }
                }
                
                // Quick Actions
                VStack(spacing: 12) {
                    Button(action: duplicateMeal) {
                        Label("meal_detail_duplicate_meal".localized, systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                    }
                    
                    Button(action: deleteMeal) {
                        Label("delete_meal".localized, systemImage: "trash")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("meal_details".localized)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddFood) {
            FoodSearchView { food in
                addFoodToMeal(food)
            }
        }
        .confirmationDialog("meal_detail_photo_options".localized, isPresented: $showPhotoOptions) {
            Button("meal_detail_take_photo".localized) {
                // Implement camera
            }
            Button("meal_detail_choose_from_library".localized) {
                // Implement photo picker
            }
            if mealPhoto != nil {
                Button("meal_detail_remove_photo".localized, role: .destructive) {
                    mealPhoto = nil
                }
            }
        }
    }
    
    private func addFoodToMeal(_ food: CDFood) {
        let mealItem = CDMealItem(context: context)
        mealItem.id = UUID()
        mealItem.quantityGrams = 100
        mealItem.food = food
        mealItem.meal = meal
        saveContext()
    }
    
    private func deleteMealItem(_ item: CDMealItem) {
        context.delete(item)
        saveContext()
    }
    
    private func duplicateMeal() {
        let dietRepository = ServiceContainer.shared.dietRepository
        
        let newMeal = dietRepository.createMeal(
            mealType: meal.mealType ?? "snack",
            date: Date()
        )
        
        for item in mealItems {
            if let food = item.food {
                dietRepository.addFoodToMeal(
                    newMeal,
                    food: food,
                    quantityGrams: item.quantityGrams
                )
            }
        }
        
        dismiss()
    }
    
    private func deleteMeal() {
        context.delete(meal)
        saveContext()
        dismiss()
    }
    
    private func saveContext() {
        do {
            try context.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
}

struct MealDetailItemRow: View {
    @ObservedObject var item: CDMealItem
    let onDelete: () -> Void
    
    @State private var editingQuantity = false
    @State private var quantityText = ""
    
    private var nutrition: NutritionInfo? {
        guard let food = item.food else { return nil }
        return ServingSizeCalculator.calculateNutrition(
            for: food,
            servingGrams: item.quantityGrams
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.food?.name ?? "unknown".localized)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    if editingQuantity {
                        HStack {
                            TextField("100", text: $quantityText)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 80)
                                .onSubmit {
                                    updateQuantity()
                                }
                            
                            Text("g")
                                .foregroundColor(.secondary)
                            
                            Button("done".localized) {
                                updateQuantity()
                            }
                            .font(.caption)
                        }
                    } else {
                        Text("\(Int(item.quantityGrams))g")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .onTapGesture {
                                quantityText = String(Int(item.quantityGrams))
                                editingQuantity = true
                            }
                    }
                }
                
                Spacer()
                
                if let nutrition = nutrition {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(nutrition.calories) cal")
                            .font(.body)
                            .fontWeight(.medium)
                        
                        HStack(spacing: 8) {
                            Text("P:\(Int(nutrition.protein))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("C:\(Int(nutrition.carbs))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("F:\(Int(nutrition.fat))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private func updateQuantity() {
        if let newQuantity = Double(quantityText), newQuantity > 0 {
            item.quantityGrams = newQuantity
            do {
                try item.managedObjectContext?.save()
            } catch {
                print("Error updating quantity: \(error)")
            }
        }
        editingQuantity = false
    }
}

struct NutritionBadge: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}