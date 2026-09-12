//
//  CalorieBankView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI
import Charts

struct CalorieBankView: View {
    @StateObject private var bankManager = CalorieBankManager.shared
    @State private var showHistory = false
    @State private var showWithdrawSheet = false
    @State private var withdrawAmount = ""
    @State private var showResetSheet = false
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private var balancePercentage: Double {
        Double(bankManager.currentBalance) / 1500.0 // Max saved balance
    }
    
    private var balanceColor: Color {
        if balancePercentage > 0.8 {
            return themeManager.accentColor.color
        } else if balancePercentage > 0.4 {
            return themeManager.accentColor.color.opacity(0.7)
        } else {
            return themeManager.accentColor == .red ? .red : themeManager.accentColor.color.opacity(0.5)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Bank Balance Card
                VStack(spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("calorie_bank".localized)
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("calorie_bank_subtitle".localized)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "building.columns.fill")
                            .font(.title)
                            .foregroundColor(themeManager.accentColor.color)
                    }
                    
                    // Balance Display
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .stroke(Color(.systemGray5), lineWidth: 20)
                                .frame(width: 200, height: 200)
                            
                            Circle()
                                .trim(from: 0, to: balancePercentage)
                                .stroke(balanceColor, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                                .frame(width: 200, height: 200)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut, value: balancePercentage)
                            
                            VStack(spacing: 8) {
                                Text("\(bankManager.currentBalance)")
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundColor(balanceColor)
                                
                                Text("saved_balance".localized)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Divider()
                                    .frame(width: 100)
                                
                                VStack(spacing: 4) {
                                    Text("calorie_bank_available_today".localized)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("\(bankManager.currentBalance + bankManager.todayAvailable)")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(themeManager.accentColor.color)
                                }
                            }
                        }
                        
                        // Today's Activity
                        HStack(spacing: 40) {
                            VStack {
                                HStack {
                                    Image(systemName: "sun.max.fill")
                                        .foregroundColor(themeManager.accentColor.color)
                                    Text("\(bankManager.todayAvailable)")
                                        .font(.headline)
                                        .foregroundColor(themeManager.accentColor.color)
                                }
                                Text("calorie_bank_todays".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack {
                                HStack {
                                    Image(systemName: "fork.knife")
                                        .foregroundColor(.red)
                                    Text("\(bankManager.todayUsed)")
                                        .font(.headline)
                                        .foregroundColor(.red)
                                }
                                Text("used".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                
                // Quick Actions
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Button(action: { showWithdrawSheet = true }) {
                            Label("calorie_bank_withdraw".localized, systemImage: "minus.circle")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                                .cornerRadius(12)
                        }
                        .disabled(bankManager.currentBalance + bankManager.todayAvailable == 0)
                        
                        Button(action: { showHistory = true }) {
                            Label("history".localized, systemImage: "clock")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(themeManager.accentColor.color.opacity(0.1))
                                .foregroundColor(themeManager.accentColor.color)
                                .cornerRadius(12)
                        }
                    }
                    
                    Button(action: { showResetSheet = true }) {
                        Label("calorie_bank_reset_start_date".localized, systemImage: "calendar.badge.clock")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .foregroundColor(.orange)
                            .cornerRadius(12)
                    }
                }
                
                // Today's Transactions
                if !bankManager.getTodayTransactions().isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("calorie_bank_todays_activity".localized)
                            .font(.headline)
                        
                        ForEach(bankManager.getTodayTransactions()) { transaction in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(transaction.foodName ?? "manual_entry".localized)
                                        .font(.subheadline)
                                    Text("\(transaction.amount) calories")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text("-\(transaction.amount)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                                
                                Button(action: {
                                    bankManager.deleteTransaction(transaction)
                                }) {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }
                
                // How It Works
                VStack(alignment: .leading, spacing: 12) {
                    Text("calorie_bank_how_it_works".localized)
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HowItWorksRow(
                            icon: "calendar.badge.plus",
                            title: "Daily Deposit",
                            description: "Get 150 free calories deposited daily"
                        )
                        
                        HowItWorksRow(
                            icon: "arrow.down.to.line",
                            title: "Save Unused Calories",
                            description: "Calories under your daily goal are saved"
                        )
                        
                        HowItWorksRow(
                            icon: "banknote",
                            title: "Maximum Balance",
                            description: "Bank up to 1,500 calories (10 days worth)"
                        )
                        
                        HowItWorksRow(
                            icon: "fork.knife",
                            title: "Use When Needed",
                            description: "Withdraw for special meals or occasions"
                        )
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                
                // Weekly Stats
                let stats = bankManager.getWeeklyStats()
                VStack(alignment: .leading, spacing: 12) {
                    Text("this_week".localized)
                        .font(.headline)
                    
                    HStack(spacing: 20) {
                        CalorieBankStatItem(
                            title: "Deposited",
                            value: "\(stats.totalDeposits)",
                            color: .green
                        )
                        
                        CalorieBankStatItem(
                            title: "Withdrawn",
                            value: "\(stats.totalWithdrawals)",
                            color: .red
                        )
                        
                        CalorieBankStatItem(
                            title: "Net Change",
                            value: "\(stats.netChange > 0 ? "+" : "")\(stats.netChange)",
                            color: stats.netChange > 0 ? .green : .red
                        )
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
            }
            .padding()
        }
        .navigationTitle("calorie_bank".localized)
        .sheet(isPresented: $showHistory) {
            CalorieBankHistoryView()
        }
        .sheet(isPresented: $showWithdrawSheet) {
            ManualCalorieEntryView(
                bankManager: bankManager,
                isPresented: $showWithdrawSheet
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

struct HowItWorksRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
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

struct CalorieBankStatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CalorieBankResetView: View {
    @ObservedObject var bankManager: CalorieBankManager
    @Binding var isPresented: Bool
    @State private var selectedDate = Date()
    @State private var showConfirmation = false
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private let dateRange: ClosedRange<Date> = {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .month, value: -3, to: endDate) ?? endDate
        return startDate...endDate
    }()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Text("calorie_bank_reset_title".localized)
                        .font(.headline)
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Date Picker - Compact
                DatePicker(
                    "Choose start date",
                    selection: $selectedDate,
                    in: dateRange,
                    displayedComponents: .date
                )
                .datePickerStyle(GraphicalDatePickerStyle())
                .padding(.horizontal, 8)
                .frame(maxHeight: 300)
                
                // Preview Card
                VStack(spacing: 8) {
                    let calendar = Calendar.current
                    let startOfSelectedDate = calendar.startOfDay(for: selectedDate)
                    let startOfToday = calendar.startOfDay(for: Date())
                    let daysSince = calendar.dateComponents([.day], from: startOfSelectedDate, to: startOfToday).day ?? 0
                    
                    // Calculate saved balance (excluding today)
                    let savedBalance = min(daysSince * 150, 1500)
                    let todayAllowance = 150
                    let totalAvailable = savedBalance + todayAllowance
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("calorie_bank_days_accumulated".localized)
                            Text("calorie_bank_saved_balance".localized)
                            Text("calorie_bank_todays_allowance".localized)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(daysSince)")
                            Text("\(savedBalance) cal")
                            Text("\(todayAllowance) cal")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                    }
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    HStack {
                        Text("calorie_bank_total_available".localized)
                            .font(.caption)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(totalAvailable) cal")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.accentColor.color)
                    }
                    
                    if calendar.isDateInToday(selectedDate) {
                        Text("calorie_bank_starting_fresh".localized)
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .padding(.top, 4)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
                
                // Reset Button
                Button(action: { showConfirmation = true }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("calorie_bank_reset_from_date".localized)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(themeManager.accentColor.color)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        isPresented = false
                    }
                }
            }
            .alert("calorie_bank_confirm_reset".localized, isPresented: $showConfirmation) {
                Button("cancel".localized, role: .cancel) { }
                Button("reset".localized, role: .destructive) {
                    bankManager.resetFromDate(selectedDate)
                    isPresented = false
                }
            } message: {
                Text("calorie_bank_reset_message".localized(selectedDate.formatted(date: .abbreviated, time: .omitted)))
            }
        }
    }
}

