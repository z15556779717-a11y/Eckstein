//
//  MealType.swift
//  Eckstein
//
//  The official meal slots for the nutrition layer.
//
//  See NUTRITION_MIGRATION_PLAN.md §6. The four canonical values match the
//  remote `meals.meal_type` CHECK constraint exactly.
//

import Foundation

/// A meal slot.
///
/// Persisted as `CDEcksteinMeal.mealType` — an optional `String`, not an
/// `Int16` enum, so persistence never depends on declaration order and a value
/// written by a newer client cannot trap an older one. `init(storedValue:)`
/// decodes anything unrecognised to `.unspecified` rather than failing.
///
/// This is separate from `CDEcksteinMeal.mealNumber` (the Eckstein method's
/// two-meal partition, 1 or 2). Neither can be derived from the other for data
/// written before slots existed, and this layer never rewrites a `mealNumber`
/// that is already stored.
///
/// It does *assign* one for new rows, though — see ``slotMealNumber``. The
/// slot lives on the meal rather than on the entry, so the Diet screen's
/// 早餐/午餐/晚餐/加餐 sections are only distinguishable if each slot is filed
/// under its own meal row.
enum MealType: String, CaseIterable, Codable, Hashable {
    case breakfast
    case lunch
    case dinner
    case snack

    /// Not a real slot: the bucket for entries logged before `mealType` existed,
    /// or written with a value this build does not know.
    ///
    /// Deliberately a separate case rather than a "nil means unspecified"
    /// convention at every call site. Never offer it in a picker — use
    /// `selectableCases`.
    case unspecified

    /// The slots a user can choose. Excludes `.unspecified`, which is a bucket,
    /// not a choice.
    static var selectableCases: [MealType] {
        [.breakfast, .lunch, .dinner, .snack]
    }

    /// Decodes a stored value, mapping `nil` and anything unrecognised to
    /// `.unspecified`.
    init(storedValue: String?) {
        guard let storedValue = storedValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !storedValue.isEmpty,
              let meal = MealType(rawValue: storedValue),
              meal != .unspecified else {
            self = .unspecified
            return
        }
        self = meal
    }

    /// The value to persist in `CDEcksteinMeal.mealType`.
    ///
    /// `nil` for `.unspecified`, so "no slot recorded" round-trips as absent
    /// rather than as the literal string `"unspecified"`.
    var storedValue: String? {
        self == .unspecified ? nil : rawValue
    }

    /// A human-readable label. Localisation is a later phase; this is the
    /// English fallback.
    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        case .unspecified: return "Other"
        }
    }

    /// The `CDEcksteinMeal.mealNumber` a new entry in this slot is filed under.
    ///
    /// `mealType` is a property of the **meal**, not of the entry, so entries can
    /// only be told apart by slot if each slot gets its own meal row. Reserving
    /// 1–4 for the four slots is what makes them separate sections instead of one
    /// list that relabels itself.
    ///
    /// `.unspecified` has no slot of its own and shares row 1. It writes no
    /// `mealType` at all (`storedValue` is `nil`), so it stays absent on the way
    /// back out rather than claiming to be breakfast.
    ///
    /// Rows already stored under `mealNumber` 1 or 2 keep their number: the
    /// lookup is by `(day, mealNumber)`, so pre-existing data is merged into
    /// rather than moved.
    var slotMealNumber: Int32 {
        switch self {
        case .breakfast: return 1
        case .lunch: return 2
        case .dinner: return 3
        case .snack: return 4
        case .unspecified: return 1
        }
    }

    /// The label to show a user, resolved through the string tables.
    ///
    /// `String.localized` returns the key itself when it finds nothing, so the
    /// miss case is detectable and `displayName` — not the raw key — is what a
    /// missing or not-yet-translated table falls back to.
    var localizedName: String {
        let key = "meal_\(rawValue)"
        let translated = key.localized
        return translated == key ? displayName : translated
    }
}
