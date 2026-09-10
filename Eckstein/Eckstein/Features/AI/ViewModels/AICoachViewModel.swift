//
//  AICoachViewModel.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation
import Combine
import CoreData

@MainActor
class AICoachViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var isTyping = false
    @Published var suggestedActions: [SuggestedAction] = []
    
    private let openAIService = OpenAIService.shared
    private let contextBuilder = AIContextBuilder()
    private let persistenceController: PersistenceController

    // Message history for context
    private var conversationHistory: [OpenAIMessage] = []
    private let maxHistoryMessages = 10

    /// - Parameter persistenceController: injected so tests can supply an
    ///   in-memory store instead of the shared CloudKit-backed one.
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        loadMessages()
        setupWelcomeMessage()
        setupSuggestedActions()
    }
    
    private func setupWelcomeMessage() {
        if messages.isEmpty {
            let welcomeMessage = ChatMessage(
                content: "שלום! I'm DorEckstein, your AI fitness coach trained in the Eckstein Method. I specialize in:\n\n• The Eckstein gram-based diet system (not calories!)\n• Personalized workout plans\n• Proper food combinations (e.g., 200g fish + 280g cheese)\n• Meal carry-over calculations\n• Form tips and exercise guidance\n• Progress tracking for your two daily meals\n\nI follow Dor Eckstein's specific approach to fitness and nutrition. What would you like to work on today?",
                isUser: false
            )
            messages.append(welcomeMessage)
            saveMessage(welcomeMessage)
        }
    }
    
    private func setupSuggestedActions() {
        suggestedActions = [
            SuggestedAction(
                title: "Plan Meal",
                icon: "fork.knife",
                prompt: "Help me plan my meals for today using the Eckstein gram system"
            ),
            SuggestedAction(
                title: "Food Combo",
                icon: "plus.circle",
                prompt: "Calculate food combinations to reach 100% of my protein requirement"
            ),
            SuggestedAction(
                title: "Carry-Over",
                icon: "arrow.right.circle",
                prompt: "Calculate my carry-over from Meal 1 to Meal 2"
            ),
            SuggestedAction(
                title: "Workout Plan",
                icon: "figure.strengthtraining.traditional",
                prompt: "Create a workout plan following the Eckstein training method"
            )
        ]
    }
    
    func sendMessage(_ content: String) {
        // Add user message
        let userMessage = ChatMessage(content: content, isUser: true)
        messages.append(userMessage)
        saveMessage(userMessage)
        
        // Clear suggested actions after first message
        if messages.count == 2 {
            suggestedActions = []
        }
        
        // Get AI response
        Task {
            await getAIResponse(for: content)
        }
    }
    
    private func getAIResponse(for userMessage: String) async {
        isLoading = true
        isTyping = true
        error = nil
        
        do {
            // Build context
            let context = await contextBuilder.buildContext()
            
            // Build messages for API
            let apiMessages = openAIService.buildFitnessCoachMessages(
                userMessage: userMessage,
                context: context
            )
            
            // Add conversation history
            let fullMessages = buildConversationMessages(apiMessages: apiMessages)
            
            // Get response
            let response = try await openAIService.sendMessage(fullMessages)
            
            // Add AI response
            let aiMessage = ChatMessage(content: response, isUser: false)
            messages.append(aiMessage)
            saveMessage(aiMessage)
            
            // Update conversation history
            updateConversationHistory(userMessage: userMessage, aiResponse: response)
            
        } catch {
            self.error = error
            
            // Provide more specific error messages
            let errorContent: String
            if let openAIError = error as? OpenAIError {
                switch openAIError {
                case .apiError(let message):
                    if message.contains("API key") {
                        errorContent = "OpenAI API key is not configured. Please check your .env file and ensure OPENAI_API_KEY is set."
                    } else if message.contains("internet") || message.contains("network") {
                        errorContent = "Unable to connect to the internet. Please check your network connection and try again."
                    } else {
                        errorContent = "Error: \(message)"
                    }
                case .httpError(let code):
                    if code == 401 {
                        errorContent = "Invalid API key. Please check your OpenAI API key in the .env file."
                    } else if code == 429 {
                        errorContent = "Rate limit exceeded. Please wait a moment and try again."
                    } else {
                        errorContent = "Server error (code: \(code)). Please try again later."
                    }
                case .rateLimitExceeded:
                    errorContent = "Too many requests. Please wait a moment and try again."
                default:
                    errorContent = "Connection error: \(error.localizedDescription)"
                }
            } else {
                errorContent = "Unexpected error: \(error.localizedDescription)"
            }
            
            let errorMessage = ChatMessage(
                content: errorContent,
                isUser: false
            )
            messages.append(errorMessage)
        }
        
        isLoading = false
        isTyping = false
    }
    
    private func buildConversationMessages(apiMessages: [OpenAIMessage]) -> [OpenAIMessage] {
        var messages = [apiMessages[0]] // System prompt
        messages.append(contentsOf: conversationHistory)
        messages.append(contentsOf: apiMessages[1...]) // Current context and user message
        return messages
    }
    
    private func updateConversationHistory(userMessage: String, aiResponse: String) {
        conversationHistory.append(OpenAIMessage(role: "user", content: userMessage))
        conversationHistory.append(OpenAIMessage(role: "assistant", content: aiResponse))
        
        // Keep only recent messages
        if conversationHistory.count > maxHistoryMessages * 2 {
            conversationHistory = Array(conversationHistory.suffix(maxHistoryMessages * 2))
        }
    }
    
    // MARK: - Quick Actions
    
    func generateWorkoutPlan() async {
        await sendMessage("Create a personalized workout plan for today based on my recent training history and goals")
    }
    
    func generateMealPlan() async {
        await sendMessage("Create a meal plan for today that fits my calorie goals and dietary preferences")
    }
    
    func analyzeForm(exercise: String) async {
        await sendMessage("Give me detailed form tips and common mistakes to avoid for \(exercise)")
    }
    
    func getMotivation() async {
        await sendMessage("I need some motivation to stay on track with my fitness goals")
    }
    
    // MARK: - Message Persistence
    
    private func loadMessages() {
        let request: NSFetchRequest<CDChatMessage> = CDChatMessage.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDChatMessage.timestamp, ascending: true)]
        request.fetchLimit = 50
        
        do {
            let savedMessages = try persistenceController.container.viewContext.fetch(request)
            messages = savedMessages.map { ChatMessage(from: $0) }
        } catch {
            print("Error loading messages: \(error)")
        }
    }
    
    private func saveMessage(_ message: ChatMessage) {
        let cdMessage = CDChatMessage(context: persistenceController.container.viewContext)
        cdMessage.id = message.id
        cdMessage.content = message.content
        cdMessage.isUser = message.isUser
        cdMessage.timestamp = message.timestamp
        
        do {
            try persistenceController.container.viewContext.save()
        } catch {
            print("Error saving message: \(error)")
        }
    }
    
    func clearChat() {
        // Delete all messages
        let request: NSFetchRequest<NSFetchRequestResult> = CDChatMessage.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        do {
            try persistenceController.container.viewContext.execute(deleteRequest)
            do {
            try persistenceController.container.viewContext.save()
        } catch {
            print("Error saving message: \(error)")
        }
            
            messages.removeAll()
            conversationHistory.removeAll()
            setupWelcomeMessage()
            setupSuggestedActions()
        } catch {
            print("Error clearing chat: \(error)")
        }
    }
}

// MARK: - Supporting Types

struct SuggestedAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let prompt: String
}