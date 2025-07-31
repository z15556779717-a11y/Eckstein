//
//  EcksteinDietView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

struct FoodPickerInfo: Identifiable {
    let id = UUID()
    let category: DietRule.DietCategory
    let mealNumber: Int
}

struct EcksteinDietView: View {
    @StateObject private var viewModel = EcksteinDietViewModel()
    @StateObject private var bankManager = CalorieBankManager.shared
    @StateObject private var achievementManager = AchievementManager.shared
    @State private var selectedMeal = 1
    @State private var foodPickerInfo: FoodPickerInfo? = nil
    @State private var showingAnalytics = false
    @State private var showingCalendar = false
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        mainContent
            .overlay(achievementOverlay)
            .onChange(of: viewModel.meal1Complete) { _ in checkAchievements() }
            .onChange(of: viewModel.meal2Complete) { _ in checkAchievements() }
            .onChange(of: viewModel.snacksComplete) { _ in checkAchievements() }
            .onChange(of: bankManager.currentBalance) { _ in checkAchievements() }
            .onReceive(viewModel.objectWillChange) { _ in
                // Additional check when view model changes
                checkAchievements()
            }
    }
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                contentCards
            }
            .padding()
        }
        .navigationTitle("diet_tracker".localized)
        .toolbar { toolbarContent }
        .sheet(item: $foodPickerInfo) { info in
            let binding = Binding<Bool>(
                get: { true },
                set: { _ in foodPickerInfo = nil }
            )
            FoodPickerView(
                category: info.category,
                mealNumber: info.mealNumber,
                viewModel: viewModel,
                isPresented: binding
            )
        }
        .sheet(isPresented: $showingAnalytics) {
            NavigationView {
                EcksteinDietAnalyticsView()
            }
        }
        .sheet(isPresented: $showingCalendar) {
            NavigationView {
                DietCalendarView()
            }
            .onDisappear {
                bankManager.loadCurrentBalance()
            }
        }
    }
    
    private var contentCards: some View {
        Group {
            // Daily Overview Card
            DailyOverviewCard(viewModel: viewModel)
            
            // Fat Meal Tracker Card
            FatMealTrackerCard(viewModel: viewModel)
            
            // Carb Load Tracker Card
            CarbLoadTrackerCard(viewModel: viewModel)
            
            // Meal Selector
            mealSelector
            
            // Current Meal Card
            CurrentMealCard(
                mealNumber: selectedMeal,
                viewModel: viewModel,
                onSelectFood: { category in
                    foodPickerInfo = FoodPickerInfo(category: category, mealNumber: selectedMeal)
                }
            )
            
            // Snacks Section
            SnacksCard(viewModel: viewModel, onAddSnack: {
                foodPickerInfo = FoodPickerInfo(category: .snack, mealNumber: selectedMeal)
            })
            
            // Daily Summary
            EcksteinDailySummaryCard(viewModel: viewModel)
            
            // Calorie Bank Card
            CalorieBankCard(bankManager: bankManager, selectedMeal: selectedMeal)
            
            // Milk Bank Card
            MilkBankCard()
        }
    }
    
    private var mealSelector: some View {
        Group {
            if viewModel.isCarbLoadDay && viewModel.combineMealsForCarbLoad {
                // When combining meals, only show carb load
                Text("carb_load_meal".localized)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
            } else {
                Picker("Meal", selection: $selectedMeal) {
                    Text("meal_1".localized).tag(1)
                    if viewModel.isCarbLoadDay && viewModel.carbLoadMealNumber == 2 {
                        Text("carb_load".localized).tag(2)
                    } else {
                        Text("meal_2".localized).tag(2)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
            }
        }
    }
    
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 16) {
                Button(action: { showingCalendar = true }) {
                    Image(systemName: "calendar")
                        .foregroundColor(toolbarIconColor)
                }
                
                Button(action: { showingAnalytics = true }) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(toolbarIconColor)
                }
            }
        }
    }
    
    private var toolbarIconColor: Color {
        themeManager.accentColor == .defaultMix ? 
            themeManager.accentColor.contextColor(for: .diet) : 
            themeManager.accentColor.color
    }
    
    private var achievementOverlay: some View {
        Group {
            if achievementManager.showUnlockPopup, let achievement = achievementManager.unlockedAchievement {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .transition(.opacity)
                    
                    AchievementUnlockView(
                        achievement: achievement,
                        isPresented: $achievementManager.showUnlockPopup
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut, value: achievementManager.showUnlockPopup)
    }
    
    private func checkAchievements() {
        achievementManager.checkForNewAchievements(
            dietViewModel: viewModel,
            bankManager: bankManager
        )
    }
}

struct DailyOverviewCard: View {
    @ObservedObject var viewModel: EcksteinDietViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("todays_progress".localized)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Image(systemName: "chart.pie.fill")
                    .font(.title2)
                    .foregroundColor(themeManager.accentColor == .defaultMix ? 
                                   themeManager.accentColor.contextColor(for: .diet) : 
                                   themeManager.accentColor.color)
            }
            
            HStack(spacing: 20) {
                ProgressItem(
                    title: "meal_1".localized,
                    isComplete: viewModel.meal1Complete,
                    color: themeManager.accentColor == .defaultMix ? 
                         themeManager.accentColor.contextColor(for: .diet) : 
                         themeManager.accentColor.color
                )
                
                ProgressItem(
                    title: "meal_2".localized,
                    isComplete: viewModel.meal2Complete,
                    color: themeManager.accentColor == .defaultMix ? 
                         themeManager.accentColor.contextColor(for: .diet) : 
                         themeManager.accentColor.color
                )
                
                ProgressItem(
                    title: "snacks".localized,
                    isComplete: viewModel.snacksComplete,
                    color: themeManager.accentColor == .defaultMix ? 
                         themeManager.accentColor.contextColor(for: .diet) : 
                         themeManager.accentColor.color
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct ProgressItem: View {
    let title: String
    let isComplete: Bool
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundColor(isComplete ? color : .gray)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CurrentMealCard: View {
    let mealNumber: Int
    @ObservedObject var viewModel: EcksteinDietViewModel
    let onSelectFood: (DietRule.DietCategory) -> Void
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    private var meal: DietMealEntry? {
        mealNumber == 1 ? viewModel.todayMeal1 : viewModel.todayMeal2
    }
    
    private func calculateTotalPercentageWithCarryOver(meal: DietMealEntry?, category: DietRule.DietCategory, carryOver: Double?) -> Double {
        guard let meal = meal else { 
            return 0
        }
        
        // Just return the meal's actual percentage
        // The carry-over is just for display purposes, not for calculating the total
        return meal.totalPercentage(for: category)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(viewModel.isCarbLoadDay && mealNumber == viewModel.carbLoadMealNumber ? "carb_load_meal".localized : "meal_number".localized(mealNumber))
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if mealNumber == 1 {
                    // For meal 1, check if it's borrowing from meal 2
                    let proteinUsed = meal?.totalPercentage(for: .proteinNonFat) ?? 0
                    let carbsUsed = meal?.totalPercentage(for: .carbs) ?? 0
                    
                    if proteinUsed > 100 || carbsUsed > 100 {
                        Text("borrowing_from_meal_2".localized)
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                    }
                } else if let carryOver = viewModel.getCarryOverFromPreviousMeal(for: mealNumber),
                   carryOver.proteinPercentage != 0 || carryOver.carbPercentage != 0 {
                    let hasBorrowing = carryOver.proteinPercentage < 0 || carryOver.carbPercentage < 0
                    Text(hasBorrowing ? "borrowing_to_meal_1".localized : "has_carry_over".localized)
                        .font(.caption)
                        .foregroundColor(hasBorrowing ? .orange : .green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((hasBorrowing ? Color.orange : Color.green).opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            if viewModel.isCarbLoadDay && mealNumber == viewModel.carbLoadMealNumber {
                // Carb Load Section
                EcksteinFoodSection(
                    title: "carb_load_foods".localized,
                    category: .carbLoad,
                    entries: meal?.carbFoods ?? [],
                    totalPercentage: 0, // No percentage limits for carb load
                    carryOver: nil,
                    onSelect: { onSelectFood(.carbLoad) },
                    onToggleType: nil,
                    viewModel: viewModel,
                    mealNumber: mealNumber,
                    isCarbLoad: true
                )
            } else {
                // Protein Section (unified for both fat and non-fat)
                EcksteinFoodSection(
                    title: "protein".localized,
                    category: .proteinNonFat, // Use as generic protein category
                    entries: meal?.proteinFoods ?? [],
                    totalPercentage: calculateTotalPercentageWithCarryOver(
                        meal: meal,
                        category: .proteinNonFat,
                        carryOver: viewModel.getCarryOverFromPreviousMeal(for: mealNumber)?.proteinPercentage
                    ),
                    carryOver: viewModel.getCarryOverFromPreviousMeal(for: mealNumber)?.proteinPercentage,
                    onSelect: { onSelectFood(viewModel.selectedProteinType) },
                    onToggleType: nil, // Remove toggle functionality
                    viewModel: viewModel,
                    mealNumber: mealNumber
                )
                
                Divider()
                
                // Carbs Section
                EcksteinFoodSection(
                    title: "carbs".localized,
                    category: .carbs,
                    entries: meal?.carbFoods ?? [],
                    totalPercentage: calculateTotalPercentageWithCarryOver(
                        meal: meal,
                        category: .carbs,
                        carryOver: viewModel.getCarryOverFromPreviousMeal(for: mealNumber)?.carbPercentage
                    ),
                    carryOver: viewModel.getCarryOverFromPreviousMeal(for: mealNumber)?.carbPercentage,
                    onSelect: { onSelectFood(.carbs) },
                    onToggleType: nil,
                    viewModel: viewModel,
                    mealNumber: mealNumber
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct EcksteinFoodSection: View {
    let title: String
    let category: DietRule.DietCategory
    let entries: [DietMealEntry.DietFoodEntry]
    let totalPercentage: Double
    let carryOver: Double?
    let onSelect: () -> Void
    let onToggleType: (() -> Void)?
    let viewModel: EcksteinDietViewModel
    let mealNumber: Int
    var isCarbLoad: Bool = false
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    private var totalPercentageText: String {
        let baseText = "\(Int(totalPercentage))%"
        guard let carryOver = carryOver, carryOver != 0 else {
            return baseText
        }
        
        let suffix = carryOver > 0 ? 
            " (\("incl_carry_over".localized))" : 
            " (\("incl_borrowing".localized))"
        return baseText + suffix
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                if mealNumber == 1 {
                    // For meal 1, show if borrowing
                    let percentage = totalPercentage
                    if percentage > 100 {
                        Text(LocalizedStringKey("+\(Int(percentage - 100))% \("borrowed".localized)"))
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                } else if let carryOver = carryOver, carryOver != 0 {
                    // For meal 2, show carry-over or borrowed
                    if carryOver > 0 {
                        Text(LocalizedStringKey("+\(Int(carryOver))% \("carry_over".localized)"))
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text(LocalizedStringKey("\(Int(carryOver))% \("borrowed".localized)"))
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            if !entries.isEmpty {
                // Show all food entries
                ForEach(entries, id: \.food.foodName) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.food.foodName)
                                .font(.subheadline)
                            
                            HStack {
                                Text("\(entry.gramsConsumed)g")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("•")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                // Show percentage contribution to daily total
                                let contribution = Double(entry.gramsConsumed) / Double(entry.food.dailyGrams) * 100
                                Text(LocalizedStringKey("\(Int(contribution))% \("of_daily".localized)"))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(contribution >= 100 ? .green : themeManager.accentColor.color)
                            }
                        }
                        
                        Spacer()
                        
                        // Remove button
                        Button(action: {
                            viewModel.removeFoodFromMeal(
                                mealNumber: mealNumber,
                                food: entry.food,
                                category: category
                            )
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                if !isCarbLoad {
                    // Total consumed info
                    HStack {
                        Text("total_progress".localized)
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(totalPercentageText)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(totalPercentage >= 100 ? .green : .orange)
                    }
                    .padding(.horizontal, 4)
                    
                    // Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 4)
                            
                            // Progress bar always maxes out at 100% visually
                            Rectangle()
                                .fill(totalPercentage >= 100 ? Color.green : 
                                    (themeManager.accentColor == .defaultMix ? 
                                     themeManager.accentColor.contextColor(for: .diet) : 
                                     themeManager.accentColor.color))
                                .frame(width: geometry.size.width * min(totalPercentage / 100.0, 1.0), height: 4)
                        }
                    }
                    .frame(height: 4)
                    
                    // Add more button if total across both meals is under 200%
                    let totalAcrossBothMeals = viewModel.getTotalCategoryPercentage(for: category)
                    if totalAcrossBothMeals < 200 {
                        Button(action: onSelect) {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text(LocalizedStringKey("\("add_more".localized) \(title)"))
                            }
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.1))
                            .foregroundColor(.orange)
                            .cornerRadius(8)
                        }
                        .padding(.top, 8)
                    }
                } else {
                    // Carb load - no restrictions
                    HStack {
                        Text("no_quantity_limits_carb_load".localized)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                        
                        Spacer()
                        
                        Image(systemName: "flame.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                    
                    Button(action: onSelect) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text(LocalizedStringKey("\("add_more".localized) \(title)"))
                        }
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .cornerRadius(8)
                    }
                    .padding(.top, 8)
                }
                
            } else {
                Button(action: onSelect) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(LocalizedStringKey("\("add".localized) \(title)"))
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .foregroundColor(.orange)
                    .cornerRadius(12)
                }
            }
        }
    }
}

struct SnacksCard: View {
    @ObservedObject var viewModel: EcksteinDietViewModel
    let onAddSnack: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("snacks".localized)
                    .font(.headline)
                
                Spacer()
                
                Button(action: onAddSnack) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(themeManager.accentColor == .defaultMix ? 
                                       themeManager.accentColor.contextColor(for: .diet) : 
                                       themeManager.accentColor.color)
                }
            }
            
            if viewModel.todaySnacks.isEmpty {
                Text("no_snacks_logged_today".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(viewModel.todaySnacks, id: \.food.foodName) { snack in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Text(snack.food.foodName)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.removeSnack(snack.food)
                        }) {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            
            // Add Snack Button
            Button(action: onAddSnack) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("add_snack".localized)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .foregroundColor(themeManager.accentColor == .defaultMix ? 
                               themeManager.accentColor.contextColor(for: .diet) : 
                               themeManager.accentColor.color)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct EcksteinDailySummaryCard: View {
    @ObservedObject var viewModel: EcksteinDietViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("daily_summary".localized)
                .font(.headline)
            
            if let summary = viewModel.getDailySummary() {
                VStack(alignment: .leading, spacing: 8) {
                    SummaryRow(title: "total_protein".localized, value: "\(summary.totalProteinGrams)g", percentage: summary.proteinPercentage)
                    SummaryRow(title: "total_carbs".localized, value: "\(summary.totalCarbGrams)g", percentage: summary.carbPercentage)
                    
                    if let carryOver = viewModel.getCarryOverFromPreviousMeal(for: 2),
                       viewModel.todayMeal2 == nil,
                       (carryOver.proteinPercentage != 0 || carryOver.carbPercentage != 0) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(carryOver.proteinPercentage < 0 || carryOver.carbPercentage < 0 ? "meal_2_budget".localized : "available_for_meal_2".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if carryOver.proteinPercentage != 0 {
                                let isBorrowed = carryOver.proteinPercentage < 0
                                Text(LocalizedStringKey("• \("protein".localized): \(isBorrowed ? "" : "+")\(Int(carryOver.proteinPercentage))%"))
                                    .font(.caption)
                                    .foregroundColor(isBorrowed ? .orange : .green)
                            }
                            if carryOver.carbPercentage != 0 {
                                let isBorrowed = carryOver.carbPercentage < 0
                                Text(LocalizedStringKey("• \("carbs".localized): \(isBorrowed ? "" : "+")\(Int(carryOver.carbPercentage))%"))
                                    .font(.caption)
                                    .foregroundColor(isBorrowed ? .orange : .green)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            } else {
                Text("start_logging_meals_summary".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct SummaryRow: View {
    let title: String
    let value: String
    let percentage: Double
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("(\(Int(percentage))%)")
                .font(.caption)
                .foregroundColor(percentage >= 100 ? .green : .orange)
        }
    }
}

struct FatMealTrackerCard: View {
    @ObservedObject var viewModel: EcksteinDietViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var fatMealManager = FatMealManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        let fatMealsInfo = viewModel.getFatMealsInfo()
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text("weekly_fat_meals".localized)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(fatMealsInfo.used) / 2")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(fatMealsInfo.used >= 2 ? .red : themeManager.accentColor.color)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(fatMealsInfo.used >= 2 ? Color.red : 
                             (fatMealsInfo.used == 1 ? Color.orange : Color.green))
                        .frame(width: geometry.size.width * (Double(fatMealsInfo.used) / 2.0), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
            
            HStack {
                if fatMealsInfo.remaining > 0 {
                    Label(fatMealsInfo.remaining == 1 ? "fat_meal_remaining_singular".localized : "fat_meals_remaining".localized(fatMealsInfo.remaining), 
                          systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Label("fat_meal_limit_reached".localized, 
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                Text("resets_sunday".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct CarbLoadTrackerCard: View {
    @ObservedObject var viewModel: EcksteinDietViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @StateObject private var carbLoadManager = CarbLoadManager.shared
    @State private var showCarbLoadOptions = false
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        let carbLoadInfo = viewModel.getCarbLoadInfo()
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame.circle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text("weekly_carb_load".localized)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if viewModel.isCarbLoadDay {
                    Text("active".localized)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .cornerRadius(8)
                } else {
                    Text(carbLoadInfo.used ? "used".localized : "available".localized)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(carbLoadInfo.used ? .gray : .green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(carbLoadInfo.used ? Color.gray.opacity(0.2) : Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            
            // Progress indicator
            HStack {
                Circle()
                    .fill(carbLoadInfo.used ? Color.orange : Color.gray.opacity(0.3))
                    .frame(width: 20, height: 20)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 2)
                
                Text("one_per_week".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Action section
            if viewModel.isCarbLoadDay {
                // Options when carb load is active
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text(viewModel.combineMealsForCarbLoad ? 
                             "combining_meals_carb_load".localized : 
                             "carb_load_replacing_meal".localized(viewModel.carbLoadMealNumber ?? 2))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: { viewModel.toggleMealCombination() }) {
                            HStack {
                                Image(systemName: viewModel.combineMealsForCarbLoad ? "rectangle.on.rectangle.slash" : "rectangle.on.rectangle")
                                    .font(.caption)
                                Text(viewModel.combineMealsForCarbLoad ? "separate_meals".localized : "combine_meals".localized)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                        }
                        
                        Button(action: { viewModel.toggleCarbLoadDay() }) {
                            HStack {
                                Image(systemName: "xmark.circle")
                                    .font(.caption)
                                Text("cancel".localized)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(8)
                        }
                    }
                }
            } else if !carbLoadInfo.used {
                // Enable carb load button
                Button(action: { viewModel.toggleCarbLoadDay() }) {
                    HStack {
                        Image(systemName: "flame.circle")
                        Text("activate_carb_load_day".localized)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.orange.opacity(0.1))
                    .foregroundColor(.orange)
                    .cornerRadius(10)
                }
            } else {
                // Already used this week
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let date = carbLoadInfo.date {
                        Text(LocalizedStringKey("\("used_on".localized) \(date, format: .dateTime.weekday(.abbreviated).month().day())"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("resets_sunday".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}