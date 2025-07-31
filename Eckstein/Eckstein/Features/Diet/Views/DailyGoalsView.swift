//
//  DailyGoalsView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

struct DailyGoalsView: View {
    @ObservedObject var viewModel: DietViewModel
    @State private var showGoalSettings = false
    
    private var calorieProgress: Double {
        guard viewModel.dailyCalorieGoal > 0 else { return 0 }
        return min(Double(viewModel.todayCalories) / Double(viewModel.dailyCalorieGoal), 1.0)
    }
    
    private var proteinProgress: Double {
        guard viewModel.dailyProteinGoal > 0 else { return 0 }
        return min(viewModel.todayProtein / Double(viewModel.dailyProteinGoal), 1.0)
    }
    
    private var carbsProgress: Double {
        guard viewModel.dailyCarbsGoal > 0 else { return 0 }
        return min(viewModel.todayCarbs / Double(viewModel.dailyCarbsGoal), 1.0)
    }
    
    private var fatProgress: Double {
        guard viewModel.dailyFatGoal > 0 else { return 0 }
        return min(viewModel.todayFat / Double(viewModel.dailyFatGoal), 1.0)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Goals")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Track your nutrition targets")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { showGoalSettings = true }) {
                    Image(systemName: "gear")
                        .font(.title3)
                }
            }
            .padding()
            
            // Calorie Goal
            GoalProgressCard(
                title: "Calories",
                current: viewModel.todayCalories,
                goal: viewModel.dailyCalorieGoal,
                unit: "cal",
                progress: calorieProgress,
                color: .orange,
                icon: "flame.fill"
            )
            
            // Macro Goals
            HStack(spacing: 12) {
                MacroGoalCard(
                    title: "Protein",
                    current: viewModel.todayProtein,
                    goal: Double(viewModel.dailyProteinGoal),
                    unit: "g",
                    progress: proteinProgress,
                    color: .red
                )
                
                MacroGoalCard(
                    title: "Carbs",
                    current: viewModel.todayCarbs,
                    goal: Double(viewModel.dailyCarbsGoal),
                    unit: "g",
                    progress: carbsProgress,
                    color: .blue
                )
                
                MacroGoalCard(
                    title: "Fat",
                    current: viewModel.todayFat,
                    goal: Double(viewModel.dailyFatGoal),
                    unit: "g",
                    progress: fatProgress,
                    color: .green
                )
            }
            
            // Calorie Bank Integration
            if viewModel.todayCalories < viewModel.dailyCalorieGoal {
                let unusedCalories = viewModel.dailyCalorieGoal - viewModel.todayCalories
                VStack(spacing: 8) {
                    Text("Unused Calories Today")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(unusedCalories)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text("Will be deposited to your calorie bank")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            }
            
            Spacer()
        }
        .sheet(isPresented: $showGoalSettings) {
            GoalSettingsView(viewModel: viewModel)
        }
    }
}

struct GoalProgressCard: View {
    let title: String
    let current: Int
    let goal: Int
    let unit: String
    let progress: Double
    let color: Color
    let icon: String
    
    private var remaining: Int {
        max(0, goal - current)
    }
    
    private var isOverGoal: Bool {
        current > goal
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.headline)
                    .foregroundColor(color)
                
                Spacer()
                
                Text("\(current) / \(goal) \(unit)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 20)
                        .cornerRadius(10)
                    
                    Rectangle()
                        .fill(isOverGoal ? Color.red : color)
                        .frame(width: geometry.size.width * (isOverGoal ? 1.0 : progress), height: 20)
                        .cornerRadius(10)
                        .animation(.easeInOut, value: progress)
                }
            }
            .frame(height: 20)
            
            HStack {
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(color)
                
                Spacer()
                
                if isOverGoal {
                    Text("\(current - goal) \(unit) over")
                        .font(.caption)
                        .foregroundColor(.red)
                } else {
                    Text("\(remaining) \(unit) remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct MacroGoalCard: View {
    let title: String
    let current: Double
    let goal: Double
    let unit: String
    let progress: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 8)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progress)
                
                VStack(spacing: 2) {
                    Text("\(Int(current))")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("\(Int(goal)) \(unit)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}