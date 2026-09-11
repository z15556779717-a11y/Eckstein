//
//  DietDayView.swift
//  Eckstein
//
//  The food log: one day, four meal slots, and the day's totals.
//
//  Everything on screen is read from `DietDayViewModel`, which reads
//  `NutritionService`. No fetch, no sum and no `NSFetchRequest` happens in this
//  file — the only Core Data objects it touches are the entries the view model
//  already fetched, and they are only passed back to it.
//

import SwiftUI

struct DietDayView: View {
    @StateObject private var viewModel = DietDayViewModel()
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared

    /// The sheet's subject: adding to a slot, or editing one entry.
    @State private var editorTarget: EditorTarget?
    @State private var entryToDelete: CDEcksteinMealEntry?
    @State private var showingDeleteConfirmation = false

    private enum EditorTarget: Identifiable {
        case add(MealType)
        case edit(CDEcksteinMealEntry)

        var id: String {
            switch self {
            case .add(let slot):
                return "add-\(slot.rawValue)"
            case .edit(let entry):
                // `objectID` is stable for the lifetime of the row, so the sheet
                // is not torn down and rebuilt while the user types.
                return "edit-\(entry.objectID.uriRepresentation().absoluteString)"
            }
        }
    }

    private var accent: Color {
        themeManager.accentColor == .defaultMix
            ? themeManager.accentColor.contextColor(for: .diet)
            : themeManager.accentColor.color
    }

    /// The four slots, plus the unrecorded bucket when it has anything in it.
    ///
    /// `.unspecified` is shown rather than hidden: entries logged before slots
    /// existed live there, and a section that disappears would make them
    /// unreachable rather than merely unsorted.
    private var slots: [MealType] {
        var slots = MealType.selectableCases
        if !viewModel.entries(for: .unspecified).isEmpty {
            slots.append(.unspecified)
        }
        return slots
    }

    var body: some View {
        List {
            dateSection
            summarySection
            mealSections
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("tab_diet".localized)
        .navigationBarTitleDisplayMode(.large)
        .environment(\.layoutDirection, localizationManager.layoutDirection)
        .task { viewModel.load() }
        .refreshable { viewModel.load() }
        .sheet(item: $editorTarget) { target in
            switch target {
            case .add(let slot):
                DietEntryEditorView(entry: nil, slot: slot, viewModel: viewModel)
            case .edit(let entry):
                DietEntryEditorView(
                    entry: entry,
                    slot: MealType(storedValue: entry.meal?.mealType),
                    viewModel: viewModel
                )
            }
        }
        .confirmationDialog(
            "diet_delete_entry_title".localized,
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible,
            presenting: entryToDelete
        ) { entry in
            Button("delete".localized, role: .destructive) {
                delete(entry)
            }
            Button("cancel".localized, role: .cancel) { }
        } message: { _ in
            Text("diet_delete_entry_message".localized)
        }
    }

    // MARK: - Sections

    private var dateSection: some View {
        Section {
            HStack {
                Button {
                    viewModel.selectPreviousDay()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("previous_day".localized)

                Spacer()

                VStack(spacing: 2) {
                    Text(viewModel.titleText)
                        .font(.headline)

                    if !viewModel.isToday {
                        Button("today".localized) { viewModel.selectToday() }
                            .font(.caption)
                    }
                }

                Spacer()

                Button {
                    viewModel.selectNextDay()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canGoToNextDay)
                .accessibilityLabel("next_day".localized)
            }
            .foregroundColor(accent)
        }
    }

    @ViewBuilder
    private var summarySection: some View {
        Section {
            if viewModel.isLoading {
                LoadingStateView()
            } else if let errorMessage = viewModel.errorMessage {
                // The sections below still render, so the user can see (and go on
                // editing) whatever the store did return.
                InlineErrorLabel(message: errorMessage)
            }

            daySummary
        }
    }

    private var daySummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 20) {
                CalorieRing(
                    consumed: viewModel.progress.calories.current,
                    target: viewModel.progress.calories.target,
                    fill: viewModel.progress.calories.displayProgress,
                    color: viewModel.progress.calories.isOverTarget ? .orange : accent
                )

                VStack(alignment: .leading, spacing: 6) {
                    if let target = NutrientFormat.calories(viewModel.progress.calories.target) {
                        Text("\(NutrientFormat.calories(viewModel.progress.calories.current) ?? "0") / \(target) kcal")
                            .font(.title3)
                            .fontWeight(.semibold)
                    } else {
                        Text("\(NutrientFormat.calories(viewModel.progress.calories.current) ?? "0") kcal")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("dashboard_no_goal_set".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    if let caption = calorieCaption {
                        Text(caption)
                            .font(.subheadline)
                            .foregroundColor(viewModel.progress.calories.isOverTarget ? .orange : .secondary)
                    }
                }

                Spacer(minLength: 0)
            }

            Divider()

            MacroProgressList(progress: viewModel.progress)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }

    /// "超出 250 kcal" / "剩余 1800 kcal", from the **unclamped** remaining.
    private var calorieCaption: String? {
        guard let remaining = viewModel.progress.calories.remaining,
              let magnitude = NutrientFormat.calorieMagnitude(remaining) else {
            return nil
        }
        return remaining < 0
            ? "dashboard_over_by".localized(magnitude)
            : "dashboard_left_today".localized(magnitude)
    }

    @ViewBuilder
    private var mealSections: some View {
        ForEach(slots, id: \.self) { slot in
            Section {
                let entries = viewModel.entries(for: slot)

                if entries.isEmpty {
                    Text("diet_no_entries_for_meal".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(entries, id: \.objectID) { entry in
                        Button {
                            editorTarget = .edit(entry)
                        } label: {
                            DietEntryRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                requestDeletion(of: entry)
                            } label: {
                                Label("delete".localized, systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                editorTarget = .edit(entry)
                            } label: {
                                Label("edit".localized, systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
            } header: {
                MealSlotHeader(
                    slot: slot,
                    totals: viewModel.totals(for: slot),
                    onAdd: { editorTarget = .add(slot) }
                )
            }
        }
    }

    // MARK: - Actions

    /// Deletion is confirmed, never immediate. `allowsFullSwipe: false` on the
    /// swipe action is the other half of that: a swipe that goes too far must not
    /// be able to skip the dialog.
    private func requestDeletion(of entry: CDEcksteinMealEntry) {
        entryToDelete = entry
        showingDeleteConfirmation = true
    }

    private func delete(_ entry: CDEcksteinMealEntry) {
        // A failed delete leaves the row on screen, which is the honest outcome:
        // the store still has it, so the totals still count it.
        try? viewModel.delete(entry)
        entryToDelete = nil
    }
}

// MARK: - Injection

extension DietDayView {
    /// Lets a preview point the screen at an in-memory store.
    ///
    /// Declared in an extension, and with its own argument label.
    ///
    /// In an extension because an initialiser written in the struct's own body
    /// would suppress the memberwise initialiser — the one the Diet tab builds
    /// this view with — and the memberwise initialiser has to stay, because a
    /// default argument is emitted into a synthesised *nonisolated* generator:
    /// `init(viewModel: DietDayViewModel = DietDayViewModel())` does not
    /// compile, since the default reads as a call to a main-actor initialiser
    /// from a synchronous nonisolated context. Writing the property's default
    /// instead works because `StateObject` takes it as an autoclosure, so the
    /// view model is not built until the body first reads it.
    ///
    /// The label is `previewing` rather than `viewModel` so this cannot be
    /// confused with the memberwise initialiser's own `viewModel` parameter,
    /// which a call with a single argument would otherwise also match.
    init(previewing viewModel: DietDayViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
}

/// Rendered against an in-memory store, so the sample meals the preview shows
/// cannot reach the store on disk.
///
/// `#if DEBUG` because `PreviewSupport` is DEBUG-only: an unguarded preview
/// would not compile in a Release build.
#if DEBUG
#Preview {
    NavigationView {
        DietDayView(previewing: DietDayViewModel(nutrition: PreviewSupport.nutritionService()))
    }
}
#endif
