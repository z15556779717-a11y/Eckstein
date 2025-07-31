//
//  CreateWorkoutView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

struct CreateWorkoutView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @StateObject private var typeManager = WorkoutTypeManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var showCreateWorkoutType = false
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationView {
            VStack {
                if typeManager.workoutTypes.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("no_workout_types".localized)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("create_workout_types_first".localized)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        Button(action: { showCreateWorkoutType = true }) {
                            Label("create_workout_type".localized, systemImage: "plus.circle.fill")
                                .padding()
                                .background(themeManager.accentColor == .defaultMix ? 
                                          themeManager.accentColor.contextColor(for: .workout) : 
                                          themeManager.accentColor.color)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                } else {
                    List {
                        Section(header: Text("select_todays_workout".localized)) {
                            ForEach(typeManager.workoutTypes, id: \.id) { workoutType in
                                WorkoutTypeSelectionRow(
                                    workoutType: workoutType,
                                    onSelect: {
                                        if let workout = typeManager.createWorkoutFromType(workoutType) {
                                            viewModel.fetchWorkouts()
                                            dismiss()
                                            // Navigate to workout detail
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                NotificationCenter.default.post(
                                                    name: Notification.Name("NavigateToWorkout"),
                                                    object: workout
                                                )
                                            }
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("start_workout".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
                
                if !typeManager.workoutTypes.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showCreateWorkoutType = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreateWorkoutType) {
                CreateWorkoutTypeView()
            }
        }
        .onAppear {
            typeManager.fetchWorkoutTypes()
        }
    }
}

struct WorkoutTypeSelectionRow: View {
    let workoutType: CDWorkoutType
    let onSelect: () -> Void
    
    private var exerciseCount: Int {
        (workoutType.exercises as? Set<CDWorkoutTypeExercise>)?.count ?? 0
    }
    
    private var lastWorkoutInfo: String {
        if let lastUsed = workoutType.lastUsed {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: lastUsed, relativeTo: Date())
        }
        return "never".localized
    }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                Text(workoutType.name ?? "unnamed_workout".localized)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack {
                    Label(exerciseCount == 1 ? "exercise_count_singular".localized : "exercises_count".localized(exerciseCount), systemImage: "figure.strengthtraining.traditional")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\("last".localized): \(lastWorkoutInfo)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}