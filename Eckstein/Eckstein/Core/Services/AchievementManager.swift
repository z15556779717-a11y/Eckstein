//
//  AchievementManager.swift
//  Eckstein
//
//  Created by Assistant on 17/01/2025.
//

import Foundation
import SwiftUI

struct Achievement: Identifiable, Codable {
    let id: String
    let icon: String
    let titleKey: String  // Localization key for title
    let descriptionKey: String  // Localization key for description
    let requirementKey: String  // Localization key for requirement
    let color: String // Store color as string for Codable
    var earnedDate: Date?
    
    // Computed properties for localized strings
    var title: String {
        titleKey.localized
    }
    
    var description: String {
        descriptionKey.localized
    }
    
    var requirement: String {
        requirementKey.localized
    }
    
    var isEarned: Bool {
        earnedDate != nil
    }
    
    var displayColor: Color {
        switch color {
        case "yellow": return .yellow
        case "orange": return .orange
        case "purple": return .purple
        case "green": return .green
        case "blue": return .blue
        case "red": return .red
        case "pink": return .pink
        default: return .gray
        }
    }
}

class AchievementManager: ObservableObject {
    @Published var achievements: [Achievement] = []
    @Published var showUnlockPopup = false
    @Published var unlockedAchievement: Achievement?
    
    private let userDefaultsKey = "EcksteinAchievements"
    private let lastCheckKey = "EcksteinLastAchievementCheck"
    
    static let shared = AchievementManager()
    
    private init() {
        setupAchievements()
        loadEarnedAchievements()
    }
    
    private func setupAchievements() {
        achievements = [
            // Beginner achievements
            Achievement(
                id: "first_day",
                icon: "star.fill",
                titleKey: "achievement_first_day_title",
                descriptionKey: "achievement_first_day_desc",
                requirementKey: "achievement_first_day_req",
                color: "yellow"
            ),
            Achievement(
                id: "week_warrior",
                icon: "flame.fill",
                titleKey: "achievement_week_warrior_title",
                descriptionKey: "achievement_week_warrior_desc",
                requirementKey: "achievement_week_warrior_req",
                color: "orange"
            ),
            Achievement(
                id: "two_week_champion",
                icon: "trophy.fill",
                titleKey: "achievement_two_week_champion_title",
                descriptionKey: "achievement_two_week_champion_desc",
                requirementKey: "achievement_two_week_champion_req",
                color: "yellow"
            ),
            Achievement(
                id: "month_master",
                icon: "crown.fill",
                titleKey: "achievement_month_master_title",
                descriptionKey: "achievement_month_master_desc",
                requirementKey: "achievement_month_master_req",
                color: "purple"
            ),
            
            // Macro achievements
            Achievement(
                id: "protein_power",
                icon: "bolt.fill",
                titleKey: "achievement_protein_power_title",
                descriptionKey: "achievement_protein_power_desc",
                requirementKey: "achievement_protein_power_req",
                color: "orange"
            ),
            Achievement(
                id: "carb_master",
                icon: "leaf.fill",
                titleKey: "achievement_carb_master_title",
                descriptionKey: "achievement_carb_master_desc",
                requirementKey: "achievement_carb_master_req",
                color: "green"
            ),
            Achievement(
                id: "macro_balance",
                icon: "scale.3d",
                titleKey: "achievement_macro_balance_title",
                descriptionKey: "achievement_macro_balance_desc",
                requirementKey: "achievement_macro_balance_req",
                color: "blue"
            ),
            
            // Calorie bank achievements
            Achievement(
                id: "bank_saver",
                icon: "building.columns.fill",
                titleKey: "achievement_bank_saver_title",
                descriptionKey: "achievement_bank_saver_desc",
                requirementKey: "achievement_bank_saver_req",
                color: "green"
            ),
            Achievement(
                id: "bank_master",
                icon: "building.columns.circle.fill",
                titleKey: "achievement_bank_master_title",
                descriptionKey: "achievement_bank_master_desc",
                requirementKey: "achievement_bank_master_req",
                color: "purple"
            ),
            
            // Meal timing achievements
            Achievement(
                id: "early_bird",
                icon: "sunrise.fill",
                titleKey: "achievement_early_bird_title",
                descriptionKey: "achievement_early_bird_desc",
                requirementKey: "achievement_early_bird_req",
                color: "orange"
            ),
            Achievement(
                id: "full_day_hero",
                icon: "sun.max.fill",
                titleKey: "achievement_full_day_hero_title",
                descriptionKey: "achievement_full_day_hero_desc",
                requirementKey: "achievement_full_day_hero_req",
                color: "yellow"
            ),
            
            // Variety achievements
            Achievement(
                id: "variety_chef",
                icon: "fork.knife.circle.fill",
                titleKey: "achievement_variety_chef_title",
                descriptionKey: "achievement_variety_chef_desc",
                requirementKey: "achievement_variety_chef_req",
                color: "pink"
            ),
            Achievement(
                id: "carb_cyclist",
                icon: "arrow.triangle.2.circlepath",
                titleKey: "achievement_carb_cyclist_title",
                descriptionKey: "achievement_carb_cyclist_desc",
                requirementKey: "achievement_carb_cyclist_req",
                color: "green"
            ),
            
            // Discipline achievements
            Achievement(
                id: "no_waste_week",
                icon: "leaf.arrow.circlepath",
                titleKey: "achievement_no_waste_week_title",
                descriptionKey: "achievement_no_waste_week_desc",
                requirementKey: "achievement_no_waste_week_req",
                color: "green"
            ),
            Achievement(
                id: "perfect_week",
                icon: "checkmark.seal.fill",
                titleKey: "achievement_perfect_week_title",
                descriptionKey: "achievement_perfect_week_desc",
                requirementKey: "achievement_perfect_week_req",
                color: "blue"
            ),
            Achievement(
                id: "consistency_king",
                icon: "infinity",
                titleKey: "achievement_consistency_king_title",
                descriptionKey: "achievement_consistency_king_desc",
                requirementKey: "achievement_consistency_king_req",
                color: "purple"
            )
        ]
    }
    
    private func loadEarnedAchievements() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let earnedDict = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return
        }
        
        // Update achievements with earned dates
        for i in 0..<achievements.count {
            if let earnedDate = earnedDict[achievements[i].id] {
                achievements[i].earnedDate = earnedDate
            }
        }
    }
    
    private func saveEarnedAchievements() {
        var earnedDict: [String: Date] = [:]
        for achievement in achievements {
            if let date = achievement.earnedDate {
                earnedDict[achievement.id] = date
            }
        }
        
        if let data = try? JSONEncoder().encode(earnedDict) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    func unlockAchievement(withId id: String) {
        guard let index = achievements.firstIndex(where: { $0.id == id }),
              achievements[index].earnedDate == nil else {
            return
        }
        
        achievements[index].earnedDate = Date()
        saveEarnedAchievements()
        
        // Show popup
        unlockedAchievement = achievements[index]
        showUnlockPopup = true
    }
    
    @MainActor
    func checkForNewAchievements(dietViewModel: EcksteinDietViewModel, bankManager: CalorieBankManager) {
        // Prevent checking too frequently
        let lastCheck = UserDefaults.standard.object(forKey: lastCheckKey) as? Date ?? Date.distantPast
        guard Date().timeIntervalSince(lastCheck) > 60 else { return } // Check at most once per minute
        
        UserDefaults.standard.set(Date(), forKey: lastCheckKey)
        
        let stats = dietViewModel.getComplianceStats()
        let weeklyStats = dietViewModel.getWeeklyAnalytics()
        
        // Check "first_day"
        if stats.compliantDays > 0 {
            unlockAchievement(withId: "first_day")
        }
        
        // Check streak achievements
        if stats.currentStreak >= 7 {
            unlockAchievement(withId: "week_warrior")
        }
        if stats.currentStreak >= 14 {
            unlockAchievement(withId: "two_week_champion")
        }
        if stats.currentStreak >= 30 {
            unlockAchievement(withId: "month_master")
        }
        
        // Check macro achievements
        if weeklyStats.averageProteinGrams >= weeklyStats.proteinTarget {
            unlockAchievement(withId: "protein_power")
        }
        if weeklyStats.averageCarbGrams >= weeklyStats.carbTarget {
            unlockAchievement(withId: "carb_master")
        }
        if weeklyStats.averageProteinGrams >= weeklyStats.proteinTarget && 
           weeklyStats.averageCarbGrams >= weeklyStats.carbTarget {
            unlockAchievement(withId: "macro_balance")
        }
        
        // Check calorie bank achievements
        if bankManager.currentBalance >= 1000 {
            unlockAchievement(withId: "bank_saver")
        }
        if bankManager.currentBalance >= 1500 {
            unlockAchievement(withId: "bank_master")
        }
        
        // Check compliance achievement
        if stats.complianceRate >= 0.8 {
            unlockAchievement(withId: "consistency_king")
        }
        
        // Check perfect week
        if weeklyStats.meal1CompletionRate >= 1.0 && weeklyStats.meal2CompletionRate >= 1.0 {
            unlockAchievement(withId: "perfect_week")
        }
        
        // TODO: Add more complex achievement checks for variety, timing, etc.
    }
    
    func getProgress(for achievementId: String) -> (current: Int, required: Int)? {
        // Return progress for achievements that can be partially completed
        // This will be used to show progress rings on badges
        // TODO: Implement based on actual tracking data
        return nil
    }
}