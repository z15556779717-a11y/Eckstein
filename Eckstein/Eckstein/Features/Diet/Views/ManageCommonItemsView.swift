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
                    Text("Common Food Items")
                }
                
                Section {
                    Button(action: { showingAddItem = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Add New Item")
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Button(action: resetToDefaults) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.orange)
                            Text("Reset to Defaults")
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .navigationTitle("Manage Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
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
                Section(header: Text("Item Details")) {
                    TextField("Item Name", text: $name)
                    
                    HStack {
                        TextField("Calories", text: $calories)
                            .keyboardType(.numberPad)
                        Text("cal")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Text("Examples: Olive Oil (1 tbsp), Jam (1 tsp), Cream (1 tbsp)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveItem()
                    }
                    .disabled(name.isEmpty || calories.isEmpty)
                }
            }
            .alert("Invalid Input", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text("Please enter a valid name and calorie amount.")
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