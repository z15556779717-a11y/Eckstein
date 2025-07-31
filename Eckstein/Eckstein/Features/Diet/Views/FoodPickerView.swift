//
//  FoodPickerView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

struct FoodPickerView: View {
    let category: DietRule.DietCategory
    let mealNumber: Int
    @ObservedObject var viewModel: EcksteinDietViewModel
    @Binding var isPresented: Bool
    let historicalDate: Date?
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedFood: DietRule?
    @State private var gramsInput = ""
    @State private var showError = false
    @State private var showAddCustomFood = false
    @State private var useCalorieBank = false
    @State private var caloriesToUse = 0
    
    @StateObject private var bankManager = CalorieBankManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    
    init(category: DietRule.DietCategory, mealNumber: Int, viewModel: EcksteinDietViewModel, isPresented: Binding<Bool>, historicalDate: Date? = nil) {
        self.category = category
        self.mealNumber = mealNumber
        self.viewModel = viewModel
        self._isPresented = isPresented
        self.historicalDate = historicalDate
    }
    
    private var availableFoods: [DietRule] {
        let foods = viewModel.getAllFoodsForCategory(category)
        print("FoodPickerView: Loading foods for category \(category.rawValue), found \(foods.count) foods")
        return foods
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Carb load header
                if category == .carbLoad {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "flame.circle.fill")
                                .foregroundColor(.orange)
                            Text("carb_load_day_no_limits".localized)
                                .font(.headline)
                                .foregroundColor(.orange)
                            Spacer()
                            Text("weekly_treat".localized)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        Text("enjoy_carb_load_no_restrictions".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.bottom, 4)
                        
                        Divider()
                    }
                }
                
                // Fat meals info header (only for protein category)
                if category == .proteinFat || category == .proteinNonFat {
                    let fatMealsInfo = viewModel.getFatMealsInfo()
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                            Text("fat_meals_this_week".localized + ": \(fatMealsInfo.used)/2")
                                .font(.headline)
                            Spacer()
                            if fatMealsInfo.remaining == 0 {
                                Text("limit_reached".localized)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        Divider()
                    }
                }
                
                // Food Selection List
                List(Array(availableFoods.enumerated()), id: \.offset) { index, food in
                    FoodOptionRow(
                        food: food,
                        isSelected: selectedFood?.foodName == food.foodName,
                        remainingGrams: category == .carbLoad ? food.dailyGrams : viewModel.getRemainingAllowance(for: food, currentGrams: 0, mealNumber: mealNumber),
                        isFat: viewModel.isFatProtein(food),
                        canSelect: category == .carbLoad ? true : viewModel.canSelectFood(food, mealNumber: mealNumber, date: historicalDate),
                        isCarboLoad: category == .carbLoad,
                        onSelect: {
                            if category == .carbLoad || viewModel.canSelectFood(food, mealNumber: mealNumber, date: historicalDate) {
                                selectedFood = food
                                if category == .carbLoad {
                                    // For carb load, suggest full portion
                                    gramsInput = "\(food.dailyGrams)"
                                } else {
                                    // Pre-fill with remaining allowance or daily allowance
                                    let remaining = viewModel.getRemainingAllowance(for: food, currentGrams: 0, mealNumber: mealNumber)
                                    gramsInput = "\(min(remaining, food.dailyGrams / 2))" // Default to half portion
                                }
                            }
                        }
                    )
                }
                .listStyle(PlainListStyle())
                
                // Input Section
                if let selected = selectedFood {
                    VStack(spacing: 16) {
                        Divider()
                        
                        if selected.category == .snack {
                            SnackConfirmationView(selectedFood: selected)
                        } else {
                            FoodAmountInputView(
                                selectedFood: selected,
                                gramsInput: $gramsInput,
                                viewModel: viewModel,
                                mealNumber: mealNumber,
                                isCarboLoad: category == .carbLoad
                            )
                        }
                        
                        // Save button
                        Button(action: saveFood) {
                            Text(category == .snack ? "add_snack".localized : (category == .carbLoad ? "add_to_carb_load".localized : "add_to_meal".localized(mealNumber)))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(canSave() ? (category == .carbLoad ? Color.orange : themeManager.primaryButtonColor) : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .disabled(!canSave())
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                }
            }
            .navigationTitle("select".localized + " \(categoryTitle)")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                print("FoodPickerView appeared with category: \(category.rawValue)")
                // Force refresh of available foods
                _ = availableFoods
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddCustomFood = true }) {
                        Image(systemName: "plus.circle")
                    }
                }
            }
            .alert("invalid_amount".localized, isPresented: $showError) {
                Button("ok".localized) { }
            } message: {
                Text("please_enter_valid_grams".localized)
            }
            .sheet(isPresented: $showAddCustomFood) {
                AddCustomFoodView(category: category, viewModel: viewModel)
            }
        }
    }
    
    private var categoryTitle: String {
        switch category {
        case .proteinFat:
            return "protein_fat".localized
        case .proteinNonFat:
            return "protein_non_fat".localized
        case .carbs:
            return "carbs".localized
        case .snack:
            return "snack".localized
        case .carbLoad:
            return "carb_load".localized
        }
    }
    
    private func canSave() -> Bool {
        guard let food = selectedFood else { return false }
        if food.category == .snack {
            return true // Snacks don't need grams input
        } else {
            return !gramsInput.isEmpty
        }
    }
    
    private func calculateCaloriesForFood(food: DietRule, grams: Int) -> Int {
        // Rough calorie estimates per 100g based on food type
        let caloriesPer100g: Double
        
        switch food.category {
        case .proteinFat:
            caloriesPer100g = 200 // Higher for fatty proteins
        case .proteinNonFat:
            caloriesPer100g = 120 // Lower for lean proteins
        case .carbs:
            caloriesPer100g = 350 // Carbs average
        case .snack:
            caloriesPer100g = 400 // Snacks tend to be calorie-dense
        case .carbLoad:
            caloriesPer100g = 350 // Carb load similar to regular carbs
        }
        
        return Int((Double(grams) / 100.0) * caloriesPer100g)
    }
    
    private func saveFood() {
        guard let food = selectedFood else {
            showError = true
            return
        }
        
        if food.category == .snack {
            // For snacks, we don't track amounts - just that it was consumed
            viewModel.addSnack(food, gramsConsumed: 1, date: historicalDate) // Use 1 as a placeholder
        } else {
            // For regular foods, require grams input
            guard let grams = Int(gramsInput), grams > 0 else {
                showError = true
                return
            }
            viewModel.addFoodToMeal(mealNumber: mealNumber, food: food, gramsConsumed: grams, date: historicalDate)
        }
        isPresented = false
    }
}

struct FoodOptionRow: View {
    let food: DietRule
    let isSelected: Bool
    let remainingGrams: Int
    let isFat: Bool
    let canSelect: Bool
    var isCarboLoad: Bool = false
    let onSelect: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(food.foodName)
                            .font(.headline)
                            .foregroundColor(canSelect ? .primary : .secondary)
                        
                        // Fat/Lean indicator for proteins
                        if food.category == .proteinFat || food.category == .proteinNonFat {
                            Text(isFat ? "FAT" : "LEAN")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(isFat ? .orange : .green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(isFat ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        if isCarboLoad {
                            Text("Suggested: \(food.dailyGrams)g")
                                .font(.caption)
                                .foregroundColor(.orange)
                            
                            Text("• No limits!")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                        } else {
                            Text("Daily: \(food.dailyGrams)g")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if remainingGrams < food.dailyGrams {
                                Text("Available: \(remainingGrams)g")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            
                            if isFat && !canSelect {
                                Text("• Fat meal limit reached")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(themeManager.dietPrimaryColor)
                } else if !canSelect {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red.opacity(0.5))
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .opacity(canSelect ? 1.0 : 0.6)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!canSelect)
    }
}

struct SnackConfirmationView: View {
    let selectedFood: DietRule
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundColor(.green)
            
            Text("Ready to add \(selectedFood.foodName)")
                .font(.headline)
            
            Text("Tap below to confirm")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

struct FoodAmountInputView: View {
    let selectedFood: DietRule
    @Binding var gramsInput: String
    let viewModel: EcksteinDietViewModel
    let mealNumber: Int
    var isCarboLoad: Bool = false
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Amount for \(selectedFood.foodName)")
                .font(.headline)
            
            HStack {
                TextField("Grams", text: $gramsInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .frame(width: 100)
                
                Text("grams")
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Quick fill buttons
                HStack(spacing: 8) {
                    QuickFillButton(title: "25%", action: {
                        gramsInput = "\(selectedFood.dailyGrams / 4)"
                    })
                    
                    QuickFillButton(title: "50%", action: {
                        gramsInput = "\(selectedFood.dailyGrams / 2)"
                    })
                    
                    QuickFillButton(title: "100%", action: {
                        let remaining = viewModel.getRemainingAllowance(for: selectedFood, currentGrams: 0, mealNumber: mealNumber)
                        gramsInput = "\(min(remaining, selectedFood.dailyGrams))"
                    })
                }
            }
            
            // Allowance info
            if let grams = Int(gramsInput) {
                if isCarboLoad {
                    // Carb load - no restrictions
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "flame.circle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("Carb load day - enjoy without limits!")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        if grams > selectedFood.dailyGrams {
                            Text("Going big! That's \(Int(Double(grams) / Double(selectedFood.dailyGrams) * 100))% of suggested portion")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                } else {
                    let remaining = viewModel.getRemainingAllowance(for: selectedFood, currentGrams: grams, mealNumber: mealNumber)
                    let percentage = Double(grams) / Double(selectedFood.dailyGrams) * 100
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Int(percentage))% of daily allowance")
                            .font(.caption)
                            .foregroundColor(themeManager.accentColor.color)
                        
                        if remaining < 0 {
                            Text("Exceeds daily allowance by \(abs(remaining))g")
                                .font(.caption)
                                .foregroundColor(.red)
                        } else {
                            Text("\(remaining)g remaining for other meals")
                                .font(.caption)
                                .foregroundColor(themeManager.accentColor.color)
                        }
                    }
                }
            }
        }
    }
}

struct QuickFillButton: View {
    let title: String
    let action: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(themeManager.dietPrimaryColor.opacity(0.1))
                .foregroundColor(themeManager.dietPrimaryColor)
                .cornerRadius(8)
        }
    }
}