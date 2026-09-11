//
//  NutritionSource.swift
//  Eckstein
//
//  Where a `CDEcksteinFood` row's values came from.
//
//  See NUTRITION_MIGRATION_PLAN.md §2. Persisted as the `rawValue` string in
//  `CDEcksteinFood.source`, so the stored values are the API: renaming a case
//  renames a persisted value. Unknown stored strings decode to `nil` rather
//  than to a guess.
//

import Foundation

/// The provenance of a food's nutrition values.
///
/// Ordered by how much the value can be trusted when two rows disagree:
/// a user's own correction (`manual`) outranks a scanned product, which outranks
/// a seeded default.
enum NutritionSource: String, CaseIterable, Codable {
    /// Typed in by the user.
    case manual

    /// Shipped with the app — `FoodData`'s templates and the Eckstein diet rules.
    case seed

    /// Filled in from a scanned barcode via `FoodAPIService`.
    case barcode

    /// Fetched from a nutrition API without a barcode (search-by-name).
    case api

    /// Written by the HealthKit import path.
    case healthKit

    /// Restored from a backup or an import file.
    case imported

    /// Decodes a stored value, returning `nil` for anything unrecognised.
    ///
    /// `nil` is the honest answer for a value this build does not know: it means
    /// "provenance unrecorded", which is exactly what a row written by an older
    /// build has.
    init?(storedValue: String?) {
        guard let storedValue = storedValue?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !storedValue.isEmpty else { return nil }
        self.init(rawValue: storedValue)
    }

    /// The value to persist in `CDEcksteinFood.source`.
    var storedValue: String { rawValue }
}

extension CDEcksteinFood {
    /// The row's provenance, or `nil` when it was not recorded.
    var nutritionSource: NutritionSource? {
        get { NutritionSource(storedValue: source) }
        set { source = newValue?.storedValue }
    }
}
