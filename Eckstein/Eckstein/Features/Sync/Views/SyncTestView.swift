//
//  SyncTestView.swift
//  Eckstein
//
//  Created by Assistant on 15/07/2025.
//

import SwiftUI

struct SyncTestView: View {
    @State private var testResult = ""
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Sync API Test")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("This will test the raw Supabase API connection")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Run Test") {
                runTest()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)
            
            if isLoading {
                ProgressView()
            }
            
            ScrollView {
                Text(testResult)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            .frame(maxHeight: .infinity)
        }
        .padding()
    }
    
    private func runTest() {
        isLoading = true
        testResult = "Starting test...\n\n"
        
        Task {
            // First test basic connectivity
            testResult += "=== Basic Connectivity Test ===\n"
            do {
                let testURL = URL(string: "https://www.google.com")!
                let (_, response) = try await URLSession.shared.data(from: testURL)
                if let httpResponse = response as? HTTPURLResponse {
                    testResult += "✅ Basic internet working: Status \(httpResponse.statusCode)\n\n"
                }
            } catch {
                testResult += "❌ No internet connection: \(error.localizedDescription)\n\n"
                isLoading = false
                return
            }
            // Test 1: Check basic configuration
            testResult += "=== Configuration Test ===\n"
            testResult += "Supabase configured: \(AppEnvironment.isSupabaseConfigured)\n"
            
            // Test 2: Try raw HTTP request
            testResult += "=== Raw HTTP Test ===\n"
            do {
                let url = AppEnvironment.supabaseURL.appendingPathComponent("rest/v1/eckstein_meals")
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("Bearer \(AppEnvironment.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
                request.setValue(AppEnvironment.supabaseAnonKey, forHTTPHeaderField: "apikey")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.url?.append(queryItems: [URLQueryItem(name: "limit", value: "1")])
                
                testResult += "Request URL: \(request.url?.absoluteString ?? "nil")\n"
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    testResult += "Status Code: \(httpResponse.statusCode)\n"
                    testResult += "Headers: \(httpResponse.allHeaderFields)\n"
                }
                
                if let responseString = String(data: data, encoding: .utf8) {
                    testResult += "Response: \(responseString)\n\n"
                }
                
                // Test 3: Try POST request
                testResult += "=== POST Test ===\n"
                let postURL = AppEnvironment.supabaseURL.appendingPathComponent("rest/v1/eckstein_meals")
                var postRequest = URLRequest(url: postURL)
                postRequest.httpMethod = "POST"
                postRequest.setValue("Bearer \(AppEnvironment.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
                postRequest.setValue("public", forHTTPHeaderField: "apikey")
                postRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                postRequest.setValue("return=representation", forHTTPHeaderField: "Prefer")
                
                let testData = [
                    "id": UUID().uuidString,
                    "user_id": "00000000-0000-0000-0000-000000000001",
                    "date": "2025-07-15",
                    "meal_number": 1,
                    "total_calories": 500,
                    "total_protein": 50.0,
                    "total_carbs": 60.0,
                    "total_fat": 20.0,
                    "created_at": ISO8601DateFormatter().string(from: Date()),
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ] as [String : Any]
                
                postRequest.httpBody = try JSONSerialization.data(withJSONObject: testData)
                
                let (postData, postResponse) = try await URLSession.shared.data(for: postRequest)
                
                if let httpResponse = postResponse as? HTTPURLResponse {
                    testResult += "POST Status Code: \(httpResponse.statusCode)\n"
                }
                
                if let responseString = String(data: postData, encoding: .utf8) {
                    testResult += "POST Response: \(responseString)\n"
                }
                
            } catch {
                testResult += "Error: \(error)\n"
                testResult += "Error description: \(error.localizedDescription)\n"
            }
            
            isLoading = false
        }
    }
}

#Preview {
    SyncTestView()
}