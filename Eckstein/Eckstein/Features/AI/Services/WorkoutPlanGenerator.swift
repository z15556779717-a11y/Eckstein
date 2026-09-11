//
//  WorkoutPlanGenerator.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation
import CoreData

@MainActor
class WorkoutPlanGenerator {
    private let openAIService = OpenAIService.shared
    private let contextBuilder = AIContextBuilder()
    
    func generateWorkoutPlan(
        duration: Int = 60,
        equipment: [String] = ["dumbbells", "barbell", "bodyweight"],
        focusArea: String? = nil
    ) async throws -> WorkoutPlan {
        let context = await contextBuilder.buildContext()
        
        let prompt = buildWorkoutPrompt(
            duration: duration,
            equipment: equipment,
            focusArea: focusArea,
            context: context
        )
        
        let messages = [
            OpenAIMessage(role: "system", content: getWorkoutSystemPrompt()),
            OpenAIMessage(role: "user", content: prompt)
        ]
        
        let response = try await openAIService.sendMessage(messages, temperature: 0.5)
        
        return parseWorkoutPlan(from: response)
    }
    
    private func buildWorkoutPrompt(
        duration: Int,
        equipment: [String],
        focusArea: String?,
        context: AICoachContext
    ) -> String {
        var prompt = """
        Create a \(duration)-minute workout plan with the following requirements:
        - Available equipment: \(equipment.joined(separator: ", "))
        """
        
        if let focus = focusArea {
            prompt += "\n- Focus area: \(focus)"
        }
        
        prompt += """
        
        User context:
        - Goals: \(context.userGoals.joined(separator: ", "))
        - Recent activity: \(context.recentActivitySummary)
        - Current stats: \(context.currentStats)
        
        Format the response as:
        WORKOUT PLAN
        Duration: X minutes
        Focus: [area]
        
        WARM-UP (5 minutes)
        1. [Exercise] - [duration/reps]
        
        MAIN WORKOUT
        1. [Exercise] - [sets] x [reps] @ [weight/intensity]
           Rest: [seconds]
           Notes: [form tips]
        
        COOL-DOWN (5 minutes)
        1. [Exercise] - [duration]
        """
        
        return prompt
    }
    
    private func getWorkoutSystemPrompt() -> String {
        """
        You are an expert personal trainer creating safe, effective workout plans. Follow these principles:
        - Progressive overload based on user's recent performance
        - Proper warm-up and cool-down
        - Balance between muscle groups
        - Appropriate rest periods
        - Clear form cues for safety
        - Modifications for different fitness levels
        
        Always prioritize safety and proper form over intensity.
        """
    }
    
    private func parseWorkoutPlan(from response: String) -> WorkoutPlan {
        // Parse the structured response into a WorkoutPlan object
        let lines = response.components(separatedBy: .newlines)
        var exercises: [PlannedExercise] = []
        var duration = 60
        var focus = "Full Body"
        
        // Simple parsing logic - in production, use more robust parsing
        for line in lines {
            if line.contains("Duration:") {
                if let match = line.firstMatch(of: /(\d+)/)?.output.1 {
                    duration = Int(String(match)) ?? 60
                }
            } else if line.contains("Focus:") {
                focus = line.replacingOccurrences(of: "Focus:", with: "").trimmingCharacters(in: .whitespaces)
            } else if let exerciseMatch = line.firstMatch(of: /^\d+\.\s+(.+?)\s+-\s+(.+)$/) {
                let exerciseName = String(exerciseMatch.output.1)
                let details = String(exerciseMatch.output.2)
                
                exercises.append(PlannedExercise(
                    name: exerciseName,
                    details: details,
                    sets: parsesets(from: details),
                    reps: parseReps(from: details),
                    weight: parseWeight(from: details),
                    restSeconds: parseRest(from: details)
                ))
            }
        }
        
        return WorkoutPlan(
            name: "\(focus) Workout",
            duration: duration,
            exercises: exercises,
            notes: "AI-generated workout based on your recent activity and goals"
        )
    }
    
    private func parsesets(from details: String) -> Int {
        if let match = details.firstMatch(of: /(\d+)\s*x/) {
            return Int(String(match.output.1)) ?? 3
        }
        return 3
    }
    
    private func parseReps(from details: String) -> String {
        if let match = details.firstMatch(of: /x\s*(\d+(?:-\d+)?)/) {
            return String(match.output.1)
        }
        return "10"
    }
    
    private func parseWeight(from details: String) -> String? {
        if let match = details.firstMatch(of: /@\s*(.+?)(?:\s|$)/) {
            return String(match.output.1)
        }
        return nil
    }
    
    private func parseRest(from details: String) -> Int {
        if let match = details.firstMatch(of: /Rest:\s*(\d+)/) {
            return Int(String(match.output.1)) ?? 60
        }
        return 60
    }
}

// MARK: - Workout Plan Models

struct WorkoutPlan {
    let name: String
    let duration: Int
    let exercises: [PlannedExercise]
    let notes: String
}

struct PlannedExercise {
    let name: String
    let details: String
    let sets: Int
    let reps: String
    let weight: String?
    let restSeconds: Int
}