//
//  CDWorkout+Extensions.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//
//

import Foundation
import CoreData

extension CDWorkout {
    var setsArray: [CDWorkoutSet] {
        let set = sets as? Set<CDWorkoutSet> ?? []
        return set.sorted { $0.setNumber < $1.setNumber }
    }
    
    /// Total volume, via the one implementation in `WorkoutMetrics`.
    ///
    /// Kept as a property because callers already read it as one; the formula
    /// itself lives in the business layer so the chart, the AI summary and the
    /// tests cannot drift apart.
    var totalVolume: Double {
        WorkoutMetrics.workoutVolume(self)
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(date ?? Date())
    }
    
    var completionPercentage: Double {
        let allSets = setsArray
        guard !allSets.isEmpty else { return 0 }
        
        let completedSets = allSets.filter { set in
            // A set is considered complete if it has reps > 0 and is marked as completed
            return set.reps > 0 && set.completed
        }
        
        return (Double(completedSets.count) / Double(allSets.count)) * 100
    }
    
    var isCompleted: Bool {
        // Consider workout completed if more than 90% of exercises are accomplished
        return completionPercentage >= 90
    }
    
    static func create(
        name: String,
        date: Date,
        in context: NSManagedObjectContext
    ) -> CDWorkout {
        let workout = CDWorkout(context: context)
        workout.id = UUID()
        workout.name = name
        workout.date = date
        workout.completed = false
        workout.syncStatus = "pending"
        return workout
    }
}