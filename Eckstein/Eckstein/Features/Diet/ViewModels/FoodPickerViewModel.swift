//
//  FoodPickerViewModel.swift
//  Eckstein
//
//  Searching the official food catalog: text search, favourites and recents.
//
//  All three read `CDEcksteinFood` through `NutritionService`, which owns the
//  fetch and its sort. Recents is a query on the stored `lastUsed` stamp rather
//  than a scan over the day's entries, so the picker stays cheap however long
//  the log gets.
//

import Foundation
import Combine

@MainActor
final class FoodPickerViewModel: ObservableObject {

    /// Which list the picker is showing.
    enum Scope: String, CaseIterable, Identifiable {
        case all
        case favorites
        case recents

        var id: String { rawValue }

        /// The localization key for the segmented control.
        var titleKey: String {
            switch self {
            case .all: return "all"
            case .favorites: return "favorites"
            case .recents: return "recents"
            }
        }
    }

    @Published var searchText = ""
    @Published var scope: Scope = .all

    @Published private(set) var results: [CDEcksteinFood] = []
    @Published private(set) var favorites: [CDEcksteinFood] = []
    @Published private(set) var recents: [CDEcksteinFood] = []
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    private let nutrition: NutritionService

    /// The in-flight search, so a fast typist does not queue one fetch per
    /// keystroke against the store.
    private var searchTask: Task<Void, Never>?

    init(nutrition: NutritionService = .shared) {
        self.nutrition = nutrition
    }

    // MARK: - Loading

    func load() {
        if favorites.isEmpty, recents.isEmpty, results.isEmpty { isLoading = true }
        errorMessage = nil

        do {
            favorites = try nutrition.favoriteFoods()
            recents = try nutrition.recentFoods()
            results = try nutrition.foods(matching: searchText)
        } catch {
            favorites = []
            recents = []
            results = []
            errorMessage = "error_loading_data".localized
        }

        isLoading = false
    }

    /// Loads and then debounces: the first pass fills the lists immediately, and
    /// the fetch for a new query runs once typing pauses.
    func searchTextChanged() {
        searchTask?.cancel()
        let query = searchText
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await self?.runSearch(query)
        }
    }

    private func runSearch(_ query: String) {
        guard !Task.isCancelled else { return }
        // A result for a query the user has already moved on from would replace
        // the list under their finger.
        guard query == searchText else { return }

        do {
            results = try nutrition.foods(matching: query)
            errorMessage = nil
        } catch {
            results = []
            errorMessage = "error_loading_data".localized
        }
    }

    // MARK: - Favourites

    func toggleFavorite(_ food: CDEcksteinFood) throws {
        try nutrition.setFavorite(food, isFavorite: !food.isFavorite)
        favorites = try nutrition.favoriteFoods()
        results = try nutrition.foods(matching: searchText)
    }

    // MARK: - Display

    /// The list the current scope shows, already sorted by the service.
    var visibleFoods: [CDEcksteinFood] {
        switch scope {
        case .all: return results
        case .favorites: return favorites
        case .recents: return recents
        }
    }

    /// Whether the picker is looking at a list that is empty for a reason worth
    /// explaining, rather than because a search matched nothing.
    var isEmptyScope: Bool {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && visibleFoods.isEmpty
    }

    /// The per-100 g energy figure, for the row's trailing label.
    func calorieText(for food: CDEcksteinFood) -> String? {
        guard let calories = food.caloriesPer100g?.doubleValue else { return nil }
        guard let text = NutrientFormat.calories(calories) else { return nil }
        return "\(text) kcal"
    }
}
