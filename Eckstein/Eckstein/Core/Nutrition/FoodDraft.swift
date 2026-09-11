//
//  FoodDraft.swift
//  Eckstein
//
//  Validating the amounts a user types for a food.
//
//  Two places need this: the custom-food form (per-100 g values) and the amount
//  field on an entry (grams actually eaten). Both are free-text number entry, and
//  both must refuse the same things — a name with nothing in it, a negative
//  amount, `nan`, `inf`, or a per-100 g figure that cannot be true.
//
//  The rules live here rather than in a `View` for the usual reason: they are
//  testable without a store or a screen, and the two forms cannot drift onto
//  different definitions of "valid".
//
//  Reuses `NutritionGoalField` from `NutritionGoalDraft` — `.unset`, `.value`
//  and `.invalid` are the same three outcomes a goal field has, and giving them a
//  second spelling here would be a second thing to keep in step.
//

import Foundation

enum FoodDraft {

    // MARK: - Ranges

    /// Calories per 100 g. Pure fat is about 900 kcal per 100 g, which is the
    /// ceiling; nothing edible is denser.
    static let calorieRange: ClosedRange<Double> = 0...900

    /// A macronutrient per 100 g. Protein, carbohydrate and fat cannot together
    /// exceed 100 g in 100 g of food, so none of them alone can either.
    static let macroRange: ClosedRange<Double> = 0...100

    /// The largest amount loggable in one entry — 100 kg. Above this the number
    /// is a unit mix-up, and the stored `Int32` grams column would only be
    /// stretched further.
    static let maxGrams: Double = 100_000

    /// The longest name worth storing, matching the catalog's own display.
    static let maxNameLength = 120

    // MARK: - Parsing

    /// A per-100 g amount, or an amount of food.
    ///
    /// Unlike a goal field, an explicit zero is a **value**: "0 g of carbohydrate
    /// per 100 g" is a fact about a food, not an absent entry. Only a blank field
    /// is `.unset`.
    ///
    /// A comma is accepted as the decimal separator, because that is the key a
    /// Chinese or Hebrew keyboard puts on the decimal pad.
    static func parseAmount(_ raw: String, range: ClosedRange<Double>) -> NutritionGoalField {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .unset }

        guard let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")),
              value.isFinite else { return .invalid }
        guard range.contains(value) else { return .invalid }
        return .value(value)
    }

    /// Calories per 100 g — required by the model, so a blank field is `0` rather
    /// than an error. Water really is zero.
    static func parseCalories(_ raw: String) -> NutritionGoalField {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .value(0) }
        return parseAmount(trimmed, range: calorieRange)
    }

    /// The amount eaten. Must be greater than zero — a zero-gram entry records
    /// nothing, and the model stores grams as a positive `Int32`.
    static func parseGrams(_ raw: String) -> NutritionGoalField {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .unset }

        guard let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")),
              value.isFinite else { return .invalid }
        guard value > 0 else { return .invalid }
        guard value <= maxGrams else { return .invalid }
        return .value(value)
    }

    /// A food name, or `nil` when there is not one.
    static func parseName(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxNameLength))
    }

    // MARK: - Building

    /// The fields of the custom-food form, as typed.
    struct Draft {
        var name: String = ""
        var category: String = ""
        var calories: String = ""
        var protein: String = ""
        var carbs: String = ""
        var fat: String = ""
        var fiber: String = ""

        /// A blank-name draft, and the starting point for the form.
        static let empty = Draft()
    }

    /// The result of validating a draft.
    struct Result {
        /// The catalog template, or `nil` when anything was refused.
        let template: FoodTemplate?

        /// The fields that were refused, as localization keys.
        let invalidFields: [String]

        // `nameField` is not a `FoodTemplate` field, so it is reported
        // separately rather than being folded into the list above.
        /// Whether the name itself was missing.
        let nameIsMissing: Bool

        var isValid: Bool { template != nil }
    }

    /// Validates a draft and builds the catalog template for it.
    ///
    /// All-or-nothing, like the goals editor: a food saved with a corrected
    /// calorie figure and a silently dropped protein figure would be worse than
    /// one not saved at all, because the user would have no way to tell.
    static func result(from draft: Draft) -> Result {
        guard let name = parseName(draft.name) else {
            return Result(template: nil, invalidFields: [], nameIsMissing: true)
        }

        let calories = parseCalories(draft.calories)
        let protein = parseAmount(draft.protein, range: macroRange)
        let carbs = parseAmount(draft.carbs, range: macroRange)
        let fat = parseAmount(draft.fat, range: macroRange)
        let fiber = parseAmount(draft.fiber, range: macroRange)

        // The nutrient names, not the goal names: this is a food's label, not a
        // target, and "Daily Calories" over a per-100 g field would read as a
        // budget the user is supposed to enter.
        let fields: [(key: String, field: NutritionGoalField)] = [
            ("calories", calories),
            ("protein", protein),
            ("carbs", carbs),
            ("fat", fat),
            ("fiber", fiber)
        ]

        let invalid = fields.filter { $0.field == .invalid }.map(\.key)
        guard invalid.isEmpty, case .value(let calorieValue) = calories else {
            return Result(template: nil, invalidFields: invalid, nameIsMissing: false)
        }

        let template = FoodTemplate(
            name: name,
            category: parseName(draft.category) ?? "",
            barcode: nil,
            caloriesPer100g: Int(calorieValue.rounded()),
            // `.unset` stays `nil`: a food whose label does not list fibre has an
            // unknown fibre content, not a fibre content of zero.
            proteinPer100g: value(of: protein),
            carbsPer100g: value(of: carbs),
            fatPer100g: value(of: fat),
            fiberPer100g: value(of: fiber),
            brand: nil,
            servingSize: nil,
            servingUnit: nil
        )

        return Result(template: template, invalidFields: [], nameIsMissing: false)
    }

    private static func value(of field: NutritionGoalField) -> Double? {
        guard case .value(let value) = field else { return nil }
        return value
    }
}
