//
//  AuthViewModel.swift
//  Eckstein
//
//  Created by Assistant on 15/01/2025.
//

import Foundation
import SwiftUI
import AuthenticationServices

@MainActor
class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var fullName = ""
    @Published var isMale = true
    @Published var isSignUpMode = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authService = AuthService.shared

    // Email validation
    var isEmailValid: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    // Password validation
    var isPasswordValid: Bool {
        password.count >= 6
    }
    
    var passwordsMatch: Bool {
        password == confirmPassword
    }
    
    /// Whether the form can be submitted.
    ///
    /// Sign-up used to require a sixth condition, comparing an "Admin Password"
    /// field against `ProcessInfo.processInfo.environment["ADMIN_PASSWORD"]`.
    /// That variable is never set on a device -- only a debugger launch can set
    /// it -- so the comparison was always against the empty string. The effect
    /// was to require the field be left *blank*, which is the opposite of what
    /// its label said, and the app was unregisterable for anyone who filled it
    /// in. It also protected nothing: a check compiled into the binary is
    /// bypassable by whoever wants to bypass it. Real control over who may sign
    /// up belongs in the Supabase Auth settings and server-side RLS, not here.
    var canSubmit: Bool {
        if isSignUpMode {
            return isEmailValid && isPasswordValid && passwordsMatch && !fullName.isEmpty && !isLoading
        } else {
            return isEmailValid && !password.isEmpty && !isLoading
        }
    }
    
    var passwordStrength: PasswordStrength {
        if password.isEmpty { return .none }
        if password.count < 6 { return .weak }
        
        var strength = 0
        if password.rangeOfCharacter(from: .lowercaseLetters) != nil { strength += 1 }
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil { strength += 1 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil { strength += 1 }
        if password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")) != nil { strength += 1 }
        
        switch strength {
        case 0...1: return .weak
        case 2: return .medium
        default: return .strong
        }
    }
    
    enum PasswordStrength {
        case none, weak, medium, strong
        
        var color: Color {
            switch self {
            case .none: return .clear
            case .weak: return .red
            case .medium: return .orange
            case .strong: return .green
            }
        }
        
        var text: String {
            switch self {
            case .none: return ""
            case .weak: return "Weak"
            case .medium: return "Medium"
            case .strong: return "Strong"
            }
        }
    }
    
    // MARK: - Email/Password Methods
    
    func signIn() async {
        guard canSubmit else { return }
        
        print("🔵 AuthViewModel: Starting sign in for email: \(email)")
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.signIn(email: email, password: password)
        } catch {
            errorMessage = formatError(error)
        }
        
        isLoading = false
    }
    
    func signUp() async {
        guard canSubmit else { return }
        
        print("🔵 AuthViewModel: Starting sign up for email: \(email)")
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.signUp(
                email: email, 
                password: password,
                fullName: fullName,
                gender: isMale ? "male" : "female"
            )
        } catch {
            errorMessage = formatError(error)
        }
        
        isLoading = false
    }
    
    func toggleMode() {
        isSignUpMode.toggle()
        errorMessage = nil
        password = ""
        confirmPassword = ""
        fullName = ""
        isMale = true
    }
    
    // MARK: - Apple Sign In
    
    func handleSignInWithAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        authService.handleSignInWithApple(request: request)
    }
    
    func handleSignInWithAppleCompletion(_ result: Result<ASAuthorization, Error>) async {
        await authService.handleSignInWithApple(result: result)
    }
    
    // MARK: - Helpers
    
    private func formatError(_ error: Error) -> String {
        // Format Supabase errors to be more user-friendly
        let errorString = error.localizedDescription
        
        if errorString.contains("Email not confirmed") {
            return "Please check your email to confirm your account"
        } else if errorString.contains("Invalid login credentials") {
            return "Invalid email or password"
        } else if errorString.contains("User already registered") {
            return "An account with this email already exists"
        } else if errorString.contains("Password should be at least") {
            return "Password must be at least 6 characters"
        } else {
            return "An error occurred. Please try again."
        }
    }
}