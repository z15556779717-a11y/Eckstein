//
//  WorkoutHistoryView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

struct WorkoutHistoryView: View {
    @StateObject private var viewModel: WorkoutHistoryViewModel
    @State private var selectedDate = Date()
    @State private var showingCalendar = false
    @Environment(\.dismiss) private var dismiss
    var onSelectWorkout: ((CDWorkout) -> Void)?
    
    init(repository: WorkoutRepository, onSelectWorkout: ((CDWorkout) -> Void)? = nil) {
        self._viewModel = StateObject(wrappedValue: WorkoutHistoryViewModel(repository: repository))
        self.onSelectWorkout = onSelectWorkout
    }
    
    var body: some View {
        ZStack {
                VStack(spacing: 0) {
                // Calendar Header
                HStack {
                    Button {
                        showingCalendar.toggle()
                    } label: {
                        HStack {
                            Image(systemName: "calendar")
                            Text(selectedDate, format: .dateTime.month(.wide).year())
                            Image(systemName: showingCalendar ? "chevron.up" : "chevron.down")
                        }
                        .font(.headline)
                    }
                    
                    Spacer()
                    
                    // Filter Menu
                    Menu {
                        Button("all_workouts".localized) {
                            viewModel.filterType = .all
                        }
                        Button("this_week".localized) {
                            viewModel.filterType = .week
                        }
                        Button("this_month".localized) {
                            viewModel.filterType = .month
                        }
                    } label: {
                        HStack {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            Text(viewModel.filterType.localizedName)
                        }
                        .font(.subheadline)
                    }
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                
                // Calendar View
                if showingCalendar {
                    CalendarView(
                        selectedDate: $selectedDate,
                        workoutDates: viewModel.workoutDates
                    )
                    .padding()
                    .background(Color(.systemGroupedBackground))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Divider()
                
                // Stats Summary
                HStack(spacing: 20) {
                    StatCard(
                        title: "total_workouts".localized,
                        value: "\(viewModel.filteredWorkouts.count)",
                        icon: "dumbbell"
                    )
                    
                    StatCard(
                        title: "this_week".localized,
                        value: "\(viewModel.weeklyWorkoutCount)",
                        icon: "calendar"
                    )
                    
                    StatCard(
                        title: "streak".localized,
                        value: "\(viewModel.currentStreak) \("days".localized)",
                        icon: "flame"
                    )
                }
                .padding()
                
                // Workout List
                if viewModel.filteredWorkouts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("no_workouts_found".localized)
                            .font(.headline)
                        Text("start_new_workout".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.groupedWorkouts, id: \.key) { section in
                            Section(header: Text(section.key)) {
                                ForEach(Array(section.value.enumerated()), id: \.element.id) { index, workout in
                                    NavigationLink(destination: WorkoutPreviewView(
                                        workout: workout,
                                        onStartWorkout: {
                                            if let onSelect = onSelectWorkout {
                                                onSelect(workout)
                                                dismiss()
                                            }
                                        }
                                    )) {
                                        WorkoutHistoryRow(workout: workout)
                                    }
                                    .if(index == 0 && section.key == viewModel.groupedWorkouts.first?.key) { view in
                                        view.tooltip(
                                            "swipe_left_delete_workouts".localized,
                                            tipId: TipManager.TipID.workoutSwipe,
                                            position: .below
                                        )
                                    }
                                }
                                .onDelete { offsets in
                                    viewModel.deleteWorkouts(at: offsets, in: section.value)
                                }
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
                }
                
                // Confetti overlay
                if viewModel.showConfetti {
                    VStack {
                        Text("workout_complete".localized)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                            .padding()
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(20)
                            .shadow(radius: 10)
                            .padding(.top, 100)
                        
                        Spacer()
                    }
                    .zIndex(1)
                    
                    ConfettiView()
                        .zIndex(2)
                        .onAppear {
                            // Hide confetti after 3 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                viewModel.showConfetti = false
                            }
                        }
                }
            }
            .navigationTitle("workout_history".localized)
            .navigationBarTitleDisplayMode(.large)
            .animation(.default, value: showingCalendar)
        .onAppear {
            viewModel.loadWorkouts()
        }
    }
}

struct CalendarView: View {
    @Binding var selectedDate: Date
    let workoutDates: Set<DateComponents>
    
    var body: some View {
        // Simple calendar grid - in production would use FSCalendar or similar
        VStack {
            // Month navigation
            HStack {
                Button {
                    selectedDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
                } label: {
                    Image(systemName: "chevron.left")
                }
                
                Spacer()
                
                Text(selectedDate, format: .dateTime.month(.wide).year())
                    .font(.headline)
                
                Spacer()
                
                Button {
                    selectedDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            
            // Calendar grid would go here
            Text("calendar_implementation".localized)
                .foregroundColor(.secondary)
                .padding()
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            
            Text(value)
                .font(.title3)
                .bold()
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct WorkoutHistoryRow: View {
    let workout: CDWorkout
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(workout.name ?? "workout".localized)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if workout.durationMinutes > 0 {
                    Text("\(workout.durationMinutes) " + "min".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                // Exercise count
                Label({
                    let count = Set(workout.setsArray.compactMap { $0.exercise }).count
                    return count == 1 ? "exercise_count_singular".localized : "exercises_count".localized(count)
                }(), systemImage: "figure.strengthtraining.traditional")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Total sets
                Label("sets_count".localized(workout.setsArray.count), systemImage: "number.square")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

class WorkoutHistoryViewModel: ObservableObject {
    @Published var workouts: [CDWorkout] = []
    @Published var filterType: FilterType = .all
    @Published var selectedWorkout: CDWorkout?
    @Published var showConfetti = false
    
    let repository: WorkoutRepository
    
    enum FilterType: String {
        case all = "All"
        case week = "This Week"
        case month = "This Month"
        
        var localizedName: String {
            switch self {
            case .all: return "all_workouts".localized
            case .week: return "this_week".localized  
            case .month: return "this_month".localized
            }
        }
    }
    
    var filteredWorkouts: [CDWorkout] {
        switch filterType {
        case .all:
            return workouts
        case .week:
            let weekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
            return workouts.filter { ($0.date ?? Date()) >= weekAgo }
        case .month:
            let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            return workouts.filter { ($0.date ?? Date()) >= monthAgo }
        }
    }
    
    var groupedWorkouts: [(key: String, value: [CDWorkout])] {
        let grouped = Dictionary(grouping: filteredWorkouts) { workout -> String in
            guard let date = workout.date else { return "unknown".localized }
            
            let calendar = Calendar.current
            if calendar.isDateInToday(date) {
                return "today".localized
            } else if calendar.isDateInYesterday(date) {
                return "yesterday".localized
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return formatter.string(from: date)
            }
        }
        
        return grouped.sorted { first, second in
            // Sort by date, with Today first
            if first.key == "Today" { return true }
            if second.key == "Today" { return false }
            if first.key == "Yesterday" { return true }
            if second.key == "Yesterday" { return false }
            return first.key > second.key
        }
    }
    
    var workoutDates: Set<DateComponents> {
        Set(workouts.compactMap { workout in
            guard let date = workout.date else { return nil }
            return Calendar.current.dateComponents([.year, .month, .day], from: date)
        })
    }
    
    var weeklyWorkoutCount: Int {
        let weekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        return workouts.filter { ($0.date ?? Date()) >= weekAgo }.count
    }
    
    var currentStreak: Int {
        // Calculate workout streak
        var streak = 0
        var checkDate = Date()
        let calendar = Calendar.current
        
        while true {
            let hasWorkout = workouts.contains { workout in
                guard let workoutDate = workout.date else { return false }
                return calendar.isDate(workoutDate, inSameDayAs: checkDate)
            }
            
            if hasWorkout {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else {
                break
            }
        }
        
        return streak
    }
    
    init(repository: WorkoutRepository) {
        self.repository = repository
    }
    
    func loadWorkouts() {
        repository.fetchWorkouts()
        workouts = repository.workouts
    }
    
    func deleteWorkouts(at offsets: IndexSet, in sectionWorkouts: [CDWorkout]) {
        for offset in offsets {
            let workout = sectionWorkouts[offset]
            repository.delete(workout)
        }
        loadWorkouts()
    }
}