//
//  ProfileView.swift
//  Eckstein
//
//  Created by Assistant on 15/01/2025.
//

import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var weightRepository = WeightRepository.shared
    @StateObject private var tipManager = TipManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    @State private var showingSignOutAlert = false
    @State private var showingDietSettings = false
    @State private var isLoading = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImage: Image?
    @State private var showingAppGuide = false
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [themeManager.accentColor.color.opacity(0.1), themeManager.accentColor.color.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                List {
                    // User Info Section
                    ProfileUserInfoSection(
                        selectedPhoto: $selectedPhoto,
                        profileImage: $profileImage,
                        userName: userName,
                        userEmail: userEmail,
                        joinDate: appCoordinator.currentUser?.createdAt,
                        themeManager: themeManager
                    )
                    
                    // Diet Progress Section
                    ProfileDietProgressSection(
                        themeManager: themeManager,
                        weightRepository: weightRepository,
                        showingDietSettings: $showingDietSettings
                    )
                    
                    // Weight Goal Section
                    ProfileWeightGoalSection(
                        themeManager: themeManager,
                        weightRepository: weightRepository
                    )
                    
                    // Meeting Section
                    ProfileMeetingSection(themeManager: themeManager)
                    
                    // Settings Section
                    Section {
                        ProfileSettingsSection(
                            showingAppGuide: $showingAppGuide,
                            tipManager: tipManager,
                            themeManager: themeManager
                        )
                    } header: {
                        Text("settings".localized)
                            .textCase(nil)
                    }
                    
                    // Language Section
                    ProfileLanguageSection(
                        localizationManager: localizationManager,
                        themeManager: themeManager
                    )
                    
                    // Appearance Section
                    ProfileAppearanceSection(themeManager: themeManager)
                    
                    // Account Section
                    ProfileAccountSection(showingSignOutAlert: $showingSignOutAlert)
                }
            .listStyle(InsetGroupedListStyle())
            .scrollContentBackground(.hidden)
            .navigationTitle("profile".localized)
            .navigationBarTitleDisplayMode(.large)
            .environment(\.layoutDirection, localizationManager.layoutDirection)
            .onChange(of: selectedPhoto) { _ in
                Task {
                    if let selectedPhoto = selectedPhoto {
                        if let data = try? await selectedPhoto.loadTransferable(type: Data.self) {
                            if let uiImage = UIImage(data: data) {
                                profileImage = Image(uiImage: uiImage)
                                // TODO: Save image to user profile
                            }
                        }
                    }
                }
            }
            .alert("sign_out".localized, isPresented: $showingSignOutAlert) {
                Button("cancel".localized, role: .cancel) { }
                Button("sign_out".localized, role: .destructive) {
                    Task {
                        await signOut()
                    }
                }
            } message: {
                Text("sign_out_confirm".localized)
            }
            .sheet(isPresented: $showingDietSettings) {
                DietSettingsSheet(isPresented: $showingDietSettings)
            }
            .sheet(isPresented: $showingAppGuide) {
                AppUsageGuideView(userId: appCoordinator.currentUser?.id.uuidString) {
                    showingAppGuide = false
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                }
            }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Computed Properties
    
    private var userName: String {
        if let user = appCoordinator.currentUser {
            // Try to get full name from UserDefaults first
            if let fullName = UserDefaults.standard.string(forKey: "user_fullname_\(user.id.uuidString)"),
               !fullName.isEmpty {
                return fullName
            }
            
            // Try to get display name
            if let displayName = UserDefaults.standard.string(forKey: "userDisplayName_\(user.id.uuidString)"),
               !displayName.isEmpty {
                return displayName
            }
            
            // Fall back to email username
            if let email = user.email {
                return email.components(separatedBy: "@").first ?? "User"
            }
        }
        return "User"
    }
    
    private var userEmail: String {
        appCoordinator.currentUser?.email ?? "No email"
    }
    
    private var userId: String {
        appCoordinator.currentUser?.id.uuidString ?? "Unknown"
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    // MARK: - Methods
    
    private func signOut() async {
        isLoading = true
        
        do {
            try await appCoordinator.signOut()
        } catch {
            print("Sign out error: \(error)")
        }
        
        isLoading = false
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppCoordinator())
}