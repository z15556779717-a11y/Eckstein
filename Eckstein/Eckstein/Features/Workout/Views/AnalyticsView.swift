//
//  AnalyticsView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 14/07/2025.
//

import SwiftUI
import Charts
import CoreData

struct AnalyticsView: View {
    @State private var selectedExercise: CDExercise?
    @State private var exercises: [CDExercise] = []
    @State private var progressData: [ExerciseProgress] = []
    @State private var selectedTimeFrame: TimeFrame = .month
    @Environment(\.managedObjectContext) private var context
    @ObservedObject private var themeManager = ThemeManager.shared
    
    enum TimeFrame: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case threeMonths = "3 Months"
        case year = "Year"
        
        var localizedName: String {
            switch self {
            case .week: return "week".localized
            case .month: return "month".localized
            case .threeMonths: return "3_months".localized
            case .year: return "year".localized
            }
        }
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            case .year: return 365
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Exercise Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("select_exercise".localized)
                        .font(.headline)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(exercises, id: \.id) { exercise in
                                ExerciseChip(
                                    exercise: exercise,
                                    isSelected: selectedExercise?.id == exercise.id,
                                    onSelect: {
                                        selectedExercise = exercise
                                        loadProgressData()
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Time Frame Selection
                Picker("time_frame".localized, selection: $selectedTimeFrame) {
                    ForEach(TimeFrame.allCases, id: \.self) { frame in
                        Text(frame.localizedName).tag(frame)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .onChange(of: selectedTimeFrame) { _, _ in
                    loadProgressData()
                }
                
                if let exercise = selectedExercise {
                    // Progress Summary
                    ProgressSummaryCard(exercise: exercise, progressData: progressData)
                        .padding(.horizontal)
                    
                    // Weight Progress Chart
                    if !progressData.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("weight_progress".localized)
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Chart(progressData) { data in
                                LineMark(
                                    x: .value("Date", data.date),
                                    y: .value("Weight", data.maxWeight)
                                )
                                .foregroundStyle(themeManager.accentColor == .defaultMix ? 
                                               themeManager.accentColor.contextColor(for: .workout) : 
                                               themeManager.accentColor.color)
                                .symbol(.circle)
                                .symbolSize(60)
                                
                                PointMark(
                                    x: .value("Date", data.date),
                                    y: .value("Weight", data.maxWeight)
                                )
                                .foregroundStyle(themeManager.accentColor == .defaultMix ? 
                                               themeManager.accentColor.contextColor(for: .workout) : 
                                               themeManager.accentColor.color)
                            }
                            .frame(height: 200)
                            .padding(.horizontal)
                            .chartYAxisLabel("weight_kg".localized)
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .day)) { _ in
                                    AxisGridLine()
                                    AxisValueLabel(format: .dateTime.day().month())
                                }
                            }
                        }
                        
                        // Reps Achievement Chart
                        VStack(alignment: .leading, spacing: 12) {
                            Text("reps_achievement".localized)
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Chart(progressData) { data in
                                BarMark(
                                    x: .value("Date", data.date),
                                    y: .value("Achievement", data.averageAchievement)
                                )
                                .foregroundStyle(data.averageAchievement >= 100 ? 
                                               (themeManager.accentColor == .defaultMix ? 
                                                themeManager.accentColor.contextColor(for: .workout) : 
                                                themeManager.accentColor.color) : 
                                               (themeManager.accentColor == .defaultMix ? 
                                                themeManager.accentColor.contextColor(for: .workout) : 
                                                themeManager.accentColor.color).opacity(0.7))
                            }
                            .frame(height: 200)
                            .padding(.horizontal)
                            .chartYAxisLabel("achievement_percent".localized)
                            .chartYScale(domain: 0...150)
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .day)) { _ in
                                    AxisGridLine()
                                    AxisValueLabel(format: .dateTime.day().month())
                                }
                            }
                        }
                        
                        // Volume Chart
                        VStack(alignment: .leading, spacing: 12) {
                            Text("training_volume".localized)
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Chart(progressData) { data in
                                AreaMark(
                                    x: .value("Date", data.date),
                                    y: .value("Volume", data.totalVolume)
                                )
                                .foregroundStyle((themeManager.accentColor == .defaultMix ? 
                                               themeManager.accentColor.contextColor(for: .workout) : 
                                               themeManager.accentColor.color).opacity(0.3))
                                
                                LineMark(
                                    x: .value("Date", data.date),
                                    y: .value("Volume", data.totalVolume)
                                )
                                .foregroundStyle(themeManager.accentColor == .defaultMix ? 
                                               themeManager.accentColor.contextColor(for: .workout) : 
                                               themeManager.accentColor.color)
                            }
                            .frame(height: 200)
                            .padding(.horizontal)
                            .chartYAxisLabel("volume_kg".localized)
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .day)) { _ in
                                    AxisGridLine()
                                    AxisValueLabel(format: .dateTime.day().month())
                                }
                            }
                        }
                    }
                } else {
                    // Empty State
                    VStack(spacing: 20) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("select_exercise_view_analytics".localized)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 60)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("analytics".localized)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadExercises()
        }
    }
    
    private func loadExercises() {
        let request: NSFetchRequest<CDExercise> = CDExercise.fetchRequest()
        request.predicate = NSPredicate(format: "workoutSets.@count > 0")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDExercise.name, ascending: true)]
        
        do {
            exercises = try context.fetch(request)
            if let first = exercises.first {
                selectedExercise = first
                loadProgressData()
            }
        } catch {
            print("Error loading exercises: \(error)")
        }
    }
    
    private func loadProgressData() {
        guard let exercise = selectedExercise else { return }
        
        let startDate = Calendar.current.date(byAdding: .day, value: -selectedTimeFrame.days, to: Date()) ?? Date()
        
        let request: NSFetchRequest<CDWorkoutSet> = CDWorkoutSet.fetchRequest()
        request.predicate = NSPredicate(
            format: "exercise == %@ AND workout.date >= %@ AND completed == YES",
            exercise, startDate as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDWorkoutSet.workout?.date, ascending: true)]
        
        do {
            let sets = try context.fetch(request)
            
            // Group by date
            let grouped = Dictionary(grouping: sets) { (set: CDWorkoutSet) -> Date in
                let date = set.workout?.date ?? Date()
                return Calendar.current.startOfDay(for: date)
            }
            
            progressData = grouped.map { (date, sets) in
                let maxWeight = sets.map { $0.weightKg }.max() ?? 0
                let totalVolume = WorkoutMetrics.volume(of: sets)
                let averageAchievement = calculateAverageAchievement(sets: sets)
                
                return ExerciseProgress(
                    date: date,
                    maxWeight: maxWeight,
                    totalVolume: totalVolume,
                    averageAchievement: averageAchievement
                )
            }.sorted { $0.date < $1.date }
            
        } catch {
            print("Error loading progress data: \(error)")
        }
    }
    
    private func calculateAverageAchievement(sets: [CDWorkoutSet]) -> Double {
        let achievements = sets.compactMap { set -> Double? in
            guard set.targetReps > 0 else { return nil }
            return (Double(set.reps) / Double(set.targetReps)) * 100
        }
        
        return achievements.isEmpty ? 0 : achievements.reduce(0, +) / Double(achievements.count)
    }
}

struct ExerciseProgress: Identifiable {
    let id = UUID()
    let date: Date
    let maxWeight: Double
    let totalVolume: Double
    let averageAchievement: Double
}

struct ExerciseChip: View {
    let exercise: CDExercise
    let isSelected: Bool
    let onSelect: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(action: onSelect) {
            Text(exercise.name ?? "unknown_exercise".localized)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? (themeManager.accentColor == .defaultMix ? 
                                        themeManager.accentColor.contextColor(for: .workout) : 
                                        themeManager.accentColor.color) : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct ProgressSummaryCard: View {
    let exercise: CDExercise
    let progressData: [ExerciseProgress]
    
    private var weightImprovement: (current: Double, previous: Double, percentage: Double) {
        guard progressData.count >= 2 else { return (0, 0, 0) }
        
        let recent = progressData.suffix(5).map { $0.maxWeight }.max() ?? 0
        let older = progressData.prefix(5).map { $0.maxWeight }.max() ?? 0
        
        let percentage = older > 0 ? ((recent - older) / older) * 100 : 0
        
        return (recent, older, percentage)
    }
    
    private var volumeImprovement: (current: Double, previous: Double, percentage: Double) {
        guard progressData.count >= 2 else { return (0, 0, 0) }
        
        let recentAvg = progressData.suffix(3).map { $0.totalVolume }.reduce(0, +) / 3
        let olderAvg = progressData.prefix(3).map { $0.totalVolume }.reduce(0, +) / 3
        
        let percentage = olderAvg > 0 ? ((recentAvg - olderAvg) / olderAvg) * 100 : 0
        
        return (recentAvg, olderAvg, percentage)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text(exercise.name ?? "unknown_exercise".localized)
                .font(.title3)
                .fontWeight(.bold)
            
            HStack(spacing: 20) {
                // Weight Progress
                VStack(alignment: .leading, spacing: 8) {
                    Label("max_weight".localized, systemImage: "scalemass")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(String(format: "%.1f", weightImprovement.current)) " + "kg".localized)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 4) {
                        Image(systemName: weightImprovement.percentage >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption)
                        Text("\(String(format: "%.1f", abs(weightImprovement.percentage)))%")
                            .font(.caption)
                    }
                    .foregroundColor(weightImprovement.percentage >= 0 ? .green : .red)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                    .frame(height: 60)
                
                // Volume Progress
                VStack(alignment: .leading, spacing: 8) {
                    Label("avg_volume".localized, systemImage: "chart.bar.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(String(format: "%.0f", volumeImprovement.current)) " + "kg".localized)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 4) {
                        Image(systemName: volumeImprovement.percentage >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption)
                        Text("\(String(format: "%.1f", abs(volumeImprovement.percentage)))%")
                            .font(.caption)
                    }
                    .foregroundColor(volumeImprovement.percentage >= 0 ? .green : .red)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}