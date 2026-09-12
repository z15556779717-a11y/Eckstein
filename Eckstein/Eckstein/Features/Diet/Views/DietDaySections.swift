//
//  DietDaySections.swift
//  Eckstein
//
//  The pieces of the day's log: a slot's header and one logged food.
//

import SwiftUI

/// A meal slot's header: its name, what it came to, and a way to add to it.
struct MealSlotHeader: View {
    let slot: MealType
    let totals: NutritionSnapshot
    let onAdd: () -> Void

    @ObservedObject private var themeManager = ThemeManager.shared

    private var accent: Color {
        themeManager.accentColor == .defaultMix
            ? themeManager.accentColor.contextColor(for: .diet)
            : themeManager.accentColor.color
    }

    var body: some View {
        HStack {
            Text(slot.localizedName)
                .textCase(nil)

            Spacer()

            if let calories = NutrientFormat.calories(totals.calories) {
                Text("\(calories) kcal")
                    .textCase(nil)
                    .foregroundColor(.secondary)
            }

            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.body)
            }
            .buttonStyle(.plain)
            .foregroundColor(accent)
            // The header already says which slot this adds to, but VoiceOver
            // reads the whole element, so the label repeats it deliberately:
            // "Breakfast" alone would be ambiguous out of context.
            .accessibilityLabel("\(("diet_add_food".localized)) · \(slot.localizedName)")
        }
    }
}

/// One logged food.
struct DietEntryRow: View {
    let entry: CDEcksteinMealEntry

    private var foodName: String {
        // `displayFoodName` rather than `foodName`: the stored name is the
        // English one the row was logged under, and is what the entry is
        // identified by. See `SeedFoodNames`.
        let name = entry.displayFoodName
        return name.isEmpty ? "diet_unknown_food".localized : name
    }

    private var amountText: String {
        guard entry.gramsConsumed > 0 else { return "" }
        return "\(entry.gramsConsumed) g"
    }

    /// The entry's own calories, or `nil` when the amount is recorded but its
    /// nutrition is not — which is shown as nothing rather than as "0 kcal".
    private var calorieText: String? {
        guard let calories = entry.calories?.doubleValue else { return nil }
        guard let text = NutrientFormat.calories(calories) else { return nil }
        return "\(text) kcal"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(foodName)
                .font(.body)

            HStack(spacing: 6) {
                if !amountText.isEmpty {
                    Text(amountText)
                }
                if let calorieText {
                    if !amountText.isEmpty { Text("·") }
                    Text(calorieText)
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
