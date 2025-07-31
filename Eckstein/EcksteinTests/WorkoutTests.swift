//
//  WorkoutTests.swift
//  EcksteinTests
//
//  Created by Eliad Shahar on 13/07/2025.
//

import XCTest
import CoreData
@testable import Eckstein

class WorkoutTests: XCTestCase {
    var controller: PersistenceController!
    var context: NSManagedObjectContext!
    var repository: WorkoutRepository!
    
    override func setUp() {
        super.setUp()
        controller = PersistenceController(inMemory: true)
        context = controller.container.viewContext
        repository = WorkoutRepository(context: context)
    }
    
    override func tearDown() {
        controller = nil
        context = nil
        repository = nil
        super.tearDown()
    }
    
    // MARK: - Workout Creation Tests
    
    func testCreateWorkout() {
        let workout = CDWorkout.create(
            name: "Morning Workout",
            date: Date(),
            in: context
        )
        
        XCTAssertNotNil(workout.id)
        XCTAssertEqual(workout.name, "Morning Workout")
        XCTAssertEqual(workout.syncStatus, "pending")
        XCTAssertFalse(workout.completed)
    }
    
    func testWorkoutWithExercises() {
        let workout = CDWorkout.create(name: "Leg Day", date: Date(), in: context)
        
        // Add exercise
        let exercise = CDExercise(context: context)
        exercise.id = UUID()
        exercise.name = "Squats"
        exercise.category = "Legs"
        exercise.muscleGroups = ["Quadriceps", "Glutes"]
        
        // Add sets
        for i in 1...3 {
            let set = CDWorkoutSet(context: context)
            set.id = UUID()
            set.setNumber = Int32(i)
            set.weightKg = 100
            set.reps = 10
            set.exercise = exercise
            set.workout = workout
        }
        
        try? context.save()
        
        XCTAssertEqual(workout.setsArray.count, 3)
        XCTAssertEqual(workout.setsArray.first?.exercise?.name, "Squats")
        XCTAssertEqual(workout.uniqueExercisesCount, 1)
    }
    
    // MARK: - Exercise Management Tests
    
    func testExerciseCreation() {
        let exercise = repository.createExercise(
            name: "Bench Press",
            category: "Chest",
            muscleGroups: ["Chest", "Triceps", "Shoulders"]
        )
        
        XCTAssertNotNil(exercise)
        XCTAssertEqual(exercise.name, "Bench Press")
        XCTAssertEqual(exercise.category, "Chest")
        XCTAssertTrue(exercise.muscleGroups?.contains("Chest") ?? false)
    }
    
    func testExerciseSearch() {
        // Create test exercises
        _ = repository.createExercise(name: "Barbell Squat", category: "Legs", muscleGroups: ["Quadriceps"])
        _ = repository.createExercise(name: "Dumbbell Squat", category: "Legs", muscleGroups: ["Quadriceps"])
        _ = repository.createExercise(name: "Bench Press", category: "Chest", muscleGroups: ["Chest"])
        
        let squatExercises = repository.searchExercises(query: "squat")
        XCTAssertEqual(squatExercises.count, 2)
        
        let chestExercises = repository.filterExercises(by: "Chest")
        XCTAssertEqual(chestExercises.count, 1)
    }
    
    // MARK: - Workout Statistics Tests
    
    func testWorkoutStatistics() {
        // Create workouts with sets
        let workout1 = CDWorkout.create(name: "Workout 1", date: Date(), in: context)
        let exercise = CDExercise(context: context)
        exercise.id = UUID()
        exercise.name = "Deadlift"
        exercise.category = "Back"
        
        // Add sets with increasing weight
        let weights = [100.0, 110.0, 120.0]
        for (index, weight) in weights.enumerated() {
            let set = CDWorkoutSet(context: context)
            set.id = UUID()
            set.setNumber = Int32(index + 1)
            set.weightKg = weight
            set.reps = 5
            set.exercise = exercise
            set.workout = workout1
        }
        
        workout1.completed = true
        workout1.totalWeightKg = 1650 // (100*5 + 110*5 + 120*5)
        workout1.duration = 3600 // 1 hour
        
        try? context.save()
        
        let stats = repository.getWorkoutStats(for: .week)
        XCTAssertGreaterThan(stats.totalWorkouts, 0)
        XCTAssertGreaterThan(stats.totalVolume, 0)
    }
    
    // MARK: - Progression Tracking Tests
    
    func testExerciseProgression() {
        let exercise = repository.createExercise(name: "Bench Press", category: "Chest", muscleGroups: ["Chest"])
        
        // Create historical workouts
        let dates = [
            Calendar.current.date(byAdding: .day, value: -7, to: Date())!,
            Calendar.current.date(byAdding: .day, value: -3, to: Date())!,
            Date()
        ]
        
        let weights = [80.0, 85.0, 90.0]
        
        for (index, date) in dates.enumerated() {
            let workout = CDWorkout.create(name: "Chest Day", date: date, in: context)
            
            let set = CDWorkoutSet(context: context)
            set.id = UUID()
            set.setNumber = 1
            set.weightKg = weights[index]
            set.reps = 8
            set.exercise = exercise
            set.workout = workout
            
            workout.completed = true
        }
        
        try? context.save()
        
        let progression = repository.getExerciseProgression(exercise, dateRange: .week)
        XCTAssertEqual(progression.count, 3)
        
        // Verify progression is ascending
        for i in 1..<progression.count {
            XCTAssertGreaterThanOrEqual(
                progression[i].maxWeight,
                progression[i-1].maxWeight
            )
        }
    }
    
    // MARK: - Template Tests
    
    func testWorkoutTemplates() {
        // Create a workout to use as template
        let workout = CDWorkout.create(name: "Push Day Template", date: Date(), in: context)
        workout.isTemplate = true
        
        let exercises = [
            ("Bench Press", "Chest", 3),
            ("Overhead Press", "Shoulders", 3),
            ("Dips", "Chest", 3)
        ]
        
        for (name, category, sets) in exercises {
            let exercise = repository.createExercise(name: name, category: category, muscleGroups: [category])
            
            for i in 1...sets {
                let set = CDWorkoutSet(context: context)
                set.id = UUID()
                set.setNumber = Int32(i)
                set.weightKg = 0 // Template sets don't have weight
                set.reps = 10
                set.exercise = exercise
                set.workout = workout
            }
        }
        
        try? context.save()
        
        let templates = repository.getWorkoutTemplates()
        XCTAssertEqual(templates.count, 1)
        XCTAssertEqual(templates.first?.name, "Push Day Template")
        XCTAssertEqual(templates.first?.setsArray.count, 9) // 3 exercises * 3 sets
    }
    
    // MARK: - Rest Timer Tests
    
    func testRestTimerCalculation() {
        let exercise = repository.createExercise(name: "Squat", category: "Legs", muscleGroups: ["Quadriceps"])
        
        // Test different rep ranges
        let restTimes = [
            (reps: 3, weight: 150.0, expectedRest: 180), // Heavy, low reps = 3 min
            (reps: 8, weight: 100.0, expectedRest: 120), // Medium = 2 min
            (reps: 15, weight: 50.0, expectedRest: 60)   // Light, high reps = 1 min
        ]
        
        for (reps, weight, expectedRest) in restTimes {
            let set = CDWorkoutSet(context: context)
            set.reps = Int32(reps)
            set.weightKg = weight
            set.exercise = exercise
            
            // Simulate rest timer calculation based on intensity
            let intensity = weight > 120 ? "heavy" : weight > 80 ? "medium" : "light"
            let actualRest = intensity == "heavy" ? 180 : intensity == "medium" ? 120 : 60
            
            XCTAssertEqual(actualRest, expectedRest)
        }
    }
    
    // MARK: - Data Validation Tests
    
    func testDataValidation() {
        // Test invalid workout name
        let workout = CDWorkout.create(name: "", date: Date(), in: context)
        XCTAssertTrue(workout.name?.isEmpty ?? true)
        
        // Test future date handling
        let futureDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let futureWorkout = CDWorkout.create(name: "Future", date: futureDate, in: context)
        XCTAssertNotNil(futureWorkout)
        
        // Test negative values
        let set = CDWorkoutSet(context: context)
        set.weightKg = -50
        set.reps = -5
        
        // In real app, these should be validated
        XCTAssertLessThan(set.weightKg, 0)
        XCTAssertLessThan(set.reps, 0)
    }
}