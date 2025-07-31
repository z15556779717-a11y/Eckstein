//
//  MilkBankCard.swift
//  Eckstein
//
//  Created by Assistant on 16/01/2025.
//

import SwiftUI

struct MilkBankCard: View {
    @ObservedObject private var milkBankManager = MilkBankManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var showingAddMilk = false
    @State private var showingHistory = false
    @State private var milkAmount = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "drop.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("milk_bank".localized)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    showingHistory = true
                }) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        (themeManager.accentColor == .defaultMix ? 
                         themeManager.accentColor.contextColor(for: .diet) : 
                         themeManager.accentColor.color).opacity(0.8),
                        (themeManager.accentColor == .defaultMix ? 
                         themeManager.accentColor.contextColor(for: .diet) : 
                         themeManager.accentColor.color).opacity(0.6)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            
            // Content
            VStack(spacing: 20) {
                // Progress Circle
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(milkBankManager.todayConsumption / 200))
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    themeManager.accentColor == .defaultMix ? 
                                    themeManager.accentColor.contextColor(for: .diet) : 
                                    themeManager.accentColor.color,
                                    (themeManager.accentColor == .defaultMix ? 
                                     themeManager.accentColor.contextColor(for: .diet) : 
                                     themeManager.accentColor.color).opacity(0.6)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: milkBankManager.todayConsumption)
                    
                    VStack(spacing: 4) {
                        Text("\(Int(milkBankManager.availableMilk))")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("ml_left".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Stats
                HStack(spacing: 30) {
                    VStack(spacing: 4) {
                        Text("\(Int(milkBankManager.todayConsumption))")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("consumed".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 1, height: 40)
                    
                    VStack(spacing: 4) {
                        Text("200")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("daily_limit".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Add Button
                Button(action: {
                    showingAddMilk = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("add_milk".localized)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(themeManager.accentColor == .defaultMix ? 
                               themeManager.accentColor.contextColor(for: .diet) : 
                               themeManager.accentColor.color)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(milkBankManager.availableMilk <= 0)
            }
            .padding()
        }
        .background(Color(.systemGray6))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .sheet(isPresented: $showingAddMilk) {
            MilkConsumptionSheet(milkBankManager: milkBankManager)
        }
        .sheet(isPresented: $showingHistory) {
            MilkHistoryView(milkBankManager: milkBankManager)
        }
    }
}

struct MilkConsumptionSheet: View {
    @ObservedObject var milkBankManager: MilkBankManager
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var amount = ""
    @FocusState private var isAmountFocused: Bool
    
    private let presetAmounts = [50, 100, 150, 200]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("add_milk_consumption".localized)
                    .font(.headline)
                    .padding(.top)
                
                // Amount Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("amount_ml".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("0", text: $amount)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.title)
                        .multilineTextAlignment(.center)
                        .focused($isAmountFocused)
                    
                    Text("available".localized + ": \(Int(milkBankManager.availableMilk)) ml")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Preset Buttons
                HStack(spacing: 12) {
                    ForEach(presetAmounts, id: \.self) { preset in
                        Button(action: {
                            amount = "\(preset)"
                        }) {
                            Text("\(preset) ml")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background((themeManager.accentColor == .defaultMix ? 
                                           themeManager.accentColor.contextColor(for: .diet) : 
                                           themeManager.accentColor.color).opacity(0.1))
                                .foregroundColor(themeManager.accentColor == .defaultMix ? 
                                              themeManager.accentColor.contextColor(for: .diet) : 
                                              themeManager.accentColor.color)
                                .cornerRadius(8)
                        }
                        .disabled(Double(preset) > milkBankManager.availableMilk)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Add Button
                Button(action: {
                    if let amountValue = Double(amount), amountValue > 0 {
                        milkBankManager.consumeMilk(amount: amountValue)
                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
                    Text("add_consumption".localized)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isValidAmount ? (themeManager.accentColor == .defaultMix ? 
                                                   themeManager.accentColor.contextColor(for: .diet) : 
                                                   themeManager.accentColor.color) : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(!isValidAmount)
                .padding(.horizontal)
            }
            .navigationBarItems(
                leading: Button("cancel".localized) {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .onAppear {
                isAmountFocused = true
            }
        }
    }
    
    private var isValidAmount: Bool {
        guard let amountValue = Double(amount), amountValue > 0 else { return false }
        return amountValue <= milkBankManager.availableMilk
    }
}

struct MilkHistoryView: View {
    @ObservedObject var milkBankManager: MilkBankManager
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                Section("todays_consumption".localized) {
                    if milkBankManager.getTodayConsumptions().isEmpty {
                        Text("no_milk_consumed_today".localized)
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(milkBankManager.getTodayConsumptions(), id: \.id) { consumption in
                            HStack {
                                Image(systemName: "drop.fill")
                                    .foregroundColor(themeManager.accentColor == .defaultMix ? 
                                              themeManager.accentColor.contextColor(for: .diet) : 
                                              themeManager.accentColor.color)
                                
                                Text("\(Int(consumption.amount)) ml")
                                    .font(.body)
                                
                                Spacer()
                                
                                if let date = consumption.date {
                                    Text(date, style: .time)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .onDelete { indices in
                            indices.forEach { index in
                                let consumption = milkBankManager.getTodayConsumptions()[index]
                                milkBankManager.deleteConsumption(consumption)
                            }
                        }
                    }
                }
                
                Section {
                    HStack {
                        Text("total_consumed".localized)
                        Spacer()
                        Text("\(Int(milkBankManager.todayConsumption)) ml")
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("remaining".localized)
                        Spacer()
                        Text("\(Int(milkBankManager.availableMilk)) ml")
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.accentColor == .defaultMix ? 
                                          themeManager.accentColor.contextColor(for: .diet) : 
                                          themeManager.accentColor.color)
                    }
                }
            }
            .navigationTitle("milk_history".localized)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("done".localized) {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

#Preview {
    MilkBankCard()
        .padding()
}