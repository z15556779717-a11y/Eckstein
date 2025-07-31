//
//  WorkoutRowView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

struct WorkoutRowView: View {
    let workout: CDWorkout
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(workout.name ?? "Unnamed Workout")
                .font(.headline)
            
            if let date = workout.date {
                Text(date, formatter: DateFormatter.workoutDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label("\(workout.setsArray.count) sets", systemImage: "list.number")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if workout.completed {
                    Label("Completed", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }
}