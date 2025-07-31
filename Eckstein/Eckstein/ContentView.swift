//
//  ContentView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var container = ServiceContainer.shared
    @StateObject private var syncManager = SyncManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Sync Status Bar
            SyncStatusView()
                .zIndex(1)
            
            // Main Tab View
            TabView(selection: $coordinator.selectedTab) {
                WorkoutTabView()
                    .tag(AppCoordinator.Tab.workout)
                    .tabItem {
                        Label(
                            AppCoordinator.Tab.workout.title,
                            systemImage: AppCoordinator.Tab.workout.icon
                        )
                    }
                    .badge(coordinator.selectedTab == .workout ? nil : syncBadgeForTab(.workout))
                
                DietTabView()
                    .tag(AppCoordinator.Tab.diet)
                    .tabItem {
                        Label(
                            AppCoordinator.Tab.diet.title,
                            systemImage: AppCoordinator.Tab.diet.icon
                        )
                    }
                    .badge(coordinator.selectedTab == .diet ? nil : syncBadgeForTab(.diet))
                
                WeightTabView()
                    .tag(AppCoordinator.Tab.weight)
                    .tabItem {
                        Label(
                            AppCoordinator.Tab.weight.title,
                            systemImage: AppCoordinator.Tab.weight.icon
                        )
                    }
                    .badge(coordinator.selectedTab == .weight ? nil : syncBadgeForTab(.weight))
                
                AICoachTabView()
                    .tag(AppCoordinator.Tab.ai)
                    .tabItem {
                        Label(
                            AppCoordinator.Tab.ai.title,
                            systemImage: AppCoordinator.Tab.ai.icon
                        )
                    }
                
                ProfileView()
                    .tag(AppCoordinator.Tab.profile)
                    .tabItem {
                        Label(
                            AppCoordinator.Tab.profile.title,
                            systemImage: AppCoordinator.Tab.profile.icon
                        )
                    }
            }
            .environmentObject(coordinator)
            .environmentObject(container)
            .onOpenURL { url in
                coordinator.handleDeepLink(url)
            }
        }
        .environment(\.layoutDirection, localizationManager.currentLanguage == "he" ? .rightToLeft : .leftToRight)
    }
    
    private func syncBadgeForTab(_ tab: AppCoordinator.Tab) -> Text? {
        // Only show sync badge if there are pending changes
        if syncManager.pendingChangesCount > 0 && !syncManager.isSyncing {
            return nil // We're showing the sync status bar instead
        }
        return nil
    }
}

#Preview {
    ContentView()
}