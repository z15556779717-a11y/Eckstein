//
//  String+Localization.swift
//  Eckstein
//
//  Created by Eliad Shahar on 23/07/2025.
//

import Foundation
import SwiftUI

extension String {
    /// The tables `localized` searches, in order, ending with the default
    /// `Localizable.strings` (the `nil` entry). Kept in one place so the several
    /// lookups below cannot drift apart.
    private static let localizationTables: [String?] = [
        "Workout", "Diet", "Weight", "Profile", "Auth", "Common", nil
    ]

    /// Returns the localized version of the string
    var localized: String {
        let (primary, fallback) = Self.localizationBundles()
        if let hit = lookup(in: primary) { return hit }
        if let fallback, let hit = lookup(in: fallback) { return hit }

        // If no translation found, return the key itself
        return self
    }

    /// Returns the localized version of the string with arguments
    func localized(_ arguments: CVarArg...) -> String {
        let (primary, fallback) = Self.localizationBundles()
        let format = lookup(in: primary)
            ?? fallback.flatMap { lookup(in: $0) }
            // Nothing anywhere: format the key itself, as before.
            ?? self
        return String(format: format, arguments: arguments)
    }

    /// Returns the localized version from a specific table
    func localized(tableName: String) -> String {
        let bundle = Bundle.currentLanguageBundle ?? Bundle.main
        return NSLocalizedString(self, tableName: tableName, bundle: bundle, comment: "")
    }

    /// Returns the localized version from a specific table with arguments
    func localized(tableName: String, arguments: CVarArg...) -> String {
        let bundle = Bundle.currentLanguageBundle ?? Bundle.main
        let format = NSLocalizedString(self, tableName: tableName, bundle: bundle, comment: "")
        return String(format: format, arguments: arguments)
    }

    // MARK: - Lookup

    /// The first of `localizationTables` to hold an entry for this key, or `nil`
    /// when none does — the check is that the result differs from the key, which
    /// is what `NSLocalizedString` returns on a miss.
    private func lookup(in bundle: Bundle) -> String? {
        for table in Self.localizationTables {
            let localized: String
            if let table {
                localized = NSLocalizedString(self, tableName: table, bundle: bundle, comment: "")
            } else {
                localized = NSLocalizedString(self, bundle: bundle, comment: "")
            }

            // If we found a translation (not the same as the key), return it
            if localized != self {
                return localized
            }
        }
        return nil
    }

    /// The bundle to search first, and the English one to fall back to.
    ///
    /// The fallback is `nil` when the active language *is* English, or when
    /// there is no `en.lproj` — in either case a second identical search would
    /// only repeat the first. Compared by URL rather than by identity because
    /// `Bundle` equality is `NSObject.isEqual`, whose meaning for two bundles
    /// pointing at the same directory is not worth relying on.
    private static func localizationBundles() -> (primary: Bundle, fallback: Bundle?) {
        let primary = Bundle.currentLanguageBundle ?? Bundle.main
        guard let english = Bundle.englishLanguageBundle,
              english.bundleURL != primary.bundleURL else {
            return (primary, nil)
        }
        return (primary, english)
    }
}

// MARK: - SwiftUI Extensions

extension Text {
    /// Creates a Text view with a localized string
    init(localized key: String) {
        self.init(LocalizedStringKey(key))
    }
    
    /// Creates a Text view with a localized string from a specific table
    init(localized key: String, tableName: String) {
        self.init(NSLocalizedString(key, tableName: tableName, comment: ""))
    }
}

// MARK: - LocalizedStringKey Extensions

extension LocalizedStringKey {
    /// Creates a LocalizedStringKey from a string
    static func key(_ key: String) -> LocalizedStringKey {
        return LocalizedStringKey(key)
    }
}