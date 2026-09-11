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
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Sync Status Bar
            SyncStatusView()
                .zIndex(1)
            
            // Main Tab View
            //
            // Driven off `Tab.allCases` rather than six hand-written branches, so
            // the bar's order cannot drift from the enum's declaration order and
            // adding a destination is one case, not two edits in two files.
            TabView(selection: $coordinator.selectedTab) {
                ForEach(AppCoordinator.Tab.allCases, id: \.self) { tab in
                    tabContent(for: tab)
                        .tag(tab)
                        .tabItem {
                            Label(tab.title, systemImage: tab.icon)
                        }
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

    @ViewBuilder
    private func tabContent(for tab: AppCoordinator.Tab) -> some View {
        switch tab {
        case .home:
            DashboardView()
        case .diet:
            DietTabView()
        case .workout:
            WorkoutTabView()
        case .progress:
            ProgressTabView()
        case .ai:
            AICoachTabView()
        case .profile:
            ProfileView()
        }
    }
}

#Preview {
    ContentView()
}