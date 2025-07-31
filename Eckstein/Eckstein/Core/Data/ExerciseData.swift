//
//  ExerciseData.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation

struct ExerciseTemplate {
    let name: String
    let muscleGroup: String
    let category: String
    let equipment: String
    let isCompound: Bool
}

class ExerciseData {
    static let exercises: [ExerciseTemplate] = [
        // Empty - users will create their own custom exercises
    ]
    
    static let muscleGroups = ["All", "Chest", "Back", "Shoulders", "Legs", "Biceps", "Triceps", "Core"]
    static let categories = ["All", "Push", "Pull", "Legs", "Core"]
    static let equipment = ["All", "Barbell", "Dumbbell", "Cable", "Machine", "Bodyweight", "Other"]
}