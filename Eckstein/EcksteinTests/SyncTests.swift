//
//  SyncTests.swift
//  EcksteinTests
//
//  Created by Eliad Shahar on 13/07/2025.
//

import XCTest
import CoreData
import Network
@testable import Eckstein

/// Tests for the sync stack: `NetworkMonitor`, `SyncQueue`, `ConflictResolver`,
/// `SyncManager` and the `SyncOperation`/`SyncResult` models.
///
/// NOTE (phase-1 audit): this file previously referenced members that do not
/// exist (`CDWorkout.updatedAt`, `CDMeal.type`, `CDMeal.totalCalories`), asserted
/// a `SyncConflict` that `ConflictResolver` cannot produce, and drove
/// `SyncManager.triggerManualSync()`, which performs real Supabase requests when
/// the environment is configured. It has been rewritten against the real API in
/// `SyncManager.swift` / `SyncQueue.swift` / `ConflictResolver.swift` /
/// `SyncOperation.swift`.
///
/// The suite is hermetic: every test forces `automaticSync = false` and nothing
/// calls `triggerManualSync()`/`performSync()`, so no network request is issued.
/// `SyncManager` is `@MainActor`, hence the annotation on the class.
@MainActor
class SyncTests: XCTestCase {
    var syncManager: SyncManager!
    var networkMonitor: NetworkMonitor!
    var syncQueue: SyncQueue!
    var conflictResolver: ConflictResolver!
    var controller: PersistenceController!
    var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        controller = PersistenceController(inMemory: true)
        context = controller.container.viewContext

        syncManager = SyncManager.shared
        networkMonitor = NetworkMonitor.shared
        syncQueue = SyncQueue()
        conflictResolver = ConflictResolver()

        // `SyncQueue` persists to UserDefaults, so operations enqueued by an
        // earlier test would otherwise be reloaded here (and counted by
        // `queueStatistics()`). Clear and flush the queue so each test starts
        // empty: `count()` uses `queue.sync`, which waits for the clear barrier.
        syncQueue.clearQueue()
        _ = syncQueue.count()

        // Keep the shared manager from ever starting a real sync during tests,
        // and start from an empty queue so pending-count assertions are stable.
        syncManager.automaticSync = false
        syncManager.syncOnWiFiOnly = false
        syncManager.clearSyncQueue()
    }

    override func tearDown() {
        syncManager?.automaticSync = false
        syncManager = nil
        networkMonitor = nil
        syncQueue = nil
        conflictResolver = nil
        controller = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func isUseLocal(_ resolution: ConflictResolution) -> Bool {
        if case .useLocal = resolution { return true }
        return false
    }

    private func isUseRemote(_ resolution: ConflictResolution) -> Bool {
        if case .useRemote = resolution { return true }
        return false
    }

    private func makeConflict(localTimestamp: Date, remoteTimestamp: Date) -> SyncConflict {
        SyncConflict(
            entityName: "CDWeightEntry",
            entityId: UUID().uuidString,
            localData: Data(),
            remoteData: Data(),
            localTimestamp: localTimestamp,
            remoteTimestamp: remoteTimestamp,
            resolution: nil
        )
    }

    // MARK: - Network Monitor Tests

    func testNetworkMonitorInitialization() {
        XCTAssertNotNil(networkMonitor)
        XCTAssertTrue(networkMonitor === NetworkMonitor.shared)

        // `shouldSync` must never claim we can sync while offline.
        if !networkMonitor.isConnected {
            XCTAssertFalse(networkMonitor.shouldSync(wifiOnly: false))
            XCTAssertFalse(networkMonitor.shouldSync(wifiOnly: true))
        }
    }

    func testNetworkStatusChanges() {
        // `shouldSync(wifiOnly: false)` mirrors connectivity exactly...
        let shouldSyncOnCellular = networkMonitor.shouldSync(wifiOnly: false)
        XCTAssertEqual(shouldSyncOnCellular, networkMonitor.isConnected)

        // ...and in WiFi-only mode only wired/WiFi links qualify.
        let shouldSyncOnWiFiOnly = networkMonitor.shouldSync(wifiOnly: true)
        if networkMonitor.isConnected {
            let isWiredOrWiFi = networkMonitor.connectionType == .wifi
                || networkMonitor.connectionType == .ethernet
            XCTAssertEqual(shouldSyncOnWiFiOnly, isWiredOrWiFi)
        } else {
            XCTAssertFalse(shouldSyncOnWiFiOnly)
        }
    }

    // MARK: - Sync Queue Tests

    func testSyncQueueOperations() {
        let operation = SyncOperation(
            entityName: "CDWorkout",
            entityId: UUID().uuidString,
            operationType: .create,
            data: Data()
        )

        syncQueue.enqueue(operation)

        XCTAssertEqual(syncQueue.count(), 1)
        XCTAssertEqual(syncQueue.pendingOperations().count, 1)

        let dequeued = syncQueue.dequeue()
        XCTAssertNotNil(dequeued)
        XCTAssertEqual(dequeued?.entityName, "CDWorkout")
        XCTAssertEqual(dequeued?.id, operation.id)
        XCTAssertEqual(syncQueue.count(), 0)
    }

    func testBatchOperations() {
        // Add multiple operations
        for i in 0..<100 {
            let operation = SyncOperation(
                entityName: "CDWeightEntry",
                entityId: UUID().uuidString,
                operationType: i % 3 == 0 ? .create : i % 3 == 1 ? .update : .delete
            )
            syncQueue.enqueue(operation)
        }

        let batch = syncQueue.batchOperations(limit: 50)
        XCTAssertEqual(batch.count, 50)

        let stats = syncQueue.queueStatistics()
        XCTAssertEqual(stats.total, 100)
        XCTAssertEqual(stats.pending, 100)
        XCTAssertEqual(stats.failed, 0)
        XCTAssertEqual(stats.conflicts, 0)
    }

    func testFailedOperationRetry() {
        let operation = SyncOperation(
            entityName: "CDMeal",
            entityId: UUID().uuidString,
            operationType: .update,
            retryCount: 0
        )

        syncQueue.enqueue(operation)

        // Simulate failure — `updateOperationStatus` bumps `retryCount`.
        syncQueue.updateOperationStatus(operation.id, status: .failed, error: "Network error")

        let failed = syncQueue.failedOperations()
        XCTAssertEqual(failed.count, 1)
        XCTAssertEqual(failed.first?.retryCount, 1)
        XCTAssertEqual(failed.first?.lastError, "Network error")
        XCTAssertEqual(syncQueue.queueStatistics().failed, 1)

        // Retry past `maxRetries` (3): the operation stays failed but is no
        // longer eligible for retry, so `failedOperations()` stops reporting it.
        for _ in 0..<3 {
            syncQueue.updateOperationStatus(operation.id, status: .failed, error: "Network error")
        }

        let failedAfterMax = syncQueue.failedOperations()
        XCTAssertEqual(failedAfterMax.count, 0)
        XCTAssertEqual(syncQueue.queueStatistics().total, 1)
        XCTAssertEqual(syncQueue.count(), 1)
    }

    // MARK: - Conflict Resolution Tests

    func testConflictDetection() {
        // `detectConflict` requires a `SyncableEntity` with a non-nil
        // `lastModified` and an attribute set that `JSONSerialization` accepts.
        // It used to abort the process here: `ConflictResolver.encodeEntity`
        // copied raw `Date` values into the payload, and
        // `JSONSerialization.data(withJSONObject:)` raises an
        // `NSInvalidArgumentException` for a `Date` rather than throwing, so
        // `try?` did not help. `encodeEntity` now converts dates to ISO-8601
        // (see AUDIT.md), and this asserts the real behaviour.
        let workout = CDWorkout.create(name: "Test Workout", date: Date(), in: context)
        try? context.save()

        let remoteData: [String: Any] = [
            "id": workout.id?.uuidString ?? "",
            "name": "Updated Workout"
        ]

        // A remote timestamp outside the ±1s window is not a conflict.
        let farApart = conflictResolver.detectConflict(
            localEntity: workout,
            remoteData: remoteData,
            remoteTimestamp: workout.date!.addingTimeInterval(-10)
        )
        XCTAssertNil(farApart)
        XCTAssertTrue(conflictResolver.pendingConflicts().isEmpty)

        // A remote timestamp within ±1s of the local `lastModified` is.
        let sameInstant = conflictResolver.detectConflict(
            localEntity: workout,
            remoteData: remoteData,
            remoteTimestamp: workout.date!
        )

        XCTAssertNotNil(sameInstant)
        XCTAssertEqual(sameInstant?.entityName, "CDWorkout")
        // `CDWorkout.lastModified` is backed by `date` (it has no `updatedAt`).
        XCTAssertEqual(sameInstant?.localTimestamp, workout.date)
        XCTAssertEqual(sameInstant?.remoteTimestamp, workout.date)
        // The identifier is the entity's own `id`, not a Core Data object URI.
        XCTAssertEqual(sameInstant?.entityId, workout.id?.uuidString)
        // The conflict is registered and unresolved.
        XCTAssertEqual(conflictResolver.pendingConflicts().count, 1)
    }

    func testLastWriteWinsResolution() {
        // Local is newer -> local wins (the default strategy).
        let localWins = makeConflict(
            localTimestamp: Date(),
            remoteTimestamp: Date().addingTimeInterval(-60)
        )
        let resolution = conflictResolver.resolveConflict(localWins)

        XCTAssertTrue(isUseLocal(resolution), "Should use local data when it's newer")
        XCTAssertFalse(isUseRemote(resolution))

        // Remote is newer -> remote wins.
        let remoteWins = makeConflict(
            localTimestamp: Date().addingTimeInterval(-60),
            remoteTimestamp: Date()
        )
        XCTAssertTrue(isUseRemote(conflictResolver.resolveConflict(remoteWins)))

        // `firstWriteWins` inverts the comparison.
        let olderLocalWins = makeConflict(
            localTimestamp: Date().addingTimeInterval(-60),
            remoteTimestamp: Date()
        )
        XCTAssertTrue(
            isUseLocal(conflictResolver.resolveConflict(olderLocalWins, strategy: .firstWriteWins))
        )

        // The audit entry mirrors the conflict it was created for.
        let audit = conflictResolver.createAuditEntry(for: localWins, resolution: resolution)
        XCTAssertEqual(audit.entityName, "CDWeightEntry")
        XCTAssertEqual(audit.entityId, localWins.entityId)
        XCTAssertEqual(audit.localTimestamp, localWins.localTimestamp)
        XCTAssertEqual(audit.remoteTimestamp, localWins.remoteTimestamp)
        XCTAssertTrue(isUseLocal(audit.resolution))
    }

    // MARK: - Sync Manager Tests

    func testSyncManagerInitialization() {
        XCTAssertNotNil(syncManager)
        XCTAssertTrue(syncManager === SyncManager.shared)
        XCTAssertFalse(syncManager.isSyncing)
        // `setUp` emptied the queue, so the published pending count is 0.
        XCTAssertEqual(syncManager.pendingChangesCount, 0)
        XCTAssertFalse(syncManager.syncStatus.isEmpty)
    }

    func testChangeDetection() async throws {
        // Saving a syncable entity must queue a sync operation. `automaticSync`
        // is false (set in `setUp`), so no sync — and no network call — runs.
        XCTAssertFalse(syncManager.automaticSync)

        let before = syncManager.pendingChangesCount

        let workout = CDWorkout.create(name: "Sync Test", date: Date(), in: context)
        try? context.save()

        // Post the save notification explicitly so the check does not depend on
        // Core Data's own notification timing.
        NotificationCenter.default.post(
            name: .NSManagedObjectContextDidSave,
            object: context,
            userInfo: [
                NSInsertedObjectsKey: Set<NSManagedObject>([workout])
            ]
        )

        // Let the manager's `Task { await queueChanges(...) }` drain.
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertGreaterThan(syncManager.pendingChangesCount, before)
    }

    func testSyncErrorDescriptions() {
        // Covers the error surface `performSync()` reports to the UI.
        XCTAssertEqual(SyncManagerError.invalidData.errorDescription, "Invalid data format")
        XCTAssertEqual(
            SyncManagerError.networkUnavailable.errorDescription,
            "Network connection unavailable"
        )
        XCTAssertEqual(SyncManagerError.syncInProgress.errorDescription, "Sync already in progress")
        XCTAssertEqual(ConflictError(message: "boom").errorDescription, "boom")
    }

    // MARK: - Syncable Entity Tests

    func testSyncableEntityConformance() {
        let user = CDUser(context: context)
        user.id = UUID()
        user.updatedAt = Date()

        XCTAssertNotNil(user.lastModified)
        XCTAssertNotNil(user.remoteId)
        XCTAssertEqual(user.localId, user.id)
        XCTAssertEqual(user.remoteId, user.id?.uuidString)

        // `CDWorkout.lastModified` is backed by `date` (it has no `updatedAt`).
        let workout = CDWorkout(context: context)
        workout.id = UUID()
        workout.date = Date()

        XCTAssertNotNil(workout.lastModified)
        XCTAssertEqual(workout.lastModified, workout.date)
        XCTAssertEqual(workout.remoteId, workout.id?.uuidString)

        let weightEntry = CDWeightEntry(context: context)
        weightEntry.id = UUID()
        weightEntry.date = Date()

        XCTAssertNotNil(weightEntry.lastModified)
        XCTAssertEqual(weightEntry.localId, weightEntry.id)
    }

    // MARK: - Sync History Tests

    func testSyncHistoryRecording() {
        // Nothing records history without a real sync, so the shared manager
        // reports no entries in a test run.
        XCTAssertTrue(syncManager.getSyncHistory().isEmpty)

        let result = SyncResult(
            successful: 10,
            failed: 2,
            conflicts: 1,
            errors: [],
            duration: 5.5
        )

        // Verify result summary
        XCTAssertTrue(result.summary.contains("Successful: 10"))
        XCTAssertTrue(result.summary.contains("Failed: 2"))
        XCTAssertTrue(result.summary.contains("Conflicts: 1"))
        XCTAssertTrue(result.summary.contains("5.50"))

        let entry = SyncHistoryEntry(
            id: UUID(),
            timestamp: Date(),
            result: result,
            direction: .bidirectional
        )

        XCTAssertEqual(entry.result.successful, 10)
        XCTAssertEqual(entry.result.errors.count, 0)
        XCTAssertEqual(entry.direction.rawValue, "Bidirectional")
        XCTAssertEqual(SyncHistoryEntry.SyncDirection.upload.rawValue, "Upload")
        XCTAssertEqual(SyncHistoryEntry.SyncDirection.download.rawValue, "Download")
    }

    // MARK: - Settings Tests

    func testSyncSettings() {
        let originalWiFiOnly = syncManager.syncOnWiFiOnly
        let originalAutomatic = syncManager.automaticSync

        // Test WiFi-only setting
        syncManager.syncOnWiFiOnly = true
        XCTAssertTrue(syncManager.syncOnWiFiOnly)

        // Test automatic sync
        syncManager.automaticSync = false
        XCTAssertFalse(syncManager.automaticSync)

        syncManager.syncOnWiFiOnly = originalWiFiOnly
        syncManager.automaticSync = originalAutomatic
    }

    // MARK: - Data Integrity Tests

    func testDataEncoding() {
        let workout = CDWorkout.create(name: "Sync Test", date: Date(), in: context)
        workout.notes = "Leg day"
        workout.durationMinutes = 45

        // Mirror `SyncManager.encodeEntity`: every attribute is copied across and
        // `Date`/`UUID` values are converted to strings, because raw `Date` and
        // `UUID` values are not valid JSON and would make the payload unserializable.
        let dateFormatter = ISO8601DateFormatter()
        var dict: [String: Any] = [:]
        for (key, _) in workout.entity.attributesByName {
            guard let value = workout.value(forKey: key) else { continue }

            if let date = value as? Date {
                dict[key] = dateFormatter.string(from: date)
            } else if let uuid = value as? UUID {
                dict[key] = uuid.uuidString
            } else {
                dict[key] = value
            }
        }

        XCTAssertEqual(dict["name"] as? String, "Sync Test")
        XCTAssertEqual(dict["notes"] as? String, "Leg day")
        XCTAssertEqual(dict["syncStatus"] as? String, "pending")
        XCTAssertNotNil(dict["date"] as? String)
        XCTAssertNotNil(dict["id"] as? String)

        // Test JSON serialization
        XCTAssertTrue(JSONSerialization.isValidJSONObject(dict))
        XCTAssertNoThrow(try JSONSerialization.data(withJSONObject: dict))

        let encoded = try? JSONSerialization.data(withJSONObject: dict)
        let decoded = encoded.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        XCTAssertEqual(decoded?["name"] as? String, "Sync Test")
        XCTAssertEqual(decoded?["durationMinutes"] as? Int, 45)
        XCTAssertEqual(decoded?["completed"] as? Bool, false)
    }
}
