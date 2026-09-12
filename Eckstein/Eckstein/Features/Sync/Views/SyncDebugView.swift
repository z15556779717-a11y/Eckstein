//
//  SyncDebugView.swift
//  Eckstein
//
//  Created by Assistant on 15/07/2025.
//

import SwiftUI

struct SyncDebugView: View {
    @StateObject private var syncManager = SyncManager.shared
    @State private var debugOutput: String = ""
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Status Section
                    GroupBox("Sync Status") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Status:")
                                Text(syncManager.syncStatus)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Pending Changes:")
                                Text("\(syncManager.pendingChangesCount)")
                                    .foregroundColor(syncManager.pendingChangesCount > 0 ? .orange : .green)
                            }
                            
                            HStack {
                                Text("Last Sync:")
                                if let lastSync = syncManager.lastSyncDate {
                                    Text(lastSync, style: .relative)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Never")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Test Actions
                    GroupBox("Test Actions") {
                        VStack(spacing: 12) {
                            Button(action: testDirectSync) {
                                Label("Test Direct Sync", systemImage: "arrow.triangle.2.circlepath")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isLoading)
                            
                            Button(action: createTestData) {
                                Label("Create Test User & Meal", systemImage: "plus.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(isLoading)
                            
                            Button(action: clearDebugOutput) {
                                Label("Clear Output", systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            
                            Button(action: checkConfiguration) {
                                Label("Check Configuration", systemImage: "checkmark.shield")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.green)
                        }
                    }
                    
                    // Debug Output
                    GroupBox("Debug Output") {
                        ScrollView {
                            Text(debugOutput.isEmpty ? "No output yet..." : debugOutput)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .frame(height: 300)
                    }
                    
                    if isLoading {
                        ProgressView("Processing...")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("Sync Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func testDirectSync() {
        isLoading = true
        debugOutput += "\n\n--- STARTING DIRECT SYNC TEST ---\n"
        
        Task {
            // First check if we can connect to Supabase at all
            debugOutput += "Testing Supabase connection...\n"
            
            do {
                // Try a simple query first
                let testQuery = SupabaseService.shared.client
                    .from("eckstein_meals")
                    .select()
                    .limit(1)
                
                debugOutput += "Executing test query...\n"
                let testResponse = try await testQuery.execute()
                debugOutput += "✅ Supabase connection successful!\n"
                debugOutput += "Response status: \(testResponse.status)\n"
                
                // Now try to create a record
                let testData: [String: Any] = [
                    "id": UUID().uuidString,
                    "user_id": "00000000-0000-0000-0000-000000000001",
                    "date": "2025-07-15",
                    "meal_number": 1,
                    "total_calories": 500,
                    "total_protein": 50.0,
                    "total_carbs": 60.0,
                    "total_fat": 20.0,
                    "created_at": ISO8601DateFormatter().string(from: Date()),
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ]
                
                debugOutput += "\nTest data:\n"
                
                // Validate JSON
                if JSONSerialization.isValidJSONObject(testData) {
                    debugOutput += "✅ JSON validation passed\n"
                    
                    let jsonData = try JSONSerialization.data(withJSONObject: testData, options: .prettyPrinted)
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        debugOutput += "JSON:\n\(jsonString)\n"
                    }
                    
                    // Try to create directly
                    debugOutput += "\nAttempting to insert record...\n"
                    
                    // Use raw HTTP request to see actual error
                    let url = URL(string: "rest/v1/eckstein_meals", relativeTo: AppEnvironment.supabaseURL)!
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(AppEnvironment.supabasePublishableKey)", forHTTPHeaderField: "Authorization")
                    request.setValue(AppEnvironment.supabasePublishableKey, forHTTPHeaderField: "apikey")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("return=representation", forHTTPHeaderField: "Prefer")
                    request.httpBody = jsonData
                    
                    let (data, response) = try await URLSession.shared.data(for: request)
                    
                    if let httpResponse = response as? HTTPURLResponse {
                        debugOutput += "HTTP Status: \(httpResponse.statusCode)\n"
                        
                        if let responseString = String(data: data, encoding: .utf8) {
                            debugOutput += "Raw response:\n\(responseString)\n"
                            
                            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                                debugOutput += "✅ Direct sync successful!\n"
                            } else {
                                debugOutput += "❌ Server returned error\n"
                            }
                        }
                    }
                } else {
                    debugOutput += "❌ JSON validation failed\n"
                }
            } catch {
                debugOutput += "❌ Error: \(error)\n"
                
                // Enhanced error parsing
                let nsError = error as NSError
                debugOutput += "Domain: \(nsError.domain)\n"
                debugOutput += "Code: \(nsError.code)\n"
                    
                // Try to extract more info from the error
                if let errorDescription = nsError.userInfo[NSLocalizedDescriptionKey] as? String {
                    debugOutput += "Description: \(errorDescription)\n"
                }
                
                if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                    debugOutput += "Underlying error: \(underlyingError)\n"
                }
                
                // Check if it's a response body error
                if let responseData = nsError.userInfo["responseData"] as? Data,
                   let responseString = String(data: responseData, encoding: .utf8) {
                    debugOutput += "Response body: \(responseString)\n"
                }
                
                debugOutput += "Full error info: \(nsError.userInfo)\n"
            }
            
            isLoading = false
        }
    }
    
    private func createTestData() {
        isLoading = true
        debugOutput += "\n\n--- CREATING TEST DATA ---\n"
        
        Task { @MainActor in
            let context = PersistenceController.shared.container.viewContext
            
            // Create test user if needed
            let userRequest = CDUser.fetchRequest()
            userRequest.predicate = NSPredicate(format: "id == %@", UUID(uuidString: "00000000-0000-0000-0000-000000000001")! as CVarArg)
            
            let users = try? context.fetch(userRequest)
            let user: CDUser
            
            if let existingUser = users?.first {
                user = existingUser
                debugOutput += "Using existing test user\n"
            } else {
                user = CDUser(context: context)
                user.id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")
                user.email = "test@example.com"
                user.createdAt = Date()
                user.updatedAt = Date()
                debugOutput += "Created new test user\n"
            }
            
            // Create test meal
            let meal = CDEcksteinMeal(context: context)
            meal.id = UUID()
            meal.date = Date()
            meal.mealNumber = 1
            meal.user = user
            
            debugOutput += "Created test meal with ID: \(meal.id?.uuidString ?? "nil")\n"
            
            do {
                try context.save()
                debugOutput += "✅ Saved to Core Data\n"
                debugOutput += "Waiting for automatic sync...\n"
                
                // Check sync queue after a delay
                try await Task.sleep(nanoseconds: 2_000_000_000)
                debugOutput += "Pending sync operations: \(syncManager.pendingChangesCount)\n"
                
                // Trigger manual sync
                await syncManager.performSync()
                
            } catch {
                debugOutput += "❌ Core Data save error: \(error)\n"
            }
            
            isLoading = false
        }
    }
    
    private func clearDebugOutput() {
        debugOutput = ""
    }
    
    private func checkConfiguration() {
        debugOutput += "\n\n--- CONFIGURATION CHECK ---\n"
        
        // Check environment. SECURITY: never print the URL or any key material
        // (prefixes included) -- they leak into the device console and sysdiagnose.
        debugOutput += "Supabase configured: \(AppEnvironment.isSupabaseConfigured)\n"
        debugOutput += "AI backend configured: \(AppEnvironment.isSupabaseConfigured)\n"
        debugOutput += "Supabase configured: \(AppEnvironment.isSupabaseConfigured)\n"
        
        // Check network
        debugOutput += "\nNetwork Status:\n"
        debugOutput += "Connected: \(NetworkMonitor.shared.isConnected)\n"
        debugOutput += "Connection Type: \(NetworkMonitor.shared.connectionType)\n"
        debugOutput += "Is Expensive: \(NetworkMonitor.shared.isExpensive)\n"
        
        // Check sync status
        debugOutput += "\nSync Status:\n"
        debugOutput += "Pending changes: \(syncManager.pendingChangesCount)\n"
        debugOutput += "Last sync: \(syncManager.lastSyncDate?.description ?? "Never")\n"
        debugOutput += "Automatic sync: \(syncManager.automaticSync)\n"
        debugOutput += "WiFi only: \(syncManager.syncOnWiFiOnly)\n"
    }
}

#Preview {
    SyncDebugView()
}