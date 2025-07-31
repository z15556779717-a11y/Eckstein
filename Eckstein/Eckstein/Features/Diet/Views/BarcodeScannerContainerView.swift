//
//  BarcodeScannerContainerView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI
import CoreData
import Combine

struct BarcodeScannerContainerView: View {
    @ObservedObject var viewModel: DietViewModel
    let selectedMealType: String?
    @State private var scannedCode: String?
    @State private var isScanning = true
    @State private var showFoodDetail = false
    @State private var scannedFood: CDFood?
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            if isScanning {
                BarcodeScannerView(
                    scannedCode: $scannedCode,
                    isPresented: .constant(true)
                ) { code in
                    handleScannedCode(code)
                }
                .navigationTitle("Scan Barcode")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
                .overlay(alignment: .bottom) {
                    if let errorMessage = errorMessage {
                        ErrorBanner(message: errorMessage)
                            .transition(.move(edge: .bottom))
                            .animation(.easeInOut, value: errorMessage)
                    }
                }
            } else if showFoodDetail, let food = scannedFood {
                ScannedFoodDetailView(
                    food: food,
                    viewModel: viewModel,
                    selectedMealType: selectedMealType,
                    onDismiss: {
                        dismiss()
                    }
                )
            } else {
                ProgressView("Searching for product...")
                    .navigationTitle("Loading")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
    
    private func handleScannedCode(_ code: String) {
        isScanning = false
        
        // First check local database
        if let localFood = viewModel.findFoodByBarcode(code) {
            scannedFood = localFood
            showFoodDetail = true
            return
        }
        
        // If not found locally, search online
        Task {
            do {
                // Use Combine publisher with async/await
                let response = try await withCheckedThrowingContinuation { continuation in
                    var cancellable: AnyCancellable?
                    cancellable = FoodAPIService.shared.searchFoodByBarcode(code)
                        .sink(
                            receiveCompletion: { completion in
                                if case .failure(let error) = completion {
                                    continuation.resume(throwing: error)
                                }
                                cancellable?.cancel()
                            },
                            receiveValue: { response in
                                continuation.resume(returning: response)
                            }
                        )
                }
                
                if let product = response.product {
                    // Create or update local food record
                    await MainActor.run {
                        scannedFood = viewModel.createFoodFromAPI(product)
                        showFoodDetail = true
                    }
                } else {
                    await MainActor.run {
                        errorMessage = "Product not found"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            errorMessage = nil
                            isScanning = true
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Error searching for product"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        errorMessage = nil
                        isScanning = true
                    }
                }
            }
        }
    }
}

struct ErrorBanner: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.red)
            .cornerRadius(8)
            .padding()
    }
}

struct ScannedFoodDetailView: View {
    let food: CDFood
    @ObservedObject var viewModel: DietViewModel
    let selectedMealType: String?
    let onDismiss: () -> Void
    
    @State private var servingSize: String = "100"
    @State private var selectedMeal: CDMeal?
    @State private var showMealPicker = false
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private var nutrition: NutritionInfo {
        let grams = Double(servingSize) ?? 100
        return ServingSizeCalculator.calculateNutrition(for: food, servingGrams: grams)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Food Info
                VStack(alignment: .leading, spacing: 12) {
                    Text(food.name ?? "Unknown Food")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let category = food.category {
                        Label(category, systemImage: "tag")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let barcode = food.barcode {
                        Label(barcode, systemImage: "barcode")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Serving Size
                VStack(alignment: .leading, spacing: 8) {
                    Text("Serving Size")
                        .font(.headline)
                    
                    HStack {
                        TextField("100", text: $servingSize)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 100)
                        
                        Text("grams")
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Quick serving buttons
                        ForEach([50, 100, 150, 200], id: \.self) { size in
                            Button("\(size)g") {
                                servingSize = String(size)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Nutrition Info
                VStack(alignment: .leading, spacing: 16) {
                    Text("Nutrition Facts")
                        .font(.headline)
                    
                    VStack(spacing: 12) {
                        ScannedNutritionRow(
                            label: "Calories",
                            value: "\(nutrition.calories)",
                            unit: "cal",
                            color: .orange
                        )
                        
                        Divider()
                        
                        ScannedNutritionRow(
                            label: "Protein",
                            value: String(format: "%.1f", nutrition.protein),
                            unit: "g",
                            color: themeManager.proteinColor
                        )
                        
                        ScannedNutritionRow(
                            label: "Carbohydrates",
                            value: String(format: "%.1f", nutrition.carbs),
                            unit: "g",
                            color: themeManager.carbsColor
                        )
                        
                        ScannedNutritionRow(
                            label: "Fat",
                            value: String(format: "%.1f", nutrition.fat),
                            unit: "g",
                            color: themeManager.fatColor
                        )
                        
                        if nutrition.fiber > 0 {
                            ScannedNutritionRow(
                                label: "Fiber",
                                value: String(format: "%.1f", nutrition.fiber),
                                unit: "g",
                                color: .brown
                            )
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Add to Meal Button
                Button(action: addToMeal) {
                    Label("Add to Meal", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeManager.dietPrimaryColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.top)
            }
            .padding()
        }
        .navigationTitle("Food Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Cancel") {
                    onDismiss()
                }
            }
        }
        .onAppear {
            setupSelectedMeal()
        }
        .actionSheet(isPresented: $showMealPicker) {
            ActionSheet(
                title: Text("Select Meal"),
                buttons: viewModel.todayMeals.map { meal in
                    .default(Text(meal.mealType?.capitalized ?? "Meal")) {
                        selectedMeal = meal
                        addFoodToSelectedMeal()
                    }
                } + [
                    .default(Text("Create New Meal")) {
                        createNewMealAndAdd()
                    },
                    .cancel()
                ]
            )
        }
    }
    
    private func setupSelectedMeal() {
        if let mealType = selectedMealType {
            selectedMeal = viewModel.todayMeals.first { $0.mealType == mealType }
        }
    }
    
    private func addToMeal() {
        if selectedMeal != nil {
            addFoodToSelectedMeal()
        } else if !viewModel.todayMeals.isEmpty {
            showMealPicker = true
        } else {
            createNewMealAndAdd()
        }
    }
    
    private func addFoodToSelectedMeal() {
        guard let meal = selectedMeal,
              let grams = Double(servingSize) else { return }
        
        viewModel.addFoodToMeal(meal, food: food, quantityGrams: grams)
        
        // Mark food as recently used
        food.lastUsed = Date()
        viewModel.saveContext()
        
        onDismiss()
    }
    
    private func createNewMealAndAdd() {
        let mealType = selectedMealType ?? MealType.breakfast.rawValue
        let meal = viewModel.createMeal(type: mealType)
        selectedMeal = meal
        addFoodToSelectedMeal()
    }
}

struct ScannedNutritionRow: View {
    let label: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(spacing: 4) {
                Text(value)
                    .font(.headline)
                    .foregroundColor(color)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// Add to DietViewModel
extension DietViewModel {
    func findFoodByBarcode(_ barcode: String) -> CDFood? {
        let request: NSFetchRequest<CDFood> = CDFood.fetchRequest()
        request.predicate = NSPredicate(format: "barcode == %@", barcode)
        request.fetchLimit = 1
        
        do {
            return try persistenceController.container.viewContext.fetch(request).first
        } catch {
            print("Error finding food by barcode: \(error)")
            return nil
        }
    }
    
    func createFoodFromAPI(_ product: FoodAPIResponse.Product) -> CDFood {
        let food = CDFood(context: persistenceController.container.viewContext)
        food.id = UUID()
        food.name = product.productName ?? "Unknown"
        food.barcode = product.code
        food.brand = product.brands
        food.category = "Scanned"
        
        // API provides nutrients per 100g
        food.caloriesPer100g = Int32(product.nutriments.energyKcal100g ?? 0)
        food.proteinPer100g = product.nutriments.proteins100g ?? 0
        food.carbsPer100g = product.nutriments.carbohydrates100g ?? 0
        food.fatPer100g = product.nutriments.fat100g ?? 0
        food.fiberPer100g = product.nutriments.fiber100g ?? 0
        food.isCustom = false
        food.lastUsed = Date()
        
        saveContext()
        repository.fetchFoods()
        
        return food
    }
}