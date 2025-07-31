//
//  AddWeightView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

struct AddWeightView: View {
    @ObservedObject var viewModel: WeightViewModel
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @State private var weight: String = ""
    @State private var date = Date()
    
    var body: some View {
        NavigationView {
            Form {
                Section("weight_entry".localized) {
                    HStack {
                        TextField("weight".localized, text: $weight)
                            .keyboardType(.decimalPad)
                        
                        Text(UserDefaults.standard.string(forKey: "weightUnit") ?? "kg")
                            .foregroundColor(.secondary)
                    }
                    
                    DatePicker("date".localized, selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle("add_weight".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save".localized) {
                        if let weightValue = Double(weight) {
                            viewModel.createEntry(weight: weightValue, date: date)
                            dismiss()
                        }
                    }
                    .disabled(weight.isEmpty)
                }
            }
        }
    }
}