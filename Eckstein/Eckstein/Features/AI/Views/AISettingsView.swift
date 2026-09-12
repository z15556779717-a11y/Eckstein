//
//  AISettingsView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

/// Read-only status for the AI coach backend.
///
/// This screen used to be a credential form: an "OpenAI Configuration" section
/// holding a `SecureField`, a Show / Save / Remove key control set, and
/// instructions for obtaining a key from `platform.openai.com`. None of that
/// described the system. There is no key for a client to hold — the provider
/// credential lives in the Supabase Edge Function and cannot be read, written,
/// or removed from here — so the form, the storage behind it, and the
/// instructions are all gone.
///
/// What is left is what a user can act on: whether the service is reachable,
/// what it is made of, and how much has been used.
struct AISettingsView: View {
    @ObservedObject private var openAIService = OpenAIService.shared
    @ObservedObject private var authService = AuthService.shared
    @Environment(\.dismiss) private var dismiss

    /// Whether the coach can be called at all: a build with a usable Supabase
    /// project, and a session to authenticate the call with.
    private var isConfigured: Bool {
        AppEnvironment.isSupabaseConfigured && authService.isAuthenticated
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text("ai_settings_service_row".localized)
                        Spacer()
                        if isConfigured {
                            Label("ai_settings_configured".localized, systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        } else {
                            Label("ai_settings_not_available".localized, systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("ai_settings_status_header".localized)
                } footer: {
                    if !isConfigured {
                        // The same two sentences the chat uses, so the reason
                        // is worded once.
                        Text(AppEnvironment.isSupabaseConfigured
                             ? "ai_error_sign_in".localized
                             : "ai_error_unavailable".localized)
                            .font(.caption)
                    }
                }

                Section {
                    HStack {
                        Text("ai_settings_provider".localized)
                        Spacer()
                        Text("Qwen")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("ai_settings_backend".localized)
                        Spacer()
                        Text("Supabase Edge Function")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("ai_settings_service_header".localized)
                } footer: {
                    Text("ai_settings_key_footer".localized)
                        .font(.caption)
                }

                if openAIService.totalTokensUsed > 0 {
                    Section {
                        HStack {
                            Text("ai_settings_total_tokens".localized)
                            Spacer()
                            Text("\(openAIService.totalTokensUsed)")
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("ai_settings_usage_header".localized)
                    }
                }
            }
            .navigationTitle("ai_settings_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    AISettingsView()
}
