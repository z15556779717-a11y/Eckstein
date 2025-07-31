//
//  TipManager.swift
//  Eckstein
//
//  Created by Eliad Shahar on 23/07/2025.
//

import Foundation
import SwiftUI

@MainActor
class TipManager: ObservableObject {
    static let shared = TipManager()
    
    @Published var showTips: Bool {
        didSet {
            if let userId = getCurrentUserId() {
                UserDefaults.standard.set(showTips, forKey: "showAppTips_\(userId)")
            }
        }
    }
    
    private var seenTips: Set<String> = []
    private let seenTipsKey = "seenTips"
    
    private init() {
        // Initialize showTips with a default value first
        self.showTips = true
        
        // Then load saved preferences
        loadUserPreferences()
        
        // Listen for user changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDidChange),
            name: .init("UserDidChange"),
            object: nil
        )
    }
    
    @objc private func userDidChange() {
        loadUserPreferences()
    }
    
    private func loadUserPreferences() {
        if let userId = getCurrentUserId() {
            let key = "showAppTips_\(userId)"
            if UserDefaults.standard.exists(key: key) {
                self.showTips = UserDefaults.standard.bool(forKey: key)
            } else {
                // Default to true for new users
                self.showTips = true
            }
            loadSeenTips(userId: userId)
        }
    }
    
    // MARK: - Public Methods
    
    func shouldShowTip(_ tipId: String) -> Bool {
        guard showTips else { return false }
        return !seenTips.contains(tipId)
    }
    
    func markTipAsSeen(_ tipId: String) {
        seenTips.insert(tipId)
        saveSeenTips()
    }
    
    func resetAllTips() {
        seenTips.removeAll()
        saveSeenTips()
    }
    
    func resetTip(_ tipId: String) {
        seenTips.remove(tipId)
        saveSeenTips()
    }
    
    // MARK: - Private Methods
    
    private func getCurrentUserId() -> String? {
        // Try to get from UserDefaults or AppCoordinator
        return UserDefaults.standard.string(forKey: "currentUserId")
    }
    
    private func loadSeenTips(userId: String) {
        let key = "\(seenTipsKey)_\(userId)"
        if let data = UserDefaults.standard.data(forKey: key),
           let tips = try? JSONDecoder().decode(Set<String>.self, from: data) {
            seenTips = tips
        }
    }
    
    private func saveSeenTips() {
        guard let userId = getCurrentUserId() else { return }
        let key = "\(seenTipsKey)_\(userId)"
        
        if let data = try? JSONEncoder().encode(seenTips) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - Tip IDs

extension TipManager {
    enum TipID {
        // Workout tips
        static let workoutSwipe = "tip_workout_swipe"
        static let workoutLongPress = "tip_workout_longpress"
        static let exerciseComplete = "tip_exercise_complete"
        static let exerciseNotes = "tip_exercise_notes"
        
        // Diet tips
        static let mealSwipe = "tip_meal_swipe"
        static let foodSearch = "tip_food_search"
        static let calorieBank = "tip_calorie_bank"
        static let dietNavigation = "tip_diet_navigation"
        
        // Weight tips
        static let weightTap = "tip_weight_tap"
        static let weightGoal = "tip_weight_goal"
        static let scaleConnect = "tip_scale_connect"
        
        // General tips
        static let tabNavigation = "tip_tab_navigation"
        static let aiCoach = "tip_ai_coach"
    }
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    func exists(key: String) -> Bool {
        return object(forKey: key) != nil
    }
}