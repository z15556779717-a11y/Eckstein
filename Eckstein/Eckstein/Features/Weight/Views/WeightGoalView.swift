//
//  WeightGoalView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

struct WeightGoalView: View {
    @ObservedObject var viewModel: WeightViewModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @State private var goalWeightString = ""
    @State private var targetDate = Date().addingTimeInterval(60 * 60 * 24 * 90) // 90 days from now
    @State private var showingDeleteAlert = false
    
    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: UserDefaults.standard.string(forKey: "weightUnit") ?? "kg") ?? .kg
    }
    
    private var currentWeight: Double? {
        viewModel.currentWeight
    }
    
    private var progressInfo: (percentage: Double, remaining: Double, estimatedDate: Date?)? {
        guard let current = currentWeight,
              let goalWeight = Double(goalWeightString.replacingOccurrences(of: ",", with: ".")) else {
            return nil
        }
        
        let goalInKg = weightUnit == .lbs ? goalWeight * 0.453592 : goalWeight
        let totalChange = abs(goalInKg - current)
        let progress = abs(current - (viewModel.startWeight ?? current))
        let percentage = totalChange > 0 ? (progress / totalChange) * 100 : 0
        let remaining = abs(goalInKg - current)
        
        // Estimate completion date based on trend
        let trend = viewModel.weightTrend
        let weeklyChange = viewModel.weeklyChange
        
        var estimatedDate: Date?
        if abs(weeklyChange) > 0.1 { // At least 0.1 kg/week change
            let weeksNeeded = remaining / abs(weeklyChange)
            estimatedDate = Date().addingTimeInterval(weeksNeeded * 7 * 24 * 60 * 60)
        }
        
        return (percentage: min(100, max(0, percentage)), 
                remaining: remaining,
                estimatedDate: estimatedDate)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Current Status
                    if let current = currentWeight {
                        CurrentStatusCard(
                            currentWeight: current,
                            unit: weightUnit,
                            trend: viewModel.repository.getWeightTrend()
                        )
                    }
                    
                    // Goal Weight Input
                    VStack(alignment: .leading, spacing: 12) {
                        Label("target_weight".localized, systemImage: "target")
                            .font(.headline)
                        
                        HStack {
                            TextField(goalPlaceholder, text: $goalWeightString)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 28, weight: .semibold, design: .rounded))
                                .multilineTextAlignment(.center)
                            
                            Text(weightUnit.rawValue)
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        if let existingGoal = viewModel.goalWeight {
                            let displayGoal = weightUnit == .lbs ? existingGoal * 2.20462 : existingGoal
                            Text("\("current_goal".localized): \(String(format: "%.1f", displayGoal)) \(weightUnit.rawValue)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Target Date
                    VStack(alignment: .leading, spacing: 12) {
                        Label("target_date".localized, systemImage: "calendar.badge.clock")
                            .font(.headline)
                        
                        DatePicker(
                            "",
                            selection: $targetDate,
                            in: Date()...,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // Quick date options
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach([30, 60, 90, 180], id: \.self) { days in
                                    Button(action: {
                                        targetDate = Date().addingTimeInterval(Double(days) * 24 * 60 * 60)
                                    }) {
                                        Text("\(days) \("days".localized)")
                                            .font(.subheadline)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color(.systemGray5))
                                            .cornerRadius(20)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Progress Preview
                    if let progress = progressInfo {
                        ProgressPreviewCard(
                            progress: progress,
                            targetDate: targetDate,
                            unit: weightUnit
                        )
                    }
                    
                    // Milestones
                    if let current = currentWeight,
                       let goalWeight = Double(goalWeightString.replacingOccurrences(of: ",", with: ".")) {
                        MilestonesCard(
                            currentWeight: current,
                            goalWeight: weightUnit == .lbs ? goalWeight * 0.453592 : goalWeight,
                            unit: weightUnit
                        )
                    }
                    
                    if viewModel.goalWeight != nil {
                        Button(action: {
                            showingDeleteAlert = true
                        }) {
                            Label("remove_goal".localized, systemImage: "trash")
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("weight_goal".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save".localized) {
                        saveGoal()
                    }
                    .fontWeight(.semibold)
                    .disabled(goalWeightString.isEmpty)
                }
            }
            .alert("remove_goal".localized, isPresented: $showingDeleteAlert) {
                Button("cancel".localized, role: .cancel) { }
                Button("remove".localized, role: .destructive) {
                    viewModel.removeGoal()
                    dismiss()
                }
            } message: {
                Text("remove_goal_confirmation".localized)
            }
        }
        .onAppear {
            loadExistingGoal()
        }
    }
    
    private var goalPlaceholder: String {
        if let current = currentWeight {
            let displayWeight = weightUnit == .lbs ? current * 2.20462 : current
            let suggestedGoal = displayWeight * 0.95 // Suggest 5% weight loss
            return String(format: "%.1f", suggestedGoal)
        }
        return weightUnit == .kg ? "weight_placeholder_kg".localized : "weight_placeholder_lbs".localized
    }
    
    private func loadExistingGoal() {
        if let existingGoal = viewModel.goalWeight {
            let displayGoal = weightUnit == .lbs ? existingGoal * 2.20462 : existingGoal
            goalWeightString = String(format: "%.1f", displayGoal)
        }
        
        if let existingDate = viewModel.goalDate {
            targetDate = existingDate
        }
    }
    
    private func saveGoal() {
        guard let goalWeight = Double(goalWeightString.replacingOccurrences(of: ",", with: ".")) else {
            return
        }
        
        let goalInKg = weightUnit == .lbs ? goalWeight * 0.453592 : goalWeight
        viewModel.setGoal(weight: goalInKg, targetDate: targetDate)
        dismiss()
    }
}

struct CurrentStatusCard: View {
    let currentWeight: Double
    let unit: WeightUnit
    let trend: WeightTrend
    
    private var displayWeight: String {
        let weight = unit == .lbs ? currentWeight * 2.20462 : currentWeight
        return String(format: "%.1f", weight)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("current_weight".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Text(displayWeight)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(unit.rawValue)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: trend.icon)
                        .font(.title2)
                        .foregroundColor(trend.color)
                    
                    Text(trend.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

struct ProgressPreviewCard: View {
    let progress: (percentage: Double, remaining: Double, estimatedDate: Date?)
    let targetDate: Date
    let unit: WeightUnit
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    private var remainingDisplay: String {
        let weight = unit == .lbs ? progress.remaining * 2.20462 : progress.remaining
        return String(format: "%.1f", weight)
    }
    
    private var daysRemaining: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: targetDate)
        return max(0, components.day ?? 0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("progress_preview".localized, systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)
            
            // Progress Bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(Int(progress.percentage))% " + "complete".localized)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("\(remainingDisplay) \(unit.rawValue) " + "to_go".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.green]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: geometry.size.width * (progress.percentage / 100), height: 8)
                    }
                }
                .frame(height: 8)
            }
            
            // Time Estimates
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("days_to_target".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(daysRemaining)")
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                
                if let estimatedDate = progress.estimatedDate {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("estimated_completion".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(estimatedDate, style: .date)
                            .font(.headline)
                            .foregroundColor(estimatedDate <= targetDate ? .green : .orange)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct MilestonesCard: View {
    let currentWeight: Double
    let goalWeight: Double
    let unit: WeightUnit
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    private var milestones: [(name: String, weight: Double, achieved: Bool)] {
        let start = max(currentWeight, goalWeight)
        let end = min(currentWeight, goalWeight)
        let totalChange = start - end
        
        let milestonePercentages = [0.25, 0.5, 0.75, 1.0]
        let milestoneNames = ["25%", "50%", "75%", "goal".localized]
        
        return zip(milestonePercentages, milestoneNames).map { percentage, name in
            let milestoneWeight = start - (totalChange * percentage)
            let achieved = currentWeight <= goalWeight ? 
                currentWeight <= milestoneWeight : 
                currentWeight >= milestoneWeight
            
            return (name: name, weight: milestoneWeight, achieved: achieved)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("milestones".localized, systemImage: "flag.checkered")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(milestones, id: \.name) { milestone in
                    HStack {
                        Image(systemName: milestone.achieved ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(milestone.achieved ? .green : .secondary)
                            .font(.title3)
                        
                        Text(milestone.name)
                            .font(.subheadline)
                            .fontWeight(milestone.achieved ? .semibold : .regular)
                        
                        Spacer()
                        
                        let displayWeight = unit == .lbs ? milestone.weight * 2.20462 : milestone.weight
                        Text("\(String(format: "%.1f", displayWeight)) \(unit.rawValue)")
                            .font(.subheadline)
                            .foregroundColor(milestone.achieved ? .primary : .secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}