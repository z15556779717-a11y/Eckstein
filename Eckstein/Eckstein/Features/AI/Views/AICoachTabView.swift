//
//  AICoachTabView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

struct AICoachTabView: View {
    @StateObject private var viewModel = AICoachViewModel()
    @StateObject private var openAIService = OpenAIService.shared
    @State private var showingAPIKeySettings = false
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [themeManager.accentColor.color.opacity(0.1), themeManager.accentColor.color.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                Group {
                    if openAIService.hasAPIKey {
                        AIChatView(viewModel: viewModel)
                    } else {
                        VStack(spacing: 20) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            
                            Text("API Key Required")
                                .font(.title)
                                .fontWeight(.semibold)
                            
                            Text("To use the AI Coach feature, you need to configure your OpenAI API key.")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            Button(action: { showingAPIKeySettings = true }) {
                                Label("Configure API Key", systemImage: "key")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.horizontal)
                        }
                        .padding()
                        .navigationTitle("AI Coach")
                    }
                }
                .toolbar {
                    if openAIService.hasAPIKey {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: { showingAPIKeySettings = true }) {
                                Image(systemName: "gearshape")
                            }
                        }
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .checkAIDisclaimer()
        .sheet(isPresented: $showingAPIKeySettings) {
            APIKeySettingsView()
        }
    }
}