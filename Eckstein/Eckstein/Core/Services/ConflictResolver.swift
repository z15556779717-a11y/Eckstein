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
            entityId: identifier(for: localEntity),
            localData: localData,
            remoteData: remoteDataEncoded,
            localTimestamp: localTimestamp,
            remoteTimestamp: remoteTimestamp
        )

        conflicts.append(conflict)
        return conflict
    }

    /// A stable identifier for the entity.
    ///
    /// Every syncable entity carries a required `id: UUID`, so prefer it. The
    /// object-ID fallback is only safe once the object is saved:
    /// `uriRepresentation()` raises `NSInvalidArgumentException` on a temporary
    /// ID, which would abort the process rather than throw.
    private func identifier(for entity: NSManagedObject) -> String {
        if let id = entity.value(forKey: "id") as? UUID {
            return id.uuidString
        }
        if !entity.objectID.isTemporaryID {
            return entity.objectID.uriRepresentation().absoluteString
        }
        return UUID().uuidString
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
    
    /// Encodes an entity's attributes for the conflict record.
    ///
    /// `Date`, `UUID` and `Data` attribute values are not valid JSON types, and
    /// `JSONSerialization.data(withJSONObject:)` does not *throw* on them — it
    /// raises an `NSInvalidArgumentException`, which Swift cannot catch and
    /// which therefore terminated the process. Every syncable entity has a
    /// `Date` attribute, so this returned nothing but aborted the caller. The
    /// values are now converted the same way `SyncManager.encodeEntity` does:
    /// dates to ISO-8601, UUIDs to strings, binary data to base64.
    private func encodeEntity(_ entity: NSManagedObject) -> Data? {
        let dateFormatter = ISO8601DateFormatter()
        var dict: [String: Any] = [:]

        for (key, _) in entity.entity.attributesByName {
            guard let value = entity.value(forKey: key) else { continue }

            if let date = value as? Date {
                dict[key] = dateFormatter.string(from: date)
            } else if let uuid = value as? UUID {
                dict[key] = uuid.uuidString
            } else if let data = value as? Data {
                dict[key] = data.base64EncodedString()
            } else if let decimal = value as? NSDecimalNumber {
                dict[key] = decimal.doubleValue
            } else {
                dict[key] = value
            }
        }

        guard JSONSerialization.isValidJSONObject(dict) else { return nil }
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