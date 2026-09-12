//
//  CalorieBankCard.swift
//  Eckstein
//
//  Created by Assistant on 14/07/2025.
//

import SwiftUI

struct CalorieBankCard: View {
    @ObservedObject var bankManager: CalorieBankManager
    let selectedMeal: Int
    
    @State private var showingManualEntry = false
    @State private var manualCalories = ""
    @State private var isDeposit = true
    @State private var showResetSheet = false
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "building.columns.fill")
                    .font(.title2)
                    .foregroundColor(themeManager.accentColor.color)
                
                Text("calorie_bank".localized)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .tooltip(
                        "save_unused_calories_tooltip".localized,
                        tipId: TipManager.TipID.calorieBank,
                        position: .below
                    )
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(bankManager.todayAvailable + bankManager.currentBalance)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("calories".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Action buttons
                HStack(spacing: 8) {
                    Button(action: { showResetSheet = true }) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.title3)
                            .foregroundColor(.orange)
                    }
                    
                    Button(action: { showingManualEntry = true }) {
                        Image(systemName: "minus.circle")
                            .font(.title3)
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Daily allowance info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("todays_calories".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "sun.max.fill")
                            .font(.caption2)
                            .foregroundColor(themeManager.accentColor.color)
                        Text("\(bankManager.todayAvailable)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(themeManager.accentColor.color)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 4) {
                    Text("used_today".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(bankManager.todayUsed)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(bankManager.todayUsed > 0 ? .red : .secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("saved_balance".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "building.columns")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text("\(bankManager.currentBalance)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                }
            }
            
            Divider()
            
            // Info text
            VStack(alignment: .leading, spacing: 4) {
                Text("daily_allowance_calories".localized)
                    .font(.caption)
                    .foregroundColor(themeManager.accentColor.color)
                
                Text("maximum_balance_calories".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Balance indicator
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.orange, Color.orange.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: geometry.size.width * min(Double(bankManager.currentBalance) / 1500.0, 1.0), height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
            .padding(.top, 8)
            
            // Today's Transactions
            if !bankManager.getTodayTransactions().isEmpty {
                Divider()
                    .padding(.top, 8)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("todays_usage".localized)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    ForEach(bankManager.getTodayTransactions()) { transaction in
                        HStack {
                            Text(transaction.foodName ?? "manual_entry".localized)
                                .font(.caption)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text("calorie_bank_card_transaction_amount".localized(transaction.amount))
                                .font(.caption)
                                .foregroundColor(.red)
                            
                            Button(action: {
                                bankManager.deleteTransaction(transaction)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .sheet(isPresented: $showingManualEntry) {
            ManualCalorieEntryView(
                bankManager: bankManager,
                isPresented: $showingManualEntry
            )
        }
        .sheet(isPresented: $showResetSheet) {
            CalorieBankResetView(
                bankManager: bankManager,
                isPresented: $showResetSheet
            )
        }
    }
}

struct ManualCalorieEntryView: View {
    @ObservedObject var bankManager: CalorieBankManager
    @Binding var isPresented: Bool
    
    @State private var foodName = ""
    @State private var calories = ""
    @State private var showError = false
    @State private var showingManageItems = false
    @StateObject private var commonItemsManager = CommonCalorieItemsManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("log_calorie_consumption".localized)
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // Current Balance
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("today".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(bankManager.todayAvailable)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.accentColor.color)
                    }
                    
                    Divider()
                        .frame(height: 40)
                    
                    VStack(spacing: 4) {
                        Text("saved".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(bankManager.currentBalance)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                    
                    Divider()
                        .frame(height: 40)
                    
                    VStack(spacing: 4) {
                        Text("total".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(bankManager.todayAvailable + bankManager.currentBalance)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Food and Calorie Input
                VStack(alignment: .leading, spacing: 12) {
                    Text("food_item".localized)
                        .font(.headline)
                    
                    TextField("food_item_placeholder".localized, text: $foodName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Text("calories".localized)
                        .font(.headline)
                    
                    HStack {
                        TextField("enter_calories".localized, text: $calories)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                        
                        Text("cal")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                // Quick options
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("common_items".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: { showingManageItems = true }) {
                            Image(systemName: "gear")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(commonItemsManager.items) { item in
                                QuickFoodButton(
                                    name: item.name,
                                    calories: item.calories,
                                    foodName: $foodName,
                                    caloriesText: $calories
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action Button
                Button(action: performTransaction) {
                    HStack {
                        Image(systemName: "fork.knife")
                        Text("log_consumption".localized)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .disabled(calories.isEmpty || foodName.isEmpty)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        isPresented = false
                    }
                }
            }
            .alert("invalid_amount".localized, isPresented: $showError) {
                Button("ok".localized) { }
            } message: {
                Text("insufficient_balance_calories".localized(bankManager.todayAvailable + bankManager.currentBalance))
            }
            .sheet(isPresented: $showingManageItems) {
                ManageCommonItemsView()
            }
        }
    }
    
    private func performTransaction() {
        guard let amount = Int(calories), amount > 0 else {
            showError = true
            return
        }
        
        let totalAvailable = bankManager.todayAvailable + bankManager.currentBalance
        if amount <= totalAvailable {
            let success = bankManager.logCalorieConsumption(foodName: foodName, calories: amount)
            if success {
                isPresented = false
            } else {
                showError = true
            }
        } else {
            showError = true
        }
    }
}

struct QuickFoodButton: View {
    let name: String
    let calories: Int
    @Binding var foodName: String
    @Binding var caloriesText: String
    
    var body: some View {
        Button(action: {
            foodName = name
            caloriesText = "\(calories)"
        }) {
            VStack(spacing: 4) {
                Text(name)
                    .font(.caption)
                    .fontWeight(.medium)
                Text("\(calories) cal")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.1))
            .foregroundColor(.orange)
            .cornerRadius(8)
        }
    }
}