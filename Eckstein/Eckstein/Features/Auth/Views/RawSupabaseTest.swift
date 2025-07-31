//
//  RawSupabaseTest.swift
//  Eckstein
//
//  Created by Assistant on 15/01/2025.
//

import SwiftUI

struct RawSupabaseTest: View {
    @State private var results = ""
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Raw Supabase API Test")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("This bypasses ALL Swift code and tests the raw API")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 12) {
                    Button("Test 1: Check Tables") {
                        Task { await checkTables() }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Test 2: Raw HTTP Insert") {
                        Task { await testRawHTTPInsert() }
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Test 3: Check Auth Config") {
                        Task { await checkAuthConfig() }
                    }
                    .buttonStyle(.bordered)
                }
                .disabled(isLoading)
                
                if isLoading {
                    ProgressView()
                        .padding()
                }
                
                Text(results)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding()
        }
    }
    
    private func checkTables() async {
        isLoading = true
        results = "Checking tables...\n\n"
        
        let url = "\(AppEnvironment.supabaseURL.absoluteString)/rest/v1/users?select=*&limit=1"
        
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "GET"
        request.setValue(AppEnvironment.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(AppEnvironment.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as! HTTPURLResponse
            
            results += "Status Code: \(httpResponse.statusCode)\n"
            results += "Response: \(String(data: data, encoding: .utf8) ?? "nil")\n\n"
            
            if httpResponse.statusCode == 200 {
                results += "✅ Users table exists and is accessible\n"
            } else if httpResponse.statusCode == 404 {
                results += "❌ Users table does not exist\n"
            } else {
                results += "❌ Unexpected status code\n"
            }
            
        } catch {
            results += "❌ Error: \(error)\n"
        }
        
        isLoading = false
    }
    
    private func testRawHTTPInsert() async {
        isLoading = true
        results = "Testing raw HTTP insert...\n\n"
        
        let testId = UUID().uuidString
        let testEmail = "raw_test_\(UUID().uuidString.prefix(8))@example.com"
        
        let url = "\(AppEnvironment.supabaseURL.absoluteString)/rest/v1/users"
        
        let body: [String: Any] = [
            "id": testId,
            "email": testEmail
        ]
        
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue(AppEnvironment.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(AppEnvironment.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            request.httpBody = jsonData
            
            results += "Sending POST to: \(url)\n"
            results += "Body: \(String(data: jsonData, encoding: .utf8) ?? "nil")\n\n"
            
            let (data, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as! HTTPURLResponse
            
            results += "Status Code: \(httpResponse.statusCode)\n"
            results += "Response Headers:\n"
            for (key, value) in httpResponse.allHeaderFields {
                results += "  \(key): \(value)\n"
            }
            results += "\nResponse Body: \(String(data: data, encoding: .utf8) ?? "nil")\n\n"
            
            if httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
                results += "✅ Insert successful!\n"
            } else {
                results += "❌ Insert failed\n"
            }
            
        } catch {
            results += "❌ Error: \(error)\n"
        }
        
        isLoading = false
    }
    
    private func checkAuthConfig() async {
        isLoading = true
        results = "Checking auth configuration...\n\n"
        
        // Test auth endpoint
        let url = "\(AppEnvironment.supabaseURL.absoluteString)/auth/v1/settings"
        
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "GET"
        request.setValue(AppEnvironment.supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as! HTTPURLResponse
            
            results += "Auth Settings Status: \(httpResponse.statusCode)\n"
            
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                results += "Settings:\n"
                results += "  Email confirmations: \(json["mailer_autoconfirm"] ?? "unknown")\n"
                results += "  SMS confirmations: \(json["sms_autoconfirm"] ?? "unknown")\n"
                
                if let externalProviders = json["external"] as? [String: Any] {
                    results += "  External providers:\n"
                    for (provider, enabled) in externalProviders {
                        results += "    \(provider): \(enabled)\n"
                    }
                }
            }
            
            results += "\nRaw response:\n\(String(data: data, encoding: .utf8) ?? "nil")\n"
            
        } catch {
            results += "❌ Error checking auth config: \(error)\n"
        }
        
        isLoading = false
    }
}

#Preview {
    RawSupabaseTest()
}