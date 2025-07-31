//
//  Theme.swift
//  Eckstein
//
//  Created by Assistant on 16/01/2025.
//

import SwiftUI

// MARK: - Accent Color Options
enum AccentColorOption: String, CaseIterable, Identifiable {
    case defaultMix = "Default"
    case blue = "Blue"
    case green = "Green"
    case purple = "Purple"
    case orange = "Orange"
    case red = "Red"
    case pink = "Pink"
    case indigo = "Indigo"
    case teal = "Teal"
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .defaultMix: return .blue // Default primary color
        case .blue: return .blue
        case .green: return .green
        case .purple: return .purple
        case .orange: return .orange
        case .red: return .red
        case .pink: return .pink
        case .indigo: return .indigo
        case .teal: return .teal
        }
    }
    
    // Get context-specific color for default theme
    func contextColor(for context: ThemeContext) -> Color {
        switch self {
        case .defaultMix:
            switch context {
            case .workout: return .blue
            case .diet: return .green
            case .weight: return .orange
            case .ai: return .purple
            case .general: return .blue
            }
        default:
            return self.color
        }
    }
    
    var displayName: String {
        return rawValue
    }
}

// MARK: - Theme Context
enum ThemeContext {
    case workout
    case diet
    case weight
    case ai
    case general
}

// MARK: - Theme Mode
enum ThemeMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "system".localized
        case .light: return "light".localized
        case .dark: return "dark".localized
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Theme Extensions
extension Color {
    // Semantic colors that adapt to theme
    static func accentColor(from option: AccentColorOption) -> Color {
        return option.color
    }
    
    // Helper for creating variations
    func opacity(_ value: Double) -> Color {
        return Color(UIColor(self).withAlphaComponent(value))
    }
}

// MARK: - View Extensions for Theming
extension View {
    func themedForegroundColor(_ colorOption: AccentColorOption, context: ThemeContext = .general) -> some View {
        self.foregroundColor(colorOption == .defaultMix ? colorOption.contextColor(for: context) : colorOption.color)
    }
    
    func themedAccentColor(_ colorOption: AccentColorOption) -> some View {
        self.accentColor(colorOption.color)
    }
    
    func themedBackground(_ colorOption: AccentColorOption, opacity: Double = 0.1) -> some View {
        self.background(colorOption.color.opacity(opacity))
    }
}