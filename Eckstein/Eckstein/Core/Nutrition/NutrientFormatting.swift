//
//  NutrientFormatting.swift
//  Eckstein
//
//  How a nutrient amount is written down, in one place.
//
//  The Dashboard, the Diet day view and the trend charts all caption the same
//  five numbers. If each decided for itself how many decimals a gram has, the
//  same protein total would appear as "120 g" on one screen and "120.0 g" on
//  another — which reads as a discrepancy even though the number is identical.
//
//  Units are fixed by the brief and are not localized: kcal and g.
//

import Foundation

enum NutrientFormat {

    /// Calories, whole. Sub-kilocalorie precision is noise — nobody counts a
    /// third of a calorie, and the totals are estimates built from per-100 g
    /// figures to begin with.
    static func calories(_ value: Double?) -> String? {
        guard let value, value.isFinite else { return nil }
        return String(format: "%.0f", value)
    }

    /// Calories as a magnitude, for a sentence that supplies its own sign
    /// ("250 kcal over"). Never negative.
    static func calorieMagnitude(_ value: Double?) -> String? {
        guard let value, value.isFinite else { return nil }
        return String(format: "%.0f", abs(value))
    }

    /// A macronutrient in grams, to one decimal.
    ///
    /// One decimal rather than none because the tracking target is often round
    /// and a total of 119.6 g should not silently read as a reached 120 g target.
    static func grams(_ value: Double?) -> String? {
        guard let value, value.isFinite else { return nil }
        return String(format: "%.1f", value)
    }

    /// A macro amount with its unit, e.g. "120.0 g". `nil` in, `nil` out.
    static func gramsWithUnit(_ value: Double?) -> String? {
        guard let grams = grams(value) else { return nil }
        return "\(grams) g"
    }
}
