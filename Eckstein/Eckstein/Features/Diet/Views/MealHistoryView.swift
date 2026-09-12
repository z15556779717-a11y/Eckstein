//
//  MealHistoryView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI
import CoreData

struct MealHistoryView: View {
    @ObservedObject var viewModel: DietViewModel
    @State private var selectedDate = Date()
    @State private var showDatePicker = false
    
    private var dateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        return startDate...Date()
    }
    
    private var mealsForSelectedDate: [CDMeal] {
        viewModel.getMealsForDate(selectedDate)
    }
    
    private var nutritionForSelectedDate: NutritionInfo {
        NutritionCalculator.calculateNutritionForMeals(mealsForSelectedDate)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Date Selector
                VStack(spacing: 12) {
                    HStack {
                        Button(action: previousDay) {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                        }
                        
                        Button(action: { showDatePicker = true }) {
                            HStack {
                                Image(systemName: "calendar")
                                Text(selectedDate, format: .dateTime.weekday(.wide).month().day())
                                    .font(.headline)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: nextDay) {
                            Image(systemName: "chevron.right")
                                .font(.title3)
                        }
                        .disabled(Calendar.current.isDateInToday(selectedDate))
                    }
                    
                    if Calendar.current.isDateInToday(selectedDate) {
                        Text("today".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Daily Summary
                DailyNutritionSummaryCard(nutrition: nutritionForSelectedDate)
                
                // Meals
                if mealsForSelectedDate.isEmpty {
                    EmptyHistoryCard(date: selectedDate)
                } else {
                    VStack(spacing: 16) {
                        ForEach(mealsForSelectedDate) { meal in
                            HistoryMealCard(meal: meal, viewModel: viewModel)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("meal_history_title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(
                selectedDate: $selectedDate,
                dateRange: dateRange
            )
        }
    }
    
    private func previousDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
    }
    
    private func nextDay() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        if tomorrow <= Date() {
            selectedDate = tomorrow
        }
    }
}

/// Renamed from `DailyNutritionSummary` in phase 2: that name now belongs to the
/// official nutrition aggregation value (`Core/Nutrition/DailyNutritionSummary.swift`).
/// This view is unreachable from the live app — see NUTRITION_MIGRATION_PLAN.md §1.3.
struct DailyNutritionSummaryCard: View {
    let nutrition: NutritionInfo
    
    var body: some View {
        VStack(spacing: 16) {
            Text("\(nutrition.calories) calories")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.orange)
            
            HStack(spacing: 20) {
                NutritionItem(
                    title: "Protein",
                    value: nutrition.protein,
                    unit: "g",
                    color: .red
                )
                
                NutritionItem(
                    title: "Carbs",
                    value: nutrition.carbs,
                    unit: "g",
                    color: .blue
                )
                
                NutritionItem(
                    title: "Fat",
                    value: nutrition.fat,
                    unit: "g",
                    color: .green
                )
                
                NutritionItem(
                    title: "Fiber",
                    value: nutrition.fiber,
                    unit: "g",
                    color: .brown
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct NutritionItem: View {
    let title: String
    let value: Double
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(Int(value))\(unit)")
                .font(.headline)
                .foregroundColor(color)
        }
    }
}

struct EmptyHistoryCard: View {
    let date: Date
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("meal_history_no_meals".localized)
                .font(.headline)
                .foregroundColor(.secondary)

            Text("meal_history_no_meals_message".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct HistoryMealCard: View {
    let meal: CDMeal
    @ObservedObject var viewModel: DietViewModel
    
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
                    ForEach(Array(items).sorted(by: { $0.food?.name ?? "" < $1.food?.name ?? "" })) { item in
                        HStack {
                            Text(item.food?.name ?? "diet_unknown_food_title".localized)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Text("\(Int(item.quantityGrams))g")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Divider()
                
                // Macro Summary
                HStack(spacing: 16) {
                    MacroLabel(value: mealNutrition.protein, unit: "g", label: "P", color: .red)
                    MacroLabel(value: mealNutrition.carbs, unit: "g", label: "C", color: .blue)
                    MacroLabel(value: mealNutrition.fat, unit: "g", label: "F", color: .green)
                }
                .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    let dateRange: ClosedRange<Date>
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            DatePicker(
                "meal_history_select_date".localized,
                selection: $selectedDate,
                in: dateRange,
                displayedComponents: .date
            )
            .datePickerStyle(GraphicalDatePickerStyle())
            .padding()
            .navigationTitle("meal_history_select_date".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Add to DietViewModel
extension DietViewModel {
    func getMealsForDate(_ date: Date) -> [CDMeal] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let request: NSFetchRequest<CDMeal> = CDMeal.fetchRequest()
        request.predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDMeal.date, ascending: true)]
        
        do {
            return try persistenceController.container.viewContext.fetch(request)
        } catch {
            print("Error fetching meals for date: \(error)")
            return []
        }
    }
}