//
//  QuickAddView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI
import CoreData

struct QuickAddView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchViewModel = FoodSearchViewModel()
    @State private var selectedMealType: String = "snack"
    @State private var selectedFoods: [(food: CDFood, quantity: Double)] = []
    @State private var showFoodSearch = false
    @ObservedObject private var themeManager = ThemeManager.shared
    
    let mealTypes = ["breakfast", "lunch", "dinner", "snack"]
    private let dietRepository = ServiceContainer.shared.dietRepository
    
    var totalNutrition: NutritionInfo {
        var calories = 0
        var protein = 0.0
        var carbs = 0.0
        var fat = 0.0
        var fiber = 0.0
        
        for (food, quantity) in selectedFoods {
            let nutrition = ServingSizeCalculator.calculateNutrition(
                for: food,
                servingGrams: quantity
            )
            calories += nutrition.calories
            protein += nutrition.protein
            carbs += nutrition.carbs
            fat += nutrition.fat
            fiber += nutrition.fiber
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
        NavigationView {
            VStack(spacing: 20) {
                // Meal Type Selector
                VStack(alignment: .leading, spacing: 12) {
                    Text("quick_add_meal_type".localized)
                        .font(.headline)

                    Picker("quick_add_meal_type".localized, selection: $selectedMealType) {
                        ForEach(mealTypes, id: \.self) { type in
                            Text(type.capitalized).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding(.horizontal)
                
                // Quick Add Sections
                ScrollView {
                    VStack(spacing: 20) {
                        // Favorites
                        if !searchViewModel.favoriteFoods.isEmpty {
                            QuickAddSection(
                                title: "Favorites",
                                foods: searchViewModel.favoriteFoods,
                                selectedFoods: $selectedFoods,
                                onToggleFavorite: searchViewModel.toggleFavorite
                            )
                        }
                        
                        // Recent Foods
                        if !searchViewModel.recentFoods.isEmpty {
                            QuickAddSection(
                                title: "Recent",
                                foods: searchViewModel.recentFoods,
                                selectedFoods: $selectedFoods,
                                onToggleFavorite: searchViewModel.toggleFavorite
                            )
                        }
                        
                        // Selected Foods Summary
                        if !selectedFoods.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("quick_add_selected_foods".localized)
                                    .font(.headline)
                                
                                ForEach(selectedFoods.indices, id: \.self) { index in
                                    SelectedFoodRow(
                                        food: selectedFoods[index].food,
                                        quantity: selectedFoods[index].quantity,
                                        onUpdateQuantity: { newQuantity in
                                            selectedFoods[index].quantity = newQuantity
                                        },
                                        onRemove: {
                                            selectedFoods.remove(at: index)
                                        }
                                    )
                                }
                                
                                // Total Nutrition
                                HStack {
                                    Text("quick_add_total_label".localized)
                                        .font(.headline)
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 12) {
                                        Text("\(totalNutrition.calories) cal")
                                            .fontWeight(.medium)
                                        Text("P: \(Int(totalNutrition.protein))g")
                                            .font(.caption)
                                        Text("C: \(Int(totalNutrition.carbs))g")
                                            .font(.caption)
                                        Text("F: \(Int(totalNutrition.fat))g")
                                            .font(.caption)
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                
                // Action Buttons
                HStack(spacing: 16) {
                    Button(action: { showFoodSearch = true }) {
                        Label("quick_add_search_more".localized, systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    
                    Button(action: saveMeal) {
                        Text("save_meal".localized)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedFoods.isEmpty ? Color.gray : themeManager.dietPrimaryColor)
                            .cornerRadius(12)
                    }
                    .disabled(selectedFoods.isEmpty)
                }
                .padding()
            }
            .navigationTitle("quick_add".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showFoodSearch) {
                FoodSearchView { food in
                    selectedFoods.append((food, 100))
                }
            }
            .onAppear {
                searchViewModel.fetchRecentFoods()
                searchViewModel.fetchFavoriteFoods()
                setDefaultMealType()
            }
        }
    }
    
    private func setDefaultMealType() {
        let hour = Calendar.current.component(.hour, from: Date())
        
        if hour < 10 {
            selectedMealType = "breakfast"
        } else if hour < 14 {
            selectedMealType = "lunch"
        } else if hour < 18 {
            selectedMealType = "snack"
        } else {
            selectedMealType = "dinner"
        }
    }
    
    private func saveMeal() {
        let meal = dietRepository.createMeal(
            mealType: selectedMealType,
            date: Date()
        )
        
        for (food, quantity) in selectedFoods {
            dietRepository.addFoodToMeal(meal, food: food, quantityGrams: quantity)
            searchViewModel.markFoodAsUsed(food)
        }
        
        dismiss()
    }
}

struct QuickAddSection: View {
    let title: String
    let foods: [CDFood]
    @Binding var selectedFoods: [(food: CDFood, quantity: Double)]
    let onToggleFavorite: (CDFood) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(foods) { food in
                        QuickAddFoodCard(
                            food: food,
                            isSelected: selectedFoods.contains(where: { $0.food.id == food.id }),
                            onToggle: {
                                if let index = selectedFoods.firstIndex(where: { $0.food.id == food.id }) {
                                    selectedFoods.remove(at: index)
                                } else {
                                    selectedFoods.append((food, food.servingSize))
                                }
                            },
                            onToggleFavorite: { onToggleFavorite(food) }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct QuickAddFoodCard: View {
    let food: CDFood
    let isSelected: Bool
    let onToggle: () -> Void
    let onToggleFavorite: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(food.name ?? "unknown".localized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                Spacer()
                
                Button(action: onToggleFavorite) {
                    Image(systemName: food.isFavorite ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundColor(food.isFavorite ? .yellow : .gray)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            
            Text("quick_add_calories_per_100g".localized(food.caloriesPer100g))
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                Text("P: \(Int(food.proteinPer100g))")
                    .font(.caption2)
                Text("C: \(Int(food.carbsPer100g))")
                    .font(.caption2)
                Text("F: \(Int(food.fatPer100g))")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 150)
        .background(isSelected ? themeManager.dietPrimaryColor.opacity(0.1) : Color(.systemGray6))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? themeManager.dietPrimaryColor : Color.clear, lineWidth: 2)
        )
        .cornerRadius(10)
        .onTapGesture {
            onToggle()
        }
    }
}

struct SelectedFoodRow: View {
    let food: CDFood
    let quantity: Double
    let onUpdateQuantity: (Double) -> Void
    let onRemove: () -> Void
    
    @State private var quantityText = ""
    @State private var isEditing = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(food.name ?? "unknown".localized)
                    .font(.body)
                
                if isEditing {
                    HStack {
                        TextField("100", text: $quantityText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                        
                        Text("g")
                            .foregroundColor(.secondary)
                        
                        Button("done".localized) {
                            if let newQuantity = Double(quantityText), newQuantity > 0 {
                                onUpdateQuantity(newQuantity)
                            }
                            isEditing = false
                        }
                        .font(.caption)
                    }
                } else {
                    Text("\(Int(quantity))g")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .onTapGesture {
                            quantityText = String(Int(quantity))
                            isEditing = true
                        }
                }
            }
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}