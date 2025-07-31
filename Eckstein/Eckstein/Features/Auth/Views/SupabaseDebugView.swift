//
//  SupabaseDebugView.swift
//  Eckstein
//
//  Created by Assistant on 15/01/2025.
//

import SwiftUI

struct SupabaseDebugView: View {
    @State private var results = ""
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Supabase Debug Info")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(spacing: 12) {
                    Button("Check Auth vs Public Users") {
                        Task { await checkUserTables() }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("List All Auth Users") {
                        Task { await listAuthUsers() }
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Try Manual Sync") {
                        Task { await tryManualSync() }
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
    
    private func checkUserTables() async {
        isLoading = true
        results = "Checking user tables...\n\n"
        
        let supabase = SupabaseService.shared
        
        // Check public.users count
        do {
            let publicUsers = try await supabase.database
                .from("users")
                .select("id, email")
                .execute()
            
            let userData = try JSONSerialization.jsonObject(with: publicUsers.data) as? [[String: Any]] ?? []
            results += "Public users table count: \(userData.count)\n"
            
            for user in userData {
                results += "  - \(user["email"] ?? "unknown")\n"
            }
            
            // Try to get current auth user
            if let currentUser = try await supabase.getCurrentUser() {
                results += "\nCurrent auth user:\n"
                results += "  ID: \(currentUser.id)\n"
                results += "  Email: \(currentUser.email ?? "nil")\n"
                
                // Check if this user exists in public.users
                do {
                    let publicUser = try await supabase.database
                        .from("users")
                        .select()
                        .eq("id", value: currentUser.id.uuidString)
                        .single()
                        .execute()
                    
                    results += "  ✅ Exists in public.users\n"
                } catch {
                    results += "  ❌ NOT in public.users\n"
                }
            } else {
                results += "\nNo authenticated user\n"
            }
            
        } catch {
            results += "Error: \(error)\n"
        }
        
        isLoading = false
    }
    
    private func listAuthUsers() async {
        isLoading = true
        results = "Listing auth users...\n\n"
        
        results += "Note: Direct access to auth.users requires admin role.\n"
        results += "Use Supabase Dashboard to view auth.users table.\n\n"
        
        results += "To check auth vs public users mismatch, run this SQL in Supabase:\n\n"
        results += "SELECT au.id, au.email, pu.id as public_id\n"
        results += "FROM auth.users au\n"
        results += "LEFT JOIN public.users pu ON au.id = pu.id\n"
        results += "WHERE pu.id IS NULL;\n"
        
        isLoading = false
    }
    
    private func tryManualSync() async {
        isLoading = true
        results = "Trying manual sync...\n\n"
        
        let supabase = SupabaseService.shared
        
        do {
            // Get current auth user
            guard let user = try await supabase.getCurrentUser() else {
                results += "No authenticated user to sync\n"
                isLoading = false
                return
            }
            
            results += "Current user: \(user.email ?? "unknown")\n"
            results += "User ID: \(user.id)\n\n"
            
            // Try to create user in public.users
            let userData = [
                "id": user.id.uuidString,
                "email": user.email ?? ""
            ]
            
            do {
                // Try upsert instead of insert
                let response = try await supabase.database
                    .from("users")
                    .upsert(userData)
                    .execute()
                
                results += "✅ Manual sync successful!\n"
                results += "Response: \(String(data: response.data, encoding: .utf8) ?? "nil")\n"
                
            } catch {
                results += "❌ Manual sync failed: \(error)\n"
            }
            
        } catch {
            results += "Error: \(error)\n"
        }
        
        isLoading = false
    }
}

#Preview {
    SupabaseDebugView()
}