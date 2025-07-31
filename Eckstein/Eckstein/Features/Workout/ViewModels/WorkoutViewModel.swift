//
//  WorkoutViewModel.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation
import Combine
import CoreData

@MainActor
class WorkoutViewModel: ObservableObject {
    @Published var workouts: [CDWorkout] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var activeWorkout: CDWorkout?
    @Published var activeWorkoutStartTime: Date?
    
    let repository: WorkoutRepository
    private var cancellables = Set<AnyCancellable>()
    
    var recentWorkouts: [CDWorkout] {
        workouts.prefix(5).map { $0 }
    }
    
    var weeklyWorkoutCount: Int {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        
        return workouts.filter { workout in
            guard let date = workout.date else { return false }
            return date >= weekAgo
        }.count
    }
    
    var currentStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        var currentDate = Date()
        
        while true {
            let hasWorkout = workouts.contains { workout in
                guard let date = workout.date else { return false }
                return calendar.isDate(date, inSameDayAs: currentDate)
            }
            
            if hasWorkout {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                break
            }
        }
        
        return streak
    }
    
    init(repository: WorkoutRepository? = nil) {
        self.repository = repository ?? ServiceContainer.shared.workoutRepository
        
        self.repository.$workouts
            .assign(to: &$workouts)
    }
    
    func fetchWorkouts() {
        repository.fetchWorkouts()
    }
    
    func createWorkout(name: String, date: Date) {
        _ = repository.createWorkout(name: name, date: date)
    }
    
    func deleteWorkouts(at offsets: IndexSet) {
        for index in offsets {
            let workout = workouts[index]
            repository.delete(workout)
        }
    }
    
    func setActiveWorkout(_ workout: CDWorkout) {
        activeWorkout = workout
        activeWorkoutStartTime = Date()
    }
    
    func clearActiveWorkout() {
        activeWorkout = nil
        activeWorkoutStartTime = nil
    }
}