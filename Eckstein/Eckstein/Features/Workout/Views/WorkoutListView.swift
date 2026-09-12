//
//  WorkoutListView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

struct WorkoutListView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @State private var showCreateWorkout = false
    @State private var showConfetti = false
    @State private var completedWorkoutId: UUID?
    @State private var justCompletedWorkout = false

    /// Set while the create sheet is open and a workout was created in it.
    ///
    /// The push waits for `onDismiss` rather than happening inside the sheet's
    /// callback: pushing a stack that is still covered by a sheet tends not to
    /// animate, and the sheet is the thing that has to leave first.
    @State private var createdWorkoutAwaitingOpen = false
    @State private var showCreatedWorkout = false

    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                // Quick Stats Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("quick_stats".localized)
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            WorkoutQuickStatCard(
                                title: "this_week".localized,
                                value: "\(viewModel.weeklyWorkoutCount)",
                                subtitle: "workouts".localized,
                                icon: "calendar",
                                color: themeManager.accentColor == .defaultMix ? 
                                     themeManager.accentColor.contextColor(for: .workout) : 
                                     themeManager.accentColor.color
                            )
                            
                            WorkoutQuickStatCard(
                                title: "current_streak".localized,
                                value: "\(viewModel.currentStreak)",
                                subtitle: "days".localized,
                                icon: "flame.fill",
                                color: themeManager.accentColor == .defaultMix ? 
                                     themeManager.accentColor.contextColor(for: .workout) : 
                                     themeManager.accentColor.color
                            )
                            
                            WorkoutQuickStatCard(
                                title: "total".localized,
                                value: "\(viewModel.workouts.count)",
                                subtitle: "workouts".localized,
                                icon: "chart.bar.fill",
                                color: themeManager.accentColor == .defaultMix ? 
                                     themeManager.accentColor.contextColor(for: .workout) : 
                                     themeManager.accentColor.color
                            )
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Active Workout Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("active_workout".localized)
                            .font(.headline)
                        Spacer()
                        NavigationLink(destination: WorkoutHistoryView(
                            repository: viewModel.repository,
                            onSelectWorkout: { workout in
                                viewModel.setActiveWorkout(workout)
                            }
                        )) {
                            Text("history".localized)
                                .font(.subheadline)
                                .foregroundColor(themeManager.accentColor == .defaultMix ? 
                                               themeManager.accentColor.contextColor(for: .workout) : 
                                               themeManager.accentColor.color)
                        }
                    }
                    .padding(.horizontal)
                    
                    if let activeWorkout = viewModel.activeWorkout {
                        NavigationLink(destination: workoutDetail(for: activeWorkout)) {
                            ActiveWorkoutCard(workout: activeWorkout, startTime: viewModel.activeWorkoutStartTime)
                        }
                        .padding(.horizontal)
                    } else {
                        // No Active Workout Card
                        VStack(spacing: 12) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            
                            Text("no_active_workout".localized)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("select_workout_or_create".localized)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .padding(.horizontal)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                
                // Quick Actions
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        NavigationLink(destination: WorkoutTypesView()) {
                            QuickActionButton(
                                title: "workouts".localized,
                                icon: "figure.strengthtraining.traditional",
                                color: themeManager.accentColor == .defaultMix ? 
                                     themeManager.accentColor.contextColor(for: .workout) : 
                                     themeManager.accentColor.color
                            )
                        }
                        
                        NavigationLink(destination: ExerciseListView(repository: ServiceContainer.shared.workoutRepository, onSelect: { _ in })) {
                            QuickActionButton(
                                title: "exercises".localized,
                                icon: "dumbbell",
                                color: themeManager.accentColor == .defaultMix ? 
                                     themeManager.accentColor.contextColor(for: .workout) : 
                                     themeManager.accentColor.color
                            )
                        }
                    }
                    
                    NavigationLink(destination: AnalyticsView()) {
                        QuickActionButton(
                            title: "analytics".localized,
                            icon: "chart.line.uptrend.xyaxis",
                            color: themeManager.accentColor.color
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            }
            
            // Confetti overlay
            if showConfetti {
                VStack {
                    Text("workout_complete".localized)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.accentColor.color)
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
                            showConfetti = false
                            completedWorkoutId = nil
                        }
                    }
            }
        }
        .navigationTitle("workouts".localized)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showCreateWorkout = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreateWorkout, onDismiss: openCreatedWorkout) {
            CreateWorkoutView(
                viewModel: viewModel,
                onCreate: { workout in
                    viewModel.setActiveWorkout(workout)
                    createdWorkoutAwaitingOpen = true
                }
            )
        }
        .navigationDestination(isPresented: $showCreatedWorkout) {
            if let activeWorkout = viewModel.activeWorkout {
                workoutDetail(for: activeWorkout)
            }
        }
        .onAppear {
            viewModel.fetchWorkouts()
            if justCompletedWorkout {
                showConfetti = true
                justCompletedWorkout = false
            }
        }
    }

    // MARK: - Navigation

    /// The detail screen for a workout, with the completion bookkeeping the list
    /// needs.
    ///
    /// Built in one place because the screen is now reachable two ways — from
    /// the active-workout card, and from a push straight after creating one —
    /// and the two must not drift apart.
    private func workoutDetail(for workout: CDWorkout) -> some View {
        WorkoutDetailView(
            workout: workout,
            startTime: viewModel.activeWorkoutStartTime,
            onWorkoutCompleted: {
                justCompletedWorkout = true
                completedWorkoutId = workout.id
                viewModel.clearActiveWorkout()
            }
        )
    }

    /// Opens the workout the create sheet just made, if it made one.
    ///
    /// A cancel leaves the flag clear, so the sheet closing by itself never
    /// navigates.
    private func openCreatedWorkout() {
        guard createdWorkoutAwaitingOpen else { return }
        createdWorkoutAwaitingOpen = false
        showCreatedWorkout = true
    }
}

struct WorkoutQuickStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 140, height: 140)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct RecentWorkoutCard: View {
    let workout: CDWorkout
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.name ?? "workout".localized)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let date = workout.date {
                    Text(DateFormatter.workoutDateTime.string(from: date))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let sets = workout.sets as? Set<CDWorkoutSet>, !sets.isEmpty {
                    let uniqueExercises = Set(sets.compactMap { $0.exercise })
                    Text(uniqueExercises.count == 1 ? "exercise_count_singular".localized : "exercises_count".localized(uniqueExercises.count))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ActiveWorkoutCard: View {
    let workout: CDWorkout
    let startTime: Date?
    @State private var elapsedTime = TimeInterval(0)
    @State private var timer: Timer?
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name ?? "workout".localized)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        // Exercise count
                        if let sets = workout.sets as? Set<CDWorkoutSet>, !sets.isEmpty {
                            let uniqueExercises = Set(sets.compactMap { $0.exercise })
                            Label("exercises_count".localized(uniqueExercises.count), systemImage: "figure.strengthtraining.traditional")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Timer
                        if startTime != nil {
                            Label(formatTime(elapsedTime), systemImage: "timer")
                                .font(.caption)
                                .foregroundColor(themeManager.accentColor.color)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("workout_in_progress".localized)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(themeManager.accentColor.color)
                        .cornerRadius(4)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Progress bar
            ProgressView(value: workout.completionPercentage, total: 100)
                .tint(themeManager.accentColor.color)
        }
        .padding()
        .background(Color(.systemGray6))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(themeManager.accentColor.color, lineWidth: 2)
        )
        .cornerRadius(12)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startTimer() {
        guard let start = startTime else { return }
        elapsedTime = Date().timeIntervalSince(start)
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedTime = Date().timeIntervalSince(start)
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

extension DateFormatter {
    static let workoutDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d 'at' h:mm a"
        return formatter
    }()
}