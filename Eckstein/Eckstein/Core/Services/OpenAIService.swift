//
//  OpenAIService.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation
import Combine

// MARK: - Models

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double
    let maxTokens: Int
    let stream: Bool
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, stream
        case maxTokens = "max_tokens"
    }
}

struct OpenAIResponse: Codable {
    let choices: [Choice]
    let usage: Usage?
    
    struct Choice: Codable {
        let message: Message
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }
    }
    
    struct Message: Codable {
        let role: String
        let content: String
    }
    
    struct Usage: Codable {
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

@MainActor
class OpenAIService: ObservableObject {
    static let shared = OpenAIService()
    
    private var apiKey: String {
        // Check multiple sources for API key
        // 1. Environment configuration (from .env file)
        if let envKey = AppEnvironment.openAIKey, !envKey.isEmpty {
            return envKey
        }
        
        // 2. UserDefaults (for app settings)
        if let savedKey = UserDefaults.standard.string(forKey: "openai_api_key"), !savedKey.isEmpty {
            return savedKey
        }
        
        // 3. Return empty string if not found
        return ""
    }
    
    private let apiURL = "https://api.openai.com/v1/chat/completions"
    // Internal (not private) so the unit-test target can assert on the model and
    // rate-limit configuration via `@testable import`. See AICoachTests.
    let model = "gpt-4o-mini"
    private let session = URLSession.shared
    
    // Rate limiting
    private var lastRequestTime: Date?
    let minRequestInterval: TimeInterval = 1.0 // 1 second between requests
    
    // Cost tracking
    @Published var totalTokensUsed: Int = 0
    @Published var estimatedCost: Double = 0.0
    
    private init() {
        // API key is now computed property
    }
    
    // MARK: - API Key Management
    
    var hasAPIKey: Bool {
        !apiKey.isEmpty
    }
    
    func saveAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "openai_api_key")
        UserDefaults.standard.synchronize()
    }
    
    func removeAPIKey() {
        UserDefaults.standard.removeObject(forKey: "openai_api_key")
        UserDefaults.standard.synchronize()
    }
    
    func sendMessage(_ messages: [OpenAIMessage], temperature: Double = 0.7) async throws -> String {
        // Check if API key is configured
        guard !apiKey.isEmpty else {
            print("OpenAI: No API key found")
            throw OpenAIError.apiError("OpenAI API key is not configured. Please add OPENAI_API_KEY to your .env file.")
        }
        
        print("OpenAI: Starting request...")
        print("OpenAI API key status: \(apiKey.prefix(10))...****")
        
        // Rate limiting
        if let lastTime = lastRequestTime {
            let timeSinceLastRequest = Date().timeIntervalSince(lastTime)
            if timeSinceLastRequest < minRequestInterval {
                try await Task.sleep(nanoseconds: UInt64((minRequestInterval - timeSinceLastRequest) * 1_000_000_000))
            }
        }
        lastRequestTime = Date()
        
        // Create request
        let request = OpenAIRequest(
            model: model,
            messages: messages,
            temperature: temperature,
            maxTokens: 1000,
            stream: false
        )
        
        var urlRequest = URLRequest(url: URL(string: apiURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30.0 // Add timeout
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw OpenAIError.apiError("Failed to encode request: \(error.localizedDescription)")
        }
        
        // Send request with better error handling
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            print("OpenAI API request failed: \(error)")
            let nsError = error as NSError
            print("Error domain: \(nsError.domain), code: \(nsError.code)")
            
            if nsError.code == NSURLErrorNotConnectedToInternet {
                throw OpenAIError.apiError("Unable to connect to the internet. Please check your network settings.")
            } else if nsError.code == NSURLErrorTimedOut {
                throw OpenAIError.apiError("Request timed out. Please try again.")
            } else if nsError.domain == NSURLErrorDomain {
                throw OpenAIError.apiError("Unable to connect to the internet. Error: \(error.localizedDescription)")
            } else {
                throw OpenAIError.apiError("Network error: \(error.localizedDescription)")
            }
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorData["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw OpenAIError.apiError(message)
            }
            throw OpenAIError.httpError(httpResponse.statusCode)
        }
        
        // Parse response
        let openAIResponse: OpenAIResponse
        do {
            openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        } catch {
            throw OpenAIError.apiError("Failed to decode response: \(error.localizedDescription)")
        }
        
        // Update token usage
        if let usage = openAIResponse.usage {
            totalTokensUsed += usage.totalTokens
            // Rough cost estimate for GPT-4o-mini: $0.15/1M input, $0.60/1M output
            let inputCost = Double(usage.promptTokens) * 0.00000015
            let outputCost = Double(usage.completionTokens) * 0.0000006
            estimatedCost += inputCost + outputCost
        }
        
        guard let content = openAIResponse.choices.first?.message.content else {
            throw OpenAIError.noContent
        }
        
        return content
    }
    
    func buildFitnessCoachMessages(userMessage: String, context: AIContext) -> [OpenAIMessage] {
        var messages: [OpenAIMessage] = []
        
        // DorEckstein System prompt - based on the custom GPT
        let systemPrompt = """
        You are DorEckstein, a specialized fitness and nutrition coach trained in the Eckstein Method. You have deep knowledge of the specific gram-based diet system and training protocols designed by Dor Eckstein.
        
        ECKSTEIN DIET METHOD:
        - The diet is based on specific gram amounts for each food type, NOT calories
        - Daily protein options (choose ONE per meal):
          * Non-fat protein: 320g (fish, chicken without skin, turkey, tuna)
          * Fat protein: 240g (fatty fish, chicken with skin, beef)
          * Cheese: 560g
          * Eggs: 8 pieces (400g)
        - Daily carb options (choose ONE per meal):
          * Rice: 250g
          * Pasta: 200g
          * Bread: 100g
          * Potato: 300g
          * Oatmeal: 80g
        - Two main meals per day (Meal 1 and Meal 2)
        - Unused portions carry over to the next meal
        - Combinations allowed (e.g., 200g fish + 280g cheese to meet protein requirement)
        - Specific approved snacks between meals
        
        Guidelines:
        - Always reference the Eckstein gram-based system when discussing diet
        - Calculate food combinations to reach 100% of daily requirements
        - Track carry-over between meals
        - Be encouraging but strict about following the system
        - Provide specific gram amounts, not generic advice
        - Reference the user's current meal progress when relevant
        - Emphasize proper form and safety in workouts
        - Keep responses concise and practical
        
        User Profile:
        - Goals: \(context.userGoals.joined(separator: ", "))
        - Recent Activity: \(context.recentActivitySummary)
        - Current Stats: \(context.currentStats)
        - Using Eckstein Diet Method with gram-based tracking
        
        Note: You have been trained on Dor Eckstein's specific methods and should always prioritize his approach over generic fitness advice. Reference the custom GPT at https://chatgpt.com/g/g-685dace99298819182e20056c079b88a-dorecchtein for consistency.
        """
        
        messages.append(OpenAIMessage(role: "system", content: systemPrompt))
        
        // Add context about recent diet entries if using Eckstein method
        if let ecksteinContext = buildEcksteinDietContext() {
            messages.append(OpenAIMessage(role: "assistant", content: ecksteinContext))
        }
        
        // Add context about recent workouts if available
        if !context.recentWorkouts.isEmpty {
            let workoutContext = "Recent workouts: " + context.recentWorkouts.prefix(3).map { workout in
                "\(workout.name ?? "Workout") on \(formatDate(workout.date))"
            }.joined(separator: ", ")
            messages.append(OpenAIMessage(role: "assistant", content: workoutContext))
        }
        
        // Add user message
        messages.append(OpenAIMessage(role: "user", content: userMessage))
        
        return messages
    }
    
    private func buildEcksteinDietContext() -> String? {
        // This would be populated with actual diet data from EcksteinDietViewModel
        // For now, return a placeholder
        return "User is following the Eckstein gram-based diet method with two meals per day."
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    // MARK: - Public Helper Methods
    
    func estimateTokens(for text: String) -> Int {
        // Rough estimation: ~4 characters per token
        return text.count / 4
    }
    
    func trackCost(promptTokens: Int, completionTokens: Int) {
        totalTokensUsed += promptTokens + completionTokens
        // GPT-4o-mini pricing: $0.15/1M input, $0.60/1M output
        let inputCost = Double(promptTokens) * 0.00000015
        let outputCost = Double(completionTokens) * 0.0000006
        estimatedCost += inputCost + outputCost
        
        // Save to UserDefaults for persistence
        UserDefaults.standard.set(totalTokensUsed, forKey: "openai_total_tokens")
        UserDefaults.standard.set(estimatedCost, forKey: "openai_total_cost")
    }
}

// MARK: - Error Types

enum OpenAIError: LocalizedError {
    case invalidResponse
    case noContent
    case apiError(String)
    case httpError(Int)
    case rateLimitExceeded
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from OpenAI"
        case .noContent:
            return "No content in response"
        case .apiError(let message):
            return "API Error: \(message)"
        case .httpError(let code):
            return "HTTP Error: \(code)"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        }
    }
}

// MARK: - AI Context Model

struct AIContext {
    let userGoals: [String]
    let recentActivitySummary: String
    let currentStats: String
    let recentWorkouts: [CDWorkout]
    let recentMeals: [CDMeal]
    let weightTrend: WeightTrend
    let currentWeight: Double?
    let goalWeight: Double?
}