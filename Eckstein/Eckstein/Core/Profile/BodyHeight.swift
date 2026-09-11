//
//  BodyHeight.swift
//  Eckstein
//
//  The user's height, stored and read in centimetres.
//
//  Height lives in `UserDefaults` under one key rather than in the Core Data
//  preferences object, because that is where it already was: `CDWeightEntry.bmi`
//  and the weight CSV export both read `userHeightCm` directly, and a second
//  store for the same number is how a BMI ends up disagreeing with itself. This
//  type names that key once so the Profile editor, the Dashboard card and the
//  BMI calculation cannot drift onto different spellings of it.
//
//  Only the *validation* lives here — what counts as a plausible height is
//  `WeightMetrics.plausibleHeightCm`, shared with the BMI calculation itself so
//  the editor cannot accept a value the formula would refuse.
//

import Foundation

enum BodyHeight {

    /// The `UserDefaults` key. Unchanged since before phase 4; renaming it
    /// would silently discard every existing user's height.
    static let storageKey = "userHeightCm"

    /// The stored height in centimetres, or `nil` when none is set or the stored
    /// value is not a usable height.
    ///
    /// A stored zero — which is what `UserDefaults.double(forKey:)` returns for a
    /// missing key — reads as unset rather than as a 0 cm person.
    static var storedCentimetres: Double? {
        guard UserDefaults.standard.object(forKey: storageKey) != nil else { return nil }
        let stored = UserDefaults.standard.double(forKey: storageKey)
        return WeightMetrics.isValidHeight(stored) ? stored : nil
    }

    /// Writes a height, or clears it when `nil` or implausible.
    static func store(_ centimetres: Double?) {
        guard let centimetres, WeightMetrics.isValidHeight(centimetres) else {
            UserDefaults.standard.removeObject(forKey: storageKey)
            return
        }
        UserDefaults.standard.set(centimetres, forKey: storageKey)
    }

    /// A height typed by the user, in centimetres, or `nil` if it is not one.
    ///
    /// Accepts a comma as the decimal separator, which is what a Chinese or
    /// Hebrew keyboard offers, and rejects anything outside
    /// `WeightMetrics.plausibleHeightCm` — the same range the BMI calculation
    /// enforces, so a value that saves is a value that computes.
    static func parse(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")),
              value.isFinite else { return nil }
        guard WeightMetrics.isValidHeight(value) else { return nil }
        // One decimal place: the field displays one, so storing more would make
        // the saved value differ from the one the user just read back.
        return (value * 10).rounded() / 10
    }

    /// A height for a text field: no unit, no trailing `.0`, empty when unset.
    static func text(_ centimetres: Double?) -> String {
        guard let centimetres, WeightMetrics.isValidHeight(centimetres) else { return "" }
        let rounded = centimetres.rounded()
        return rounded == centimetres
            ? String(format: "%.0f", centimetres)
            : String(format: "%.1f", centimetres)
    }

    /// A height with its unit, for display where the unit is not implied by a
    /// field label. Centimetres are not convertible here: the app stores and
    /// shows heights in cm in every language, and a feet-and-inches rendering of
    /// a metric BMI input is a second way to get the number wrong.
    static func formatted(_ centimetres: Double?) -> String? {
        guard let centimetres, WeightMetrics.isValidHeight(centimetres) else { return nil }
        return "\(text(centimetres)) cm"
    }
}
