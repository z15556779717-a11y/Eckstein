//
//  FoodPickerSheet.swift
//  Eckstein
//
//  Choosing a food: search the catalog, or pick from favourites and recents.
//
//  Everything it lists is a `CDEcksteinFood`. The deprecated `CDFood` set is not
//  reachable from here, which is what keeps a newly logged entry from landing in
//  the old model.
//

import SwiftUI

struct FoodPickerSheet: View {
    /// Called with the chosen food. The caller decides whether that means
    /// "log it" or "put it in the editor".
    let onPick: (CDEcksteinFood) -> Void

    @StateObject private var viewModel = FoodPickerViewModel()
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizationManager = LocalizationManager.shared

    @State private var showingCustomFood = false
    @State private var showingBarcode = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("diet_picker_scope", selection: $viewModel.scope) {
                    ForEach(FoodPickerViewModel.Scope.allCases) { scope in
                        Text(scope.titleKey.localized).tag(scope)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top, 8)

                content
            }
            .navigationTitle("diet_add_food".localized)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.searchText, prompt: "search_food".localized)
            .onChange(of: viewModel.searchText) { _, _ in
                viewModel.searchTextChanged()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingCustomFood = true
                        } label: {
                            Label("custom_food".localized, systemImage: "square.and.pencil")
                        }
                        Button {
                            showingBarcode = true
                        } label: {
                            Label("scan_barcode".localized, systemImage: "barcode.viewfinder")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("diet_add_food".localized)
                }
            }
            .environment(\.layoutDirection, localizationManager.layoutDirection)
            .onAppear { viewModel.load() }
            .sheet(isPresented: $showingCustomFood) {
                CustomFoodFormView { food in
                    showingCustomFood = false
                    onPick(food)
                    dismiss()
                }
            }
            .sheet(isPresented: $showingBarcode) {
                BarcodeLookupSheet { food in
                    showingBarcode = false
                    onPick(food)
                    dismiss()
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            LoadingStateView()
                .frame(maxHeight: .infinity)
        } else if let errorMessage = viewModel.errorMessage {
            ErrorStateView(message: errorMessage) { viewModel.load() }
                .frame(maxHeight: .infinity)
        } else if viewModel.visibleFoods.isEmpty {
            EmptyStateContent(
                icon: viewModel.isEmptyScope ? "tray" : "magnifyingglass",
                title: emptyTitle,
                message: emptyMessage
            )
            .frame(maxHeight: .infinity)
        } else {
            List {
                ForEach(viewModel.visibleFoods, id: \.objectID) { food in
                    Button {
                        onPick(food)
                        dismiss()
                    } label: {
                        row(for: food)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .leading) {
                        favoriteAction(for: food)
                    }
                }
            }
            .listStyle(PlainListStyle())
        }
    }

    /// A search that matched nothing and an empty list are different facts, and
    /// the picker says which one it is showing.
    private var emptyTitle: String {
        guard viewModel.isEmptyScope else { return "no_search_results".localized }
        switch viewModel.scope {
        case .all: return "diet_no_foods".localized
        case .favorites: return "diet_no_favorites".localized
        case .recents: return "diet_no_recents".localized
        }
    }

    private var emptyMessage: String {
        guard viewModel.isEmptyScope else { return "no_search_results_message".localized }
        switch viewModel.scope {
        case .all: return "diet_no_foods_message".localized
        case .favorites: return "diet_no_favorites_message".localized
        case .recents: return "diet_no_recents_message".localized
        }
    }

    private func row(for food: CDEcksteinFood) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(food.displayName)
                    .font(.body)
                    .foregroundColor(.primary)

                if let subtitle = subtitle(for: food) {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 8)

            if let calorieText = viewModel.calorieText(for: food) {
                Text(calorieText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if food.isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// Brand and category, either of which may be absent — a shipped diet rule
    /// has a category and no brand, a scanned product usually has both.
    ///
    /// The category goes through `displayCategory` for the same reason the name
    /// goes through `displayName`: a shipped food's "Protein" is a label, and a
    /// scanned product's is whatever its own database said.
    private func subtitle(for food: CDEcksteinFood) -> String? {
        let parts = [food.brand, food.displayCategory]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func favoriteAction(for food: CDEcksteinFood) -> some View {
        Button {
            try? viewModel.toggleFavorite(food)
        } label: {
            Label(
                (food.isFavorite ? "unfavorite" : "favorite").localized,
                systemImage: food.isFavorite ? "star.slash" : "star"
            )
        }
        .tint(.yellow)
    }
}
