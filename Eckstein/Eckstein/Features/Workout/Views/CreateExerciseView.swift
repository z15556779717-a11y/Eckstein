//
//  CreateExerciseView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

struct CreateExerciseView: View {
    @StateObject private var viewModel: CreateExerciseViewModel
    @Environment(\.dismiss) private var dismiss
    let onSave: (CDExercise) -> Void
    
    init(repository: WorkoutRepository, onSave: @escaping (CDExercise) -> Void) {
        self._viewModel = StateObject(wrappedValue: CreateExerciseViewModel(repository: repository))
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("exercise_details".localized) {
                    TextField("exercise_name".localized, text: $viewModel.name)

                    Picker("muscle_group".localized, selection: $viewModel.muscleGroup) {
                        ForEach(ExerciseData.muscleGroups.filter { $0 != "All" }, id: \.self) { group in
                            Text(group).tag(group)
                        }
                    }
                    
                    Picker("category".localized, selection: $viewModel.category) {
                        ForEach(ExerciseData.categories.filter { $0 != "All" }, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    
                    Picker("equipment".localized, selection: $viewModel.equipment) {
                        ForEach(ExerciseData.equipment.filter { $0 != "All" }, id: \.self) { equipment in
                            Text(equipment).tag(equipment)
                        }
                    }
                    
                    Toggle("compound_exercise".localized, isOn: $viewModel.isCompound)
                }
                
                Section {
                    TextField("create_exercise_notes_optional".localized, text: $viewModel.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("create_exercise_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save".localized) {
                        if let exercise = viewModel.saveExercise() {
                            onSave(exercise)
                        }
                    }
                    .disabled(viewModel.name.isEmpty)
                }
            }
        }
    }
}

class CreateExerciseViewModel: ObservableObject {
    @Published var name = ""
    @Published var muscleGroup = "Chest"
    @Published var category = "Push"
    @Published var equipment = "Barbell"
    @Published var isCompound = false
    @Published var notes = ""
    
    let repository: WorkoutRepository
    
    init(repository: WorkoutRepository) {
        self.repository = repository
    }
    
    func saveExercise() -> CDExercise? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        
        let exercise = repository.createExercise(
            name: trimmedName,
            muscleGroup: muscleGroup,
            category: category,
            equipment: equipment,
            notes: notes.isEmpty ? nil : notes
        )
        
        return exercise
    }
}