//
//  SimpleUserSync.swift
//  Eckstein
//
//  Created by Assistant on 15/01/2025.
//

import Foundation
import Supabase

extension SupabaseService {
    
    /// Simplified user sync that just works
    func syncCurrentUserToDatabase() async {
        do {
            // Get current auth user
            let session = try await client.auth.session
            let authUser = session.user
            
            print("🔄 Syncing user: \(authUser.id)")
            
            // Prepare minimal user data
            struct MinimalUser: Encodable {
                let id: String
                let email: String
                let full_name: String?
                let gender: String?
                let updated_at: String
            }
            
            // Extract metadata from UserDefaults (temporary solution)
            let fullName = UserDefaults.standard.string(forKey: "user_fullname_\(authUser.id)")
            let gender = UserDefaults.standard.string(forKey: "user_gender_\(authUser.id)")
            
            let userData = MinimalUser(
                id: authUser.id.uuidString,
                email: authUser.email ?? "",
                full_name: fullName,
                gender: gender,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )
            
            // Simple upsert - this should just work
            do {
                let response = try await client.database
                    .from("users")
                    .upsert(userData)
                    .execute()
                
                print("✅ User synced successfully")
                print("Status: \(response.response.statusCode)")
                
                // If successful, try preferences
                struct UserPrefs: Encodable {
                    let user_id: String
                    let daily_calorie_goal: Int
                    let daily_protein_goal: Int
                    let daily_carb_goal: Int
                    let weight_unit: String
                    let activity_level: String
                }
                
                let prefsData = UserPrefs(
                    user_id: authUser.id.uuidString,
                    daily_calorie_goal: 2000,
                    daily_protein_goal: 150,
                    daily_carb_goal: 250,
                    weight_unit: "kg",
                    activity_level: "moderate"
                )
                
                let _ = try? await client.database
                    .from("user_preferences")
                    .upsert(prefsData)
                    .execute()
                
            } catch {
                print("❌ Sync failed: \(error)")
                
                // Try raw insert as last resort
                let insertData = """
                {
                    "id": "\(authUser.id.uuidString)",
                    "email": "\(authUser.email ?? "")"
                }
                """
                
                if let jsonData = insertData.data(using: .utf8) {
                    do {
                        let response = try await client.database
                            .from("users")
                            .insert(jsonData)
                            .execute()
                        print("✅ Raw insert worked: \(response.response.statusCode)")
                    } catch {
                        print("❌ Raw insert also failed: \(error)")
                    }
                }
            }
            
        } catch {
            print("❌ Auth session error: \(error)")
        }
    }
}