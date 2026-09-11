//
//  FoodAPIService.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation
import Combine

struct FoodAPIResponse: Codable {
    let product: Product?
    let status: Int
    let statusVerbose: String?
    
    struct Product: Codable {
        let productName: String?
        let brands: String?
        let nutriments: Nutriments
        let servingSize: String?
        let code: String?
        
        private enum CodingKeys: String, CodingKey {
            case productName = "product_name"
            case brands
            case nutriments
            case servingSize = "serving_size"
            case code
        }
    }
    
    struct Nutriments: Codable {
        let energyKcal100g: Double?
        let proteins100g: Double?
        let carbohydrates100g: Double?
        let fat100g: Double?
        let fiber100g: Double?
        
        private enum CodingKeys: String, CodingKey {
            case energyKcal100g = "energy-kcal_100g"
            case proteins100g = "proteins_100g"
            case carbohydrates100g = "carbohydrates_100g"
            case fat100g = "fat_100g"
            case fiber100g = "fiber_100g"
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case product
        case status
        case statusVerbose = "status_verbose"
    }
}

class FoodAPIService: ObservableObject {
    static let shared = FoodAPIService()
    private let baseURL = "https://world.openfoodfacts.org/api/v0"
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isLoading = false
    @Published var error: Error?
    
    private init() {}
    
    func searchFoodByBarcode(_ barcode: String) -> AnyPublisher<FoodAPIResponse, Error> {
        guard let url = URL(string: "\(baseURL)/product/\(barcode).json") else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        isLoading = true
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: FoodAPIResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .handleEvents(
                receiveCompletion: { [weak self] _ in
                    self?.isLoading = false
                },
                receiveCancel: { [weak self] in
                    self?.isLoading = false
                }
            )
            .eraseToAnyPublisher()
    }
    
    func searchFoodByName(_ query: String) -> AnyPublisher<[FoodAPIResponse.Product], Error> {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "\(baseURL)/cgi/search.pl?search_terms=\(encodedQuery)&search_simple=1&action=process&json=1") else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        isLoading = true
        
        struct SearchResponse: Codable {
            let products: [FoodAPIResponse.Product]
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: SearchResponse.self, decoder: JSONDecoder())
            .map(\.products)
            .receive(on: DispatchQueue.main)
            .handleEvents(
                receiveCompletion: { [weak self] _ in
                    self?.isLoading = false
                },
                receiveCancel: { [weak self] in
                    self?.isLoading = false
                }
            )
            .eraseToAnyPublisher()
    }
    
    func createFoodFromAPIResponse(_ product: FoodAPIResponse.Product) -> FoodTemplate? {
        guard let name = product.productName,
              let calories = product.nutriments.energyKcal100g else {
            return nil
        }
        
        return FoodTemplate(
            name: name,
            category: "External",
            barcode: product.code,
            caloriesPer100g: Int(calories),
            // Passed through as-is, `nil` included. A label that omits a macro
            // states nothing about it, and `?? 0` here would record a claim the
            // product never made — for a food whose calories are known but whose
            // macros are not, that is a wrong number rather than a missing one.
            proteinPer100g: product.nutriments.proteins100g,
            carbsPer100g: product.nutriments.carbohydrates100g,
            fatPer100g: product.nutriments.fat100g,
            fiberPer100g: product.nutriments.fiber100g,
            brand: product.brands,
            servingSize: nil,
            servingUnit: product.servingSize
        )
    }
}