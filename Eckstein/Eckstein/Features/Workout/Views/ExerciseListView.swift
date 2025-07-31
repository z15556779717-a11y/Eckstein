//
//  ExerciseListView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

struct ExerciseListView: View {
    @StateObject private var viewModel: ExerciseListViewModel
    @Environment(\.dismiss) private var dismiss
    let onSelect: (CDExercise) -> Void
    
    init(repository: WorkoutRepository, onSelect: @escaping (CDExercise) -> Void) {
        self._viewModel = StateObject(wrappedValue: ExerciseListViewModel(repository: repository))
        self.onSelect = onSelect
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchBar
                filterSection
                Divider()
                exerciseListContent
            }
            .navigationTitle("select_exercise".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.showCreateExercise = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showCreateExercise) {
                CreateCustomExerciseView(viewModel: viewModel)
            }
        }
        .onAppear {
            viewModel.loadData()
        }
    }
    
    // MARK: - View Components
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("search_exercises".localized, text: $viewModel.searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                muscleFilterChip
                categoryFilterChip
                equipmentFilterChip
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }
    
    private var muscleFilterChip: some View {
        FilterChipView(
            title: "\("muscle".localized): \(viewModel.selectedMuscleGroup)",
            isSelected: viewModel.selectedMuscleGroup != "All",
            menu: {
                ForEach(ExerciseData.muscleGroups, id: \.self) { group in
                    Button(group) {
                        viewModel.selectedMuscleGroup = group
                    }
                }
            }
        )
    }
    
    private var categoryFilterChip: some View {
        FilterChipView(
            title: "\("category".localized): \(viewModel.selectedCategory)",
            isSelected: viewModel.selectedCategory != "All",
            menu: {
                ForEach(ExerciseData.categories, id: \.self) { category in
                    Button(category) {
                        viewModel.selectedCategory = category
                    }
                }
            }
        )
    }
    
    private var equipmentFilterChip: some View {
        FilterChipView(
            title: "\("equipment".localized): \(viewModel.selectedEquipment)",
            isSelected: viewModel.selectedEquipment != "All",
            menu: {
                ForEach(ExerciseData.equipment, id: \.self) { equipment in
                    Button(equipment) {
                        viewModel.selectedEquipment = equipment
                    }
                }
            }
        )
    }
    
    private var exerciseListContent: some View {
        Group {
            if viewModel.exercises.isEmpty || (viewModel.filteredExercises.isEmpty && !viewModel.searchText.isEmpty) {
                emptyStateView
            } else {
                exerciseList
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: viewModel.exercises.isEmpty ? "dumbbell" : "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(viewModel.exercises.isEmpty ? "no_exercises_yet".localized : "no_exercises_found".localized)
                .font(.headline)
            
            if viewModel.exercises.isEmpty {
                Text("create_first_custom_exercise".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("create_custom_exercise".localized) {
                viewModel.showCreateExercise = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var exerciseList: some View {
        List {
            // Recent Exercises Section
            if !viewModel.recentExercises.isEmpty && viewModel.searchText.isEmpty {
                Section("recent".localized) {
                    ForEach(viewModel.recentExercises) { exercise in
                        ExerciseRowView(exercise: exercise, onTap: {
                            onSelect(exercise)
                            dismiss()
                        }, viewModel: viewModel)
                    }
                }
            }
            
            // All Exercises
            Section(viewModel.searchText.isEmpty ? "all_exercises".localized : "search_results".localized) {
                ForEach(viewModel.filteredExercises) { exercise in
                    ExerciseRowView(exercise: exercise, onTap: {
                        onSelect(exercise)
                        dismiss()
                    }, viewModel: viewModel)
                }
                .onDelete { indices in
                    indices.forEach { index in
                        let exercise = viewModel.filteredExercises[index]
                        viewModel.deleteExercise(exercise)
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
}

struct ExerciseRowView: View {
    let exercise: CDExercise
    let onTap: () -> Void
    let viewModel: ExerciseListViewModel
    @State private var showingDetail = false
    @State private var showingEdit = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name ?? "")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    Label(exercise.muscleGroup ?? "", systemImage: "figure.strengthtraining.traditional")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let equipment = exercise.equipment, equipment != "Other" {
                        Label(equipment, systemImage: "dumbbell")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                if exercise.youtubeLink != nil || exercise.imageData != nil {
                    Button(action: { showingDetail = true }) {
                        HStack(spacing: 8) {
                            if exercise.youtubeLink != nil {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            
                            if exercise.imageData != nil {
                                Image(systemName: "photo.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                
                Button(action: onTap) {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button(action: { 
                showingEdit = true 
            }) {
                Label("edit_exercise".localized, systemImage: "pencil")
            }
            
            Button(action: { showingDetail = true }) {
                Label("view_details".localized, systemImage: "info.circle")
            }
        }
        .sheet(isPresented: $showingDetail) {
            ExerciseDetailView(exercise: exercise)
        }
        .sheet(isPresented: $showingEdit) {
            CreateCustomExerciseView(viewModel: viewModel, exerciseToEdit: exercise)
        }
    }
}

struct FilterChipView<MenuContent: View>: View {
    let title: String
    let isSelected: Bool
    @ViewBuilder let menu: () -> MenuContent
    
    var body: some View {
        Menu {
            menu()
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
    }
}

class ExerciseListViewModel: ObservableObject {
    @Published var exercises: [CDExercise] = []
    @Published var recentExercises: [CDExercise] = []
    @Published var searchText = ""
    @Published var selectedMuscleGroup = "All"
    @Published var selectedCategory = "All"
    @Published var selectedEquipment = "All"
    @Published var showCreateExercise = false
    
    let repository: WorkoutRepository
    
    var filteredExercises: [CDExercise] {
        exercises.filter { exercise in
            let matchesSearch = searchText.isEmpty || 
                (exercise.name ?? "").localizedCaseInsensitiveContains(searchText)
            
            let matchesMuscle = selectedMuscleGroup == "All" || 
                exercise.muscleGroup == selectedMuscleGroup
            
            let matchesCategory = selectedCategory == "All" || 
                exercise.category == selectedCategory
            
            let matchesEquipment = selectedEquipment == "All" || 
                exercise.equipment == selectedEquipment
            
            return matchesSearch && matchesMuscle && matchesCategory && matchesEquipment
        }
    }
    
    init(repository: WorkoutRepository) {
        self.repository = repository
    }
    
    func loadData() {
        // Only fetch custom exercises
        exercises = repository.fetchAllExercises().filter { $0.isCustom }
        
        // Fetch recent exercises (last 5 used) - only custom ones
        recentExercises = repository.fetchRecentExercises(limit: 5).filter { $0.isCustom }
    }
    
    func createCustomExercise(name: String, muscleGroup: String, category: String, equipment: String, youtubeLink: String? = nil, imageData: Data? = nil) {
        let exercise = repository.createExercise(
            name: name,
            muscleGroup: muscleGroup,
            category: category,
            equipment: equipment,
            isCustom: true
        )
        
        // Set additional properties
        exercise.youtubeLink = youtubeLink
        exercise.imageData = imageData
        
        repository.save()
        loadData()
    }
    
    func updateExercise(_ exercise: CDExercise, name: String, muscleGroup: String, category: String, equipment: String, youtubeLink: String? = nil, imageData: Data? = nil) {
        exercise.name = name
        exercise.muscleGroup = muscleGroup
        exercise.category = category
        exercise.equipment = equipment
        exercise.youtubeLink = youtubeLink
        exercise.imageData = imageData
        
        repository.save()
        loadData()
    }
    
    func deleteExercise(_ exercise: CDExercise) {
        repository.deleteExercise(exercise)
        loadData()
    }
}