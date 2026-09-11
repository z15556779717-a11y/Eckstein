//
//  SyncManager.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation
import CoreData
import Combine

@MainActor
class SyncManager: ObservableObject {
    static let shared = SyncManager()
    
    // Published properties for UI
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var pendingChangesCount = 0
    @Published private(set) var syncProgress: Double = 0.0
    @Published private(set) var syncStatus: String = "Ready"
    
    // Core components
    private let networkMonitor = NetworkMonitor.shared
    private let syncQueue = SyncQueue()
    private let conflictResolver = ConflictResolver()
    private let supabaseService = SupabaseService.shared
    
    // Settings
    @Published var syncOnWiFiOnly = false
    @Published var automaticSync = true
    
    // Internal state
    private var syncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let syncInterval: TimeInterval = 300 // 5 minutes
    private var syncHistory: [SyncHistoryEntry] = []
    
    private init() {
        setupObservers()
        loadSettings()
        updatePendingChangesCount()
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        // Monitor network changes
        networkMonitor.$isConnected
            .sink { [weak self] isConnected in
                if isConnected && self?.automaticSync == true {
                    self?.scheduleSyncIfNeeded()
                }
            }
            .store(in: &cancellables)
        
        // Listen for Core Data changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] notification in
                self?.handleContextDidSave(notification)
            }
            .store(in: &cancellables)
        
        // Listen for network restoration
        NotificationCenter.default.publisher(for: .networkConnectionRestored)
            .sink { [weak self] _ in
                Task {
                    await self?.performSync()
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadSettings() {
        syncOnWiFiOnly = UserDefaults.standard.bool(forKey: "syncOnWiFiOnly")
        automaticSync = UserDefaults.standard.bool(forKey: "automaticSync")
        
        if let lastSync = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date {
            lastSyncDate = lastSync
        }
    }
    
    // MARK: - Core Data Change Detection
    
    private func handleContextDidSave(_ notification: Notification) {
        guard let context = notification.object as? NSManagedObjectContext else { return }
        
        print("SyncManager: Received context save notification")
        print("Context: \(context)")
        
        // Extract changes
        let inserted = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
        let updated = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
        let deleted = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? []
        
        print("Context did save - Inserted: \(inserted.count), Updated: \(updated.count), Deleted: \(deleted.count)")
        
        // Debug: Show what types were saved
        if !inserted.isEmpty {
            print("Inserted types: \(inserted.map { type(of: $0) })")
        }
        if !updated.isEmpty {
            print("Updated types: \(updated.map { type(of: $0) })")
        }
        
        // Queue sync operations
        Task {
            await queueChanges(inserted: inserted, updated: updated, deleted: deleted)
        }
    }
    
    private func queueChanges(
        inserted: Set<NSManagedObject>,
        updated: Set<NSManagedObject>,
        deleted: Set<NSManagedObject>
    ) async {
        var queuedCount = 0
        var skippedCount = 0
        
        // Handle inserted objects
        for object in inserted {
            guard let syncable = object as? SyncableEntity else { 
                skippedCount += 1
                print("Skipped non-syncable insert: \(type(of: object))")
                continue 
            }
            
            let entityName = String(describing: type(of: object))
            print("Queueing insert for entity: \(entityName)")
            
            // Use the syncable entity's ID if available
            let entityId = syncable.localId?.uuidString ?? object.objectID.uriRepresentation().absoluteString
            
            let operation = SyncOperation(
                entityName: entityName,
                entityId: entityId,
                operationType: .create,
                data: encodeEntity(object)
            )
            
            syncQueue.enqueue(operation)
            queuedCount += 1
        }
        
        // Handle updated objects
        for object in updated {
            guard let syncable = object as? SyncableEntity else { 
                skippedCount += 1
                print("Skipped non-syncable update: \(type(of: object))")
                continue 
            }
            
            let entityName = String(describing: type(of: object))
            print("Queueing update for entity: \(entityName)")
            
            // Use the syncable entity's ID if available
            let entityId = syncable.localId?.uuidString ?? object.objectID.uriRepresentation().absoluteString
            
            let operation = SyncOperation(
                entityName: entityName,
                entityId: entityId,
                operationType: .update,
                data: encodeEntity(object)
            )
            
            syncQueue.enqueue(operation)
            queuedCount += 1
        }
        
        // Handle deleted objects
        for object in deleted {
            let entityName = String(describing: type(of: object))
            print("Queueing delete for entity: \(entityName)")
            
            // Try to get ID from syncable entity if possible
            let entityId: String
            if let syncable = object as? SyncableEntity,
               let localId = syncable.localId {
                entityId = localId.uuidString
            } else {
                entityId = object.objectID.uriRepresentation().absoluteString
            }
            
            let operation = SyncOperation(
                entityName: entityName,
                entityId: entityId,
                operationType: .delete
            )
            
            syncQueue.enqueue(operation)
            queuedCount += 1
        }
        
        print("Sync queue update - Queued: \(queuedCount), Skipped: \(skippedCount)")
        updatePendingChangesCount()
        
        // Trigger sync if automatic sync is enabled
        if automaticSync && networkMonitor.shouldSync(wifiOnly: syncOnWiFiOnly) {
            print("Triggering automatic sync...")
            await performSync()
        }
    }
    
    // MARK: - Sync Execution
    
    func performSync() async {
        print("SyncManager.performSync() called")
        
        guard !isSyncing else { 
            print("Sync already in progress, skipping")
            return 
        }
        
        print("Checking network status...")
        guard networkMonitor.shouldSync(wifiOnly: syncOnWiFiOnly) else {
            syncStatus = "Waiting for network..."
            print("Network not available or WiFi-only mode enabled")
            return
        }
        
        print("Checking API configuration...")
        print("Supabase configured: \(AppEnvironment.isSupabaseConfigured)")
        print("OpenAI configured: \(AppEnvironment.isOpenAIConfigured)")

        // Sync only needs Supabase. It previously required a configured OpenAI key
        // too, which silently disabled sync whenever the AI coach was unset.
        guard AppEnvironment.isSupabaseConfigured else {
            syncStatus = "Sync not configured"
            print("Sync skipped: Supabase not configured")
            return
        }
        
        print("Starting sync - Pending changes: \(pendingChangesCount)")
        
        isSyncing = true
        syncStatus = "Syncing..."
        syncProgress = 0.0
        
        let startTime = Date()
        var successCount = 0
        var failureCount = 0
        var conflictCount = 0
        var errors: [SyncError] = []
        
        // Get batch of operations
        let operations = syncQueue.batchOperations()
        let totalOperations = operations.count
        
        print("Sync: Found \(totalOperations) operations to sync")
        
        if totalOperations == 0 {
            print("Sync: No pending operations found")
            print("Sync queue statistics: \(syncQueue.queueStatistics().description)")
            
            // Check if we're getting any data at all
            let allOps = syncQueue.pendingOperations()
            print("All pending operations count: \(allOps.count)")
        }
        
        for (index, operation) in operations.enumerated() {
            syncProgress = Double(index) / Double(totalOperations)
            
            do {
                switch operation.operationType {
                case .create:
                    try await syncCreate(operation)
                case .update:
                    try await syncUpdate(operation)
                case .delete:
                    try await syncDelete(operation)
                }
                
                syncQueue.updateOperationStatus(operation.id, status: .completed)
                successCount += 1
                
            } catch {
                print("❌ SYNC ERROR for \(operation.entityName):")
                print("   Entity ID: \(operation.entityId)")
                print("   Operation: \(operation.operationType)")
                print("   Error: \(error)")
                
                if let supabaseError = error as? NSError {
                    print("   Error Domain: \(supabaseError.domain)")
                    print("   Error Code: \(supabaseError.code)")
                    print("   Error Info: \(supabaseError.userInfo)")
                }
                
                if error is ConflictError {
                    conflictCount += 1
                    syncQueue.updateOperationStatus(operation.id, status: .conflict, error: error.localizedDescription)
                } else {
                    failureCount += 1
                    syncQueue.updateOperationStatus(operation.id, status: .failed, error: error.localizedDescription)
                    errors.append(SyncError(operation: operation, error: error, timestamp: Date()))
                }
            }
        }
        
        // Clean up completed operations
        syncQueue.removeCompletedOperations()
        
        // Record sync result
        let duration = Date().timeIntervalSince(startTime)
        let result = SyncResult(
            successful: successCount,
            failed: failureCount,
            conflicts: conflictCount,
            errors: errors,
            duration: duration
        )
        
        recordSyncHistory(result: result)
        
        // Update UI
        lastSyncDate = Date()
        UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
        
        isSyncing = false
        syncProgress = 1.0
        updatePendingChangesCount()
        
        if result.successful > 0 && result.failed == 0 {
            syncStatus = "Last sync: \(formatDate(lastSyncDate!))"
        } else if result.failed > 0 {
            syncStatus = "Sync failed (\(result.failed) errors)"
        } else if !AppEnvironment.isSupabaseConfigured {
            syncStatus = "Sync not configured"
        } else {
            syncStatus = "Ready to sync"
        }
        
        // Schedule next sync
        scheduleSyncIfNeeded()
    }
    
    // MARK: - Sync Operations
    
    private func syncCreate(_ operation: SyncOperation) async throws {
        guard let data = operation.data else {
            print("Sync create failed - no data for entity: \(operation.entityName)")
            throw SyncManagerError.invalidData
        }
        
        // Try to parse the JSON data
        let entityData: [String: Any]
        do {
            guard let parsedData = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("Sync create failed - data is not a dictionary for entity: \(operation.entityName)")
                throw SyncManagerError.invalidData
            }
            entityData = parsedData
        } catch {
            print("Sync create failed - JSON parsing error for entity: \(operation.entityName)")
            print("Error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("JSON string: \(jsonString)")
            }
            throw SyncManagerError.invalidData
        }
        
        // Map Core Data entity names to Supabase table names
        let tableName = mapEntityToTable(operation.entityName)
        print("Syncing create: \(operation.entityName) -> table: \(tableName)")
        
        // Make sure we have the ID in the data
        var mutableData = entityData
        if mutableData["id"] == nil {
            mutableData["id"] = operation.entityId
        }
        
        // Add user_id only for the tables that actually have the column.
        //
        // This used to run for every row regardless of table. `eckstein_meal_entries`
        // is owned through its `meal_id` and `eckstein_foods` is shared catalog
        // data — neither table has a `user_id` column, so injecting one made
        // PostgREST reject the row ("column user_id does not exist") and the
        // record never synced.
        if NutritionSyncTable.requiresUserID(tableName), mutableData["user_id"] == nil {
            do {
                if let user = try await supabaseService.getCurrentUser() {
                    mutableData["user_id"] = user.id.uuidString
                    print("Sync: Using authenticated user ID: \(user.id.uuidString)")
                } else {
                    print("Sync: WARNING - No authenticated user found!")
                    // Use a test user ID for development
                    // This should be replaced with proper authentication in production
                    let testUserId = "00000000-0000-0000-0000-000000000001"
                    mutableData["user_id"] = testUserId
                    print("Sync: Using test user ID: \(testUserId)")
                }
            } catch {
                print("Sync: Error getting current user: \(error)")
                // Use a test user ID for development
                let testUserId = "00000000-0000-0000-0000-000000000001"
                mutableData["user_id"] = testUserId
                print("Sync: Using test user ID: \(testUserId)")
            }
        }
        
        print("Create data: \(mutableData)")
        
        // Send to Supabase
        try await supabaseService.create(
            table: tableName,
            data: mutableData
        )
    }
    
    private func syncUpdate(_ operation: SyncOperation) async throws {
        guard let data = operation.data,
              let entityData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("Sync update failed - invalid data for entity: \(operation.entityName)")
            throw SyncManagerError.invalidData
        }
        
        // Map Core Data entity names to Supabase table names
        let tableName = mapEntityToTable(operation.entityName)
        print("Syncing update: \(operation.entityName) -> table: \(tableName), id: \(operation.entityId)")
        
        // Make sure we have the ID in the data
        var mutableData = entityData
        if mutableData["id"] == nil {
            mutableData["id"] = operation.entityId
        }
        
        // Check for conflicts
        if let remoteData = try? await supabaseService.fetch(
            table: tableName,
            id: operation.entityId
        ) {
            // Detect and resolve conflicts
            // This is simplified - real implementation would be more complex
            print("Remote data exists, updating...")
        }
        
        // Send update to Supabase
        try await supabaseService.update(
            table: tableName,
            id: operation.entityId,
            data: mutableData
        )
    }
    
    private func syncDelete(_ operation: SyncOperation) async throws {
        // Map Core Data entity names to Supabase table names
        let tableName = mapEntityToTable(operation.entityName)
        print("Syncing delete: \(operation.entityName) -> table: \(tableName), id: \(operation.entityId)")
        
        try await supabaseService.delete(
            table: tableName,
            id: operation.entityId
        )
    }
    
    // MARK: - Manual Sync
    
    func triggerManualSync() {
        print("SyncManager: Manual sync triggered")
        Task {
            await performSync()
        }
    }
    
    // Debug method to test sync
    func testSync() {
        print("SyncManager: Running test sync...")
        
        // Check environment
        print("Test - Supabase configured: \(AppEnvironment.isSupabaseConfigured)")
        print("Test - OpenAI configured: \(AppEnvironment.isOpenAIConfigured)")
        
        // Check pending changes
        print("Test - Pending changes count: \(pendingChangesCount)")
        print("Test - Sync queue operations: \(syncQueue.count())")
        
        // Try to manually trigger a sync
        Task {
            await performSync()
        }
    }
    
    // Force test data into sync queue
    func createTestSyncOperation() {
        print("SyncManager: Creating test sync operation...")
        
        // Create a test operation
        let testData: [String: Any] = [
            "id": UUID().uuidString,
            "date": ISO8601DateFormatter().string(from: Date()),
            "total_calories": 2000,
            "total_protein": 150.5,
            "total_carbs": 250.0,
            "total_fat": 80.0,
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: testData) else {
            print("Failed to create test data")
            return
        }
        
        let operation = SyncOperation(
            entityName: "CDEcksteinMeal",
            entityId: testData["id"] as! String,
            operationType: .create,
            data: jsonData
        )
        
        syncQueue.enqueue(operation)
        updatePendingChangesCount()
        
        print("Test operation created. Pending count: \(pendingChangesCount)")
        
        // Trigger sync
        Task {
            await performSync()
        }
    }
    
    // Test sync with real Core Data entity
    func testSyncWithCoreData() {
        print("SyncManager: Testing sync with Core Data...")
        
        Task { @MainActor in
            let context = PersistenceController.shared.container.viewContext
            
            // Create a test meal
            let meal = CDEcksteinMeal(context: context)
            meal.id = UUID()
            meal.date = Date()
            meal.mealNumber = 1
            
            // Create a test user if needed
            if meal.user == nil {
                let user = CDUser(context: context)
                user.id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")
                user.email = "test@example.com"
                // CDUser doesn't have name property, only email
                user.createdAt = Date()
                user.updatedAt = Date()
                meal.user = user
            }
            
            do {
                try context.save()
                print("Test meal saved to Core Data")
                
                // The save should trigger sync automatically
                // Let's also manually trigger sync after a delay
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                await performSync()
            } catch {
                print("Error saving test meal: \(error)")
            }
        }
    }
    
    // MARK: - Sync Scheduling
    
    private func scheduleSyncIfNeeded() {
        guard automaticSync else { return }
        
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: false) { [weak self] _ in
            Task {
                await self?.performSync()
            }
        }
    }
    
    // MARK: - Utilities
    
    private func mapEntityToTable(_ entityName: String) -> String {
        // Remove "CD" prefix and convert to snake_case for Supabase tables
        let cleanName = entityName.hasPrefix("CD") ? String(entityName.dropFirst(2)) : entityName
        
        switch cleanName {
        case "User":
            return "users"
        case "UserPreferences":
            return "user_preferences"
        case "EcksteinMeal":
            return "eckstein_meals"
        case "EcksteinMealEntry":
            return "eckstein_meal_entries"
        case "EcksteinFood":
            return "eckstein_foods"
        case "CalorieBank":
            return "calorie_bank"
        case "WeightEntry":
            return "weight_entries"
        case "Workout":
            return "workouts"
        case "WorkoutSet":
            return "workout_sets"
        case "WorkoutType":
            return "workout_types"
        case "WorkoutTypeExercise":
            return "workout_type_exercises"
        case "Exercise":
            return "exercises"
        case "Meal":
            return "meals"
        case "MealItem":
            return "meal_items"
        case "Food":
            return "foods"
        case "ChatMessage":
            return "chat_messages"
        default:
            // Convert camelCase to snake_case as fallback
            return cleanName
                .replacingOccurrences(of: "([A-Z])", with: "_$1", options: .regularExpression)
                .lowercased()
                .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        }
    }
    
    private func updatePendingChangesCount() {
        pendingChangesCount = syncQueue.count()
    }
    
    private func encodeEntity(_ entity: NSManagedObject) -> Data? {
        var dict: [String: Any] = [:]
        let dateFormatter = ISO8601DateFormatter()
        
        // Map entity types to their Supabase table structure
        let entityName = entity.entity.name ?? ""
        
        switch entityName {
        case "CDUser":
            if let user = entity as? CDUser {
                dict["id"] = user.id?.uuidString ?? "00000000-0000-0000-0000-000000000001"
                dict["email"] = user.email
                dict["created_at"] = user.createdAt != nil ? dateFormatter.string(from: user.createdAt!) : dateFormatter.string(from: Date())
                dict["updated_at"] = user.updatedAt != nil ? dateFormatter.string(from: user.updatedAt!) : dateFormatter.string(from: Date())
                dict["sync_status"] = user.syncStatus ?? "pending"
                dict["last_synced_at"] = user.lastSyncedAt != nil ? dateFormatter.string(from: user.lastSyncedAt!) : nil
            }
            
        case "CDUserPreferences":
            // Explicit DTO rather than a hand-built dictionary: the keys come
            // from the table definition, including `daily_fat_goal` and
            // `daily_fiber_goal`, which this branch used to drop entirely.
            if let prefs = entity as? CDUserPreferences {
                return NutritionSyncCoding.encode(NutritionPreferencesDTO(preferences: prefs))
            }

        case "CDEcksteinFood":
            // Previously fell through to `default:`, which emits the Core Data
            // attribute names verbatim (`dailyGrams`, `isCustom`, `createdAt`, …)
            // where the table has `daily_grams`, `is_custom`, `created_at`.
            if let food = entity as? CDEcksteinFood {
                return NutritionSyncCoding.encode(NutritionFoodDTO(food: food))
            }

        case "CDEcksteinMeal":
            if let meal = entity as? CDEcksteinMeal {
                return NutritionSyncCoding.encode(NutritionMealDTO(meal: meal))
            }

        case "CDEcksteinMealEntry":
            if let entry = entity as? CDEcksteinMealEntry {
                return NutritionSyncCoding.encode(NutritionMealEntryDTO(entry: entry))
            }

        case "CDWeightEntry":
            if let weight = entity as? CDWeightEntry {
                dict["id"] = weight.id?.uuidString
                dict["user_id"] = weight.user?.id?.uuidString
                dict["weight"] = weight.weightKg
                dict["date"] = weight.date != nil ? dateFormatter.string(from: weight.date!) : nil
                dict["body_fat_percentage"] = weight.bodyFatPercentage
                dict["muscle_mass"] = weight.muscleMass
                dict["notes"] = weight.notes
                dict["created_at"] = weight.date != nil ? dateFormatter.string(from: weight.date!) : dateFormatter.string(from: Date())
                dict["updated_at"] = dateFormatter.string(from: Date())
            }
            
        case "CDWorkout":
            if let workout = entity as? CDWorkout {
                dict["id"] = workout.id?.uuidString
                dict["user_id"] = workout.user?.id?.uuidString
                dict["workout_type_id"] = workout.workoutType?.id?.uuidString
                dict["name"] = workout.name
                dict["date"] = workout.date != nil ? dateFormatter.string(from: workout.date!) : nil
                dict["duration_minutes"] = workout.durationMinutes
                dict["notes"] = workout.notes
                dict["completed"] = workout.completed
                dict["sync_status"] = workout.syncStatus ?? "pending"
                dict["created_at"] = workout.date != nil ? dateFormatter.string(from: workout.date!) : dateFormatter.string(from: Date())
                dict["updated_at"] = dateFormatter.string(from: Date())
            }
            
        case "CDWorkoutSet":
            if let set = entity as? CDWorkoutSet {
                dict["id"] = set.id?.uuidString
                dict["workout_id"] = set.workout?.id?.uuidString
                dict["exercise_id"] = set.exercise?.id?.uuidString
                dict["set_number"] = set.setNumber
                dict["weight_kg"] = set.weightKg
                dict["reps"] = set.reps
                dict["target_reps"] = set.targetReps
                dict["completed"] = set.completed
                dict["notes"] = set.notes
                dict["created_at"] = dateFormatter.string(from: Date())
            }
            
        case "CDExercise":
            if let exercise = entity as? CDExercise {
                dict["id"] = exercise.id?.uuidString
                dict["name"] = exercise.name
                dict["category"] = exercise.category
                dict["muscle_group"] = exercise.muscleGroup
                dict["equipment"] = exercise.equipment
                dict["is_custom"] = exercise.isCustom
                dict["created_at"] = exercise.createdAt != nil ? dateFormatter.string(from: exercise.createdAt!) : dateFormatter.string(from: Date())
            }
            
        case "CDMeal":
            if let meal = entity as? CDMeal {
                dict["id"] = meal.id?.uuidString
                dict["user_id"] = meal.user?.id?.uuidString
                dict["date"] = meal.date != nil ? dateFormatter.string(from: meal.date!) : nil
                dict["meal_type"] = meal.mealType
                dict["created_at"] = dateFormatter.string(from: Date())
                dict["sync_status"] = "pending"
            }
            
        case "CDCalorieBank":
            if let bank = entity as? CDCalorieBank {
                dict["id"] = bank.id?.uuidString
                dict["user_id"] = bank.user?.id?.uuidString
                // For DATE columns in Postgres, we need YYYY-MM-DD format
                if let date = bank.date {
                    let dateOnlyFormatter = DateFormatter()
                    dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
                    dateOnlyFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                    dict["date"] = dateOnlyFormatter.string(from: date)
                } else {
                    dict["date"] = nil
                }
                dict["balance"] = bank.caloriesSaved
                dict["deposit"] = 0  // CDCalorieBank doesn't have separate deposit/withdrawal
                dict["withdrawal"] = 0
                dict["notes"] = bank.foodName  // Using foodName as notes
                dict["sync_status"] = bank.syncStatus ?? "pending"
                dict["created_at"] = dateFormatter.string(from: Date())
                dict["updated_at"] = dateFormatter.string(from: Date())
            }
            
        case "CDChatMessage":
            if let message = entity as? CDChatMessage {
                dict["id"] = message.id?.uuidString
                dict["user_id"] = UUID(uuidString: "00000000-0000-0000-0000-000000000001")?.uuidString // Default user for now
                dict["content"] = message.content
                dict["is_user"] = message.isUser
                dict["timestamp"] = message.timestamp != nil ? dateFormatter.string(from: message.timestamp!) : dateFormatter.string(from: Date())
                dict["sync_status"] = "pending"
                dict["created_at"] = dateFormatter.string(from: Date())
            }
            
        default:
            // Generic encoding for other entities
            for (key, _) in entity.entity.attributesByName {
                if let value = entity.value(forKey: key) {
                    // Convert dates to ISO8601 strings for JSON serialization
                    if let date = value as? Date {
                        dict[key] = dateFormatter.string(from: date)
                    } else if let uuid = value as? UUID {
                        dict[key] = uuid.uuidString
                    } else if let data = value as? Data {
                        // Convert binary data to base64
                        dict[key] = data.base64EncodedString()
                    } else if let decimal = value as? NSDecimalNumber {
                        // Convert NSDecimalNumber to Double for JSON
                        dict[key] = decimal.doubleValue
                    } else if let number = value as? NSNumber {
                        // Handle NSNumber properly
                        dict[key] = number
                    } else {
                        // For all other types (String, etc.)
                        dict[key] = value
                    }
                }
            }
        }
        
        // Remove nil values and relationships
        dict = dict.compactMapValues { value in
            if value is NSSet || value is NSOrderedSet || value is NSManagedObject {
                return nil // Skip relationships
            }
            return value
        }
        
        do {
            // Validate the dictionary can be serialized
            if !JSONSerialization.isValidJSONObject(dict) {
                print("ERROR: Dictionary is not valid JSON object for entity: \(entityName)")
                print("Dict contents: \(dict)")
                
                // Try to find the problematic values
                for (key, value) in dict {
                    if !JSONSerialization.isValidJSONObject([key: value]) {
                        print("  - Invalid value for key '\(key)': \(type(of: value)) = \(value)")
                    }
                }
                return nil
            }
            
            let jsonData = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
            
            // Debug: print the JSON string
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("Encoded JSON for \(entityName):")
                print(jsonString)
            }
            
            return jsonData
        } catch {
            print("Error encoding entity \(entity.entity.name ?? "Unknown"): \(error)")
            // Debug: print the problematic dictionary
            print("Dict contents: \(dict)")
            return nil
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func recordSyncHistory(result: SyncResult) {
        let entry = SyncHistoryEntry(
            id: UUID(),
            timestamp: Date(),
            result: result,
            direction: .bidirectional
        )
        
        syncHistory.append(entry)
        
        // Keep only last 100 entries
        if syncHistory.count > 100 {
            syncHistory.removeFirst(syncHistory.count - 100)
        }
    }
    
    // MARK: - Public Methods
    
    func getSyncHistory() -> [SyncHistoryEntry] {
        syncHistory
    }
    
    func clearSyncQueue() {
        syncQueue.clearQueue()
        updatePendingChangesCount()
    }
    
    func resolvePendingConflicts() {
        conflictResolver.resolveAllConflicts(strategy: .lastWriteWins)
    }
}

// MARK: - Errors

enum SyncManagerError: LocalizedError {
    case invalidData
    case networkUnavailable
    case syncInProgress
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid data format"
        case .networkUnavailable:
            return "Network connection unavailable"
        case .syncInProgress:
            return "Sync already in progress"
        }
    }
}

struct ConflictError: LocalizedError {
    let message: String
    
    var errorDescription: String? {
        message
    }
}