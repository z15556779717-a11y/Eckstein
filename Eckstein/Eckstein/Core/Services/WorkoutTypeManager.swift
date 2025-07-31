//
//  WorkoutTypeManager.swift
//  Eckstein
//
//  Created by Eliad Shahar on 14/07/2025.
//

import Foundation
import CoreData

@MainActor
class WorkoutTypeManager: ObservableObject {
    static let shared = WorkoutTypeManager()
    
    @Published var workoutTypes: [CDWorkoutType] = []
    private let context = PersistenceController.shared.container.viewContext
    
    private init() {
        fetchWorkoutTypes()
    }
    
    // MARK: - Fetch Methods
    
    func fetchWorkoutTypes() {
        let request: NSFetchRequest<CDWorkoutType> = CDWorkoutType.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDWorkoutType.name, ascending: true)]
        request.predicate = NSPredicate(format: "user == %@", getCurrentUser())
        
        do {
            workoutTypes = try context.fetch(request)
        } catch {
            print("Error fetching workout types: \(error)")
        }
    }
    
    // MARK: - Create Methods
    
    func createWorkoutType(name: String) -> CDWorkoutType? {
        let workoutType = CDWorkoutType(context: context)
        workoutType.id = UUID()
        workoutType.name = name
        workoutType.createdAt = Date()
        workoutType.user = getCurrentUser()
        
        do {
            try context.save()
            fetchWorkoutTypes()
            return workoutType
        } catch {
            print("Error creating workout type: \(error)")
            return nil
        }
    }
    
    func addExerciseToWorkoutType(_ workoutType: CDWorkoutType, exercise: CDExercise, targetSets: Int, targetReps: Int) {
        let workoutTypeExercise = CDWorkoutTypeExercise(context: context)
        workoutTypeExercise.id = UUID()
        workoutTypeExercise.exercise = exercise
        workoutTypeExercise.workoutType = workoutType
        workoutTypeExercise.targetSets = Int32(targetSets)
        workoutTypeExercise.targetReps = Int32(targetReps)
        
        // Set order index based on existing exercises
        if let exercises = workoutType.exercises as? Set<CDWorkoutTypeExercise> {
            workoutTypeExercise.orderIndex = Int32(exercises.count)
        } else {
            workoutTypeExercise.orderIndex = 0
        }
        
        do {
            try context.save()
            fetchWorkoutTypes()
        } catch {
            print("Error adding exercise to workout type: \(error)")
        }
    }
    
    // MARK: - Update Methods
    
    func updateWorkoutType(_ workoutType: CDWorkoutType, name: String? = nil) {
        if let name = name {
            workoutType.name = name
        }
        
        do {
            try context.save()
            fetchWorkoutTypes()
        } catch {
            print("Error updating workout type: \(error)")
        }
    }
    
    func updateExerciseTargets(_ exercise: CDWorkoutTypeExercise, targetSets: Int, targetReps: Int) {
        exercise.targetSets = Int32(targetSets)
        exercise.targetReps = Int32(targetReps)
        
        do {
            try context.save()
        } catch {
            print("Error updating exercise targets: \(error)")
        }
    }
    
    // MARK: - Delete Methods
    
    func deleteWorkoutType(_ workoutType: CDWorkoutType) {
        context.delete(workoutType)
        
        do {
            try context.save()
            fetchWorkoutTypes()
        } catch {
            print("Error deleting workout type: \(error)")
        }
    }
    
    func removeExerciseFromWorkoutType(_ exercise: CDWorkoutTypeExercise) {
        context.delete(exercise)
        
        do {
            try context.save()
            fetchWorkoutTypes()
        } catch {
            print("Error removing exercise from workout type: \(error)")
        }
    }
    
    // MARK: - Workout Creation
    
    func createWorkoutFromType(_ workoutType: CDWorkoutType) -> CDWorkout? {
        let workout = CDWorkout(context: context)
        workout.id = UUID()
        workout.name = workoutType.name
        workout.date = Date()
        workout.completed = false
        workout.syncStatus = "pending"
        workout.user = getCurrentUser()
        workout.workoutType = workoutType
        
        // Create sets from workout type exercises
        if let exercises = workoutType.exercises as? Set<CDWorkoutTypeExercise> {
            let sortedExercises = exercises.sorted { $0.orderIndex < $1.orderIndex }
            
            for typeExercise in sortedExercises {
                guard let exercise = typeExercise.exercise else { continue }
                
                // Create sets based on target
                for setNumber in 1...Int(typeExercise.targetSets) {
                    let set = CDWorkoutSet(context: context)
                    set.id = UUID()
                    set.setNumber = Int32(setNumber)
                    set.targetReps = typeExercise.targetReps
                    set.reps = 0
                    // Get weight for specific set number
                    set.weightKg = getLastWeightForExerciseSet(exercise, setNumber: Int32(setNumber))
                    set.completed = false
                    set.exercise = exercise
                    set.workout = workout
                }
            }
        }
        
        // Update last used date
        workoutType.lastUsed = Date()
        
        do {
            try context.save()
            return workout
        } catch {
            print("Error creating workout from type: \(error)")
            return nil
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentUser() -> CDUser {
        let request: NSFetchRequest<CDUser> = CDUser.fetchRequest()
        request.fetchLimit = 1
        
        do {
            if let user = try context.fetch(request).first {
                return user
            }
        } catch {
            print("Error fetching user: \(error)")
        }
        
        // Create default user if none exists
        let user = CDUser(context: context)
        user.id = UUID()
        user.email = "user@example.com"
        user.createdAt = Date()
        user.updatedAt = Date()
        user.syncStatus = "pending"
        
        try? context.save()
        return user
    }
    
    private func getLastWeightForExercise(_ exercise: CDExercise) -> Double {
        let request: NSFetchRequest<CDWorkoutSet> = CDWorkoutSet.fetchRequest()
        // Only get sets from completed workouts with valid weight
        request.predicate = NSPredicate(format: "exercise == %@ AND weightKg > 0 AND workout.completed == true", exercise)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDWorkoutSet.workout?.date, ascending: false)]
        request.fetchLimit = 1
        
        do {
            let sets = try context.fetch(request)
            if let lastSet = sets.first {
                print("Found last weight for \(exercise.name ?? "Unknown"): \(lastSet.weightKg)kg from workout on \(lastSet.workout?.date ?? Date())")
                return lastSet.weightKg
            } else {
                // Try without completed requirement if no completed workouts found
                let fallbackRequest: NSFetchRequest<CDWorkoutSet> = CDWorkoutSet.fetchRequest()
                fallbackRequest.predicate = NSPredicate(format: "exercise == %@ AND weightKg > 0", exercise)
                fallbackRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CDWorkoutSet.workout?.date, ascending: false)]
                fallbackRequest.fetchLimit = 1
                
                if let lastSet = try context.fetch(fallbackRequest).first {
                    print("Found last weight (from incomplete workout) for \(exercise.name ?? "Unknown"): \(lastSet.weightKg)kg")
                    return lastSet.weightKg
                }
            }
        } catch {
            print("Error fetching last weight for \(exercise.name ?? "Unknown"): \(error)")
        }
        
        print("No previous weight found for \(exercise.name ?? "Unknown"), using default 0")
        return 0
    }
    
    private func getLastWeightForExerciseSet(_ exercise: CDExercise, setNumber: Int32) -> Double {
        let request: NSFetchRequest<CDWorkoutSet> = CDWorkoutSet.fetchRequest()
        // Get the specific set number from the most recent workout
        request.predicate = NSPredicate(format: "exercise == %@ AND setNumber == %d AND weightKg > 0", exercise, setNumber)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDWorkoutSet.workout?.date, ascending: false)]
        request.fetchLimit = 1
        
        do {
            let sets = try context.fetch(request)
            if let lastSet = sets.first {
                print("Found weight for \(exercise.name ?? "Unknown") set \(setNumber): \(lastSet.weightKg)kg")
                return lastSet.weightKg
            } else {
                // If no weight found for this specific set number, try to get the last weight used for any set
                print("No weight found for \(exercise.name ?? "Unknown") set \(setNumber), falling back to last weight")
                return getLastWeightForExercise(exercise)
            }
        } catch {
            print("Error fetching weight for set \(setNumber): \(error)")
        }
        
        return getLastWeightForExercise(exercise)
    }
}