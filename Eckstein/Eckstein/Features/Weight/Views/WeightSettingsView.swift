//
//  WeightSettingsView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

struct WeightSettingsView: View {
    @AppStorage("weightUnit") private var weightUnit: String = "kg"
    @AppStorage("userHeightCm") private var userHeightCm: Double = 170
    @AppStorage("enableWeightReminders") private var enableReminders = false
    @AppStorage("reminderTime") private var reminderTime = Date()
    @AppStorage("reminderFrequency") private var reminderFrequency = "daily"
    @AppStorage("autoSyncHealthKit") private var autoSyncHealthKit = false
    @AppStorage("showBodyComposition") private var showBodyComposition = true
    @AppStorage("weightPrivacyMode") private var privacyMode = false
    
    @State private var showingDeleteConfirmation = false
    @State private var showingExportOptions = false
    @State private var showingImportPicker = false
    @State private var heightString = ""
    
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @ObservedObject private var notificationService = NotificationService.shared
    
    private let heightFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            Form {
                // Units & Measurements
                Section {
                    Picker("weight_unit".localized, selection: $weightUnit) {
                        Text("kilograms_kg".localized).tag("kg")
                        Text("pounds_lbs".localized).tag("lbs")
                    }
                    
                    HStack {
                        Label("height".localized, systemImage: "ruler")
                        
                        Spacer()
                        
                        TextField("height".localized, text: $heightString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .onChange(of: heightString) { newValue in
                                if let height = Double(newValue.replacingOccurrences(of: ",", with: ".")) {
                                    userHeightCm = height
                                }
                            }
                        
                        Text("cm".localized)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("units_measurements".localized)
                } footer: {
                    Text("height_description".localized)
                }
                
                // Reminders
                Section {
                    Toggle("daily_reminders".localized, isOn: $enableReminders)
                        .onChange(of: enableReminders) { newValue in
                            if newValue {
                                Task {
                                    await scheduleReminders()
                                }
                            } else {
                                Task {
                                    await notificationService.cancelWeightReminders()
                                }
                            }
                        }
                    
                    if enableReminders {
                        DatePicker(
                            "reminder_time".localized,
                            selection: $reminderTime,
                            displayedComponents: .hourAndMinute
                        )
                        .onChange(of: reminderTime) { _ in
                            if enableReminders {
                                Task {
                                    await scheduleReminders()
                                }
                            }
                        }
                        
                        Picker("frequency".localized, selection: $reminderFrequency) {
                            Text("daily".localized).tag("daily")
                            Text("every_3_days".localized).tag("3days")
                            Text("weekly".localized).tag("weekly")
                        }
                        .onChange(of: reminderFrequency) { _ in
                            if enableReminders {
                                Task {
                                    await scheduleReminders()
                                }
                            }
                        }
                        
                        Button(action: {
                            Task {
                                await notificationService.sendTestNotification()
                            }
                        }) {
                            Label("send_test_notification".localized, systemImage: "bell.badge")
                                .foregroundColor(.blue)
                        }
                    }
                } header: {
                    Text("reminders".localized)
                } footer: {
                    Text("reminders_description".localized)
                }
                
                // Privacy & Display
                Section {
                    Toggle("privacy_mode".localized, isOn: $privacyMode)
                    Toggle("show_body_composition".localized, isOn: $showBodyComposition)
                } header: {
                    Text("privacy_display".localized)
                } footer: {
                    Text("privacy_mode_description".localized)
                }
                
                // Health Integration
                Section {
                    Toggle("auto_sync_healthkit".localized, isOn: $autoSyncHealthKit)
                        .onChange(of: autoSyncHealthKit) { newValue in
                            if newValue {
                                requestHealthKitPermission()
                            }
                        }
                    
                    Button(action: syncHealthKitData) {
                        Label("sync_now".localized, systemImage: "arrow.triangle.2.circlepath")
                    }
                } header: {
                    Text("health_integration".localized)
                }
                
                // Data Management
                Section {
                    Button(action: { showingExportOptions = true }) {
                        Label("export_data".localized, systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: { showingImportPicker = true }) {
                        Label("import_data".localized, systemImage: "square.and.arrow.down")
                    }
                    
                    Button(action: { showingDeleteConfirmation = true }) {
                        Label("delete_all_data".localized, systemImage: "trash")
                            .foregroundColor(.red)
                    }
                } header: {
                    Text("data_management".localized)
                }
                
                // About
                Section {
                    HStack {
                        Text("version".localized)
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://example.com/weight-tracking-help")!) {
                        HStack {
                            Label("help_support".localized, systemImage: "questionmark.circle")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("about".localized)
                }
            }
            .navigationTitle("weight_settings".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                }
            }
            .alert("delete_all_weight_data".localized, isPresented: $showingDeleteConfirmation) {
                Button("cancel".localized, role: .cancel) { }
                Button("delete".localized, role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text("delete_all_data_message".localized)
            }
            .sheet(isPresented: $showingExportOptions) {
                ExportOptionsView()
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
        }
        .onAppear {
            heightString = String(format: "%.0f", userHeightCm)
            if enableReminders {
                Task {
                    await scheduleReminders()
                }
            }
        }
    }
    
    private func requestHealthKitPermission() {
        Task {
            let authorized = await HealthKitService.shared.requestAuthorization()
            if !authorized {
                autoSyncHealthKit = false
            }
        }
    }
    
    private func syncHealthKitData() {
        print("Sync button tapped")
        Task {
            print("Starting HealthKit sync...")
            await HealthKitService.shared.syncWithHealthKit(
                repository: ServiceContainer.shared.weightRepository
            )
            print("HealthKit sync completed")
        }
    }
    
    private func deleteAllData() {
        let repository = ServiceContainer.shared.weightRepository
        repository.deleteAllData()
        
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "goalWeight")
        UserDefaults.standard.removeObject(forKey: "goalDate")
        UserDefaults.standard.removeObject(forKey: "startWeight")
    }
    
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importCSVData(from: url)
        case .failure(let error):
            print("Import error: \(error)")
        }
    }
    
    private func importCSVData(from url: URL) {
        // Import CSV data
        // This would parse the CSV and create weight entries
        // Placeholder for actual implementation
    }
    
    private func scheduleReminders() async {
        // Request authorization if needed
        guard await notificationService.requestAuthorization() else {
            // If authorization denied, disable reminders
            await MainActor.run {
                enableReminders = false
            }
            return
        }
        
        // Schedule the reminder
        await notificationService.scheduleWeightReminder(at: reminderTime, frequency: reminderFrequency)
    }
}

struct ExportOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var selectedFormat = "csv"
    @State private var selectedDateRange = "all"
    @State private var includeBodyComposition = true
    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("export_format".localized, selection: $selectedFormat) {
                        Text("CSV").tag("csv")
                        Text("JSON").tag("json")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                } header: {
                    Text("export_format".localized)
                }
                
                Section {
                    Picker("date_range".localized, selection: $selectedDateRange) {
                        Text("all_time_option".localized).tag("all")
                        Text("last_month".localized).tag("month")
                        Text("last_3_months".localized).tag("3months")
                        Text("last_6_months".localized).tag("6months")
                        Text("last_year".localized).tag("year")
                    }
                } header: {
                    Text("date_range".localized)
                }
                
                Section {
                    Toggle("include_body_composition".localized, isOn: $includeBodyComposition)
                } header: {
                    Text("options".localized)
                } footer: {
                    Text("body_composition_description".localized)
                }
                
                Section {
                    Button(action: exportData) {
                        HStack {
                            Spacer()
                            Label("export".localized, systemImage: "square.and.arrow.up")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("export_options".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }
    
    private func exportData() {
        let repository = ServiceContainer.shared.weightRepository
        
        let dateRange: DateRange
        switch selectedDateRange {
        case "month": dateRange = .month
        case "3months": dateRange = .threeMonths
        case "6months": dateRange = .sixMonths
        case "year": dateRange = .year
        default: dateRange = .all
        }
        
        if selectedFormat == "csv" {
            exportURL = repository.exportToCSV(
                dateRange: dateRange,
                includeBodyComposition: includeBodyComposition
            )
        } else {
            exportURL = repository.exportToJSON(
                dateRange: dateRange,
                includeBodyComposition: includeBodyComposition
            )
        }
        
        if exportURL != nil {
            showingShareSheet = true
        }
    }
}

// Settings Button View for easy integration
struct WeightSettingsButton: View {
    @State private var showingSettings = false
    
    var body: some View {
        Button(action: {
            showingSettings = true
        }) {
            Image(systemName: "gearshape")
        }
        .sheet(isPresented: $showingSettings) {
            WeightSettingsView()
        }
    }
}