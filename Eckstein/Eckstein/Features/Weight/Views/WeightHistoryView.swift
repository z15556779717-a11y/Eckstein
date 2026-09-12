//
//  WeightHistoryView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct WeightHistoryView: View {
    @ObservedObject var viewModel: WeightViewModel
    @State private var showingDeleteAlert = false
    @State private var entryToDelete: CDWeightEntry?
    @State private var showingExportSheet = false
    @State private var exportURL: URL?
    @State private var sortOrder: SortOrder = .dateDescending
    @State private var filterDateRange: DateRange = .all
    
    enum SortOrder: String, CaseIterable {
        case dateDescending = "dateDescending"
        case dateAscending = "dateAscending"
        case weightDescending = "weightDescending"
        case weightAscending = "weightAscending"
        
        var displayName: String {
            switch self {
            case .dateDescending:
                return "newest_first".localized
            case .dateAscending:
                return "oldest_first".localized
            case .weightDescending:
                return "heaviest_first".localized
            case .weightAscending:
                return "lightest_first".localized
            }
        }
    }
    
    private var filteredAndSortedEntries: [CDWeightEntry] {
        let filtered = filterDateRange == .all 
            ? viewModel.weightEntries 
            : viewModel.repository.fetchWeightEntries(for: filterDateRange)
        
        return filtered.sorted { entry1, entry2 in
            switch sortOrder {
            case .dateDescending:
                return (entry1.date ?? Date()) > (entry2.date ?? Date())
            case .dateAscending:
                return (entry1.date ?? Date()) < (entry2.date ?? Date())
            case .weightDescending:
                return entry1.weightKg > entry2.weightKg
            case .weightAscending:
                return entry1.weightKg < entry2.weightKg
            }
        }
    }
    
    var body: some View {
        VStack {
            // Filter and Sort Controls
            VStack(spacing: 12) {
                // Date Range Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach([DateRange.all, .week, .month, .threeMonths, .year], id: \.self) { range in
                            FilterChip(
                                title: range.displayName,
                                isSelected: filterDateRange == range,
                                action: { filterDateRange = range }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Sort Options
                HStack {
                    Text("sort_by_label".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Picker("sort".localized, selection: $sortOrder) {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Text(order.displayName).tag(order)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Spacer()
                    
                    Button(action: exportData) {
                        Label("export".localized, systemImage: "square.and.arrow.up")
                            .font(.subheadline)
                    }
                }
                .padding(.horizontal)
            }
            
            if filteredAndSortedEntries.isEmpty {
                WeightEmptyHistoryView()
            } else {
                List {
                    ForEach(filteredAndSortedEntries) { entry in
                        WeightHistoryRow(
                            entry: entry, 
                            viewModel: viewModel,
                            onDelete: {
                                entryToDelete = entry
                                showingDeleteAlert = true
                            }
                        )
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("weight_history".localized)
        .navigationBarTitleDisplayMode(.large)
        .alert("delete_entry_title".localized, isPresented: $showingDeleteAlert) {
            Button("cancel".localized, role: .cancel) { }
            Button("delete".localized, role: .destructive) {
                if let entry = entryToDelete {
                    viewModel.deleteEntry(entry)
                }
            }
        } message: {
            Text("delete_entry_message".localized)
        }
        .sheet(isPresented: $showingExportSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
    }
    
    private func exportData() {
        if let url = viewModel.repository.exportToCSV() {
            exportURL = url
            showingExportSheet = true
        }
    }
}

struct WeightHistoryRow: View {
    let entry: CDWeightEntry
    @ObservedObject var viewModel: WeightViewModel
    let onDelete: () -> Void
    @State private var showingEditSheet = false
    
    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: UserDefaults.standard.string(forKey: "weightUnit") ?? "kg") ?? .kg
    }
    
    private var displayWeight: String {
        let weight = weightUnit == .lbs ? entry.weightKg * 2.20462 : entry.weightKg
        return String(format: "%.1f", weight)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.formattedDate)
                        .font(.headline)
                    
                    if let source = entry.source {
                        Label(localizedSource(source), systemImage: sourceIcon(source))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(displayWeight)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(weightUnit.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let bmi = entry.bmi {
                        Text("\("bmi_prefix".localized): \(String(format: "%.1f", bmi))")
                            .font(.caption)
                            .foregroundColor(bmiColor(bmi))
                    }
                }
            }
            
            // Additional Details - Safely access body composition data
            let bodyFat = (try? entry.value(forKey: "bodyFatPercentage") as? Double) ?? 0
            let muscleMassKg = (try? entry.value(forKey: "muscleMass") as? Double) ?? 0
            
            if bodyFat > 0 || muscleMassKg > 0 {
                HStack(spacing: 16) {
                    if bodyFat > 0 {
                        Label("\(String(format: "%.1f", bodyFat))% \("fat_suffix".localized)", systemImage: "percent")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    if muscleMassKg > 0 {
                        let muscleMass = weightUnit == .lbs ? muscleMassKg * 2.20462 : muscleMassKg
                        Label("\(String(format: "%.1f", muscleMass)) \(weightUnit.rawValue) \("muscle_suffix".localized)", systemImage: "figure.strengthtraining.traditional")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            if let notes = entry.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            showingEditSheet = true
        }
        .contextMenu {
            Button {
                showingEditSheet = true
            } label: {
                Label("edit".localized, systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("delete".localized, systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            WeightEditView(entry: entry, viewModel: viewModel)
        }
    }
    
    private func sourceIcon(_ source: String) -> String {
        switch source.lowercased() {
        case "manual":
            return "pencil"
        case "scale":
            return "scalemass"
        case "healthkit":
            return "heart.fill"
        default:
            return "questionmark.circle"
        }
    }
    
    private func bmiColor(_ bmi: Double) -> Color {
        switch bmi {
        case ..<18.5:
            return .blue
        case 18.5..<25:
            return .green
        case 25..<30:
            return .orange
        default:
            return .red
        }
    }
    
    private func localizedSource(_ source: String) -> String {
        switch source.lowercased() {
        case "manual":
            return "manual".localized
        case "scale", "xiaomi":
            return "xiaomi_scale".localized
        case "health", "healthkit":
            return "apple_health".localized
        default:
            return source.capitalized
        }
    }
}

struct WeightEmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("no_weight_entries".localized)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("start_tracking_weight".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? (themeManager.accentColor == .defaultMix ? 
                                        themeManager.accentColor.contextColor(for: .weight) : 
                                        themeManager.accentColor.color) : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}