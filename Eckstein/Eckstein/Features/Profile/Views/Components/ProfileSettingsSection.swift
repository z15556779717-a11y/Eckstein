//
//  ProfileSettingsSection.swift
//  Eckstein
//
//  Created by Eliad Shahar on 23/07/2025.
//

import SwiftUI

struct ProfileSettingsSection: View {
    @Binding var showingAppGuide: Bool
    @ObservedObject var tipManager: TipManager
    @ObservedObject var themeManager: ThemeManager
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        NavigationLink(destination: WeightSettingsView()) {
            Label("weight_and_health".localized, systemImage: "heart.text.square")
                .themedForegroundColor(themeManager.accentColor, context: .general)
        }
        
        NavigationLink(destination: DietSettingsSheet(isPresented: .constant(false))) {
            Label("diet_and_nutrition".localized, systemImage: "fork.knife.circle")
                .themedForegroundColor(themeManager.accentColor, context: .general)
        }
        
        Button(action: {
            showingAppGuide = true
        }) {
            Label("app_usage_guide".localized, systemImage: "questionmark.circle")
                .themedForegroundColor(themeManager.accentColor, context: .general)
        }
        
        // Tip Management
        HStack {
            Label("show_tips".localized, systemImage: "lightbulb")
                .themedForegroundColor(themeManager.accentColor, context: .general)
            
            Spacer()
            
            Toggle("", isOn: $tipManager.showTips)
                .labelsHidden()
        }
        
        if tipManager.showTips {
            Button(action: {
                tipManager.resetAllTips()
            }) {
                Label("reset_all_tips".localized, systemImage: "arrow.clockwise")
                    .foregroundColor(.secondary)
            }
        }
    }
}