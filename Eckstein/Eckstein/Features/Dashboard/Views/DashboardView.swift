//
//  DashboardView.swift
//  Eckstein
//
//  The home screen: today's nutrition, today's training, body weight, and the
//  four things a user most often opens the app to do.
//
//  Nothing on this screen computes anything. Every number comes from
//  `DashboardViewModel`, which reads it from `NutritionService` and
//  `WeightMetrics` — the same types the Diet and Progress screens read. The view
//  decides layout and nothing else.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appCoordinator: AppCoordinator
    @StateObject private var viewModel: DashboardViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var showingAddWeight = false

    /// The view model is injectable so a preview can point the screen at an
    /// in-memory store. The default is the one the app builds.
    init(viewModel: DashboardViewModel = DashboardViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        themeManager.accentColor.color.opacity(0.1),
                        themeManager.accentColor.color.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        header

                        // The nutrition card owns its own loading and error state:
                        // it is the one card whose data is fetched, and a failure
                        // to fetch it must not take the rest of the screen down.
                        if viewModel.isLoading {
                            LoadingStateView()
                                .cardBackground()
                        } else if let errorMessage = viewModel.errorMessage {
                            ErrorStateView(message: errorMessage) {
                                Task { await viewModel.load() }
                            }
                            .cardBackground()
                        } else if let summary = viewModel.summary, let progress = viewModel.progress {
                            TodayNutritionCard(summary: summary, progress: progress)
                            MacroBreakdownCard(progress: progress)
                        }

                        TodayWorkoutCard(workouts: viewModel.todaysWorkouts) {
                            appCoordinator.selectedTab = .workout
                        }

                        BodyWeightCard(
                            viewModel: viewModel,
                            onLogWeight: { showingAddWeight = true },
                            onSeeTrends: { appCoordinator.selectedTab = .progress }
                        )

                        QuickActionsCard(
                            onLogFood: { appCoordinator.selectedTab = .diet },
                            onStartWorkout: { appCoordinator.selectedTab = .workout },
                            onLogWeight: { showingAddWeight = true },
                            onAskAI: { appCoordinator.selectedTab = .ai }
                        )
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("tab_home".localized)
            .navigationBarTitleDisplayMode(.large)
            .environment(\.layoutDirection, localizationManager.layoutDirection)
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
            .sheet(isPresented: $showingAddWeight) {
                // The existing weight entry sheet, reused rather than
                // reimplemented. It already validates, converts units and
                // exports to HealthKit.
                WeightEntryView {
                    Task { await viewModel.load() }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.greetingKey.localized)
                .font(.title2)
                .fontWeight(.bold)
            Text(viewModel.todayText)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Card chrome

extension View {
    /// The standard card surface: the system's grouped-list background, a
    /// rounded corner and no shadow.
    ///
    /// `Color(.secondarySystemGroupedBackground)` rather than a literal colour,
    /// so it inverts with Dark Mode on its own. A shadow was deliberately left
    /// off — a screen of eight cards each with one reads as a stack of stickers.
    func cardBackground() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
    }
}

/// Rendered against an in-memory store, so the sample meals and weigh-ins the
/// preview shows cannot reach the store on disk.
///
/// `#if DEBUG` because `PreviewSupport` is DEBUG-only: an unguarded preview
/// would not compile in a Release build.
#if DEBUG
#Preview {
    DashboardView(
        viewModel: DashboardViewModel(
            nutrition: PreviewSupport.nutritionService(),
            weightRepository: PreviewSupport.weightRepository()
        )
    )
    .environmentObject(AppCoordinator())
}
#endif
