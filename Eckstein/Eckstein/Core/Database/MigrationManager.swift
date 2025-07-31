//
//  MigrationManager.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//
//

import CoreData

class MigrationManager {
    static func migrateIfNeeded(for container: NSPersistentContainer) {
        // Lightweight migration is automatic
        // Add custom migration logic here if needed
    }
    
    static func cleanupLegacyData(in context: NSManagedObjectContext) {
        // Remove any Item entities if they exist
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Item")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
        } catch {
            print("Failed to cleanup legacy data: \(error)")
        }
    }
}