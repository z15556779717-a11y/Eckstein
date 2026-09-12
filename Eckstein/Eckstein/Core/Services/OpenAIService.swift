//
//  OpenAIService.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation
import Combine
import Supabase

// MARK: - Models

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

/// The body this app posts to its own AI backend.
///
/// It no longer looks like a provider request because it no longer is one: the
/// model, the provider key and the retry policy all live in the Edge Function
/// now. `temperature` is passed through because the caller knows whether it
/// wants a plan or a chat reply; everything else is the server's business.
struct AIBackendRequest: Encodable {
    let messages: [OpenAIMessage]
    let temperature: Double

    /// The language to answer in, as the app's own code
    /// (`LocalizationManager.currentLanguage`) — `"en"`, `"he"` or `"zh-Hans"`.
    ///
    /// A code, not a sentence: the Edge Function owns how a language is asked
    /// for, and it only accepts the codes it knows, so nothing a client sends
    /// here reaches the model as an instruction. Optional because the request is
    /// still valid without it, and because a build older than this field is a
    /// caller the function has to keep serving.
    let locale: String?
}

struct AIBackendResponse: Decodable {
    let content: String
    let usage: TokenUsage?

    struct TokenUsage: Decodable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

// MARK: - Service

/// The app's client for the AI coach backend.
///
/// **There is no provider key in this app, and no way to enter one.** The coach
/// runs behind a Supabase Edge Function (`supabase/functions/ai-coach`) which
/// holds the provider key as a server-side secret; the provider itself is
/// deployment configuration there, currently Alibaba Bailian (Qwen) in its
/// OpenAI-compatible mode. This type sends the trimmed conversation and the
/// user's Supabase session token to that function and returns its answer. A key
/// shipped in an IPA is a key anyone with the IPA has, so the only place it can
/// live is the server.
///
/// The consequence worth stating: a signed-in user is required. The function
/// authenticates the caller, which is also what stops the endpoint from being an
/// open proxy for the provider account.
@MainActor
class OpenAIService: ObservableObject {
    static let shared = OpenAIService()

    /// The name of the deployed function.
    private static let functionName = "ai-coach"

    // Internal (not private) so the unit-test target can assert on the model and
    // rate-limit configuration via `@testable import`. See AICoachTests.
    //
    // The *name* is the server's default model, kept here so the client can
    // label what it is talking to; the server is free to override it.
    let model = "gpt-4o-mini"

    // Rate limiting
    private var lastRequestTime: Date?
    let minRequestInterval: TimeInterval = 1.0

    // Cost tracking
    @Published var totalTokensUsed: Int = 0
    @Published var estimatedCost: Double = 0.0

    private init() {}

    // MARK: - Sending

    /// Sends a conversation to the backend and returns the reply.
    ///
    /// Every failure mode the user can meet — no session, no network, a slow
    /// reply, a rate limit, an empty or unreadable answer — leaves this method as
    /// a typed `OpenAIError`. Nothing here formats text for display: the view
    /// model asks `OpenAIError.userMessage`, so the wording exists once.
    func sendMessage(_ messages: [OpenAIMessage], temperature: Double = 0.7) async throws -> String {
        // No backend to call: this build has no project URL or key, so there is
        // nothing a session check or a request could succeed against. Answered
        // before the client is built, which also keeps a misconfigured build from
        // reaching out to a placeholder host at all.
        guard AppEnvironment.isSupabaseConfigured else {
            throw OpenAIError.backendUnavailable
        }

        // The session is the credential. `functions.invoke` attaches its access
        // token; without one the function would reject the call anyway, and
        // asking first turns that into a clear message.
        let client = SupabaseService.shared.client
        guard (try? await client.auth.session) != nil else {
            throw OpenAIError.notSignedIn
        }

        // Rate limiting
        if let lastTime = lastRequestTime {
            let timeSinceLastRequest = Date().timeIntervalSince(lastTime)
            if timeSinceLastRequest < minRequestInterval {
                try await Task.sleep(nanoseconds: UInt64((minRequestInterval - timeSinceLastRequest) * 1_000_000_000))
            }
        }
        lastRequestTime = Date()

        let response: AIBackendResponse
        do {
            response = try await client.functions.invoke(
                Self.functionName,
                options: FunctionInvokeOptions(
                    body: AIBackendRequest(
                        messages: messages,
                        temperature: temperature,
                        // Read at send time, not cached: the user can switch
                        // language between two messages, and the next reply
                        // should follow.
                        locale: LocalizationManager.shared.currentLanguage
                    )
                )
            )
        } catch {
            throw OpenAIService.from(transport: error)
        }

        if let usage = response.usage {
            totalTokensUsed += usage.totalTokens
            estimatedCost += Self.cost(promptTokens: usage.promptTokens, completionTokens: usage.completionTokens)
        }

        let content = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            throw OpenAIError.noContent
        }

        return content
    }

    /// Maps anything that came out of the network layer onto a case the UI knows
    /// how to explain.
    ///
    /// The mapping is coarse on purpose. A `FunctionsError` carries a status and
    /// a body, and neither belongs in front of a user; what matters is whether
    /// this is worth retrying, whether the user can fix it, or whether it is the
    /// backend's problem.
    private static func from(transport error: Error) -> OpenAIError {
        if error is URLError {
            let code = (error as? URLError)?.code
            switch code {
            case .timedOut:
                return .timedOut
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost, .dataNotAllowed:
                return .offline
            default:
                return .backendUnavailable
            }
        }

        // `FunctionsError` is the supabase-swift error type; matched by name so
        // this file does not have to keep importing its internals.
        let description = String(describing: error)
        if description.contains("statusCode: 401") || description.contains("statusCode: 403") {
            return .notSignedIn
        }
        if description.contains("statusCode: 429") {
            return .rateLimited
        }
        if description.contains("statusCode: 404") {
            // The function is not deployed on this project.
            return .backendUnavailable
        }

        return .backendUnavailable
    }

    // MARK: - Prompt

    /// Builds the conversation sent for one chat turn.
    ///
    /// The shape is: one system message, then the recent conversation, then the
    /// user's new message. The system message carries the user's goal and the
    /// summary of where they are — the same numbers the Dashboard shows — rather
    /// than a dump of their history, and the history itself is capped by the
    /// caller (see `AICoachViewModel.maxHistoryMessages`).
    ///
    /// Context used to be appended as `assistant` messages, which told the model
    /// that the coach had said those facts. Stating them once, as instructions,
    /// is both shorter and more accurate.
    func buildFitnessCoachMessages(userMessage: String, context: AICoachContext) -> [OpenAIMessage] {
        [OpenAIMessage(role: "system", content: Self.systemPrompt(for: context)),
         OpenAIMessage(role: "user", content: userMessage)]
    }

    /// The system prompt: who the coach is, who the user is, and the rules.
    static func systemPrompt(for context: AICoachContext) -> String {
        """
        You are DorEckstein, a fitness and nutrition coach working in the \
        Eckstein Method: gram-based meals rather than calorie counting, two main \
        meals a day with carry-over between them, and progressive strength \
        training.

        The user's goal: \(context.fitnessGoal)
        Where they are now: \(context.currentStats)

        How to answer:
        - Be specific and practical. Give gram amounts, weights, reps and sets, \
        not general encouragement.
        - Use the numbers above when they are relevant, and say when you do not \
        have the data to answer something.
        - You advise only. You cannot log meals, create or change workouts, \
        delete anything, or change the user's goals, and you must not claim to \
        have done any of those. If a change is needed, tell the user what to do \
        and let them do it.
        - For pain, injury, pregnancy, eating disorders, medication or any other \
        medical question, say plainly that this needs a doctor, and do not \
        suggest a diet or a training plan for it.
        - Keep answers under about 200 words unless asked for a full plan.
        """
    }

    // MARK: - Cost

    /// Rough cost estimate for GPT-4o-mini: $0.15/1M input, $0.60/1M output.
    private static func cost(promptTokens: Int, completionTokens: Int) -> Double {
        Double(promptTokens) * 0.00000015 + Double(completionTokens) * 0.0000006
    }

    func estimateTokens(for text: String) -> Int {
        // Rough estimation: ~4 characters per token
        return text.count / 4
    }

    func trackCost(promptTokens: Int, completionTokens: Int) {
        totalTokensUsed += promptTokens + completionTokens
        estimatedCost += Self.cost(promptTokens: promptTokens, completionTokens: completionTokens)

        UserDefaults.standard.set(totalTokensUsed, forKey: "openai_total_tokens")
        UserDefaults.standard.set(estimatedCost, forKey: "openai_total_cost")
    }
}

// MARK: - Error Types

/// What can go wrong with an AI request, in terms the user can act on.
///
/// The associated values are for logging and for tests. `userMessage` is the
/// only thing the UI may show — an HTTP status, a decoder error or a provider
/// error string tells the user nothing and reads as a crash.
enum OpenAIError: LocalizedError {
    case notSignedIn
    case offline
    case timedOut
    case backendUnavailable
    case rateLimited
    case invalidResponse
    case noContent
    case apiError(String)

    /// The sentence shown in the chat.
    var userMessage: String {
        switch self {
        case .notSignedIn:
            return "ai_error_sign_in".localized
        case .offline:
            return "ai_error_offline".localized
        case .timedOut, .backendUnavailable, .invalidResponse, .apiError:
            return "ai_error_unavailable".localized
        case .rateLimited:
            return "ai_error_rate_limited".localized
        case .noContent:
            return "ai_error_empty".localized
        }
    }

    /// For logs and assertions. Not shown to users.
    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "No signed-in session for the AI backend"
        case .offline: return "No network connection"
        case .timedOut: return "Request timed out"
        case .backendUnavailable: return "AI backend unavailable"
        case .rateLimited: return "Rate limited"
        case .invalidResponse: return "Unreadable response from the AI backend"
        case .noContent: return "Empty response from the AI backend"
        case .apiError(let message): return "AI backend error: \(message)"
        }
    }
}
