//
//  ExerciseProgressionView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI
import Charts
import CoreData

struct ExerciseProgressionView: View {
    @StateObject private var viewModel: ExerciseProgressionViewModel
    @State private var selectedMetric: MetricType = .volume
    @State private var selectedTimeRange: TimeRange = .month
    
    enum MetricType: String, CaseIterable {
        case volume = "Volume"
        case maxWeight = "Max Weight"
        case oneRM = "Est. 1RM"
        case totalSets = "Total Sets"

        /// The picker label.
        ///
        /// `rawValue` stays in English because it is also the chart's series
        /// name; only what is on screen is translated.
        var titleKey: String {
            switch self {
            case .volume: return "metric_volume"
            case .maxWeight: return "metric_max_weight"
            case .oneRM: return "metric_one_rm"
            case .totalSets: return "metric_total_sets"
            }
        }
    }
    
    enum TimeRange: String, CaseIterable {
        case week = "1W"
        case month = "1M"
        case threeMonths = "3M"
        case year = "1Y"
        case all = "All"

        /// The four numeric cases are abbreviations that read the same in every
        /// language this ships in; "All" is an English word and is not.
        var title: String {
            self == .all ? "time_range_all".localized : rawValue
        }
    }
    
    init(exercise: CDExercise, repository: WorkoutRepository) {
        self._viewModel = StateObject(wrappedValue: ExerciseProgressionViewModel(
            exercise: exercise,
            repository: repository
        ))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                exerciseInfoSection
                personalRecordsSection
                chartControlsSection
                progressionChartSection
                recentSetsSection
            }
        }
        // Its own key, not the shared `progress` one: that resolves through
        // Weight, where it means "trend". This title means progress, as in how
        // the lift has advanced.
        .navigationTitle("exercise_progression_title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadData()
        }
    }
    
    @ViewBuilder
    private var exerciseInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.exercise.name ?? "")
                .font(.title2)
                .bold()
            
            HStack(spacing: 16) {
                Label(viewModel.exercise.muscleGroup ?? "", systemImage: "figure.strengthtraining.traditional")
                Label(viewModel.exercise.equipment ?? "", systemImage: "dumbbell")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var personalRecordsSection: some View {
        VStack(spacing: 16) {
            Text("personal_records".localized)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                PRCard(
                    title: "pr_heaviest".localized,
                    value: WorkoutFormat.weight(viewModel.maxWeight),
                    date: viewModel.maxWeightDate,
                    icon: "scalemass.fill"
                )
                
                PRCard(
                    title: "pr_most_reps".localized,
                    value: "reps_count".localized(viewModel.maxReps),
                    subtitle: "@ \(WorkoutFormat.weight(viewModel.maxRepsWeight))",
                    date: viewModel.maxRepsDate,
                    icon: "number.circle.fill"
                )
                
                PRCard(
                    title: "pr_best_volume".localized,
                    value: WorkoutFormat.weight(viewModel.maxVolume),
                    date: viewModel.maxVolumeDate,
                    icon: "chart.bar.fill"
                )
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var chartControlsSection: some View {
        VStack(spacing: 16) {
            // Metric Selector
            Picker("metric".localized, selection: $selectedMetric) {
                ForEach(MetricType.allCases, id: \.self) { metric in
                    Text(metric.titleKey.localized).tag(metric)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // Time Range Selector
            HStack {
                Text("time_range".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 8) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Button {
                            selectedTimeRange = range
                        } label: {
                            Text(range.title)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedTimeRange == range ? Color.accentColor : Color.secondary.opacity(0.1))
                                .foregroundColor(selectedTimeRange == range ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var progressionChartSection: some View {
        if viewModel.chartData.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("no_data_available".localized)
                    .font(.headline)
                Text("complete_more_workouts_for_progress".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(height: 300)
        } else {
            Chart(viewModel.filteredChartData(for: selectedMetric, timeRange: selectedTimeRange)) { dataPoint in
                LineMark(
                    x: .value("Date", dataPoint.date),
                    y: .value(selectedMetric.rawValue, dataPoint.value)
                )
                .foregroundStyle(Color.accentColor)
                
                PointMark(
                    x: .value("Date", dataPoint.date),
                    y: .value(selectedMetric.rawValue, dataPoint.value)
                )
                .foregroundStyle(Color.accentColor)
            }
            .frame(height: 300)
            .padding(.horizontal)
        }
    }
    
    /// "80 kg × 8" — the weight and the reps of one set.
    private func progressionSummary(for set: CDWorkoutSet) -> String {
        "\(WorkoutFormat.weight(set.weightKg)) × \(set.reps) \("reps".localized)"
    }

    /// "Total Volume 640 kg · Est. 1RM 101 kg". The second half is appended
    /// only when the set can have an estimate at all.
    private func progressionMetrics(for set: CDWorkoutSet) -> String {
        var parts = [
            "\("total_volume".localized) \(WorkoutFormat.weight(WorkoutMetrics.setVolume(set)))"
        ]
        if let oneRM = WorkoutMetrics.estimatedOneRepMax(set) {
            parts.append("\("estimated_1rm".localized) \(WorkoutFormat.weight(oneRM))")
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var recentSetsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("recent_sets".localized)
                .font(.headline)
            
            ForEach(viewModel.recentSets.prefix(10)) { set in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(progressionSummary(for: set))
                            .font(.headline)

                        Text(progressionMetrics(for: set))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let date = set.workout?.date {
                            Text(date, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if viewModel.isPersonalRecord(set) {
                        Label("workout_pr".localized, systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
}

struct PRCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    let date: Date?
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if let date = date {
                Text(date, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

class ExerciseProgressionViewModel: ObservableObject {
    @Published var chartData: [ChartDataPoint] = []
    @Published var recentSets: [CDWorkoutSet] = []
    
    let exercise: CDExercise
    let repository: WorkoutRepository
    
    // Personal Records
    @Published var maxWeight: Double = 0
    @Published var maxWeightDate: Date?
    @Published var maxReps: Int32 = 0
    @Published var maxRepsWeight: Double = 0
    @Published var maxRepsDate: Date?
    @Published var maxVolume: Double = 0
    @Published var maxVolumeDate: Date?
    
    struct ChartDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
        let metric: ExerciseProgressionView.MetricType
    }
    
    init(exercise: CDExercise, repository: WorkoutRepository) {
        self.exercise = exercise
        self.repository = repository
    }
    
    func loadData() {
        // Fetch all sets for this exercise
        let request: NSFetchRequest<CDWorkoutSet> = CDWorkoutSet.fetchRequest()
        request.predicate = NSPredicate(format: "exercise == %@", exercise)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDWorkoutSet.workout?.date, ascending: false)]
        
        do {
            let sets = try repository.context.fetch(request)
            recentSets = sets
            
            // Calculate personal records
            calculatePersonalRecords(from: sets)
            
            // Generate chart data
            generateChartData(from: sets)
        } catch {
            print("Error fetching exercise sets: \(error)")
        }
    }
    
    private func calculatePersonalRecords(from sets: [CDWorkoutSet]) {
        for set in sets {
            // Max Weight
            if set.weightKg > maxWeight {
                maxWeight = set.weightKg
                maxWeightDate = set.workout?.date
            }
            
            // Max Reps
            if set.reps > maxReps || (set.reps == maxReps && set.weightKg > maxRepsWeight) {
                maxReps = set.reps
                maxRepsWeight = set.weightKg
                maxRepsDate = set.workout?.date
            }
            
            // Max Volume (single set)
            let volume = WorkoutMetrics.setVolume(set)
            if volume > maxVolume {
                maxVolume = volume
                maxVolumeDate = set.workout?.date
            }
        }
    }
    
    private func generateChartData(from sets: [CDWorkoutSet]) {
        // Group sets by workout date
        let groupedByDate = Dictionary(grouping: sets) { set -> Date in
            guard let date = set.workout?.date else { return Date() }
            return Calendar.current.startOfDay(for: date)
        }
        
        chartData = groupedByDate.flatMap { date, sets -> [ChartDataPoint] in
            guard !sets.isEmpty else { return [] }
            
            // Calculate metrics for each date
            let volume = WorkoutMetrics.volume(of: sets)
            let maxWeight = sets.map { $0.weightKg }.max() ?? 0
            let totalSets = Double(sets.count)
            let oneRM = WorkoutMetrics.bestEstimatedOneRepMax(in: sets) ?? 0
            
            return [
                ChartDataPoint(date: date, value: volume, metric: .volume),
                ChartDataPoint(date: date, value: maxWeight, metric: .maxWeight),
                ChartDataPoint(date: date, value: oneRM, metric: .oneRM),
                ChartDataPoint(date: date, value: totalSets, metric: .totalSets)
            ]
        }
    }
    
    func isPersonalRecord(_ set: CDWorkoutSet) -> Bool {
        // The `maxVolume > 0` guard is the point of this line as much as the
        // comparison is: without it, a workout where nothing has been logged yet
        // has `maxVolume == 0`, and every empty row would match `0 == 0` and be
        // badged a personal record.
        return set.weightKg == maxWeight ||
               (set.reps == maxReps && set.weightKg == maxRepsWeight) ||
               (maxVolume > 0 && WorkoutMetrics.setVolume(set) == maxVolume)
    }
    func filteredChartData(for metric: ExerciseProgressionView.MetricType, timeRange: ExerciseProgressionView.TimeRange) -> [ChartDataPoint] {
        let filtered = chartData.filter { $0.metric == metric }
        
        guard let earliestDate = filtered.map({ $0.date }).min() else { return filtered }
        
        let calendar = Calendar.current
        let cutoffDate: Date
        
        switch timeRange {
        case .week:
            cutoffDate = calendar.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? earliestDate
        case .month:
            cutoffDate = calendar.date(byAdding: .month, value: -1, to: Date()) ?? earliestDate
        case .threeMonths:
            cutoffDate = calendar.date(byAdding: .month, value: -3, to: Date()) ?? earliestDate
        case .year:
            cutoffDate = calendar.date(byAdding: .year, value: -1, to: Date()) ?? earliestDate
        case .all:
            cutoffDate = earliestDate
        }
        
        return filtered.filter { $0.date >= cutoffDate }.sorted { $0.date < $1.date }
    }
    
}