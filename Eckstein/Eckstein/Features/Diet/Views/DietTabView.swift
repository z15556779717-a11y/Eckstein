//
//  DietTabView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//
//  Reworked in phase 4 around `DietDayView`. The tab is a container: it owns the
//  navigation stack and nothing else.
//
//  The accent gradient that used to sit behind the content is gone. A grouped
//  `List` paints its own background over it, so the only thing the gradient
//  still reached was the strip behind the navigation bar — where it read as a
//  rendering artefact rather than as a theme.
//

import SwiftUI

struct DietTabView: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared

    var body: some View {
        NavigationView {
            DietDayView()
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .environment(\.layoutDirection, localizationManager.layoutDirection)
    }
}
