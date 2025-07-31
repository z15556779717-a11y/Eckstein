//
//  CalorieBankHistoryView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI
import Charts

struct CalorieBankHistoryView: View {
    @StateObject private var bankManager = CalorieBankManager.shared
    @State private var selectedTimeRange = TimeRange.week
    @Environment(\.dismiss) private var dismiss
    
    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case all = "All Time"
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .all: return 365
            }
        }
    }
    
    private var filteredTransactions: [CalorieBankTransaction] {
        bankManager.getTransactionHistory(days: selectedTimeRange.days)
    }
    
    private var chartData: [(date: Date, balance: Int)] {
        var data: [(date: Date, balance: Int)] = []
        var runningBalance = 0
        
        for transaction in filteredTransactions.reversed() {
            runningBalance = transaction.balance
            data.append((date: transaction.date, balance: runningBalance))
        }
        
        return data
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Time Range Picker
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    // Balance Chart
                    if !chartData.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Balance Over Time")
                                .font(.headline)
                            
                            Chart(chartData, id: \.date) { item in
                                LineMark(
                                    x: .value("Date", item.date),
                                    y: .value("Balance", item.balance)
                                )
                                .foregroundStyle(Color.blue)
                                
                                AreaMark(
                                    x: .value("Date", item.date),
                                    y: .value("Balance", item.balance)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.1)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            }
                            .frame(height: 200)
                            .chartYScale(domain: 0...1500)
                            .chartXAxis {
                                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel(format: .dateTime.day().month())
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Transaction List
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Transaction History")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if filteredTransactions.isEmpty {
                            Text("No transactions yet")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            ForEach(filteredTransactions) { transaction in
                                TransactionRow(
                                    transaction: transaction,
                                    onDelete: {
                                        bankManager.deleteTransaction(transaction)
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Bank History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TransactionRow: View {
    let transaction: CalorieBankTransaction
    let onDelete: () -> Void
    
    private var icon: String {
        switch transaction.type {
        case .deposit:
            return "arrow.down.circle.fill"
        case .withdrawal:
            return "arrow.up.circle.fill"
        }
    }
    
    private var color: Color {
        switch transaction.type {
        case .deposit:
            return .green
        case .withdrawal:
            return .red
        }
    }
    
    private var amountText: String {
        switch transaction.type {
        case .deposit:
            return "+\(transaction.amount)"
        case .withdrawal:
            return "-\(abs(transaction.amount))"
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(transaction.foodName ?? (transaction.type == .deposit ? "Daily Deposit" : "Withdrawal"))
                        .font(.body)
                        .fontWeight(.medium)
                    
                    if transaction.type == .withdrawal && transaction.foodName != nil {
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Text(transaction.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(amountText)
                    .font(.headline)
                    .foregroundColor(color)
                
                Text("cal")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if transaction.type == .withdrawal {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                .padding(.leading, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}