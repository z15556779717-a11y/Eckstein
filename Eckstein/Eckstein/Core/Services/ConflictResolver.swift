//
//  ConflictResolver.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation
import CoreData

class ConflictResolver {
    enum ResolutionStrategy {
        case lastWriteWins
        case firstWriteWins
        case manual
        case merge
    }
    
    private var conflicts: [SyncConflict] = []
    private let defaultStrategy: ResolutionStrategy = .lastWriteWins
    
    // MARK: - Conflict Detection
    
    func detectConflict(
        localEntity: NSManagedObject,
        remoteData: [String: Any],
        remoteTimestamp: Date
    ) -> SyncConflict? {
        guard let localTimestamp = (localEntity as? SyncableEntity)?.lastModified,
              let localData = encodeEntity(localEntity) else {
            return nil
        }
        
        // Check if both were modified after last sync
        let hasConflict = localTimestamp > remoteTimestamp.addingTimeInterval(-1) &&
                         localTimestamp < remoteTimestamp.addingTimeInterval(1)
        
        guard hasConflict,
              let remoteDataEncoded = try? JSONSerialization.data(withJSONObject: remoteData) else {
            return nil
        }
        
        let conflict = SyncConflict(
            entityName: String(describing: type(of: localEntity)),
            entityId: localEntity.objectID.uriRepresentation().absoluteString,
            localData: localData,
            remoteData: remoteDataEncoded,
            localTimestamp: localTimestamp,
            remoteTimestamp: remoteTimestamp
        )
        
        conflicts.append(conflict)
        return conflict
    }
    
    // MARK: - Resolution
    
    func resolveConflict(
        _ conflict: SyncConflict,
        strategy: ResolutionStrategy? = nil
    ) -> ConflictResolution {
        let activeStrategy = strategy ?? defaultStrategy
        
        switch activeStrategy {
        case .lastWriteWins:
            return resolveByTimestamp(conflict)
            
        case .firstWriteWins:
            return resolveByEarliestTimestamp(conflict)
            
        case .manual:
            // Store for manual resolution later
            return .useLocal // Default to local until user decides
            
        case .merge:
            return attemptMerge(conflict)
        }
    }
    
    private func resolveByTimestamp(_ conflict: SyncConflict) -> ConflictResolution {
        if conflict.localTimestamp > conflict.remoteTimestamp {
            return .useLocal
        } else {
            return .useRemote
        }
    }
    
    private func resolveByEarliestTimestamp(_ conflict: SyncConflict) -> ConflictResolution {
        if conflict.localTimestamp < conflict.remoteTimestamp {
            return .useLocal
        } else {
            return .useRemote
        }
    }
    
    private func attemptMerge(_ conflict: SyncConflict) -> ConflictResolution {
        // Attempt to merge based on entity type
        switch conflict.entityName {
        case "CDWorkout":
            return mergeWorkout(conflict)
        case "CDMeal":
            return mergeMeal(conflict)
        case "CDWeightEntry":
            // Weight entries shouldn't be merged - use latest
            return resolveByTimestamp(conflict)
        default:
            // Default to last write wins if merge not implemented
            return resolveByTimestamp(conflict)
        }
    }
    
    // MARK: - Entity-Specific Merge Strategies
    
    private func mergeWorkout(_ conflict: SyncConflict) -> ConflictResolution {
        // For workouts, we might want to keep both sets if they're different
        // This is a simplified example - real implementation would be more complex
        
        guard let localData = try? JSONSerialization.jsonObject(with: conflict.localData) as? [String: Any],
              let remoteData = try? JSONSerialization.jsonObject(with: conflict.remoteData) as? [String: Any] else {
            return .useRemote
        }
        
        // Merge logic would go here
        // For now, default to last write wins
        return resolveByTimestamp(conflict)
    }
    
    private func mergeMeal(_ conflict: SyncConflict) -> ConflictResolution {
        // For meals, we might want to combine food items if they're different
        // This is a simplified example
        return resolveByTimestamp(conflict)
    }
    
    // MARK: - Conflict Management
    
    func pendingConflicts() -> [SyncConflict] {
        conflicts.filter { $0.resolution == nil }
    }
    
    func resolveAllConflicts(strategy: ResolutionStrategy) {
        for (index, conflict) in conflicts.enumerated() where conflict.resolution == nil {
            conflicts[index].resolution = resolveConflict(conflict, strategy: strategy)
        }
    }
    
    func clearResolvedConflicts() {
        conflicts.removeAll { $0.resolution != nil }
    }
    
    // MARK: - Helpers
    
    private func encodeEntity(_ entity: NSManagedObject) -> Data? {
        var dict: [String: Any] = [:]
        
        for (key, _) in entity.entity.attributesByName {
            if let value = entity.value(forKey: key) {
                dict[key] = value
            }
        }
        
        return try? JSONSerialization.data(withJSONObject: dict)
    }
    
    // MARK: - Audit Trail
    
    func createAuditEntry(for conflict: SyncConflict, resolution: ConflictResolution) -> ConflictAuditEntry {
        ConflictAuditEntry(
            timestamp: Date(),
            entityName: conflict.entityName,
            entityId: conflict.entityId,
            resolution: resolution,
            localTimestamp: conflict.localTimestamp,
            remoteTimestamp: conflict.remoteTimestamp
        )
    }
}

// MARK: - Supporting Types

struct ConflictAuditEntry {
    let timestamp: Date
    let entityName: String
    let entityId: String
    let resolution: ConflictResolution
    let localTimestamp: Date
    let remoteTimestamp: Date
}