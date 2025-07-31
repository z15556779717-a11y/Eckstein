//
//  String+Localization.swift
//  Eckstein
//
//  Created by Eliad Shahar on 23/07/2025.
//

import Foundation
import SwiftUI

extension String {
    /// Returns the localized version of the string
    var localized: String {
        let bundle = Bundle.currentLanguageBundle ?? Bundle.main
        
        // Try different localization tables in order
        let tables = ["Workout", "Diet", "Weight", "Profile", "Auth", "Common", nil]
        
        for table in tables {
            let localized = table != nil 
                ? NSLocalizedString(self, tableName: table, bundle: bundle, comment: "")
                : NSLocalizedString(self, bundle: bundle, comment: "")
            
            // If we found a translation (not the same as the key), return it
            if localized != self {
                return localized
            }
        }
        
        // If no translation found, return the key itself
        return self
    }
    
    /// Returns the localized version of the string with arguments
    func localized(_ arguments: CVarArg...) -> String {
        let bundle = Bundle.currentLanguageBundle ?? Bundle.main
        
        // Try different localization tables in order
        let tables = ["Workout", "Diet", "Weight", "Profile", "Auth", "Common", nil]
        
        for table in tables {
            let format = table != nil
                ? NSLocalizedString(self, tableName: table, bundle: bundle, comment: "")
                : NSLocalizedString(self, bundle: bundle, comment: "")
            
            // If we found a translation (not the same as the key), use it
            if format != self {
                return String(format: format, arguments: arguments)
            }
        }
        
        // If no translation found, try to format with the key itself
        return String(format: self, arguments: arguments)
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