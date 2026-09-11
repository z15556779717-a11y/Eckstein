//
//  NutritionHealthKitExport.swift
//  Eckstein
//
//  The pure half of the Apple Health nutrition export: which nutrients an entry
//  contributes, what metadata identifies a sample, and which samples are still
//  missing. No `HKHealthStore`, no Core Data, no I/O.
//
//  See NUTRITION_MIGRATION_PLAN.md §13.
//
//  Kept separate from `NutritionHealthKitService` on purpose. The simulator has
//  the HealthKit framework but no user data and cannot grant write permission, so
//  anything that touches `HKHealthStore` is untestable in CI. Everything that
//  *decides* something lives here and is a plain function.
//

import Foundation
import HealthKit

/// A nutrient the app can write to Apple Health.
///
/// The five the brief names, and no more. This phase is App → Health only; the
/// import direction for nutrition is not built.
enum NutritionHealthKitNutrient: String, CaseIterable, Hashable {
    case energyConsumed
    case protein
    case carbohydrates
    case fatTotal
    case fiber

    /// The HealthKit quantity type this nutrient is written as, or `nil` when the
    /// identifier is unavailable on this system.
    var quantityTypeIdentifier: HKQuantityTypeIdentifier? {
        switch self {
        case .energyConsumed: return .dietaryEnergyConsumed
        case .protein: return .dietaryProtein
        case .carbohydrates: return .dietaryCarbohydrates
        case .fatTotal: return .dietaryFatTotal
        case .fiber: return .dietaryFiber
        }
    }

    var quantityType: HKQuantityType? {
        guard let identifier = quantityTypeIdentifier else { return nil }
        return HKObjectType.quantityType(forIdentifier: identifier)
    }

    /// The unit the value is expressed in: kcal for energy, grams otherwise.
    var unit: HKUnit {
        switch self {
        case .energyConsumed: return .kilocalorie()
        case .protein, .carbohydrates, .fatTotal, .fiber: return .gram()
        }
    }

    /// The nutrient's value in `snapshot`, in `unit`.
    func value(in snapshot: NutritionSnapshot) -> Double {
        switch self {
        case .energyConsumed: return snapshot.calories
        case .protein: return snapshot.protein
        case .carbohydrates: return snapshot.carbs
        case .fatTotal: return snapshot.fat
        case .fiber: return snapshot.fiber
        }
    }
}

/// One logged entry, reduced to the facts an export needs.
///
/// A value type rather than a `CDEcksteinMealEntry`, so the planning logic is
/// testable without a store — the same reason `NutritionEntry` exists for the
/// aggregator.
struct NutritionHealthKitExportInput: Equatable {
    let entryID: UUID
    let foodName: String
    /// When the sample is dated. A meal entry has no timestamp of its own, so
    /// this is the meal's date.
    let date: Date
    let snapshot: NutritionSnapshot
    /// Whether the entry recorded nutrition at all. `false` for an entry logged
    /// before nutrition tracking existed.
    let hasNutritionData: Bool
}

/// One sample the export intends to write.
struct NutritionHealthKitSamplePlan: Equatable {
    let entryID: UUID
    let nutrient: NutritionHealthKitNutrient
    let value: Double
    let date: Date
    let foodName: String
}

/// What identifies a sample that has already been written.
///
/// The pair, not the entry alone: a food with calories but no protein writes one
/// sample, and a later re-export must be able to write the protein without
/// writing a second calorie sample.
struct NutritionHealthKitSampleKey: Hashable {
    let entryID: UUID
    let nutrient: NutritionHealthKitNutrient
}

/// Metadata keys written onto every sample this app creates.
///
/// `EcksteinMealEntryUUID` is the dedupe key: it is stable across launches (the
/// entry's own `UUID`, not its `objectID`), so a re-export can find its earlier
/// samples. HealthKit stores it in `HKQuantitySample.metadata`, which is
/// preserved by the system and readable back by a metadata predicate.
enum NutritionHealthKitMetadata {
    static let mealEntryUUIDKey = "EcksteinMealEntryUUID"

    /// Which app wrote the sample. HealthKit records its own source revision, but
    /// a value the app controls survives a store rebuild and is readable back.
    static let sourceAppKey = "EcksteinSourceApp"
    static let sourceAppValue = "Eckstein"

    static func metadata(entryID: UUID, foodName: String) -> [String: Any] {
        [
            mealEntryUUIDKey: entryID.uuidString,
            sourceAppKey: sourceAppValue,
            HKMetadataKeyFoodType: foodName
        ]
    }

    /// The entry a sample belongs to, or `nil` for a sample this app did not
    /// write.
    static func entryID(in metadata: [String: Any]?) -> UUID? {
        guard let raw = metadata?[mealEntryUUIDKey] as? String else { return nil }
        return UUID(uuidString: raw)
    }

    /// Whether a sample was written by this app.
    static func isOurs(_ metadata: [String: Any]?) -> Bool {
        (metadata?[sourceAppKey] as? String) == sourceAppValue
    }
}

/// Decides what an export writes. Pure — every input is a value.
enum NutritionHealthKitPlanner {

    /// The samples one entry contributes.
    ///
    /// Returns an empty array when:
    ///
    ///   * the entry recorded no nutrition — a meal logged before nutrition
    ///     tracking. Writing zeros would put a fabricated zero-calorie meal into
    ///     the user's Health record, and HealthKit has no "unknown"; and
    ///   * a nutrient is zero. Zero contributes nothing to a daily sum, and a
    ///     written zero is indistinguishable from a real measurement of zero, so
    ///     it is noise at best and a false statement at worst.
    ///
    /// Negative values are dropped for the same reason — nothing here can be
    /// negative, so one appearing means the input is corrupt, and HealthKit
    /// rejects negative dietary quantities anyway.
    static func samples(for input: NutritionHealthKitExportInput) -> [NutritionHealthKitSamplePlan] {
        guard input.hasNutritionData else { return [] }

        return NutritionHealthKitNutrient.allCases.compactMap { nutrient in
            let value = nutrient.value(in: input.snapshot)
            guard value > 0 else { return nil }
            return NutritionHealthKitSamplePlan(
                entryID: input.entryID,
                nutrient: nutrient,
                value: value,
                date: input.date,
                foodName: input.foodName
            )
        }
    }

    /// The subset of `inputs`' samples whose entry and nutrient have not already
    /// been written.
    ///
    /// This is the dedupe rule, in one place: a sample is skipped when
    /// `alreadyWritten` holds its `(entryID, nutrient)` pair, whoever wrote it.
    /// Re-running an export therefore writes nothing the second time, and an
    /// export that stopped half way resumes at the first missing sample.
    static func missingSamples(
        for inputs: [NutritionHealthKitExportInput],
        alreadyWritten: Set<NutritionHealthKitSampleKey>
    ) -> [NutritionHealthKitSamplePlan] {
        inputs
            .flatMap(samples(for:))
            .filter { !alreadyWritten.contains(NutritionHealthKitSampleKey(entryID: $0.entryID, nutrient: $0.nutrient)) }
    }

    /// Whether every sample an entry contributes has already been written.
    static func isFullyExported(
        _ input: NutritionHealthKitExportInput,
        alreadyWritten: Set<NutritionHealthKitSampleKey>
    ) -> Bool {
        missingSamples(for: [input], alreadyWritten: alreadyWritten).isEmpty
    }
}

// MARK: - Core Data bridge

extension NutritionHealthKitExportInput {
    /// The export facts for a logged entry.
    ///
    /// `meal.date` is nullable, so it falls back to the argument rather than
    /// dropping the entry: an entry with no date is still a real meal.
    init?(entry: CDEcksteinMealEntry, fallbackDate: Date = Date()) {
        guard let id = entry.id, let meal = entry.meal else { return nil }
        self.init(
            entryID: id,
            foodName: entry.foodName ?? "",
            date: meal.date ?? fallbackDate,
            snapshot: entry.nutritionSnapshot,
            hasNutritionData: entry.hasNutritionData
        )
    }
}
