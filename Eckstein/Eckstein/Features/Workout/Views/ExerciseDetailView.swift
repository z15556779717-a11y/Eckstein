//
//  ExerciseDetailView.swift
//  Eckstein
//
//  Created by Assistant on 16/01/2025.
//

import SwiftUI
import AVKit

struct ExerciseDetailView: View {
    let exercise: CDExercise
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showingYouTubePlayer = false
    @State private var showingEditView = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Exercise Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text(exercise.name ?? "Unknown Exercise")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 16) {
                            Label(exercise.muscleGroup ?? "", systemImage: "figure.strengthtraining.traditional")
                            Label(exercise.category ?? "", systemImage: "tag")
                            if let equipment = exercise.equipment {
                                Label(equipment, systemImage: "dumbbell")
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Exercise Image
                    if let imageData = exercise.imageData,
                       let uiImage = UIImage(data: imageData) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("exercise_image".localized)
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 300)
                                .cornerRadius(12)
                                .padding(.horizontal)
                        }
                    }
                    
                    // YouTube Link
                    if let youtubeLink = exercise.youtubeLink, !youtubeLink.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("video_tutorial".localized)
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Button(action: {
                                if let url = URL(string: youtubeLink) {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "play.rectangle.fill")
                                        .font(.title2)
                                        .foregroundColor(.red)
                                    
                                    VStack(alignment: .leading) {
                                        Text("watch_on_youtube".localized)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text(youtubeLink)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.up.forward")
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Created Date
                    if let createdAt = exercise.createdAt {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.secondary)
                            Text("added_on".localized(DateFormatter.mediumDate.string(from: createdAt)))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Exercise Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Edit") {
                        showingEditView = true
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingEditView) {
                CreateCustomExerciseView(
                    viewModel: ExerciseListViewModel(repository: WorkoutRepository()),
                    exerciseToEdit: exercise
                )
            }
        }
    }
}

extension DateFormatter {
    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}