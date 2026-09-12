//
//  LoginView.swift
//  Eckstein
//
//  Created by Assistant on 15/01/2025.
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @FocusState private var focusedField: Field?
    @State private var showIntroduction = true
    @ObservedObject private var themeManager = ThemeManager.shared
    
    enum Field {
        case email, password, confirmPassword, fullName
    }
    
    var body: some View {
        if showIntroduction {
            IntroductionView(showIntroduction: $showIntroduction)
                .transition(.move(edge: .trailing))
        } else {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [themeManager.accentColor.color.opacity(0.1), themeManager.accentColor.color.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    // Logo and Title
                    VStack(spacing: 16) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 80))
                            .foregroundColor(themeManager.accentColor.color)
                            .padding(.top, 60)
                        
                        Text("Eckstein")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Your Personal Fitness Companion")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 30)
                    
                    // Sign in with Apple
                    SignInWithAppleButton(
                        onRequest: { request in
                            viewModel.handleSignInWithAppleRequest(request)
                        },
                        onCompletion: { result in
                            Task {
                                await viewModel.handleSignInWithAppleCompletion(result)
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .padding(.horizontal)
                    
                    // Or divider
                    HStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                        
                        Text("OR")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.horizontal)
                    
                    // Email/Password Form
                    VStack(spacing: 16) {
                        // Email field
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Email", text: $viewModel.email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .keyboardType(.emailAddress)
                                .focused($focusedField, equals: .email)
                                .onSubmit {
                                    focusedField = .password
                                }
                            
                            if !viewModel.email.isEmpty && !viewModel.isEmailValid {
                                Text("Please enter a valid email")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        // Password field
                        VStack(alignment: .leading, spacing: 8) {
                            SecureField("Password", text: $viewModel.password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .focused($focusedField, equals: .password)
                                .onSubmit {
                                    if viewModel.isSignUpMode {
                                        focusedField = .confirmPassword
                                    } else {
                                        Task {
                                            await viewModel.signIn()
                                        }
                                    }
                                }
                            
                            if viewModel.isSignUpMode && !viewModel.password.isEmpty {
                                HStack {
                                    Text("Password strength:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text(viewModel.passwordStrength.text)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(viewModel.passwordStrength.color)
                                }
                            }
                        }
                        
                        // Confirm password (sign up only)
                        if viewModel.isSignUpMode {
                            VStack(alignment: .leading, spacing: 8) {
                                SecureField("Confirm Password", text: $viewModel.confirmPassword)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .focused($focusedField, equals: .confirmPassword)
                                    .onSubmit {
                                        focusedField = .fullName
                                    }
                                
                                if !viewModel.confirmPassword.isEmpty && !viewModel.passwordsMatch {
                                    Text("Passwords don't match")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                            
                            // Full Name field
                            TextField("Full Name", text: $viewModel.fullName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .focused($focusedField, equals: .fullName)
                                .onSubmit {
                                    // The last field in the form, so Return
                                    // submits. `signUp` is guarded by
                                    // `canSubmit`, so this is the same action
                                    // as the button and no weaker.
                                    Task {
                                        await viewModel.signUp()
                                    }
                                }

                            // Gender toggle
                            HStack {
                                Text("Gender:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Picker("Gender", selection: $viewModel.isMale) {
                                    Text("Male").tag(true)
                                    Text("Female").tag(false)
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .frame(width: 150)
                            }
                        }
                        
                        // Error message
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // Submit button
                        Button(action: {
                            Task {
                                if viewModel.isSignUpMode {
                                    await viewModel.signUp()
                                } else {
                                    await viewModel.signIn()
                                }
                            }
                        }) {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text(viewModel.isSignUpMode ? "Create Account" : "Sign In")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(viewModel.canSubmit ? themeManager.accentColor.color : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(!viewModel.canSubmit)
                        
                        // Toggle mode button
                        Button(action: {
                            viewModel.toggleMode()
                        }) {
                            HStack {
                                Text(viewModel.isSignUpMode ? "Already have an account?" : "Don't have an account?")
                                    .foregroundColor(.secondary)
                                
                                Text(viewModel.isSignUpMode ? "Sign In" : "Sign Up")
                                    .fontWeight(.semibold)
                                    .foregroundColor(themeManager.accentColor.color)
                            }
                            .font(.footnote)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 50)
                }
            }
        }
        }
    }
}

#Preview {
    LoginView()
}