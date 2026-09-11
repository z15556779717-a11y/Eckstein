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
    /// The built-in exercise library.
    ///
    /// This was deliberately emptied at one point — users were expected to
    /// create every movement themselves — which left a new install with a
    /// training screen that could not be filled in without typing "Bench Press"
    /// first. The fifteen here are the standard barbell and machine movements
    /// the templates and the AI plan generator already refer to by name.
    ///
    /// Seeded once, by name: `ExerciseCatalogSeed` adds only what the store does
    /// not already have, so a user with their own "Squat" does not get a second
    /// one, and nothing is ever deleted. Users can still create their own; see
    /// `CreateCustomExerciseView`.
    static let exercises: [ExerciseTemplate] = [
        ExerciseTemplate(name: "Bench Press", muscleGroup: "Chest", category: "Push", equipment: "Barbell", isCompound: true),
        ExerciseTemplate(name: "Incline Bench Press", muscleGroup: "Chest", category: "Push", equipment: "Barbell", isCompound: true),
        ExerciseTemplate(name: "Squat", muscleGroup: "Legs", category: "Legs", equipment: "Barbell", isCompound: true),
        ExerciseTemplate(name: "Deadlift", muscleGroup: "Back", category: "Pull", equipment: "Barbell", isCompound: true),
        ExerciseTemplate(name: "Overhead Press", muscleGroup: "Shoulders", category: "Push", equipment: "Barbell", isCompound: true),
        ExerciseTemplate(name: "Pull Up", muscleGroup: "Back", category: "Pull", equipment: "Bodyweight", isCompound: true),
        ExerciseTemplate(name: "Lat Pulldown", muscleGroup: "Back", category: "Pull", equipment: "Cable", isCompound: true),
        ExerciseTemplate(name: "Barbell Row", muscleGroup: "Back", category: "Pull", equipment: "Barbell", isCompound: true),
        ExerciseTemplate(name: "Dumbbell Row", muscleGroup: "Back", category: "Pull", equipment: "Dumbbell", isCompound: true),
        ExerciseTemplate(name: "Biceps Curl", muscleGroup: "Biceps", category: "Pull", equipment: "Dumbbell", isCompound: false),
        ExerciseTemplate(name: "Triceps Extension", muscleGroup: "Triceps", category: "Push", equipment: "Cable", isCompound: false),
        ExerciseTemplate(name: "Leg Press", muscleGroup: "Legs", category: "Legs", equipment: "Machine", isCompound: true),
        ExerciseTemplate(name: "Leg Curl", muscleGroup: "Legs", category: "Legs", equipment: "Machine", isCompound: false),
        ExerciseTemplate(name: "Leg Extension", muscleGroup: "Legs", category: "Legs", equipment: "Machine", isCompound: false),
        ExerciseTemplate(name: "Lateral Raise", muscleGroup: "Shoulders", category: "Push", equipment: "Dumbbell", isCompound: false)
    ]

    static let muscleGroups = ["All", "Chest", "Back", "Shoulders", "Legs", "Biceps", "Triceps", "Core"]
    static let categories = ["All", "Push", "Pull", "Legs", "Core"]
    static let equipment = ["All", "Barbell", "Dumbbell", "Cable", "Machine", "Bodyweight", "Other"]
}
