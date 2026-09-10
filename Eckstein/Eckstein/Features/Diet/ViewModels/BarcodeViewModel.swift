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

/// Scan-code state for the barcode flow.
///
/// **Retargeted in phase 2.** This used to fetch and create `CDFood` rows
/// directly — the orphaned entity set, whose catalog received no user writes and
/// whose lookups could never hit. It now resolves through `BarcodeFoodResolver`,
/// so a scan lands in the official `CDEcksteinFood` catalog. The camera layer
/// (`BarcodeScannerView`) and the network layer (`FoodAPIService`) are untouched.
/// See NUTRITION_MIGRATION_PLAN.md §9.
@MainActor
class BarcodeViewModel: ObservableObject {
    @Published var scannedCode: String?
    @Published var isScanning = false
    @Published var foundFood: CDEcksteinFood?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var hasCameraPermission = false

    private let resolver: BarcodeFoodResolver
    private var cancellables = Set<AnyCancellable>()

    /// `resolver` is optional rather than defaulted to `BarcodeFoodResolver()`.
    /// A default argument is evaluated in a nonisolated thunk, which cannot call
    /// the `@MainActor` initializer; constructing it in the body can.
    init(resolver: BarcodeFoodResolver? = nil) {
        self.resolver = resolver ?? BarcodeFoodResolver()
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

        Task {
            do {
                let food = try await resolver.resolve(barcode: barcode)
                foundFood = food
                if food == nil {
                    error = BarcodeError.foodNotFound
                }
            } catch {
                self.error = error
            }
            isLoading = false
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
