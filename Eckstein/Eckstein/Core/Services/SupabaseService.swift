//
//  SupabaseService.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation
import Supabase

class SupabaseService {
    static let shared = SupabaseService()
    
    let client: SupabaseClient
    
    private init() {
        print("🚀 Initializing Supabase client")
        // SECURITY: do not log the URL or any part of the key here. This used to
        // print the project URL and a key prefix to the device console.
        print("Supabase configured: \(AppEnvironment.isSupabaseConfigured)")

        client = SupabaseClient(
            supabaseURL: AppEnvironment.supabaseURL,
            supabaseKey: AppEnvironment.supabaseAnonKey
        )
        print("✅ Supabase client initialized")
    }
    
    // MARK: - Authentication
    
    func signUp(email: String, password: String, metadata: [String: Any]? = nil) async throws -> User {
        print("🔐 Attempting to sign up with email: \(email)")
        do {
            let response = try await client.auth.signUp(
                email: email,
                password: password
            )
            print("✅ Sign up successful, user: \(response.user)")
            print("User ID: \(response.user.id)")
            print("User email: \(response.user.email ?? "nil")")
            
            // Update user metadata if provided
            if let metadata = metadata, response.session != nil {
                // Store metadata in user defaults for now
                // In a real app, you'd update this via Supabase's update user endpoint
                if let fullName = metadata["full_name"] as? String {
                    UserDefaults.standard.set(fullName, forKey: "user_fullname_\(response.user.id)")
                }
                if let gender = metadata["gender"] as? String {
                    UserDefaults.standard.set(gender, forKey: "user_gender_\(response.user.id)")
                }
            }
            
            // IMPORTANT: For email signups, Supabase might require email confirmation
            // Check if the user needs to confirm their email
            if response.session == nil {
                print("⚠️ Email confirmation required - check your email")
            }
            
            return response.user
        } catch {
            print("❌ Supabase signUp error: \(error)")
            print("Error type: \(type(of: error))")
            
            // Try to extract more error details
            if let nsError = error as NSError? {
                print("NSError domain: \(nsError.domain)")
                print("NSError code: \(nsError.code)")
                print("NSError userInfo: \(nsError.userInfo)")
                
                // Check if this is the "Database error saving new user" error
                if let message = nsError.userInfo["message"] as? String {
                    print("Error message: \(message)")
                }
            }
            
            throw error
        }
    }
    
    func signIn(email: String, password: String) async throws -> User {
        print("🔐 Attempting to sign in with email: \(email)")
        do {
            let session = try await client.auth.signIn(
                email: email,
                password: password
            )
            print("✅ Sign in successful, user: \(session.user)")
            return session.user
        } catch {
            print("❌ Supabase signIn error: \(error)")
            print("Error type: \(type(of: error))")
            if let authError = error as? AuthError {
                print("Auth error: \(authError)")
            }
            throw error
        }
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
    }
    
    func getCurrentUser() async throws -> User? {
        return try await client.auth.session.user
    }
    
    // MARK: - Database Helpers
    
    var database: SupabaseClient {
        return client
    }
    
    // MARK: - Sync Operations
    
    func create(table: String, data: [String: Any]) async throws {
        print("SupabaseService: Creating record in table '\(table)'")
        print("Data: \(data)")
        
        // Validate meal_number if it's eckstein_meals table
        if table == "eckstein_meals", let mealNumber = data["meal_number"] as? Int {
            guard mealNumber == 1 || mealNumber == 2 else {
                print("SupabaseService: Invalid meal_number \(mealNumber). Must be 1 or 2.")
                throw NSError(domain: "SupabaseService", code: 400, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid meal_number. Must be 1 or 2."
                ])
            }
        }
        
        do {
            // Convert data to proper format for Supabase
            let jsonData = try JSONSerialization.data(withJSONObject: [data])
            
            let response = try await client.database
                .from(table)
                .insert(jsonData)
                .execute()
            
            print("SupabaseService: Successfully created record in '\(table)'")
            print("Response: \(String(data: response.data, encoding: .utf8) ?? "nil")")
        } catch {
            print("SupabaseService: Failed to create record in '\(table)': \(error)")
            print("Error type: \(type(of: error))")
            throw error
        }
    }
    
    func update(table: String, id: String, data: [String: Any]) async throws {
        let jsonData = try JSONSerialization.data(withJSONObject: data)
        
        _ = try await client.database
            .from(table)
            .update(jsonData)
            .eq("id", value: id)
            .execute()
    }
    
    func delete(table: String, id: String) async throws {
        _ = try await client.database
            .from(table)
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    func fetch(table: String, id: String) async throws -> [String: Any]? {
        let response = try await client.database
            .from(table)
            .select()
            .eq("id", value: id)
            .single()
            .execute()
        
        let data = response.data
        
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
    
    func fetchAll(table: String, since: Date? = nil) async throws -> [[String: Any]] {
        var query = client.database
            .from(table)
            .select()
        
        if let since = since {
            let formatter = ISO8601DateFormatter()
            query = query.gte("updated_at", value: formatter.string(from: since))
        }
        
        let response = try await query.execute()
        
        let data = response.data
        
        return try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
    }
    
    func batchInsert(table: String, items: [[String: Any]]) async throws {
        let jsonData = try JSONSerialization.data(withJSONObject: items)
        
        _ = try await client.database
            .from(table)
            .insert(jsonData)
            .execute()
    }
}