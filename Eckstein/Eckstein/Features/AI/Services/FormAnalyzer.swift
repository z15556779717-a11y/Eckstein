//
//  FormAnalyzer.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation

@MainActor
class FormAnalyzer {
    private let openAIService = OpenAIService.shared
    
    private let exerciseDatabase: [String: ExerciseInfo] = [
        "squat": ExerciseInfo(
            name: "Squat",
            muscleGroups: ["quadriceps", "glutes", "hamstrings", "core"],
            equipment: ["barbell", "dumbbells", "bodyweight"],
            difficulty: "intermediate"
        ),
        "bench press": ExerciseInfo(
            name: "Bench Press",
            muscleGroups: ["chest", "triceps", "shoulders"],
            equipment: ["barbell", "dumbbells"],
            difficulty: "intermediate"
        ),
        "deadlift": ExerciseInfo(
            name: "Deadlift",
            muscleGroups: ["hamstrings", "glutes", "back", "core"],
            equipment: ["barbell"],
            difficulty: "advanced"
        ),
        "pull-up": ExerciseInfo(
            name: "Pull-up",
            muscleGroups: ["back", "biceps", "core"],
            equipment: ["pull-up bar"],
            difficulty: "intermediate"
        )
    ]
    
    func getFormGuidance(for exercise: String) async throws -> FormGuidance {
        let exerciseInfo = findExerciseInfo(for: exercise)
        
        let prompt = """
        Provide detailed form guidance for \(exerciseInfo?.name ?? exercise):
        
        Include:
        1. Starting position
        2. Movement execution (step by step)
        3. Common mistakes to avoid
        4. Breathing pattern
        5. Safety tips
        6. Beginner modifications
        7. Advanced variations
        
        Format clearly with sections and bullet points.
        """
        
        let messages = [
            OpenAIMessage(role: "system", content: getFormSystemPrompt()),
            OpenAIMessage(role: "user", content: prompt)
        ]
        
        let response = try await openAIService.sendMessage(messages, temperature: 0.3)
        
        return FormGuidance(
            exercise: exerciseInfo?.name ?? exercise,
            guidance: response,
            muscleGroups: exerciseInfo?.muscleGroups ?? [],
            difficulty: exerciseInfo?.difficulty ?? "intermediate"
        )
    }
    
    func getQuickTips(for exercise: String) async throws -> [String] {
        let prompt = """
        Give me 5 quick form tips for \(exercise) in bullet points.
        Keep each tip concise (one sentence).
        Focus on the most important safety and effectiveness points.
        """
        
        let messages = [
            OpenAIMessage(role: "system", content: getFormSystemPrompt()),
            OpenAIMessage(role: "user", content: prompt)
        ]
        
        let response = try await openAIService.sendMessage(messages, temperature: 0.3)
        
        return extractBulletPoints(from: response)
    }
    
    func compareExercises(_ exercise1: String, _ exercise2: String) async throws -> ExerciseComparison {
        let prompt = """
        Compare \(exercise1) vs \(exercise2):
        
        1. Muscle activation differences
        2. Difficulty level
        3. Equipment requirements
        4. When to choose each one
        5. Progression path
        
        Keep it practical and actionable.
        """
        
        let messages = [
            OpenAIMessage(role: "system", content: getFormSystemPrompt()),
            OpenAIMessage(role: "user", content: prompt)
        ]
        
        let response = try await openAIService.sendMessage(messages, temperature: 0.5)
        
        return ExerciseComparison(
            exercise1: exercise1,
            exercise2: exercise2,
            comparison: response
        )
    }
    
    private func getFormSystemPrompt() -> String {
        """
        You are a certified personal trainer and movement specialist with expertise in:
        - Biomechanics and kinesiology
        - Injury prevention
        - Exercise progression and regression
        - Various training modalities
        
        Provide form guidance that:
        - Prioritizes safety above all else
        - Uses clear, anatomical cues
        - Addresses common compensations
        - Offers modifications for different levels
        - Emphasizes proper breathing
        - Includes mobility prerequisites when relevant
        
        Always remind users to start with light weight and focus on form before progressing.
        """
    }
    
    private func findExerciseInfo(for query: String) -> ExerciseInfo? {
        let lowercased = query.lowercased()
        
        // Direct match
        if let info = exerciseDatabase[lowercased] {
            return info
        }
        
        // Partial match
        for (key, info) in exerciseDatabase {
            if lowercased.contains(key) || key.contains(lowercased) {
                return info
            }
        }
        
        return nil
    }
    
    private func extractBulletPoints(from text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        var tips: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("•") || trimmed.hasPrefix("-") || trimmed.hasPrefix("*") {
                let tip = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                tips.append(String(tip))
            } else if let match = trimmed.firstMatch(of: /^\d+\.\s+(.+)$/) {
                tips.append(String(match.output.1))
            }
        }
        
        return tips
    }
}

// MARK: - Form Models

struct ExerciseInfo {
    let name: String
    let muscleGroups: [String]
    let equipment: [String]
    let difficulty: String
}

struct FormGuidance {
    let exercise: String
    let guidance: String
    let muscleGroups: [String]
    let difficulty: String
}

struct ExerciseComparison {
    let exercise1: String
    let exercise2: String
    let comparison: String
}