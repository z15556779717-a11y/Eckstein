//
//  WorkoutTabView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

struct WorkoutTabView: View {
    @StateObject private var viewModel = WorkoutViewModel()
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [themeManager.accentColor.color.opacity(0.1), themeManager.accentColor.color.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                WorkoutListView(viewModel: viewModel)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}