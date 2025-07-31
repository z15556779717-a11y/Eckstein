//
//  DietCalendarView.swift
//  Eckstein
//
//  Created by Assistant on 16/01/2025.
//

import SwiftUI
import CoreData

struct DietCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = DietCalendarViewModel()
    @State private var selectedDate = Date()
    @State private var showingDayEdit = false
    @State private var refreshTrigger = false
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // Month header
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(themeManager.accentColor.color)
                }
                
                Spacer()
                
                Text(dateFormatter.string(from: selectedDate))
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(themeManager.accentColor.color)
                }
                .disabled(calendar.isDate(selectedDate, equalTo: Date(), toGranularity: .month))
            }
            .padding()
            
            // Day labels
            HStack {
                ForEach(Array(["sun_short".localized, "mon_short".localized, "tue_short".localized, "wed_short".localized, "thu_short".localized, "fri_short".localized, "sat_short".localized].enumerated()), id: \.offset) { index, day in
                    Text(String(day.prefix(1)))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            // Calendar grid
            CalendarGridView(
                selectedDate: $selectedDate,
                dataStatus: viewModel.dataStatus,
                onDateSelected: { date in
                    // Use the start of day in local timezone for consistency
                    let calendar = Calendar.current
                    selectedDate = calendar.startOfDay(for: date)
                    print("DietCalendarView: Date selected: \(date)")
                    print("  Start of day: \(selectedDate)")
                    showingDayEdit = true
                }
            )
            .padding()
            
            // Legend
            VStack(alignment: .leading, spacing: 8) {
                Text("legend".localized)
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 20) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("complete".localized)
                                .font(.caption)
                        }
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 8, height: 8)
                            Text("partial".localized)
                                .font(.caption)
                        }
                    }
                    
                    HStack(spacing: 20) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 8, height: 8)
                            Text("carb_load".localized)
                                .font(.caption)
                        }
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                            Text("no_data".localized)
                                .font(.caption)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            
            Spacer()
        }
        .navigationTitle("diet_history".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("done".localized) {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingDayEdit) {
            NavigationView {
                DietDayEditView(date: selectedDate)
            }
            .onDisappear {
                // Reload data status when returning from edit view
                viewModel.loadDataStatus()
            }
        }
        .onAppear {
            viewModel.loadDataStatus()
        }
        .onChange(of: showingDayEdit) { newValue in
            if !newValue {
                // Sheet was dismissed, refresh data
                viewModel.loadDataStatus()
            }
        }
    }
    
    private func previousMonth() {
        if let newDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) {
            selectedDate = newDate
            viewModel.loadDataStatus(for: selectedDate)
        }
    }
    
    private func nextMonth() {
        if let newDate = calendar.date(byAdding: .month, value: 1, to: selectedDate),
           !calendar.isDate(newDate, equalTo: Date(), toGranularity: .month) ||
           calendar.compare(newDate, to: Date(), toGranularity: .day) != .orderedDescending {
            selectedDate = newDate
            viewModel.loadDataStatus(for: selectedDate)
        }
    }
}

struct CalendarGridView: View {
    @Binding var selectedDate: Date
    let dataStatus: [Date: DietDataStatus]
    let onDateSelected: (Date) -> Void
    
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(calendarDays().enumerated()), id: \.offset) { index, date in
                if let date = date {
                    CalendarDayView(
                        date: date,
                        isToday: calendar.isDateInToday(date),
                        status: dataStatus[calendar.startOfDay(for: date)] ?? DietDataStatus.none,
                        onTap: {
                            if calendar.compare(date, to: Date(), toGranularity: .day) != .orderedDescending {
                                onDateSelected(date)
                            }
                        }
                    )
                    .disabled(calendar.compare(date, to: Date(), toGranularity: .day) == .orderedDescending)
                } else {
                    Color.clear
                        .frame(height: 40)
                }
            }
        }
    }
    
    private func calendarDays() -> [Date?] {
        guard let monthRange = calendar.range(of: .day, in: .month, for: selectedDate),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate)) else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) - 1
        let numberOfDays = monthRange.count
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        
        for day in 1...numberOfDays {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }
        
        // Fill remaining days to complete the grid
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
}

struct CalendarDayView: View {
    let date: Date
    let isToday: Bool
    let status: DietDataStatus
    let onTap: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isToday ? Color.accentColor.opacity(0.2) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isToday ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                
                VStack(spacing: 4) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 16, weight: isToday ? .bold : .regular))
                        .foregroundColor(calendar.compare(date, to: Date(), toGranularity: .day) == .orderedDescending ? .gray : .primary)
                    
                    Circle()
                        .fill(status.color)
                        .frame(width: 8, height: 8)
                }
            }
            .frame(height: 40)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

enum DietDataStatus {
    case none
    case partial
    case complete
    case carbLoad
    
    var color: Color {
        switch self {
        case .none:
            return Color.gray.opacity(0.3)
        case .partial:
            return Color.orange
        case .complete:
            return Color.green
        case .carbLoad:
            return Color.blue
        }
    }
}

class DietCalendarViewModel: ObservableObject {
    @Published var dataStatus: [Date: DietDataStatus] = [:]
    
    private let context = PersistenceController.shared.container.viewContext
    private let calendar = Calendar.current
    
    func loadDataStatus(for selectedDate: Date? = nil) {
        // Refresh the context to ensure we have the latest data
        context.refreshAllObjects()
        
        dataStatus.removeAll()
        
        // Get date range for the current view
        let referenceDate = selectedDate ?? Date()
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate)),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else { return }
        
        // Extend range to cover adjacent months for smooth scrolling
        guard let startDate = calendar.date(byAdding: .month, value: -1, to: monthStart),
              let endDate = calendar.date(byAdding: .month, value: 1, to: monthEnd) else { return }
        
        // Fetch all meals in date range
        let request: NSFetchRequest<CDEcksteinMeal> = CDEcksteinMeal.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", startDate as NSDate, endDate as NSDate)
        request.relationshipKeyPathsForPrefetching = ["entries"]
        request.includesPendingChanges = false // Ensure we get saved data only
        
        do {
            let meals = try context.fetch(request)
            print("DietCalendarViewModel: Found \(meals.count) meals in date range")
            
            // Group meals by day
            let mealsByDay = Dictionary(grouping: meals) { meal -> Date in
                calendar.startOfDay(for: meal.date ?? Date())
            }
            
            // Check each day's completeness
            for (date, dayMeals) in mealsByDay {
                print("DietCalendarViewModel: Checking date \(date) with \(dayMeals.count) meals")
                
                var meal1Percentages: (protein: Double, carbs: Double) = (0, 0)
                var meal2Percentages: (protein: Double, carbs: Double) = (0, 0)
                var hasMeal1 = false
                var hasMeal2 = false
                
                for meal in dayMeals {
                    let mealHasContent = hasContent(meal)
                    print("  Meal \(meal.mealNumber): hasContent=\(mealHasContent), entries=\((meal.entries as? Set<CDEcksteinMealEntry>)?.count ?? 0)")
                    
                    if mealHasContent {
                        let percentages = calculateMealPercentages(meal)
                        if meal.mealNumber == 1 {
                            hasMeal1 = true
                            meal1Percentages = percentages
                            print("  Meal 1: protein=\(percentages.protein)%, carbs=\(percentages.carbs)%")
                        } else if meal.mealNumber == 2 {
                            hasMeal2 = true
                            meal2Percentages = percentages
                            print("  Meal 2: protein=\(percentages.protein)%, carbs=\(percentages.carbs)%")
                        }
                    }
                }
                
                // Check if day is complete:
                // 1. Both meals have content (both meal 1 and meal 2 filled), OR
                // 2. Single meal has 200% total (protein + carbs combined)
                let totalProtein = meal1Percentages.protein + meal2Percentages.protein
                let totalCarbs = meal1Percentages.carbs + meal2Percentages.carbs
                
                // Calculate total percentage for each meal (protein + carbs)
                let meal1Total = meal1Percentages.protein + meal1Percentages.carbs
                let meal2Total = meal2Percentages.protein + meal2Percentages.carbs
                
                // Day is complete if:
                // - Both meals have content (regardless of percentage), OR
                // - Either meal has 200% total (protein + carbs combined)
                let bothMealsHaveContent = hasMeal1 && hasMeal2
                let anyMealHas200Percent = meal1Total >= 200 || meal2Total >= 200
                
                let isDayComplete = bothMealsHaveContent || anyMealHas200Percent
                
                print("  Decision: meal1Total=\(meal1Total)%, meal2Total=\(meal2Total)%, bothMealsHaveContent=\(bothMealsHaveContent), anyMealHas200Percent=\(anyMealHas200Percent), isDayComplete=\(isDayComplete)")
                print("  hasMeal1=\(hasMeal1), hasMeal2=\(hasMeal2)")
                
                // Check if this is a carb load day
                let isCarbLoadDay = CarbLoadManager.shared.isCarbLoadDay(date: date)
                
                if isCarbLoadDay {
                    dataStatus[date] = .carbLoad
                } else if isDayComplete {
                    dataStatus[date] = .complete
                } else if hasMeal1 || hasMeal2 {
                    dataStatus[date] = .partial
                } else {
                    dataStatus[date] = DietDataStatus.none
                }
                print("  Final Status for \(date): \(dataStatus[date]!)")
            }
            
            // For dates not in mealsByDay, they have no data
            // This ensures days with all meals deleted show as "No Data"
        } catch {
            print("Error loading diet data status: \(error)")
        }
    }
    
    private func hasContent(_ meal: CDEcksteinMeal) -> Bool {
        guard let entries = meal.entries as? Set<CDEcksteinMealEntry> else { return false }
        return !entries.isEmpty
    }
    
    private func calculateMealPercentages(_ meal: CDEcksteinMeal) -> (protein: Double, carbs: Double) {
        guard let entries = meal.entries as? Set<CDEcksteinMealEntry> else {
            return (0, 0)
        }
        
        // Use same hardcoded values as EcksteinDietViewModel
        // TODO: These should be stored in user preferences
        let proteinTarget = 320 // Default to non-fat protein target
        let carbTarget = 250 // Default to rice
        
        var proteinPercentage: Double = 0
        var carbsPercentage: Double = 0
        
        print("    Calculating percentages for meal \(meal.mealNumber) with \(entries.count) entries")
        
        for entry in entries {
            guard let category = entry.category,
                  let categoryEnum = DietRule.DietCategory(rawValue: category) else { 
                print("    Skipping entry with invalid category: \(entry.category ?? "nil")")
                continue 
            }
            
            let gramsConsumed = Int(entry.gramsConsumed)
            print("    Entry: \(entry.foodName ?? "unknown") - \(gramsConsumed)g, category: \(category)")
            
            switch categoryEnum {
            case .proteinFat, .proteinNonFat:
                // Calculate percentage based on protein target
                let contribution = (Double(gramsConsumed) / Double(proteinTarget)) * 100
                proteinPercentage += contribution
                print("    Protein contribution: \(contribution)% (total now: \(proteinPercentage)%)")
            case .carbs:
                // Calculate percentage based on carb target
                let contribution = (Double(gramsConsumed) / Double(carbTarget)) * 100
                carbsPercentage += contribution
                print("    Carb contribution: \(contribution)% (total now: \(carbsPercentage)%)")
            case .snack:
                // Snacks don't count towards meal percentages
                print("    Snack - not counted")
                break
            case .carbLoad:
                // Carb load counts as 100% completion for both protein and carbs
                print("    Carb load - counts as full meal")
                // Each carb load item contributes 100% to indicate meal is complete
                proteinPercentage = 100
                carbsPercentage = 100
            }
        }
        
        print("    Final percentages - protein: \(proteinPercentage)%, carbs: \(carbsPercentage)%")
        return (proteinPercentage, carbsPercentage)
    }
}