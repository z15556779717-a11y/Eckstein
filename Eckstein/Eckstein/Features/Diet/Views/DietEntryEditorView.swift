//
//  DietEntryEditorView.swift
//  Eckstein
//
//  Adding or editing one logged food.
//
//  The same sheet serves both, because the operations are the same: choose a
//  food, choose an amount, see what it comes to. Only the title and the save
//  call differ.
//
//  The live preview is not a convenience. Before it, the only way to find out
//  what 250 g of something was worth was to log it and read the day's total,
//  which meant a mistake cost a deletion. It is computed by
//  `DietDayViewModel.previewSnapshot` — the same resolution the write uses — so
//  the preview and the stored value cannot disagree.
//

import SwiftUI

struct DietEntryEditorView: View {
    /// The entry being edited, or `nil` when adding.
    let entry: CDEcksteinMealEntry?
    /// The slot a new entry goes into, and the starting slot when editing.
    let slot: MealType
    @ObservedObject var viewModel: DietDayViewModel

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizationManager = LocalizationManager.shared

    @State private var selectedFood: CDEcksteinFood?
    @State private var selectedSlot: MealType
    @State private var gramsText: String
    @State private var showingFoodPicker = false
    @State private var errorMessage: String?

    init(entry: CDEcksteinMealEntry?, slot: MealType, viewModel: DietDayViewModel) {
        self.entry = entry
        self.slot = slot
        self.viewModel = viewModel
        _selectedFood = State(initialValue: entry?.food)
        _selectedSlot = State(initialValue: MealType(storedValue: entry?.meal?.mealType))
        _gramsText = State(initialValue: entry.map { String(Int($0.gramsConsumed)) } ?? "")
    }

    // MARK: - Derived

    private var isEditing: Bool { entry != nil }

    /// The name to show and to log. A legacy entry with no catalog row still has
    /// a name, and it must not be lost by opening the editor.
    ///
    /// This is the stored name and it stays English: it is what the entry is
    /// filed under and what the sync payload keys on. `displayFoodName` is the
    /// copy that reaches the screen.
    private var foodName: String {
        selectedFood?.name ?? entry?.foodName ?? ""
    }

    /// The name as shown. See `SeedFoodNames` for why the two differ.
    private var displayFoodName: String {
        if let selectedFood { return selectedFood.displayName }
        return entry?.displayFoodName ?? ""
    }

    private var grams: Double? {
        guard case .value(let grams) = FoodDraft.parseGrams(gramsText) else { return nil }
        return grams
    }

    private var preview: NutritionSnapshot? {
        guard let grams else { return nil }
        return viewModel.previewSnapshot(
            food: selectedFood,
            foodName: foodName,
            category: selectedFood?.category ?? entry?.category,
            grams: grams
        )
    }

    private var canSave: Bool {
        !foodName.isEmpty && grams != nil
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            Form {
                foodSection
                amountSection
                slotSection

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle((isEditing ? "diet_edit_entry" : "diet_add_food").localized)
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.layoutDirection, localizationManager.layoutDirection)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save".localized) { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showingFoodPicker) {
                FoodPickerSheet { food in
                    selectedFood = food
                    // A food picked from the catalog gets a sensible starting
                    // amount only if the field is still empty — retyping over an
                    // amount the user already chose would be worse than useless.
                    if gramsText.trimmingCharacters(in: .whitespaces).isEmpty,
                       let serving = food.servingSize?.doubleValue, serving > 0 {
                        gramsText = String(Int(serving.rounded()))
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Sections

    private var foodSection: some View {
        Section {
            Button {
                showingFoodPicker = true
            } label: {
                HStack {
                    Text(displayFoodName.isEmpty ? "diet_select_food".localized : displayFoodName)
                        .foregroundColor(displayFoodName.isEmpty ? .secondary : .primary)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityElement(children: .combine)

            if let per100g = viewModel.per100gText(for: selectedFood) {
                Text(per100g)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("diet_entry_food".localized)
        }
    }

    private var amountSection: some View {
        Section {
            HStack {
                Text("diet_entry_amount".localized)
                Spacer()
                TextField("0", text: $gramsText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 90)
                Text("g")
                    .foregroundColor(.secondary)
                    .frame(width: 20, alignment: .leading)
            }
            .accessibilityElement(children: .combine)

            if !gramsText.isEmpty, grams == nil {
                Text("invalid_value".localized)
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            if let preview {
                previewRows(preview)
            } else if grams != nil {
                // grams is valid but nothing is known about this food, so the
                // honest answer is that the totals are unknown — not zero.
                Text("diet_nutrition_unknown".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("diet_entry_amount".localized)
        }
    }

    private var slotSection: some View {
        Section {
            Picker("diet_entry_meal".localized, selection: $selectedSlot) {
                ForEach(slotsForPicker, id: \.self) { slot in
                    Text(slot.localizedName).tag(slot)
                }
            }
        } footer: {
            Text("diet_slot_change_hint".localized)
        }
    }

    /// The four slots, plus `.unspecified` only when it is what the entry is
    /// already filed under — it is a bucket for unrecorded data, not a choice.
    private var slotsForPicker: [MealType] {
        var slots = MealType.selectableCases
        if selectedSlot == .unspecified { slots.append(.unspecified) }
        return slots
    }

    /// The live preview: the same five figures the day's card shows.
    private func previewRows(_ snapshot: NutritionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let calories = NutrientFormat.calories(snapshot.calories) {
                HStack {
                    Text("calories".localized)
                    Spacer()
                    Text("\(calories) kcal")
                        .foregroundColor(.secondary)
                }
            }

            // One line per macro, so the row's identity is the nutrient it
            // describes rather than its position in the list.
            ForEach(macroLines(of: snapshot)) { line in
                HStack {
                    Text(line.titleKey.localized)
                    Spacer()
                    Text("\(NutrientFormat.grams(line.grams) ?? "0") g")
                        .foregroundColor(.secondary)
                }
            }
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }

    private struct MacroLine: Identifiable {
        let titleKey: String
        let grams: Double
        var id: String { titleKey }
    }

    private func macroLines(of snapshot: NutritionSnapshot) -> [MacroLine] {
        [
            MacroLine(titleKey: "protein", grams: snapshot.protein),
            MacroLine(titleKey: "carbs", grams: snapshot.carbs),
            MacroLine(titleKey: "fat", grams: snapshot.fat),
            MacroLine(titleKey: "fiber", grams: snapshot.fiber)
        ]
    }

    // MARK: - Saving

    private func save() {
        guard let grams else { return }

        do {
            if let entry {
                try viewModel.save(entry, food: selectedFood, grams: grams, slot: selectedSlot)
            } else if let selectedFood {
                try viewModel.add(food: selectedFood, grams: grams, to: selectedSlot)
            } else {
                // Nothing chosen yet; the save button is disabled in this state,
                // so this is unreachable rather than an error the user can hit.
                return
            }
            errorMessage = nil
            dismiss()
        } catch {
            errorMessage = "something_went_wrong".localized
        }
    }
}
