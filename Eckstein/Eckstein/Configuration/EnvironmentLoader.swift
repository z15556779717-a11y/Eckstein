//
//  EnvironmentLoader.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation

/// Reads the app's runtime configuration from every source that exists on each
/// platform, in increasing order of precedence:
///
/// 1. `Info.plist` — what the build shipped. This is the only source that
///    reaches a real device, and the one CI writes into (see
///    `.github/workflows/ios-release-check.yml`).
/// 2. A `.env` file — development only. Xcode launches the app with the working
///    directory set to the project, so a `.env` beside the sources is found on a
///    Mac; on a device there is no such file and this step finds nothing.
/// 3. Process environment variables — set by an Xcode scheme or a test host.
///    Highest precedence, so a developer can point a build at their own project
///    without editing anything tracked.
///
/// SECURITY: a `service_role` key must never be placed in any of these sources.
/// `AppEnvironment` refuses one if it appears anyway. The AI provider key is not
/// read here at all: it lives on the server, in the `ai-coach` Edge Function.
/// See `OpenAIService`.
class EnvironmentLoader {
    static let shared = EnvironmentLoader()

    private var config: [String: String] = [:]

    // MARK: - Key names

    static let supabaseURLKey = "SUPABASE_URL"

    /// The current name for the client-side key.
    ///
    /// Supabase renamed `anon` to `publishable`; `sb_publishable_…` is the value
    /// a client app is meant to carry. It is a public credential by design — the
    /// boundary that protects the data is row-level security, not this string.
    static let publishableKeyKey = "SUPABASE_PUBLISHABLE_KEY"

    /// The previous name for the same slot, still read so an existing `.env`
    /// keeps working. Never preferred over the current name.
    static let legacyAnonKeyKey = "SUPABASE_ANON_KEY"

    private static let supabaseKeys = [supabaseURLKey, publishableKeyKey, legacyAnonKeyKey]

    private init() {
        loadEnvironment()
    }

    // MARK: - Sources

    /// The values the build injected into its own `Info.plist`.
    ///
    /// Takes its bundle as a parameter so a test can read a bundle it built
    /// rather than depending on what the test host happens to ship with.
    static func infoPlistValues(in bundle: Bundle = .main) -> [String: String] {
        var values: [String: String] = [:]
        for key in supabaseKeys {
            guard let value = bundle.object(forInfoDictionaryKey: key) as? String else { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            // An unset CI variable arrives as an empty string rather than a
            // missing key; treating it as absent keeps an unconfigured build
            // unconfigured instead of half-configured.
            if !trimmed.isEmpty {
                values[key] = trimmed
            }
        }
        return values
    }

    private func loadDotEnvFile() {
        if let envPath = Bundle.main.path(forResource: ".env", ofType: nil) {
            print("EnvironmentLoader: Found .env in bundle at: \(envPath)")
            loadFromFile(at: envPath)
            return
        }

        print("EnvironmentLoader: No .env in bundle, checking file system...")
        let fileManager = FileManager.default

        let possiblePaths = [
            URL(fileURLWithPath: fileManager.currentDirectoryPath).appendingPathComponent(".env").path,
            URL(fileURLWithPath: fileManager.currentDirectoryPath)
                .deletingLastPathComponent()
                .appendingPathComponent(".env").path,
            URL(fileURLWithPath: fileManager.currentDirectoryPath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent(".env").path
        ]

        for path in possiblePaths {
            if fileManager.fileExists(atPath: path) {
                print("EnvironmentLoader: Found .env at: \(path)")
                loadFromFile(at: path)
                return
            }
        }

        print("EnvironmentLoader: No .env file found (this is normal on a device)")
    }

    private func loadProcessEnvironment() {
        print("EnvironmentLoader: Checking process environment variables...")
        for (key, value) in ProcessInfo.processInfo.environment {
            if key.hasPrefix("OPENAI") || key.hasPrefix("SUPABASE") {
                print("EnvironmentLoader: Found env var \(key)")
                config[key] = value
            }
        }
    }

    private func loadEnvironment() {
        print("EnvironmentLoader: Starting environment loading...")

        // Ordered so that each source overrides the one before it.
        config = Self.infoPlistValues()
        loadDotEnvFile()
        loadProcessEnvironment()

        // Log loaded configuration (names only, never values)
        print("EnvironmentLoader: Loaded configuration:")
        print("  - \(Self.supabaseURLKey): \(supabaseURL != nil ? "✓" : "✗")")
        print("  - \(Self.publishableKeyKey): \(supabasePublishableKey != nil ? "✓" : "✗")")
        print("  - \(Self.legacyAnonKeyKey): \(legacyAnonKey != nil ? "✓" : "✗")")
    }

    private func loadFromFile(at path: String) {
        do {
            let contents = try String(contentsOfFile: path, encoding: .utf8)
            let lines = contents.components(separatedBy: .newlines)

            print("EnvironmentLoader: Processing \(lines.count) lines from .env file")

            for line in lines {
                // Skip empty lines and comments
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                    continue
                }

                // Parse key=value pairs
                if let equalIndex = trimmedLine.firstIndex(of: "=") {
                    let key = String(trimmedLine[..<equalIndex]).trimmingCharacters(in: .whitespaces)
                    let value = String(trimmedLine[trimmedLine.index(after: equalIndex)...])
                        .trimmingCharacters(in: .whitespaces)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

                    if !key.isEmpty {
                        config[key] = value
                        if key.hasPrefix("OPENAI") || key.hasPrefix("SUPABASE") {
                            // SECURITY: the name only. This used to print the
                            // first ten characters of the value.
                            print("EnvironmentLoader: Loaded \(key)")
                        }
                    }
                }
            }

            print("EnvironmentLoader: Finished loading from file. Total keys: \(config.count)")
        } catch {
            print("EnvironmentLoader: Failed to load .env file: \(error)")
        }
    }

    // MARK: - Resolution

    /// The client key to use, given a merged configuration.
    ///
    /// Prefers the current name and falls back to the legacy one, so a `.env`
    /// written before the rename keeps working. The fallback is on the *value*,
    /// not the source: a shipped `SUPABASE_PUBLISHABLE_KEY` beats a developer's
    /// local `SUPABASE_ANON_KEY`, because the shipped one is what the project
    /// actually is.
    static func publishableKey(in config: [String: String]) -> String? {
        for key in [publishableKeyKey, legacyAnonKeyKey] {
            if let value = config[key], !value.isEmpty { return value }
        }
        return nil
    }

    static func resolvedURL(in config: [String: String]) -> String? {
        guard let value = config[supabaseURLKey], !value.isEmpty else { return nil }
        return value
    }

    /// True when a value must never be used as a client key.
    ///
    /// Both `sb_secret_…` and a `service_role` JWT bypass row-level security.
    /// A build that somehow carries one has to behave as unconfigured rather
    /// than hand it to the network layer. This catches the explicit forms; it
    /// is a backstop against a mistake, not a substitute for not making it.
    static func isSecretKey(_ value: String) -> Bool {
        let lowered = value.lowercased()
        return lowered.hasPrefix("sb_secret_") || lowered.contains("service_role")
    }

    /// True when a value is a stand-in rather than a real one.
    ///
    /// `$(...)` is the one that matters here: the shipped `Info.plist` holds
    /// `$(SUPABASE_URL)` and `$(SUPABASE_PUBLISHABLE_KEY)` and the build is
    /// supposed to expand them. A build that skipped the expansion would
    /// otherwise hand a literal build-setting reference to the network layer as
    /// though it were a real host, so the app has to read it as unconfigured.
    static func containsPlaceholder(_ value: String) -> Bool {
        value.contains("YOUR_") || value.contains("your-") || value.contains("$(")
    }

    func getValue(for key: String) -> String? {
        return config[key]
    }

    // MARK: - Convenience properties

    var supabaseURL: String? {
        Self.resolvedURL(in: config)
    }

    /// The client key, current name first.
    var supabasePublishableKey: String? {
        Self.publishableKey(in: config)
    }

    /// The value stored under the legacy name, if any. Reported separately so
    /// the startup log can say which name the build was configured with.
    var legacyAnonKey: String? {
        getValue(for: Self.legacyAnonKeyKey)
    }
}
