//
//  ProfileWeightGoalSection.swift
//  Eckstein
//
//  Created by Assistant on 23/07/2025.
//
//  Reworked in phase 4: the current weight, the target weight, and the distance
//  between them.
//
//  Two things changed. The weight shown is `WeightMetrics.currentWeight` — the
//  newest weigh-in by date — rather than `latestEntry`, so Profile, Dashboard and
//  the Progress screen are reading one definition instead of three that agree
//  until they don't. And the distance is rendered through
//  `WeightTargetProgress`, which resolves the direction itself: the old row took
//  `abs(difference)` and always appended "to go", so a user 3 kg *below* their
//  target was told they had 3 kg left to lose.
//

import SwiftUI

struct ProfileWeightGoalSection: View {
    @ObservedObject var themeManager: ThemeManager
    @ObservedObject var weightRepository: WeightRepository
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var showingGoalSettings = false

    private var unit: WeightUnit { .preferred }

    /// Read through `WeightMetrics` rather than `latestEntry` so the value here
    /// is the newest weigh-in by date, not by whatever order the fetch returned.
    private var currentWeightKg: Double? {
        WeightMetrics.currentWeight(from: weightRepository.weightEntries)
    }

    private var targetWeightKg: Double? {
        weightRepository.goalWeight
    }

    private var targetProgress: WeightTargetProgress? {
        WeightMetrics.targetProgress(currentKg: currentWeightKg, targetKg: targetWeightKg)
    }

    private var goalDate: Date? {
        weightRepository.getGoalDate()
    }

    @ViewBuilder
    var body: some View {
        Section {
            valueRow(
                titleKey: "current_weight",
                systemImage: "scalemass",
                value: unit.formatted(kilograms: currentWeightKg),
                fallbackKey: "weight_empty_state"
            )

            valueRow(
                titleKey: "goal_weight",
                systemImage: "target",
                value: unit.formatted(kilograms: targetWeightKg),
                fallbackKey: "weight_no_target_set"
            )

            if let targetProgress {
                progressRow(targetProgress)
            }

            Button {
                showingGoalSettings = true
            } label: {
                HStack {
                    Image(systemName: "target")
                    Text(targetWeightKg == nil ? "set_goal".localized : "update_goal".localized)
                }
                .themedForegroundColor(themeManager.accentColor)
            }
        } header: {
            Text("weight_goal".localized)
                .textCase(nil)
        }
        .onAppear { weightRepository.refresh() }
        .sheet(isPresented: $showingGoalSettings) {
            WeightGoalView(viewModel: WeightViewModel())
        }
        .id(localizationManager.currentLanguage)
    }

    // MARK: - Rows

    private func valueRow(
        titleKey: String,
        systemImage: String,
        value: String?,
        fallbackKey: String
    ) -> some View {
        HStack {
            Label(titleKey.localized, systemImage: systemImage)
                .themedForegroundColor(themeManager.accentColor, context: .general)

            Spacer()

            if let value {
                Text(value)
                    .font(.headline)
            } else {
                Text(fallbackKey.localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func progressRow(_ progress: WeightTargetProgress) -> some View {
        HStack {
            Label("weight_to_goal".localized, systemImage: "chart.line.uptrend.xyaxis")
                .themedForegroundColor(themeManager.accentColor, context: .general)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                // The sentence carries the direction; the number is an
                // unsigned distance. A minus sign in front of someone's distance
                // to their own goal is never the right rendering.
                Text(
                    progress.descriptionKey.localized(
                        unit.formattedDistance(kilograms: progress.remainingKg) ?? "0"
                    )
                )
                .font(.headline)
                .multilineTextAlignment(.trailing)

                if let goalDate, !progress.isAtTarget {
                    let days = Calendar.current.dateComponents(
                        [.day], from: Calendar.current.startOfDay(for: Date()),
                        to: Calendar.current.startOfDay(for: goalDate)
                    ).day ?? 0
                    Text(daysRemainingText(days))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// A target date in the past is not "−12 days". Past the date the plan is
    /// simply unfinished, and the count of days is not the useful fact any more.
    private func daysRemainingText(_ days: Int) -> String {
        guard days > 0 else { return "days_overdue".localized }
        return "\(days) \("days".localized)"
    }
}
