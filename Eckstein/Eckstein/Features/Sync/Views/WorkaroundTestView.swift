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
                        Button("Test 1: Direct HTTP with Publishable Key") {
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
        testResult = "=== Test 1: Direct HTTP with Publishable Key ===\n"
        
        Task {
            // SECURITY: this previously embedded a Supabase service_role key in the
            // client bundle (full RLS bypass). It was removed in the phase-1 audit.
            let publishableKey = AppEnvironment.supabasePublishableKey
            
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
                    let url = URL(string: "rest/v1/eckstein_meals?limit=1", relativeTo: AppEnvironment.supabaseURL)!
                    var request = URLRequest(url: url)
                    request.httpMethod = "GET"
                    request.setValue("Bearer \(publishableKey)", forHTTPHeaderField: "Authorization")
                    request.setValue(publishableKey, forHTTPHeaderField: "apikey")
                    
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
                supabaseURL: AppEnvironment.supabaseURL,
                supabaseKey: AppEnvironment.supabasePublishableKey
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
            let base = AppEnvironment.supabaseURL.absoluteString
            let urls = [
                base + "/rest/v1/",
                base + "/rest/v1/eckstein_meals",
                base,
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
                    request.setValue(AppEnvironment.supabasePublishableKey, forHTTPHeaderField: "apikey")
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