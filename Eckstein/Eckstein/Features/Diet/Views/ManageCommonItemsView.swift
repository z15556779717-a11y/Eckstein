//
//  ManageCommonItemsView.swift
//  Eckstein
//
//  Created by Assistant on 14/07/2025.
//

import SwiftUI

struct ManageCommonItemsView: View {
    @StateObject private var manager = CommonCalorieItemsManager.shared
    @State private var showingAddItem = false
    @State private var newItemName = ""
    @State private var newItemCalories = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(manager.items) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("\(item.calories) calories")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    .onDelete(perform: deleteItems)
                } header: {
                    Text("manage_common_items_title".localized)
                }

                Section {
                    Button(action: { showingAddItem = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("manage_common_items_add_new".localized)
                                .foregroundColor(.primary)
                        }
                    }

                    Button(action: resetToDefaults) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.orange)
                            Text("manage_common_items_reset_defaults".localized)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .navigationTitle("manage_common_items_nav_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("done".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddCommonItemView(manager: manager)
            }
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            manager.deleteItem(manager.items[index])
        }
    }
    
    private func resetToDefaults() {
        manager.resetToDefaults()
    }
}

struct AddCommonItemView: View {
    @ObservedObject var manager: CommonCalorieItemsManager
    @State private var name = ""
    @State private var calories = ""
    @State private var showError = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("manage_common_items_item_details".localized)) {
                    TextField("manage_common_items_item_name".localized, text: $name)

                    HStack {
                        TextField("calories".localized, text: $calories)
                            .keyboardType(.numberPad)
                        Text("cal")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Text("manage_common_items_examples".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("manage_common_items_add_item".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save".localized) {
                        saveItem()
                    }
                    .disabled(name.isEmpty || calories.isEmpty)
                }
            }
            .alert("manage_common_items_invalid_input".localized, isPresented: $showError) {
                Button("ok".localized) { }
            } message: {
                Text("manage_common_items_invalid_message".localized)
            }
        }
    }
    
    private func saveItem() {
        guard !name.isEmpty, let calorieAmount = Int(calories), calorieAmount > 0 else {
            showError = true
            return
        }
        
        let newItem = CommonCalorieItem(name: name, calories: calorieAmount)
        manager.addItem(newItem)
        dismiss()
    }
}