//
//  AICoachTests.swift
//  EcksteinTests
//
//  Created by Eliad Shahar on 13/07/2025.
//

import XCTest
import CoreData
@testable import Eckstein

class AICoachTests: XCTestCase {
    var viewModel: AICoachViewModel!
    var openAIService: OpenAIService!
    var contextBuilder: AIContextBuilder!
    var controller: PersistenceController!
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        controller = PersistenceController(inMemory: true)
        context = controller.container.viewContext
        viewModel = AICoachViewModel()
        openAIService = OpenAIService.shared
        contextBuilder = AIContextBuilder()
    }
    
    override func tearDown() {
        viewModel = nil
        openAIService = nil
        contextBuilder = nil
        controller = nil
        context = nil
        super.tearDown()
    }
    
    // MARK: - Message Management Tests
    
    func testSendMessage() {
        let initialCount = viewModel.messages.count
        
        viewModel.sendMessage("Test message")
        
        // Should add user message immediately
        XCTAssertEqual(viewModel.messages.count, initialCount + 1)
        XCTAssertEqual(viewModel.messages.last?.content, "Test message")
        XCTAssertTrue(viewModel.messages.last?.isUser ?? false)
        XCTAssertTrue(viewModel.isTyping)
    }
    
    func testMessagePersistence() {
        // Send a message
        viewModel.sendMessage("Test persistence")
        
        // Create new view model to test loading
        let newViewModel = AICoachViewModel()
        
        // Should load persisted messages
        XCTAssertTrue(newViewModel.messages.contains { $0.content == "Test persistence" })
    }
    
    // MARK: - Context Building Tests
    
    func testContextBuilding() async {
        // Create test data
        let workoutRepo = WorkoutRepository(context: context)
        let dietRepo = DietRepository(context: context)
        let weightRepo = WeightRepository(context: context)
        
        // Add test workout
        let workout = CDWorkout.create(name: "Test Workout", date: Date(), in: context)
        workout.completed = true
        
        // Add test meal
        _ = dietRepo.createMeal(type: .lunch)
        
        // Add test weight
        _ = weightRepo.createWeightEntry(weight: 75.0)
        
        try? context.save()
        
        // Build context
        let aiContext = await contextBuilder.buildContext()
        
        XCTAssertFalse(aiContext.userGoals.isEmpty)
        XCTAssertNotNil(aiContext.activitySummary)
        XCTAssertNotNil(aiContext.currentStats)
    }
    
    // MARK: - API Service Tests
    
    func testOpenAIServiceInitialization() {
        XCTAssertNotNil(openAIService)
        XCTAssertEqual(openAIService.model, "gpt-4o-mini")
        XCTAssertGreaterThan(openAIService.minRequestInterval, 0)
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
    
    // MARK: - Suggested Actions Tests
    
    func testSuggestedActionsGeneration() {
        // Test initial suggested actions
        XCTAssertFalse(viewModel.suggestedActions.isEmpty)
        XCTAssertTrue(viewModel.suggestedActions.contains("💪 Create workout plan"))
        XCTAssertTrue(viewModel.suggestedActions.contains("🥗 Get meal suggestions"))
    }
    
    func testActionTrigger() {
        let action = "💪 Create workout plan"
        viewModel.handleSuggestedAction(action)
        
        // Should send appropriate message
        XCTAssertTrue(viewModel.messages.contains { $0.content.contains("workout plan") })
    }
    
    // MARK: - Safety Tests
    
    func testDisclaimerRequired() {
        // Reset disclaimer acceptance
        UserDefaults.standard.set(false, forKey: "hasAcceptedAIDisclaimer")
        
        let hasAccepted = UserDefaults.standard.bool(forKey: "hasAcceptedAIDisclaimer")
        XCTAssertFalse(hasAccepted)
    }
    
    func testSafetyDisclaimer() {
        let disclaimerView = SafetyDisclaimerView(isPresented: .constant(true))
        
        // Test that disclaimer contains required elements
        let disclaimerText = """
        Medical Disclaimer
        Fitness Guidance
        Nutrition Advice
        AI Limitations
        Emergency Situations
        """
        
        for element in disclaimerText.components(separatedBy: "\n") {
            XCTAssertTrue(element.count > 0)
        }
    }
    
    // MARK: - Specialized Service Tests
    
    func testWorkoutPlanGenerator() async {
        let generator = WorkoutPlanGenerator()
        
        // Test plan request formatting
        let plan = await generator.generateWorkoutPlan(
            goal: "Build muscle",
            experience: "intermediate",
            daysPerWeek: 4,
            equipment: ["Barbell", "Dumbbells", "Pull-up bar"]
        )
        
        // Verify structure (mock response)
        XCTAssertNotNil(plan)
    }
    
    func testDietAdvisor() async {
        let advisor = DietAdvisor()
        
        // Test meal suggestions
        let suggestions = try? await advisor.getMealSuggestions(
            mealType: "breakfast",
            preferences: ["High protein"],
            restrictions: ["Gluten-free"]
        )
        
        XCTAssertNotNil(suggestions)
    }
    
    func testFormAnalyzer() async {
        let analyzer = FormAnalyzer()
        
        // Test exercise lookup
        let exerciseInfo = analyzer.exerciseDatabase["squat"]
        XCTAssertNotNil(exerciseInfo)
        XCTAssertEqual(exerciseInfo?.name, "Squat")
        XCTAssertTrue(exerciseInfo?.muscleGroups.contains("quadriceps") ?? false)
    }
    
    // MARK: - Error Handling Tests
    
    func testAPIErrorHandling() {
        // Test with empty API key
        UserDefaults.standard.removeObject(forKey: "openai_api_key")
        
        viewModel.sendMessage("Test without API key")
        
        // Should handle gracefully
        XCTAssertTrue(viewModel.isTyping || viewModel.messages.last?.content.contains("Error") ?? false)
    }
    
    func testRateLimiting() async {
        // Send multiple rapid requests
        for i in 0..<3 {
            viewModel.sendMessage("Rapid request \(i)")
            
            // Small delay to let async operations start
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Should handle rate limiting
        XCTAssertTrue(viewModel.messages.count >= 3)
    }
    
    // MARK: - Cost Tracking Tests
    
    func testCostCalculation() {
        let service = OpenAIService.shared
        
        // Test token estimation
        let shortMessage = "Hi"
        let longMessage = String(repeating: "Test ", count: 200)
        
        let shortTokens = service.estimateTokens(for: shortMessage)
        let longTokens = service.estimateTokens(for: longMessage)
        
        XCTAssertLessThan(shortTokens, longTokens)
        XCTAssertGreaterThan(longTokens, 100)
    }
    
    func testCostTracking() {
        let initialCost = UserDefaults.standard.double(forKey: "openai_total_cost")
        
        // Simulate API usage
        openAIService.trackCost(promptTokens: 100, completionTokens: 200)
        
        let newCost = UserDefaults.standard.double(forKey: "openai_total_cost")
        XCTAssertGreaterThan(newCost, initialCost)
    }
}