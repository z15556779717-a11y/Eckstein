//
//  Config.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation

enum Config {
    static let appName = "Eckstein"
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
    
    enum Environment {
        case development
        case staging
        case production
        
        static var current: Environment {
            #if DEBUG
            return .development
            #else
            return .production
            #endif
        }
    }
}