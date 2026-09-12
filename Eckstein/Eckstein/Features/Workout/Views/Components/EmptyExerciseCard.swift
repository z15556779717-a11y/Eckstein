//
//  EmptyExerciseCard.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

struct EmptyExerciseCard: View {
    let onAdd: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("empty_exercise_card_no_exercises".localized)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("empty_exercise_card_hint".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: onAdd) {
                Label("empty_exercise_card_add_first".localized, systemImage: "plus")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}