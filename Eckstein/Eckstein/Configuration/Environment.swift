//
//  Environment.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation

enum AppEnvironment {
    // Load from environment configuration
    static var supabaseURL: URL {
        let urlString = EnvironmentLoader.shared.supabaseURL ?? "https://zyuqxuuosmiiezjsrasb.supabase.co"
        return URL(string: urlString)!
    }
    
    static var supabaseAnonKey: String {
        EnvironmentLoader.shared.supabaseAnonKey ?? "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp5dXF4dXVvc21paWV6anNyYXNiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI0MzkwOTQsImV4cCI6MjA2ODAxNTA5NH0.ri-fONM9mLcJ79bu5lOFFLBCarK2IUZ552HNRoVrg1s"
    }
    
    static var openAIKey: String? {
        EnvironmentLoader.shared.openAIKey
    }
    
    // Use Xcode configuration files in production
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    // Helper to validate configuration
    static var isConfigured: Bool {
        let hasSupabase = !supabaseAnonKey.contains("YOUR_") && 
                         !supabaseURL.absoluteString.contains("YOUR_")
        let hasOpenAI = openAIKey != nil && !openAIKey!.isEmpty && !openAIKey!.contains("YOUR_")
        
        print("Environment config check - Supabase: \(hasSupabase), OpenAI: \(hasOpenAI)")
        print("OpenAI key: \(openAIKey != nil ? "exists" : "nil")")
        
        return hasSupabase && hasOpenAI
    }
}
