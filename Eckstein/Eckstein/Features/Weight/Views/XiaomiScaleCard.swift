//
//  XiaomiScaleCard.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

struct XiaomiScaleCard: View {
    let isConnected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "wifi")
                .font(.title2)
                .foregroundColor(isConnected ? .green : .gray)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("xiaomi_scale".localized)
                    .font(.headline)
                
                Text(isConnected ? "connected".localized : "xiaomi_scale_not_connected".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {}) {
                Text(isConnected ? "settings".localized : "xiaomi_scale_connect".localized)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}