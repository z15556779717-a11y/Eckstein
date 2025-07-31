//
//  AchievementDetailView.swift
//  Eckstein
//
//  Created by Assistant on 17/01/2025.
//

import SwiftUI

struct AchievementDetailView: View {
    let achievement: Achievement
    let progress: (current: Int, required: Int)?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Achievement icon
                ZStack {
                    Circle()
                        .fill(achievement.isEarned ? achievement.displayColor.opacity(0.2) : Color.gray.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    if !achievement.isEarned, let progress = progress {
                        // Progress ring for unearned achievements
                        Circle()
                            .trim(from: 0, to: CGFloat(progress.current) / CGFloat(progress.required))
                            .stroke(
                                achievement.displayColor,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut, value: progress.current)
                    }
                    
                    Image(systemName: achievement.isEarned ? achievement.icon : "lock.fill")
                        .font(.system(size: 50))
                        .foregroundColor(achievement.isEarned ? achievement.displayColor : .gray)
                }
                
                // Achievement info
                VStack(spacing: 16) {
                    Text(achievement.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(achievement.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Divider()
                    
                    VStack(spacing: 12) {
                        Label("How to earn", systemImage: "target")
                            .font(.headline)
                            .foregroundColor(achievement.displayColor)
                        
                        Text(achievement.requirement)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    if let progress = progress, !achievement.isEarned {
                        Divider()
                        
                        VStack(spacing: 8) {
                            Text("Progress")
                                .font(.headline)
                            
                            HStack {
                                Text("\(progress.current)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(achievement.displayColor)
                                
                                Text("/ \(progress.required)")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                            
                            ProgressView(value: Double(progress.current), total: Double(progress.required))
                                .tint(achievement.displayColor)
                                .scaleEffect(x: 1, y: 2)
                        }
                    }
                    
                    if achievement.isEarned, let earnedDate = achievement.earnedDate {
                        Divider()
                        
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.green)
                            
                            Text("Earned on")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(earnedDate, style: .date)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                }
                .padding()
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}