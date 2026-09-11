//
//  DashboardViewModel.swift
//  Eckstein
//
//  The home screen's data.
//
//  Everything here is read through the official aggregation — `NutritionService`
//  for the day's nutrition, `WeightMetrics` for the body-weight figures — so the
//  Dashboard cannot drift from the Diet screen or the Progress screen. The view
//  formats; it does not sum, and it does not know which day it is looking at.
//

import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {

    // MARK: - Published state

    /// Today's nutrition, or `nil` before the first load.
    @Published private(set) var summary: DailyNutritionSummary?

    /// Today's totals read against today's goals. Built from `summary`, so the
    /// two can never disagree.
    @Published private(set) var progress: NutritionGoalProgress?

    /// Today's workouts, most recent first. Empty is a normal state, not an
    /// error — plenty of days have no workout.
    @Published private(set) var todaysWorkouts: [CDWorkout] = []

    /// The newest weigh-in, in kilograms, or `nil` when nothing is logged.
    @Published private(set) var currentWeightKg: Double?

    /// The distance to the target weight, or `nil` when there is no target or no
    /// weigh-in yet.
    @Published private(set) var targetProgress: WeightTargetProgress?

    /// BMI for the current weight, or `nil` when the height is missing or
    /// implausible. `nil` is rendered as "no BMI", never as a number.
    @Published private(set) var bmi: Double?

    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    /// The user's display unit.
    @Published private(set) var unit: WeightUnit = .preferred

    // MARK: - Dependencies

    private let nutrition: NutritionService
    private let weightRepository: WeightRepository
    private let workoutRepository: WorkoutRepository
    private let calendar: Calendar

    init(
        nutrition: NutritionService = .shared,
        weightRepository: WeightRepository = .shared,
        workoutRepository: WorkoutRepository = ServiceContainer.shared.workoutRepository,
        calendar: Calendar = .current
    ) {
        self.nutrition = nutrition
        self.weightRepository = weightRepository
        self.workoutRepository = workoutRepository
        self.calendar = calendar
    }

    // MARK: - Loading

    func load() async {
        // The spinner is for the first load only. Re-entering the tab re-reads
        // the numbers, but flashing a spinner over content the user is already
        // looking at is worse than showing it a beat stale.
        if summary == nil { isLoading = true }
        errorMessage = nil

        do {
            let summary = try nutrition.dailySummary(for: Date(), calendar: calendar)
            self.summary = summary
            self.progress = NutritionGoalProgress(summary: summary)
        } catch {
            // The nutrition figures are the screen's main content, so a failure
            // here is a failure of the screen. The weight and workout cards are
            // still rendered below — a partial screen beats a blank one, and the
            // error view is scoped to what actually failed.
            self.errorMessage = "error_loading_data".localized
        }

        loadWeight()
        loadWorkouts()

        isLoading = false
    }

    private func loadWeight() {
        weightRepository.refresh()

        let entries = weightRepository.weightEntries
        // The newest entry by *date*, through the one definition of that rule —
        // not `latestEntry` and not a cached Profile field.
        currentWeightKg = WeightMetrics.currentWeight(from: entries)
        unit = .preferred

        targetProgress = WeightMetrics.targetProgress(
            currentKg: currentWeightKg,
            targetKg: weightRepository.goalWeight
        )

        bmi = WeightMetrics.bmi(weightKg: currentWeightKg, heightCm: Self.storedHeightCm())
    }

    private func loadWorkouts() {
        workoutRepository.fetchWorkouts()
        let today = Date()
        todaysWorkouts = workoutRepository.workouts.filter { workout in
            guard let date = workout.date else { return false }
            return calendar.isDate(date, inSameDayAs: today)
        }
    }

    // MARK: - Derived display values

    /// The body-mass index band for the current BMI, if there is one.
    var bmiCategory: BMICategory? {
        WeightMetrics.bmiCategory(for: bmi)
    }

    /// BMI rounded to one decimal, or `nil`.
    var bmiText: String? {
        guard let bmi else { return nil }
        return String(format: "%.1f", bmi)
    }

    var currentWeightText: String? {
        unit.formatted(kilograms: currentWeightKg)
    }

    var targetWeightText: String? {
        unit.formatted(kilograms: weightRepository.goalWeight)
    }

    /// "4.2 kg to go" / "2.5 kg to gain" / "At your target weight", or `nil` when
    /// there is no target to measure against.
    var targetDescription: String? {
        guard let targetProgress else { return nil }
        guard let distance = unit.formattedDistance(kilograms: targetProgress.remainingKg) else {
            return nil
        }
        return targetProgress.descriptionKey.localized(distance)
    }

    /// Whether a target weight exists at all.
    var hasTarget: Bool {
        targetProgress != nil
    }

    /// Whether any weight has been logged.
    var hasWeightData: Bool {
        currentWeightKg != nil
    }

    /// The hour-appropriate greeting, as a localization key.
    ///
    /// Computed rather than stored: the Dashboard can sit on screen across noon,
    /// and a greeting that says "Good morning" at 3pm is a small thing that
    /// reads as a bug.
    var greetingKey: String {
        switch calendar.component(.hour, from: Date()) {
        case 5..<12: return "dashboard_greeting_morning"
        case 12..<18: return "dashboard_greeting_afternoon"
        default: return "dashboard_greeting_evening"
        }
    }

    /// Today's date, formatted in the app's current language.
    var todayText: String {
        let formatter = DateFormatter()
        formatter.locale = LocalizationManager.shared.currentLocale
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }

    /// The remaining calories as a sentence.
    ///
    /// `nil` when no calorie goal is set — "剩余 0 kcal" for a user who has never
    /// set a target would be a lie about a target of zero.
    ///
    /// Over target the *unclamped* negative remaining is used, so the caption can
    /// say how far over the user is instead of showing "0 left".
    var calorieCaption: String? {
        guard let calories = progress?.calories, let remaining = calories.remaining else {
            return nil
        }
        guard let magnitude = NutrientFormat.calorieMagnitude(remaining) else { return nil }
        if remaining < 0 {
            return "dashboard_over_by".localized(magnitude)
        }
        return "dashboard_left_today".localized(magnitude)
    }

    /// Whether the day is over the calorie target.
    var isOverCalorieTarget: Bool {
        progress?.calories.isOverTarget ?? false
    }

    /// The nutrition ring's fill, clamped to `0...1` for drawing. The unclamped
    /// ratio stays on `progress`.
    var calorieDisplayProgress: Double {
        progress?.calories.displayProgress ?? 0
    }

    /// The height stored for this user, in centimetres.
    ///
    /// One of two places the app records a height — this `UserDefaults` key is
    /// the one `CDWeightEntry.bmi` and the profile editor already read, so it is
    /// the one that stays authoritative here rather than a second reading of
    /// `CDUserPreferences.heightCm` that could disagree with it. `BodyHeight`
    /// names the key and applies the plausibility range the BMI formula uses.
    static func storedHeightCm() -> Double? {
        BodyHeight.storedCentimetres
    }
}
