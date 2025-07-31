//
//  LocalizationModifier.swift
//  Eckstein
//
//  Created by Eliad Shahar on 23/07/2025.
//

import SwiftUI

struct LocalizationModifier: ViewModifier {
    @ObservedObject var localizationManager = LocalizationManager.shared
    
    func body(content: Content) -> some View {
        content
            .environment(\.locale, localizationManager.currentLocale)
            .environment(\.layoutDirection, localizationManager.layoutDirection)
    }
}

extension View {
    /// Applies localization settings to the view
    func withLocalization() -> some View {
        modifier(LocalizationModifier())
    }
}