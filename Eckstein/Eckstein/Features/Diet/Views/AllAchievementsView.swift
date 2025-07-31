//
//  AllAchievementsView.swift
//  Eckstein
//
//  Created by Assistant on 17/01/2025.
//

import SwiftUI

struct AllAchievementsView: View {
    @ObservedObject var achievementManager: AchievementManager
    @State private var selectedAchievement: Achievement?
    @State private var showingDetail = false
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    progressSummaryCard
                    achievementsGrid
                }
                .padding()
            }
            .navigationTitle("All Achievements")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingDetail) {
            if let achievement = selectedAchievement {
                AchievementDetailView(
                    achievement: achievement,
                    progress: achievementManager.getProgress(for: achievement.id)
                )
            }
        }
    }
    
    private var earnedCount: Int {
        achievementManager.achievements.filter { $0.isEarned }.count
    }
    
    private var totalCount: Int {
        achievementManager.achievements.count
    }
    
    private var progressPercentage: Int {
        guard totalCount > 0 else { return 0 }
        return Int((Double(earnedCount) / Double(totalCount)) * 100)
    }
    
    private var progressSummaryCard: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Total Progress")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(earnedCount) of \(totalCount)")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            progressCircle
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var progressCircle: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                .frame(width: 80, height: 80)
            
            Circle()
                .trim(from: 0, to: CGFloat(earnedCount) / CGFloat(max(1, totalCount)))
                .stroke(themeManager.accentColor.color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(-90))
            
            Text("\(progressPercentage)%")
                .font(.title3)
                .fontWeight(.bold)
        }
    }
    
    private var achievementsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(achievementManager.achievements) { achievement in
                BadgeView(
                    achievement: achievement,
                    progress: achievementManager.getProgress(for: achievement.id)
                )
                .onTapGesture {
                    selectedAchievement = achievement
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showingDetail = true
                    }
                }
            }
        }
    }
}