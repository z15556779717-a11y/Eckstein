//
//  ThemeManager.swift
//  Eckstein
//
//  Created by Assistant on 16/01/2025.
//

import SwiftUI

@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @AppStorage("themeMode") private var themeModeRaw: String = ThemeMode.system.rawValue
    @AppStorage("accentColor") private var accentColorRaw: String = AccentColorOption.defaultMix.rawValue
    @AppStorage("dietStartDate") private var dietStartDateString: String = ""
    @AppStorage("startingWeight") var startingWeight: Double = 0.0
    
    @Published var themeMode: ThemeMode = .system {
        didSet {
            themeModeRaw = themeMode.rawValue
        }
    }
    
    @Published var accentColor: AccentColorOption = .defaultMix {
        didSet {
            accentColorRaw = accentColor.rawValue
        }
    }
    
    @Published var dietStartDate: Date? {
        didSet {
            if let date = dietStartDate {
                dietStartDateString = ISO8601DateFormatter().string(from: date)
            } else {
                dietStartDateString = ""
            }
        }
    }
    
    private init() {
        // Load saved preferences
        if let savedThemeMode = ThemeMode(rawValue: themeModeRaw) {
            self.themeMode = savedThemeMode
        }
        
        if let savedAccentColor = AccentColorOption(rawValue: accentColorRaw) {
            self.accentColor = savedAccentColor
        }
        
        if !dietStartDateString.isEmpty,
           let date = ISO8601DateFormatter().date(from: dietStartDateString) {
            self.dietStartDate = date
        }
    }
    
    // MARK: - Computed Properties
    
    var daysOnDiet: Int {
        guard let startDate = dietStartDate else { return 0 }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: Date())
        return components.day ?? 0
    }
    
    var colorScheme: ColorScheme? {
        return themeMode.colorScheme
    }
    
    // MARK: - Methods
    
    func setDietStartInfo(date: Date, weight: Double) {
        dietStartDate = date
        startingWeight = weight
    }
    
    func resetDietInfo() {
        dietStartDate = nil
        startingWeight = 0.0
    }
}

// MARK: - Diet-Specific Color Extensions

extension ThemeManager {
    /// Primary color for diet-related UI elements
    var dietPrimaryColor: Color {
        accentColor == .defaultMix ? 
        accentColor.contextColor(for: .diet) : 
        accentColor.color
    }
    
    /// Chart colors that work well with the current theme
    var chartColors: [Color] {
        switch accentColor {
        case .defaultMix:
            return [
                accentColor.contextColor(for: .diet),
                accentColor.contextColor(for: .diet).opacity(0.7),
                accentColor.contextColor(for: .diet).opacity(0.5)
            ]
        case .blue:
            return [.blue, .cyan, .indigo]
        case .green:
            return [.green, .mint, Color(red: 0.2, green: 0.7, blue: 0.3)]
        case .orange:
            return [.orange, Color(red: 1.0, green: 0.6, blue: 0.2), .yellow]
        case .purple:
            return [.purple, .indigo, Color(red: 0.6, green: 0.4, blue: 0.8)]
        case .red:
            return [.red, .pink, Color(red: 0.8, green: 0.2, blue: 0.2)]
        case .pink:
            return [.pink, Color(red: 1.0, green: 0.4, blue: 0.6), Color(red: 1.0, green: 0.6, blue: 0.8)]
        case .indigo:
            return [.indigo, .purple, Color(red: 0.4, green: 0.4, blue: 0.8)]
        case .teal:
            return [.teal, .cyan, Color(red: 0.2, green: 0.8, blue: 0.8)]
        }
    }
    
    /// Macro nutrient colors that complement the theme
    var proteinColor: Color {
        switch accentColor {
        case .defaultMix, .red:
            return .red
        case .blue:
            return Color(red: 0.8, green: 0.3, blue: 0.3) // Reddish
        case .green:
            return Color(red: 0.9, green: 0.4, blue: 0.2) // Orange-red
        case .orange:
            return Color(red: 0.8, green: 0.2, blue: 0.2) // Deep red
        case .purple:
            return Color(red: 0.9, green: 0.3, blue: 0.5) // Pink-red
        case .pink:
            return Color(red: 0.9, green: 0.2, blue: 0.4) // Deep pink
        case .indigo:
            return Color(red: 0.8, green: 0.3, blue: 0.4) // Indigo-red
        case .teal:
            return Color(red: 0.9, green: 0.3, blue: 0.3) // Coral red
        }
    }
    
    var carbsColor: Color {
        switch accentColor {
        case .defaultMix, .blue:
            return .blue
        case .red:
            return Color(red: 0.3, green: 0.5, blue: 0.8) // Medium blue
        case .green:
            return Color(red: 0.2, green: 0.6, blue: 0.9) // Sky blue
        case .orange:
            return Color(red: 0.3, green: 0.6, blue: 0.9) // Light blue
        case .purple:
            return Color(red: 0.4, green: 0.4, blue: 0.8) // Purple-blue
        case .pink:
            return Color(red: 0.5, green: 0.5, blue: 0.9) // Lavender blue
        case .indigo:
            return Color(red: 0.3, green: 0.3, blue: 0.7) // Indigo blue
        case .teal:
            return Color(red: 0.2, green: 0.5, blue: 0.8) // Ocean blue
        }
    }
    
    var fatColor: Color {
        switch accentColor {
        case .defaultMix, .green:
            return .green
        case .red:
            return Color(red: 0.3, green: 0.7, blue: 0.3) // Medium green
        case .blue:
            return Color(red: 0.2, green: 0.8, blue: 0.4) // Bright green
        case .orange:
            return Color(red: 0.4, green: 0.7, blue: 0.3) // Yellow-green
        case .purple:
            return Color(red: 0.3, green: 0.8, blue: 0.5) // Mint green
        case .pink:
            return Color(red: 0.4, green: 0.8, blue: 0.4) // Light green
        case .indigo:
            return Color(red: 0.3, green: 0.6, blue: 0.4) // Indigo-green
        case .teal:
            return Color(red: 0.2, green: 0.7, blue: 0.5) // Teal-green
        }
    }
    
    /// Button color for primary actions
    var primaryButtonColor: Color {
        dietPrimaryColor
    }
    
    /// Color for secondary UI elements
    var secondaryUIColor: Color {
        accentColor == .defaultMix ? 
        accentColor.contextColor(for: .diet).opacity(0.8) : 
        accentColor.color.opacity(0.8)
    }
}