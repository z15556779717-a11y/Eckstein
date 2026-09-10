//
//  DirectSyncTestView.swift
//  Eckstein
//
//  Created by Assistant on 15/07/2025.
//

import SwiftUI

struct DirectSyncTestView: View {
    @State private var testResult = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Direct Sync Test")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("This bypasses the SDK and tests raw HTTP")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Run Direct Test") {
                        runDirectTest()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)
                    
                    if isLoading {
                        ProgressView()
                    }
                    
                    Text(testResult)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func runDirectTest() {
        isLoading = true
        testResult = "Starting test...\n\n"
        
        Task {
            // SECURITY: this previously embedded a Supabase service_role key in the
            // client bundle (full RLS bypass). It was removed in the phase-1 audit.
            // Use the anon/publishable key only; privileged work belongs in a
            // server-side Supabase Edge Function.
            let serviceKey = AppEnvironment.supabaseAnonKey
            
            // Test 1: List meals with service role
            testResult += "=== Test 1: List Meals (Service Role) ===\n"
            do {
                let url = URL(string: "https://zyuqxuuosmiiezjsrasb.supabase.co/rest/v1/eckstein_meals?limit=5")!
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("Bearer \(serviceKey)", forHTTPHeaderField: "Authorization")
                request.setValue(serviceKey, forHTTPHeaderField: "apikey")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.timeoutInterval = 30
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    testResult += "Status: \(httpResponse.statusCode)\n"
                    
                    if let responseString = String(data: data, encoding: .utf8) {
                        testResult += "Response: \(responseString)\n\n"
                    }
                }
            } catch {
                testResult += "Error: \(error.localizedDescription)\n\n"
            }
            
            // Test 2: Insert a meal with service role
            testResult += "=== Test 2: Insert Meal (Service Role) ===\n"
            do {
                let url = URL(string: "https://zyuqxuuosmiiezjsrasb.supabase.co/rest/v1/eckstein_meals")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("Bearer \(serviceKey)", forHTTPHeaderField: "Authorization")
                request.setValue(serviceKey, forHTTPHeaderField: "apikey")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("return=representation", forHTTPHeaderField: "Prefer")
                
                let testData: [String: Any] = [
                    "id": UUID().uuidString,
                    "user_id": "00000000-0000-0000-0000-000000000001",
                    "date": "2025-07-15",
                    "meal_number": 2, // Only 1 or 2 are allowed per database constraint
                    "total_calories": 500,
                    "total_protein": 50.0,
                    "total_carbs": 60.0,
                    "total_fat": 20.0,
                    "created_at": ISO8601DateFormatter().string(from: Date()),
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ]
                
                request.httpBody = try JSONSerialization.data(withJSONObject: testData, options: .prettyPrinted)
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    testResult += "Status: \(httpResponse.statusCode)\n"
                    
                    if let responseString = String(data: data, encoding: .utf8) {
                        testResult += "Response: \(responseString)\n\n"
                    }
                }
            } catch {
                testResult += "Error: \(error.localizedDescription)\n\n"
            }
            
            // Test 3: Test with anon key (should fail due to RLS)
            testResult += "=== Test 3: List Meals (Anon Key) ===\n"
            do {
                let url = URL(string: "https://zyuqxuuosmiiezjsrasb.supabase.co/rest/v1/eckstein_meals?limit=5")!
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("Bearer \(AppEnvironment.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
                request.setValue(AppEnvironment.supabaseAnonKey, forHTTPHeaderField: "apikey")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    testResult += "Status: \(httpResponse.statusCode)\n"
                    
                    if let responseString = String(data: data, encoding: .utf8) {
                        testResult += "Response: \(responseString)\n"
                    }
                }
            } catch {
                testResult += "Error: \(error.localizedDescription)\n"
            }
            
            isLoading = false
        }
    }
}

#Preview {
    DirectSyncTestView()
}