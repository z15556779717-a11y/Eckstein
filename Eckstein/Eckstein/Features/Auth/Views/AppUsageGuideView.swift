//
//  AppUsageGuideView.swift
//  Eckstein
//
//  Created by Assistant on 15/01/2025.
//

import SwiftUI

struct AppUsageGuideView: View {
    @State private var currentPage = 0
    @State private var dontShowAgain = false
    let userId: String?
    var onComplete: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var pages: [GuidePage] {
        [
            GuidePage(
                icon: "figure.strengthtraining.traditional",
                title: "track_your_workouts".localized,
                description: "track_workouts_description".localized,
                tips: [
                    "track_workouts_tip1".localized,
                    "track_workouts_tip2".localized,
                    "track_workouts_tip3".localized
                ],
                color: themeManager.accentColor.color
            ),
            GuidePage(
                icon: "fork.knife",
                title: "monitor_your_diet".localized,
                description: "monitor_diet_description".localized,
                tips: [
                    "monitor_diet_tip1".localized,
                    "monitor_diet_tip2".localized,
                    "monitor_diet_tip3".localized
                ],
                color: themeManager.accentColor.color
            ),
            GuidePage(
                icon: "scalemass",
                title: "track_your_weight".localized,
                description: "track_weight_description".localized,
                tips: [
                    "track_weight_tip1".localized,
                    "track_weight_tip2".localized,
                    "track_weight_tip3".localized
                ],
                color: themeManager.accentColor.color
            ),
            GuidePage(
                icon: "sparkles",
                title: "ai_fitness_coach".localized,
                description: "ai_coach_description".localized,
                tips: [
                    "ai_coach_tip1".localized,
                    "ai_coach_tip2".localized,
                    "ai_coach_tip3".localized
                ],
                color: themeManager.accentColor.color
            )
        ]
    }
    
    private func handleComplete() {
        if dontShowAgain, let userId = userId {
            // Store preference to never show the guide again
            UserDefaults.standard.set(true, forKey: "neverShowGuide_\(userId)")
        }
        onComplete()
    }
    
    var body: some View {
        VStack {
            // Skip button
            HStack {
                Spacer()
                Button("skip".localized) {
                    withAnimation {
                        handleComplete()
                    }
                }
                .foregroundColor(.gray)
                .padding()
            }
            
            // Page content
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    GuidePageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle())
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            
            // Don't show again checkbox on last page
            if currentPage == pages.count - 1 {
                HStack {
                    Button(action: {
                        dontShowAgain.toggle()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: dontShowAgain ? "checkmark.square.fill" : "square")
                                .foregroundColor(themeManager.accentColor.color)
                                .font(.system(size: 20))
                            
                            Text("dont_show_guide_again".localized)
                                .foregroundColor(.primary)
                                .font(.subheadline)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            
            // Navigation buttons
            HStack {
                if currentPage > 0 {
                    Button(action: {
                        withAnimation {
                            currentPage -= 1
                        }
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("previous".localized)
                        }
                        .foregroundColor(themeManager.accentColor.color)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        if currentPage < pages.count - 1 {
                            currentPage += 1
                        } else {
                            handleComplete()
                        }
                    }
                }) {
                    HStack {
                        Text(currentPage < pages.count - 1 ? "next".localized : "get_started".localized)
                        Image(systemName: currentPage < pages.count - 1 ? "chevron.right" : "checkmark")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(themeManager.accentColor.color)
                    .cornerRadius(25)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        .background(Color(.systemGray6))
        .id(localizationManager.currentLanguage)
    }
}

struct GuidePage {
    let icon: String
    let title: String
    let description: String
    let tips: [String]
    let color: Color
}

struct GuidePageView: View {
    let page: GuidePage
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: page.icon)
                    .font(.system(size: 60))
                    .foregroundColor(page.color)
            }
            
            // Title
            Text(page.title)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Description
            Text(page.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // Tips
            VStack(alignment: .leading, spacing: 12) {
                ForEach(page.tips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(page.color)
                            .font(.system(size: 20))
                        
                        Text(tip)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
            Spacer()
        }
    }
}

#Preview {
    AppUsageGuideView(userId: "preview-user") {
        print("Guide completed")
    }
}