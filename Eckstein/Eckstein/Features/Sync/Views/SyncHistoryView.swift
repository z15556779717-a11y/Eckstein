//
//  SyncHistoryView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

struct SyncHistoryView: View {
    @StateObject private var syncManager = SyncManager.shared
    @Environment(\.dismiss) private var dismiss
    
    private var syncHistory: [SyncHistoryEntry] {
        syncManager.getSyncHistory().reversed()
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                if syncHistory.isEmpty {
                    EmptyHistoryView()
                        .padding(.top, 100)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(syncHistory) { entry in
                            SyncHistoryRow(entry: entry)
                        }
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("sync_history_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SyncHistoryRow: View {
    let entry: SyncHistoryEntry
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                // Status Icon
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                    .font(.title3)
                
                // Timestamp and Direction
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.timestamp, style: .date)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 4) {
                        Image(systemName: directionIcon)
                            .imageScale(.small)
                        Text(entry.direction.displayName)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Summary Stats
                VStack(alignment: .trailing, spacing: 4) {
                    if entry.result.successful > 0 {
                        HStack(spacing: 4) {
                            Text("\(entry.result.successful)")
                                .fontWeight(.semibold)
                            Image(systemName: "checkmark.circle.fill")
                                .imageScale(.small)
                        }
                        .font(.caption)
                        .foregroundColor(.green)
                    }
                    
                    if entry.result.failed > 0 || entry.result.conflicts > 0 {
                        HStack(spacing: 4) {
                            Text("\(entry.result.failed + entry.result.conflicts)")
                                .fontWeight(.semibold)
                            Image(systemName: "exclamationmark.circle.fill")
                                .imageScale(.small)
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                }
                
                // Expand Button
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
            
            // Expanded Details
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    // Detailed Stats
                    HStack(spacing: 20) {
                        SyncStatItem(
                            label: "sync_stat_successful".localized,
                            value: "\(entry.result.successful)",
                            color: .green
                        )
                        
                        SyncStatItem(
                            label: "sync_stat_failed".localized,
                            value: "\(entry.result.failed)",
                            color: .red
                        )
                        
                        SyncStatItem(
                            label: "sync_stat_conflicts".localized,
                            value: "\(entry.result.conflicts)",
                            color: .orange
                        )
                        
                        Spacer()
                        
                        SyncStatItem(
                            label: "duration".localized,
                            value: String(format: "%.1fs", entry.result.duration),
                            color: .blue
                        )
                    }
                    
                    // Errors if any
                    if !entry.result.errors.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("sync_errors".localized)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            
                            ForEach(entry.result.errors.indices, id: \.self) { index in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                        .imageScale(.small)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.result.errors[index].operation.entityName)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        
                                        Text(entry.result.errors[index].error.localizedDescription)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var statusIcon: String {
        if entry.result.failed > 0 || entry.result.conflicts > 0 {
            return "exclamationmark.circle.fill"
        } else if entry.result.successful > 0 {
            return "checkmark.circle.fill"
        } else {
            return "minus.circle.fill"
        }
    }
    
    private var statusColor: Color {
        if entry.result.failed > 0 || entry.result.conflicts > 0 {
            return .red
        } else if entry.result.successful > 0 {
            return .green
        } else {
            return .gray
        }
    }
    
    private var directionIcon: String {
        switch entry.direction {
        case .upload:
            return "arrow.up"
        case .download:
            return "arrow.down"
        case .bidirectional:
            return "arrow.up.arrow.down"
        }
    }
}

struct SyncStatItem: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("sync_history_empty_title".localized)
                .font(.headline)
                .foregroundColor(.primary)

            Text("sync_history_empty_message".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

#Preview {
    SyncHistoryView()
}