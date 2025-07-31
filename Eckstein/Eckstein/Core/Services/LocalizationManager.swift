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
    
    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "app_language")
            Bundle.setLanguage(currentLanguage)
            NotificationCenter.default.post(name: .languageChanged, object: nil)
        }
    }
    
    @Published var isRTL: Bool
    
    private init() {
        let savedLanguage = UserDefaults.standard.string(forKey: "app_language")
        let systemLanguage = Locale.current.language.languageCode?.identifier ?? "en"
        
        // Use saved language, or Hebrew if system is Hebrew, otherwise English
        let language = savedLanguage ?? (systemLanguage == "he" ? "he" : "en")
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