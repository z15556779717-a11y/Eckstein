//
//  DashboardCards.swift
//  Eckstein
//
//  The Dashboard's four cards.
//
//  They are separate types rather than one long body because each has its own
//  empty case, and a single body would have to nest four of them.
//

import SwiftUI

// MARK: - Today's nutrition

struct TodayNutritionCard: View {
    let summary: DailyNutritionSummary
    let progress: NutritionGoalProgress

    @ObservedObject private var themeManager = ThemeManager.shared

    private var calories: NutrientGoalProgress { progress.calories }

    private var ringColor: Color {
        // Over target is the one state worth a colour change, and it is never the
        // *only* signal — the caption below says how far over in kcal.
        calories.isOverTarget
            ? .orange
            : (themeManager.accentColor == .defaultMix
                ? themeManager.accentColor.contextColor(for: .diet)
                : themeManager.accentColor.color)
    }

    private var targetText: String? {
        NutrientFormat.calories(calories.target)
    }

    private var caption: String? {
        guard let remaining = calories.remaining,
              let magnitude = NutrientFormat.calorieMagnitude(remaining) else {
            return nil
        }
        return remaining < 0
            ? "dashboard_over_by".localized(magnitude)
            : "dashboard_left_today".localized(magnitude)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("dashboard_today_nutrition".localized)
                .font(.headline)

            HStack(spacing: 20) {
                CalorieRing(
                    consumed: calories.current,
                    target: calories.target,
                    fill: calories.displayProgress,
                    color: ringColor
                )

                VStack(alignment: .leading, spacing: 6) {
                    if let targetText {
                        Text("\(NutrientFormat.calories(calories.current) ?? "0") / \(targetText) kcal")
                            .font(.title3)
                            .fontWeight(.semibold)
                    } else {
                        // No target set. The current value still shows; only the
                        // comparison is missing.
                        Text("\(NutrientFormat.calories(calories.current) ?? "0") kcal")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("dashboard_no_goal_set".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    if let caption {
                        Text(caption)
                            .font(.subheadline)
                            .foregroundColor(calories.isOverTarget ? .orange : .secondary)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .cardBackground()
        .accessibilityElement(children: .combine)
    }
}

/// The calories ring.
///
/// Split out so its accessibility is stated once. The ring is a drawing of two
/// numbers that are both already on screen in text, so VoiceOver reads the pair
/// rather than trying to describe an arc.
struct CalorieRing: View {
    let consumed: Double
    let target: Double?
    let fill: Double
    let color: Color

    private let diameter: CGFloat = 128
    private let lineWidth: CGFloat = 14

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: fill)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                // Animates the fill when a food is logged while the Dashboard is
                // open; a static redraw would jump.
                .animation(.easeInOut(duration: 0.35), value: fill)

            VStack(spacing: 2) {
                Text(NutrientFormat.calories(consumed) ?? "0")
                    .font(.title2)
                    .fontWeight(.bold)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("kcal")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, lineWidth)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("dashboard_today_nutrition".localized)
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        let current = NutrientFormat.calories(consumed) ?? "0"
        guard let target = NutrientFormat.calories(target) else {
            return "\(current) kcal"
        }
        return "\(current) / \(target) kcal"
    }
}

// MARK: - Macro breakdown

struct MacroBreakdownCard: View {
    let progress: NutritionGoalProgress

    var body: some View {
        MacroProgressList(progress: progress)
            .cardBackground()
    }
}

/// One macro's name and progress, in a shape `ForEach` can key on.
///
/// A small type rather than a tuple element: the identity of a row here is the
/// nutrient it describes, and saying that once is clearer than relying on a key
/// path into a tuple literal.
struct MacroProgressItem: Identifiable {
    let titleKey: String
    let progress: NutrientGoalProgress

    var id: String { titleKey }
}

/// The four macro rows, in the order the brief lists them.
///
/// Calories are deliberately absent: they are the ring above, and repeating
/// them here would give one number two homes on one screen.
///
/// Shared by the Dashboard's breakdown card and the Diet screen's day summary,
/// so the two screens cannot order or label the macros differently.
struct MacroProgressList: View {
    let progress: NutritionGoalProgress

    private var items: [MacroProgressItem] {
        [
            MacroProgressItem(titleKey: "protein", progress: progress.protein),
            MacroProgressItem(titleKey: "carbs", progress: progress.carbohydrates),
            MacroProgressItem(titleKey: "fat", progress: progress.fat),
            MacroProgressItem(titleKey: "fiber", progress: progress.fiber)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(items) { item in
                MacroRow(titleKey: item.titleKey, progress: item.progress)
            }
        }
    }
}

struct MacroRow: View {
    let titleKey: String
    let progress: NutrientGoalProgress

    @ObservedObject private var themeManager = ThemeManager.shared

    private var tint: Color {
        progress.isOverTarget
            ? .orange
            : (themeManager.accentColor == .defaultMix
                ? themeManager.accentColor.contextColor(for: .diet)
                : themeManager.accentColor.color)
    }

    private var amountText: String {
        let current = NutrientFormat.grams(progress.current) ?? "0"
        guard let target = NutrientFormat.grams(progress.target) else {
            return "\(current) g"
        }
        return "\(current) / \(target) g"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(titleKey.localized)
                    .font(.subheadline)
                Spacer()
                Text(amountText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // `displayProgress` is clamped to 0...1 for the bar, but the figure
            // beside it is not — a user 20% over their protein target sees a full
            // bar and the real number.
            ProgressView(value: progress.displayProgress)
                .tint(tint)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(titleKey.localized)
        .accessibilityValue(amountText)
    }
}

// MARK: - Today's workout

struct TodayWorkoutCard: View {
    let workouts: [CDWorkout]
    let onOpenWorkouts: () -> Void

    @ObservedObject private var themeManager = ThemeManager.shared

    private var accent: Color {
        themeManager.accentColor == .defaultMix
            ? themeManager.accentColor.contextColor(for: .workout)
            : themeManager.accentColor.color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("dashboard_today_workout".localized)
                .font(.headline)

            if workouts.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .foregroundColor(.secondary)
                    Text("dashboard_no_workout_today".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(workouts, id: \.objectID) { workout in
                    Button(action: onOpenWorkouts) {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(accent)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(workout.name ?? "workout".localized)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)

                                Text(detail(for: workout))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer(minLength: 0)

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .cardBackground()
    }

    /// "4 组 · 35 分钟", omitting whichever half is unknown rather than printing a
    /// zero for it.
    private func detail(for workout: CDWorkout) -> String {
        var parts: [String] = []
        let sets = workout.setsArray.count
        if sets > 0 {
            parts.append("\(sets) \("sets".localized)")
        }
        if workout.durationMinutes > 0 {
            parts.append("\(workout.durationMinutes) \("min".localized)")
        }
        return parts.isEmpty ? "workout".localized : parts.joined(separator: " · ")
    }
}

// MARK: - Body weight

struct BodyWeightCard: View {
    @ObservedObject var viewModel: DashboardViewModel
    let onLogWeight: () -> Void
    let onSeeTrends: () -> Void

    @ObservedObject private var themeManager = ThemeManager.shared

    private var accent: Color {
        themeManager.accentColor == .defaultMix
            ? themeManager.accentColor.contextColor(for: .weight)
            : themeManager.accentColor.color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("dashboard_body_weight".localized)
                    .font(.headline)
                Spacer()
                if viewModel.hasWeightData {
                    Button("progress".localized, action: onSeeTrends)
                        .font(.subheadline)
                }
            }

            if let currentText = viewModel.currentWeightText {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(currentText)
                        .font(.title2)
                        .fontWeight(.bold)
                    if let bmiText = viewModel.bmiText {
                        Text("· \("bmi_prefix".localized) \(bmiText)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // The BMI band. Shown as text, never as a coloured dot alone —
                // a band with no words is not readable by someone who cannot see
                // the colour.
                if let category = viewModel.bmiCategory {
                    Text(category.titleKey.localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if viewModel.hasTarget, let targetText = viewModel.targetWeightText {
                    Text("\("goal_weight".localized) \(targetText)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if let description = viewModel.targetDescription {
                        Label(description, systemImage: "target")
                            .font(.subheadline)
                            .foregroundColor(accent)
                    }
                } else {
                    Text("weight_no_target_set".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                EmptyStateContent(
                    icon: "scalemass",
                    title: "weight_empty_state".localized,
                    message: "weight_empty_state_message".localized,
                    actionTitle: "dashboard_log_weight".localized,
                    action: onLogWeight
                )
                .frame(minHeight: 140)
            }
        }
        .cardBackground()
    }
}

// MARK: - Quick actions

struct QuickActionsCard: View {
    let onLogFood: () -> Void
    let onStartWorkout: () -> Void
    let onLogWeight: () -> Void
    let onAskAI: () -> Void

    /// Two columns rather than four across: at the largest Dynamic Type sizes a
    /// four-across row truncates every label to a word fragment.
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("dashboard_quick_actions".localized)
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 12) {
                action("fork.knife", "dashboard_log_food", onLogFood)
                action("figure.strengthtraining.traditional", "dashboard_start_workout", onStartWorkout)
                action("scalemass", "dashboard_log_weight", onLogWeight)
                action("bubble.left.and.bubble.right", "dashboard_ask_ai", onAskAI)
            }
        }
        .cardBackground()
    }

    private func action(_ icon: String, _ titleKey: String, _ perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.body)
                    .frame(width: 24)
                Text(titleKey.localized)
                    .font(.subheadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.tertiarySystemGroupedBackground))
            .cornerRadius(12)
            .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
        // An icon-only control would need an explicit label; these have visible
        // text, but the combined element reads the icon's name off too, so the
        // label is pinned to the words.
        .accessibilityLabel(titleKey.localized)
    }
}
