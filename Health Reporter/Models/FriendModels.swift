//
//  FriendModels.swift
//  Health Reporter
//
//  מודלים לניהול חברים ובקשות חברות.
//

import Foundation

// MARK: - Friend

struct Friend: Codable {
    let uid: String
    let displayName: String
    var photoURL: String?  // mutable to allow fallback from publicScores
    let addedAt: Date

    // Cached score data for leaderboard display
    var healthScore: Int?
    var carTierIndex: Int?
    var carTierName: String?
}

// MARK: - Friend Request

struct FriendRequest: Codable, Identifiable {
    let id: String
    let fromUid: String
    let fromDisplayName: String
    let fromPhotoURL: String?
    let toUid: String
    let status: FriendRequestStatus
    let createdAt: Date
    let updatedAt: Date?
}

enum FriendRequestStatus: String, Codable {
    case pending
    case accepted
    case declined
}

// MARK: - Leaderboard Entry

struct LeaderboardEntry: Codable, Identifiable {
    var id: String { uid }

    let uid: String
    let displayName: String
    let photoURL: String?
    let healthScore: Int
    let carTierIndex: Int
    let carTierName: String
    let carTierLabel: String
    let lastUpdated: Date
    let isPublic: Bool

    // Computed locally when displaying
    var rank: Int?
    var isCurrentUser: Bool = false
}

// MARK: - User Search Result

struct UserSearchResult: Codable, Identifiable {
    var id: String { uid }

    let uid: String
    let displayName: String
    var photoURL: String?  // mutable to allow fallback from publicScores

    // Relationship status with current user
    var isFriend: Bool = false
    var hasPendingRequest: Bool = false
    var requestSentByMe: Bool = false

    // Health score / car tier (from publicScores)
    var healthScore: Int?
    var carTierIndex: Int?
    var carTierName: String?
}
