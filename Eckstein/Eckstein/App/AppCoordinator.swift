//
//  AppCoordinator.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI
import Combine
import Supabase

class AppCoordinator: ObservableObject {
    @Published var selectedTab: Tab = .home
    @Published var isAuthenticated = false
    @Published var showOnboarding = false
    @Published var currentUser: User?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupAuthObserver()
    }
    
    private func setupAuthObserver() {
        Task { @MainActor in
            // Observe authentication state changes
            AuthService.shared.$isAuthenticated
                .sink { [weak self] isAuthenticated in
                    self?.isAuthenticated = isAuthenticated
                }
                .store(in: &cancellables)
            
            // Observe current user changes
            AuthService.shared.$currentUser
                .sink { [weak self] user in
                    self?.currentUser = user
                    // Store user ID for TipManager
                    if let userId = user?.id.uuidString {
                        UserDefaults.standard.set(userId, forKey: "currentUserId")
                        NotificationCenter.default.post(name: .init("UserDidChange"), object: nil)
                    }
                }
                .store(in: &cancellables)
        }
    }
    
    /// The six primary destinations, in the order they appear in the tab bar:
    /// 首页 / 饮食 / 训练 / 趋势 / AI / 我的.
    ///
    /// `home` is the Dashboard and is where a launch lands. `weight` is gone as a
    /// tab: the weight log and its trends are the body of the `progress` tab, and
    /// keeping both would have put seven items in the bar — past the point where
    /// iOS folds the extras into a "More" list and the last two tabs stop being
    /// reachable in one tap.
    enum Tab: Int, CaseIterable {
        case home = 0
        case diet = 1
        case workout = 2
        case progress = 3
        case ai = 4
        case profile = 5

        var title: String {
            switch self {
            case .home: return "tab_home".localized
            case .diet: return "tab_diet".localized
            case .workout: return "tab_workout".localized
            case .progress: return "tab_progress".localized
            case .ai: return "tab_ai_coach".localized
            case .profile: return "tab_profile".localized
            }
        }

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .diet: return "fork.knife"
            case .workout: return "figure.strengthtraining.traditional"
            case .progress: return "chart.line.uptrend.xyaxis"
            case .ai: return "bubble.left.and.bubble.right"
            case .profile: return "person.circle"
            }
        }
    }

    func handleDeepLink(_ url: URL) {
        // Prepare for future deep linking
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return
        }

        switch components.path {
        case "/home":
            selectedTab = .home
        case "/workout":
            selectedTab = .workout
        case "/diet":
            selectedTab = .diet
        // `/weight` still resolves, and now lands on the tab that holds the
        // weight log. Repointing it rather than dropping it keeps any link
        // already in the wild working.
        case "/weight", "/progress":
            selectedTab = .progress
        case "/ai":
            selectedTab = .ai
        case "/profile":
            selectedTab = .profile
        default:
            break
        }
    }

    func signOut() async {
        do {
            try await AuthService.shared.signOut()
            // Reset to first tab after sign out
            await MainActor.run {
                selectedTab = .home
            }
        } catch {
            print("Error signing out: \(error)")
        }
    }
}