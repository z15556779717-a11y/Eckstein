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
        // A `NavigationStack`, not a `NavigationView`: the tab pushes a workout
        // from code as well as from a link (`WorkoutListView`'s
        // `navigationDestination`), and that is only supported on the stack.
        // `navigationViewStyle` went with it — it is a `NavigationView` modifier.
        // The `NavigationLink(destination:)` children are unaffected.
        NavigationStack {
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
    }
}
