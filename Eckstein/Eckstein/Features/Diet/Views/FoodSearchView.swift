//
//  FoodSearchView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI
import UIKit

struct FoodSearchView: View {
    @StateObject private var viewModel = FoodSearchViewModel()
    @StateObject private var barcodeViewModel = BarcodeViewModel()
    @State private var showBarcodeScanner = false
    @State private var showAddFood = false
    @State private var showCameraDeniedAlert = false

    /// The scan button has two jobs now: opening the scanner, and — when the
    /// camera has been refused — being the one place that says why it will not
    /// open and offers the only thing that can change that.
    private func handleScanTap() {
        if barcodeViewModel.cameraPermission == .refused {
            showCameraDeniedAlert = true
        } else {
            showBarcodeScanner = true
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
    @State private var selectedFood: CDFood?
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    
    let onSelect: (CDFood) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search foods...", text: $viewModel.searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: handleScanTap) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.title2)
                            .foregroundColor(themeManager.dietPrimaryColor)
                    }
                    // Disabled only while the system prompt is still up: once the
                    // answer is known, a refusal has to stay tappable or the trip
                    // to Settings is behind a dead button.
                    .disabled(barcodeViewModel.cameraPermission == .notDetermined)
                    .alert("diet_camera_permission_title".localized, isPresented: $showCameraDeniedAlert) {
                        Button("alert_button_cancel".localized, role: .cancel) {}
                        Button("diet_open_settings".localized) { openAppSettings() }
                    } message: {
                        Text("diet_camera_permission_message".localized)
                    }
                    .tooltip(
                        "Scan barcodes to quickly add foods",
                        tipId: TipManager.TipID.foodSearch,
                        position: .below
                    )
                }
                .padding()
                
                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.categories, id: \.self) { category in
                            CategoryChip(
                                title: category,
                                isSelected: viewModel.selectedCategory == category,
                                action: {
                                    if viewModel.selectedCategory == category {
                                        viewModel.selectedCategory = nil
                                    } else {
                                        viewModel.selectedCategory = category
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Search Results
                        if !viewModel.searchText.isEmpty {
                            if viewModel.isSearching {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                    Spacer()
                                }
                                .padding()
                            } else if viewModel.searchResults.isEmpty {
                                VStack(spacing: 16) {
                                    Text("No foods found")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    
                                    Button(action: { showAddFood = true }) {
                                        Label("Create Custom Food", systemImage: "plus.circle.fill")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                            } else {
                                FoodSection(
                                    title: "Search Results",
                                    foods: viewModel.searchResults,
                                    onSelect: selectFood,
                                    onToggleFavorite: viewModel.toggleFavorite
                                )
                            }
                        } else {
                            // Favorites
                            if !viewModel.favoriteFoods.isEmpty {
                                FoodSection(
                                    title: "Favorites",
                                    foods: viewModel.favoriteFoods,
                                    onSelect: selectFood,
                                    onToggleFavorite: viewModel.toggleFavorite
                                )
                            }
                            
                            // Recent Foods
                            if !viewModel.recentFoods.isEmpty {
                                FoodSection(
                                    title: "Recent",
                                    foods: viewModel.recentFoods,
                                    onSelect: selectFood,
                                    onToggleFavorite: viewModel.toggleFavorite
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddFood = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showBarcodeScanner) {
                BarcodeScannerView(
                    scannedCode: $barcodeViewModel.scannedCode,
                    isPresented: $showBarcodeScanner,
                    onScan: barcodeViewModel.handleScannedCode
                )
                // This view is unreachable legacy code and its whole data path is
                // the frozen `CDFood` set, so a scan result — which now resolves
                // to an official `CDEcksteinFood` — has nothing to select here.
                // Scans land in the official catalog via `BarcodeFoodResolver`.
                // See NUTRITION_MIGRATION_PLAN.md §9.
            }
            .sheet(isPresented: $showAddFood) {
                AddFoodView { newFood in
                    selectFood(newFood)
                }
            }
        }
    }
    
    private func selectFood(_ food: CDFood) {
        viewModel.markFoodAsUsed(food)
        onSelect(food)
        dismiss()
    }
}

struct FoodSection: View {
    let title: String
    let foods: [CDFood]
    let onSelect: (CDFood) -> Void
    let onToggleFavorite: (CDFood) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                ForEach(foods) { food in
                    FoodRowView(
                        food: food,
                        onSelect: { onSelect(food) },
                        onToggleFavorite: { onToggleFavorite(food) }
                    )
                }
            }
        }
    }
}

struct FoodRowView: View {
    let food: CDFood
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(food.name ?? "Unknown")
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        if let brand = food.brand, !brand.isEmpty {
                            Text("• \(brand)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if food.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    
                    HStack {
                        Text("\(food.caloriesPer100g) cal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text("P: \(Int(food.proteinPer100g))g")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("C: \(Int(food.carbsPer100g))g")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("F: \(Int(food.fatPer100g))g")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: onToggleFavorite) {
                    Image(systemName: food.isFavorite ? "star.fill" : "star")
                        .foregroundColor(food.isFavorite ? .yellow : .gray)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CategoryChip: View {
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
                .background(isSelected ? themeManager.dietPrimaryColor : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}