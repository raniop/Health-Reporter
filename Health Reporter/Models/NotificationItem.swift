//
//  NotificationItem.swift
//  Health Reporter
//
//  Model for notification center items stored in Firestore.
//

import Foundation

enum NotificationType: String, Codable {
    case followRequest = "follow_request"
    case followAccepted = "follow_accepted"
    case newFollower = "new_follower"
    case morningSummary = "morning_summary"
    case healthMilestone = "health_milestone"

    var icon: String {
        switch self {
        case .followRequest: return "person.badge.plus"
        case .followAccepted: return "person.fill.checkmark"
        case .newFollower: return "person.2.fill"
        case .morningSummary: return "sun.horizon.fill"
        case .healthMilestone: return "trophy.fill"
        }
    }
}

struct NotificationItem: Identifiable {
    let id: String
    let type: NotificationType
    let title: String
    let body: String
    let data: [String: Any]
    var read: Bool
    let createdAt: Date

    var timeAgo: String {
        let interval = Date().timeIntervalSince(createdAt)
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        if minutes < 1 { return "now" }
        if minutes < 60 { return "\(minutes)m" }
        if hours < 24 { return "\(hours)h" }
        if days < 7 { return "\(days)d" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: createdAt)
    }
}
