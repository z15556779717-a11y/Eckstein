//
//  SupabaseTestView.swift
//  Eckstein
//
//  Created by Assistant on 15/01/2025.
//

import SwiftUI

struct SupabaseTestView: View {
    @State private var testResults = "Testing Supabase connection...\n"
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Supabase Connection Test")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom)
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                } else {
                    Text(testResults)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Button("Run Test Again") {
                    Task {
                        await runTests()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
            }
            .padding()
        }
        .task {
            await runTests()
        }
    }
    
    private func runTests() async {
        isLoading = true
        testResults = ""
        
        // Test 1: Check Supabase client initialization
        addResult("1. Checking Supabase client initialization...")
        let supabase = SupabaseService.shared
        addResult("✅ Supabase client initialized")
        
        // Test 2: Check Supabase URL and Key
        addResult("\n2. Checking Supabase configuration...")
        addResult("URL: \(AppEnvironment.supabaseURL)")
        addResult("Key prefix: \(String(AppEnvironment.supabaseAnonKey.prefix(20)))...")
        
        // Test 3: Test creating a test user
        addResult("\n3. Testing user registration...")
        do {
            let testEmail = "test\(UUID().uuidString.prefix(8))@example.com"
            let testPassword = "testPassword123!"
            addResult("Creating user with email: \(testEmail)")
            
            let user = try await supabase.signUp(email: testEmail, password: testPassword)
            addResult("✅ User created successfully!")
            addResult("User ID: \(user.id)")
            addResult("User email: \(user.email ?? "nil")")
            
            // Test 4: Check if users table exists
            addResult("\n4. Testing database access...")
            do {
                try await supabase.create(table: "users", data: [
                    "id": user.id.uuidString,
                    "email": user.email ?? "",
                    "created_at": ISO8601DateFormatter().string(from: Date()),
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                addResult("✅ Successfully created user record in database")
            } catch {
                addResult("❌ Failed to create user record: \(error)")
                addResult("This might mean the users table doesn't exist or has different schema")
            }
            
            // Clean up - sign out
            try await supabase.signOut()
            addResult("\n✅ All tests completed!")
            
        } catch {
            addResult("❌ User registration failed: \(error)")
            addResult("Error type: \(type(of: error))")
            addResult("Error description: \(error.localizedDescription)")
            
            // Check for specific error types
            if let nsError = error as NSError? {
                addResult("NSError domain: \(nsError.domain)")
                addResult("NSError code: \(nsError.code)")
                if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] {
                    addResult("Underlying error: \(underlyingError)")
                }
            }
        }
        
        isLoading = false
    }
    
    private func addResult(_ text: String) {
        testResults += text + "\n"
    }
}

#Preview {
    SupabaseTestView()
}