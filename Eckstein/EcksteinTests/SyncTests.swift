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

class SyncTests: XCTestCase {
    var syncManager: SyncManager!
    var networkMonitor: NetworkMonitor!
    var syncQueue: SyncQueue!
    var conflictResolver: ConflictResolver!
    var controller: PersistenceController!
    var context: NSManagedObjectContext!
    
    override func setUp() async throws {
        try await super.setUp()
        controller = PersistenceController(inMemory: true)
        context = controller.container.viewContext
        
        await MainActor.run {
            syncManager = SyncManager.shared
            networkMonitor = NetworkMonitor.shared
            syncQueue = SyncQueue()
            conflictResolver = ConflictResolver()
        }
    }
    
    override func tearDown() {
        syncManager = nil
        networkMonitor = nil
        syncQueue = nil
        conflictResolver = nil
        controller = nil
        context = nil
        super.tearDown()
    }
    
    // MARK: - Network Monitor Tests
    
    func testNetworkMonitorInitialization() async {
        await MainActor.run {
            XCTAssertNotNil(networkMonitor)
            // Initial state may vary based on device
            XCTAssertNotNil(networkMonitor.connectionType)
        }
    }
    
    func testNetworkStatusChanges() async {
        await MainActor.run {
            // Test WiFi-only sync preference
            let shouldSyncOnCellular = networkMonitor.shouldSync(wifiOnly: false)
            let shouldSyncOnWiFiOnly = networkMonitor.shouldSync(wifiOnly: true)
            
            // If connected, first should be true
            if networkMonitor.isConnected {
                XCTAssertTrue(shouldSyncOnCellular)
                // Second depends on connection type
                if networkMonitor.connectionType == .cellular {
                    XCTAssertFalse(shouldSyncOnWiFiOnly)
                }
            }
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
    }
    
    func testFailedOperationRetry() {
        var operation = SyncOperation(
            entityName: "CDMeal",
            entityId: UUID().uuidString,
            operationType: .update,
            retryCount: 0
        )
        
        syncQueue.enqueue(operation)
        
        // Simulate failure
        syncQueue.updateOperationStatus(operation.id, status: .failed, error: "Network error")
        
        let failed = syncQueue.failedOperations()
        XCTAssertEqual(failed.count, 1)
        XCTAssertEqual(failed.first?.retryCount, 1)
        
        // Retry multiple times
        for _ in 0..<3 {
            syncQueue.updateOperationStatus(operation.id, status: .failed, error: "Network error")
        }
        
        // Should not be in failed operations after max retries
        let failedAfterMax = syncQueue.failedOperations()
        XCTAssertEqual(failedAfterMax.count, 0)
    }
    
    // MARK: - Conflict Resolution Tests
    
    func testConflictDetection() {
        // Create local entity
        let workout = CDWorkout.create(name: "Test Workout", date: Date(), in: context)
        workout.updatedAt = Date()
        
        // Simulate remote data
        let remoteData: [String: Any] = [
            "id": workout.id?.uuidString ?? "",
            "name": "Updated Workout",
            "updatedAt": Date().addingTimeInterval(-10) // 10 seconds earlier
        ]
        
        let conflict = conflictResolver.detectConflict(
            localEntity: workout,
            remoteData: remoteData,
            remoteTimestamp: Date().addingTimeInterval(-10)
        )
        
        XCTAssertNotNil(conflict)
    }
    
    func testLastWriteWinsResolution() {
        let localData = Data()
        let remoteData = Data()
        
        let conflict = SyncConflict(
            entityName: "CDWeightEntry",
            entityId: UUID().uuidString,
            localData: localData,
            remoteData: remoteData,
            localTimestamp: Date(),
            remoteTimestamp: Date().addingTimeInterval(-60) // Remote is older
        )
        
        let resolution = conflictResolver.resolveConflict(conflict)
        
        switch resolution {
        case .useLocal:
            XCTAssertTrue(true) // Expected
        case .useRemote, .merge:
            XCTFail("Should use local data when it's newer")
        }
    }
    
    // MARK: - Sync Manager Tests
    
    func testSyncManagerInitialization() async {
        await MainActor.run {
            XCTAssertNotNil(syncManager)
            XCTAssertFalse(syncManager.isSyncing)
            XCTAssertEqual(syncManager.pendingChangesCount, 0)
        }
    }
    
    func testChangeDetection() async {
        await MainActor.run {
            // Create a new workout
            let workout = CDWorkout.create(name: "Sync Test", date: Date(), in: context)
            try? context.save()
            
            // Post save notification manually for testing
            NotificationCenter.default.post(
                name: .NSManagedObjectContextDidSave,
                object: context,
                userInfo: [
                    NSInsertedObjectsKey: Set([workout])
                ]
            )
            
            // Wait a bit for async processing
            let expectation = XCTestExpectation(description: "Change detection")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 1.0)
            
            // Should have pending changes
            XCTAssertGreaterThan(syncManager.pendingChangesCount, 0)
        }
    }
    
    func testSyncStatusUpdates() async {
        await MainActor.run {
            XCTAssertEqual(syncManager.syncStatus, "Ready")
            
            // Trigger manual sync
            syncManager.triggerManualSync()
            
            // Status should update
            XCTAssertNotEqual(syncManager.syncStatus, "Ready")
        }
    }
    
    // MARK: - Syncable Entity Tests
    
    func testSyncableEntityConformance() {
        let user = CDUser(context: context)
        user.id = UUID()
        user.updatedAt = Date()
        
        XCTAssertNotNil(user.lastModified)
        XCTAssertNotNil(user.remoteId)
        XCTAssertEqual(user.localId, user.id)
        
        // Test other entities
        let workout = CDWorkout(context: context)
        workout.id = UUID()
        workout.updatedAt = Date()
        
        XCTAssertNotNil(workout.lastModified)
        XCTAssertEqual(workout.remoteId, workout.id?.uuidString)
    }
    
    // MARK: - Sync History Tests
    
    func testSyncHistoryRecording() async {
        await MainActor.run {
            let initialCount = syncManager.getSyncHistory().count
            
            // Create a sync result
            let result = SyncResult(
                successful: 10,
                failed: 2,
                conflicts: 1,
                errors: [],
                duration: 5.5
            )
            
            // Record in history (this would normally happen during sync)
            let entry = SyncHistoryEntry(
                id: UUID(),
                timestamp: Date(),
                result: result,
                direction: .bidirectional
            )
            
            // Verify result summary
            XCTAssertTrue(result.summary.contains("Successful: 10"))
            XCTAssertTrue(result.summary.contains("Failed: 2"))
            XCTAssertTrue(result.summary.contains("Conflicts: 1"))
        }
    }
    
    // MARK: - Settings Tests
    
    func testSyncSettings() async {
        await MainActor.run {
            // Test WiFi-only setting
            syncManager.syncOnWiFiOnly = true
            XCTAssertTrue(syncManager.syncOnWiFiOnly)
            
            // Test automatic sync
            syncManager.automaticSync = false
            XCTAssertFalse(syncManager.automaticSync)
        }
    }
    
    // MARK: - Data Integrity Tests
    
    func testDataEncoding() {
        let meal = CDMeal(context: context)
        meal.id = UUID()
        meal.type = "breakfast"
        meal.date = Date()
        meal.totalCalories = 500
        
        // Test encoding for sync
        var dict: [String: Any] = [:]
        for (key, _) in meal.entity.attributesByName {
            if let value = meal.value(forKey: key) {
                dict[key] = value
            }
        }
        
        XCTAssertEqual(dict["type"] as? String, "breakfast")
        XCTAssertEqual(dict["totalCalories"] as? Double, 500)
        
        // Test JSON serialization
        XCTAssertNoThrow(try JSONSerialization.data(withJSONObject: dict))
    }
}