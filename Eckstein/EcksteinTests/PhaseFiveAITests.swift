//
//  PhaseFiveAITests.swift
//  EcksteinTests
//
//  Phase 5: what the AI coach is told, and what it says when it cannot answer.
//

import XCTest
import CoreData
@testable import Eckstein

/// Tests for the AI coach's context and its failure states.
///
/// The context is the part with a privacy contract attached, so it is tested for
/// what it *excludes* as much as for the numbers it carries.
@MainActor
class PhaseFiveAITests: XCTestCase {

    var controller: PersistenceController!
    var context: NSManagedObjectContext!
    var workoutRepository: WorkoutRepository!
    var weightRepository: WeightRepository!
    var nutritionService: NutritionService!
    var builder: AICoachContextBuilder!

    /// A fixed instant, so "this week" and "days ago" mean something stable.
    let now = Date(timeIntervalSince1970: 1_760_000_000)

    override func setUp() {
        super.setUp()
        controller = PersistenceController(inMemory: true)
        context = controller.container.viewContext
        workoutRepository = WorkoutRepository(context: context)
        weightRepository = WeightRepository(context: context)
        nutritionService = NutritionService(context: context)
        builder = AICoachContextBuilder(
            workoutRepository: workoutRepository,
            weightRepository: weightRepository,
            nutritionService: nutritionService,
            calendar: .current,
            now: { [fixedNow = now] in fixedNow }
        )
    }

    override func tearDown() {
        builder = nil
        nutritionService = nil
        weightRepository = nil
        workoutRepository = nil
        context = nil
        controller = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: now) ?? now
    }

    @discardableResult
    private func logChicken(grams: Double, on date: Date) throws -> CDEcksteinMealEntry {
        let food = CDEcksteinFood(context: context)
        food.id = UUID()
        food.name = "Chicken"
        food.category = ""
        food.caloriesPer100g = NSNumber(value: 165)
        food.proteinPer100g = NSNumber(value: 31)
        food.carbsPer100g = NSNumber(value: 0)
        food.fatPer100g = NSNumber(value: 3.6)
        food.fiberPer100g = NSNumber(value: 0)
        try context.save()

        return try nutritionService.logEntry(
            foodName: "Chicken",
            category: "",
            grams: grams,
            date: date,
            food: food
        )
    }

    @discardableResult
    private func logWorkout(
        name: String,
        on date: Date,
        weight: Double,
        reps: Int32,
        sets: Int
    ) -> CDWorkout {
        let workout = workoutRepository.createWorkout(name: name, date: date)
        let exercise = workoutRepository.createExercise(
            name: "Squat", muscleGroup: "Legs", category: "Legs", equipment: "Barbell"
        )
        for number in 1...sets {
            let set = CDWorkoutSet(context: context)
            set.id = UUID()
            set.setNumber = Int32(number)
            set.weightKg = weight
            set.reps = reps
            set.completed = true
            set.exercise = exercise
            set.workout = workout
        }
        workout.durationMinutes = 45
        try? context.save()
        return workout
    }

    @discardableResult
    private func logWeight(_ kilograms: Double, on date: Date) -> CDWeightEntry {
        let entry = CDWeightEntry(context: context)
        entry.id = UUID()
        entry.date = date
        entry.weightKg = kilograms
        try? context.save()
        return entry
    }

    // MARK: - Nutrition window

    func testNutritionAverageCoversOnlyTheDaysThatWereLogged() async throws {
        try logChicken(grams: 200, on: day(-1))
        try logChicken(grams: 200, on: day(-3))

        let window = await builder.buildContext().nutrition

        XCTAssertEqual(window.daysCovered, 7, "the span asked for")
        XCTAssertEqual(window.daysLogged, 2, "two days have food in them; five do not")
        XCTAssertEqual(window.averageCalories, 330, "165 kcal per 100 g, 200 g")
        XCTAssertEqual(window.averageProteinGrams, 62)
        XCTAssertEqual(window.averageFatGrams, 7)
        XCTAssertTrue(window.hasData)

        // An empty week is not a week of fasting.
        let emptyController = PersistenceController(inMemory: true)
        let emptyBuilder = AICoachContextBuilder(
            workoutRepository: WorkoutRepository(context: emptyController.container.viewContext),
            weightRepository: WeightRepository(context: emptyController.container.viewContext),
            nutritionService: NutritionService(context: emptyController.container.viewContext),
            calendar: .current,
            now: { [fixedNow = now] in fixedNow }
        )
        let empty = await emptyBuilder.buildContext().nutrition
        XCTAssertFalse(empty.hasData)
        XCTAssertEqual(empty.averageCalories, 0)
        XCTAssertEqual(empty.daysLogged, 0)
    }

    // MARK: - Training window

    func testWorkoutSummaryCountsThisWeekAndSumsVolume() async throws {
        logWorkout(name: "Legs", on: day(-1), weight: 100, reps: 5, sets: 3)
        logWorkout(name: "Push", on: day(-3), weight: 60, reps: 8, sets: 3)
        // Outside the seven-day window: written, and deliberately not counted.
        logWorkout(name: "Old", on: day(-20), weight: 100, reps: 5, sets: 3)

        let window = await builder.buildContext().workout

        XCTAssertEqual(window.sessionsThisWeek, 2)
        XCTAssertEqual(window.volumeThisWeekKg, 2940, accuracy: 0.0001, "3×500 plus 3×480")
        XCTAssertEqual(window.recentSessions.count, 2)
        XCTAssertEqual(window.recentSessions.first?.name, "Legs", "most recent first")
        XCTAssertEqual(window.recentSessions.first?.daysAgo, 1)
        XCTAssertEqual(window.recentSessions.first?.completedSets, 3)
        XCTAssertEqual(window.recentSessions.first?.durationMinutes, 45)
    }

    func testExerciseProgressReportsTheBestEstimatePerMovement() async throws {
        logWorkout(name: "Legs", on: day(-2), weight: 100, reps: 5, sets: 2)
        logWorkout(name: "Legs", on: day(-9), weight: 110, reps: 3, sets: 1)

        let progress = await builder.buildContext().workout.exerciseProgress

        let squat = try XCTUnwrap(progress.first)
        XCTAssertEqual(squat.name, "Squat")
        XCTAssertEqual(squat.bestWeightKg, 110, accuracy: 0.0001)
        // 110 × (1 + 3/30) = 121 beats 100 × (1 + 5/30) = 116.67
        XCTAssertEqual(squat.bestEstimatedOneRepMaxKg, 121, accuracy: 0.01)
        XCTAssertEqual(squat.daysAgo, 2, "the most recent session, not the best one")
        XCTAssertEqual(progress.count, 1, "one entry per movement, not one per set")
    }

    // MARK: - Weight window

    func testWeightSummaryCarriesCurrentTargetAndChange() async throws {
        logWeight(80, on: day(-20))
        logWeight(78, on: day(-1))

        // Written through the setter rather than assigned to the property. The
        // goal lives in `UserDefaults`, and building the context calls
        // `weightRepository.refresh()`, which reloads the property from there —
        // so a direct assignment is undone before anything reads it.
        let previousGoal = UserDefaults.standard.object(forKey: "goalWeight") as? Double
        weightRepository.setGoalWeight(74)
        defer {
            if let previousGoal {
                weightRepository.setGoalWeight(previousGoal)
            } else {
                UserDefaults.standard.removeObject(forKey: "goalWeight")
                weightRepository.goalWeight = nil
            }
        }

        let window = await builder.buildContext().weight

        XCTAssertEqual(window.currentKg ?? 0, 78, accuracy: 0.0001, "the newest weigh-in")
        XCTAssertEqual(window.targetKg ?? 0, 74, accuracy: 0.0001)
        XCTAssertEqual(window.changeOverMonthKg ?? 0, -2, accuracy: 0.0001)
    }

    func testWeightChangeIsNilWithASingleReading() async throws {
        logWeight(80, on: day(-1))

        let window = await builder.buildContext().weight

        XCTAssertEqual(window.currentKg ?? 0, 80, accuracy: 0.0001)
        XCTAssertNil(window.changeOverMonthKg, "a change measured from one point is not a change")
    }

    // MARK: - What is never sent

    /// The privacy contract, asserted rather than asserted-about.
    ///
    /// Everything the coach can be handed is rendered to text here, and the test
    /// looks for the things that must not be in it: the store's own identifiers,
    /// managed-object descriptions, file paths, and the account's email.
    func testContextAndPromptCarryNoInternalIdentifiers() async throws {
        try logChicken(grams: 200, on: day(-1))
        let workout = logWorkout(name: "Legs", on: day(-2), weight: 100, reps: 5, sets: 2)
        let entry = logWeight(80, on: day(-1))
        let exercise = try XCTUnwrap(workout.setsArray.first?.exercise)

        let context = await builder.buildContext()
        let prompt = OpenAIService.systemPrompt(for: context)
        let everything = [
            prompt,
            context.currentStats,
            context.recentActivitySummary,
            context.fitnessGoal,
            String(describing: context)
        ].joined(separator: "\n")

        for identifier in [
            workout.id?.uuidString,
            exercise.id?.uuidString,
            entry.id?.uuidString,
            workout.objectID.uriRepresentation().absoluteString
        ].compactMap({ $0 }) {
            XCTAssertFalse(everything.contains(identifier), "leaked an internal identifier: \(identifier)")
        }

        for forbidden in ["CDWorkout", "CDWeightEntry", "NSManagedObject", "objectID", "file://", "/Users/", "@"] {
            XCTAssertFalse(
                everything.contains(forbidden),
                "the prompt carries \(forbidden), which is the app's internals or the user's account"
            )
        }
    }

    // MARK: - Prompt shape

    func testSystemPromptCarriesTheGoalAndTheNumbers() async throws {
        try logChicken(grams: 200, on: day(-1))
        logWorkout(name: "Legs", on: day(-1), weight: 100, reps: 5, sets: 2)
        logWeight(80, on: day(-1))

        let previousGoal = FitnessGoal.stored
        FitnessGoal.store(.buildMuscle)
        defer { FitnessGoal.store(previousGoal) }

        let context = await builder.buildContext()
        let prompt = OpenAIService.systemPrompt(for: context)

        XCTAssertEqual(context.fitnessGoal, FitnessGoal.buildMuscle.titleKey.localized)
        XCTAssertTrue(prompt.contains("1 workout"), "the training summary")
        XCTAssertTrue(prompt.contains("1000 kg total volume"))
        XCTAssertTrue(prompt.contains("80.0 kg"), "the current weight")
        // The safety rules travel with every request, not just the first.
        XCTAssertTrue(prompt.contains("needs a doctor"))
        XCTAssertTrue(prompt.contains("You advise only"))
    }

    func testThePromptIsShortEnoughToSendOnEveryTurn() async throws {
        try logChicken(grams: 200, on: day(-1))
        logWorkout(name: "Legs", on: day(-1), weight: 100, reps: 5, sets: 3)
        logWeight(80, on: day(-1))

        let prompt = OpenAIService.systemPrompt(for: await builder.buildContext())

        // Roughly 4 characters to a token, so this is about 500 tokens with the
        // whole system prompt and the user's stats — small enough to send on
        // every turn rather than caching a summary of the history.
        XCTAssertLessThan(prompt.count, 2000, "the prompt has grown into a history dump")
    }

    // MARK: - Conversation window

    func testOnlyTheMostRecentTurnsAreReplayed() {
        let viewModel = AICoachViewModel(persistenceController: controller)

        for index in 0..<30 {
            viewModel.updateConversationHistory(userMessage: "u\(index)", aiResponse: "a\(index)")
        }

        let built = viewModel.buildConversationMessages(apiMessages: [
            OpenAIMessage(role: "system", content: "system"),
            OpenAIMessage(role: "user", content: "now")
        ])

        // One system message, twenty history messages, one new turn.
        XCTAssertEqual(built.count, 22)
        XCTAssertEqual(built.first?.role, "system")
        XCTAssertEqual(built.last?.content, "now")
        XCTAssertEqual(built[1].content, "u20", "the oldest five exchanges were dropped")
    }

    // MARK: - Failure states

    func testEveryErrorExplainsItselfWithoutLeakingTheTransport() {
        let cases: [OpenAIError] = [
            .notSignedIn,
            .offline,
            .timedOut,
            .backendUnavailable,
            .rateLimited,
            .invalidResponse,
            .noContent,
            .apiError("HTTP 500: upstream connect error")
        ]

        for error in cases {
            let message = error.userMessage
            XCTAssertFalse(message.isEmpty)
            XCTAssertFalse(message.contains("_"), "that is a raw key, not a sentence: \(message)")
            XCTAssertFalse(message.lowercased().contains("http"))
            XCTAssertFalse(message.contains("Error:"))
            XCTAssertFalse(message.contains("500"))
        }

        // The cases a user can act on differently read differently.
        XCTAssertNotEqual(OpenAIError.rateLimited.userMessage, OpenAIError.offline.userMessage)
        XCTAssertNotEqual(OpenAIError.notSignedIn.userMessage, OpenAIError.backendUnavailable.userMessage)
    }

    /// A failure the user cannot do anything about still leaves them a sentence,
    /// not a stack trace.
    func testAnUnrecognisedFailureIsAnsweredGenerically() {
        // What a raw transport error looks like if one ever escapes the service.
        let transport = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorCannotConnectToHost,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "Could not connect to the server. https://xyz.supabase.co/functions/v1/ai-coach (Error 502)"
            ]
        )

        let message = AICoachViewModel.failureMessage(for: transport)

        XCTAssertEqual(message, OpenAIError.backendUnavailable.userMessage)
        XCTAssertFalse(message.contains("_"))
        XCTAssertFalse(message.lowercased().contains("http"))
        XCTAssertFalse(message.contains("502"))
        XCTAssertFalse(message.contains("supabase"))

        // Our own errors keep their own sentence, so the cases a user can act on
        // differently do not all collapse into one.
        XCTAssertEqual(AICoachViewModel.failureMessage(for: OpenAIError.rateLimited), OpenAIError.rateLimited.userMessage)
    }

    // MARK: - Read-only

    /// The coach reads; it never writes.
    ///
    /// Building the context is the only thing the app does with the user's data
    /// on the coach's behalf, so this asserts that path leaves the store exactly
    /// as it found it — no new rows, no pending changes. The prompt tells the
    /// model it cannot change anything; this is the part the code enforces.
    func testBuildingTheContextDoesNotTouchTheStore() async throws {
        try logChicken(grams: 200, on: day(-1))
        logWorkout(name: "Legs", on: day(-1), weight: 100, reps: 5, sets: 3)
        logWeight(80, on: day(-1))

        XCTAssertFalse(context.hasChanges, "the fixtures left nothing pending")

        let before = try counts()

        _ = await builder.buildContext()
        _ = await builder.buildContext()

        XCTAssertEqual(try counts(), before)
        XCTAssertFalse(context.hasChanges, "building the context wrote to the store")
    }

    private func counts() throws -> [Int] {
        try [
            context.fetch(CDWorkout.fetchRequest()).count,
            context.fetch(CDWorkoutSet.fetchRequest()).count,
            context.fetch(CDExercise.fetchRequest()).count,
            context.fetch(CDWeightEntry.fetchRequest()).count,
            context.fetch(CDEcksteinMealEntry.fetchRequest()).count
        ]
    }

    // MARK: - Duplicate submission

    func testASecondSendWhileWaitingIsIgnored() {
        let viewModel = AICoachViewModel(persistenceController: controller)
        let before = viewModel.messages.count

        viewModel.isLoading = true
        viewModel.sendMessage("First")
        viewModel.sendMessage("Second")

        XCTAssertEqual(
            viewModel.messages.count,
            before,
            "neither message was sent while the first request was still in flight"
        )
    }
}
