//
//  DietTabView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

struct DietTabView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [themeManager.accentColor.color.opacity(0.1), themeManager.accentColor.color.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                EcksteinDietView()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}