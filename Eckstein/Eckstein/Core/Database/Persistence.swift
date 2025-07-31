//
//  Persistence.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample data for previews
        let user = CDUser(context: viewContext)
        user.id = UUID()
        user.email = "preview@example.com"
        user.createdAt = Date()
        user.updatedAt = Date()
        
        let workout = CDWorkout.create(
            name: "Morning Workout",
            date: Date(),
            in: viewContext
        )
        workout.user = user
        
        // Add sample exercises
        let benchPress = CDExercise(context: viewContext)
        benchPress.id = UUID()
        benchPress.name = "Bench Press"
        benchPress.category = "Chest"
        benchPress.muscleGroup = "Pectorals"
        
        // Add sample set
        let set = CDWorkoutSet(context: viewContext)
        set.id = UUID()
        set.setNumber = 1
        set.weightKg = 80
        set.reps = 10
        set.exercise = benchPress
        set.workout = workout
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Eckstein")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.persistentStoreDescriptions.forEach { storeDescription in
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            // Enable lightweight migration
            storeDescription.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            storeDescription.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        }
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    // MARK: - Core Data Operations
    
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    func delete(_ object: NSManagedObject) {
        container.viewContext.delete(object)
        save()
    }
}