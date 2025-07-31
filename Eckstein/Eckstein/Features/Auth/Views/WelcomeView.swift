//
//  WelcomeView.swift
//  Eckstein
//
//  Created by Assistant on 15/01/2025.
//

import SwiftUI

struct WelcomeView: View {
    let isNewUser: Bool
    let userId: String?
    let onComplete: () -> Void
    
    var body: some View {
        AppUsageGuideView(userId: userId, onComplete: onComplete)
    }
}

#Preview {
    WelcomeView(isNewUser: true, userId: "preview-user") {
        print("Welcome completed")
    }
}