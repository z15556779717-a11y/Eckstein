//
//  SupabaseAuthService.swift
//  Eckstein
//
//  Created by Assistant on 15/01/2025.
//

import Foundation
import Supabase

// Custom structs that match the Supabase table structure exactly
struct DBUser: Codable {
    let id: String
    let email: String
    let display_name: String?
    let created_at: String?
    let updated_at: String?
    let sync_status: String?
}

struct DBUserPreferences: Codable {
    let user_id: String
    let daily_calorie_goal: Int
    let daily_protein_goal: Int
    let daily_carb_goal: Int
    let weight_unit: String
    let activity_level: String
}

extension SupabaseService {
    
    // Create user with proper error handling
    func createUserRecord(userId: String, email: String, displayName: String? = nil) async throws {
        print("🔵 Creating user record for: \(userId)")
        
        // First, let's check if the table exists and is accessible
        do {
            // Try a simple select to verify table access
            let testResponse = try await client.database
                .from("users")
                .select("id")
                .limit(1)
                .execute()
            
            print("✅ Users table is accessible")
        } catch {
            print("❌ Cannot access users table: \(error)")
            throw error
        }
        
        // Create the user record
        let user = DBUser(
            id: userId,
            email: email,
            display_name: displayName,
            created_at: nil,  // Let database handle this
            updated_at: nil,  // Let database handle this
            sync_status: "synced"
        )
        
        do {
            // Use Supabase's upsert to handle conflicts
            let response = try await client.database
                .from("users")
                .upsert(user)
                .execute()
            
            print("✅ User record created/updated successfully")
            print("Response status: \(response.response.statusCode)")
            
        } catch {
            print("❌ Failed to create user record")
            print("Error: \(error)")
            
            // Try to get more error details
            print("Full error: \(error)")
            if let nsError = error as NSError? {
                print("NSError domain: \(nsError.domain)")
                print("NSError code: \(nsError.code)")
                print("NSError userInfo: \(nsError.userInfo)")
            }
            
            throw error
        }
    }
    
    // Create user preferences
    func createUserPreferences(userId: String) async throws {
        print("🔵 Creating user preferences for: \(userId)")
        
        let preferences = DBUserPreferences(
            user_id: userId,
            daily_calorie_goal: 2000,
            daily_protein_goal: 150,
            daily_carb_goal: 250,
            weight_unit: "kg",
            activity_level: "moderate"
        )
        
        do {
            let response = try await client.database
                .from("user_preferences")
                .upsert(preferences)
                .execute()
            
            print("✅ User preferences created successfully")
            
        } catch {
            print("❌ Failed to create user preferences: \(error)")
            // Don't throw - preferences are optional
        }
    }
}