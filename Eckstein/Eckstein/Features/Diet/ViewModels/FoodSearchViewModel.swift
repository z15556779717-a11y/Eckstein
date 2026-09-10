//
//  FoodSearchViewModel.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation
import CoreData
import Combine

/// **Deprecated in phase 2.**
///
/// Searches and writes `CDFood`, the orphaned entity set. It is reachable only
/// from the unreachable view suite rooted at `DietDashboardView`. The official
/// search path is `NutritionService.foods(matching:)` over `CDEcksteinFood`.
/// See NUTRITION_MIGRATION_PLAN.md §11.
@MainActor
class FoodSearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [CDFood] = []
    @Published var recentFoods: [CDFood] = []
    @Published var favoriteFoods: [CDFood] = []
    @Published var isSearching = false
    @Published var selectedCategory: String? = nil
    @Published var error: Error?
    
    private let repository: DietRepository
    private let foodAPIService = FoodAPIService.shared
    private let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    
    let categories = ["All", "Protein", "Carbs", "Vegetable", "Fruit", "Dairy", "Fats", "Nuts", "Snack", "Supplement", "External"]
    
    init(repository: DietRepository? = nil,
         context: NSManagedObjectContext? = nil) {
        self.repository = repository ?? ServiceContainer.shared.dietRepository
        self.context = context ?? PersistenceController.shared.container.viewContext
        
        setupSearchPublisher()
        fetchRecentFoods()
        fetchFavoriteFoods()
    }
    
    private func setupSearchPublisher() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] searchText in
                self?.performSearch(searchText)
            }
            .store(in: &cancellables)
    }
    
    private func performSearch(_ query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        // First search local database
        let request: NSFetchRequest<CDFood> = CDFood.fetchRequest()
        
        var predicates: [NSPredicate] = []
        predicates.append(NSPredicate(format: "name CONTAINS[cd] %@", query))
        
        if let category = selectedCategory, category != "All" {
            predicates.append(NSPredicate(format: "category == %@", category))
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [
            NSSortDescriptor(key: "isFavorite", ascending: false),
            NSSortDescriptor(key: "lastUsed", ascending: false),
            NSSortDescriptor(key: "name", ascending: true)
        ]
        
        do {
            searchResults = try context.fetch(request)
            
            // If no local results and query looks like a barcode, search API
            if searchResults.isEmpty && query.count >= 8 && query.allSatisfy({ $0.isNumber }) {
                searchFoodByBarcode(query)
            } else if searchResults.count < 5 {
                // If few local results, search API for more options
                searchFoodByName(query)
            }
        } catch {
            self.error = error
        }
        
        isSearching = false
    }
    
    private func searchFoodByBarcode(_ barcode: String) {
        foodAPIService.searchFoodByBarcode(barcode)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] response in
                    if let product = response.product,
                       let foodTemplate = self?.foodAPIService.createFoodFromAPIResponse(product) {
                        self?.createFoodFromTemplate(foodTemplate)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func searchFoodByName(_ query: String) {
        foodAPIService.searchFoodByName(query)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] products in
                    for product in products.prefix(5) {
                        if let foodTemplate = self?.foodAPIService.createFoodFromAPIResponse(product) {
                            self?.createFoodFromTemplate(foodTemplate)
                        }
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func createFoodFromTemplate(_ template: FoodTemplate) {
        // Check if food already exists
        let request: NSFetchRequest<CDFood> = CDFood.fetchRequest()
        if let barcode = template.barcode {
            request.predicate = NSPredicate(format: "barcode == %@", barcode)
        } else {
            request.predicate = NSPredicate(format: "name == %@ AND brand == %@", template.name, template.brand ?? "")
        }
        
        do {
            let existingFoods = try context.fetch(request)
            if existingFoods.isEmpty {
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
                
                try context.save()
                performSearch(searchText) // Refresh search results
            }
        } catch {
            self.error = error
        }
    }
    
    func fetchRecentFoods() {
        let request: NSFetchRequest<CDFood> = CDFood.fetchRequest()
        request.predicate = NSPredicate(format: "lastUsed != nil")
        request.sortDescriptors = [NSSortDescriptor(key: "lastUsed", ascending: false)]
        request.fetchLimit = 10
        
        do {
            recentFoods = try context.fetch(request)
        } catch {
            self.error = error
        }
    }
    
    func fetchFavoriteFoods() {
        let request: NSFetchRequest<CDFood> = CDFood.fetchRequest()
        request.predicate = NSPredicate(format: "isFavorite == YES")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            favoriteFoods = try context.fetch(request)
        } catch {
            self.error = error
        }
    }
    
    func toggleFavorite(_ food: CDFood) {
        food.isFavorite.toggle()
        do {
            try context.save()
            fetchFavoriteFoods()
        } catch {
            self.error = error
        }
    }
    
    func markFoodAsUsed(_ food: CDFood) {
        food.lastUsed = Date()
        do {
            try context.save()
            fetchRecentFoods()
        } catch {
            self.error = error
        }
    }
}