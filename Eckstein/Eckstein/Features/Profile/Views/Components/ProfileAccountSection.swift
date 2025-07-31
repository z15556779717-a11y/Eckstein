//
//  ProfileAccountSection.swift
//  Eckstein
//
//  Created by Eliad Shahar on 23/07/2025.
//

import SwiftUI

struct ProfileAccountSection: View {
    @Binding var showingSignOutAlert: Bool
    
    @ViewBuilder
    var body: some View {
        Section {
            Button(action: {
                showingSignOutAlert = true
            }) {
                HStack {
                    Image(systemName: "arrow.right.square")
                        .foregroundColor(.red)
                    Text("sign_out".localized)
                        .foregroundColor(.red)
                }
            }
        } header: {
            Text("account".localized)
        }
    }
}