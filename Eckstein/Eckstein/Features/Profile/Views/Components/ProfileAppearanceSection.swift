//
//  ProfileAppearanceSection.swift
//  Eckstein
//
//  Created by Eliad Shahar on 23/07/2025.
//

import SwiftUI

struct ProfileAppearanceSection: View {
    @ObservedObject var themeManager: ThemeManager
    
    @ViewBuilder
    var body: some View {
        Section {
            // Theme Mode Picker
            HStack {
                Label("theme".localized, systemImage: "moon.circle")
                Spacer()
                Picker("theme".localized, selection: $themeManager.themeMode) {
                    ForEach(ThemeMode.allCases) { mode in
                        Text(mode.displayName)
                            .tag(mode)
                            .environment(\.layoutDirection, .leftToRight)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
                .environment(\.layoutDirection, .leftToRight) // Force LTR for segmented control
            }
            
            // Accent Color Picker
            VStack(alignment: .leading, spacing: 12) {
                Label("accent_color".localized, systemImage: "paintbrush")
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                    ForEach(AccentColorOption.allCases) { color in
                        Circle()
                            .fill(color == .defaultMix ? 
                                  LinearGradient(colors: [.blue, .green, .orange, .purple], 
                                               startPoint: .topLeading, 
                                               endPoint: .bottomTrailing) : 
                                  LinearGradient(colors: [color.color], 
                                               startPoint: .topLeading, 
                                               endPoint: .bottomTrailing))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: themeManager.accentColor == color ? 3 : 0)
                            )
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    themeManager.accentColor = color
                                }
                            }
                    }
                }
                .padding(.vertical, 8)
            }
        } header: {
            Text("appearance".localized)
        }
    }
}