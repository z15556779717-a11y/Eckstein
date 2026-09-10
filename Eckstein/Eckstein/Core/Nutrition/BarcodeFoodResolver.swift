//
//  BarcodeFoodResolver.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation
import Combine

/// Turns a scanned barcode into an official `CDEcksteinFood` row.
///
/// This is the seam required by NUTRITION_MIGRATION_PLAN.md §9. The two halves
/// of the barcode feature are already model-free and stay that way:
///
/// * `BarcodeScannerView` / `BarcodeScannerViewController` (AVFoundation) only
///   hand back a `String` code.
/// * `FoodAPIService` only hands back a `FoodTemplate`.
///
/// The persistence half used to be welded to the orphaned entity set: both
/// `BarcodeViewModel` and the legacy `DietViewModel` helpers wrote `CDFood`
/// directly. This resolver is the single place that maps a barcode onto the
/// official model instead — local catalog first, then Open Food Facts, then a
/// write through `NutritionService`. No second scanner and no second lookup
/// path were introduced.
@MainActor
final class BarcodeFoodResolver {
    /// `source` stamp for catalog rows that entered through a scan.
    static let source = "barcode"

    private let service: NutritionService
    private let api: FoodAPIService

    init(service: NutritionService = NutritionService(),
         api: FoodAPIService = FoodAPIService.shared) {
        self.service = service
        self.api = api
    }

    /// Local-first barcode lookup.
    ///
    /// Returns the existing catalog row when the barcode is already known —
    /// without touching the network — otherwise asks Open Food Facts and upserts
    /// the product into the official catalog. Returns `nil` when the barcode is
    /// unknown to both and the API has no usable product data.
    func resolve(barcode: String) async throws -> CDEcksteinFood? {
        if let known = try service.food(matchingBarcode: barcode) {
            return known
        }

        let response = try await fetchProduct(barcode: barcode)
        guard let product = response.product,
              let template = api.createFoodFromAPIResponse(product) else {
            return nil
        }

        return try service.upsertFood(from: template, source: Self.source)
    }

    private func fetchProduct(barcode: String) async throws -> FoodAPIResponse {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = api.searchFoodByBarcode(barcode)
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
    }
}
