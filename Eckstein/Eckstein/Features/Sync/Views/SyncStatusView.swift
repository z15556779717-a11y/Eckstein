//
//  SyncStatusView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

struct SyncStatusView: View {
    @StateObject private var syncManager = SyncManager.shared
    @State private var showingSyncHistory = false
    @State private var showingDebugView = false
    @State private var showingTestView = false
    @State private var showingNetworkDiagnostics = false
    @State private var showingDirectTest = false
    @State private var showingDataValidation = false
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Compact Status Bar
            HStack {
                // Sync Icon
                Image(systemName: syncIcon)
                    .foregroundColor(syncColor)
                    .imageScale(.medium)
                
                // Status Text
                Text(syncManager.syncStatus)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Pending Changes Badge
                if syncManager.pendingChangesCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .imageScale(.small)
                        Text("\(syncManager.pendingChangesCount)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.orange)
                }
                
                // Expand/Collapse Button
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .imageScale(.small)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            
            // Expanded Content
            if isExpanded {
                VStack(spacing: 16) {
                    // Progress Bar
                    if syncManager.isSyncing {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Syncing...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("\(Int(syncManager.syncProgress * 100))%")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            ProgressView(value: syncManager.syncProgress)
                                .tint(.blue)
                        }
                    }
                    
                    // Quick Stats
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Last Sync")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(lastSyncText)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        Divider()
                            .frame(height: 30)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pending")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(syncManager.pendingChangesCount) changes")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(syncManager.pendingChangesCount > 0 ? .orange : .primary)
                        }
                        
                        Spacer()
                    }
                    
                    // Action Buttons
                    HStack(spacing: 12) {
                        // Manual Sync Button
                        Button {
                            syncManager.triggerManualSync()
                        } label: {
                            Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .disabled(syncManager.isSyncing)
                        
                        // History Button
                        Button {
                            showingSyncHistory = true
                        } label: {
                            Label("History", systemImage: "clock")
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray5))
                                .foregroundColor(.primary)
                                .cornerRadius(8)
                        }
                    }
                    
                    // Settings
                    VStack(spacing: 12) {
                        Toggle(isOn: $syncManager.automaticSync) {
                            Label("Automatic Sync", systemImage: "arrow.triangle.2.circlepath.circle")
                                .font(.caption)
                        }
                        .tint(.green)
                        
                        Toggle(isOn: $syncManager.syncOnWiFiOnly) {
                            Label("WiFi Only", systemImage: "wifi")
                                .font(.caption)
                        }
                        .tint(.blue)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    // Debug section (only in DEBUG builds)
                    #if DEBUG
                    VStack(spacing: 8) {
                        Text("Debug Tools")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Button {
                            syncManager.createTestSyncOperation()
                        } label: {
                            Label("Create Test Sync Data", systemImage: "ladybug")
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.purple.opacity(0.2))
                                .foregroundColor(.purple)
                                .cornerRadius(6)
                        }
                        
                        Button {
                            syncManager.testSyncWithCoreData()
                        } label: {
                            Label("Test Core Data Sync", systemImage: "externaldrive.badge.plus")
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.indigo.opacity(0.2))
                                .foregroundColor(.indigo)
                                .cornerRadius(6)
                        }
                        
                        Button {
                            syncManager.testSync()
                        } label: {
                            Label("Debug Sync Status", systemImage: "stethoscope")
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(6)
                        }
                        
                        Button {
                            showingDebugView = true
                        } label: {
                            Label("Open Debug Console", systemImage: "terminal")
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(6)
                        }
                        
                        Button {
                            showingTestView = true
                        } label: {
                            Label("API Test View", systemImage: "network")
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.2))
                                .foregroundColor(.red)
                                .cornerRadius(6)
                        }
                        
                        Button {
                            showingNetworkDiagnostics = true
                        } label: {
                            Label("Network Diagnostics", systemImage: "wifi.exclamationmark")
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(6)
                        }
                        
                        Button {
                            showingDirectTest = true
                        } label: {
                            Label("Direct Sync Test", systemImage: "bolt.fill")
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.yellow.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(6)
                        }
                        
                        Button {
                            showingDataValidation = true
                        } label: {
                            Label("Validate Data", systemImage: "checkmark.shield")
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.purple.opacity(0.2))
                                .foregroundColor(.purple)
                                .cornerRadius(6)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    #endif
                }
                .padding()
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .background(Color(.systemGray6))
        .sheet(isPresented: $showingSyncHistory) {
            SyncHistoryView()
        }
        .sheet(isPresented: $showingDebugView) {
            SyncDebugView()
        }
        .sheet(isPresented: $showingTestView) {
            SyncTestView()
        }
        .sheet(isPresented: $showingNetworkDiagnostics) {
            NetworkDiagnosticsView()
        }
        .sheet(isPresented: $showingDirectTest) {
            DirectSyncTestView()
        }
        .sheet(isPresented: $showingDataValidation) {
            DataValidationView()
        }
    }
    
    private var syncIcon: String {
        if syncManager.isSyncing {
            return "arrow.triangle.2.circlepath.circle.fill"
        } else if syncManager.pendingChangesCount > 0 {
            return "exclamationmark.arrow.circlepath"
        } else {
            return "checkmark.circle.fill"
        }
    }
    
    private var syncColor: Color {
        if syncManager.isSyncing {
            return .blue
        } else if syncManager.pendingChangesCount > 0 {
            return .orange
        } else {
            return .green
        }
    }
    
    private var lastSyncText: String {
        if let lastSync = syncManager.lastSyncDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: lastSync, relativeTo: Date())
        } else {
            return "Never"
        }
    }
}

// MARK: - Sync Status Badge

struct SyncStatusBadge: View {
    @StateObject private var syncManager = SyncManager.shared
    
    var body: some View {
        HStack(spacing: 4) {
            if syncManager.isSyncing {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Image(systemName: iconName)
                    .foregroundColor(iconColor)
            }
            
            if syncManager.pendingChangesCount > 0 {
                Text("\(syncManager.pendingChangesCount)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange)
                    .cornerRadius(10)
            }
        }
    }
    
    private var iconName: String {
        if syncManager.pendingChangesCount > 0 {
            return "arrow.up.circle.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }
    
    private var iconColor: Color {
        if syncManager.pendingChangesCount > 0 {
            return .orange
        } else {
            return .green
        }
    }
}

#Preview {
    VStack {
        SyncStatusView()
        Spacer()
    }
}