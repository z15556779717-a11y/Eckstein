//
//  NutritionAggregator.swift
//  Eckstein
//
//  Pure daily-nutrition aggregation. No SwiftUI, no Core Data, no I/O.
//
//  See NUTRITION_MIGRATION_PLAN.md §7.
//

import Foundation

/// Sums logged entries into a day's nutrition.
///
/// Every function here is pure and takes its `Calendar` explicitly, so results
/// do not depend on the device's time zone or on the clock at call time. This is
/// the only place daily nutrition is computed — no `View` body sums anything.
enum NutritionAggregator {

    // MARK: - Day boundaries

    /// The half-open bounds of the calendar day containing `date`.
    ///
    /// `start` is inclusive, `end` is exclusive. The exclusive upper bound is the
    /// point: with an inclusive one, a meal logged at exactly 00:00 tomorrow
    /// would be counted in both days.
    ///
    /// These are the bounds to build an `NSPredicate` from
    /// (`date >= start AND date < end`), and they deliberately match the
    /// predicate the existing diet view models already use.
    static func dayBounds(
        containing date: Date,
        calendar: Calendar
    ) -> (start: Date, end: Date) {
        let start = calendar.startOfDay(for: date)
        // A calendar that cannot add a day is a misconfigured calendar; falling
        // back to the start keeps the interval empty rather than spanning all time.
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return (start, end)
    }

    /// Whether `date` falls in the half-open day starting at `start`.
    static func isDate(
        _ date: Date,
        inDayStartingAt start: Date,
        calendar: Calendar
    ) -> Bool {
        let bounds = dayBounds(containing: start, calendar: calendar)
        return date >= bounds.start && date < bounds.end
    }

    // MARK: - Aggregation

    /// Aggregates the entries that fall on `date`.
    ///
    /// Entries from other days in `entries` are ignored rather than being the
    /// caller's responsibility to filter, so "different days are isolated" is a
    /// property of this function and not of every call site.
    ///
    /// Never compares `Date` to `Date` for equality — two `Date`s are the same
    /// day when `Calendar` says so, not when they are the same instant.
    static func summary(
        for entries: [NutritionEntry],
        on date: Date,
        calendar: Calendar = .current,
        goals: DailyNutritionGoals = .unset
    ) -> DailyNutritionSummary {
        let bounds = dayBounds(containing: date, calendar: calendar)

        var totals = NutritionSnapshot.zero
        var byMeal = Dictionary(uniqueKeysWithValues: MealType.allCases.map { ($0, NutritionSnapshot.zero) })
        var count = 0

        for entry in entries {
            guard entry.date >= bounds.start, entry.date < bounds.end else { continue }

            totals += entry.nutrition
            byMeal[entry.mealType, default: .zero] += entry.nutrition
            count += 1
        }

        return DailyNutritionSummary(
            date: date,
            totals: totals,
            byMealType: byMeal,
            goals: goals,
            entryCount: count
        )
    }

    /// Groups entries that fall on `date` by meal slot, for a caller that wants
    /// the meals themselves rather than the day's totals.
    ///
    /// Meals come back in `MealType.allCases` order, and `.unspecified` always
    /// sorts last so entries with no recorded slot do not displace a real meal.
    static func meals(
        for entries: [NutritionEntry],
        on date: Date,
        calendar: Calendar = .current
    ) -> [NutritionMealSummary] {
        let bounds = dayBounds(containing: date, calendar: calendar)
        let onDay = entries.filter { $0.date >= bounds.start && $0.date < bounds.end }

        let ordered: [MealType] = MealType.selectableCases + [.unspecified]

        return ordered.compactMap { mealType in
            let inSlot = onDay.filter { $0.mealType == mealType }
            guard !inSlot.isEmpty else { return nil }

            return NutritionMealSummary(
                date: date,
                mealType: mealType,
                foodNames: inSlot.map(\.foodName),
                totalGrams: inSlot.reduce(0) { $0 + $1.grams },
                nutrition: inSlot.reduce(NutritionSnapshot.zero) { $0 + $1.nutrition }
            )
        }
    }
}
