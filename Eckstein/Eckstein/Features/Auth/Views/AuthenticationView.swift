//
//  AuthenticationView.swift
//  Eckstein
//
//  Created by Assistant on 15/01/2025.
//

import SwiftUI

struct AuthenticationView: View {
    @StateObject private var authService = AuthService.shared
    @State private var showSplash = true
    @State private var showWelcomeGuide = false
    
    var body: some View {
        Group {
            if showSplash {
                // Splash screen
                SplashView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation {
                                showSplash = false
                            }
                        }
                    }
            } else if authService.isAuthenticated {
                // Main app
                ContentView()
                    .transition(.opacity)
                    .onAppear {
                        // Check for welcome guide after transitioning to main app
                        checkAndShowWelcomeGuide()
                    }
            } else {
                // Login screen
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: showSplash)
        .fullScreenCover(isPresented: $showWelcomeGuide) {
            AppUsageGuideView(userId: authService.currentUser?.id.uuidString) {
                // Mark as seen and dismiss
                let userId = authService.currentUser?.id.uuidString ?? ""
                UserDefaults.standard.set(true, forKey: "hasSeenWelcome_\(userId)")
                showWelcomeGuide = false
            }
        }
    }
    
    private func checkAndShowWelcomeGuide() {
        let userId = authService.currentUser?.id.uuidString ?? ""
        
        // TEMPORARY: Always show welcome guide for testing
        // Remove this line after testing
        UserDefaults.standard.removeObject(forKey: "hasSeenWelcome_\(userId)")
        
        let hasSeenWelcome = UserDefaults.standard.bool(forKey: "hasSeenWelcome_\(userId)")
        let neverShowGuide = UserDefaults.standard.bool(forKey: "neverShowGuide_\(userId)")
        
        print("🔵 AuthenticationView: Checking welcome guide for user \(userId)")
        print("🔵 AuthenticationView: Has seen welcome: \(hasSeenWelcome)")
        print("🔵 AuthenticationView: Never show guide: \(neverShowGuide)")
        
        if !hasSeenWelcome && !neverShowGuide {
            print("🔵 AuthenticationView: Showing welcome guide")
            showWelcomeGuide = true
        } else {
            print("🔵 AuthenticationView: Skipping welcome")
        }
    }
}

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [ThemeManager.shared.accentColor.color.opacity(0.1), ThemeManager.shared.accentColor.color.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 100))
                    .foregroundColor(ThemeManager.shared.accentColor.color)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                
                Text("Eckstein")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .opacity(logoOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
        }
    }
}

#Preview {
    AuthenticationView()
}