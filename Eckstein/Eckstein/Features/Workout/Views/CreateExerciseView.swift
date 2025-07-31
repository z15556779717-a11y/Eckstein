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
                Section("Exercise Details") {
                    TextField("Exercise Name", text: $viewModel.name)
                    
                    Picker("Muscle Group", selection: $viewModel.muscleGroup) {
                        ForEach(ExerciseData.muscleGroups.filter { $0 != "All" }, id: \.self) { group in
                            Text(group).tag(group)
                        }
                    }
                    
                    Picker("Category", selection: $viewModel.category) {
                        ForEach(ExerciseData.categories.filter { $0 != "All" }, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    
                    Picker("Equipment", selection: $viewModel.equipment) {
                        ForEach(ExerciseData.equipment.filter { $0 != "All" }, id: \.self) { equipment in
                            Text(equipment).tag(equipment)
                        }
                    }
                    
                    Toggle("Compound Exercise", isOn: $viewModel.isCompound)
                }
                
                Section {
                    TextField("Notes (optional)", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Create Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
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