//
//  ProfileMeetingSection.swift
//  Eckstein
//
//  Created by Eliad Shahar on 23/07/2025.
//

import SwiftUI

struct ProfileMeetingSection: View {
    @ObservedObject var themeManager: ThemeManager
    
    @ViewBuilder
    var body: some View {
        Section {
            Button(action: {
                if let url = URL(string: "https://yoman.co.il/doreckstein") {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    Label("set_a_meeting".localized, systemImage: "calendar.badge.plus")
                        .themedForegroundColor(themeManager.accentColor, context: .general)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}