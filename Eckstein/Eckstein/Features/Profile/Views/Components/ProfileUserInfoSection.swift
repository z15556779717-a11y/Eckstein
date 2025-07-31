//
//  ProfileUserInfoSection.swift
//  Eckstein
//
//  Created by Eliad Shahar on 23/07/2025.
//

import SwiftUI
import PhotosUI

struct ProfileUserInfoSection: View {
    @Binding var selectedPhoto: PhotosPickerItem?
    @Binding var profileImage: Image?
    let userName: String
    let userEmail: String
    let joinDate: Date?
    @ObservedObject var themeManager: ThemeManager
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    @ViewBuilder
    var body: some View {
        Section {
            HStack {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    if let profileImage = profileImage {
                        profileImage
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .themedForegroundColor(themeManager.accentColor, context: .general)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(userName)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(userEmail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let joinDate = joinDate {
                        Text("Member since \(joinDate, formatter: dateFormatter)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.leading, 8)
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
}