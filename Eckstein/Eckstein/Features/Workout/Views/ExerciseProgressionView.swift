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
    }
    
    enum TimeRange: String, CaseIterable {
        case week = "1W"
        case month = "1M"
        case threeMonths = "3M"
        case year = "1Y"
        case all = "All"
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
        .navigationTitle("Progress")
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
            Text("Personal Records")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                PRCard(
                    title: "Heaviest",
                    value: "\(Int(viewModel.maxWeight)) kg",
                    date: viewModel.maxWeightDate,
                    icon: "scalemass.fill"
                )
                
                PRCard(
                    title: "Most Reps",
                    value: "\(viewModel.maxReps) reps",
                    subtitle: "@ \(Int(viewModel.maxRepsWeight)) kg",
                    date: viewModel.maxRepsDate,
                    icon: "number.circle.fill"
                )
                
                PRCard(
                    title: "Best Volume",
                    value: "\(Int(viewModel.maxVolume)) kg",
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
            Picker("Metric", selection: $selectedMetric) {
                ForEach(MetricType.allCases, id: \.self) { metric in
                    Text(metric.rawValue).tag(metric)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // Time Range Selector
            HStack {
                Text("Time Range")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 8) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Button {
                            selectedTimeRange = range
                        } label: {
                            Text(range.rawValue)
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
                Text("No data available")
                    .font(.headline)
                Text("Complete more workouts to see progress")
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
    
    @ViewBuilder
    private var recentSetsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Sets")
                .font(.headline)
            
            ForEach(viewModel.recentSets.prefix(10)) { set in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Int(set.weightKg)) kg × \(set.reps) reps")
                            .font(.headline)
                        
                        if let date = set.workout?.date {
                            Text(date, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if viewModel.isPersonalRecord(set) {
                        Label("PR", systemImage: "star.fill")
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
            let volume = set.weightKg * Double(set.reps)
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
            let volume = sets.reduce(0) { $0 + ($1.weightKg * Double($1.reps)) }
            let maxWeight = sets.map { $0.weightKg }.max() ?? 0
            let totalSets = Double(sets.count)
            let oneRM = calculateOneRM(from: sets)
            
            return [
                ChartDataPoint(date: date, value: volume, metric: .volume),
                ChartDataPoint(date: date, value: maxWeight, metric: .maxWeight),
                ChartDataPoint(date: date, value: oneRM, metric: .oneRM),
                ChartDataPoint(date: date, value: totalSets, metric: .totalSets)
            ]
        }
    }
    
    private func calculateOneRM(from sets: [CDWorkoutSet]) -> Double {
        // Epley Formula: 1RM = weight × (1 + reps/30)
        return sets.compactMap { set in
            guard set.reps > 0 else { return nil }
            return set.weightKg * (1 + Double(set.reps) / 30)
        }.max() ?? 0
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
    
    func isPersonalRecord(_ set: CDWorkoutSet) -> Bool {
        return set.weightKg == maxWeight ||
               (set.reps == maxReps && set.weightKg == maxRepsWeight) ||
               (set.weightKg * Double(set.reps) == maxVolume)
    }
}