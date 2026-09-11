//
//  NutritionGoalsViewModel.swift
//  Eckstein
//
//  Reading and writing the user's daily nutrition targets.
//
//  The values live in `CDUserPreferences` and are reached only through
//  `NutritionService.goals()` / `setGoals(_:)`. Nothing here writes to
//  `UserDefaults`: a second store for the same number is how the Dashboard and
//  the Profile screen end up disagreeing.
//

import Foundation
import Combine

@MainActor
final class NutritionGoalsViewModel: ObservableObject {

    /// The saved targets, as the store holds them.
    @Published private(set) var goals: DailyNutritionGoals = .unset

    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    // MARK: - Editor draft

    @Published var caloriesText = ""
    @Published var proteinText = ""
    @Published var carbsText = ""
    @Published var fatText = ""
    @Published var fiberText = ""

    /// Set when a save is refused, naming what is wrong. Cleared on the next
    /// successful save or when the editor is re-seeded.
    @Published private(set) var validationMessage: String?

    private let nutrition: NutritionService

    init(nutrition: NutritionService = .shared) {
        self.nutrition = nutrition
    }

    // MARK: - Loading

    func load() {
        if goals == .unset { isLoading = true }
        errorMessage = nil
        do {
            goals = try nutrition.goals()
        } catch {
            errorMessage = "error_loading_data".localized
        }
        isLoading = false
    }

    /// Copies the saved targets into the text fields.
    ///
    /// Called each time the editor opens rather than once, so a cancelled edit
    /// does not leave its values behind in the fields.
    func beginEditing() {
        validationMessage = nil
        caloriesText = NutritionGoalDraft.text(goals.calories)
        proteinText = NutritionGoalDraft.text(goals.protein)
        carbsText = NutritionGoalDraft.text(goals.carbs)
        fatText = NutritionGoalDraft.text(goals.fat)
        fiberText = NutritionGoalDraft.text(goals.fiber)
    }

    // MARK: - Saving

    /// Validates the draft and writes it. Returns whether anything was saved.
    ///
    /// All five fields are written together. A partial save — calories updated,
    /// carbs silently left at their old value — would leave the user looking at a
    /// form they filled in and a stored state that does not match it.
    @discardableResult
    func save() -> Bool {
        let result = NutritionGoalDraft.goals(
            calories: caloriesText,
            protein: proteinText,
            carbs: carbsText,
            fat: fatText,
            fiber: fiberText
        )

        guard let goals = result.goals else {
            // The whole sentence, punctuation included, comes from the string
            // table: a colon hard-coded here would be Chinese in English and
            // English in Chinese, and no reviewer would see it in a diff of the
            // .strings files.
            let names = result.invalid.map { $0.titleKey.localized }.joined(separator: ", ")
            validationMessage = "invalid_fields_named".localized(names)
            return false
        }

        do {
            try nutrition.setGoals(goals)
            self.goals = try nutrition.goals()
            validationMessage = nil
            errorMessage = nil
            return true
        } catch {
            errorMessage = "something_went_wrong".localized
            return false
        }
    }

    // MARK: - Display

    /// A saved goal with its unit, or `nil` when it is not set.
    func displayValue(_ value: Double?, component: NutritionGoalComponent) -> String? {
        guard let value, value > 0, value.isFinite else { return nil }
        let rounded = value.rounded()
        let text = rounded == value
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
        return "\(text) \(component.unit)"
    }

    var hasAnyGoal: Bool {
        goals != .unset
    }
}
