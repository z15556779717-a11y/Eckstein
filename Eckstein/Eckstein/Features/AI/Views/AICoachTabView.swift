//
//  AICoachTabView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

/// The AI Coach tab.
///
/// What decides whether this screen is usable is the question "could a request
/// succeed", not "has a key been entered". There is no key on this device to
/// enter: the provider credential lives in the Supabase Edge Function. So the
/// gate is the two preconditions that function actually needs — a build with a
/// usable Supabase project, and somebody signed in — and everything else is the
/// answer to a real message.
///
/// The gate used to read a locally stored `openai_api_key` string, which nothing
/// ever set on a device, so the tab was permanently replaced by an "API Key
/// Required" screen pointing at `platform.openai.com`. That screen is gone.
struct AICoachTabView: View {
    @StateObject private var viewModel = AICoachViewModel()
    @ObservedObject private var authService = AuthService.shared
    @State private var showingSettings = false
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

                Group {
                    if !AppEnvironment.isSupabaseConfigured {
                        // This build has no project URL or key, so there is
                        // nothing to call. Reported before a request is made
                        // rather than as a failed one.
                        unavailable(
                            icon: "antenna.radiowaves.left.and.right.slash",
                            message: "ai_error_unavailable".localized
                        )
                    } else if !authService.isAuthenticated {
                        // The session is the credential the Edge Function
                        // authenticates. Without one the call would be rejected,
                        // so say why here instead.
                        unavailable(
                            icon: "person.crop.circle.badge.exclamationmark",
                            message: "ai_error_sign_in".localized
                        )
                    } else {
                        AIChatView(viewModel: viewModel)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .checkAIDisclaimer()
        .sheet(isPresented: $showingSettings) {
            AISettingsView()
        }
    }

    /// Shown when the coach cannot be reached for a reason the app can see
    /// before sending anything. Failures that only the backend can report are
    /// left to the chat, where they arrive as an answer.
    private func unavailable(icon: String, message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .padding()
        .navigationTitle("tab_ai_coach".localized)
    }
}
