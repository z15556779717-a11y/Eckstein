//
//  BarcodeViewModel.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation
import CoreData
import Combine
import AVFoundation

@MainActor
class BarcodeViewModel: ObservableObject {
    @Published var scannedCode: String?
    @Published var isScanning = false
    @Published var foundFood: CDFood?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var hasCameraPermission = false
    
    private let foodAPIService = FoodAPIService.shared
    private let repository: DietRepository
    private let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    
    init(repository: DietRepository? = nil,
         context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.repository = repository ?? DietRepository(context: context)
        self.context = context
        checkCameraPermission()
    }
    
    func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasCameraPermission = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.hasCameraPermission = granted
                }
            }
        case .denied, .restricted:
            hasCameraPermission = false
        @unknown default:
            hasCameraPermission = false
        }
    }
    
    func handleScannedCode(_ code: String) {
        scannedCode = code
        searchFoodByBarcode(code)
    }
    
    private func searchFoodByBarcode(_ barcode: String) {
        isLoading = true
        
        // First check local database
        let request: NSFetchRequest<CDFood> = CDFood.fetchRequest()
        request.predicate = NSPredicate(format: "barcode == %@", barcode)
        request.fetchLimit = 1
        
        do {
            let foods = try context.fetch(request)
            if let food = foods.first {
                foundFood = food
                isLoading = false
                return
            }
        } catch {
            self.error = error
        }
        
        // If not found locally, search API
        foodAPIService.searchFoodByBarcode(barcode)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] response in
                    if let product = response.product,
                       let foodTemplate = self?.foodAPIService.createFoodFromAPIResponse(product) {
                        self?.createAndSelectFood(from: foodTemplate)
                    } else {
                        self?.error = BarcodeError.foodNotFound
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func createAndSelectFood(from template: FoodTemplate) {
        let food = CDFood(context: context)
        food.id = UUID()
        food.name = template.name
        food.category = template.category
        food.barcode = template.barcode
        food.caloriesPer100g = Int32(template.caloriesPer100g)
        food.proteinPer100g = template.proteinPer100g
        food.carbsPer100g = template.carbsPer100g
        food.fatPer100g = template.fatPer100g
        food.fiberPer100g = template.fiberPer100g ?? 0
        food.brand = template.brand
        food.servingSize = template.servingSize ?? 100
        food.servingUnit = template.servingUnit ?? "g"
        food.isCustom = false
        food.isVerified = false
        
        do {
            try context.save()
            foundFood = food
        } catch {
            self.error = error
        }
    }
    
    func reset() {
        scannedCode = nil
        foundFood = nil
        error = nil
        isLoading = false
    }
}

enum BarcodeError: LocalizedError {
    case foodNotFound
    
    var errorDescription: String? {
        switch self {
        case .foodNotFound:
            return "Food not found. Try searching manually or create a custom food."
        }
    }
}