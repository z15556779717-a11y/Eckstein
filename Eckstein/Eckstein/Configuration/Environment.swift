//
//  Environment.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation

enum AppEnvironment {
    // MARK: - Supabase

    /// Supabase project URL.
    ///
    /// SECURITY: the hardcoded project URL fallback and the `URL(string:)!`
    /// force-unwrap were both removed in the phase-1 audit — a malformed
    /// `SUPABASE_URL` used to crash on launch. Configure via `.env`
    /// (see `EnvironmentLoader`). When unconfigured this returns a harmless
    /// placeholder; gate network work on `isSupabaseConfigured`.
    static var supabaseURL: URL {
        guard let urlString = EnvironmentLoader.shared.supabaseURL,
              !urlString.isEmpty,
              let url = URL(string: urlString) else {
            return URL(string: "about:blank")!
        }
        return url
    }

    /// Supabase anon/publishable key — a *public* credential by design.
    ///
    /// SECURITY: the hardcoded literal fallback was removed in the phase-1
    /// audit. A `service_role` key must never appear here; see `AUDIT.md`.
    static var supabaseAnonKey: String {
        EnvironmentLoader.shared.supabaseAnonKey ?? ""
    }

    // MARK: - OpenAI

    static var openAIKey: String? {
        guard let key = EnvironmentLoader.shared.openAIKey, !key.isEmpty else {
            return nil
        }
        return key
    }

    // Use Xcode configuration files in production
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    // MARK: - Validation

    /// True when Supabase is usable on its own.
    ///
    /// Sync gates on this rather than `isConfigured`: previously a missing
    /// OpenAI key silently disabled Supabase sync as well.
    static var isSupabaseConfigured: Bool {
        guard let url = EnvironmentLoader.shared.supabaseURL, !url.isEmpty,
              let key = EnvironmentLoader.shared.supabaseAnonKey, !key.isEmpty else {
            return false
        }
        return !containsPlaceholder(url) && !containsPlaceholder(key)
    }

    /// True when the AI coach has a usable key.
    static var isOpenAIConfigured: Bool {
        guard let key = openAIKey else { return false }
        return !containsPlaceholder(key)
    }

    /// True when every optional backend integration is configured.
    static var isConfigured: Bool {
        isSupabaseConfigured && isOpenAIConfigured
    }

    private static func containsPlaceholder(_ value: String) -> Bool {
        value.contains("YOUR_") || value.contains("your-")
    }
}
