//
//  WorkoutRepository.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//
//

import CoreData
import Combine

class WorkoutRepository: ObservableObject {
    let context: NSManagedObjectContext
    @Published var workouts: [CDWorkout] = []
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        fetchWorkouts()
    }
    
    func fetchWorkouts() {
        let request: NSFetchRequest<CDWorkout> = CDWorkout.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDWorkout.date, ascending: false)]
        
        do {
            workouts = try context.fetch(request)
        } catch {
            print("Error fetching workouts: \(error)")
        }
    }
    
    func createWorkout(name: String, date: Date) -> CDWorkout {
        let workout = CDWorkout.create(name: name, date: date, in: context)
        save()
        fetchWorkouts()
        return workout
    }
    
    func addSet(to workout: CDWorkout, exercise: CDExercise, weight: Double, reps: Int32) {
        let set = CDWorkoutSet(context: context)
        set.id = UUID()
        set.setNumber = Int32(workout.setsArray.count + 1)
        set.weightKg = weight
        set.reps = reps
        set.exercise = exercise
        set.workout = workout
        save()
    }
    
    func delete(_ workout: CDWorkout) {
        context.delete(workout)
        save()
        fetchWorkouts()
    }
    
    func createExercise(name: String, muscleGroup: String, category: String, equipment: String, isCustom: Bool = false, notes: String? = nil) -> CDExercise {
        let exercise = CDExercise(context: context)
        exercise.id = UUID()
        exercise.name = name
        exercise.muscleGroup = muscleGroup
        exercise.category = category
        exercise.equipment = equipment
        exercise.isCustom = isCustom
        exercise.createdAt = Date()
        // Notes can be added later if needed
        save()
        return exercise
    }
    
    func deleteExercise(_ exercise: CDExercise) {
        context.delete(exercise)
        save()
    }
    
    func save() {
        do {
            try context.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
    
    /// Brings the exercise library up to date with the app's built-in
    /// movements.
    ///
    /// Safe to call on every launch: it adds only what is missing and returns
    /// `0` once the library is complete. See `ExerciseCatalogSeed`.
    func seedExercisesIfNeeded() {
        do {
            try ExerciseCatalogSeed.seedIfNeeded(context: context)
        } catch {
            print("Error seeding exercises: \(error)")
        }
    }

    func fetchAllExercises() -> [CDExercise] {
        let request: NSFetchRequest<CDExercise> = CDExercise.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDExercise.name, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching exercises: \(error)")
            return []
        }
    }
    
    func fetchRecentExercises(limit: Int) -> [CDExercise] {
        // Fetch exercises that have been used in recent workouts
        let workoutRequest: NSFetchRequest<CDWorkoutSet> = CDWorkoutSet.fetchRequest()
        workoutRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CDWorkoutSet.workout?.date, ascending: false)]
        workoutRequest.predicate = NSPredicate(format: "exercise != nil")
        
        do {
            let recentSets = try context.fetch(workoutRequest)
            var uniqueExercises: [CDExercise] = []
            var addedExerciseIDs: Set<UUID> = []
            
            for set in recentSets {
                if let exercise = set.exercise, 
                   let exerciseID = exercise.id,
                   !addedExerciseIDs.contains(exerciseID) {
                    uniqueExercises.append(exercise)
                    addedExerciseIDs.insert(exerciseID)
                    
                    if uniqueExercises.count >= limit {
                        break
                    }
                }
            }
            
            return uniqueExercises
        } catch {
            print("Error fetching recent exercises: \(error)")
            return []
        }
    }
}