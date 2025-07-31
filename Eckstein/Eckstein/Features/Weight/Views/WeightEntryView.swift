//
//  WeightEntryView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

struct WeightEntryView: View {
    @StateObject private var viewModel = WeightEntryViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isWeightFieldFocused: Bool
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var onSave: (() -> Void)?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Weight Input
                    VStack(alignment: .leading, spacing: 8) {
                        Label("weight".localized, systemImage: "scalemass")
                            .font(.headline)
                        
                        HStack {
                            TextField(viewModel.weightPlaceholder, text: $viewModel.weightString)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .multilineTextAlignment(.center)
                                .focused($isWeightFieldFocused)
                            
                            Text(viewModel.unitLabel)
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Date & Time
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("date_time".localized, systemImage: "calendar")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button("today".localized) {
                                viewModel.quickSetToday()
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                        
                        DatePicker(
                            "",
                            selection: $viewModel.selectedDate,
                            in: ...Date(),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Optional Body Composition
                    DisclosureGroup {
                        VStack(spacing: 16) {
                            // Body Fat
                            VStack(alignment: .leading, spacing: 8) {
                                Label("body_fat".localized, systemImage: "percent")
                                    .font(.subheadline)
                                
                                HStack {
                                    TextField("body_fat_placeholder".localized, text: $viewModel.bodyFatString)
                                        .keyboardType(.decimalPad)
                                    
                                    Text("percentage_symbol".localized)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemGray5))
                                .cornerRadius(8)
                            }
                            
                            // Muscle Mass
                            VStack(alignment: .leading, spacing: 8) {
                                Label("muscle_mass".localized, systemImage: "figure.strengthtraining.traditional")
                                    .font(.subheadline)
                                
                                HStack {
                                    TextField("muscle_mass_placeholder".localized, text: $viewModel.muscleMassString)
                                        .keyboardType(.decimalPad)
                                    
                                    Text(viewModel.unitLabel)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemGray5))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.top)
                    } label: {
                        Label("body_composition_optional".localized, systemImage: "figure.stand")
                            .font(.headline)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Label("notes_optional".localized, systemImage: "note.text")
                            .font(.headline)
                        
                        TextEditor(text: $viewModel.notes)
                            .frame(minHeight: 80)
                            .padding(8)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
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
                        saveWeight()
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.weightString.isEmpty)
                }
            }
            .alert("error".localized, isPresented: $viewModel.isShowingError) {
                Button("ok".localized) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
        .onAppear {
            isWeightFieldFocused = true
        }
    }
    
    private func saveWeight() {
        viewModel.saveWeight { success in
            if success {
                onSave?()
                dismiss()
            }
        }
    }
}

struct WeightEntryView_Previews: PreviewProvider {
    static var previews: some View {
        WeightEntryView()
    }
}