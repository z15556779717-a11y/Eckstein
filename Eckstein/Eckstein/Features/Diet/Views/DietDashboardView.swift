//
//  DietDashboardView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

/// **Unreachable in phase 2 — root of the frozen legacy diet suite.**
///
/// This view has no external caller, which means every view it presents
/// (`FoodSearchView`, `AddFoodView`, `FoodDetailView`, `MealDetailView`,
/// `MealHistoryView`, `QuickAddView`, `BarcodeScannerContainerView`,
/// `DailyGoalsView`, `MacroBreakdownView`, `WeeklyAnalyticsView`) is unreachable
/// too, along with `DietViewModel` and `FoodSearchViewModel`. They read and write
/// the orphaned `CDFood` / `CDMeal` set. The live Diet tab is
/// `DietTabView → EcksteinDietView`. Nothing here is deleted in phase 2.
/// See NUTRITION_MIGRATION_PLAN.md §1 and §11.
struct DietDashboardView: View {
    @ObservedObject var viewModel: DietViewModel
    @State private var showFoodSearch = false
    @State private var showBarcodeScanner = false
    @State private var showCalorieBank = false
    @State private var showAnalytics = false
    @State private var selectedMealType: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Quick Actions
                QuickActionsRow(
                    showFoodSearch: $showFoodSearch,
                    showBarcodeScanner: $showBarcodeScanner,
                    showCalorieBank: $showCalorieBank,
                    showAnalytics: $showAnalytics
                )
                
                // Daily Progress Card
                DailyProgressCard(viewModel: viewModel)
                
                // Calorie Bank Summary
                CalorieBankSummaryCard(
                    balance: viewModel.calorieBankBalance,
                    todayDeposit: viewModel.todayDeposit,
                    onTap: { showCalorieBank = true }
                )
                
                // Today's Meals
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("todays_meals".localized)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        NavigationLink(destination: MealHistoryView(viewModel: viewModel)) {
                            Text("history".localized)
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if viewModel.todayMeals.isEmpty {
                        EmptyMealsCard(onAddMeal: {
                            selectedMealType = DietDashboardMealType.breakfast.rawValue
                            showFoodSearch = true
                        })
                    } else {
                        ForEach(viewModel.todayMeals) { meal in
                            MealCard(
                                meal: meal,
                                viewModel: viewModel,
                                onAddFood: {
                                    selectedMealType = meal.mealType
                                    showFoodSearch = true
                                }
                            )
                        }
                    }
                    
                    // Add Meal Button
                    AddMealButton(
                        viewModel: viewModel,
                        onMealCreated: { mealType in
                            selectedMealType = mealType
                            showFoodSearch = true
                        }
                    )
                }
                
                // Nutrition Insights
                NutritionInsightsCard(
                    viewModel: viewModel,
                    onViewAnalytics: { showAnalytics = true }
                )
            }
            .padding()
        }
        .navigationTitle("diet_tracker".localized)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showFoodSearch = true }) {
                        Label("add_food".localized, systemImage: "plus.circle")
                    }

                    Button(action: { showBarcodeScanner = true }) {
                        Label("scan_barcode".localized, systemImage: "barcode.viewfinder")
                    }

                    Button(action: { showCalorieBank = true }) {
                        Label("calorie_bank".localized, systemImage: "building.columns")
                    }

                    Button(action: { showAnalytics = true }) {
                        Label("analytics".localized, systemImage: "chart.line.uptrend.xyaxis")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showFoodSearch) {
            FoodSearchView { food in
                viewModel.addFoodToMeal(food, mealType: selectedMealType)
            }
        }
        .sheet(isPresented: $showBarcodeScanner) {
            BarcodeScannerContainerView(
                viewModel: viewModel,
                selectedMealType: selectedMealType
            )
        }
        .sheet(isPresented: $showCalorieBank) {
            NavigationView {
                CalorieBankView()
            }
        }
        .sheet(isPresented: $showAnalytics) {
            NavigationView {
                AnalyticsTabView(viewModel: viewModel)
            }
        }
        .onAppear {
            viewModel.refreshData()
        }
    }
}

struct QuickActionsRow: View {
    @Binding var showFoodSearch: Bool
    @Binding var showBarcodeScanner: Bool
    @Binding var showCalorieBank: Bool
    @Binding var showAnalytics: Bool
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                DietQuickActionButton(
                    icon: "magnifyingglass",
                    title: "Search Food",
                    color: .blue,
                    action: { showFoodSearch = true }
                )
                
                DietQuickActionButton(
                    icon: "barcode.viewfinder",
                    title: "Scan",
                    color: .green,
                    action: { showBarcodeScanner = true }
                )
                
                DietQuickActionButton(
                    icon: "building.columns",
                    title: "Bank",
                    color: .orange,
                    action: { showCalorieBank = true }
                )
                
                DietQuickActionButton(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Analytics",
                    color: .purple,
                    action: { showAnalytics = true }
                )
            }
        }
    }
}

struct DietQuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 50, height: 50)
                    .background(color.opacity(0.1))
                    .cornerRadius(12)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
    }
}

struct DailyProgressCard: View {
    @ObservedObject var viewModel: DietViewModel
    
    private var calorieProgress: Double {
        guard viewModel.dailyCalorieGoal > 0 else { return 0 }
        return min(Double(viewModel.todayCalories) / Double(viewModel.dailyCalorieGoal), 1.5)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("daily_progress".localized)
                        .font(.headline)
                    Text("diet_dashboard_calorie_progress".localized(viewModel.todayCalories, viewModel.dailyCalorieGoal))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                CircularProgressView(
                    progress: calorieProgress,
                    lineWidth: 8,
                    color: calorieProgress > 1 ? .red : .orange
                )
                .frame(width: 60, height: 60)
            }
            
            // Macro Summary
            HStack(spacing: 20) {
                MacroSummaryItem(
                    title: "Protein",
                    value: viewModel.todayProtein,
                    goal: Double(viewModel.dailyProteinGoal),
                    unit: "g",
                    color: .red
                )
                
                MacroSummaryItem(
                    title: "Carbs",
                    value: viewModel.todayCarbs,
                    goal: Double(viewModel.dailyCarbsGoal),
                    unit: "g",
                    color: .blue
                )
                
                MacroSummaryItem(
                    title: "Fat",
                    value: viewModel.todayFat,
                    goal: Double(viewModel.dailyFatGoal),
                    unit: "g",
                    color: .green
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct MacroSummaryItem: View {
    let title: String
    let value: Double
    let goal: Double
    let unit: String
    let color: Color
    
    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(value / goal, 1.0)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 4)
                    .frame(width: 40, height: 40)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
            }
            
            Text("\(Int(value))\(unit)")
                .font(.caption2)
                .fontWeight(.medium)
        }
    }
}

struct CalorieBankSummaryCard: View {
    let balance: Int
    let todayDeposit: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label("calorie_bank".localized, systemImage: "building.columns.fill")
                        .font(.headline)
                        .foregroundColor(.orange)

                    Text("diet_dashboard_balance_line".localized(balance))
                        .font(.subheadline)

                    if todayDeposit > 0 {
                        Text("diet_dashboard_deposit".localized(todayDeposit))
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EmptyMealsCard: View {
    let onAddMeal: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("no_meals_logged_today".localized)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Button("diet_dashboard_add_first_meal".localized) {
                onAddMeal()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct MealCard: View {
    let meal: CDMeal
    @ObservedObject var viewModel: DietViewModel
    let onAddFood: () -> Void
    
    private var mealNutrition: NutritionInfo {
        viewModel.getNutritionForMeal(meal)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(meal.mealType?.capitalized ?? "diet_entry_meal".localized)
                        .font(.headline)
                    
                    if let date = meal.date {
                        Text(date, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text("\(mealNutrition.calories) cal")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            
            // Food Items
            if let items = meal.items as? Set<CDMealItem>, !items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(items)) { item in
                        DashboardMealItemRow(item: item, viewModel: viewModel)
                    }
                }
                
                Divider()
                
                // Macro Summary
                HStack {
                    MacroLabel(value: mealNutrition.protein, unit: "g", label: "Protein", color: .red)
                    MacroLabel(value: mealNutrition.carbs, unit: "g", label: "Carbs", color: .blue)
                    MacroLabel(value: mealNutrition.fat, unit: "g", label: "Fat", color: .green)
                }
                .font(.caption)
            }
            
            Button(action: onAddFood) {
                Label("add_food".localized, systemImage: "plus.circle")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct DashboardMealItemRow: View {
    let item: CDMealItem
    @ObservedObject var viewModel: DietViewModel
    
    private var nutrition: NutritionInfo {
        guard let food = item.food else {
            return NutritionInfo(calories: 0, protein: 0, carbs: 0, fat: 0, fiber: 0)
        }
        return ServingSizeCalculator.calculateNutrition(for: food, servingGrams: item.quantityGrams)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.food?.name ?? "diet_unknown_food_title".localized)
                    .font(.subheadline)
                
                Text("\(Int(item.quantityGrams))g")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(nutrition.calories) cal")
                .font(.subheadline)
                .foregroundColor(.orange)
            
            Button(action: { viewModel.removeMealItem(item) }) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
                    .font(.body)
            }
        }
    }
}

struct MacroLabel: View {
    let value: Double
    let unit: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(Int(value))\(unit) \(label)")
                .foregroundColor(.secondary)
        }
    }
}

struct AddMealButton: View {
    @ObservedObject var viewModel: DietViewModel
    let onMealCreated: (String) -> Void
    @State private var showMealPicker = false
    
    var body: some View {
        Button(action: { showMealPicker = true }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("add_meal".localized)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(12)
        }
        .actionSheet(isPresented: $showMealPicker) {
            ActionSheet(
                title: Text("select_meal_type".localized),
                buttons: MealType.allCases.map { mealType in
                    .default(Text(mealType.displayName)) {
                        _ = viewModel.createMeal(type: mealType.rawValue)
                        onMealCreated(mealType.rawValue)
                    }
                } + [.cancel()]
            )
        }
    }
}

struct NutritionInsightsCard: View {
    @ObservedObject var viewModel: DietViewModel
    let onViewAnalytics: () -> Void
    
    private var insight: String {
        if viewModel.todayCalories == 0 {
            return "Start logging your meals to see insights"
        } else if viewModel.todayProtein < Double(viewModel.dailyProteinGoal) * 0.5 {
            return "Your protein intake is low. Consider adding lean meats, fish, or legumes."
        } else if viewModel.todayCalories > viewModel.dailyCalorieGoal {
            return "You've exceeded your calorie goal. Consider lighter options for your next meal."
        } else {
            return "Great job staying on track! Keep it up!"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("diet_dashboard_nutrition_insights".localized, systemImage: "lightbulb.fill")
                    .font(.headline)
                    .foregroundColor(.yellow)

                Spacer()

                Button("view_all".localized) {
                    onViewAnalytics()
                }
                .font(.caption)
            }
            
            Text(insight)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CircularProgressView: View {
    let progress: Double
    let lineWidth: CGFloat
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: progress)
            
            Text("\(Int(progress * 100))%")
                .font(.caption)
                .fontWeight(.bold)
        }
    }
}

struct AnalyticsTabView: View {
    @ObservedObject var viewModel: DietViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        VStack {
            Picker("analytics".localized, selection: $selectedTab) {
                Text("diet_dashboard_goals".localized).tag(0)
                Text("weekly".localized).tag(1)
                Text("diet_dashboard_macros".localized).tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            TabView(selection: $selectedTab) {
                DailyGoalsView(viewModel: viewModel)
                    .tag(0)
                
                WeeklyAnalyticsView(viewModel: viewModel)
                    .tag(1)
                
                MacroBreakdownView(viewModel: viewModel)
                    .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .navigationTitle("analytics".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Meal slots for this legacy dashboard's segmented control.
///
/// Renamed from `MealType` in phase 2: the official nutrition vocabulary now
/// owns that name (`Core/Nutrition/MealType.swift`). This view is unreachable
/// from the live app — see NUTRITION_MIGRATION_PLAN.md §1.3 — and is kept only
/// so the frozen `CDFood`/`CDMeal` path still compiles.
enum DietDashboardMealType: String, CaseIterable {
    case breakfast, lunch, dinner, snack

    var displayName: String {
        rawValue.capitalized
    }
}