//
//  WeightTabView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

struct WeightTabView: View {
    @StateObject private var viewModel = WeightViewModel()
    @State private var showingAddEntry = false
    @State private var selectedTab = 0
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [themeManager.accentColor.color.opacity(0.1), themeManager.accentColor.color.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Tab Selector
                    WeightTabSelector(selectedTab: $selectedTab)
                    
                    // Tab Content
                    TabView(selection: $selectedTab) {
                        // Dashboard Tab
                        WeightDashboardView(viewModel: viewModel)
                            .tag(0)
                        
                        // History Tab
                        WeightHistoryView(viewModel: viewModel)
                            .tag(1)
                        
                        // Progress Tab
                        WeightChartView(viewModel: viewModel)
                            .tag(2)
                        
                        // Analytics Tab
                        WeightAnalyticsView(viewModel: viewModel)
                            .tag(3)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                }
            }
            .navigationTitle("weight_tracking".localized)
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    WeightSettingsButton()
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddEntry = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(themeManager.accentColor == .defaultMix ? 
                                           themeManager.accentColor.contextColor(for: .weight) : 
                                           themeManager.accentColor.color)
                    }
                }
            }
            .sheet(isPresented: $showingAddEntry) {
                WeightEntryView {
                    viewModel.refresh()
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct WeightTabSelector: View {
    @Binding var selectedTab: Int
    
    private var tabs: [String] {
        ["dashboard".localized, "history".localized, "progress".localized, "analytics".localized]
    }
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = index
                    }
                }) {
                    VStack(spacing: 8) {
                        Text(tabs[index])
                            .font(.subheadline)
                            .fontWeight(selectedTab == index ? .semibold : .regular)
                            .foregroundColor(selectedTab == index ? .primary : .secondary)
                        
                        Rectangle()
                            .fill(selectedTab == index ? (themeManager.accentColor == .defaultMix ? 
                                                       themeManager.accentColor.contextColor(for: .weight) : 
                                                       themeManager.accentColor.color) : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
    }
}