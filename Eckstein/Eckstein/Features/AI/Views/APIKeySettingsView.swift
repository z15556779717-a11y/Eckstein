//
//  APIKeySettingsView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

struct APIKeySettingsView: View {
    @StateObject private var openAIService = OpenAIService.shared
    @State private var apiKey: String = ""
    @State private var showingKey = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text("API Key Status")
                        Spacer()
                        if openAIService.hasAPIKey {
                            Label("Configured", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        } else {
                            Label("Not Set", systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("Status")
                }
                
                Section {
                    if showingKey {
                        SecureField("Enter OpenAI API Key", text: $apiKey)
                            .textContentType(.password)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    } else {
                        TextField("Enter OpenAI API Key", text: $apiKey)
                            .textContentType(.password)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    Toggle("Show API Key", isOn: $showingKey)
                    
                    Button(action: saveAPIKey) {
                        Label("Save API Key", systemImage: "key.fill")
                    }
                    .disabled(apiKey.isEmpty)
                    
                    if openAIService.hasAPIKey {
                        Button(action: removeAPIKey) {
                            Label("Remove API Key", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                    }
                } header: {
                    Text("OpenAI Configuration")
                } footer: {
                    Text("Get your API key from https://platform.openai.com/api-keys")
                        .font(.caption)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How to get an API Key:")
                            .font(.headline)
                        
                        Text("1. Visit https://platform.openai.com")
                        Text("2. Sign up or log in to your account")
                        Text("3. Go to API Keys section")
                        Text("4. Click 'Create new secret key'")
                        Text("5. Copy the key and paste it above")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                } header: {
                    Text("Instructions")
                }
                
                if openAIService.totalTokensUsed > 0 {
                    Section {
                        HStack {
                            Text("Total Tokens Used")
                            Spacer()
                            Text("\(openAIService.totalTokensUsed)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Estimated Cost")
                            Spacer()
                            Text(String(format: "$%.4f", openAIService.estimatedCost))
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Usage")
                    } footer: {
                        Text("Cost estimates based on GPT-4o-mini pricing")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("AI Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("API Key", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
        .onAppear {
            // Load existing key if any (masked for security)
            if openAIService.hasAPIKey {
                apiKey = "sk-...configured"
            }
        }
    }
    
    private func saveAPIKey() {
        guard !apiKey.isEmpty else { return }
        
        // Basic validation
        if !apiKey.starts(with: "sk-") {
            alertMessage = "Invalid API key format. OpenAI keys start with 'sk-'"
            showingAlert = true
            return
        }
        
        openAIService.saveAPIKey(apiKey)
        alertMessage = "API key saved successfully"
        showingAlert = true
        
        // Clear the field for security
        apiKey = "sk-...configured"
    }
    
    private func removeAPIKey() {
        openAIService.removeAPIKey()
        apiKey = ""
        alertMessage = "API key removed"
        showingAlert = true
    }
}

#Preview {
    APIKeySettingsView()
}