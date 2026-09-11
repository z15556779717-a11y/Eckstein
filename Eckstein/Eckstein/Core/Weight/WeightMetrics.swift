//
//  WeightMetrics.swift
//  Eckstein
//
//  Body-weight maths for the phase-4 Progress UI: trend series, BMI and the
//  distance to a target weight.
//
//  Why this is not in the views. Every value here is a rule the product has an
//  opinion about — which of two same-day weigh-ins wins, what "no data" is
//  distinct from, which way round a target is. A SwiftUI body is not a place to
//  hold a rule like that: it cannot be tested, and two screens that each work it
//  out for themselves drift apart. The views format these values; they do not
//  derive them.
//
//  The functions take plain `(date, kilograms)` pairs rather than
//  `CDWeightEntry`, so the maths is testable without a Core Data stack. The
//  `CDWeightEntry` conveniences at the bottom are the only part that touches the
//  store.
//

import Foundation

// MARK: - Ranges

/// A time span the Progress screen can show.
enum WeightRange: String, CaseIterable, Identifiable, Hashable {
    case week
    case month
    case quarter
    case year

    var id: String { rawValue }

    /// How many days back from the end date the range covers, inclusive of both
    /// ends.
    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        }
    }

    /// The localization key for this range's picker label.
    var titleKey: String {
        switch self {
        case .week: return "range_7_days"
        case .month: return "range_30_days"
        case .quarter: return "range_90_days"
        case .year: return "range_1_year"
        }
    }
}

// MARK: - Points

/// One plotted day.
///
/// `weightKg` is `nil` when the range covers a day with no weigh-in. That
/// distinction is the whole reason this is not a bare `Double`: a gap in a
/// weight chart must be a gap, and drawing it as `0` would put a spike through
/// the floor of the chart and read as a catastrophic weight loss.
struct WeightPoint: Identifiable, Equatable {
    let date: Date
    let weightKg: Double?

    var id: Date { date }
    var hasValue: Bool { weightKg != nil }
}

/// A day's nutrition totals for the trend charts.
///
/// Same reasoning as `WeightPoint`: a day with nothing logged is `nil`, not
/// zero. Zero calories is a real (if unlikely) thing to record; "no data" is
/// not the same claim, and a bar chart that conflates them is lying.
struct NutritionTrendPoint: Identifiable, Equatable {
    let date: Date
    let calories: Double?
    let protein: Double?

    var id: Date { date }
    var hasValue: Bool { calories != nil || protein != nil }
}

// MARK: - BMI

/// A BMI band.
///
/// Deliberately four plain bands with no clinical language. The app is not a
/// diagnostic tool, and a label like "obese" presented without context to
/// someone who is not expecting it does more harm than the number does good.
/// The thresholds are the conventional adult cut-offs.
enum BMICategory: String, CaseIterable {
    case underweight
    case normal
    case overweight
    case obese

    /// The localization key for this band's label.
    var titleKey: String {
        switch self {
        case .underweight: return "bmi_underweight"
        case .normal: return "bmi_normal"
        case .overweight: return "bmi_overweight"
        case .obese: return "bmi_obese"
        }
    }
}

// MARK: - Target

/// The distance from the current weight to the target weight, with the
/// direction already resolved.
///
/// `remainingKg` is never negative, because it is not a signed difference — it
/// is a distance. `direction` carries the sign, so the UI can say "4.2 kg to go"
/// or "2.5 kg to gain" without ever showing a person a minus sign next to their
/// own body weight.
struct WeightTargetProgress: Equatable {
    let currentKg: Double
    let targetKg: Double

    enum Direction: Equatable {
        case lose
        case gain
        case atTarget
    }

    /// Absolute distance to the target.
    var remainingKg: Double { abs(currentKg - targetKg) }

    var direction: Direction {
        // Compared with a tolerance rather than `==`: two doubles that came out
        // of a unit conversion are almost never bit-identical even when they
        // represent the same weight, and "0.0000001 kg to go" is not a sentence
        // worth rendering.
        if remainingKg < Self.tolerance { return .atTarget }
        return currentKg > targetKg ? .lose : .gain
    }

    var isAtTarget: Bool { direction == .atTarget }

    /// A localization key for the whole sentence, so the view picks a phrasing
    /// rather than assembling one from fragments it would have to order itself.
    var descriptionKey: String {
        switch direction {
        case .lose: return "weight_to_go_lose"
        case .gain: return "weight_to_go_gain"
        case .atTarget: return "weight_at_target"
        }
    }

    /// Half a gram. Below this the two weights are the same weight.
    static let tolerance = 0.0005
}

// MARK: - Metrics

/// The body-weight calculations.
enum WeightMetrics {

    // MARK: Daily series

    /// One point per calendar day across `range`, oldest first.
    ///
    /// Every day in the range is present, including days with no weigh-in, so
    /// the x-axis is evenly spaced and a gap stays a gap.
    ///
    /// **Same-day resolution.** A day with several weigh-ins is represented by
    /// its *latest* reading. That is the right rule here rather than an average:
    /// the app's own weigh-in guidance is to weigh once, first thing, and a
    /// second reading later in the day is a correction to the first rather than
    /// a second independent sample. Averaging would let a mid-afternoon reading
    /// pull the day's number away from the morning one the user actually meant
    /// to record.
    ///
    /// Ties on `date` are broken by `id` so the result is deterministic rather
    /// than dependent on fetch order — two readings at the same instant are
    /// otherwise indistinguishable, and an unstable chart is worse than an
    /// arbitrary but fixed one.
    static func dailySeries(
        from entries: [(date: Date, weightKg: Double, id: UUID)],
        endingOn endDate: Date,
        range: WeightRange,
        calendar: Calendar = .current
    ) -> [WeightPoint] {
        let byDay = latestByDay(entries, calendar: calendar)

        var points: [WeightPoint] = []
        let end = calendar.startOfDay(for: endDate)

        for offset in stride(from: range.days - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: end) else { continue }
            points.append(WeightPoint(date: day, weightKg: byDay[day]))
        }

        return points
    }

    /// The latest reading for each day, keyed by `startOfDay`.
    static func latestByDay(
        _ entries: [(date: Date, weightKg: Double, id: UUID)],
        calendar: Calendar = .current
    ) -> [Date: Double] {
        // Sorted by instant, then by id, so "the last one wins" below is a fixed
        // outcome rather than whatever order the fetch returned.
        let ordered = entries.sorted {
            $0.date == $1.date
                ? $0.id.uuidString < $1.id.uuidString
                : $0.date < $1.date
        }

        var byDay: [Date: Double] = [:]
        for entry in ordered {
            byDay[calendar.startOfDay(for: entry.date)] = entry.weightKg
        }
        return byDay
    }

    /// The most recent reading at or before `date`, or the earliest reading if
    /// every entry is in the future.
    ///
    /// This is the single definition of "current weight": the newest weigh-in by
    /// date, not by insertion order and not a cached copy. Profile, Dashboard and
    /// the Progress screen all read it from here, so they cannot disagree.
    static func currentWeight(
        from entries: [(date: Date, weightKg: Double, id: UUID)]
    ) -> Double? {
        entries.max { $0.date < $1.date }?.weightKg
    }

    /// The change across the range: last reading minus first reading.
    ///
    /// `nil` when fewer than two days in the series have a value — a "change"
    /// measured from a single point is not a change.
    static func changeOverRange(_ points: [WeightPoint]) -> Double? {
        let values = points.compactMap(\.weightKg)
        guard values.count >= 2, let first = values.first, let last = values.last else {
            return nil
        }
        return last - first
    }

    // MARK: BMI

    /// The heights, in centimetres, the app will compute a BMI from.
    ///
    /// 50 cm to 260 cm. Outside this the stored height is a typo or a unit
    /// mix-up (170 in inches, 1.7 in metres), and the square in the BMI formula
    /// turns either into a confidently wrong number. Exposed so the editor can
    /// refuse the same values the calculation does.
    static let plausibleHeightCm: ClosedRange<Double> = 50...260

    /// Whether a height is one the app will use.
    static func isValidHeight(_ heightCm: Double?) -> Bool {
        guard let heightCm, heightCm.isFinite else { return false }
        return plausibleHeightCm.contains(heightCm)
    }

    /// Body mass index, or `nil` when it cannot be computed honestly.
    ///
    /// Returns `nil` for a missing, zero or negative height or weight, and for a
    /// height outside `plausibleHeightCm`. A malformed height is a data-entry
    /// problem, and reporting a BMI derived from it would dress that up as a
    /// measurement.
    static func bmi(weightKg: Double?, heightCm: Double?) -> Double? {
        guard let weightKg, let heightCm else { return nil }
        guard weightKg.isFinite, heightCm.isFinite else { return nil }
        guard weightKg > 0, isValidHeight(heightCm) else { return nil }

        let metres = heightCm / 100
        let value = weightKg / (metres * metres)
        guard value.isFinite else { return nil }
        return value
    }

    /// The band `bmi` falls in, or `nil` when there is no BMI.
    static func bmiCategory(for bmi: Double?) -> BMICategory? {
        guard let bmi, bmi.isFinite, bmi > 0 else { return nil }
        switch bmi {
        case ..<18.5: return .underweight
        case ..<25: return .normal
        case ..<30: return .overweight
        default: return .obese
        }
    }

    /// BMI rounded for display, or `nil`.
    static func formattedBMI(weightKg: Double?, heightCm: Double?) -> String? {
        guard let bmi = bmi(weightKg: weightKg, heightCm: heightCm) else { return nil }
        return String(format: "%.1f", bmi)
    }

    // MARK: Target

    /// The distance to a target weight, or `nil` when either end is missing.
    static func targetProgress(currentKg: Double?, targetKg: Double?) -> WeightTargetProgress? {
        guard let currentKg, let targetKg else { return nil }
        guard currentKg.isFinite, targetKg.isFinite, currentKg > 0, targetKg > 0 else {
            return nil
        }
        return WeightTargetProgress(currentKg: currentKg, targetKg: targetKg)
    }
}

// MARK: - Core Data conveniences

import CoreData

extension WeightMetrics {
    /// `dailySeries` over managed objects.
    ///
    /// Entries with no `date` are dropped: an undated weigh-in cannot be placed
    /// on a time axis, and guessing "today" for it would move a historical point
    /// every time the app opened.
    static func dailySeries(
        entries: [CDWeightEntry],
        endingOn endDate: Date,
        range: WeightRange,
        calendar: Calendar = .current
    ) -> [WeightPoint] {
        let tuples = entries.compactMap { entry -> (date: Date, weightKg: Double, id: UUID)? in
            guard let date = entry.date else { return nil }
            return (date: date, weightKg: entry.weightKg, id: entry.id ?? UUID())
        }
        return dailySeries(from: tuples, endingOn: endDate, range: range, calendar: calendar)
    }

    /// `currentWeight` over managed objects.
    static func currentWeight(from entries: [CDWeightEntry]) -> Double? {
        let tuples = entries.compactMap { entry -> (date: Date, weightKg: Double, id: UUID)? in
            guard let date = entry.date else { return nil }
            return (date: date, weightKg: entry.weightKg, id: entry.id ?? UUID())
        }
        return currentWeight(from: tuples)
    }
}

// MARK: - Nutrition series

extension WeightMetrics {
    /// One point per day for the nutrition trend charts.
    ///
    /// Built from summaries the nutrition layer already aggregated — the same
    /// numbers the Diet screen shows, not a second sum over the entries. A day
    /// the range covers but nobody logged is `nil` at both fields.
    static func nutritionSeries(
        from summaries: [DailyNutritionSummary],
        calendar: Calendar = .current
    ) -> [NutritionTrendPoint] {
        summaries.map { summary in
            NutritionTrendPoint(
                date: calendar.startOfDay(for: summary.date),
                calories: summary.isEmpty ? nil : summary.totals.calories,
                protein: summary.isEmpty ? nil : summary.totals.protein
            )
        }
    }
}
