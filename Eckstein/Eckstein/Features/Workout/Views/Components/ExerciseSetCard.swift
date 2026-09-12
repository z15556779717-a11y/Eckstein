//
//  ExerciseSetCard.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI
import CoreData

struct ExerciseSetCard: View {
    let exercise: CDExercise
    let sets: [CDWorkoutSet]
    let onAddSet: () -> Void
    let onDeleteSet: (CDWorkoutSet) -> Void
    let onUpdateSet: (CDWorkoutSet) -> Void
    let onDeleteExercise: () -> Void
    
    @State private var isExpanded = true
    @State private var showingDetail = false
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Exercise Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name ?? "unknown_exercise".localized)
                        .font(.headline)
                    
                    HStack(spacing: 8) {
                        if let category = exercise.category {
                            Text(category)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
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
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    if exercise.youtubeLink != nil || exercise.imageData != nil {
                        Button(action: { showingDetail = true }) {
                            Image(systemName: "info.circle")
                                .foregroundColor(themeManager.accentColor == .defaultMix ? 
                                              themeManager.accentColor.contextColor(for: .workout) : 
                                              themeManager.accentColor.color)
                        }
                    }
                    
                    Menu {
                        Button(role: .destructive, action: onDeleteExercise) {
                            Label("delete_exercise".localized, systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: { withAnimation { isExpanded.toggle() } }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if isExpanded {
                Divider()
                
                // Sets List
                if sets.isEmpty {
                    Text("no_sets_added".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 8) {
                        // Header
                        HStack {
                            Text("set".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 40, alignment: .leading)
                            
                            Text("weight".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 70, alignment: .center)
                            
                            Text("target".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 50, alignment: .center)
                            
                            Text("actual".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 50, alignment: .center)
                            
                            Spacer()
                            
                            Text("done".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 40, alignment: .center)
                        }
                        .padding(.horizontal, 4)
                        
                        ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                            SetRow(
                                set: set,
                                onUpdate: onUpdateSet,
                                onDelete: { onDeleteSet(set) }
                            )
                            .if(index == 0 && exercise == exercise) { view in
                                view.tooltip(
                                    "tap_checkmark_complete_set".localized,
                                    tipId: TipManager.TipID.exerciseComplete,
                                    position: .below
                                )
                            }
                        }
                    }
                }
                
                // Add Set Button
                Button(action: onAddSet) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("add_set".localized)
                    }
                    .font(.subheadline)
                    .foregroundColor(themeManager.accentColor.color)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .sheet(isPresented: $showingDetail) {
            ExerciseDetailView(exercise: exercise)
        }
    }
}

struct SetRow: View {
    @ObservedObject var set: CDWorkoutSet
    let onUpdate: (CDWorkoutSet) -> Void
    let onDelete: () -> Void
    
    @State private var selectedWeight: Double = 0.0
    @State private var selectedReps: Int32 = 0
    @State private var isCompleted: Bool = false
    @State private var showWeightPicker = false
    @State private var showRepsPicker = false
    @ObservedObject private var themeManager = ThemeManager.shared
    
    // Generate weight options from 0 to 220kg with 0.5kg intervals
    private let weightOptions: [Double] = {
        var weights: [Double] = []
        for i in 0...440 {
            weights.append(Double(i) * 0.5)
        }
        return weights
    }()
    
    // Generate reps options from 0 to 40
    private let repsOptions: [Int32] = Array(0...40)
    
    init(set: CDWorkoutSet, onUpdate: @escaping (CDWorkoutSet) -> Void, onDelete: @escaping () -> Void) {
        self.set = set
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self._selectedWeight = State(initialValue: set.weightKg)
        self._selectedReps = State(initialValue: set.reps)
        self._isCompleted = State(initialValue: set.completed)
    }
    
    private var repsColor: Color {
        guard selectedReps > 0 else { return Color.clear }
        
        if selectedReps >= set.targetReps {
            return themeManager.accentColor.color
        } else if selectedReps >= set.targetReps - 1 {
            return themeManager.accentColor.color.opacity(0.7)
        } else {
            return themeManager.accentColor == .red ? .red : themeManager.accentColor.color.opacity(0.5)
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Text("\(set.setNumber)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .leading)
            
            // Weight picker button
            Button(action: { showWeightPicker = true }) {
                Text(selectedWeight == 0 ? "-" : String(format: "%.1f", selectedWeight))
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .frame(width: 70)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .cornerRadius(6)
            }
            .sheet(isPresented: $showWeightPicker) {
                WeightPickerView(selectedWeight: $selectedWeight, weightOptions: weightOptions) {
                    updateSet()
                }
            }
            
            // Target reps (read-only)
            Text("\(set.targetReps)")
                .font(.subheadline)
                .foregroundColor(.blue)
                .frame(width: 50, alignment: .center)
            
            // Actual reps picker button
            Button(action: { showRepsPicker = true }) {
                Text(selectedReps == 0 ? "-" : "\(selectedReps)")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .frame(width: 50)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(repsColor, lineWidth: 1)
                    )
            }
            .sheet(isPresented: $showRepsPicker) {
                RepsPickerView(selectedReps: $selectedReps, repsOptions: repsOptions) {
                    updateSet()
                }
            }
            
            Spacer()
            
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isCompleted ? .green : .secondary)
                .font(.title3)
                .frame(width: 30)
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            .frame(width: 20)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .onAppear {
            selectedWeight = set.weightKg
            selectedReps = set.reps
            isCompleted = set.completed
        }
    }
    
    private func updateSet() {
        // Only update if values actually changed
        if set.weightKg != selectedWeight || set.reps != selectedReps {
            set.weightKg = selectedWeight
            set.reps = selectedReps
            
            // Auto-complete set when actual reps are entered
            if selectedReps > 0 {
                set.completed = true
                isCompleted = true
            } else {
                set.completed = false
                isCompleted = false
            }
            
            onUpdate(set)
        }
    }
}

// Weight Picker View
struct WeightPickerView: View {
    @Binding var selectedWeight: Double
    let weightOptions: [Double]
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationView {
            VStack {
                Text("select_weight".localized)
                    .font(.headline)
                    .padding()
                
                Picker("weight".localized, selection: $selectedWeight) {
                    ForEach(weightOptions, id: \.self) { weight in
                        Text(weight == 0 ? "0 " + "kg".localized : String(format: "%.1f ", weight) + "kg".localized)
                            .tag(weight)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(maxHeight: 200)
                
                Spacer()
            }
            .navigationTitle("weight".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        onDismiss()
                        dismiss()
                    }
                    .foregroundColor(themeManager.accentColor.color)
                }
            }
        }
    }
}

// Reps Picker View
struct RepsPickerView: View {
    @Binding var selectedReps: Int32
    let repsOptions: [Int32]
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationView {
            VStack {
                Text("select_reps".localized)
                    .font(.headline)
                    .padding()
                
                Picker("reps".localized, selection: $selectedReps) {
                    ForEach(repsOptions, id: \.self) { reps in
                        Text(reps == 0 ? "-" : "\(reps)")
                            .tag(reps)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(maxHeight: 200)
                
                Spacer()
            }
            .navigationTitle("reps".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        onDismiss()
                        dismiss()
                    }
                    .foregroundColor(themeManager.accentColor.color)
                }
            }
        }
    }
}