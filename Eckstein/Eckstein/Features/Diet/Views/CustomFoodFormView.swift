//
//  CustomFoodFormView.swift
//  Eckstein
//
//  Entering a food that is not in the catalog.
//
//  Writes a real `CDEcksteinFood` through `NutritionService.upsertFood`, stamped
//  `manual`. It deliberately does not keep the food in view state: a food that
//  only exists inside one entry's editor cannot be found again, and the next
//  time the user eats it they would have to retype it.
//
//  Validation is `FoodDraft`'s, not this file's.
//

import SwiftUI

struct CustomFoodFormView: View {
    /// Called with the saved catalog row.
    let onCreate: (CDEcksteinFood) -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizationManager = LocalizationManager.shared

    @State private var draft = FoodDraft.Draft.empty
    @State private var nameIsMissing = false
    @State private var invalidFields: [String] = []
    @State private var errorMessage: String?

    private let nutrition = NutritionService.shared

    var body: some View {
        NavigationView {
            Form {
                Section {
                    field("custom_food_name", text: $draft.name, isMissing: nameIsMissing)
                        .accessibilityLabel("custom_food_name".localized)
                    field("diet_food_category", text: $draft.category)
                } footer: {
                    Text("custom_food_name_hint".localized)
                }

                Section {
                    amountField(.calories, text: $draft.calories)
                    amountField(.protein, text: $draft.protein)
                    amountField(.carbs, text: $draft.carbs)
                    amountField(.fat, text: $draft.fat)
                    amountField(.fiber, text: $draft.fiber)
                } header: {
                    Text("diet_per_100g".localized)
                } footer: {
                    Text("custom_food_macros_hint".localized)
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle("custom_food".localized)
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.layoutDirection, localizationManager.layoutDirection)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save".localized) { save() }
                        .fontWeight(.semibold)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Fields

    private func field(_ titleKey: String, text: Binding<String>, isMissing: Bool = false) -> some View {
        TextField(titleKey.localized, text: text)
            .foregroundColor(isMissing ? .orange : .primary)
    }

    /// One per-100 g amount. The unit is a unit, not a word: it is the same in
    /// every language.
    private func amountField(_ component: NutritionGoalComponent, text: Binding<String>) -> some View {
        HStack {
            Text(component.titleKey.localized)
            Spacer()
            TextField(component.unit, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
            Text(component.unit)
                .foregroundColor(.secondary)
                .frame(width: 36, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(component.titleKey.localized)
    }

    // MARK: - Saving

    private func save() {
        let result = FoodDraft.result(from: draft)

        nameIsMissing = result.nameIsMissing
        invalidFields = result.invalidFields

        guard let template = result.template else {
            errorMessage = validationMessage(for: result)
            return
        }

        do {
            let food = try nutrition.upsertFood(from: template, source: .manual)
            errorMessage = nil
            onCreate(food)
        } catch {
            errorMessage = "something_went_wrong".localized
        }
    }

    private func validationMessage(for result: FoodDraft.Result) -> String? {
        if result.nameIsMissing { return "custom_food_name_required".localized }

        let names = result.invalidFields.map { $0.localized }.joined(separator: ", ")
        return names.isEmpty ? "invalid_value".localized : "invalid_fields_named".localized(names)
    }
}
