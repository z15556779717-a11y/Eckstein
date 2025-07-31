//
//  CoreDataTests.swift
//  EcksteinTests
//
//  Created by Eliad Shahar on 13/07/2025.
//
//

import XCTest
import CoreData
@testable import Eckstein

class CoreDataTests: XCTestCase {
    var controller: PersistenceController!
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        controller = PersistenceController(inMemory: true)
        context = controller.container.viewContext
    }
    
    func testCreateWorkout() {
        let workout = CDWorkout.create(
            name: "Test Workout",
            date: Date(),
            in: context
        )
        
        XCTAssertNotNil(workout.id)
        XCTAssertEqual(workout.name, "Test Workout")
        XCTAssertEqual(workout.syncStatus, "pending")
        XCTAssertFalse(workout.completed)
    }
    
    func testWorkoutSetRelationship() {
        let workout = CDWorkout.create(name: "Test", date: Date(), in: context)
        let exercise = CDExercise(context: context)
        exercise.id = UUID()
        exercise.name = "Squat"
        exercise.category = "Legs"
        
        let set = CDWorkoutSet(context: context)
        set.id = UUID()
        set.setNumber = 1
        set.weightKg = 100
        set.reps = 5
        set.exercise = exercise
        set.workout = workout
        
        try? context.save()
        
        XCTAssertEqual(workout.setsArray.count, 1)
        XCTAssertEqual(workout.setsArray.first?.exercise?.name, "Squat")
    }
    
    func testCascadeDelete() {
        let workout = CDWorkout.create(name: "Test", date: Date(), in: context)
        
        // Add 3 sets
        for i in 1...3 {
            let set = CDWorkoutSet(context: context)
            set.id = UUID()
            set.setNumber = Int32(i)
            set.workout = workout
        }
        
        try? context.save()
        XCTAssertEqual(workout.setsArray.count, 3)
        
        // Delete workout
        context.delete(workout)
        try? context.save()
        
        // Verify sets are deleted
        let setRequest: NSFetchRequest<CDWorkoutSet> = CDWorkoutSet.fetchRequest()
        let remainingSets = try? context.fetch(setRequest)
        XCTAssertEqual(remainingSets?.count, 0)
    }
}