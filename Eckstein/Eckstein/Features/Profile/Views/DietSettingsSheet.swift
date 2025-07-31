//
//  DietSettingsSheet.swift
//  Eckstein
//
//  Created by Assistant on 16/01/2025.
//

import SwiftUI

struct DietSettingsSheet: View {
    @Binding var isPresented: Bool
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var weightRepository = WeightRepository.shared
    
    @State private var selectedDate: Date = Date()
    @State private var startingWeight: String = ""
    @State private var showingDatePicker = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("diet_start_information".localized) {
                    // Date Picker
                    HStack {
                        Label("start_date".localized, systemImage: "calendar")
                            .themedForegroundColor(themeManager.accentColor, context: .general)
                        
                        Spacer()
                        
                        Button(action: {
                            showingDatePicker.toggle()
                        }) {
                            Text(selectedDate, formatter: dateFormatter)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    if showingDatePicker {
                        DatePicker(
                            "Select Date",
                            selection: $selectedDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(GraphicalDatePickerStyle())
                        .themedAccentColor(themeManager.accentColor)
                    }
                    
                    // Weight Input
                    HStack {
                        Label("starting_weight".localized, systemImage: "scalemass")
                            .themedForegroundColor(themeManager.accentColor, context: .general)
                        
                        Spacer()
                        
                        TextField("0.0", text: $startingWeight)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        
                        Text("kg")
                            .foregroundColor(.secondary)
                    }
                }
                
                if themeManager.dietStartDate != nil {
                    Section("current_progress".localized) {
                        HStack {
                            Text("days_on_diet".localized)
                            Spacer()
                            Text("\(themeManager.daysOnDiet)")
                                .fontWeight(.semibold)
                        }
                        
                        if let currentWeight = weightRepository.latestEntry?.weightKg,
                           themeManager.startingWeight > 0 {
                            HStack {
                                Text("weight_change".localized)
                                Spacer()
                                let difference = currentWeight - themeManager.startingWeight
                                Text("\(difference > 0 ? "+" : "")\(difference, specifier: "%.1f") kg")
                                    .fontWeight(.semibold)
                                    .foregroundColor(difference < 0 ? .green : difference > 0 ? .red : .secondary)
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        resetDietInfo()
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("reset_diet_info".localized)
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("diet_settings".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save".localized) {
                        saveDietInfo()
                    }
                    .disabled(startingWeight.isEmpty)
                }
            }
            .onAppear {
                loadCurrentValues()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    // MARK: - Methods
    
    private func loadCurrentValues() {
        if let dietStartDate = themeManager.dietStartDate {
            selectedDate = dietStartDate
        }
        
        if themeManager.startingWeight > 0 {
            startingWeight = String(format: "%.1f", themeManager.startingWeight)
        }
    }
    
    private func saveDietInfo() {
        guard let weight = Double(startingWeight) else { return }
        
        themeManager.setDietStartInfo(date: selectedDate, weight: weight)
        isPresented = false
    }
    
    private func resetDietInfo() {
        themeManager.resetDietInfo()
        startingWeight = ""
        selectedDate = Date()
        isPresented = false
    }
}

#Preview {
    DietSettingsSheet(isPresented: .constant(true))
}