//
//  GoalSettingsView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

struct GoalSettingsView: View {
    @ObservedObject var viewModel: DietViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var weight: String = ""
    @State private var height: String = ""
    @State private var age: String = ""
    @State private var gender: Gender = .male
    @State private var activityLevel: ActivityLevel = .moderatelyActive
    @State private var nutritionGoal: NutritionGoal = .maintain
    
    @State private var customCalories: String = ""
    @State private var customProtein: String = ""
    @State private var customCarbs: String = ""
    @State private var customFat: String = ""
    
    @State private var useCustomGoals = false
    @State private var showCalculation = false
    
    private var calculatedTargets: MacroTargets? {
        guard let weightValue = Double(weight),
              let heightValue = Double(height),
              let ageValue = Int(age),
              weightValue > 0,
              heightValue > 0,
              ageValue > 0 else { return nil }
        
        let dailyCalories = NutritionCalculator.calculateDailyCalorieNeeds(
            weight: weightValue,
            height: heightValue,
            age: ageValue,
            gender: gender,
            activityLevel: activityLevel
        )
        
        return NutritionCalculator.calculateMacroTargets(
            dailyCalories: dailyCalories,
            goal: nutritionGoal
        )
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    personalInfoSection
                    activityLevelSection
                    nutritionGoalSection
                    calculateButtonSection
                    targetsSection
                    saveButtonSection
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Goal Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadCurrentGoals()
        }
    }
    
    @ViewBuilder
    private var personalInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Personal Information")
                .font(.headline)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Weight (kg)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("70", text: $weight)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading) {
                    Text("Height (cm)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("175", text: $height)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading) {
                    Text("Age")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("25", text: $age)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            
            // Gender Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Gender")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Gender", selection: $gender) {
                    Text("Male").tag(Gender.male)
                    Text("Female").tag(Gender.female)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var activityLevelSection: some View {
        VStack(alignment: .leading, spacing: 16) {
                        Text("Activity Level")
                            .font(.headline)
                        
                        ForEach([
                            (ActivityLevel.sedentary, "Sedentary", "Little to no exercise"),
                            (ActivityLevel.lightlyActive, "Lightly Active", "Exercise 1-3 days/week"),
                            (ActivityLevel.moderatelyActive, "Moderately Active", "Exercise 3-5 days/week"),
                            (ActivityLevel.veryActive, "Very Active", "Exercise 6-7 days/week"),
                            (ActivityLevel.extraActive, "Extra Active", "Intense exercise daily")
                        ], id: \.0) { level, title, description in
                            ActivityLevelRow(
                                level: level,
                                title: title,
                                description: description,
                                isSelected: activityLevel == level,
                                onTap: { activityLevel = level }
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
    }
    
    @ViewBuilder
    private var nutritionGoalSection: some View {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Nutrition Goal")
                            .font(.headline)
                        
                        ForEach([
                            (NutritionGoal.loseFat, "Lose Fat", "Higher protein, moderate carbs & fat"),
                            (NutritionGoal.buildMuscle, "Build Muscle", "Higher carbs, adequate protein"),
                            (NutritionGoal.maintain, "Maintain", "Balanced macro distribution")
                        ], id: \.1) { goal, title, description in
                            GoalRow(
                                title: title,
                                description: description,
                                isSelected: {
                                    switch (nutritionGoal, goal) {
                                    case (.loseFat, .loseFat),
                                         (.buildMuscle, .buildMuscle),
                                         (.maintain, .maintain):
                                        return true
                                    default:
                                        return false
                                    }
                                }(),
                                onTap: { nutritionGoal = goal }
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
    }
    
    @ViewBuilder 
    private var calculateButtonSection: some View {
                    if !useCustomGoals {
                        Button(action: { showCalculation = true }) {
                            Label("Calculate Targets", systemImage: "function")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(calculatedTargets != nil ? Color.blue : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .disabled(calculatedTargets == nil)
                    }
    }
    
    @ViewBuilder
    private var targetsSection: some View {
                    if showCalculation || useCustomGoals {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text(useCustomGoals ? "Custom Targets" : "Calculated Targets")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Toggle("Custom", isOn: $useCustomGoals)
                                    .labelsHidden()
                            }
                            
                            if useCustomGoals {
                                // Custom input fields
                                VStack(spacing: 12) {
                                    CustomTargetField(
                                        title: "Calories",
                                        value: $customCalories,
                                        unit: "cal",
                                        color: .orange
                                    )
                                    
                                    CustomTargetField(
                                        title: "Protein",
                                        value: $customProtein,
                                        unit: "g",
                                        color: .red
                                    )
                                    
                                    CustomTargetField(
                                        title: "Carbs",
                                        value: $customCarbs,
                                        unit: "g",
                                        color: .blue
                                    )
                                    
                                    CustomTargetField(
                                        title: "Fat",
                                        value: $customFat,
                                        unit: "g",
                                        color: .green
                                    )
                                }
                            } else if let targets = calculatedTargets {
                                // Display calculated targets
                                VStack(spacing: 12) {
                                    TargetDisplay(
                                        title: "Daily Calories",
                                        value: targets.calories,
                                        unit: "cal",
                                        color: .orange
                                    )
                                    
                                    TargetDisplay(
                                        title: "Protein",
                                        value: targets.protein,
                                        unit: "g",
                                        color: .red
                                    )
                                    
                                    TargetDisplay(
                                        title: "Carbohydrates",
                                        value: targets.carbs,
                                        unit: "g",
                                        color: .blue
                                    )
                                    
                                    TargetDisplay(
                                        title: "Fat",
                                        value: targets.fat,
                                        unit: "g",
                                        color: .green
                                    )
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
    }
    
    @ViewBuilder
    private var saveButtonSection: some View {
                    Button(action: saveGoals) {
                        Text("Save Goals")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canSave ? Color.green : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(!canSave)
    }
    
    private var canSave: Bool {
        if useCustomGoals {
            return Int(customCalories) != nil &&
                   Int(customProtein) != nil &&
                   Int(customCarbs) != nil &&
                   Int(customFat) != nil
        } else {
            return calculatedTargets != nil && showCalculation
        }
    }
    
    private func loadCurrentGoals() {
        customCalories = String(viewModel.dailyCalorieGoal)
        customProtein = String(viewModel.dailyProteinGoal)
        customCarbs = String(viewModel.dailyCarbsGoal)
        customFat = String(viewModel.dailyFatGoal)
    }
    
    private func saveGoals() {
        if useCustomGoals {
            viewModel.updateDailyGoals(
                calories: Int(customCalories) ?? 2000,
                protein: Int(customProtein) ?? 150,
                carbs: Int(customCarbs) ?? 200,
                fat: Int(customFat) ?? 65
            )
        } else if let targets = calculatedTargets {
            viewModel.updateDailyGoals(
                calories: targets.calories,
                protein: targets.protein,
                carbs: targets.carbs,
                fat: targets.fat
            )
        }
        
        dismiss()
    }
}

struct ActivityLevelRow: View {
    let level: ActivityLevel
    let title: String
    let description: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct GoalRow: View {
    let title: String
    let description: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TargetDisplay: View {
    let title: String
    let value: Int
    let unit: String
    let color: Color
    
    var body: some View {
        HStack {
            Label(title, systemImage: "target")
                .font(.subheadline)
                .foregroundColor(color)
            
            Spacer()
            
            Text("\(value) \(unit)")
                .font(.headline)
                .foregroundColor(color)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct CustomTargetField: View {
    let title: String
    @Binding var value: String
    let unit: String
    let color: Color
    
    var body: some View {
        HStack {
            Label(title, systemImage: "target")
                .font(.subheadline)
                .foregroundColor(color)
            
            Spacer()
            
            HStack {
                TextField("0", text: $value)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// Add to DietViewModel
extension DietViewModel {
    func updateDailyGoals(calories: Int, protein: Int, carbs: Int, fat: Int) {
        // Save to UserDefaults or Core Data
        UserDefaults.standard.set(calories, forKey: "dailyCalorieGoal")
        UserDefaults.standard.set(protein, forKey: "dailyProteinGoal")
        UserDefaults.standard.set(carbs, forKey: "dailyCarbsGoal")
        UserDefaults.standard.set(fat, forKey: "dailyFatGoal")
        
        // Update local properties
        dailyCalorieGoal = calories
        dailyProteinGoal = protein
        dailyCarbsGoal = carbs
        dailyFatGoal = fat
    }
}