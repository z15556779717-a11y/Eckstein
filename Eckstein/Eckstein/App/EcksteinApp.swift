//
//  EcksteinApp.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

@main
struct EcksteinApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var serviceContainer = ServiceContainer.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    
    init() {
        configureEnvironment()
        seedInitialData()
    }

    var body: some Scene {
        WindowGroup {
            AuthenticationView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(serviceContainer)
                .environmentObject(themeManager)
                .environmentObject(localizationManager)
                .preferredColorScheme(themeManager.colorScheme)
                .accentColor(themeManager.accentColor.color)
                .withLocalization()
        }
    }
}
