//
//  Persistence.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import CoreData
import os

struct PersistenceController {
    static let shared = PersistenceController()

    /// The store error that stopped the app from opening its database, if any.
    ///
    /// Set once by the store-load callback and never cleared: a store that
    /// failed to open stays failed for the life of the process. Exposed so a
    /// screen can explain the empty state, and so the failure is a value the
    /// app owns rather than a crash it cannot report.
    private(set) static var storeLoadFailure: NSError?

    private static let logger = Logger(subsystem: "com.eliosdigital.Eckstein", category: "persistence")

    /// The one `NSManagedObjectModel` instance every container shares.
    ///
    /// `NSPersistentCloudKitContainer(name:)` compiles a *fresh* model object on
    /// every call, and Core Data disambiguates `+entity` on the generated
    /// `NSManagedObject` subclasses by scanning every model that is loaded. Two
    /// containers therefore mean two models claiming `CDWorkout`, `CDChatMessage`
    /// and the rest, and every `CDXxx(context:)` throws
    /// "must have a valid NSEntityDescription
    /// (… Multiple NSEntityDescriptions claim …)".
    ///
    /// The app only builds `shared`, so this never showed up at runtime, but any
    /// second container (a preview, a test, a future background context) hit it.
    /// Loading the model once and handing the same instance to every container
    /// keeps `+entity` unambiguous.
    static let managedObjectModel: NSManagedObjectModel = {
        guard let url = Bundle.main.url(forResource: "Eckstein", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: url) else {
            fatalError("Failed to load the Eckstein Core Data model from \(Bundle.main.bundlePath)")
        }
        return model
    }()

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
        container = NSPersistentCloudKitContainer(
            name: "Eckstein",
            managedObjectModel: Self.managedObjectModel
        )
        
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
                // A store that will not open is a data problem, not a reason to
                // kill the app on launch. Record it so a future screen can say
                // so, log it for the device console, and let the app come up:
                // an empty app the user can still use beats an instant crash
                // they cannot report.
                Self.storeLoadFailure = error
                Self.logger.error("Core Data store failed to load: \(error.domain) \(error.code)")
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
                // Logged rather than fatal: a save can fail because the device
                // is out of space, which is neither the user's fault nor a
                // reason to take the whole app down with it.
                Self.logger.error("Core Data save failed: \(nsError.domain) \(nsError.code)")
            }
        }
    }
    
    func delete(_ object: NSManagedObject) {
        container.viewContext.delete(object)
        save()
    }
}