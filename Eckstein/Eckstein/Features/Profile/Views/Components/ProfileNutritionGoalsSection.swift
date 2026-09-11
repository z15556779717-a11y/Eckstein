//
//  ProfileNutritionGoalsSection.swift
//  Eckstein
//
//  The Profile screen's daily targets, and the editor for them.
//
//  This is the first production caller of `NutritionService.setGoals(_:)` — the
//  write path has existed since phase 3 but nothing reached it, so the targets
//  the Dashboard and the AI Coach read against could not previously be set
//  anywhere in the app.
//

import SwiftUI

struct ProfileNutritionGoalsSection: View {
    @ObservedObject var themeManager: ThemeManager
    @StateObject private var viewModel = NutritionGoalsViewModel()
    @State private var showingEditor = false
    @ObservedObject private var localizationManager = LocalizationManager.shared

    var body: some View {
        Section {
            if viewModel.isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("loading".localized)
                        .foregroundColor(.secondary)
                }
            } else if let errorMessage = viewModel.errorMessage {
                InlineErrorLabel(message: errorMessage)
            } else {
                ForEach(NutritionGoalComponent.allCases, id: \.self) { component in
                    row(for: component)
                }
            }

            Button {
                viewModel.beginEditing()
                showingEditor = true
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                    Text(viewModel.hasAnyGoal ? "update_goal".localized : "set_goal".localized)
                }
                .themedForegroundColor(themeManager.accentColor)
            }
        } header: {
            Text("nutrition_goals".localized)
                .textCase(nil)
        }
        .onAppear { viewModel.load() }
        .sheet(isPresented: $showingEditor) {
            NutritionGoalsEditorView(viewModel: viewModel)
        }
        // The section's labels are `String.localized` reads, which are not
        // reactive on their own; re-rendering on a language change is what makes
        // the switches take effect without a relaunch.
        .id(localizationManager.currentLanguage)
    }

    @ViewBuilder
    private func row(for component: NutritionGoalComponent) -> some View {
        HStack {
            Text(component.titleKey.localized)
                .themedForegroundColor(themeManager.accentColor, context: .diet)

            Spacer()

            if let text = viewModel.displayValue(value(for: component), component: component) {
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                // Distinct from a target of zero, and the reason the model keeps
                // the two apart.
                Text("dashboard_no_goal_set".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func value(for component: NutritionGoalComponent) -> Double? {
        switch component {
        case .calories: return viewModel.goals.calories
        case .protein: return viewModel.goals.protein
        case .carbs: return viewModel.goals.carbs
        case .fat: return viewModel.goals.fat
        case .fiber: return viewModel.goals.fiber
        }
    }
}

// MARK: - Editor

struct NutritionGoalsEditorView: View {
    @ObservedObject var viewModel: NutritionGoalsViewModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizationManager = LocalizationManager.shared

    var body: some View {
        NavigationView {
            Form {
                Section {
                    field(.calories, text: $viewModel.caloriesText)
                    field(.protein, text: $viewModel.proteinText)
                    field(.carbs, text: $viewModel.carbsText)
                    field(.fat, text: $viewModel.fatText)
                    field(.fiber, text: $viewModel.fiberText)
                } footer: {
                    Text("goals_clear_hint".localized)
                }

                if let validationMessage = viewModel.validationMessage {
                    Section {
                        Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle("nutrition_goals".localized)
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.layoutDirection, localizationManager.layoutDirection)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save".localized) {
                        if viewModel.save() {
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func field(_ component: NutritionGoalComponent, text: Binding<String>) -> some View {
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
}
