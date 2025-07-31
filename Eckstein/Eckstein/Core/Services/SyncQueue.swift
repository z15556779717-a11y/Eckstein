//
//  SyncQueue.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation
import CoreData

class SyncQueue {
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 2.0
    
    private var operations: [SyncOperation] = []
    private let queue = DispatchQueue(label: "com.eckstein.syncqueue", attributes: .concurrent)
    private let operationsKey = "pendingSyncOperations"
    
    init() {
        loadPersistedOperations()
    }
    
    // MARK: - Queue Management
    
    func enqueue(_ operation: SyncOperation) {
        queue.async(flags: .barrier) {
            self.operations.append(operation)
            self.persistOperations()
        }
    }
    
    func dequeue() -> SyncOperation? {
        queue.sync {
            guard !operations.isEmpty else { return nil }
            return operations.removeFirst()
        }
    }
    
    func peek() -> SyncOperation? {
        queue.sync {
            operations.first
        }
    }
    
    func count() -> Int {
        queue.sync {
            operations.count
        }
    }
    
    func pendingOperations() -> [SyncOperation] {
        queue.sync {
            operations.filter { $0.status == .pending }
        }
    }
    
    func failedOperations() -> [SyncOperation] {
        queue.sync {
            operations.filter { $0.status == .failed && $0.retryCount < maxRetries }
        }
    }
    
    // MARK: - Batch Operations
    
    func batchOperations(limit: Int = 50) -> [SyncOperation] {
        queue.sync {
            let pending = operations
                .filter { $0.status == .pending || ($0.status == .failed && $0.retryCount < maxRetries) }
                .prefix(limit)
            
            return Array(pending)
        }
    }
    
    func updateOperationStatus(_ operationId: UUID, status: SyncStatus, error: String? = nil) {
        queue.async(flags: .barrier) {
            if let index = self.operations.firstIndex(where: { $0.id == operationId }) {
                self.operations[index].status = status
                self.operations[index].lastError = error
                
                if status == .failed {
                    self.operations[index].retryCount += 1
                }
                
                self.persistOperations()
            }
        }
    }
    
    func removeCompletedOperations() {
        queue.async(flags: .barrier) {
            self.operations.removeAll { $0.status == .completed }
            self.persistOperations()
        }
    }
    
    func removeOperation(_ operationId: UUID) {
        queue.async(flags: .barrier) {
            self.operations.removeAll { $0.id == operationId }
            self.persistOperations()
        }
    }
    
    // MARK: - Persistence
    
    private func persistOperations() {
        guard let data = try? JSONEncoder().encode(operations) else { return }
        UserDefaults.standard.set(data, forKey: operationsKey)
    }
    
    private func loadPersistedOperations() {
        guard let data = UserDefaults.standard.data(forKey: operationsKey),
              let operations = try? JSONDecoder().decode([SyncOperation].self, from: data) else {
            return
        }
        
        self.operations = operations.filter { $0.status != .completed }
    }
    
    func clearQueue() {
        queue.async(flags: .barrier) {
            self.operations.removeAll()
            self.persistOperations()
        }
    }
    
    // MARK: - Priority Management
    
    func prioritizeOperation(_ operationId: UUID) {
        queue.async(flags: .barrier) {
            guard let index = self.operations.firstIndex(where: { $0.id == operationId }),
                  index > 0 else { return }
            
            let operation = self.operations.remove(at: index)
            self.operations.insert(operation, at: 0)
            self.persistOperations()
        }
    }
    
    // MARK: - Analytics
    
    func queueStatistics() -> QueueStatistics {
        queue.sync {
            let total = operations.count
            let pending = operations.filter { $0.status == .pending }.count
            let inProgress = operations.filter { $0.status == .inProgress }.count
            let failed = operations.filter { $0.status == .failed }.count
            let conflicts = operations.filter { $0.status == .conflict }.count
            
            return QueueStatistics(
                total: total,
                pending: pending,
                inProgress: inProgress,
                failed: failed,
                conflicts: conflicts
            )
        }
    }
}

// MARK: - Supporting Types

struct QueueStatistics {
    let total: Int
    let pending: Int
    let inProgress: Int
    let failed: Int
    let conflicts: Int
    
    var description: String {
        """
        Queue Statistics:
        - Total: \(total)
        - Pending: \(pending)
        - In Progress: \(inProgress)
        - Failed: \(failed)
        - Conflicts: \(conflicts)
        """
    }
}