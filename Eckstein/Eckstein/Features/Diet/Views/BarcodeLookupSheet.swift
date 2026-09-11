//
//  BarcodeLookupSheet.swift
//  Eckstein
//
//  Scanning a barcode into the official catalog.
//
//  The AVFoundation half is `BarcodeScannerView`, unchanged and untouched: it
//  hands back a `String` and knows nothing about nutrition. The lookup half is
//  `BarcodeFoodResolver`, which goes local catalog first and Open Food Facts
//  second and writes through `NutritionService`. Nothing here reads or writes
//  Core Data, and nothing here knows what Open Food Facts is.
//

import SwiftUI

struct BarcodeLookupSheet: View {
    /// Called with the resolved catalog row.
    let onPick: (CDEcksteinFood) -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizationManager = LocalizationManager.shared

    @State private var scannedCode: String?
    @State private var phase: Phase = .scanning

    private enum Phase: Equatable {
        case scanning
        case lookingUp
        case notFound
        case failed(String)
    }

    var body: some View {
        NavigationView {
            content
                .navigationTitle("scan_barcode".localized)
                .navigationBarTitleDisplayMode(.inline)
                .environment(\.layoutDirection, localizationManager.layoutDirection)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("cancel".localized) { dismiss() }
                    }
                }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .scanning:
            BarcodeScannerView(
                scannedCode: $scannedCode,
                // The scanner clears this flag once it has a code. The sheet
                // stays up until the lookup resolves, so the binding is a no-op
                // rather than something this view reacts to.
                isPresented: .constant(true)
            ) { code in
                Task { await lookUp(code) }
            }

        case .lookingUp:
            LoadingStateView(message: "barcode_searching".localized)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .notFound:
            EmptyStateContent(
                icon: "barcode.viewfinder",
                title: "barcode_not_found".localized,
                message: "barcode_not_found_message".localized,
                actionTitle: "scan_again".localized,
                action: { phase = .scanning }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            ErrorStateView(message: message) { phase = .scanning }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Resolves a scanned code and hands the food back.
    ///
    /// The three outcomes are kept apart deliberately. "Unknown product" is not
    /// a failure — Open Food Facts simply does not have it, and the user's next
    /// move is to scan another one. A network error is a failure, and its next
    /// move is to retry.
    private func lookUp(_ code: String) async {
        phase = .lookingUp

        do {
            let resolver = BarcodeFoodResolver()
            guard let food = try await resolver.resolve(barcode: code) else {
                phase = .notFound
                return
            }
            onPick(food)
            dismiss()
        } catch {
            phase = .failed("error_loading_data".localized)
        }
    }
}
