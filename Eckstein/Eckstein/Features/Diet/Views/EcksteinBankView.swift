//
//  EcksteinBankView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 14/07/2025.
//

import SwiftUI

struct EcksteinBankView: View {
    @StateObject private var viewModel = EcksteinDietViewModel()
    @State private var showWithdrawSheet = false
    @State private var selectedCategory: DietRule.DietCategory = .proteinNonFat
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Bank Balance Card
                VStack(spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Eckstein Food Bank")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Save unused portions for later")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "building.columns.fill")
                            .font(.title)
                            .foregroundColor(.orange)
                    }
                    
                    // Balance Display by Category
                    VStack(spacing: 16) {
                        BankCategoryRow(
                            title: "Protein (Non-Fat)",
                            savedGrams: 160,
                            icon: "fish.fill",
                            color: .red
                        )
                        
                        BankCategoryRow(
                            title: "Protein (Fat)",
                            savedGrams: 120,
                            icon: "fish.fill",
                            color: .red
                        )
                        
                        BankCategoryRow(
                            title: "Carbs",
                            savedGrams: 125,
                            icon: "leaf.fill",
                            color: .green
                        )
                        
                        BankCategoryRow(
                            title: "Snacks",
                            savedGrams: 50,
                            icon: "cookie.fill",
                            color: .brown
                        )
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                
                // How It Works
                VStack(alignment: .leading, spacing: 12) {
                    Text("How It Works")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        BankInfoRow(
                            icon: "arrow.down.to.line",
                            title: "Auto-Save",
                            description: "Unused portions from meals are saved automatically"
                        )
                        
                        BankInfoRow(
                            icon: "repeat.circle",
                            title: "Use Anytime",
                            description: "Withdraw saved portions for any meal"
                        )
                        
                        BankInfoRow(
                            icon: "calendar",
                            title: "Weekly Reset",
                            description: "Bank resets every Sunday for a fresh start"
                        )
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                
                // Quick Actions
                HStack(spacing: 12) {
                    Button(action: { showWithdrawSheet = true }) {
                        Label("Withdraw", systemImage: "minus.circle")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .foregroundColor(.orange)
                            .cornerRadius(12)
                    }
                    
                    Button(action: { }) {
                        Label("History", systemImage: "clock.arrow.circlepath")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Food Bank")
        .sheet(isPresented: $showWithdrawSheet) {
            WithdrawGramsView(viewModel: viewModel)
        }
    }
}

struct BankCategoryRow: View {
    let title: String
    let savedGrams: Int
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(savedGrams)g saved")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(savedGrams)g")
                .font(.headline)
                .foregroundColor(color)
        }
        .padding(.vertical, 8)
    }
}

struct BankInfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.orange)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct WithdrawGramsView: View {
    @ObservedObject var viewModel: EcksteinDietViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedCategory: DietRule.DietCategory = .proteinNonFat
    @State private var selectedFood: DietRule?
    @State private var gramsToWithdraw = ""
    @State private var targetMeal = 1
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Category Selection
                Picker("Category", selection: $selectedCategory) {
                    Text("Protein (Non-Fat)").tag(DietRule.DietCategory.proteinNonFat)
                    Text("Protein (Fat)").tag(DietRule.DietCategory.proteinFat)
                    Text("Carbs").tag(DietRule.DietCategory.carbs)
                    Text("Snacks").tag(DietRule.DietCategory.snack)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Available Balance
                VStack(spacing: 8) {
                    Text("Available Balance")
                        .font(.headline)
                    Text("160g") // This would be dynamic
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Food Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select Food")
                        .font(.headline)
                    
                    // Food picker would go here
                }
                
                // Amount Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Amount to Withdraw")
                        .font(.headline)
                    
                    HStack {
                        TextField("Grams", text: $gramsToWithdraw)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 100)
                        
                        Text("grams")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Target Meal
                Picker("Add to", selection: $targetMeal) {
                    Text("meal_1".localized).tag(1)
                    Text("meal_2".localized).tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                
                Spacer()
                
                Button(action: withdraw) {
                    Text("Withdraw")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(12)
                }
            }
            .padding()
            .navigationTitle("Withdraw from Bank")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func withdraw() {
        // Implement withdrawal logic
        dismiss()
    }
}