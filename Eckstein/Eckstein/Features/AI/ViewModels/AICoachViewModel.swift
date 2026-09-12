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
    private let contextBuilder = AICoachContextBuilder()
    private let persistenceController: PersistenceController

    /// The conversation as the backend sees it, which is not the same as
    /// `messages`: the persisted list holds every turn including the welcome
    /// message and the error notices, and only real exchanges are replayed. Not
    /// `@Published` — nothing on screen reads it.
    private var conversationHistory: [OpenAIMessage] = []

    /// How many exchanges are replayed to the backend.
    ///
    /// Each exchange is two messages, so ten is twenty — the top of the range
    /// the brief allows, and enough for "what about tomorrow?" to make sense.
    /// The conversation is replayed as chat turns only; the user's history and
    /// stats travel once, in the system prompt, and are not repeated per turn.
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

    /// The four questions the brief asks the coach to answer.
    ///
    /// Each one is answerable from the context the builder sends — today's
    /// advice from the training window, the diet from the seven-day nutrition
    /// window, the summary from both, and progress from the weight trend. None
    /// of them asks the coach to change anything, because it cannot: see
    /// `OpenAIService.systemPrompt`.
    ///
    /// `title` is what the button shows and is localized; `prompt` is what is
    /// sent to the backend and stays English.
    private func setupSuggestedActions() {
        suggestedActions = [
            SuggestedAction(
                title: "ai_chat_action_plan_meal".localized,
                icon: "fork.knife",
                prompt: "What should I eat today? Use my recent meals and my goals."
            ),
            SuggestedAction(
                title: "ai_chat_action_workout_plan".localized,
                icon: "figure.strengthtraining.traditional",
                prompt: "What should I train today? Use my recent training."
            ),
            SuggestedAction(
                title: "ai_chat_action_week_summary".localized,
                icon: "calendar",
                prompt: "Summarize how my last 7 days of eating and training went."
            ),
            SuggestedAction(
                title: "ai_chat_action_progress".localized,
                icon: "chart.line.uptrend.xyaxis",
                prompt: "How is my progress towards my goal?"
            )
        ]
    }

    /// Appends the user's message and asks for a reply.
    ///
    /// A second send while one is in flight is dropped rather than queued. The
    /// reply is not streamed, so a duplicate would arrive as a second answer to
    /// the same question, and the user's own message would appear twice.
    func sendMessage(_ content: String) {
        guard !isLoading else { return }

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

        defer {
            isLoading = false
            isTyping = false
        }

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

            let errorMessage = ChatMessage(
                content: Self.failureMessage(for: error),
                isUser: false
            )
            messages.append(errorMessage)
        }
    }

    /// One sentence, chosen by the error case.
    ///
    /// This used to be built from `error.localizedDescription`, which for an
    /// unhandled case meant pasting a transport or decoding error — a URL, a
    /// status code, sometimes a whole response body — into the chat. Anything
    /// that is not one of our own errors falls through to the generic sentence.
    ///
    /// Internal rather than private so `PhaseFiveAITests` can hand it a raw
    /// transport error and assert that none of it reaches the user.
    static func failureMessage(for error: Error) -> String {
        (error as? OpenAIError)?.userMessage ?? OpenAIError.backendUnavailable.userMessage
    }

    /// Internal rather than private so the phase-5 tests can assert the window
    /// without sending a request. See `PhaseFiveAITests`.
    func buildConversationMessages(apiMessages: [OpenAIMessage]) -> [OpenAIMessage] {
        // System prompt, then the recent conversation, then the new user turn.
        // Earlier turns are dropped from the front, so the cap is on the window
        // rather than on nothing.
        var messages = [apiMessages[0]]
        messages.append(contentsOf: conversationHistory.suffix(maxHistoryMessages * 2))
        messages.append(contentsOf: apiMessages[1...])
        return messages
    }

    /// Internal rather than private for the same reason as
    /// `buildConversationMessages`.
    func updateConversationHistory(userMessage: String, aiResponse: String) {
        conversationHistory.append(OpenAIMessage(role: "user", content: userMessage))
        conversationHistory.append(OpenAIMessage(role: "assistant", content: aiResponse))

        // Keep only recent messages
        if conversationHistory.count > maxHistoryMessages * 2 {
            conversationHistory = Array(conversationHistory.suffix(maxHistoryMessages * 2))
        }
    }

    // MARK: - Quick Actions

    func generateWorkoutPlan() async {
        sendMessage("Create a personalized workout plan for today based on my recent training history and goals")
    }

    func generateMealPlan() async {
        sendMessage("Create a meal plan for today that fits my calorie goals and dietary preferences")
    }

    func analyzeForm(exercise: String) async {
        sendMessage("Give me detailed form tips and common mistakes to avoid for \(exercise)")
    }

    func getMotivation() async {
        sendMessage("I need some motivation to stay on track with my fitness goals")
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
    /// The button's label, localized for display. `prompt` is what gets sent.
    let title: String
    let icon: String
    let prompt: String
}
