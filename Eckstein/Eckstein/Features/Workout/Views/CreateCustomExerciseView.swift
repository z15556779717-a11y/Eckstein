//
//  CreateCustomExerciseView.swift
//  Eckstein
//
//  Created by Assistant on 16/01/2025.
//

import SwiftUI
import PhotosUI

struct CreateCustomExerciseView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: ExerciseListViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    
    // Optional exercise for editing
    let exerciseToEdit: CDExercise?
    
    init(viewModel: ExerciseListViewModel, exerciseToEdit: CDExercise? = nil) {
        self.viewModel = viewModel
        self.exerciseToEdit = exerciseToEdit
    }
    
    @State private var exerciseName = ""
    @State private var selectedMuscleGroup = "Chest"
    @State private var selectedCategory = "Push"
    @State private var selectedEquipment = "Dumbbell"
    @State private var youtubeLink = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var exerciseImage: Image?
    @State private var imageData: Data?
    
    private let muscleGroups = ["Chest", "Back", "Shoulders", "Legs", "Biceps", "Triceps", "Core"]
    private let categories = ["Push", "Pull", "Legs", "Core"]
    private let equipment = ["Barbell", "Dumbbell", "Cable", "Machine", "Bodyweight", "Other"]
    
    var body: some View {
        NavigationView {
            Form {
                // Exercise Name
                Section("exercise_details".localized) {
                    TextField("exercise_name".localized, text: $exerciseName)
                        .autocapitalization(.words)

                    Picker("muscle_group".localized, selection: $selectedMuscleGroup) {
                        ForEach(muscleGroups, id: \.self) { group in
                            Text(group).tag(group)
                        }
                    }
                    
                    Picker("category".localized, selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    
                    Picker("equipment".localized, selection: $selectedEquipment) {
                        ForEach(equipment, id: \.self) { equip in
                            Text(equip).tag(equip)
                        }
                    }
                }
                
                // Media Section
                Section("media_optional".localized) {
                    // YouTube Link
                    HStack {
                        Image(systemName: "play.rectangle.fill")
                            .foregroundColor(.red)
                        TextField("youtube_link".localized, text: $youtubeLink)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                    }
                    
                    // Image Picker
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack {
                            Image(systemName: "photo")
                                .foregroundColor(themeManager.accentColor.color)
                            
                            if let exerciseImage = exerciseImage {
                                exerciseImage
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 100)
                                    .cornerRadius(8)
                            } else {
                                Text("add_exercise_image".localized)
                                    .foregroundColor(themeManager.accentColor.color)
                            }
                            
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle(exerciseToEdit == nil ? "create_exercise_title".localized : "edit_exercise".localized)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let exercise = exerciseToEdit {
                    exerciseName = exercise.name ?? ""
                    selectedMuscleGroup = exercise.muscleGroup ?? "Chest"
                    selectedCategory = exercise.category ?? "Push"
                    selectedEquipment = exercise.equipment ?? "Dumbbell"
                    youtubeLink = exercise.youtubeLink ?? ""
                    if let data = exercise.imageData {
                        imageData = data
                        if let uiImage = UIImage(data: data) {
                            exerciseImage = Image(uiImage: uiImage)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save".localized) {
                        saveExercise()
                    }
                    .disabled(exerciseName.isEmpty)
                }
            }
            .onChange(of: selectedPhoto) { _ in
                Task {
                    if let selectedPhoto = selectedPhoto {
                        if let data = try? await selectedPhoto.loadTransferable(type: Data.self) {
                            if let uiImage = UIImage(data: data) {
                                exerciseImage = Image(uiImage: uiImage)
                                imageData = data
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func saveExercise() {
        if let exercise = exerciseToEdit {
            // Update existing exercise
            viewModel.updateExercise(
                exercise,
                name: exerciseName,
                muscleGroup: selectedMuscleGroup,
                category: selectedCategory,
                equipment: selectedEquipment,
                youtubeLink: youtubeLink.isEmpty ? nil : youtubeLink,
                imageData: imageData
            )
        } else {
            // Create new exercise
            viewModel.createCustomExercise(
                name: exerciseName,
                muscleGroup: selectedMuscleGroup,
                category: selectedCategory,
                equipment: selectedEquipment,
                youtubeLink: youtubeLink.isEmpty ? nil : youtubeLink,
                imageData: imageData
            )
        }
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    CreateCustomExerciseView(viewModel: ExerciseListViewModel(repository: WorkoutRepository()))
}