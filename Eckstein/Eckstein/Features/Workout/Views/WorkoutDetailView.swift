//
//  WorkoutDetailView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI
import CoreData

struct WorkoutDetailView: View {
    let workout: CDWorkout
    var startTime: Date?
    var onWorkoutCompleted: (() -> Void)?
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showAddExercise = false
    @State private var selectedExercise: CDExercise?
    @State private var groupedSets: [(exercise: CDExercise, sets: [CDWorkoutSet])] = []
    @State private var showDeleteConfirmation = false
    @State private var refreshID = UUID()
    @State private var workoutStartTime = Date()
    @State private var elapsedTime = TimeInterval(0)
    @State private var timer: Timer?
    @State private var showBreakTimer = false
    @State private var breakTimerSeconds = 0
    @State private var currentExerciseID: UUID?
    @State private var isReorderMode = false
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                // Timer Section
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("workout_timer".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatTime(elapsedTime))
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(themeManager.accentColor.color)
                        }
                        
                        Spacer()
                        
                        Button(action: { showBreakTimer.toggle() }) {
                            HStack {
                                Image(systemName: "timer")
                                Text("break_timer".localized)
                            }
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(showBreakTimer ? themeManager.accentColor.color : Color(.systemGray6))
                            .foregroundColor(showBreakTimer ? .white : .primary)
                            .cornerRadius(8)
                        }
                    }
                    
                    if showBreakTimer {
                        BreakTimerView(breakTimerSeconds: $breakTimerSeconds)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Workout Info Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("workout_details".localized)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let date = workout.date {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.secondary)
                            Text(date, formatter: DateFormatter.workoutDate)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let notes = workout.notes, !notes.isEmpty {
                        HStack(alignment: .top) {
                            Image(systemName: "note.text")
                                .foregroundColor(.secondary)
                            Text(notes)
                                .font(.body)
                        }
                    }
                }
                
                Divider()
                
                // Exercises and Sets Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("exercises".localized)
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        if !groupedSets.isEmpty {
                            Button(action: { withAnimation { isReorderMode.toggle() } }) {
                                Label(isReorderMode ? "done".localized : "reorder".localized, 
                                      systemImage: isReorderMode ? "checkmark.circle" : "arrow.up.arrow.down")
                                    .font(.subheadline)
                                    .foregroundColor(isReorderMode ? .green : themeManager.accentColor.color)
                            }
                            .padding(.trailing, 8)
                        }
                        
                        Button(action: { showAddExercise = true }) {
                            Label("add_exercise".localized, systemImage: "plus.circle.fill")
                                .font(.subheadline)
                        }
                    }
                    
                    if groupedSets.isEmpty {
                        EmptyExerciseCard(onAdd: { showAddExercise = true })
                    } else {
                        if isReorderMode {
                            // Show reorderable list
                            ForEach(groupedSets, id: \.exercise.id) { group in
                                HStack {
                                    Image(systemName: "line.3.horizontal")
                                        .foregroundColor(.secondary)
                                        .padding(.leading)
                                    
                                    ExerciseSetCard(
                                        exercise: group.exercise,
                                        sets: group.sets,
                                        onAddSet: { },
                                        onDeleteSet: { _ in },
                                        onUpdateSet: { _ in },
                                        onDeleteExercise: { }
                                    )
                                    .disabled(true)
                                    .opacity(0.8)
                                }
                                .id(group.exercise.id)
                                .onDrag {
                                    NSItemProvider(object: group.exercise.id!.uuidString as NSString)
                                }
                                .onDrop(of: [.text], delegate: ExerciseDropDelegate(
                                    exercise: group.exercise,
                                    groupedSets: $groupedSets,
                                    workout: workout,
                                    context: context
                                ))
                            }
                        } else {
                            ForEach(groupedSets, id: \.exercise.id) { group in
                                ExerciseSetCard(
                                    exercise: group.exercise,
                                    sets: group.sets,
                                    onAddSet: { addSet(to: group.exercise) },
                                    onDeleteSet: { deleteSet($0) },
                                    onUpdateSet: { set in
                                        currentExerciseID = group.exercise.id
                                        updateSet(set)
                                        // Maintain scroll position after update
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            if let exerciseID = currentExerciseID {
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    scrollProxy.scrollTo(exerciseID, anchor: .center)
                                                }
                                            }
                                        }
                                    },
                                    onDeleteExercise: { deleteExercise(group.exercise) }
                                )
                                .id(group.exercise.id) // Add ID for ScrollViewReader
                            }
                        }
                    }
                }
                
                // Finish Workout Button
                if workout.completionPercentage >= 90 {
                    Button(action: finishWorkout) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("finish_workout".localized)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeManager.accentColor.color)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                } else {
                    // Progress indicator
                    VStack(spacing: 8) {
                        Text("complete_more_to_finish".localized(Int(90 - workout.completionPercentage)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ProgressView(value: workout.completionPercentage, total: 100)
                            .tint(themeManager.accentColor.color)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                }
            }
            .padding()
        }
        } // End ScrollViewReader
        .id(refreshID)
        .navigationTitle(workout.name ?? "workout".localized)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(themeManager.accentColor == .red ? .red : .red)
                }
            }
        }
        .sheet(isPresented: $showAddExercise) {
            ExerciseListView(repository: WorkoutRepository()) { exercise in
                selectedExercise = exercise
                showAddExercise = false
                addSet(to: exercise)
            }
        }
        .alert("delete_workout".localized, isPresented: $showDeleteConfirmation) {
            Button("cancel".localized, role: .cancel) { }
            Button("delete".localized, role: .destructive) {
                deleteWorkout()
            }
        } message: {
            Text("delete_workout_message".localized)
        }
        .onAppear {
            loadGroupedSets()
            if let passedStartTime = startTime {
                workoutStartTime = passedStartTime
            }
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func loadGroupedSets() {
        guard let sets = workout.sets as? Set<CDWorkoutSet> else { return }
        
        // Filter out any invalid sets and group by exercise
        let validSets = Array(sets).filter { $0.exercise != nil }
        let grouped = Dictionary(grouping: validSets) { $0.exercise! }
        
        groupedSets = grouped.map { (exercise, sets) in
            // Remove duplicates and sort by set number
            let uniqueSets = Array(Set(sets)).sorted { $0.setNumber < $1.setNumber }
            return (exercise, uniqueSets)
        }.sorted { (first, second) in
            // Sort by workout type exercise order if available
            if let workoutType = workout.workoutType,
               let typeExercises = workoutType.exercises as? Set<CDWorkoutTypeExercise> {
                let firstIndex = typeExercises.first(where: { $0.exercise?.id == first.exercise.id })?.orderIndex ?? Int32.max
                let secondIndex = typeExercises.first(where: { $0.exercise?.id == second.exercise.id })?.orderIndex ?? Int32.max
                return firstIndex < secondIndex
            }
            // Fall back to alphabetical sorting if no workout type
            return first.exercise.name ?? "" < second.exercise.name ?? ""
        }
    }
    
    private func addSet(to exercise: CDExercise) {
        let newSet = CDWorkoutSet(context: context)
        newSet.id = UUID()
        newSet.exercise = exercise
        newSet.workout = workout
        let nextSetNumber = Int32(getNextSetNumber(for: exercise))
        newSet.setNumber = nextSetNumber
        newSet.reps = 0
        newSet.weightKg = getLastWeight(for: exercise, setNumber: nextSetNumber)
        newSet.completed = false
        
        // Set target reps based on workout type if available
        if let workoutType = workout.workoutType,
           let typeExercises = workoutType.exercises as? Set<CDWorkoutTypeExercise>,
           let typeExercise = typeExercises.first(where: { $0.exercise?.id == exercise.id }) {
            newSet.targetReps = typeExercise.targetReps
        } else {
            newSet.targetReps = 10 // Default target
        }
        
        do {
            try context.save()
            loadGroupedSets()
            // Force UI refresh to update completion percentage
            refreshID = UUID()
        } catch {
            print("Error adding set: \(error)")
        }
    }
    
    private func deleteSet(_ set: CDWorkoutSet) {
        context.delete(set)
        do {
            try context.save()
            loadGroupedSets()
            // Force UI refresh to update completion percentage
            refreshID = UUID()
        } catch {
            print("Error deleting set: \(error)")
        }
    }
    
    private func deleteExercise(_ exercise: CDExercise) {
        // Delete all sets for this exercise
        if let setsToDelete = groupedSets.first(where: { $0.exercise.id == exercise.id })?.sets {
            setsToDelete.forEach { context.delete($0) }
        }
        
        do {
            try context.save()
            loadGroupedSets()
            // Force UI refresh
            refreshID = UUID()
        } catch {
            print("Error deleting exercise: \(error)")
        }
    }
    
    private func updateSet(_ set: CDWorkoutSet) {
        do {
            try context.save()
            // Force UI refresh to update completion percentage
            refreshID = UUID()
        } catch {
            print("Error updating set: \(error)")
        }
    }
    
    private func getNextSetNumber(for exercise: CDExercise) -> Int {
        let existingSets = groupedSets.first { $0.exercise.id == exercise.id }?.sets ?? []
        return existingSets.count + 1
    }
    
    private func getLastWeight(for exercise: CDExercise, setNumber: Int32? = nil) -> Double {
        // First check if there's a previous set in this workout
        if let existingSets = groupedSets.first(where: { $0.exercise.id == exercise.id })?.sets,
           let lastSet = existingSets.last {
            return lastSet.weightKg
        }
        
        // Otherwise, fetch from previous workouts (excluding current workout)
        let request: NSFetchRequest<CDWorkoutSet> = CDWorkoutSet.fetchRequest()
        
        if let setNum = setNumber {
            // Get weight for specific set number
            request.predicate = NSPredicate(format: "exercise == %@ AND setNumber == %d AND weightKg > 0 AND workout != %@", exercise, setNum, workout)
        } else {
            // Get last weight for any set
            request.predicate = NSPredicate(format: "exercise == %@ AND weightKg > 0 AND workout != %@", exercise, workout)
        }
        
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDWorkoutSet.workout?.date, ascending: false)]
        request.fetchLimit = 1
        
        do {
            if let lastSet = try context.fetch(request).first {
                if let setNum = setNumber {
                    print("Loading weight for \(exercise.name ?? "") set \(setNum): \(lastSet.weightKg)kg")
                } else {
                    print("Loading last weight for \(exercise.name ?? ""): \(lastSet.weightKg)kg")
                }
                return lastSet.weightKg
            } else if setNumber != nil {
                // If no weight found for specific set number, try without set number
                print("No weight found for \(exercise.name ?? "") set \(setNumber!), trying any set")
                return getLastWeight(for: exercise, setNumber: nil)
            }
        } catch {
            print("Error fetching last weight: \(error)")
        }
        
        print("No previous weight found for \(exercise.name ?? ""), using 0")
        return 0
    }
    
    private func deleteWorkout() {
        context.delete(workout)
        do {
            try context.save()
            dismiss()
        } catch {
            print("Error deleting workout: \(error)")
        }
    }
    
    private func finishWorkout() {
        // Mark workout as completed
        workout.completed = true
        // Calculate and save workout duration
        workout.durationMinutes = Int32(elapsedTime / 60)
        do {
            try context.save()
            // Call the completion handler
            onWorkoutCompleted?()
            // Dismiss the view
            dismiss()
        } catch {
            print("Error finishing workout: \(error)")
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedTime = Date().timeIntervalSince(workoutStartTime)
        }
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        let seconds = Int(interval) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

struct BreakTimerView: View {
    @Binding var breakTimerSeconds: Int
    @State private var timer: Timer?
    @State private var isRunning = false
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private let presetTimes = [30, 60, 90, 120, 180]
    
    var body: some View {
        VStack(spacing: 12) {
            Text("break_timer".localized)
                .font(.headline)
            
            Text(formatTime(breakTimerSeconds))
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundColor(isRunning ? themeManager.accentColor.color : .primary)
            
            // Preset buttons
            HStack(spacing: 8) {
                ForEach(presetTimes, id: \.self) { seconds in
                    Button(action: {
                        breakTimerSeconds = seconds
                        startTimer()
                    }) {
                        Text("\(seconds)" + "sec".localized)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5))
                            .cornerRadius(6)
                    }
                }
            }
            
            // Control buttons
            HStack(spacing: 16) {
                Button(action: {
                    if isRunning {
                        pauseTimer()
                    } else {
                        startTimer()
                    }
                }) {
                    HStack {
                        Image(systemName: isRunning ? "pause.fill" : "play.fill")
                        Text(isRunning ? "pause".localized : "start".localized)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(themeManager.accentColor.color)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Button(action: resetTimer) {
                    Text("reset".localized)
                        .font(.subheadline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray5))
        .cornerRadius(12)
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startTimer() {
        isRunning = true
        timer?.invalidate()
        
        if breakTimerSeconds == 0 {
            breakTimerSeconds = 60 // Default 1 minute
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if breakTimerSeconds > 0 {
                breakTimerSeconds -= 1
            } else {
                // Timer finished
                pauseTimer()
                // Play sound or haptic feedback
                #if !targetEnvironment(simulator)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                #endif
            }
        }
    }
    
    private func pauseTimer() {
        isRunning = false
        timer?.invalidate()
    }
    
    private func resetTimer() {
        pauseTimer()
        breakTimerSeconds = 0
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

extension DateFormatter {
    static let workoutDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

// Drop delegate for reordering exercises
struct ExerciseDropDelegate: DropDelegate {
    let exercise: CDExercise
    @Binding var groupedSets: [(exercise: CDExercise, sets: [CDWorkoutSet])]
    let workout: CDWorkout
    let context: NSManagedObjectContext
    
    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.text]).first else { return false }
        
        itemProvider.loadItem(forTypeIdentifier: "public.text", options: nil) { (item, error) in
            guard let data = item as? Data,
                  let uuidString = String(data: data, encoding: .utf8),
                  let draggedExerciseID = UUID(uuidString: uuidString) else { return }
            
            DispatchQueue.main.async {
                // Find indices
                guard let fromIndex = groupedSets.firstIndex(where: { $0.exercise.id == draggedExerciseID }),
                      let toIndex = groupedSets.firstIndex(where: { $0.exercise.id == exercise.id }),
                      fromIndex != toIndex else { return }
                
                // Reorder the array
                withAnimation {
                    let movedItem = groupedSets.remove(at: fromIndex)
                    groupedSets.insert(movedItem, at: toIndex)
                    
                    // Update order indices in workout type if available
                    if let workoutType = workout.workoutType,
                       let typeExercises = workoutType.exercises as? Set<CDWorkoutTypeExercise> {
                        
                        // Update order indices
                        for (index, group) in groupedSets.enumerated() {
                            if let typeExercise = typeExercises.first(where: { $0.exercise?.id == group.exercise.id }) {
                                typeExercise.orderIndex = Int32(index)
                            }
                        }
                        
                        // Save changes
                        do {
                            try context.save()
                        } catch {
                            print("Error saving reorder: \(error)")
                        }
                    }
                }
            }
        }
        
        return true
    }
    
    func dropEntered(info: DropInfo) {
        // Optional: Add visual feedback when dragging over
    }
}