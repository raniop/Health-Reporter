//
//  FriendModels.swift
//  Health Reporter
//
//  מודלים לניהול עוקבים, בקשות מעקב ולידרבורד.
//

import Foundation

// MARK: - Follow Relation

struct FollowRelation: Codable {
    let uid: String
    let displayName: String
    var photoURL: String?
    let followedAt: Date

    // Cached score data for leaderboard display
    var healthScore: Int?
    var carTierIndex: Int?
    var carTierName: String?
}

/// Backward compatibility alias
typealias Friend = FollowRelation

// MARK: - Follow Request

struct FollowRequest: Codable, Identifiable {
    let id: String
    let fromUid: String
    let fromDisplayName: String
    let fromPhotoURL: String?
    let toUid: String
    let status: FollowRequestStatus
    let createdAt: Date
    let updatedAt: Date?
}

/// Backward compatibility alias
typealias FriendRequest = FollowRequest

enum FollowRequestStatus: String, Codable {
    case pending
    case accepted
    case declined
}

/// Backward compatibility alias
typealias FriendRequestStatus = FollowRequestStatus

// MARK: - Follow Privacy

enum FollowPrivacy: String, Codable {
    case open       // Anyone can follow instantly
    case approval   // Follow requires approval
}

// MARK: - Rank Change

struct RankChange {
    let previousRank: Int?
    let currentRank: Int

    enum Direction {
        case up, down, same, new
    }

    var direction: Direction {
        guard let prev = previousRank else { return .new }
        if currentRank < prev { return .up }
        if currentRank > prev { return .down }
        return .same
    }

    var delta: Int {
        guard let prev = previousRank else { return 0 }
        return abs(prev - currentRank)
    }
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
    var photoURL: String?

    // Relationship status with current user
    var isFollowing: Bool = false
    var isFollowedBy: Bool = false
    var hasPendingRequest: Bool = false
    var requestSentByMe: Bool = false

    /// Backward compatibility
    var isFriend: Bool {
        get { isFollowing }
        set { isFollowing = newValue }
    }

    // Health score / car tier (from publicScores)
    var healthScore: Int?
    var carTierIndex: Int?
    var carTierName: String?
}
