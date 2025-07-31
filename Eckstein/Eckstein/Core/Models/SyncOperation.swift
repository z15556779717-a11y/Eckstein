//
//  SyncOperation.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation

enum SyncOperationType: String, CaseIterable, Codable {
    case create = "CREATE"
    case update = "UPDATE"
    case delete = "DELETE"
}

enum SyncStatus: String, CaseIterable, Codable {
    case pending = "PENDING"
    case inProgress = "IN_PROGRESS"
    case completed = "COMPLETED"
    case failed = "FAILED"
    case conflict = "CONFLICT"
}

struct SyncOperation: Identifiable, Codable {
    let id: UUID
    let entityName: String
    let entityId: String
    let operationType: SyncOperationType
    var status: SyncStatus
    let timestamp: Date
    var retryCount: Int
    var lastError: String?
    var data: Data?
    
    init(
        id: UUID = UUID(),
        entityName: String,
        entityId: String,
        operationType: SyncOperationType,
        status: SyncStatus = .pending,
        timestamp: Date = Date(),
        retryCount: Int = 0,
        lastError: String? = nil,
        data: Data? = nil
    ) {
        self.id = id
        self.entityName = entityName
        self.entityId = entityId
        self.operationType = operationType
        self.status = status
        self.timestamp = timestamp
        self.retryCount = retryCount
        self.lastError = lastError
        self.data = data
    }
}

// MARK: - Sync Metadata Protocol

protocol SyncableEntity {
    var lastModified: Date? { get set }
    var syncStatus: String? { get set }
    var remoteId: String? { get set }
    var localId: UUID? { get }
}

// MARK: - Sync Conflict

struct SyncConflict {
    let entityName: String
    let entityId: String
    let localData: Data
    let remoteData: Data
    let localTimestamp: Date
    let remoteTimestamp: Date
    
    var resolution: ConflictResolution?
}

enum ConflictResolution {
    case useLocal
    case useRemote
    case merge(mergedData: Data)
}

// MARK: - Sync Result

struct SyncResult {
    let successful: Int
    let failed: Int
    let conflicts: Int
    let errors: [SyncError]
    let duration: TimeInterval
    
    var summary: String {
        """
        Sync completed:
        - Successful: \(successful)
        - Failed: \(failed)
        - Conflicts: \(conflicts)
        - Duration: \(String(format: "%.2f", duration))s
        """
    }
}

struct SyncError {
    let operation: SyncOperation
    let error: Error
    let timestamp: Date
}

// MARK: - Sync History

struct SyncHistoryEntry: Identifiable {
    let id: UUID
    let timestamp: Date
    let result: SyncResult
    let direction: SyncDirection
    
    enum SyncDirection: String {
        case upload = "Upload"
        case download = "Download"
        case bidirectional = "Bidirectional"
    }
}