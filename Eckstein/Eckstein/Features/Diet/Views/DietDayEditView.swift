//
//  DietDayEditView.swift
//  Eckstein
//
//  Created by Assistant on 16/01/2025.
//

import SwiftUI
import CoreData
import Combine

struct DietDayEditView: View {
    let date: Date
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: DietDayEditViewModel
    @State private var selectedMeal = 1
    @State private var showingFoodPicker = false
    @State private var foodPickerType: DietRule.DietCategory = .proteinNonFat
    @State private var showingBankWithdrawal = false
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    init(date: Date) {
        self.date = date
        self._viewModel = StateObject(wrappedValue: DietDayEditViewModel(date: date))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Date Header
                VStack(spacing: 8) {
                    Text("editing_diet_data".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(dateFormatter.string(from: date))
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .padding(.top)
                
                // Progress Overview
                DayProgressOverview(viewModel: viewModel)
                
                // Fat Meal Tracker for historical view
                HistoricalFatMealTrackerCard(viewModel: viewModel)
                
                // Carb Load Tracker for historical view
                HistoricalCarbLoadTrackerCard(viewModel: viewModel)
                
                // Meal Selector
                if viewModel.dietViewModel.isCarbLoadDay && viewModel.dietViewModel.combineMealsForCarbLoad {
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
                        if viewModel.dietViewModel.isCarbLoadDay && viewModel.dietViewModel.carbLoadMealNumber == 2 {
                            Text("carb_load".localized).tag(2)
                        } else {
                            Text("meal_2".localized).tag(2)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                }
                
                // Meal Card
                EditableMealCard(
                    mealNumber: selectedMeal,
                    viewModel: viewModel,
                    onSelectFood: { category in
                        foodPickerType = category
                        showingFoodPicker = true
                    }
                )
                
                // Snacks Section
                EditableSnacksCard(viewModel: viewModel, onAddSnack: {
                    foodPickerType = .snack
                    showingFoodPicker = true
                })
                
                // Calorie Bank Section
                CalorieBankDayCard(
                    date: date,
                    viewModel: viewModel,
                    onAddWithdrawal: { showingBankWithdrawal = true }
                )
                
                // Day Summary
                PastDaySummaryCard(viewModel: viewModel)
            }
            .padding()
        }
        .navigationTitle("Edit Diet History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingFoodPicker) {
            HistoricalFoodPickerView(
                category: foodPickerType,
                mealNumber: selectedMeal,
                date: date,
                viewModel: viewModel.dietViewModel,
                isPresented: $showingFoodPicker
            )
        }
        .sheet(isPresented: $showingBankWithdrawal) {
            CalorieBankHistoryWithdrawalView(
                date: date,
                viewModel: viewModel,
                isPresented: $showingBankWithdrawal
            )
        }
        .onAppear {
            viewModel.loadDataForDate()
        }
    }
}

struct DayProgressOverview: View {
    @ObservedObject var viewModel: DietDayEditViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("days_progress".localized)
                .font(.headline)
            
            HStack(spacing: 20) {
                ProgressCircle(
                    title: "Meal 1",
                    isComplete: viewModel.meal1Complete,
                    color: themeManager.accentColor == .defaultMix ?
                         themeManager.accentColor.contextColor(for: .diet) :
                         themeManager.accentColor.color
                )
                
                ProgressCircle(
                    title: "Meal 2",
                    isComplete: viewModel.meal2Complete,
                    color: themeManager.accentColor == .defaultMix ?
                         themeManager.accentColor.contextColor(for: .diet) :
                         themeManager.accentColor.color
                )
                
                ProgressCircle(
                    title: "Snacks",
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

struct ProgressCircle: View {
    let title: String
    let isComplete: Bool
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                    .frame(width: 60, height: 60)
                
                if isComplete {
                    Circle()
                        .fill(color)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                }
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct EditableMealCard: View {
    let mealNumber: Int
    @ObservedObject var viewModel: DietDayEditViewModel
    let onSelectFood: (DietRule.DietCategory) -> Void
    
    var body: some View {
        // Create a custom meal card that handles historical dates
        HistoricalMealCard(
            mealNumber: mealNumber,
            viewModel: viewModel.dietViewModel,
            date: viewModel.date,
            onSelectFood: onSelectFood
        )
    }
}

// Custom meal card for historical editing
struct HistoricalMealCard: View {
    let mealNumber: Int
    @ObservedObject var viewModel: EcksteinDietViewModel
    let date: Date
    let onSelectFood: (DietRule.DietCategory) -> Void
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private var meal: DietMealEntry? {
        mealNumber == 1 ? viewModel.todayMeal1 : viewModel.todayMeal2
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(viewModel.isCarbLoadDay && mealNumber == viewModel.carbLoadMealNumber ? "Carb Load Meal" : "Meal \(mealNumber)")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if mealNumber == 1 {
                    // For meal 1, check if it's borrowing from meal 2
                    let proteinUsed = meal?.totalPercentage(for: .proteinNonFat) ?? 0
                    let carbsUsed = meal?.totalPercentage(for: .carbs) ?? 0
                    
                    if proteinUsed > 100 || carbsUsed > 100 {
                        Text("Borrowing from meal 2")
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
                    Text(hasBorrowing ? "Borrowing to meal 1" : "Has carry-over")
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
                HistoricalFoodSection(
                    title: "Carb Load Foods",
                    category: .carbLoad,
                    entries: meal?.carbFoods ?? [],
                    totalPercentage: 0, // No percentage limits for carb load
                    carryOver: nil,
                    onSelect: { onSelectFood(.carbLoad) },
                    viewModel: viewModel,
                    mealNumber: mealNumber,
                    date: date,
                    isCarbLoad: true
                )
            } else {
                // Protein Section (unified for both fat and non-fat)
                HistoricalFoodSection(
                    title: "protein".localized,
                    category: .proteinNonFat,
                    entries: meal?.proteinFoods ?? [],
                    totalPercentage: meal?.totalPercentage(for: .proteinNonFat) ?? 0,
                    carryOver: viewModel.getCarryOverFromPreviousMeal(for: mealNumber)?.proteinPercentage,
                    onSelect: { onSelectFood(viewModel.selectedProteinType) },
                    viewModel: viewModel,
                    mealNumber: mealNumber,
                    date: date
                )
                
                Divider()
                
                // Carbs Section
                HistoricalFoodSection(
                    title: "carbs".localized,
                    category: .carbs,
                    entries: meal?.carbFoods ?? [],
                    totalPercentage: meal?.totalPercentage(for: .carbs) ?? 0,
                    carryOver: viewModel.getCarryOverFromPreviousMeal(for: mealNumber)?.carbPercentage,
                    onSelect: { onSelectFood(.carbs) },
                    viewModel: viewModel,
                    mealNumber: mealNumber,
                    date: date
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct HistoricalCarbLoadTrackerCard: View {
    @ObservedObject var viewModel: DietDayEditViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @StateObject private var carbLoadManager = CarbLoadManager.shared
    
    var body: some View {
        let calendar = Calendar.current
        let weekRange = calendar.weekRange(for: viewModel.date)
        let hasUsedCarbLoad = !carbLoadManager.canUseCarbLoadForWeek(of: viewModel.date)
        let carbLoadDate = carbLoadManager.getCarbLoadDateForWeek(of: viewModel.date)
        let isCurrentDayCarboLoad = carbLoadManager.isCarbLoadDay(date: viewModel.date)
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame.circle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text("weekly_carb_load".localized)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if isCurrentDayCarboLoad {
                    Text("active".localized)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .cornerRadius(8)
                } else {
                    Text(hasUsedCarbLoad ? "Used" : "Available")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(hasUsedCarbLoad ? .gray : .green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(hasUsedCarbLoad ? Color.gray.opacity(0.2) : Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            
            // Progress indicator
            HStack {
                Circle()
                    .fill(hasUsedCarbLoad ? Color.orange : Color.gray.opacity(0.3))
                    .frame(width: 20, height: 20)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 2)
                
                Text("1 / week")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Action section
            if isCurrentDayCarboLoad {
                // Options when carb load is active
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text(viewModel.dietViewModel.combineMealsForCarbLoad ? 
                             "Combining meals into one carb load" : 
                             "Carb load replacing meal \(viewModel.dietViewModel.carbLoadMealNumber ?? 2)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: { viewModel.toggleMealCombination() }) {
                            HStack {
                                Image(systemName: viewModel.dietViewModel.combineMealsForCarbLoad ? "rectangle.on.rectangle.slash" : "rectangle.on.rectangle")
                                    .font(.caption)
                                Text(viewModel.dietViewModel.combineMealsForCarbLoad ? "Separate Meals" : "Combine Meals")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(themeManager.dietPrimaryColor.opacity(0.1))
                            .foregroundColor(themeManager.dietPrimaryColor)
                            .cornerRadius(8)
                        }
                        
                        Button(action: { viewModel.toggleCarbLoadDay() }) {
                            HStack {
                                Image(systemName: "xmark.circle")
                                    .font(.caption)
                                Text("Cancel")
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
            } else if !hasUsedCarbLoad {
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
                    
                    if let date = carbLoadDate {
                        Text("Used on \(date, format: .dateTime.weekday(.abbreviated).month().day())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if let weekStart = weekRange?.lowerBound,
                       let weekEnd = weekRange?.upperBound {
                        Text("\(weekStart, format: .dateTime.month(.abbreviated).day()) - \(weekEnd, format: .dateTime.month(.abbreviated).day())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .onAppear {
            // Load carb load data for the week when viewing historical date
            carbLoadManager.loadCurrentWeekData()
        }
    }
}

struct HistoricalFatMealTrackerCard: View {
    @ObservedObject var viewModel: DietDayEditViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @StateObject private var fatMealManager = FatMealManager.shared
    
    var body: some View {
        let calendar = Calendar.current
        let weekRange = calendar.weekRange(for: viewModel.date)
        let weekFatMeals = fatMealManager.getFatMealsForWeek(of: viewModel.date)
        let remaining = max(0, 2 - weekFatMeals)
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text("Fat Meals This Week")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(weekFatMeals) / 2")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(weekFatMeals >= 2 ? .red : themeManager.accentColor.color)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(weekFatMeals >= 2 ? Color.red : 
                             (weekFatMeals == 1 ? Color.orange : Color.green))
                        .frame(width: geometry.size.width * (Double(weekFatMeals) / 2.0), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
            
            HStack {
                if remaining > 0 {
                    Label("\(remaining) fat meal\(remaining == 1 ? "" : "s") remaining", 
                          systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Label("Fat meal limit reached for this week", 
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                if let weekStart = weekRange?.lowerBound,
                   let weekEnd = weekRange?.upperBound {
                    Text("\(weekStart, format: .dateTime.month(.abbreviated).day()) - \(weekEnd, format: .dateTime.month(.abbreviated).day())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .onAppear {
            // Update fat meal tracking when viewing historical date
            fatMealManager.updateFatMealTrackingForWeek(of: viewModel.date, customFoods: viewModel.dietViewModel.customFoods)
        }
    }
}

struct HistoricalFoodSection: View {
    let title: String
    let category: DietRule.DietCategory
    let entries: [DietMealEntry.DietFoodEntry]
    let totalPercentage: Double
    let carryOver: Double?
    let onSelect: () -> Void
    let viewModel: EcksteinDietViewModel
    let mealNumber: Int
    let date: Date
    var isCarbLoad: Bool = false
    @ObservedObject private var themeManager = ThemeManager.shared
    
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
                        Text("+\(Int(percentage - 100))% borrowed")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                } else if let carryOver = carryOver, carryOver != 0 {
                    // For meal 2, show carry-over or borrowed
                    if carryOver > 0 {
                        Text("+\(Int(carryOver))% carry-over")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("\(Int(carryOver))% borrowed")
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
                                Text("\(Int(contribution))% of daily")
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
                                category: category,
                                date: date
                            )
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                }
                
                // Total consumed info
                HStack {
                    Text("Total Progress")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(Int(totalPercentage))% \(carryOver != nil && carryOver! != 0 ? (carryOver! > 0 ? "(incl. carry-over)" : "(incl. borrowing)") : "")")
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
                
                if !isCarbLoad {
                    // Add more button if total across both meals is under 200%
                    let totalAcrossBothMeals = viewModel.getTotalCategoryPercentage(for: category)
                    if totalAcrossBothMeals < 200 {
                        Button(action: onSelect) {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text(LocalizedStringKey("\\(\"add_more\".localized) \\(title)"))
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
                        Text("No quantity limits for carb load!")
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
                            Text(LocalizedStringKey("\\(\"add_more\".localized) \\(title)"))
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
                        Text(LocalizedStringKey("\\(\"add\".localized) \\(title)"))
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

struct EditableSnacksCard: View {
    @ObservedObject var viewModel: DietDayEditViewModel
    let onAddSnack: () -> Void
    
    var body: some View {
        HistoricalSnacksCard(
            viewModel: viewModel.dietViewModel,
            date: viewModel.date,
            onAddSnack: onAddSnack
        )
    }
}

struct HistoricalSnacksCard: View {
    @ObservedObject var viewModel: EcksteinDietViewModel
    let date: Date
    let onAddSnack: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Snacks")
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
                Text("No snacks logged today")
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
                            viewModel.removeSnack(snack.food, date: date)
                        }) {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray5))
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
                .background(Color(.systemGray5))
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

struct CalorieBankDayCard: View {
    let date: Date
    @ObservedObject var viewModel: DietDayEditViewModel
    let onAddWithdrawal: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "building.columns.fill")
                    .font(.title3)
                    .foregroundColor(themeManager.accentColor.color)
                
                Text("Calorie Bank Activity")
                    .font(.headline)
                
                Spacer()
                
                Button(action: onAddWithdrawal) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(themeManager.accentColor.color)
                }
            }
            
            if viewModel.dayBankTransactions.isEmpty {
                Text("No calorie bank activity for this day")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(viewModel.dayBankTransactions) { transaction in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(transaction.foodName ?? "Manual Entry")
                                .font(.subheadline)
                            
                            Text("\(transaction.amount) calories")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if transaction.type == .withdrawal {
                            Text("-\(transaction.amount)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                        }
                        
                        Button(action: {
                            viewModel.deleteCalorieBankTransaction(transaction)
                        }) {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                }
            }
            
            // Total used
            if !viewModel.dayBankTransactions.isEmpty {
                HStack {
                    Text("Total Used")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(viewModel.totalBankCaloriesUsed) calories")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct CalorieBankHistoryWithdrawalView: View {
    let date: Date
    @ObservedObject var viewModel: DietDayEditViewModel
    @Binding var isPresented: Bool
    
    @State private var foodName = ""
    @State private var calories = ""
    @State private var showError = false
    @State private var showingManageItems = false
    @StateObject private var commonItemsManager = CommonCalorieItemsManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Log Past Calorie Consumption")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                Text("Recording for: \(date, formatter: DateFormatter.mediumDateFormatter)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Food Item")
                        .font(.headline)
                    
                    TextField("e.g., Soy sauce, Oil, Dressing", text: $foodName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Text("Calories")
                        .font(.headline)
                    
                    HStack {
                        TextField("Enter calories", text: $calories)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                        
                        Text("cal")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                // Common items section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Common Items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: { showingManageItems = true }) {
                            Image(systemName: "gear")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(commonItemsManager.items) { item in
                                QuickFoodButton(
                                    name: item.name,
                                    calories: item.calories,
                                    foodName: $foodName,
                                    caloriesText: $calories
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                Button(action: performWithdrawal) {
                    HStack {
                        Image(systemName: "fork.knife")
                        Text("Log Consumption")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .disabled(calories.isEmpty || foodName.isEmpty)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .alert("Invalid Entry", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text("Please enter a valid amount.")
            }
            .sheet(isPresented: $showingManageItems) {
                ManageCommonItemsView()
            }
        }
    }
    
    private func performWithdrawal() {
        guard let amount = Int(calories), amount > 0 else {
            showError = true
            return
        }
        
        viewModel.addCalorieBankWithdrawal(foodName: foodName, calories: amount)
        isPresented = false
    }
}

struct PastDaySummaryCard: View {
    @ObservedObject var viewModel: DietDayEditViewModel
    
    var body: some View {
        EcksteinDailySummaryCard(viewModel: viewModel.dietViewModel)
    }
}

extension DateFormatter {
    static let mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

extension Calendar {
    func weekRange(for date: Date) -> Range<Date>? {
        let startOfDay = startOfDay(for: date)
        let weekday = component(.weekday, from: startOfDay)
        let daysToSubtract = weekday - 1 // Sunday is 1
        
        guard let weekStart = self.date(byAdding: .day, value: -daysToSubtract, to: startOfDay),
              let weekEnd = self.date(byAdding: .day, value: 6, to: weekStart) else {
            return nil
        }
        
        return weekStart..<weekEnd
    }
}

@MainActor
class DietDayEditViewModel: ObservableObject {
    let date: Date
    @Published var dietViewModel: EcksteinDietViewModel
    @Published var dayBankTransactions: [CalorieBankTransaction] = []
    @Published var totalBankCaloriesUsed: Int = 0
    
    private let context = PersistenceController.shared.container.viewContext
    private let calendar = Calendar.current
    private var cancellables = Set<AnyCancellable>()
    
    init(date: Date) {
        self.date = date
        self.dietViewModel = EcksteinDietViewModel()
        
        // Forward updates from dietViewModel to this view model
        dietViewModel.objectWillChange
            .sink { [weak self] _ in
                self?.updateCompletionStatus()
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    var isToday: Bool {
        calendar.isDateInToday(date)
    }
    
    @Published var meal1Complete: Bool = false
    @Published var meal2Complete: Bool = false
    @Published var snacksComplete: Bool = false
    
    private func updateCompletionStatus() {
        meal1Complete = dietViewModel.meal1Complete
        meal2Complete = dietViewModel.meal2Complete
        snacksComplete = dietViewModel.snacksComplete
    }
    
    func loadDataForDate() {
        print("DietDayEditViewModel: Loading data for date: \(date)")
        // Override the diet view model to load specific date
        dietViewModel.loadMealsForDate(date)
        
        // Check if this date is a carb load day
        if CarbLoadManager.shared.isCarbLoadDay(date: date) {
            dietViewModel.isCarbLoadDay = true
            // Check if any meals for this date have carb load foods
            checkCarbLoadMealConfiguration()
        } else {
            dietViewModel.isCarbLoadDay = false
            dietViewModel.carbLoadMealNumber = nil
            dietViewModel.combineMealsForCarbLoad = false
        }
        
        loadCalorieBankTransactions()
        updateCompletionStatus()
    }
    
    private func checkCarbLoadMealConfiguration() {
        // Check if meal 1 or meal 2 has carb load foods
        if let meal1 = dietViewModel.todayMeal1 {
            for entry in meal1.carbFoods {
                if entry.food.category == .carbLoad {
                    dietViewModel.carbLoadMealNumber = 1
                    return
                }
            }
        }
        
        if let meal2 = dietViewModel.todayMeal2 {
            for entry in meal2.carbFoods {
                if entry.food.category == .carbLoad {
                    dietViewModel.carbLoadMealNumber = 2
                    return
                }
            }
        }
        
        // Default to meal 2 if no carb load foods found yet
        dietViewModel.carbLoadMealNumber = 2
    }
    
    func toggleCarbLoadDay() {
        if dietViewModel.isCarbLoadDay {
            // Remove carb load day
            CarbLoadManager.shared.removeCarbLoadDay(date: date)
            dietViewModel.isCarbLoadDay = false
            dietViewModel.carbLoadMealNumber = nil
            dietViewModel.combineMealsForCarbLoad = false
            
            // Update meal to remove carb load flag
            if let meal2 = dietViewModel.todayMeal2 {
                dietViewModel.updateMealCarbLoadStatus(mealNumber: 2, isCarbLoad: false)
            }
        } else {
            // Set carb load day
            guard CarbLoadManager.shared.canUseCarbLoadForWeek(of: date) else { return }
            CarbLoadManager.shared.setCarbLoadDay(date: date)
            dietViewModel.isCarbLoadDay = true
            dietViewModel.carbLoadMealNumber = 2 // Default to meal 2
            
            // Update meal to add carb load flag
            dietViewModel.updateMealCarbLoadStatus(mealNumber: 2, isCarbLoad: true)
        }
        
        // Reload meals to reflect changes
        dietViewModel.loadMealsForDate(date)
    }
    
    func toggleMealCombination() {
        dietViewModel.toggleMealCombination()
    }
    
    private func loadCalorieBankTransactions() {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let request: NSFetchRequest<CDCalorieBank> = CDCalorieBank.fetchRequest()
        request.predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDCalorieBank.date, ascending: true)]
        
        do {
            let transactions = try context.fetch(request)
            dayBankTransactions = transactions.map { transaction in
                CalorieBankTransaction(
                    id: transaction.id ?? UUID(),
                    date: transaction.date ?? Date(),
                    amount: abs(Int(transaction.caloriesSaved)),
                    type: transaction.caloriesSaved > 0 ? .deposit : .withdrawal,
                    balance: 0,
                    foodName: transaction.foodName
                )
            }.filter { $0.type == .withdrawal } // Only show withdrawals for editing
            
            totalBankCaloriesUsed = dayBankTransactions.reduce(0) { $0 + $1.amount }
        } catch {
            print("Error loading calorie bank transactions: \(error)")
        }
    }
    
    func addCalorieBankWithdrawal(foodName: String, calories: Int) {
        let transaction = CDCalorieBank(context: context)
        transaction.id = UUID()
        transaction.date = date // Use the selected date, not today
        transaction.caloriesSaved = -Int32(calories)
        transaction.foodName = foodName
        transaction.syncStatus = "pending"
        
        do {
            try context.save()
            loadCalorieBankTransactions()
            
            // Reload the global calorie bank balance
            CalorieBankManager.shared.loadCurrentBalance()
        } catch {
            print("Error saving historical calorie withdrawal: \(error)")
        }
    }
    
    func deleteCalorieBankTransaction(_ transaction: CalorieBankTransaction) {
        let request: NSFetchRequest<CDCalorieBank> = CDCalorieBank.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", transaction.id as CVarArg)
        
        do {
            let results = try context.fetch(request)
            if let toDelete = results.first {
                context.delete(toDelete)
                try context.save()
                loadCalorieBankTransactions()
                
                // Reload the global calorie bank balance
                CalorieBankManager.shared.loadCurrentBalance()
            }
        } catch {
            print("Error deleting calorie bank transaction: \(error)")
        }
    }
}

// Wrapper for historical food picker
struct HistoricalFoodPickerView: View {
    let category: DietRule.DietCategory
    let mealNumber: Int
    let date: Date
    @ObservedObject var viewModel: EcksteinDietViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        FoodPickerView(
            category: category,
            mealNumber: mealNumber,
            viewModel: viewModel,
            isPresented: $isPresented,
            historicalDate: date
        )
    }
}

// Extension to EcksteinDietViewModel to support date-specific loading
extension EcksteinDietViewModel {
    func loadMealsForDate(_ date: Date) {
        let calendar = Calendar.current
        let localDate = calendar.startOfDay(for: date)
        
        print("EcksteinDietViewModel: loadMealsForDate called with date: \(date)")
        print("  Calendar timezone: \(calendar.timeZone)")
        print("  Local date (startOfDay): \(localDate)")
        
        // Create a date range that covers the full day in the user's local timezone
        var components = calendar.dateComponents([.year, .month, .day], from: localDate)
        components.hour = 0
        components.minute = 0
        components.second = 0
        
        guard let startOfDay = calendar.date(from: components) else { return }
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }
        
        print("  Date range: \(startOfDay) to \(endOfDay)")
        
        // Clear current data
        todayMeal1 = nil
        todayMeal2 = nil
        todaySnacks = []
        
        let request: NSFetchRequest<CDEcksteinMeal> = CDEcksteinMeal.fetchRequest()
        
        // Fetch all meals and filter by local date
        let allMealsRequest: NSFetchRequest<CDEcksteinMeal> = CDEcksteinMeal.fetchRequest()
        allMealsRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CDEcksteinMeal.mealNumber, ascending: true)]
        allMealsRequest.relationshipKeyPathsForPrefetching = ["entries"]
        
        do {
            let allMeals = try context.fetch(allMealsRequest)
            
            // Debug: Show what we're looking for
            print("  Looking for meals on local date: \(localDate)")
            print("  All meals found:")
            for meal in allMeals {
                if let mealDate = meal.date {
                    let mealLocalDate = calendar.startOfDay(for: mealDate)
                    print("    Meal \(meal.mealNumber) - DB date: \(mealDate), Local date: \(mealLocalDate), Entries: \((meal.entries as? Set<CDEcksteinMealEntry>)?.count ?? 0)")
                }
            }
            
            // Filter meals by comparing their date in local timezone
            let meals = allMeals.filter { meal in
                guard let mealDate = meal.date else { return false }
                let mealLocalDate = calendar.startOfDay(for: mealDate)
                return calendar.isDate(mealLocalDate, inSameDayAs: localDate)
            }
            
            print("EcksteinDietViewModel: Filtered to \(meals.count) meals for local date \(localDate)")
            
            // Process only meals with entries
            for meal in meals {
                let entries = (meal.entries as? Set<CDEcksteinMealEntry>) ?? []
                
                // Skip meals without entries
                if entries.isEmpty {
                    continue
                }
                
                print("  Processing meal \(meal.mealNumber) dated \(meal.date ?? Date())")
                print("  Meal has \(entries.count) entries")
                
                var proteinFoods: [DietMealEntry.DietFoodEntry] = []
                var carbFoods: [DietMealEntry.DietFoodEntry] = []
                var snacks: [DietMealEntry.DietFoodEntry] = []
                
                // Group entries by food name
                var foodGroups: [String: [CDEcksteinMealEntry]] = [:]
                for entry in entries {
                    if let foodName = entry.foodName {
                        foodGroups[foodName, default: []].append(entry)
                        print("    Entry: \(foodName) - \(entry.gramsConsumed)g, category: \(entry.category ?? "unknown")")
                    }
                }
                
                for (foodName, groupedEntries) in foodGroups {
                    guard let firstEntry = groupedEntries.first,
                          let category = firstEntry.category,
                          let categoryEnum = DietRule.DietCategory(rawValue: category) else { continue }
                    
                    let totalGrams = groupedEntries.reduce(0) { $0 + Int($1.gramsConsumed) }
                    let food = findFoodRule(name: foodName, category: categoryEnum)
                    let foodEntry = DietMealEntry.DietFoodEntry(food: food, gramsConsumed: totalGrams)
                    
                    switch categoryEnum {
                    case .proteinFat, .proteinNonFat:
                        proteinFoods.append(foodEntry)
                    case .carbs, .carbLoad:
                        carbFoods.append(foodEntry)
                    case .snack:
                        snacks.append(foodEntry)
                    }
                }
                
                let mealEntry = DietMealEntry(
                    id: meal.id ?? UUID(),
                    date: meal.date ?? Date(),
                    mealNumber: Int(meal.mealNumber),
                    proteinFoods: proteinFoods,
                    carbFoods: carbFoods,
                    snacks: snacks
                )
                
                if meal.mealNumber == 1 {
                    todayMeal1 = mealEntry
                } else if meal.mealNumber == 2 {
                    todayMeal2 = mealEntry
                }
                
                todaySnacks.append(contentsOf: snacks)
            }
            
            // Force UI update after loading historical data
            objectWillChange.send()
        } catch {
            print("Error loading meals for date: \(error)")
        }
    }
    
    // Override save methods to use specific date
    func saveFoodEntryForDate(date: Date, mealNumber: Int, food: DietRule, gramsConsumed: Int) {
        let calendar = Calendar.current
        let localDate = calendar.startOfDay(for: date)
        
        // Find or create meal
        let request: NSFetchRequest<CDEcksteinMeal> = CDEcksteinMeal.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@ AND mealNumber == %d", 
                                       localDate as NSDate, 
                                       calendar.date(byAdding: .day, value: 1, to: localDate)! as NSDate,
                                       mealNumber)
        
        do {
            let meals = try context.fetch(request)
            let meal: CDEcksteinMeal
            
            if let existingMeal = meals.first {
                meal = existingMeal
            } else {
                meal = CDEcksteinMeal(context: context)
                meal.id = UUID()
                meal.date = localDate
                meal.mealNumber = Int32(mealNumber)
                meal.user = getCurrentUser()
            }
            
            // Check if entry for this food already exists
            let existingEntries = (meal.entries as? Set<CDEcksteinMealEntry>) ?? []
            if let existingEntry = existingEntries.first(where: { 
                $0.foodName == food.foodName && $0.category == food.category.rawValue 
            }) {
                // Update existing entry by adding to current amount
                existingEntry.gramsConsumed += Int32(gramsConsumed)
            } else {
                // Create new entry
                let entry = CDEcksteinMealEntry(context: context)
                entry.id = UUID()
                entry.foodName = food.foodName
                entry.category = food.category.rawValue
                entry.gramsConsumed = Int32(gramsConsumed)
                entry.meal = meal
            }
            
            try context.save()
            
            // Reload data after saving
            loadMealsForDate(date)
        } catch {
            print("Error saving meal entry for date: \(error)")
        }
    }
}