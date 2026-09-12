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
    ///
    /// The placeholder must be a well-formed URL *with a host*: `SupabaseClient`
    /// calls `fatalError` when `supabaseURL.host` is nil, and an earlier
    /// `about:blank` placeholder took the whole app down on launch (and the unit
    /// test host with it). `.invalid` is reserved by RFC 2606 and never resolves,
    /// so a stray request fails as a network error instead of crashing.
    static var supabaseURL: URL {
        guard let urlString = EnvironmentLoader.shared.supabaseURL,
              !urlString.isEmpty,
              let url = URL(string: urlString),
              url.host != nil else {
            return URL(string: "https://unconfigured.invalid")!
        }
        return url
    }

    /// The Supabase client key — a *public* credential by design.
    ///
    /// Reads `SUPABASE_PUBLISHABLE_KEY`, falling back to the legacy
    /// `SUPABASE_ANON_KEY` so an existing `.env` keeps working. Both names hold
    /// the same kind of value; Supabase renamed `anon` to `publishable`, and
    /// `sb_publishable_…` is what a client app is meant to carry now.
    ///
    /// SECURITY: the hardcoded literal fallback was removed in the phase-1
    /// audit. A `service_role` key must never appear here; see `AUDIT.md`. A
    /// value that looks like one is refused below rather than returned.
    static var supabasePublishableKey: String {
        guard let key = EnvironmentLoader.shared.supabasePublishableKey,
              !EnvironmentLoader.isSecretKey(key) else {
            return ""
        }
        return key
    }

    /// The previous name for `supabasePublishableKey`, kept so existing call
    /// sites read as they did. There is one key and one source of it.
    static var supabaseAnonKey: String {
        supabasePublishableKey
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
    ///
    /// A key that looks like a secret counts as unconfigured. Refusing it here
    /// means every caller — sync, auth, the AI coach — is gated off at once,
    /// rather than each having to remember not to use it.
    static var isSupabaseConfigured: Bool {
        guard let url = EnvironmentLoader.shared.supabaseURL, !url.isEmpty else {
            return false
        }
        let key = supabasePublishableKey
        guard !key.isEmpty else { return false }
        return !EnvironmentLoader.containsPlaceholder(url)
            && !EnvironmentLoader.containsPlaceholder(key)
    }
}
