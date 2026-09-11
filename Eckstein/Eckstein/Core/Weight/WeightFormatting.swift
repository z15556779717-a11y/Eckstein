//
//  WeightFormatting.swift
//  Eckstein
//
//  Unit conversion and display for body weight.
//
//  Weight is stored in kilograms everywhere — `CDWeightEntry.weightKg`, the
//  HealthKit export, the CSV export — and the pound is a display concern only.
//  These helpers keep the conversion in one place so a screen never multiplies
//  by a magic number of its own; before this, `2.20462` and `0.453592` both
//  appeared in the codebase as separate approximations of the same constant.
//

import Foundation

extension WeightUnit {

    /// The international avoirdupois pound, by definition. The `2.20462` that
    /// appears in older code is this constant's reciprocal rounded to six
    /// figures; using the defined value keeps a round trip exact.
    static let kilogramsPerPound = 0.45359237

    /// The unit the user has chosen, defaulting to kilograms.
    ///
    /// A stored value that is not one of the cases — a leftover, a hand-edited
    /// default — falls back to kilograms rather than failing, because a unit
    /// preference is not worth an error path.
    static var preferred: WeightUnit {
        WeightUnit(rawValue: UserDefaults.standard.string(forKey: "weightUnit") ?? "kg") ?? .kg
    }

    /// How many kilograms one of this unit is.
    var kilograms: Double {
        self == .lbs ? Self.kilogramsPerPound : 1
    }

    /// A value expressed in this unit, from kilograms.
    func value(fromKilograms kilograms: Double) -> Double {
        kilograms / self.kilograms
    }

    /// A value in this unit, as kilograms.
    func kilograms(from value: Double) -> Double {
        value * self.kilograms
    }

    /// A weight with its unit, rounded for display.
    ///
    /// `nil` in, `nil` out: an absent weight is not "0.0 kg".
    func formatted(kilograms kilograms: Double?, fractionDigits: Int = 1) -> String? {
        guard let kilograms, kilograms.isFinite else { return nil }
        return String(
            format: "%.\(fractionDigits)f %@",
            value(fromKilograms: kilograms),
            rawValue
        )
    }

    /// A signed change with its unit, for a trend caption. Always carries an
    /// explicit sign so "+0.4 kg" and "0.4 kg" are never confused.
    func formattedChange(kilograms kilograms: Double?, fractionDigits: Int = 1) -> String? {
        guard let kilograms, kilograms.isFinite else { return nil }
        let value = value(fromKilograms: kilograms)
        return String(
            format: "%@%.\(fractionDigits)f %@",
            value >= 0 ? "+" : "−",
            abs(value),
            rawValue
        )
    }

    /// A distance with its unit, never signed. For "4.2 kg to go", where the
    /// direction is carried by the sentence rather than a minus sign.
    func formattedDistance(kilograms kilograms: Double?, fractionDigits: Int = 1) -> String? {
        guard let kilograms, kilograms.isFinite else { return nil }
        // Rounded *in display units* before the absolute value is taken, so a
        // change of −0.04 kg renders as "0.0 kg" rather than as a minus sign in
        // front of a zero.
        let value = value(fromKilograms: kilograms)
        return String(format: "%.\(fractionDigits)f", abs(value))
    }
}
