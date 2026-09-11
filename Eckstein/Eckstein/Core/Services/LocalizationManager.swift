//
//  LocalizationManager.swift
//  Eckstein
//
//  Created by Eliad Shahar on 23/07/2025.
//

import Foundation
import SwiftUI

@MainActor
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    /// The languages the app ships a `.lproj` for.
    static let supportedLanguages = ["en", "he", "zh-Hans"]

    /// Maps a BCP-47 tag onto one of ``supportedLanguages``.
    ///
    /// `Locale.current.language.languageCode` is not enough on its own: it
    /// reports `zh` for every Chinese variant, and the app ships Simplified
    /// only. The script subtag is what separates `zh-Hans` from `zh-Hant`.
    static func resolveLanguage(_ identifier: String) -> String {
        let parts = identifier
            .replacingOccurrences(of: "_", with: "-")
            .split(separator: "-")
            .map { $0.lowercased() }
        guard let code = parts.first else { return "en" }

        guard code == "zh" else {
            return supportedLanguages.contains(code) ? code : "en"
        }

        // Traditional regions fall back to English rather than being handed
        // Simplified, which is not the script they asked for.
        let subtags = Set(parts.dropFirst())
        let isTraditional = subtags.contains("hant")
            || subtags.contains("tw") || subtags.contains("hk") || subtags.contains("mo")
        return isTraditional ? "en" : "zh-Hans"
    }

    @Published var currentLanguage: String {
        didSet {
            // Kept here rather than only in `setLanguage`, so the picker —
            // which binds straight to this property — cannot leave `isRTL`
            // describing the previous language.
            isRTL = currentLanguage == "he"
            UserDefaults.standard.set(currentLanguage, forKey: "app_language")
            Bundle.setLanguage(currentLanguage)
            NotificationCenter.default.post(name: .languageChanged, object: nil)
        }
    }

    @Published var isRTL: Bool

    private init() {
        let saved = UserDefaults.standard.string(forKey: "app_language")
        let systemLanguage = Locale.preferredLanguages.first ?? "en"

        // A saved language is only honoured if it is one we actually ship.
        let language = saved.flatMap { Self.supportedLanguages.contains($0) ? $0 : nil }
            ?? Self.resolveLanguage(systemLanguage)
        self.currentLanguage = language
        self.isRTL = language == "he"

        Bundle.setLanguage(language)
    }
    
    func setLanguage(_ code: String) {
        currentLanguage = code
        isRTL = code == "he"
    }
    
    var currentLocale: Locale {
        Locale(identifier: currentLanguage)
    }
    
    var layoutDirection: LayoutDirection {
        isRTL ? .rightToLeft : .leftToRight
    }
}

// MARK: - Bundle Extension for Dynamic Language Switching

extension Bundle {
    fileprivate static var bundleKey: UInt8 = 0
    
    static func setLanguage(_ language: String) {
        defer {
            object_setClass(Bundle.main, AnyLanguageBundle.self)
        }
        
        let path = Bundle.main.path(forResource: language, ofType: "lproj")
        objc_setAssociatedObject(
            Bundle.main,
            &bundleKey,
            path.flatMap(Bundle.init) ?? Bundle.main,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
    
    static var currentLanguageBundle: Bundle? {
        return objc_getAssociatedObject(Bundle.main, &bundleKey) as? Bundle
    }
}

private class AnyLanguageBundle: Bundle {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let bundle = objc_getAssociatedObject(self, &Bundle.bundleKey) as? Bundle else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

// MARK: - Notification

extension Notification.Name {
    static let languageChanged = Notification.Name("languageChanged")
}