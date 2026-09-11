//
//  PhaseFiveTests.swift
//  EcksteinTests
//
//  Phase 5: the numbers the training screens and the AI coach are built on.
//

import XCTest
import CoreData
@testable import Eckstein

/// Tests for the phase-5 additions.
///
/// The two things worth testing here are the ones that were previously spread
/// across several files with no test under any of them: the volume and
/// estimated-one-rep-max arithmetic, and the exercise library seed. The
/// nutrition cases at the top are the historical-goal rule that phase 4 left
/// asymmetric.
class PhaseFiveTests: XCTestCase {

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
    private func makeExercise(name: String = "Squat") -> CDExercise {
        repository.createExercise(
            name: name,
            muscleGroup: "Legs",
            category: "Legs",
            equipment: "Barbell"
        )
    }

    @discardableResult
    private func addSet(
        to workout: CDWorkout,
        exercise: CDExercise,
        weight: Double,
        reps: Int32,
        number: Int32,
        completed: Bool = true
    ) -> CDWorkoutSet {
        let set = CDWorkoutSet(context: context)
        set.id = UUID()
        set.setNumber = number
        set.weightKg = weight
        set.reps = reps
        set.completed = completed
        set.exercise = exercise
        set.workout = workout
        return set
    }

    // MARK: - Historical nutrition goals (§1)

    /// A row written before the normalisation rule existed holds a stored zero
    /// for a goal the user never set.
    ///
    /// Read straight through, that surfaces as a target of zero, and the Diet
    /// screen then reports every gram eaten as "over by".
    func testHistoricalZeroFatGoalReadsAsUnset() throws {
        let preferences = CDUserPreferences(context: context)
        preferences.id = UUID()
        preferences.dailyFatGoal = 0
        try context.save()

        let goals = try NutritionService(context: context).goals()
        XCTAssertNil(goals.fat, "a stored fat goal of 0 means 'not set', not 'eat no fat'")
    }

    func testHistoricalZeroFiberGoalReadsAsUnset() throws {
        let preferences = CDUserPreferences(context: context)
        preferences.id = UUID()
        preferences.dailyFiberGoal = 0
        try context.save()

        let goals = try NutritionService(context: context).goals()
        XCTAssertNil(goals.fiber)
    }

    func testPositiveFatAndFiberGoalsArePreserved() throws {
        let preferences = CDUserPreferences(context: context)
        preferences.id = UUID()
        preferences.dailyCalorieGoal = 2200
        preferences.dailyFatGoal = 70
        preferences.dailyFiberGoal = 30
        try context.save()

        let goals = try NutritionService(context: context).goals()
        XCTAssertEqual(goals.fat ?? -1, 70, accuracy: 0.0001)
        XCTAssertEqual(goals.fiber ?? -1, 30, accuracy: 0.0001)
        // The Int32 columns follow the same rule, so the two kinds of column
        // cannot answer "is this goal set?" differently.
        XCTAssertEqual(goals.calories ?? -1, 2200, accuracy: 0.0001)

        // A negative goal is nonsense in the same way a zero is, and is treated
        // the same way rather than rendered as a target of -5 g.
        preferences.dailyFatGoal = -5
        try context.save()
        XCTAssertNil(try NutritionService(context: context).goals().fat)
    }

    // MARK: - Volume (§6)

    func testSetVolumeIsWeightTimesReps() {
        XCTAssertEqual(WorkoutMetrics.setVolume(weightKg: 100, reps: 5), 500, accuracy: 0.0001)
        XCTAssertEqual(WorkoutMetrics.setVolume(weightKg: 82.5, reps: 8), 660, accuracy: 0.0001)
    }

    /// A set with no weight or no reps moves nothing, and — the part that
    /// matters — one corrupt row cannot put an infinity or a `nan` into a
    /// workout total, the weekly chart and the AI summary at once.
    func testSetVolumeOfAnUnusableSetIsZero() {
        XCTAssertEqual(WorkoutMetrics.setVolume(weightKg: 0, reps: 10), 0)
        XCTAssertEqual(WorkoutMetrics.setVolume(weightKg: 100, reps: 0), 0)
        XCTAssertEqual(WorkoutMetrics.setVolume(weightKg: 100, reps: -3), 0)
        XCTAssertEqual(WorkoutMetrics.setVolume(weightKg: -20, reps: 5), 0)
        XCTAssertEqual(WorkoutMetrics.setVolume(weightKg: .nan, reps: 5), 0)
        XCTAssertEqual(WorkoutMetrics.setVolume(weightKg: .infinity, reps: 5), 0)
    }

    func testExerciseVolumeSumsItsOwnSetsInOneWorkout() {
        let workout = repository.createWorkout(name: "Legs", date: Date())
        let squat = makeExercise(name: "Squat")
        let press = makeExercise(name: "Leg Press")

        addSet(to: workout, exercise: squat, weight: 100, reps: 5, number: 1)
        addSet(to: workout, exercise: squat, weight: 100, reps: 5, number: 2)
        addSet(to: workout, exercise: press, weight: 200, reps: 10, number: 3)

        XCTAssertEqual(WorkoutMetrics.exerciseVolume(squat, in: workout), 1000, accuracy: 0.0001)
        XCTAssertEqual(WorkoutMetrics.exerciseVolume(press, in: workout), 2000, accuracy: 0.0001)
    }

    func testWorkoutVolumeIsTheSumOfItsExerciseVolumes() {
        let workout = repository.createWorkout(name: "Full body", date: Date())
        let squat = makeExercise(name: "Squat")
        let press = makeExercise(name: "Bench Press")

        addSet(to: workout, exercise: squat, weight: 100, reps: 5, number: 1)
        addSet(to: workout, exercise: squat, weight: 100, reps: 5, number: 2)
        addSet(to: workout, exercise: press, weight: 60, reps: 8, number: 3)

        let byExercise = [squat, press].reduce(0) {
            $0 + WorkoutMetrics.exerciseVolume($1, in: workout)
        }
        XCTAssertEqual(WorkoutMetrics.workoutVolume(workout), byExercise, accuracy: 0.0001)
        XCTAssertEqual(WorkoutMetrics.workoutVolume(workout), 1480, accuracy: 0.0001)

        // The model's own accessor is the same number, not a fourth formula.
        XCTAssertEqual(workout.totalVolume, WorkoutMetrics.workoutVolume(workout), accuracy: 0.0001)
    }

    /// The two questions the app asks about a workout: what was on the screen
    /// (every set) and what the user actually did (completed sets only).
    func testIncompleteSetsAreExcludedFromCompletedVolume() throws {
        let workout = repository.createWorkout(name: "Legs", date: Date())
        let squat = makeExercise(name: "Squat")

        addSet(to: workout, exercise: squat, weight: 100, reps: 5, number: 1)
        addSet(to: workout, exercise: squat, weight: 100, reps: 5, number: 2)
        addSet(to: workout, exercise: squat, weight: 100, reps: 5, number: 3, completed: false)
        try context.save()

        XCTAssertEqual(WorkoutMetrics.workoutVolume(workout), 1500, accuracy: 0.0001)
        XCTAssertEqual(WorkoutMetrics.completedWorkoutVolume(workout), 1000, accuracy: 0.0001)
        XCTAssertEqual(WorkoutMetrics.completedSetCount(workout.setsArray), 2)
    }

    // MARK: - Estimated 1RM (§7)

    func testEstimatedOneRepMaxFollowsEpley() {
        // 100 × (1 + 5/30) = 116.67
        XCTAssertEqual(
            WorkoutMetrics.estimatedOneRepMax(weightKg: 100, reps: 5) ?? -1,
            116.6667,
            accuracy: 0.001
        )
        // 60 × (1 + 10/30) = 80
        XCTAssertEqual(
            WorkoutMetrics.estimatedOneRepMax(weightKg: 60, reps: 10) ?? -1,
            80,
            accuracy: 0.001
        )
    }

    /// A single rep comes back a little above the weight itself — that is what
    /// the formula says, and returning the weight exactly would disagree with
    /// every other Epley implementation.
    func testSingleRepEstimateIsJustAboveTheWeight() {
        let estimate = WorkoutMetrics.estimatedOneRepMax(weightKg: 100, reps: 1)
        XCTAssertNotNil(estimate)
        XCTAssertGreaterThanOrEqual(estimate ?? 0, 100)
        XCTAssertEqual(estimate ?? -1, 103.3333, accuracy: 0.001)
    }

    func testInvalidOneRepMaxInputsReturnNil() {
        XCTAssertNil(WorkoutMetrics.estimatedOneRepMax(weightKg: 0, reps: 5))
        XCTAssertNil(WorkoutMetrics.estimatedOneRepMax(weightKg: -100, reps: 5))
        XCTAssertNil(WorkoutMetrics.estimatedOneRepMax(weightKg: 100, reps: 0))
        XCTAssertNil(WorkoutMetrics.estimatedOneRepMax(weightKg: 100, reps: -1))
        XCTAssertNil(WorkoutMetrics.estimatedOneRepMax(weightKg: .nan, reps: 5))
        XCTAssertNil(WorkoutMetrics.estimatedOneRepMax(weightKg: .infinity, reps: 5))

        // The best-of helper ignores the sets with no estimate rather than
        // letting one of them drag the answer to zero.
        let workout = repository.createWorkout(name: "Mixed", date: Date())
        let squat = makeExercise(name: "Squat")
        addSet(to: workout, exercise: squat, weight: 0, reps: 5, number: 1)
        addSet(to: workout, exercise: squat, weight: 100, reps: 5, number: 2)
        XCTAssertEqual(
            WorkoutMetrics.bestEstimatedOneRepMax(in: workout.setsArray) ?? -1,
            116.6667,
            accuracy: 0.001
        )
    }

    // MARK: - History (§8, §9)

    func testWorkoutHistoryIsNewestFirst() {
        let old = repository.createWorkout(name: "Old", date: Date().addingTimeInterval(-86_400 * 3))
        _ = repository.createWorkout(name: "Newest", date: Date())
        _ = repository.createWorkout(name: "Middle", date: Date().addingTimeInterval(-86_400))

        XCTAssertEqual(repository.workouts.count, 3)
        XCTAssertEqual(repository.workouts.first?.name, "Newest")
        XCTAssertEqual(repository.workouts.last?.name, "Old")
        XCTAssertEqual(repository.workouts.last?.objectID, old.objectID)
    }

    /// Tapping an exercise shows its recent sets, its heaviest set, its best
    /// volume and a per-day trend — all from the sets already in the store.
    func testExerciseHistoryAggregatesAcrossWorkouts() {
        let squat = makeExercise(name: "Squat")
        let bench = makeExercise(name: "Bench Press")

        let older = repository.createWorkout(name: "Week 1", date: Date().addingTimeInterval(-86_400 * 7))
        addSet(to: older, exercise: squat, weight: 100, reps: 5, number: 1)
        addSet(to: older, exercise: squat, weight: 100, reps: 5, number: 2)

        let recent = repository.createWorkout(name: "Week 2", date: Date())
        addSet(to: recent, exercise: squat, weight: 110, reps: 5, number: 1)
        // Another exercise's sets must not leak into this exercise's history.
        addSet(to: recent, exercise: bench, weight: 200, reps: 1, number: 2)

        let viewModel = ExerciseProgressionViewModel(exercise: squat, repository: repository)
        viewModel.loadData()

        XCTAssertEqual(viewModel.recentSets.count, 3, "only the squat's sets belong to the squat")
        XCTAssertEqual(viewModel.recentSets.first?.weightKg ?? 0, 110, accuracy: 0.0001, "most recent first")
        XCTAssertEqual(viewModel.maxWeight, 110, accuracy: 0.0001)
        XCTAssertEqual(viewModel.maxReps, 5)
        XCTAssertEqual(viewModel.maxVolume, 550, accuracy: 0.0001, "110 × 5 is the best single set")

        // Two training days, four metrics each; the older day's volume is the
        // sum of its two sets rather than one set repeated.
        let volumes = viewModel.chartData
            .filter { $0.metric == .volume }
            .sorted { $0.date < $1.date }
        XCTAssertEqual(volumes.count, 2)
        XCTAssertEqual(volumes.first?.value ?? 0, 1000, accuracy: 0.0001)
        XCTAssertEqual(volumes.last?.value ?? 0, 550, accuracy: 0.0001)
    }

    // MARK: - Exercise library seed (§11)

    func testSeedingFillsAnEmptyLibrary() throws {
        XCTAssertTrue(repository.fetchAllExercises().isEmpty)

        let inserted = try ExerciseCatalogSeed.seedIfNeeded(context: context)
        XCTAssertEqual(inserted, ExerciseData.exercises.count)

        let names = Set(repository.fetchAllExercises().compactMap { $0.name })
        for required in [
            "Bench Press", "Incline Bench Press", "Squat", "Deadlift",
            "Overhead Press", "Pull Up", "Lat Pulldown", "Barbell Row",
            "Dumbbell Row", "Biceps Curl", "Triceps Extension", "Leg Press",
            "Leg Curl", "Leg Extension", "Lateral Raise"
        ] {
            XCTAssertTrue(names.contains(required), "missing \(required)")
        }

        // Seeded movements are usable straight away: a new install can pick one
        // and log a set without creating anything first.
        let seeded = try XCTUnwrap(repository.fetchAllExercises().first { $0.name == "Squat" })
        XCTAssertEqual(seeded.muscleGroup, "Legs")
        XCTAssertEqual(seeded.equipment, "Barbell")
        XCTAssertFalse(seeded.isCustom)
    }

    /// The regression the name-based rule exists to prevent: an existing user
    /// whose own exercises are not flagged custom must still get the library.
    func testSeedingIsIdempotentAndNeverDeletes() throws {
        let mine = makeExercise(name: "My Own Movement")
        XCTAssertFalse(mine.isCustom, "createExercise defaults isCustom to false")

        XCTAssertEqual(try ExerciseCatalogSeed.seedIfNeeded(context: context), ExerciseData.exercises.count)
        XCTAssertEqual(try ExerciseCatalogSeed.seedIfNeeded(context: context), 0, "the second launch adds nothing")
        XCTAssertEqual(try context.count(for: CDExercise.fetchRequest()), ExerciseData.exercises.count + 1)
        XCTAssertFalse(mine.isDeleted, "seeding never removes what is already there")
    }

    func testSeedingDoesNotDuplicateAMovementTheUserAlreadyHas() throws {
        let existing = makeExercise(name: "squat")
        _ = try ExerciseCatalogSeed.seedIfNeeded(context: context)

        let squats = repository.fetchAllExercises().filter {
            $0.name?.lowercased() == "squat"
        }
        XCTAssertEqual(squats.count, 1, "matching is case-insensitive")
        XCTAssertEqual(squats.first?.objectID, existing.objectID, "the user's row is kept, not replaced")
    }

    // MARK: - Dashboard (§13)

    /// Today's training status comes from real workout records: today's workout
    /// shows, yesterday's does not, and an empty day is simply empty.
    @MainActor
    func testDashboardShowsOnlyTodaysWorkouts() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date()).addingTimeInterval(60 * 60 * 10)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        repository.createWorkout(name: "Today's Session", date: today)
        repository.createWorkout(name: "Yesterday's Session", date: yesterday)

        let viewModel = DashboardViewModel(
            nutrition: NutritionService(context: context),
            weightRepository: WeightRepository(context: context),
            workoutRepository: repository,
            calendar: calendar
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.todaysWorkouts.count, 1)
        XCTAssertEqual(viewModel.todaysWorkouts.first?.name, "Today's Session")

        // Nowhere to log training is a normal day, not an error.
        repository.delete(viewModel.todaysWorkouts[0])
        await viewModel.load()
        XCTAssertTrue(viewModel.todaysWorkouts.isEmpty)
    }
}
