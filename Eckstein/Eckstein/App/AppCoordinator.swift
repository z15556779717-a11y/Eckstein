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
    @Published var selectedTab: Tab = .workout
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
    
    enum Tab: Int, CaseIterable {
        case workout = 0
        case diet = 1
        case weight = 2
        case ai = 3
        case profile = 4
        
        var title: String {
            switch self {
            case .workout: return "tab_workout".localized
            case .diet: return "tab_diet".localized
            case .weight: return "tab_weight".localized
            case .ai: return "tab_ai_coach".localized
            case .profile: return "tab_profile".localized
            }
        }
        
        var icon: String {
            switch self {
            case .workout: return "figure.strengthtraining.traditional"
            case .diet: return "fork.knife"
            case .weight: return "scalemass"
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
        case "/workout":
            selectedTab = .workout
        case "/diet":
            selectedTab = .diet
        case "/weight":
            selectedTab = .weight
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
                selectedTab = .workout
            }
        } catch {
            print("Error signing out: \(error)")
        }
    }
}