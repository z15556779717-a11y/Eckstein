//
//  ProgressViewModel.swift
//  Eckstein
//
//  The Progress tab's data: the body-weight trend, the calorie and protein
//  trends, and the weigh-in history.
//
//  Two aggregations, both reused rather than re-implemented. Weight comes from
//  `WeightMetrics` over the entries `WeightRepository` already holds; nutrition
//  comes from `NutritionService.summaries(inRangeEndingOn:days:)`, which reads
//  the range in one fetch. Nothing here walks a day at a time.
//

import Foundation
import Combine

@MainActor
final class ProgressViewModel: ObservableObject {

    // MARK: - Published state

    @Published var range: WeightRange = .month

    /// One point per day across `range`, oldest first, gaps included.
    @Published private(set) var weightPoints: [WeightPoint] = []

    /// One point per day across `range` for the nutrition charts.
    @Published private(set) var nutritionPoints: [NutritionTrendPoint] = []

    /// Every weigh-in, newest first — the list under the charts.
    @Published private(set) var entries: [CDWeightEntry] = []

    @Published private(set) var currentWeightKg: Double?
    /// Captured during `load()` rather than read through `weightRepository` at
    /// render time, so the view republishes when the goal changes.
    @Published private(set) var targetWeightKg: Double?
    @Published private(set) var targetProgress: WeightTargetProgress?
    @Published private(set) var bmi: Double?
    @Published private(set) var unit: WeightUnit = .preferred

    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    // MARK: - Dependencies

    private let nutrition: NutritionService
    private let weightRepository: WeightRepository
    private let calendar: Calendar

    init(
        nutrition: NutritionService = .shared,
        weightRepository: WeightRepository = .shared,
        calendar: Calendar = .current
    ) {
        self.nutrition = nutrition
        self.weightRepository = weightRepository
        self.calendar = calendar
    }

    // MARK: - Loading

    func load() async {
        if weightPoints.isEmpty { isLoading = true }
        errorMessage = nil

        weightRepository.refresh()
        unit = .preferred
        entries = weightRepository.weightEntries

        currentWeightKg = WeightMetrics.currentWeight(from: entries)
        targetWeightKg = weightRepository.goalWeight
        targetProgress = WeightMetrics.targetProgress(
            currentKg: currentWeightKg,
            targetKg: targetWeightKg
        )
        bmi = WeightMetrics.bmi(weightKg: currentWeightKg, heightCm: DashboardViewModel.storedHeightCm())

        weightPoints = WeightMetrics.dailySeries(
            entries: entries,
            endingOn: Date(),
            range: range,
            calendar: calendar
        )

        do {
            let summaries = try nutrition.summaries(
                inRangeEndingOn: Date(),
                days: range.days,
                calendar: calendar
            )
            nutritionPoints = WeightMetrics.nutritionSeries(from: summaries, calendar: calendar)
            // Every summary carries the same goals — they are read once per
            // range, not once per day — so the first is as good as any.
            calorieTarget = summaries.first?.goals.calories
        } catch {
            // The weight half of the screen is independent of this and still
            // renders. The charts that need it show their own empty state.
            nutritionPoints = []
            calorieTarget = nil
            errorMessage = "error_loading_data".localized
        }

        isLoading = false
    }

    // MARK: - Editing

    func delete(_ entry: CDWeightEntry) {
        weightRepository.delete(entry)
        // Re-read immediately rather than waiting for the change notification's
        // debounce, so the row leaves the list as the user watches.
        entries = weightRepository.weightEntries
        currentWeightKg = WeightMetrics.currentWeight(from: entries)
        targetWeightKg = weightRepository.goalWeight
        targetProgress = WeightMetrics.targetProgress(
            currentKg: currentWeightKg,
            targetKg: targetWeightKg
        )
        weightPoints = WeightMetrics.dailySeries(
            entries: entries,
            endingOn: Date(),
            range: range,
            calendar: calendar
        )
    }

    // MARK: - Derived

    /// The change across the visible range, or `nil` when there are fewer than
    /// two weigh-ins in it.
    var weightChangeKg: Double? {
        WeightMetrics.changeOverRange(weightPoints)
    }

    var weightChangeText: String? {
        unit.formattedChange(kilograms: weightChangeKg)
    }

    /// Whether any day in the range has a weigh-in. Drives the chart's empty
    /// state, which is a different claim from "the range is short".
    var hasWeightData: Bool {
        // `contains(where:)`, not `contains(_:)`: the unlabelled overload takes
        // an element, and a key path is not one — unlike `filter(_:)`, which is
        // the key-path form.
        weightPoints.contains(where: \.hasValue)
    }

    /// Whether any day in the range has nutrition logged.
    var hasNutritionData: Bool {
        nutritionPoints.contains(where: \.hasValue)
    }

    /// Whether there are at least two days of weight, which is what a trend
    /// needs. One point is a reading, not a line.
    var hasWeightTrend: Bool {
        weightPoints.filter(\.hasValue).count >= 2
    }

    var currentWeightText: String? {
        unit.formatted(kilograms: currentWeightKg)
    }

    var targetWeightText: String? {
        unit.formatted(kilograms: targetWeightKg)
    }

    /// "4.2 kg to go" / "2.5 kg to gain" / "At your target weight", or `nil` when
    /// no target is set.
    ///
    /// The direction is carried by the sentence, never by a minus sign on the
    /// distance — see `WeightTargetProgress.remainingKg`.
    var targetDescription: String? {
        guard let targetProgress,
              let distance = unit.formattedDistance(kilograms: targetProgress.remainingKg) else {
            return nil
        }
        return targetProgress.descriptionKey.localized(distance)
    }

    var bmiText: String? {
        guard let bmi else { return nil }
        return String(format: "%.1f", bmi)
    }

    var bmiCategory: BMICategory? {
        WeightMetrics.bmiCategory(for: bmi)
    }

    /// The weigh-ins that fall inside the selected range, newest first.
    ///
    /// Filtered in memory from the entries already loaded rather than by a second
    /// fetch, and so the list under the chart always matches the chart above it.
    /// An entry with no date cannot be placed in a range and is left out.
    var visibleEntries: [CDWeightEntry] {
        guard let firstDay = calendar.date(
            byAdding: .day,
            value: -(range.days - 1),
            to: calendar.startOfDay(for: Date())
        ) else {
            return entries
        }
        return entries.filter { entry in
            guard let date = entry.date else { return false }
            return date >= firstDay
        }
    }

    /// The calorie goal, for drawing the target line on the calorie chart.
    ///
    /// Captured during `load()` from the summaries the aggregation already
    /// carried, rather than fetched here — a computed property that reads the
    /// store would issue a query from inside a SwiftUI body.
    @Published private(set) var calorieTarget: Double?
}
