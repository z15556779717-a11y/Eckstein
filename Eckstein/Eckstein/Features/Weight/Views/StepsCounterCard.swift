//
//  StepsCounterCard.swift
//  Eckstein
//
//  Created by Assistant on 23/07/2025.
//

import SwiftUI

struct StepsCounterCard: View {
    @ObservedObject private var healthKitService = HealthKitService.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @State private var todaySteps: Double = 0
    @State private var weeklyAverage: Double = 0
    @State private var monthlyAverage: Double = 0
    @State private var isLoading = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("steps_counter".localized, systemImage: "figure.walk")
                    .font(.headline)
                    .foregroundColor(themeManager.accentColor == .defaultMix ? 
                                   themeManager.accentColor.contextColor(for: .weight) : 
                                   themeManager.accentColor.color)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Today's Steps
            VStack(alignment: .leading, spacing: 8) {
                Text("today".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Text(formatSteps(todaySteps))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    
                    Text("steps".localized)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            
            // Averages Grid
            HStack(spacing: 12) {
                // Weekly Average
                VStack(alignment: .leading, spacing: 4) {
                    Text("weekly_avg".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 2) {
                        Text(formatSteps(weeklyAverage))
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("steps".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray5))
                .cornerRadius(10)
                
                // Monthly Average
                VStack(alignment: .leading, spacing: 4) {
                    Text("monthly_avg".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 2) {
                        Text(formatSteps(monthlyAverage))
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("steps".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray5))
                .cornerRadius(10)
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(themeManager.accentColor == .defaultMix ? 
                              themeManager.accentColor.contextColor(for: .weight) : 
                              themeManager.accentColor.color)
                        .frame(width: min(geometry.size.width * (todaySteps / 10000), geometry.size.width), height: 8)
                }
            }
            .frame(height: 8)
            
            // Goal Text
            HStack {
                Text(String(format: "steps_goal_progress".localized, formatSteps(todaySteps), "10,000"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if todaySteps >= 10000 {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .onAppear(perform: loadStepsData)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            loadStepsData()
        }
    }
    
    private func formatSteps(_ steps: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: localizationManager.currentLanguage)
        return formatter.string(from: NSNumber(value: steps)) ?? "0"
    }
    
    private func loadStepsData() {
        Task {
            isLoading = true
            
            // Fetch today's steps
            todaySteps = await healthKitService.fetchStepsData(for: Date())
            
            // Fetch weekly average
            weeklyAverage = await healthKitService.fetchAverageSteps(for: .week)
            
            // Fetch monthly average
            monthlyAverage = await healthKitService.fetchAverageSteps(for: .month)
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
}