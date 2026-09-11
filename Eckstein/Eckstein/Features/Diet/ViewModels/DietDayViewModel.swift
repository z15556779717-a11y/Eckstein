//
//  DietDayViewModel.swift
//  Eckstein
//
//  One day of the food log: the entries, the totals they add up to, and the
//  four write actions the Diet screen offers.
//
//  Every number here comes out of `NutritionService` — the entries it fetches,
//  the summary it aggregates. Nothing in the view sums anything, which is the
//  point: a second sum in a SwiftUI body is a second answer to "how many
//  calories today", and the two only agree until one of them is edited.
//
//  Only `CDEckstein*` entities are touched. `CDFood` / `CDMeal` / `CDMealItem`
//  are the deprecated compatibility layer and are deliberately absent.
//

import Foundation
import Combine

@MainActor
final class DietDayViewModel: ObservableObject {

    /// The day on screen. Always a real date, never a "day offset".
    @Published private(set) var date: Date

    /// The day's entries, grouped by slot.
    ///
    /// `CDEcksteinMealEntry` is a managed object, so a row can be edited and
    /// deleted without a second lookup. Nothing here mutates one directly: every
    /// write goes back through `NutritionService`, which is what recomputes the
    /// meal's cached totals.
    @Published private(set) var entriesBySlot: [MealType: [CDEcksteinMealEntry]] = [:]

    @Published private(set) var summary: DailyNutritionSummary

    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    private let nutrition: NutritionService
    private let calendar: Calendar
    private let now: () -> Date

    init(
        date: Date = Date(),
        nutrition: NutritionService = .shared,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.date = calendar.startOfDay(for: date)
        self.nutrition = nutrition
        self.calendar = calendar
        self.now = now
        // Seeded rather than left `nil` so the first render shows a real zero
        // against the real targets instead of an empty card.
        self.summary = DailyNutritionSummary.empty(on: date)
    }

    // MARK: - Loading

    func load() {
        // The spinner only on the first load: a refresh after logging a food
        // would otherwise flash the whole day away and back.
        if entriesBySlot.isEmpty { isLoading = true }
        errorMessage = nil

        do {
            let entries = try nutrition.entries(on: date, calendar: calendar)
            entriesBySlot = Dictionary(grouping: entries) { entry in
                MealType(storedValue: entry.meal?.mealType)
            }
            summary = try nutrition.dailySummary(for: date, calendar: calendar)
        } catch {
            // Both the entries and the summary failed, so the day is not partly
            // shown: an error here means the store could not be read at all.
            entriesBySlot = [:]
            summary = .empty(on: date)
            errorMessage = "error_loading_data".localized
        }

        isLoading = false
    }

    // MARK: - Moving between days

    var isToday: Bool {
        calendar.isDate(date, inSameDayAs: now())
    }

    var canGoToNextDay: Bool {
        calendar.startOfDay(for: date) < calendar.startOfDay(for: now())
    }

    /// The day as the screen's title: "今天" for today, otherwise the date.
    var titleText: String {
        if isToday { return "today".localized }
        return Self.dateFormatter(for: calendar).string(from: date)
    }

    func selectPreviousDay() {
        move(by: -1)
    }

    func selectNextDay() {
        guard canGoToNextDay else { return }
        move(by: 1)
    }

    func selectToday() {
        guard !isToday else { return }
        date = calendar.startOfDay(for: now())
        load()
    }

    private func move(by days: Int) {
        guard let moved = calendar.date(byAdding: .day, value: days, to: date) else { return }
        date = calendar.startOfDay(for: moved)
        load()
    }

    // MARK: - Reading the day

    func entries(for slot: MealType) -> [CDEcksteinMealEntry] {
        entriesBySlot[slot] ?? []
    }

    /// The day's totals against the day's goals, for the summary card.
    var progress: NutritionGoalProgress {
        NutritionGoalProgress(summary: summary)
    }

    /// The slot totals as the aggregator computed them, so a section header and
    /// the day's card can never disagree about what breakfast came to.
    func totals(for slot: MealType) -> NutritionSnapshot {
        summary.byMealType[slot] ?? .zero
    }

    /// What the amount currently typed in the editor would contribute.
    ///
    /// Resolved by `NutritionService`, not here: the editor must show the number
    /// that would be written, including the diet-rule fallback for a food with no
    /// catalog row. `nil` means the food's values are unknown — which is not the
    /// same as zero, and the editor says so rather than printing zeros.
    func previewSnapshot(
        food: CDEcksteinFood?,
        foodName: String,
        category: String?,
        grams: Double
    ) -> NutritionSnapshot? {
        nutrition.snapshot(for: food, foodName: foodName, category: category, grams: grams)
    }

    /// The per-100 g line for a food, or `nil` when it declares nothing.
    func per100gText(for food: CDEcksteinFood?) -> String? {
        guard let food, let calories = food.caloriesPer100g?.doubleValue,
              let calorieText = NutrientFormat.calories(calories) else { return nil }

        var parts = ["\(calorieText) kcal"]
        let macros: [(String, NSNumber?)] = [
            ("protein", food.proteinPer100g),
            ("carbs", food.carbsPer100g),
            ("fat", food.fatPer100g),
            ("fiber", food.fiberPer100g)
        ]
        for (key, stored) in macros {
            guard let value = stored?.doubleValue,
                  let text = NutrientFormat.grams(value) else { continue }
            parts.append("\(key.localized) \(text) g")
        }

        return "diet_per_100g_line".localized(parts.joined(separator: " · "))
    }

    // MARK: - Writing

    /// Logs `grams` of `food` into `slot` on the day on screen.
    ///
    /// `mealNumber` is the slot's row, so entries filed under different slots
    /// stay in different meals — the slot is stored on the meal, and one meal
    /// cannot be two slots. `.unspecified` passes no slot at all rather than
    /// claiming one.
    func add(food: CDEcksteinFood, grams: Double, to slot: MealType) throws {
        try nutrition.logEntry(
            foodName: food.name ?? "",
            category: food.category,
            grams: grams,
            mealNumber: slot.slotMealNumber,
            mealType: slot.storedValue == nil ? nil : slot,
            date: date,
            food: food,
            calendar: calendar
        )
        try nutrition.markUsed(food)
        load()
    }

    /// Replaces an entry's food, amount and slot, recomputing its nutrition.
    ///
    /// A slot change is a **move**, not a `mealType` edit: the slot belongs to
    /// the meal, so setting it on the entry's current meal would relabel every
    /// other entry filed under it. The entry is copied into the target slot's
    /// meal row and the original deleted, which carries the recorded amount
    /// across unchanged and recomputes nothing from new inputs.
    func save(
        _ entry: CDEcksteinMealEntry,
        food: CDEcksteinFood?,
        grams: Double,
        slot: MealType
    ) throws {
        let resolvedFood = food ?? entry.food

        if let resolvedFood {
            try nutrition.updateEntry(
                entry,
                foodName: resolvedFood.name ?? "",
                category: resolvedFood.category,
                grams: grams,
                food: resolvedFood
            )
            try nutrition.markUsed(resolvedFood)
        } else {
            // No catalog row: a legacy diet-rule entry being re-weighed. The
            // name and category it was logged with are kept, and the snapshot is
            // recomputed from the shipped diet-rule fixture — which is what
            // produced its original values.
            try nutrition.updateGrams(grams, for: entry)
        }

        if MealType(storedValue: entry.meal?.mealType) != slot {
            _ = try nutrition.duplicate(
                entry,
                date: date,
                mealNumber: slot.slotMealNumber,
                mealType: slot.storedValue == nil ? nil : slot,
                calendar: calendar
            )
            try nutrition.delete(entry)
        }

        load()
    }

    /// Deletes an entry and refreshes the day, so the totals drop immediately.
    func delete(_ entry: CDEcksteinMealEntry) throws {
        try nutrition.delete(entry)
        load()
    }

    // MARK: - Formatting

    /// A formatter in the app's current language.
    ///
    /// Built per call rather than cached: the language can change while the app
    /// is running, and a cached formatter would keep printing the old one's
    /// month names.
    static func dateFormatter(for calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = LocalizationManager.shared.currentLocale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
}
