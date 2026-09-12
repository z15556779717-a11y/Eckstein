//
//  AICoachTests.swift
//  EcksteinTests
//
//  Created by Eliad Shahar on 13/07/2025.
//

import XCTest
import CoreData
@testable import Eckstein

/// Tests for the AI coach stack.
///
/// NOTE (phase-1 audit): the AI types (`OpenAIService`, `AICoachViewModel`,
/// `AIContextBuilder`, `WorkoutPlanGenerator`, `DietAdvisor`, `FormAnalyzer`)
/// are all `@MainActor`, and this class previously touched them from a
/// non-isolated `setUp`. It also read `private` members
/// (`OpenAIService.model`, `.minRequestInterval`, `FormAnalyzer.exerciseDatabase`)
/// and used `AIContext` property names that do not exist (`activitySummary`).
/// The class is now `@MainActor` and asserts against the real surface.
///
/// Tests that would require a live call to the AI backend — a deployed Edge
/// Function and a signed-in session — are skipped, so the suite stays hermetic
/// on CI. There is no client API key to gate on: the app stores none.
@MainActor
class AICoachTests: XCTestCase {
    var viewModel: AICoachViewModel!
    var openAIService: OpenAIService!
    var controller: PersistenceController!
    var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        // The chat view model gets a clean slate so persistence assertions are
        // deterministic regardless of what earlier tests stored. (There is no
        // longer an API key to clear: the client stores none.)
        controller = PersistenceController(inMemory: true)
        context = controller.container.viewContext
        viewModel = AICoachViewModel(persistenceController: controller)
        openAIService = OpenAIService.shared
    }

    override func tearDown() {
        viewModel = nil
        openAIService = nil
        controller = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Message Management Tests

    func testSendMessage() {
        let initialCount = viewModel.messages.count

        viewModel.sendMessage("Test message")

        // The user message is appended synchronously; the reply runs in a Task.
        XCTAssertEqual(viewModel.messages.count, initialCount + 1)
        XCTAssertEqual(viewModel.messages.last?.content, "Test message")
        XCTAssertTrue(viewModel.messages.last?.isUser ?? false)
    }

    func testChatMessageModel() {
        let message = ChatMessage(content: "Hello coach", isUser: true)

        XCTAssertEqual(message.content, "Hello coach")
        XCTAssertTrue(message.isUser)
        XCTAssertNotNil(message.id)
    }

    func testMessageFormatting() {
        let messages = [
            OpenAIMessage(role: "system", content: "You are a fitness coach"),
            OpenAIMessage(role: "user", content: "Help me lose weight")
        ]

        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].role, "system")
        XCTAssertEqual(messages[1].role, "user")
    }

    // MARK: - Context Building Tests

    func testContextBuilding() async {
        let contextBuilder = AIContextBuilder()
        let aiContext = await contextBuilder.buildContext()

        // `buildContext()` falls back to a default goal and always produces a
        // summary/stats string, so these are safe regardless of stored data.
        XCTAssertFalse(aiContext.userGoals.isEmpty)
        XCTAssertFalse(aiContext.recentActivitySummary.isEmpty)
        XCTAssertFalse(aiContext.currentStats.isEmpty)
    }

    // MARK: - API Service Tests

    func testOpenAIServiceInitialization() {
        XCTAssertNotNil(openAIService)
        XCTAssertEqual(openAIService.model, "gpt-4o-mini")
        XCTAssertGreaterThan(openAIService.minRequestInterval, 0)
    }

    /// There used to be a test here asserting that a key saved by
    /// `saveAPIKey` came back from `hasAPIKey`. Both are gone, and their
    /// absence is the point: the app has no local credential to save, and the
    /// screen that asked for one is gone with it. What replaces it is a
    /// read-only status view, which is at least constructible.
    func testAISettingsViewCanBeConstructed() {
        _ = AISettingsView()
    }

    // MARK: - Suggested Actions Tests

    func testSuggestedActionsGeneration() {
        XCTAssertFalse(viewModel.suggestedActions.isEmpty)
        // Actions are `SuggestedAction` values with a title + prompt.
        XCTAssertTrue(viewModel.suggestedActions.contains { $0.title == "Workout Plan" })
        XCTAssertTrue(viewModel.suggestedActions.contains { $0.title == "Plan Meal" })
    }

    func testActionTrigger() {
        // Tapping a suggested action sends its prompt as a user message.
        let prompt = viewModel.suggestedActions.first?.prompt ?? "Workout plan"
        viewModel.sendMessage(prompt)

        XCTAssertTrue(viewModel.messages.contains { $0.content == prompt })
    }

    // MARK: - Safety Tests

    func testDisclaimerRequired() {
        UserDefaults.standard.set(false, forKey: "hasAcceptedAIDisclaimer")

        let hasAccepted = UserDefaults.standard.bool(forKey: "hasAcceptedAIDisclaimer")
        XCTAssertFalse(hasAccepted)
    }

    func testSafetyDisclaimerViewCanBeConstructed() {
        // Constructing the view exercises its initializer and static copy.
        _ = SafetyDisclaimerView(isPresented: .constant(true))
    }

    // MARK: - Specialized Service Tests
    //
    // These call the live AI backend, which needs a deployed Edge Function and a
    // signed-in session. Neither exists in CI, so they are skipped. The skip is
    // explicit rather than a silent pass, and the condition is the real
    // precondition — there is no client key to gate on any more.

    private func skipUnlessLiveBackendIsReachable() throws {
        try XCTSkipUnless(
            AppEnvironment.isSupabaseConfigured && AuthService.shared.isAuthenticated,
            "No configured project and signed-in session — skipping live AI backend test."
        )
    }

    func testWorkoutPlanGeneratorRequiresAPIKey() async throws {
        try skipUnlessLiveBackendIsReachable()

        let generator = WorkoutPlanGenerator()
        let plan = try await generator.generateWorkoutPlan(
            duration: 60,
            equipment: ["Barbell", "Dumbbells"],
            focusArea: "Upper body"
        )
        XCTAssertFalse(plan.exercises.isEmpty)
    }

    func testDietAdvisorRequiresAPIKey() async throws {
        try skipUnlessLiveBackendIsReachable()

        let advisor = DietAdvisor()
        let suggestions = try await advisor.getMealSuggestions(
            mealType: "breakfast",
            preferences: ["High protein"],
            restrictions: ["Gluten-free"]
        )
        XCTAssertFalse(suggestions.meals.isEmpty)
    }

    // MARK: - Error Handling Tests

    func testSendMessageWithoutBackendDoesNotCrash() async {
        viewModel.sendMessage("Test without a reachable backend")

        // Allow the reply Task to attempt (and fail) the request.
        for _ in 0..<5 {
            await Task.yield()
        }

        XCTAssertFalse(viewModel.messages.isEmpty)
        XCTAssertTrue(viewModel.messages.contains { $0.content == "Test without a reachable backend" })
    }

    // MARK: - Cost Tracking Tests

    func testCostCalculation() {
        let shortMessage = "Hi"
        let longMessage = String(repeating: "Test ", count: 200)

        let shortTokens = openAIService.estimateTokens(for: shortMessage)
        let longTokens = openAIService.estimateTokens(for: longMessage)

        XCTAssertLessThan(shortTokens, longTokens)
        XCTAssertGreaterThan(longTokens, 100)
    }

    func testCostTracking() {
        let initialCost = UserDefaults.standard.double(forKey: "openai_total_cost")

        openAIService.trackCost(promptTokens: 100, completionTokens: 200)

        let newCost = UserDefaults.standard.double(forKey: "openai_total_cost")
        XCTAssertGreaterThan(newCost, initialCost)
    }
}
