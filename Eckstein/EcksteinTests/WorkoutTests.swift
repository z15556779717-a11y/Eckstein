//
//  WorkoutTests.swift
//  EcksteinTests
//
//  Created by Eliad Shahar on 13/07/2025.
//

import XCTest
import CoreData
@testable import Eckstein

/// Tests for the workout data model and `WorkoutRepository`.
///
/// NOTE (phase-1 audit): this file previously exercised an API that does not
/// exist in the app sources (`muscleGroups` arrays, `searchExercises`,
/// `filterExercises`, `getWorkoutStats`, `getExerciseProgression`,
/// `getWorkoutTemplates`, `isTemplate`, `duration`, `totalWeightKg`,
/// `uniqueExercisesCount`), so the test target could not compile. It was
/// rewritten against the real `CDWorkout` / `CDWorkoutSet` / `CDExercise`
/// model and the real `WorkoutRepository` surface.
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

    // MARK: - Helpers

    @discardableResult
    private func makeExercise(
        name: String = "Squat",
        muscleGroup: String = "Quadriceps",
        category: String = "Legs"
    ) -> CDExercise {
        repository.createExercise(
            name: name,
            muscleGroup: muscleGroup,
            category: category,
            equipment: "Barbell"
        )
    }

    @discardableResult
    private func addSet(
        to workout: CDWorkout,
        exercise: CDExercise,
        weight: Double,
        reps: Int32,
        number: Int32
    ) -> CDWorkoutSet {
        let set = CDWorkoutSet(context: context)
        set.id = UUID()
        set.setNumber = number
        set.weightKg = weight
        set.reps = reps
        set.exercise = exercise
        set.workout = workout
        return set
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

    func testWorkoutWithExercisesAndSets() {
        let workout = CDWorkout.create(name: "Leg Day", date: Date(), in: context)
        let exercise = makeExercise()

        for i in 1...3 {
            addSet(to: workout, exercise: exercise, weight: 100, reps: 10, number: Int32(i))
        }

        try? context.save()

        XCTAssertEqual(workout.setsArray.count, 3)
        XCTAssertEqual(workout.setsArray.first?.exercise?.name, "Squat")
        // setsArray is sorted by setNumber, so order must be 1, 2, 3.
        XCTAssertEqual(workout.setsArray.map(\.setNumber), [1, 2, 3])
    }

    // MARK: - Volume Tests

    func testTotalVolumeIsSumOfRepsTimesWeight() {
        let workout = CDWorkout.create(name: "Volume", date: Date(), in: context)
        let exercise = makeExercise(name: "Deadlift", muscleGroup: "Back")

        for (index, weight) in [100.0, 110.0, 120.0].enumerated() {
            addSet(to: workout, exercise: exercise, weight: weight, reps: 5, number: Int32(index + 1))
        }

        try? context.save()

        // (100 + 110 + 120) * 5 reps
        XCTAssertEqual(workout.totalVolume, 1650, accuracy: 0.001)
    }

    func testTotalVolumeIsZeroForEmptyWorkout() {
        let workout = CDWorkout.create(name: "Empty", date: Date(), in: context)
        XCTAssertEqual(workout.totalVolume, 0, accuracy: 0.001)
    }

    // MARK: - Completion Tests

    func testCompletionPercentage() {
        let workout = CDWorkout.create(name: "Partial", date: Date(), in: context)
        let exercise = makeExercise()

        let first = addSet(to: workout, exercise: exercise, weight: 100, reps: 10, number: 1)
        addSet(to: workout, exercise: exercise, weight: 100, reps: 10, number: 2)

        // Only the first set is marked complete.
        first.completed = true
        try? context.save()

        XCTAssertEqual(workout.completionPercentage, 50, accuracy: 0.001)
        XCTAssertFalse(workout.isCompleted)

        // Marking both complete should cross the 90% threshold.
        workout.setsArray.forEach { $0.completed = true }
        XCTAssertTrue(workout.isCompleted)
    }

    func testCompletionPercentageIsZeroWhenNoSets() {
        let workout = CDWorkout.create(name: "Empty", date: Date(), in: context)
        XCTAssertEqual(workout.completionPercentage, 0, accuracy: 0.001)
        XCTAssertFalse(workout.isCompleted)
    }

    // MARK: - Exercise Management Tests

    func testExerciseCreation() {
        let exercise = repository.createExercise(
            name: "Bench Press",
            muscleGroup: "Chest",
            category: "Chest",
            equipment: "Barbell"
        )

        XCTAssertNotNil(exercise.id)
        XCTAssertEqual(exercise.name, "Bench Press")
        XCTAssertEqual(exercise.category, "Chest")
        XCTAssertEqual(exercise.muscleGroup, "Chest")
        XCTAssertFalse(exercise.isCustom)
    }

    func testFetchAllExercisesIsSortedByName() {
        makeExercise(name: "Squat", muscleGroup: "Quadriceps")
        makeExercise(name: "Bench Press", muscleGroup: "Chest")
        makeExercise(name: "Deadlift", muscleGroup: "Back")

        let names = repository.fetchAllExercises().compactMap(\.name)
        XCTAssertEqual(names, ["Bench Press", "Deadlift", "Squat"])
    }

    func testFetchRecentExercisesRespectsLimit() {
        makeExercise(name: "A", muscleGroup: "Chest")
        makeExercise(name: "B", muscleGroup: "Back")
        makeExercise(name: "C", muscleGroup: "Legs")

        XCTAssertEqual(repository.fetchRecentExercises(limit: 2).count, 2)
    }

    func testDeleteExercise() {
        let exercise = makeExercise(name: "ToDelete")
        XCTAssertEqual(repository.fetchAllExercises().count, 1)

        repository.deleteExercise(exercise)
        XCTAssertEqual(repository.fetchAllExercises().count, 0)
    }

    // MARK: - Repository Workout Tests

    func testRepositoryCreateWorkoutPersistsAndPublishes() {
        let workout = repository.createWorkout(name: "Persisted", date: Date())

        XCTAssertTrue(repository.workouts.contains { $0.objectID == workout.objectID })

        let request: NSFetchRequest<CDWorkout> = CDWorkout.fetchRequest()
        let fetched = (try? context.fetch(request)) ?? []
        XCTAssertEqual(fetched.count, 1)
    }

    func testDeleteWorkout() {
        let workout = repository.createWorkout(name: "ToDelete", date: Date())
        repository.delete(workout)

        let request: NSFetchRequest<CDWorkout> = CDWorkout.fetchRequest()
        let fetched = (try? context.fetch(request)) ?? []
        XCTAssertTrue(fetched.isEmpty)
    }

    // MARK: - Cascade / Relationship Tests

    func testDeletingWorkoutCascadesToSets() {
        let workout = CDWorkout.create(name: "Cascade", date: Date(), in: context)
        let exercise = makeExercise()
        addSet(to: workout, exercise: exercise, weight: 50, reps: 10, number: 1)
        try? context.save()

        XCTAssertEqual(workout.setsArray.count, 1)

        context.delete(workout)
        try? context.save()

        let request: NSFetchRequest<CDWorkoutSet> = CDWorkoutSet.fetchRequest()
        let sets = (try? context.fetch(request)) ?? []
        // The model declares the workout -> sets relationship as Cascade.
        XCTAssertTrue(sets.isEmpty, "Deleting a workout should cascade to its sets")
    }

    // MARK: - Data Validation Tests

    func testInvalidSetValuesAreStoredVerbatim() {
        // The model does not currently validate weight/reps; callers are
        // responsible. This pins the current contract so a future change to add
        // validation is a conscious one.
        let set = CDWorkoutSet(context: context)
        set.weightKg = -50
        set.reps = -5

        XCTAssertLessThan(set.weightKg, 0)
        XCTAssertLessThan(set.reps, 0)
    }

    func testWorkoutCreatedWithEmptyNameIsAllowed() {
        let workout = CDWorkout.create(name: "", date: Date(), in: context)
        XCTAssertTrue(workout.name?.isEmpty ?? true)
    }
}
