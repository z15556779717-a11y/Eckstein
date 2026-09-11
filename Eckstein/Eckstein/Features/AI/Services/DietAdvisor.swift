//
//  DietAdvisor.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation
import CoreData

@MainActor
class DietAdvisor {
    private let openAIService = OpenAIService.shared
    private let contextBuilder = AIContextBuilder()

    /// The official nutrition path.
    ///
    /// Replaced a `DietRepository` dependency in phase 2: the weekly stats below
    /// used to be derived from `CDMeal`, which receives no user writes, so they
    /// were always empty. See NUTRITION_MIGRATION_PLAN.md §13.
    private let nutritionService = NutritionService()

    init() {}
    
    func getMealSuggestions(
        mealType: String,
        preferences: [String] = [],
        restrictions: [String] = []
    ) async throws -> MealSuggestions {
        let context = await contextBuilder.buildContext()
        let dietContext = contextBuilder.buildDietContext(for: mealType)
        
        let prompt = buildMealPrompt(
            mealType: mealType,
            preferences: preferences,
            restrictions: restrictions,
            context: context,
            dietContext: dietContext
        )
        
        let messages = [
            OpenAIMessage(role: "system", content: getDietSystemPrompt()),
            OpenAIMessage(role: "user", content: prompt)
        ]
        
        let response = try await openAIService.sendMessage(messages, temperature: 0.7)
        
        return parseMealSuggestions(from: response)
    }
    
    func analyzeDietProgress() async throws -> DietAnalysis {
        let context = await contextBuilder.buildContext()
        let weeklyStats = await calculateWeeklyStats()
        
        let prompt = """
        Analyze my diet progress for the past week:
        
        Weekly averages:
        - Calories: \(weeklyStats.avgCalories)
        - Protein: \(weeklyStats.avgProtein)g
        - Carbs: \(weeklyStats.avgCarbs)g
        - Fats: \(weeklyStats.avgFats)g
        
        Goals:
        - Target calories: \(weeklyStats.targetCalories)
        - Weight goal: \(context.goalWeight != nil ? String(format: "%.1f", context.goalWeight!) + "kg" : "Not set")
        
        Provide:
        1. Progress assessment
        2. Areas for improvement
        3. Specific recommendations
        4. Meal timing optimization
        """
        
        let messages = [
            OpenAIMessage(role: "system", content: getDietSystemPrompt()),
            OpenAIMessage(role: "user", content: prompt)
        ]
        
        let response = try await openAIService.sendMessage(messages, temperature: 0.5)
        
        return DietAnalysis(
            summary: response,
            recommendations: extractRecommendations(from: response),
            compliance: calculateCompliance(stats: weeklyStats)
        )
    }
    
    private func buildMealPrompt(
        mealType: String,
        preferences: [String],
        restrictions: [String],
        context: AICoachContext,
        dietContext: String
    ) -> String {
        """
        Suggest 3 meal options for \(mealType) that fit these requirements:
        
        User goals: \(context.userGoals.joined(separator: ", "))
        Current stats: \(context.currentStats)
        Recent \(mealType) history: \(dietContext)
        
        Preferences: \(preferences.isEmpty ? "None specified" : preferences.joined(separator: ", "))
        Restrictions: \(restrictions.isEmpty ? "None" : restrictions.joined(separator: ", "))
        
        For each meal, provide:
        - Name and description
        - Estimated macros (calories, protein, carbs, fats)
        - Key ingredients
        - Preparation time
        - Why it fits the user's goals
        
        Format as:
        MEAL 1: [Name]
        Description: [Brief description]
        Macros: [calories]cal, [protein]g protein, [carbs]g carbs, [fats]g fats
        Ingredients: [list]
        Prep time: [minutes]
        Benefits: [why it's good for their goals]
        """
    }
    
    private func getDietSystemPrompt() -> String {
        """
        You are a certified nutritionist specializing in sports nutrition. Provide evidence-based dietary advice that:
        - Supports the user's fitness goals
        - Ensures adequate protein for muscle recovery
        - Maintains appropriate calorie balance
        - Includes variety and micronutrients
        - Considers meal timing for performance
        - Respects dietary restrictions
        - Promotes sustainable eating habits
        
        Never recommend extreme diets or unsafe practices. Always emphasize whole foods and balanced nutrition.
        """
    }
    
    private func parseMealSuggestions(from response: String) -> MealSuggestions {
        // Parse the structured response
        var meals: [SuggestedMeal] = []
        let sections = response.components(separatedBy: "MEAL")
        
        for section in sections.dropFirst() {
            let lines = section.components(separatedBy: .newlines)
            var name = ""
            var description = ""
            var calories = 0
            var protein = 0
            var carbs = 0
            var fats = 0
            
            for line in lines {
                if line.contains(":") {
                    let parts = line.split(separator: ":", maxSplits: 1)
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    let value = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
                    
                    switch key {
                    case let k where k.contains("1") || k.contains("2") || k.contains("3"):
                        name = value
                    case "Description":
                        description = value
                    case "Macros":
                        (calories, protein, carbs, fats) = parseMacros(from: value)
                    default:
                        break
                    }
                }
            }
            
            if !name.isEmpty {
                meals.append(SuggestedMeal(
                    name: name,
                    description: description,
                    calories: calories,
                    protein: protein,
                    carbs: carbs,
                    fats: fats
                ))
            }
        }
        
        return MealSuggestions(meals: meals)
    }
    
    private func parseMacros(from text: String) -> (Int, Int, Int, Int) {
        var calories = 0, protein = 0, carbs = 0, fats = 0
        
        if let calMatch = text.firstMatch(of: /(\d+)\s*cal/) {
            calories = Int(String(calMatch.output.1)) ?? 0
        }
        if let proteinMatch = text.firstMatch(of: /(\d+)g?\s*protein/) {
            protein = Int(String(proteinMatch.output.1)) ?? 0
        }
        if let carbMatch = text.firstMatch(of: /(\d+)g?\s*carbs/) {
            carbs = Int(String(carbMatch.output.1)) ?? 0
        }
        if let fatMatch = text.firstMatch(of: /(\d+)g?\s*fats?/) {
            fats = Int(String(fatMatch.output.1)) ?? 0
        }
        
        return (calories, protein, carbs, fats)
    }
    
    private func calculateWeeklyStats() async -> WeeklyDietStats {
        let targetCalories = UserDefaults.standard.integer(forKey: "dailyCalorieGoal")

        let zero = WeeklyDietStats(
            avgCalories: 0,
            avgProtein: 0,
            avgCarbs: 0,
            avgFats: 0,
            targetCalories: targetCalories
        )

        let summaries: [DailyNutritionSummary]
        do {
            summaries = try nutritionService.summaries(endingOn: Date(), days: 7)
        } catch {
            print("Error fetching weekly nutrition: \(error)")
            return zero
        }

        // Average over the days that actually have logging, matching what the
        // previous `CDMeal`-based version did (`dailyTotals.count`).
        let loggedDays = summaries.filter { !$0.isEmpty }
        guard !loggedDays.isEmpty else { return zero }

        let count = Double(loggedDays.count)
        let totals = loggedDays.reduce(NutritionSnapshot.zero) { $0 + $1.totals }

        return WeeklyDietStats(
            avgCalories: Int((totals.calories / count).rounded()),
            avgProtein: Int((totals.protein / count).rounded()),
            avgCarbs: Int((totals.carbs / count).rounded()),
            avgFats: Int((totals.fat / count).rounded()),
            targetCalories: targetCalories
        )
    }

    private func extractRecommendations(from analysis: String) -> [String] {
        // Extract numbered recommendations
        var recommendations: [String] = []
        let lines = analysis.components(separatedBy: .newlines)
        
        for line in lines {
            if let match = line.firstMatch(of: /^\d+\.\s+(.+)$/) {
                recommendations.append(String(match.output.1))
            }
        }
        
        return recommendations
    }
    
    private func calculateCompliance(stats: WeeklyDietStats) -> Double {
        guard stats.targetCalories > 0 else { return 0 }
        
        let calorieCompliance = 1.0 - abs(Double(stats.avgCalories - stats.targetCalories)) / Double(stats.targetCalories)
        return max(0, min(1, calorieCompliance)) * 100
    }
}

// MARK: - Diet Models

struct MealSuggestions {
    let meals: [SuggestedMeal]
}

struct SuggestedMeal {
    let name: String
    let description: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fats: Int
}

struct DietAnalysis {
    let summary: String
    let recommendations: [String]
    let compliance: Double
}

struct WeeklyDietStats {
    let avgCalories: Int
    let avgProtein: Int
    let avgCarbs: Int
    let avgFats: Int
    let targetCalories: Int
}