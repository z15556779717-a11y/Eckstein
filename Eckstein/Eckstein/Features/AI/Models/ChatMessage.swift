//
//  ChatMessage.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation
import CoreData

struct ChatMessage: Identifiable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date
    
    init(id: UUID = UUID(), content: String, isUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
    }
    
    init(from cdMessage: CDChatMessage) {
        self.id = cdMessage.id ?? UUID()
        self.content = cdMessage.content ?? ""
        self.isUser = cdMessage.isUser
        self.timestamp = cdMessage.timestamp ?? Date()
    }
}