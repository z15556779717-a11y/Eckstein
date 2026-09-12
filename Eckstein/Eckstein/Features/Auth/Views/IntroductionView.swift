//
//  IntroductionView.swift
//  Eckstein
//
//  Created by Assistant on 15/01/2025.
//

import SwiftUI

struct IntroductionView: View {
    @Binding var showIntroduction: Bool
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 80))
                    .foregroundColor(themeManager.accentColor.color)
                
                Text("introduction_welcome_title".localized)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("auth_tagline".localized)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 60)
            
            // Features
            VStack(spacing: 24) {
                FeatureRow(
                    icon: "figure.run",
                    title: "introduction_feature_workouts_title".localized,
                    description: "introduction_feature_workouts_body".localized
                )

                FeatureRow(
                    icon: "fork.knife",
                    title: "introduction_feature_nutrition_title".localized,
                    description: "introduction_feature_nutrition_body".localized
                )

                FeatureRow(
                    icon: "scalemass",
                    title: "introduction_feature_weight_title".localized,
                    description: "introduction_feature_weight_body".localized
                )

                FeatureRow(
                    icon: "sparkles",
                    title: "tab_ai_coach".localized,
                    description: "introduction_feature_ai_body".localized
                )
            }
            .padding(.vertical, 40)
            .padding(.horizontal)
            
            Spacer()
            
            // Get Started Button
            Button(action: {
                withAnimation {
                    showIntroduction = false
                }
            }) {
                Text("get_started".localized)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(themeManager.accentColor.color)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .background(
            LinearGradient(
                colors: [themeManager.accentColor.color.opacity(0.05), themeManager.accentColor.color.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(.blue)
                .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    IntroductionView(showIntroduction: .constant(true))
}