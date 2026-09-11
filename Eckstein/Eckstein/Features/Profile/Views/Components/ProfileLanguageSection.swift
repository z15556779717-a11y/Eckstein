//
//  ProfileLanguageSection.swift
//  Eckstein
//
//  Created by Eliad Shahar on 23/07/2025.
//

import SwiftUI

struct ProfileLanguageSection: View {
    @ObservedObject var localizationManager: LocalizationManager
    @ObservedObject var themeManager: ThemeManager
    
    @ViewBuilder
    var body: some View {
        Section {
            HStack {
                Label("app_language".localized, systemImage: "globe")
                    .themedForegroundColor(themeManager.accentColor, context: .general)
                
                Spacer()
                
                Picker("language".localized, selection: $localizationManager.currentLanguage) {
                    HStack {
                        Image(systemName: "flag")
                        Text("english".localized)
                    }
                    .tag("en")

                    HStack {
                        Image(systemName: "flag.fill")
                        Text("עברית")
                    }
                    .tag("he")

                    // Endonyms, like the Hebrew entry above: a language is
                    // named in itself, so it stays legible to the person
                    // looking for it whatever the app is currently set to.
                    HStack {
                        Image(systemName: "flag.fill")
                        Text("简体中文")
                    }
                    .tag("zh-Hans")
                }
                .pickerStyle(MenuPickerStyle())
                .labelsHidden()
            }
        } header: {
            Text("language".localized)
                .textCase(nil)
        }
    }
}