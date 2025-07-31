//
//  CurrentWeightCard.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

struct CurrentWeightCard: View {
    let weight: CDWeightEntry
    let unit: String
    let change: Double?
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            Text("current_weight".localized)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(alignment: .bottom, spacing: 4) {
                Text(String(format: "%.1f", weight.weightKg))
                    .font(.system(size: 48, weight: .bold))
                
                Text(unit)
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
            }
            
            if let change = change {
                HStack {
                    Image(systemName: change > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .foregroundColor(change > 0 ? .red : .green)
                    
                    Text(String(format: "%.1f %@ " + "this_week".localized, abs(change), unit))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            if let date = weight.date {
                Text("\("last_updated".localized): \(date, formatter: DateFormatter.shortDate)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}