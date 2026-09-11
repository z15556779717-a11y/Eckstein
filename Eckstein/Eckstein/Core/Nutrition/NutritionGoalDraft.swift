//
//  NutritionGoalDraft.swift
//  Eckstein
//
//  Reading the goal editor's five text fields.
//
//  Pure, and separate from the view model, because "what counts as a valid
//  target" is a rule rather than a rendering detail — and because a text field
//  is the one place a user can hand the app a NaN, a negative number or the
//  word "banana". None of those may reach `CDUserPreferences`.
//
//  Empty is a *valid* input meaning "clear this goal". That is deliberately
//  different from zero, which is also treated as cleared: a target of zero
//  calories is never something a person means, and `NutritionService` stores
//  "no goal" as zero in the columns that cannot hold NULL.
//

import Foundation

/// One field's reading.
enum NutritionGoalField: Equatable {
    /// Blank — the goal is being cleared.
    case unset

    /// A usable target, in kcal for calories and grams for the macros.
    case value(Double)

    /// Not a number, not finite, negative, or outside any plausible range.
    case invalid
}

/// One component of the goal editor.
///
/// The upper bounds are deliberately far above any real target — they exist to
/// catch a slipped decimal point, not to have an opinion about nutrition.
enum NutritionGoalComponent: String, CaseIterable {
    case calories
    case protein
    case carbs
    case fat
    case fiber

    var titleKey: String {
        switch self {
        case .calories: return "daily_calorie_goal"
        case .protein: return "daily_protein_goal"
        case .carbs: return "daily_carb_goal"
        case .fat: return "daily_fat_goal"
        case .fiber: return "daily_fiber_goal"
        }
    }

    var unit: String {
        self == .calories ? "kcal" : "g"
    }

    /// The largest value this component will accept.
    var maximum: Double {
        switch self {
        case .calories: return 20_000
        case .protein, .carbs: return 2_000
        case .fat, .fiber: return 1_000
        }
    }
}

enum NutritionGoalDraft {

    /// Reads one text field.
    ///
    /// A comma is accepted as a decimal separator: the app ships in languages
    /// where that is the convention, and the decimal keypad produces one.
    static func parse(_ raw: String, for component: NutritionGoalComponent) -> NutritionGoalField {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .unset }

        guard let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")),
              value.isFinite else {
            return .invalid
        }

        // Zero clears, matching how `NutritionService` reads a stored zero back.
        guard value > 0 else { return value == 0 ? .unset : .invalid }
        guard value <= component.maximum else { return .invalid }

        return .value(value)
    }

    /// Reads all five fields.
    ///
    /// Returns `nil` when any field is unusable, so a save cannot half-apply:
    /// either every field the user typed is understood, or nothing is written.
    static func goals(
        calories: String,
        protein: String,
        carbs: String,
        fat: String,
        fiber: String
    ) -> (goals: DailyNutritionGoals?, invalid: [NutritionGoalComponent]) {
        let parsed: [(NutritionGoalComponent, NutritionGoalField)] = [
            (.calories, parse(calories, for: .calories)),
            (.protein, parse(protein, for: .protein)),
            (.carbs, parse(carbs, for: .carbs)),
            (.fat, parse(fat, for: .fat)),
            (.fiber, parse(fiber, for: .fiber))
        ]

        let invalid = parsed.filter { $0.1 == .invalid }.map { $0.0 }
        guard invalid.isEmpty else { return (nil, invalid) }

        func value(_ component: NutritionGoalComponent) -> Double? {
            // The `?` is required: matching a non-optional pattern against an
            // optional value is not a valid pattern match.
            guard case .value(let value)? = parsed.first(where: { $0.0 == component })?.1 else {
                return nil
            }
            return value
        }

        return (
            DailyNutritionGoals(
                calories: value(.calories),
                protein: value(.protein),
                carbs: value(.carbs),
                fat: value(.fat),
                fiber: value(.fiber)
            ),
            []
        )
    }

    /// A goal as text for the editor, or `""` when it is unset.
    static func text(_ value: Double?) -> String {
        guard let value, value.isFinite, value > 0 else { return "" }
        // Whole numbers lose the trailing ".0": a goal of 2000 kcal should read
        // back as "2000", not "2000.0".
        return value.rounded() == value
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}
