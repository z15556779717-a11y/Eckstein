//
//  WeightAchievementsView.swift
//  Eckstein
//
//  Created by Assistant on 23/07/2025.
//

import SwiftUI

struct WeightAchievementsView: View {
    @ObservedObject var viewModel: WeightViewModel
    let period: WeightAnalyticsView.AnalyticsPeriod
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    private var achievements: [WeightAchievement] {
        calculateAchievements()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("achievements".localized)
                .font(.headline)
            
            if achievements.isEmpty {
                Text("no_achievements_yet".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(achievements) { achievement in
                        WeightAchievementCard(achievement: achievement, themeManager: themeManager)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private func calculateAchievements() -> [WeightAchievement] {
        var achievements: [WeightAchievement] = []
        let entries = viewModel.repository.fetchWeightEntries(for: period.dateRange)
            .sorted { ($0.date ?? Date()) < ($1.date ?? Date()) }
        
        // First Entry Achievement
        if !entries.isEmpty {
            achievements.append(WeightAchievement(
                id: "first_entry",
                title: "first_weigh_in".localized,
                description: "started_journey".localized,
                icon: "flag.fill",
                color: .green,
                isUnlocked: true
            ))
        }
        
        // Weight Loss Milestones
        if let firstWeight = entries.first?.weightKg,
           let latestWeight = entries.last?.weightKg {
            let totalLoss = firstWeight - latestWeight
            
            if totalLoss >= 1 {
                achievements.append(WeightAchievement(
                    id: "1kg_lost",
                    title: "1kg_milestone".localized,
                    description: "lost_1kg".localized,
                    icon: "star.fill",
                    color: .blue,
                    isUnlocked: true
                ))
            }
            
            if totalLoss >= 5 {
                achievements.append(WeightAchievement(
                    id: "5kg_lost",
                    title: "5kg_milestone".localized,
                    description: "lost_5kg".localized,
                    icon: "star.circle.fill",
                    color: .purple,
                    isUnlocked: true
                ))
            }
            
            if totalLoss >= 10 {
                achievements.append(WeightAchievement(
                    id: "10kg_lost",
                    title: "10kg_milestone".localized,
                    description: "lost_10kg".localized,
                    icon: "rosette",
                    color: .orange,
                    isUnlocked: true
                ))
            }
        }
        
        // Consistency Achievements
        let consecutiveDays = calculateConsecutiveDays(entries)
        
        if consecutiveDays >= 7 {
            achievements.append(WeightAchievement(
                id: "week_streak",
                title: "week_streak".localized,
                description: "7_days_tracking".localized,
                icon: "flame.fill",
                color: .red,
                isUnlocked: true
            ))
        }
        
        if consecutiveDays >= 30 {
            achievements.append(WeightAchievement(
                id: "month_streak",
                title: "month_streak".localized,
                description: "30_days_tracking".localized,
                icon: "flame.circle.fill",
                color: .orange,
                isUnlocked: true
            ))
        }
        
        // Goal Achievement
        if let goalWeight = viewModel.goalWeight,
           let currentWeight = entries.last?.weightKg,
           currentWeight <= goalWeight {
            achievements.append(WeightAchievement(
                id: "goal_reached",
                title: "goal_reached".localized,
                description: "reached_target_weight".localized,
                icon: "trophy.fill",
                color: .yellow,
                isUnlocked: true
            ))
        }
        
        // Add locked achievements as hints
        if achievements.count < 3 {
            achievements.append(WeightAchievement(
                id: "next_milestone",
                title: "next_milestone".localized,
                description: "keep_going".localized,
                icon: "lock.fill",
                color: .gray,
                isUnlocked: false
            ))
        }
        
        return achievements
    }
    
    private func calculateConsecutiveDays(_ entries: [CDWeightEntry]) -> Int {
        guard !entries.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        var maxStreak = 0
        var currentStreak = 1
        
        for i in 1..<entries.count {
            guard let prevDate = entries[i-1].date,
                  let currDate = entries[i].date else { continue }
            
            let daysBetween = calendar.dateComponents([.day], from: prevDate, to: currDate).day ?? 0
            
            if daysBetween == 1 {
                currentStreak += 1
                maxStreak = max(maxStreak, currentStreak)
            } else {
                currentStreak = 1
            }
        }
        
        return max(maxStreak, 1)
    }
}

struct WeightAchievement: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isUnlocked: Bool
}

struct WeightAchievementCard: View {
    let achievement: WeightAchievement
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: achievement.icon)
                .font(.largeTitle)
                .foregroundColor(achievement.isUnlocked ? achievement.color : .gray)
                .opacity(achievement.isUnlocked ? 1.0 : 0.5)
            
            Text(achievement.title)
                .font(.caption)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .foregroundColor(achievement.isUnlocked ? .primary : .secondary)
            
            Text(achievement.description)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .opacity(achievement.isUnlocked ? 1.0 : 0.5)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(achievement.isUnlocked ? 
                      Color(.systemBackground) : 
                      Color(.systemGray5))
                .shadow(color: achievement.isUnlocked ? 
                        achievement.color.opacity(0.3) : 
                        Color.clear, radius: 4)
        )
    }
}