//
//  ProfileBodyMetricsSection.swift
//  Eckstein
//
//  The Profile screen's height, BMI and fitness-goal rows.
//
//  Height is the input BMI needs and the app previously had no way to set from
//  Profile — the only editor was a settings screen two taps deep inside the
//  Weight tab, so a user who never found it saw "Add your height to see BMI"
//  with no clue where to add it. This puts the field where the BMI is.
//
//  The BMI number itself is not computed here. `WeightMetrics.bmi` owns the
//  formula and the plausibility range for the height, and `BMICategory` owns the
//  bands; a view that worked either out for itself would be a second opinion
//  about a number the user reads as a measurement.
//

import SwiftUI

struct ProfileBodyMetricsSection: View {
    @ObservedObject var themeManager: ThemeManager
    @ObservedObject var weightRepository: WeightRepository
    @ObservedObject private var localizationManager = LocalizationManager.shared

    @State private var heightText = ""
    @State private var heightIsInvalid = false
    @State private var fitnessGoal: FitnessGoal?
    @FocusState private var heightFieldIsFocused: Bool

    // MARK: - Derived

    /// Read through `WeightMetrics`, the one definition of "current weight", so
    /// this BMI and the Dashboard's cannot be computed from different weigh-ins.
    private var currentWeightKg: Double? {
        WeightMetrics.currentWeight(from: weightRepository.weightEntries)
    }

    private var bmi: Double? {
        WeightMetrics.bmi(weightKg: currentWeightKg, heightCm: BodyHeight.storedCentimetres)
    }

    private var bmiCategory: BMICategory? {
        WeightMetrics.bmiCategory(for: bmi)
    }

    // MARK: - Body

    var body: some View {
        Section {
            heightRow
            bmiRow
            fitnessGoalRow
        } header: {
            Text("body_metrics".localized)
                .textCase(nil)
        } footer: {
            Text("height_hint".localized)
        }
        .onAppear {
            weightRepository.refresh()
            seedFromStorage()
        }
        // The row labels are `String.localized` reads, which are not reactive on
        // their own; rebuilding on a language change is what makes the switcher
        // take effect without a relaunch.
        .id(localizationManager.currentLanguage)
    }

    // MARK: - Rows

    private var heightRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("height".localized, systemImage: "ruler")
                    .themedForegroundColor(themeManager.accentColor, context: .general)

                Spacer()

                TextField("height".localized, text: $heightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 80)
                    .focused($heightFieldIsFocused)
                    .accessibilityLabel("height".localized)

                // A unit, not a word: centimetres are centimetres in every
                // language, and translating the symbol is how a number changes
                // meaning between locales.
                Text("cm")
                    .foregroundColor(.secondary)
            }

            if heightIsInvalid {
                Text("height_invalid".localized)
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        // `decimalPad` has no return key, so the commit points are the ones the
        // user actually has: leaving the field, and leaving the screen.
        .onChange(of: heightFieldIsFocused) { _, isFocused in
            if !isFocused { commitHeight() }
        }
        .onDisappear { commitHeight() }
    }

    private var bmiRow: some View {
        HStack {
            Label("bmi".localized, systemImage: "figure.stand")
                .themedForegroundColor(themeManager.accentColor, context: .general)

            Spacer()

            if let text = WeightMetrics.formattedBMI(weightKg: currentWeightKg,
                                                     heightCm: BodyHeight.storedCentimetres) {
                Text(categoryText(bmi: text))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("bmi_no_height".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var fitnessGoalRow: some View {
        Picker(selection: $fitnessGoal) {
            Text("not_set".localized)
                .tag(FitnessGoal?.none)

            ForEach(FitnessGoal.allCases) { goal in
                Label(goal.titleKey.localized, systemImage: goal.icon)
                    .tag(FitnessGoal?.some(goal))
            }
        } label: {
            Label("fitness_goal".localized, systemImage: "flame")
                .themedForegroundColor(themeManager.accentColor, context: .general)
        }
        // Stored as the enum's raw value (`fatLoss`, `buildMuscle`), never as the
        // displayed text: the app must still recognise the goal after the user
        // switches language.
        .onChange(of: fitnessGoal) { _, newValue in
            FitnessGoal.store(newValue)
        }
    }

    // MARK: - Helpers

    private func categoryText(bmi text: String) -> String {
        guard let bmiCategory else { return text }
        return "\(text) · \(bmiCategory.titleKey.localized)"
    }

    private func seedFromStorage() {
        heightText = BodyHeight.text(BodyHeight.storedCentimetres)
        heightIsInvalid = false
        fitnessGoal = FitnessGoal.stored
    }

    /// Writes the typed height, or reports it as unusable.
    ///
    /// An emptied field clears the height rather than being an error: there is no
    /// way to express "I don't know my height" other than deleting it. An invalid
    /// entry is kept in the field and flagged, so the user can correct a typo
    /// instead of retyping from scratch.
    private func commitHeight() {
        let trimmed = heightText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            BodyHeight.store(nil)
            heightIsInvalid = false
            heightText = ""
            return
        }

        guard let centimetres = BodyHeight.parse(trimmed) else {
            heightIsInvalid = true
            return
        }

        BodyHeight.store(centimetres)
        heightIsInvalid = false
        heightText = BodyHeight.text(centimetres)
    }
}
