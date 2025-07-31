//
//  WorkaroundTestView.swift
//  Eckstein
//
//  Created by Assistant on 15/07/2025.
//

import SwiftUI
import Supabase

struct WorkaroundTestView: View {
    @State private var testResult = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Workaround Test")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Testing various workarounds for the connection issue")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 12) {
                        Button("Test 1: Direct HTTP with Service Key") {
                            testDirectHTTP()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isLoading)
                        
                        Button("Test 2: Custom Supabase Client") {
                            testCustomClient()
                        }
                        .buttonStyle(.bordered)
                        .disabled(isLoading)
                        
                        Button("Test 3: Different URL Format") {
                            testDifferentURL()
                        }
                        .buttonStyle(.bordered)
                        .disabled(isLoading)
                    }
                    
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                    
                    ScrollView {
                        Text(testResult)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(height: 400)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func testDirectHTTP() {
        isLoading = true
        testResult = "=== Test 1: Direct HTTP with Service Key ===\n"
        
        Task {
            let serviceKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp5dXF4dXVvc21paWV6anNyYXNiIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MjQzOTA5NCwiZXhwIjoyMDY4MDE1MDk0fQ.WPDFIsY--ZN0y4B5AUCY4NlFXLpFslZaHgerC2Ri3ZA"
            
            // Try different request configurations
            let configurations = [
                ("Default", URLSessionConfiguration.default),
                ("Ephemeral", URLSessionConfiguration.ephemeral),
            ]
            
            for (name, config) in configurations {
                testResult += "\nTrying with \(name) configuration:\n"
                
                config.timeoutIntervalForRequest = 60
                config.timeoutIntervalForResource = 300
                config.waitsForConnectivity = true
                config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                
                let session = URLSession(configuration: config)
                
                do {
                    let url = URL(string: "https://zyuqxuuosmiiezjsrasb.supabase.co/rest/v1/eckstein_meals?limit=1")!
                    var request = URLRequest(url: url)
                    request.httpMethod = "GET"
                    request.setValue("Bearer \(serviceKey)", forHTTPHeaderField: "Authorization")
                    request.setValue(serviceKey, forHTTPHeaderField: "apikey")
                    
                    let (data, response) = try await session.data(for: request)
                    
                    if let httpResponse = response as? HTTPURLResponse {
                        testResult += "✅ Success! Status: \(httpResponse.statusCode)\n"
                        if let responseString = String(data: data, encoding: .utf8) {
                            testResult += "Data: \(responseString.prefix(100))...\n"
                        }
                    }
                } catch {
                    testResult += "❌ Failed: \(error.localizedDescription)\n"
                }
            }
            
            isLoading = false
        }
    }
    
    private func testCustomClient() {
        isLoading = true
        testResult = "=== Test 2: Custom Supabase Client ===\n"
        
        Task {
            // Create a new client with custom configuration
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 60
            config.waitsForConnectivity = true
            
            let session = URLSession(configuration: config)
            
            let client = SupabaseClient(
                supabaseURL: URL(string: "https://zyuqxuuosmiiezjsrasb.supabase.co")!,
                supabaseKey: AppEnvironment.supabaseAnonKey
            )
            
            do {
                testResult += "Attempting to fetch meals...\n"
                let response = try await client
                    .from("eckstein_meals")
                    .select()
                    .limit(1)
                    .execute()
                
                testResult += "✅ Success!\n"
                if let jsonString = String(data: response.data, encoding: .utf8) {
                    testResult += "Response: \(jsonString)\n"
                }
            } catch {
                testResult += "❌ Failed: \(error)\n"
                
                // Try to extract more error details
                if let supabaseError = error as? PostgrestError {
                    testResult += "Postgrest error: \(supabaseError)\n"
                }
            }
            
            isLoading = false
        }
    }
    
    private func testDifferentURL() {
        isLoading = true
        testResult = "=== Test 3: Different URL Formats ===\n"
        
        Task {
            let urls = [
                "https://zyuqxuuosmiiezjsrasb.supabase.co/rest/v1/",
                "https://zyuqxuuosmiiezjsrasb.supabase.co/rest/v1/eckstein_meals",
                "https://zyuqxuuosmiiezjsrasb.supabase.co",
            ]
            
            for urlString in urls {
                testResult += "\nTesting: \(urlString)\n"
                
                do {
                    guard let url = URL(string: urlString) else {
                        testResult += "❌ Invalid URL\n"
                        continue
                    }
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "GET"
                    request.setValue(AppEnvironment.supabaseAnonKey, forHTTPHeaderField: "apikey")
                    request.timeoutInterval = 30
                    
                    let (_, response) = try await URLSession.shared.data(for: request)
                    
                    if let httpResponse = response as? HTTPURLResponse {
                        testResult += "✅ Connected! Status: \(httpResponse.statusCode)\n"
                    }
                } catch let error as NSError {
                    testResult += "❌ Error code: \(error.code), domain: \(error.domain)\n"
                }
            }
            
            isLoading = false
        }
    }
}

#Preview {
    WorkaroundTestView()
}