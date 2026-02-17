//
//  ChatModels.swift
//  Health Reporter
//
//  Data models for 1-on-1 chat conversations and messages.
//

import Foundation

// MARK: - Chat Conversation

struct ChatConversation: Identifiable {
    let id: String                          // chatId (deterministic: sorted UIDs joined by "_")
    let participants: [String]
    let participantProfiles: [String: ChatUserProfile]
    let lastMessage: ChatLastMessage?
    let lastMessageTimestamp: Date?
    let createdAt: Date
    var unreadCount: Int

    /// Returns the other participant's UID
    func otherParticipantUid(currentUid: String) -> String? {
        participants.first { $0 != currentUid }
    }

    /// Returns the other participant's profile
    func otherParticipantProfile(currentUid: String) -> ChatUserProfile? {
        guard let otherUid = otherParticipantUid(currentUid: currentUid) else { return nil }
        return participantProfiles[otherUid]
    }
}

struct ChatUserProfile {
    let displayName: String
    let photoURL: String?
}

struct ChatLastMessage {
    let text: String
    let senderUid: String
    let timestamp: Date
    let type: String
}

// MARK: - Chat Message

struct ChatMessage: Identifiable {
    let id: String                          // Firestore document ID
    let senderUid: String
    let text: String
    let timestamp: Date
    let type: String                        // "text"
    var status: ChatMessageStatus
}

enum ChatMessageStatus: String {
    case sent
    case delivered
    case seen
}

// MARK: - Helper

enum ChatHelper {
    /// Generates deterministic chatId from two UIDs (sorted alphabetically, joined by "_")
    static func chatId(uid1: String, uid2: String) -> String {
        let sorted = [uid1, uid2].sorted()
        return "\(sorted[0])_\(sorted[1])"
    }
}
