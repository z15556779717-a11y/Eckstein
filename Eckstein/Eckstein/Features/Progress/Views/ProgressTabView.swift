//
//  ProgressTabView.swift
//  Eckstein
//
//  The Progress tab: body weight, calories and protein over time.
//
//  Named `ProgressTabView` rather than `ProgressView` on purpose — SwiftUI
//  already has a `ProgressView`, and a same-named type in this module would be
//  chosen over it by name lookup, silently replacing every spinner in the app.
//

import SwiftUI
import Charts

struct ProgressTabView: View {
    @StateObject private var viewModel: ProgressViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared

    /// The view model is injectable so a preview can point the screen at an
    /// in-memory store. The default is the one the app builds.
    init(viewModel: ProgressViewModel = ProgressViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    /// One sheet for both flows. Two `.sheet` modifiers on the same view is a
    /// known way to lose one of them, and this keeps the choice explicit.
    @State private var activeSheet: ProgressSheet?
    @State private var pendingDelete: CDWeightEntry?
    @State private var showingDetailedAnalytics = false

    private var accent: Color {
        themeManager.accentColor == .defaultMix
            ? themeManager.accentColor.contextColor(for: .weight)
            : themeManager.accentColor.color
    }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        themeManager.accentColor.color.opacity(0.1),
                        themeManager.accentColor.color.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        rangePicker
                        summaryCard

                        if viewModel.isLoading {
                            LoadingStateView().cardBackground()
                        } else {
                            weightChartCard
                            calorieChartCard
                            proteinChartCard
                            historyCard
                        }

                        if let errorMessage = viewModel.errorMessage {
                            InlineErrorLabel(message: errorMessage)
                                .cardBackground()
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("tab_progress".localized)
            .navigationBarTitleDisplayMode(.large)
            .environment(\.layoutDirection, localizationManager.layoutDirection)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        activeSheet = .add
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    // An icon-only control has to carry its label itself; without
                    // this VoiceOver reads the SF Symbol's name.
                    .accessibilityLabel("dashboard_log_weight".localized)
                }
            }
            .task { await viewModel.load() }
            .onChange(of: viewModel.range) { _, _ in
                Task { await viewModel.load() }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .add:
                    WeightEntryView {
                        Task { await viewModel.load() }
                    }
                case .edit(let entry):
                    WeightEditView(
                        entry: entry,
                        viewModel: WeightViewModel(repository: WeightRepository.shared)
                    )
                }
            }
            .sheet(isPresented: $showingDetailedAnalytics) {
                // The pre-existing weight screens, kept reachable now that the
                // Weight tab is gone. Presented rather than pushed so their own
                // navigation stack does not stack inside this one.
                WeightTabView()
            }
            .confirmationDialog(
                "diet_delete_entry_title".localized,
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("delete".localized, role: .destructive) {
                    if let entry = pendingDelete {
                        viewModel.delete(entry)
                    }
                    pendingDelete = nil
                }
                Button("cancel".localized, role: .cancel) { pendingDelete = nil }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Range

    private var rangePicker: some View {
        Picker("progress_range".localized, selection: $viewModel.range) {
            ForEach(WeightRange.allCases) { range in
                Text(range.titleKey.localized).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("progress_range".localized)
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let currentText = viewModel.currentWeightText {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(currentText)
                        .font(.title)
                        .fontWeight(.bold)
                    if let changeText = viewModel.weightChangeText {
                        Text(changeText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                if let bmiText = viewModel.bmiText, let category = viewModel.bmiCategory {
                    Text("\("bmi_prefix".localized) \(bmiText) · \(category.titleKey.localized)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let targetText = viewModel.targetWeightText,
                   let description = viewModel.targetDescription {
                    Label("\(description) · \(targetText)", systemImage: "target")
                        .font(.subheadline)
                        .foregroundColor(accent)
                } else {
                    Text("weight_no_target_set".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("weight_empty_state".localized)
                    .font(.headline)
                Text("weight_empty_state_message".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Button {
                showingDetailedAnalytics = true
            } label: {
                Label("weight_analytics".localized, systemImage: "chart.bar.xaxis")
                    .font(.subheadline)
            }
            .padding(.top, 2)
        }
        .cardBackground()
    }

    // MARK: - Weight chart

    private var weightChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("progress_weight_trend".localized)
                    .font(.headline)
                Spacer()
                if let changeText = viewModel.weightChangeText {
                    Text(changeText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if viewModel.hasWeightTrend {
                Chart {
                    ForEach(viewModel.weightPoints) { point in
                        if let kilograms = point.weightKg {
                            LineMark(
                                x: .value("date", point.date, unit: .day),
                                y: .value("weight", viewModel.unit.value(fromKilograms: kilograms))
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(accent)

                            PointMark(
                                x: .value("date", point.date, unit: .day),
                                y: .value("weight", viewModel.unit.value(fromKilograms: kilograms))
                            )
                            .foregroundStyle(accent)
                            .symbolSize(24)
                        }
                    }

                    if let targetKg = viewModel.targetWeightKg {
                        RuleMark(y: .value("target", viewModel.unit.value(fromKilograms: targetKg)))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(.secondary)
                            .annotation(position: .top, alignment: .leading) {
                                Text("goal_weight".localized)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                    }
                }
                .chartYScale(domain: weightYDomain)
                .frame(height: 200)
                .chartAccessibility(
                    label: "progress_weight_trend".localized,
                    value: "\(viewModel.currentWeightText ?? "") \(viewModel.weightChangeText ?? "")"
                )
            } else {
                // Two different empty states, because they are two different
                // facts: nothing has ever been logged, versus one reading is not
                // yet a trend.
                EmptyStateContent(
                    icon: "chart.line.uptrend.xyaxis",
                    title: (viewModel.hasWeightData
                        ? "progress_insufficient_data"
                        : "weight_empty_state").localized,
                    message: (viewModel.hasWeightData
                        ? "progress_no_entries_in_range"
                        : "weight_empty_state_message").localized,
                    actionTitle: "dashboard_log_weight".localized,
                    action: { activeSheet = .add }
                )
                .frame(minHeight: 160)
            }
        }
        .cardBackground()
    }

    /// The plotted weight range, with a margin so the line is not drawn along the
    /// very edge of the plot area, and a minimum span so a week of identical
    /// readings does not zoom to a flat line with meaningless axis labels.
    private var weightYDomain: ClosedRange<Double> {
        var values = viewModel.weightPoints
            .compactMap(\.weightKg)
            .map { viewModel.unit.value(fromKilograms: $0) }

        if let targetKg = viewModel.targetWeightKg, viewModel.hasWeightData {
            values.append(viewModel.unit.value(fromKilograms: targetKg))
        }

        guard let minimum = values.min(), let maximum = values.max() else { return 0...1 }
        if maximum - minimum < 2 { return (minimum - 1)...(maximum + 1) }
        let padding = (maximum - minimum) * 0.15
        return (minimum - padding)...(maximum + padding)
    }

    // MARK: - Nutrition charts

    private var calorieChartCard: some View {
        NutritionTrendCard(
            titleKey: "progress_calorie_trend",
            unitLabel: "kcal",
            points: viewModel.nutritionPoints,
            value: \.calories,
            target: viewModel.calorieTarget,
            accent: accent,
            targetLabelKey: "daily_calorie_goal",
            action: { activeSheet = .add }
        )
    }

    private var proteinChartCard: some View {
        NutritionTrendCard(
            titleKey: "progress_protein_trend",
            unitLabel: "g",
            points: viewModel.nutritionPoints,
            value: \.protein,
            target: nil,
            accent: accent,
            targetLabelKey: nil,
            action: { activeSheet = .add }
        )
    }

    // MARK: - History

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("weight_history".localized)
                .font(.headline)

            if viewModel.visibleEntries.isEmpty {
                Text("progress_no_entries_in_range".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.visibleEntries, id: \.objectID) { entry in
                    ProgressHistoryRow(
                        entry: entry,
                        unit: viewModel.unit,
                        onEdit: { activeSheet = .edit(entry) },
                        onDelete: { pendingDelete = entry }
                    )
                    if entry.objectID != viewModel.visibleEntries.last?.objectID {
                        Divider()
                    }
                }
            }
        }
        .cardBackground()
    }
}

// MARK: - Sheet identity

private enum ProgressSheet: Identifiable {
    case add
    case edit(CDWeightEntry)

    var id: String {
        switch self {
        case .add:
            return "add"
        case .edit(let entry):
            // The object ID is stable for the life of the row and unique across
            // rows, which is what `sheet(item:)` needs to tell one edit from
            // another.
            return entry.objectID.uriRepresentation().absoluteString
        }
    }
}

// MARK: - History row

private struct ProgressHistoryRow: View {
    let entry: CDWeightEntry
    let unit: WeightUnit
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var weightText: String {
        unit.formatted(kilograms: entry.weightKg) ?? "—"
    }

    private var dateText: String {
        guard let date = entry.date else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = LocalizationManager.shared.currentLocale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(weightText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(dateText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.body)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .accessibilityLabel("edit".localized)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.body)
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
            .accessibilityLabel("delete".localized)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Nutrition trend card

/// A bar chart of one nutrient across the range, with an optional target line.
///
/// One type for both charts rather than two near-identical bodies: the only
/// differences are the key path, the unit label and whether a target exists.
private struct NutritionTrendCard: View {
    let titleKey: String
    let unitLabel: String
    let points: [NutritionTrendPoint]
    let value: KeyPath<NutritionTrendPoint, Double?>
    let target: Double?
    let accent: Color
    let targetLabelKey: String?
    let action: () -> Void

    private var hasData: Bool {
        points.contains { $0[keyPath: value] != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(titleKey.localized)
                    .font(.headline)
                Spacer()
                Text(unitLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if hasData {
                Chart {
                    ForEach(points) { point in
                        if let amount = point[keyPath: value] {
                            BarMark(
                                x: .value("date", point.date, unit: .day),
                                y: .value("amount", amount)
                            )
                            .foregroundStyle(accent.opacity(0.75))
                            .cornerRadius(3)
                        }
                    }

                    if let target, target > 0 {
                        RuleMark(y: .value("target", target))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 180)
                .chartAccessibility(label: titleKey.localized, value: summary)
            } else {
                EmptyStateContent(
                    icon: "fork.knife",
                    title: "progress_insufficient_data".localized,
                    message: "diet_no_entries_for_day".localized,
                    actionTitle: "dashboard_log_food".localized,
                    action: action
                )
                .frame(minHeight: 140)
            }
        }
        .cardBackground()
    }

    /// A sentence for VoiceOver, because a bar chart read out as "chart" is not
    /// information. Reports the average rather than every bar — a 365-bar reading
    /// is unusable, and the average is what the shape of the chart conveys.
    private var summary: String {
        let values = points.compactMap { $0[keyPath: value] }
        guard !values.isEmpty else { return "progress_insufficient_data".localized }
        let average = values.reduce(0, +) / Double(values.count)
        let formatted = unitLabel == "g"
            ? (NutrientFormat.grams(average) ?? "0")
            : (NutrientFormat.calories(average) ?? "0")
        return "\(values.count) \(unitLabel) · \("average".localized) \(formatted) \(unitLabel)"
    }
}

// MARK: - Chart accessibility

private extension View {
    /// Hides a chart's marks from VoiceOver and substitutes one element with a
    /// summary. Without this a chart is either silent or reads out every point.
    func chartAccessibility(label: String, value: String) -> some View {
        self
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(value)
    }
}

/// Rendered against an in-memory store, so the sample weigh-ins and meals the
/// preview shows cannot reach the store on disk.
///
/// `#if DEBUG` because `PreviewSupport` is DEBUG-only: an unguarded preview
/// would not compile in a Release build.
#if DEBUG
#Preview {
    ProgressTabView(
        viewModel: ProgressViewModel(
            nutrition: PreviewSupport.nutritionService(),
            weightRepository: PreviewSupport.weightRepository()
        )
    )
}
#endif
