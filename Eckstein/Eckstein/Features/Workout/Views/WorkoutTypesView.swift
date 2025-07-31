//
//  WorkoutTypesView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 14/07/2025.
//

import SwiftUI

struct WorkoutTypesView: View {
    @StateObject private var typeManager = WorkoutTypeManager.shared
    @State private var showCreateType = false
    @State private var selectedType: CDWorkoutType?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if typeManager.workoutTypes.isEmpty {
                    EmptyWorkoutTypesView(onCreate: { showCreateType = true })
                } else {
                    List {
                        ForEach(typeManager.workoutTypes, id: \.id) { workoutType in
                            WorkoutTypeRow(
                                workoutType: workoutType,
                                onSelect: { selectedType = workoutType }
                            )
                        }
                        .onDelete(perform: deleteTypes)
                    }
                }
            }
            .navigationTitle("workouts".localized)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCreateType = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateType) {
                CreateWorkoutTypeView()
            }
            .sheet(item: $selectedType) { workoutType in
                WorkoutTypeDetailView(workoutType: workoutType)
            }
        }
    }
    
    private func deleteTypes(at offsets: IndexSet) {
        for index in offsets {
            typeManager.deleteWorkoutType(typeManager.workoutTypes[index])
        }
    }
}

struct EmptyWorkoutTypesView: View {
    let onCreate: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("no_workouts".localized)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("create_workout_types_description".localized)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button(action: onCreate) {
                Label("create_workout".localized, systemImage: "plus.circle.fill")
                    .padding()
                    .background(themeManager.accentColor == .defaultMix ? 
                              themeManager.accentColor.contextColor(for: .workout) : 
                              themeManager.accentColor.color)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
}

struct WorkoutTypeRow: View {
    let workoutType: CDWorkoutType
    let onSelect: () -> Void
    
    private var exerciseCount: Int {
        (workoutType.exercises as? Set<CDWorkoutTypeExercise>)?.count ?? 0
    }
    
    private var lastUsedText: String {
        if let lastUsed = workoutType.lastUsed {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
            return formatter.string(from: lastUsed)
        }
        return "never_used".localized
    }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(workoutType.name ?? "unnamed_workout".localized)
                        .font(.headline)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Label(exerciseCount == 1 ? "exercise_count_singular".localized : "exercises_count".localized(exerciseCount), systemImage: "figure.strengthtraining.traditional")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(lastUsedText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct WorkoutTypeDetailView: View {
    let workoutType: CDWorkoutType
    @StateObject private var typeManager = WorkoutTypeManager.shared
    @State private var showingWorkout = false
    @State private var createdWorkout: CDWorkout?
    @State private var showAddExercise = false
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    
    private var exercises: [CDWorkoutTypeExercise] {
        if let exercises = workoutType.exercises as? Set<CDWorkoutTypeExercise> {
            return exercises.sorted { $0.orderIndex < $1.orderIndex }
        }
        return []
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Workout Type Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text(workoutType.name ?? "unnamed_workout".localized)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if let lastUsed = workoutType.lastUsed {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.secondary)
                                Text("last_used".localized + ": \(DateFormatter.workoutDateTime.string(from: lastUsed))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Exercises
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("exercises".localized)
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(action: { showAddExercise = true }) {
                                Label("add".localized, systemImage: "plus.circle")
                                    .font(.subheadline)
                            }
                        }
                        
                        if exercises.isEmpty {
                            Text("no_exercises_added".localized)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            ForEach(exercises, id: \.id) { exercise in
                                WorkoutTypeExerciseRow(
                                    exercise: exercise,
                                    onDelete: {
                                        typeManager.removeExerciseFromWorkoutType(exercise)
                                    }
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Start Workout Button
                    Button(action: startWorkout) {
                        Label("start_workout".localized, systemImage: "play.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(themeManager.accentColor == .defaultMix ? 
                                      themeManager.accentColor.contextColor(for: .workout) : 
                                      themeManager.accentColor.color)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.top)
                }
                .padding()
            }
            .navigationTitle("workout_details".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showAddExercise) {
                ExerciseListView(repository: WorkoutRepository()) { exercise in
                    // Add exercise with default sets/reps
                    typeManager.addExerciseToWorkoutType(workoutType, exercise: exercise, targetSets: 3, targetReps: 10)
                    showAddExercise = false
                }
            }
            .fullScreenCover(item: $createdWorkout) { workout in
                NavigationView {
                    WorkoutDetailView(workout: workout)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("exit".localized) {
                                    createdWorkout = nil
                                }
                            }
                        }
                }
            }
        }
    }
    
    private func startWorkout() {
        if let workout = typeManager.createWorkoutFromType(workoutType) {
            createdWorkout = workout
        }
    }
}

struct WorkoutTypeExerciseRow: View {
    let exercise: CDWorkoutTypeExercise
    let onDelete: () -> Void
    @StateObject private var typeManager = WorkoutTypeManager.shared
    @State private var showingUpdate = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exercise.exercise?.name ?? "unknown_exercise".localized)
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack(spacing: 20) {
                Label("sets_count".localized(exercise.targetSets), systemImage: "number.square")
                    .font(.caption)
                
                Label("\(exercise.targetReps) " + "reps_target".localized, systemImage: "target")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .contextMenu {
            Button("update_targets".localized) {
                showingUpdate = true
            }
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("delete_exercise".localized, systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingUpdate) {
            UpdateExerciseTargetsView(exercise: exercise)
        }
    }
}

struct UpdateExerciseTargetsView: View {
    let exercise: CDWorkoutTypeExercise
    @StateObject private var typeManager = WorkoutTypeManager.shared
    @State private var targetSets: String = ""
    @State private var targetReps: String = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("target_settings".localized)) {
                    HStack {
                        Text("sets".localized)
                        Spacer()
                        TextField("sets".localized, text: $targetSets)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    HStack {
                        Text("target_reps".localized)
                        Spacer()
                        TextField("reps".localized, text: $targetReps)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
                
                Section {
                    Text("target_settings_description".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(exercise.exercise?.name ?? "update_exercise".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save".localized) {
                        saveTargets()
                    }
                    .disabled(targetSets.isEmpty || targetReps.isEmpty)
                }
            }
        }
        .onAppear {
            targetSets = String(exercise.targetSets)
            targetReps = String(exercise.targetReps)
        }
    }
    
    private func saveTargets() {
        guard let sets = Int(targetSets),
              let reps = Int(targetReps) else { return }
        
        typeManager.updateExerciseTargets(exercise, targetSets: sets, targetReps: reps)
        dismiss()
    }
}

struct CreateWorkoutTypeView: View {
    @State private var workoutName = ""
    @StateObject private var typeManager = WorkoutTypeManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("workout_name".localized)) {
                    TextField("enter_workout_name".localized, text: $workoutName)
                }
                
                Section {
                    Text("workout_name_description".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("create_workout".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("create".localized) {
                        createWorkoutType()
                    }
                    .disabled(workoutName.isEmpty)
                }
            }
        }
    }
    
    private func createWorkoutType() {
        _ = typeManager.createWorkoutType(name: workoutName)
        dismiss()
    }
}

