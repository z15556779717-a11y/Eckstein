//
//  NutritionHealthKitService.swift
//  Eckstein
//
//  Writes a logged meal's nutrition to Apple Health, when the user asks for it.
//
//  See NUTRITION_MIGRATION_PLAN.md §13.
//
//  What this deliberately does not do:
//
//    * No write at launch, and no "sync everything" action. Every call is made in
//      response to something the user did, on the day they did it. HealthKit
//      write permission is a one-off grant, and bulk-writing a user's history
//      into their Health record on the strength of it is not what they agreed to.
//    * No delete. This never removes a sample, whoever wrote it.
//    * No import. This phase is App → Health only; nutrition read-back is a later
//      change and would need its own conflict rules.
//
//  Dedupe: each sample carries the entry's `UUID` in its metadata, so before
//  writing anything the service asks HealthKit which of an entry's nutrients are
//  already recorded and writes only the rest. Re-exporting the same entry is a
//  no-op, and an export interrupted half way resumes rather than restarting.
//

import Foundation
import HealthKit

/// The slice of HealthKit this export needs.
///
/// A protocol so the export can be exercised without a store: the simulator has
/// HealthKit but no user data, and a test cannot grant write permission. The
/// shipped path is `HealthKitNutritionStore`, which is a thin wrapper over
/// `HKHealthStore` — nothing here exists to make the real implementation
/// test-only, only to let the logic above it be tested.
@MainActor
protocol NutritionHealthKitStore: AnyObject {
    /// Whether HealthKit exists on this device at all.
    var isHealthDataAvailable: Bool { get }

    /// Asks for permission to write the dietary types. Returns whether the user
    /// granted it. Never throws: a refusal is an answer, not an error.
    func requestWriteAuthorization() async -> Bool

    /// Which of `entryID`'s nutrients already have a sample written by this app.
    func recordedNutrients(for entryID: UUID) async -> Set<NutritionHealthKitNutrient>

    /// Writes one sample.
    func write(_ plan: NutritionHealthKitSamplePlan) async throws
}

/// The outcome of an export attempt, for a caller that wants to say something
/// about it.
struct NutritionHealthKitExportResult: Equatable {
    /// Samples actually written.
    var written: Int = 0
    /// Samples skipped because the entry and nutrient were already recorded.
    var skipped: Int = 0
    /// Samples that failed. The export continues past a failure.
    var failed: Int = 0
    /// Whether the user has granted write access.
    var isAuthorized: Bool = false
    /// Whether HealthKit is present on this device.
    var isAvailable: Bool = true
    /// Entries with no recorded nutrition, which contribute nothing.
    var entriesWithoutNutrition: Int = 0

    /// Whether anything was written.
    var didWrite: Bool { written > 0 }

    /// Whether there was nothing to do — everything was already recorded.
    var wasAlreadyUpToDate: Bool {
        written == 0 && failed == 0 && entriesWithoutNutrition == 0
    }
}

/// Exports logged meals to Apple Health on demand.
@MainActor
final class NutritionHealthKitService: ObservableObject {

    static let shared = NutritionHealthKitService()

    private let store: NutritionHealthKitStore

    /// Default argument is `nil` rather than `HealthKitNutritionStore()`: a
    /// default parameter is evaluated outside the actor, so constructing the
    /// store there would not compile.
    init(store: NutritionHealthKitStore? = nil) {
        self.store = store ?? HealthKitNutritionStore()
    }

    /// Whether the app can write nutrition at all on this device.
    var isAvailable: Bool { store.isHealthDataAvailable }

    /// Asks for write permission. Call before the first export, from the user's
    /// action — not at launch.
    @discardableResult
    func requestAuthorization() async -> Bool {
        guard store.isHealthDataAvailable else { return false }
        return await store.requestWriteAuthorization()
    }

    /// Exports the given entries, writing only what is missing.
    ///
    /// Each entry is checked against HealthKit separately, so one entry that
    /// fails to write does not stop the others.
    @discardableResult
    func export(_ inputs: [NutritionHealthKitExportInput]) async -> NutritionHealthKitExportResult {
        var result = NutritionHealthKitExportResult()
        result.isAvailable = store.isHealthDataAvailable

        guard store.isHealthDataAvailable else { return result }

        result.isAuthorized = await store.requestWriteAuthorization()
        guard result.isAuthorized else { return result }

        for input in inputs {
            result.entriesWithoutNutrition += input.hasNutritionData ? 0 : 1

            let alreadyWritten = await store.recordedNutrients(for: input.entryID)
            let keys = Set(alreadyWritten.map {
                NutritionHealthKitSampleKey(entryID: input.entryID, nutrient: $0)
            })

            let planned = NutritionHealthKitPlanner.samples(for: input)
            let missing = NutritionHealthKitPlanner.missingSamples(for: [input], alreadyWritten: keys)
            result.skipped += planned.count - missing.count

            for plan in missing {
                do {
                    try await store.write(plan)
                    result.written += 1
                } catch {
                    // One bad sample does not abandon the rest of the day.
                    print("HealthKit nutrition export failed for \(plan.nutrient.rawValue): \(error)")
                    result.failed += 1
                }
            }
        }

        return result
    }

    /// Exports one day's logged entries.
    ///
    /// `NutritionService` supplies the entries, so the export reads the same
    /// numbers the rest of the app shows. The service is built in the body rather
    /// than as a default argument: a default is evaluated outside the actor, and
    /// its initialiser is main-actor isolated.
    @discardableResult
    func exportDay(
        _ date: Date = Date(),
        service: NutritionService? = nil,
        calendar: Calendar = .current
    ) async -> NutritionHealthKitExportResult {
        let service = service ?? NutritionService()
        do {
            let inputs = try service.entries(on: date, calendar: calendar)
                .compactMap { NutritionHealthKitExportInput(entry: $0, fallbackDate: date) }
            return await export(inputs)
        } catch {
            print("HealthKit nutrition export could not read the day's entries: \(error)")
            return NutritionHealthKitExportResult()
        }
    }
}

// MARK: - The real store

/// `HKHealthStore` behind `NutritionHealthKitStore`.
///
/// The only type in the nutrition layer that touches HealthKit's API. It reads
/// back what it wrote through the `EcksteinMealEntryUUID` metadata key, and never
/// deletes anything.
@MainActor
final class HealthKitNutritionStore: NutritionHealthKitStore {

    private let healthStore = HKHealthStore()

    var isHealthDataAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var allTypes: [NutritionHealthKitNutrient: HKQuantityType] {
        NutritionHealthKitNutrient.allCases.reduce(into: [:]) { result, nutrient in
            if let type = nutrient.quantityType { result[nutrient] = type }
        }
    }

    func requestWriteAuthorization() async -> Bool {
        guard isHealthDataAvailable else { return false }
        let types = Set(allTypes.values)
        guard !types.isEmpty else { return false }

        do {
            try await healthStore.requestAuthorization(toShare: types, read: [])
            return types.allSatisfy { healthStore.authorizationStatus(for: $0) == .sharingAuthorized }
        } catch {
            // A refusal lands here or in the status check above. Either way the
            // app carries on without writing; nothing about a denied permission
            // should be fatal.
            print("HealthKit nutrition authorization failed: \(error)")
            return false
        }
    }

    func recordedNutrients(for entryID: UUID) async -> Set<NutritionHealthKitNutrient> {
        guard isHealthDataAvailable else { return [] }

        var found: Set<NutritionHealthKitNutrient> = []
        let predicate = HKQuery.predicateForObjects(
            withMetadataKey: NutritionHealthKitMetadata.mealEntryUUIDKey,
            operatorType: .equalTo,
            value: entryID.uuidString
        )

        for (nutrient, type) in allTypes {
            let samples = await samples(ofType: type, predicate: predicate)
            if samples.contains(where: { NutritionHealthKitMetadata.isOurs($0.metadata) }) {
                found.insert(nutrient)
            }
        }

        return found
    }

    func write(_ plan: NutritionHealthKitSamplePlan) async throws {
        guard let type = plan.nutrient.quantityType else {
            throw NutritionHealthKitError.unsupportedNutrient(plan.nutrient)
        }

        let sample = HKQuantitySample(
            type: type,
            quantity: HKQuantity(unit: plan.nutrient.unit, doubleValue: plan.value),
            start: plan.date,
            end: plan.date,
            metadata: NutritionHealthKitMetadata.metadata(entryID: plan.entryID, foodName: plan.foodName)
        )

        try await healthStore.save(sample)
    }

    private func samples(ofType type: HKQuantityType, predicate: NSPredicate) async -> [HKQuantitySample] {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    // A read failure is reported as "nothing recorded", which
                    // makes the export write again rather than silently skip —
                    // a duplicate sample is the better failure of the two.
                    print("HealthKit nutrition lookup failed: \(error)")
                    continuation.resume(returning: [])
                    return
                }
                continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
            }
            healthStore.execute(query)
        }
    }
}

/// Why an export could not write a sample.
enum NutritionHealthKitError: Error {
    /// The quantity type is not available on this system.
    case unsupportedNutrient(NutritionHealthKitNutrient)
}
