//
//  SyncableExtensions.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation
import CoreData

// MARK: - CDUser + SyncableEntity

extension CDUser: SyncableEntity {
    var lastModified: Date? {
        get { updatedAt }
        set { updatedAt = newValue }
    }
    
    var remoteId: String? {
        get { id?.uuidString }
        set { 
            if let value = newValue, let uuid = UUID(uuidString: value) {
                id = uuid
            }
        }
    }
    
    var localId: UUID? {
        id
    }
}

// MARK: - CDWorkout + SyncableEntity

extension CDWorkout: SyncableEntity {
    var lastModified: Date? {
        get { date }
        set { date = newValue }
    }
    
    var remoteId: String? {
        get { id?.uuidString }
        set { 
            if let value = newValue, let uuid = UUID(uuidString: value) {
                id = uuid
            }
        }
    }
    
    var localId: UUID? {
        id
    }
}

// MARK: - CDMeal + SyncableEntity

extension CDMeal: SyncableEntity {
    var lastModified: Date? {
        get { date }
        set { date = newValue }
    }
    
    var syncStatus: String? {
        get { nil } // CDMeal doesn't have syncStatus, so we return nil
        set { } // No-op
    }
    
    var remoteId: String? {
        get { id?.uuidString }
        set { 
            if let value = newValue, let uuid = UUID(uuidString: value) {
                id = uuid
            }
        }
    }
    
    var localId: UUID? {
        id
    }
}

// MARK: - CDWeightEntry + SyncableEntity

extension CDWeightEntry: SyncableEntity {
    var lastModified: Date? {
        get { date }
        set { date = newValue }
    }
    
    
    var remoteId: String? {
        get { id?.uuidString }
        set { 
            if let value = newValue, let uuid = UUID(uuidString: value) {
                id = uuid
            }
        }
    }
    
    var localId: UUID? {
        id
    }
}

// MARK: - CDExercise + SyncableEntity

extension CDExercise: SyncableEntity {
    var lastModified: Date? {
        get { createdAt }
        set { createdAt = newValue }
    }
    
    var syncStatus: String? {
        get { nil }
        set { }
    }
    
    var remoteId: String? {
        get { id?.uuidString }
        set { 
            if let value = newValue, let uuid = UUID(uuidString: value) {
                id = uuid
            }
        }
    }
    
    var localId: UUID? {
        id
    }
}

// MARK: - CDFood + SyncableEntity

extension CDFood: SyncableEntity {
    var lastModified: Date? {
        get { lastUsed }
        set { lastUsed = newValue }
    }
    
    var syncStatus: String? {
        get { nil }
        set { }
    }
    
    var remoteId: String? {
        get { id?.uuidString }
        set { 
            if let value = newValue, let uuid = UUID(uuidString: value) {
                id = uuid
            }
        }
    }
    
    var localId: UUID? {
        id
    }
}

// MARK: - CDCalorieBank + SyncableEntity

extension CDCalorieBank: SyncableEntity {
    var lastModified: Date? {
        get { date }
        set { date = newValue }
    }
    
    var remoteId: String? {
        get { id?.uuidString }
        set { 
            if let value = newValue, let uuid = UUID(uuidString: value) {
                id = uuid
            }
        }
    }
    
    var localId: UUID? {
        id
    }
}

// MARK: - CDEcksteinMeal + SyncableEntity

extension CDEcksteinMeal: SyncableEntity {
    var lastModified: Date? {
        get { date }
        set { date = newValue }
    }
    
    var syncStatus: String? {
        get { nil }
        set { }
    }
    
    var remoteId: String? {
        get { id?.uuidString }
        set { 
            if let value = newValue, let uuid = UUID(uuidString: value) {
                id = uuid
            }
        }
    }
    
    var localId: UUID? { id }
}

// MARK: - CDEcksteinMealEntry + SyncableEntity

extension CDEcksteinMealEntry: SyncableEntity {
    var lastModified: Date? {
        get { meal?.date }
        set { }
    }
    
    var syncStatus: String? {
        get { nil }
        set { }
    }
    
    var remoteId: String? {
        get { id?.uuidString }
        set { 
            if let value = newValue, let uuid = UUID(uuidString: value) {
                id = uuid
            }
        }
    }
    
    var localId: UUID? { id }
}