//
//  DirectSupabaseTest.swift
//  Eckstein
//
//  Created by Assistant on 15/01/2025.
//

import SwiftUI
import Supabase

struct DirectSupabaseTest: View {
    @State private var testResults = ""
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Direct Supabase Test")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("This test bypasses all our code and directly tests Supabase")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if isLoading {
                    ProgressView()
                        .padding()
                }
                
                Text(testResults)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                
                VStack(spacing: 12) {
                    Button("Test 1: Direct Insert") {
                        Task { await testDirectInsert() }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Test 2: Check Auth User") {
                        Task { await testAuthUser() }
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Test 3: Raw SQL Insert") {
                        Task { await testRawSQL() }
                    }
                    .buttonStyle(.bordered)
                }
                .disabled(isLoading)
            }
            .padding()
        }
    }
    
    private func testDirectInsert() async {
        isLoading = true
        testResults = "Testing direct insert...\n"
        
        let client = SupabaseService.shared.client
        let testId = UUID().uuidString
        let testEmail = "test_\(UUID().uuidString.prefix(8))@example.com"
        
        // Create a minimal struct
        struct MinimalUser: Codable {
            let id: String
            let email: String
        }
        
        let user = MinimalUser(id: testId, email: testEmail)
        
        do {
            addResult("Creating user with id: \(testId)")
            addResult("Email: \(testEmail)")
            
            // Test 1: Try upsert
            let response1 = try await client.database
                .from("users")
                .upsert(user)
                .execute()
            
            addResult("✅ Upsert succeeded!")
            addResult("Status: \(response1.response.statusCode)")
            
        } catch {
            addResult("❌ Upsert failed: \(error)")
            
            // Test 2: Try insert with dictionary
            do {
                let dict: [String: Any] = ["id": testId, "email": testEmail]
                let jsonData = try JSONSerialization.data(withJSONObject: dict)
                
                let response2 = try await client.database
                    .from("users")
                    .insert(jsonData)
                    .execute()
                
                addResult("✅ Dictionary insert succeeded!")
                
            } catch {
                addResult("❌ Dictionary insert also failed: \(error)")
            }
        }
        
        isLoading = false
    }
    
    private func testAuthUser() async {
        isLoading = true
        testResults = "Checking current auth user...\n"
        
        let client = SupabaseService.shared.client
        
        do {
            let session = try await client.auth.session
            let user = session.user
            
            addResult("✅ Auth user found:")
            addResult("ID: \(user.id)")
            addResult("Email: \(user.email ?? "nil")")
            
            // Try to check if this user exists in our table
            do {
                let response = try await client.database
                    .from("users")
                    .select()
                    .eq("id", value: user.id.uuidString)
                    .single()
                    .execute()
                
                addResult("✅ User exists in users table")
                
            } catch {
                addResult("❌ User NOT in users table")
                addResult("Error: \(error)")
            }
        } catch {
            addResult("❌ No authenticated user or auth check failed")
            addResult("Error: \(error)")
        }
        
        isLoading = false
    }
    
    private func testRawSQL() async {
        isLoading = true
        testResults = "Testing raw SQL...\n"
        
        let client = SupabaseService.shared.client
        let testId = UUID().uuidString
        let testEmail = "sql_\(UUID().uuidString.prefix(8))@example.com"
        
        // For Supabase v2, we need to use RPC for raw SQL
        do {
            // First, let's create an RPC function in Supabase
            addResult("Note: Raw SQL requires an RPC function")
            addResult("Create this function in Supabase SQL editor:")
            addResult("")
            addResult("CREATE OR REPLACE FUNCTION insert_user(")
            addResult("  user_id UUID,")
            addResult("  user_email TEXT")
            addResult(") RETURNS void AS $$")
            addResult("BEGIN")
            addResult("  INSERT INTO users (id, email)")
            addResult("  VALUES (user_id, user_email)")
            addResult("  ON CONFLICT (id) DO NOTHING;")
            addResult("END;")
            addResult("$$ LANGUAGE plpgsql;")
            
        } catch {
            addResult("❌ Error: \(error)")
        }
        
        isLoading = false
    }
    
    private func addResult(_ text: String) {
        testResults += text + "\n"
    }
}

#Preview {
    DirectSupabaseTest()
}