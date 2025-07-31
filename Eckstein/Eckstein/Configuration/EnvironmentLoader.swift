//
//  EnvironmentLoader.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation

class EnvironmentLoader {
    static let shared = EnvironmentLoader()
    private var config: [String: String] = [:]
    
    private init() {
        loadEnvironment()
    }
    
    private func loadEnvironment() {
        print("EnvironmentLoader: Starting environment loading...")
        
        // First, set default values for development
        // These will be overridden if .env file is found
        config["SUPABASE_URL"] = "https://zyuqxuuosmiiezjsrasb.supabase.co"
        config["SUPABASE_ANON_KEY"] = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp5dXF4dXVvc21paWV6anNyYXNiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI0MzkwOTQsImV4cCI6MjA2ODAxNTA5NH0.ri-fONM9mLcJ79bu5lOFFLBCarK2IUZ552HNRoVrg1s"
        // OpenAI API key must be provided via .env file
        
        // Try to load from .env file
        if let envPath = Bundle.main.path(forResource: ".env", ofType: nil) {
            print("EnvironmentLoader: Found .env in bundle at: \(envPath)")
            loadFromFile(at: envPath)
        } else {
            print("EnvironmentLoader: No .env in bundle, checking file system...")
            // Try to find .env in the project root (for development)
            let fileManager = FileManager.default
            print("EnvironmentLoader: Current directory: \(fileManager.currentDirectoryPath)")
            
            // Try multiple common locations for .env file
            let possiblePaths = [
                "/Users/eliadshahar/Desktop/Eckstein/.env",
                URL(fileURLWithPath: fileManager.currentDirectoryPath).appendingPathComponent(".env").path,
                URL(fileURLWithPath: fileManager.currentDirectoryPath)
                    .deletingLastPathComponent()
                    .appendingPathComponent(".env").path,
                URL(fileURLWithPath: fileManager.currentDirectoryPath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent(".env").path
            ]
            
            var foundPath: String?
            for path in possiblePaths {
                print("EnvironmentLoader: Checking path: \(path)")
                if fileManager.fileExists(atPath: path) {
                    print("EnvironmentLoader: Found .env at: \(path)")
                    loadFromFile(at: path)
                    foundPath = path
                    break
                }
            }
            
            if foundPath == nil {
                print("EnvironmentLoader: WARNING - No .env file found, using hardcoded values!")
            }
        }
        
        // Override with process environment variables if available
        print("EnvironmentLoader: Checking process environment variables...")
        for (key, value) in ProcessInfo.processInfo.environment {
            if key.hasPrefix("OPENAI") || key.hasPrefix("SUPABASE") {
                print("EnvironmentLoader: Found env var \(key)")
                config[key] = value
            }
        }
        
        // Log loaded configuration (safely)
        print("EnvironmentLoader: Loaded configuration:")
        print("  - SUPABASE_URL: \(supabaseURL != nil ? "✓" : "✗")")
        print("  - SUPABASE_ANON_KEY: \(supabaseAnonKey != nil ? "✓" : "✗")")
        print("  - OPENAI_API_KEY: \(openAIKey != nil ? "✓" : "✗")")
        if let key = openAIKey, !key.isEmpty {
            print("  - OPENAI_API_KEY preview: \(key.prefix(10))...****")
        }
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
                            print("EnvironmentLoader: Loaded \(key) = \(value.prefix(10))...")
                        }
                    }
                }
            }
            
            print("EnvironmentLoader: Finished loading from file. Total keys: \(config.count)")
        } catch {
            print("EnvironmentLoader: Failed to load .env file: \(error)")
        }
    }
    
    func getValue(for key: String) -> String? {
        return config[key]
    }
    
    // Convenience properties
    var supabaseURL: String? {
        getValue(for: "SUPABASE_URL")
    }
    
    var supabaseAnonKey: String? {
        getValue(for: "SUPABASE_ANON_KEY")
    }
    
    var openAIKey: String? {
        getValue(for: "OPENAI_API_KEY")
    }
    
    var openAIOrgId: String? {
        getValue(for: "OPENAI_ORG_ID")
    }
}