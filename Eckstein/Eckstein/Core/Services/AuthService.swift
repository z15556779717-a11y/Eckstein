//
//  AuthService.swift
//  Eckstein
//
//  Created by Assistant on 15/01/2025.
//

import Foundation
import AuthenticationServices
import CryptoKit
import Supabase

@MainActor
class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var currentNonce: String?
    private let supabase = SupabaseService.shared
    
    override init() {
        super.init()
        Task {
            await checkAuthStatus()
        }
    }
    
    // MARK: - Auth Status
    
    func checkAuthStatus() async {
        do {
            let user = try await supabase.getCurrentUser()
            
            // If user exists, sync to public.users
            if user != nil {
                await supabase.syncCurrentUserToDatabase()
            }
            
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = user != nil
            }
        } catch {
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
            }
        }
    }
    
    // MARK: - Email/Password Authentication
    
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let user = try await supabase.signIn(email: email, password: password)
            
            // Simple sync approach
            await supabase.syncCurrentUserToDatabase()
            
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
                self.isLoading = false
            }
        } catch {
            print("❌ AuthService signIn error: \(error)")
            print("Error details: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            throw error
        }
    }
    
    func signUp(email: String, password: String, fullName: String, gender: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let user = try await supabase.signUp(
                email: email, 
                password: password,
                metadata: [
                    "full_name": fullName,
                    "gender": gender
                ]
            )
            
            // Simple sync approach
            await supabase.syncCurrentUserToDatabase()
            
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
                self.isLoading = false
            }
        } catch {
            print("❌ AuthService signUp error: \(error)")
            print("Error details: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            throw error
        }
    }
    
    // MARK: - Apple Sign In
    
    func handleSignInWithApple(request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }
    
    func handleSignInWithApple(result: Result<ASAuthorization, Error>) async {
        isLoading = true
        errorMessage = nil
        
        do {
            switch result {
            case .success(let authorization):
                guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                      let nonce = currentNonce,
                      let identityToken = appleIDCredential.identityToken,
                      let tokenString = String(data: identityToken, encoding: .utf8) else {
                    throw AuthError.invalidCredential
                }
                
                // Sign in with Supabase using Apple credentials
                let session = try await supabase.client.auth.signInWithIdToken(
                    credentials: .init(
                        provider: .apple,
                        idToken: tokenString,
                        nonce: nonce
                    )
                )
                
                // Simple sync approach
                await supabase.syncCurrentUserToDatabase()
                
                // Save display name from Apple if available
                if let fullName = appleIDCredential.fullName {
                    let firstName = fullName.givenName ?? ""
                    let lastName = fullName.familyName ?? ""
                    let displayName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
                    if !displayName.isEmpty {
                        UserDefaults.standard.set(displayName, forKey: "userDisplayName_\(session.user.id.uuidString)")
                    }
                }
                
                await MainActor.run {
                    self.currentUser = session.user
                    self.isAuthenticated = true
                    self.isLoading = false
                }
                
            case .failure(let error):
                throw error
            }
        } catch {
            print("❌ AuthService Apple Sign In error: \(error)")
            print("Error details: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() async throws {
        isLoading = true
        
        do {
            try await supabase.signOut()
            
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            throw error
        }
    }
    
    // MARK: - User Record Management
    
    private func createOrUpdateUserRecord(user: User, appleCredential: ASAuthorizationAppleIDCredential? = nil) async {
        let userId = user.id.uuidString
        let userEmail = user.email ?? ""
        
        var displayName: String? = nil
        
        // Add Apple-specific data if available
        if let credential = appleCredential {
            if let fullName = credential.fullName {
                let firstName = fullName.givenName ?? ""
                let lastName = fullName.familyName ?? ""
                let name = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    displayName = name
                }
            }
        }
        
        // Create a simple user struct for insertion
        struct UserRecord: Encodable {
            let id: String
            let email: String
            let display_name: String?
            let created_at: String
            let updated_at: String
            let sync_status: String
        }
        
        let userRecord = UserRecord(
            id: userId,
            email: userEmail,
            display_name: displayName,
            created_at: ISO8601DateFormatter().string(from: Date()),
            updated_at: ISO8601DateFormatter().string(from: Date()),
            sync_status: "synced"
        )
        
        // Check if user exists
        do {
            print("📝 Checking if user exists in database: \(userId)")
            let existingUser = try await supabase.client.database
                .from("users")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
            
            print("✅ User exists, skipping creation")
        } catch {
            print("📝 User doesn't exist, creating new record")
            
            // Try direct insert with Supabase
            do {
                let encoder = JSONEncoder()
                let jsonData = try encoder.encode([userRecord])
                
                print("📤 Sending data: \(String(data: jsonData, encoding: .utf8) ?? "nil")")
                
                let response = try await supabase.client.database
                    .from("users")
                    .insert(jsonData)
                    .execute()
                
                print("✅ User created successfully")
                print("Response: \(String(data: response.data, encoding: .utf8) ?? "nil")")
                
                // Also try to create user preferences
                struct UserPreferences: Encodable {
                    let user_id: String
                    let daily_calorie_goal: Int
                    let daily_protein_goal: Int
                    let daily_carb_goal: Int
                    let weight_unit: String
                    let activity_level: String
                }
                
                let preferences = UserPreferences(
                    user_id: userId,
                    daily_calorie_goal: 2000,
                    daily_protein_goal: 150,
                    daily_carb_goal: 250,
                    weight_unit: "kg",
                    activity_level: "moderate"
                )
                
                let prefData = try encoder.encode([preferences])
                _ = try await supabase.client.database
                    .from("user_preferences")
                    .insert(prefData)
                    .execute()
                
                print("✅ User preferences created")
            } catch {
                print("❌ Failed to create user record: \(error)")
                print("Error type: \(type(of: error))")
                // Don't throw - auth succeeded even if our table insert failed
            }
        }
    }
    
    // MARK: - Helpers
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case invalidCredential
    case userNotFound
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid credentials provided"
        case .userNotFound:
            return "User not found"
        case .networkError:
            return "Network error occurred"
        }
    }
}