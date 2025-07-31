//
//  WorkoutPreviewView.swift
//  Eckstein
//
//  Created by Assistant on 13/07/2025.
//

import SwiftUI
import CoreData

struct WorkoutPreviewView: View {
    let workout: CDWorkout
    let onStartWorkout: () -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var groupedSets: [(exercise: CDExercise, sets: [CDWorkoutSet])] = []
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Workout Info Card
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(workout.name ?? "workout".localized)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            if let date = workout.date {
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.secondary)
                                    Text(date, formatter: DateFormatter.workoutDate)
                                        .foregroundColor(.secondary)
                                }
                                .font(.subheadline)
                            }
                        }
                        
                        Spacer()
                        
                        // Completion Badge
                        if workout.completed {
                            VStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.green)
                                Text("completed".localized)
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    if let notes = workout.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("notes".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(notes)
                                .font(.body)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Workout Stats
                HStack(spacing: 16) {
                    StatBox(
                        title: "exercises".localized,
                        value: "\(groupedSets.count)",
                        icon: "figure.strengthtraining.traditional"
                    )
                    
                    StatBox(
                        title: "total_sets".localized,
                        value: "\(groupedSets.reduce(0) { $0 + $1.sets.count })",
                        icon: "number.square"
                    )
                    
                    StatBox(
                        title: "duration".localized,
                        value: workout.durationMinutes > 0 ? "\(workout.durationMinutes) " + "min".localized : "-",
                        icon: "timer"
                    )
                }
                
                // Exercise List
                VStack(alignment: .leading, spacing: 12) {
                    Text("exercises".localized)
                        .font(.headline)
                    
                    ForEach(groupedSets, id: \.exercise.id) { group in
                        ExercisePreviewCard(
                            exercise: group.exercise,
                            sets: group.sets
                        )
                    }
                }
                
                // Start Workout Button
                if !workout.completed {
                    Button(action: onStartWorkout) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .font(.title3)
                            Text("start_workout".localized)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeManager.accentColor.color)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.top)
                }
            }
            .padding()
        }
        .navigationTitle("workout_details".localized)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadGroupedSets()
        }
    }
    
    private func loadGroupedSets() {
        guard let sets = workout.sets as? Set<CDWorkoutSet> else { return }
        
        let validSets = Array(sets).filter { $0.exercise != nil }
        let grouped = Dictionary(grouping: validSets) { $0.exercise! }
        
        groupedSets = grouped.map { (exercise, sets) in
            let uniqueSets = Array(Set(sets)).sorted { $0.setNumber < $1.setNumber }
            return (exercise, uniqueSets)
        }.sorted { $0.exercise.name ?? "" < $1.exercise.name ?? "" }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(themeManager.accentColor.color)
            
            Text(value)
                .font(.headline)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct ExercisePreviewCard: View {
    let exercise: CDExercise
    let sets: [CDWorkoutSet]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exercise.name ?? "unknown_exercise".localized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if let category = exercise.category {
                    Text(category)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                }
            }
            
            // Sets Summary
            HStack(spacing: 16) {
                ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                    VStack(spacing: 4) {
                        Text("set".localized + " \(index + 1)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 4) {
                            if set.weightKg > 0 {
                                Text("\(Int(set.weightKg))" + "kg".localized)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            
                            if set.completed {
                                Text("×")
                                    .foregroundColor(.secondary)
                                Text("\(set.reps)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                            } else if set.targetReps > 0 {
                                Text("×")
                                    .foregroundColor(.secondary)
                                Text("\(set.targetReps)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if index < sets.count - 1 {
                        Divider()
                            .frame(height: 30)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

