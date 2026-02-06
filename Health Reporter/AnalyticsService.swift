//
//  AnalyticsService.swift
//  Health Reporter
//
//  Centralized analytics wrapper for Firebase Analytics.
//  Provides type-safe event logging and user property management.
//

import Foundation
import FirebaseAnalytics

// MARK: - Analytics Events

enum AnalyticsEvent: String {
    // Screen Views
    case screenView = "screen_view"

    // Dashboard Events
    case dashboardRefresh = "dashboard_refresh"
    case periodChanged = "period_changed"
    case scoreViewed = "score_viewed"

    // Insights & Reports
    case reportGenerated = "report_generated"
    case insightViewed = "insight_viewed"
    case recommendationTapped = "recommendation_tapped"

    // Social Events
    case friendRequestSent = "friend_request_sent"
    case friendRequestAccepted = "friend_request_accepted"
    case friendRequestDeclined = "friend_request_declined"
    case friendRemoved = "friend_removed"
    case leaderboardViewed = "leaderboard_viewed"
    case userProfileViewed = "user_profile_viewed"
    case followRequestSent = "follow_request_sent"
    case followed = "followed"
    case unfollowed = "unfollowed"
    case rivalCardTapped = "rival_card_tapped"
    case inviteFriendsTapped = "invite_friends_tapped"

    // Profile Events
    case profileShareTapped = "profile_share_tapped"
    case profileEditTapped = "profile_edit_tapped"
    case profileStatTapped = "profile_stat_tapped"

    // Social Hub Events (Social-First)
    case storyAvatarTapped = "story_avatar_tapped"
    case activityFeedCardTapped = "activity_feed_card_tapped"

    // Car Tier Events
    case carTierChanged = "car_tier_changed"
    case carTierViewed = "car_tier_viewed"

    // Data Sources
    case dataSourceConnected = "data_source_connected"
    case dataSourceDisconnected = "data_source_disconnected"

    // User Actions
    case shareAction = "share_action"
    case settingsOpened = "settings_opened"
    case languageChanged = "language_changed"
    case loggedIn = "logged_in"
    case loggedOut = "logged_out"
    case signedUp = "signed_up"

    // Errors
    case errorOccurred = "error_occurred"
}

// MARK: - Screen Names

enum AnalyticsScreen: String {
    case splash = "Splash"
    case login = "Login"
    case dashboard = "Dashboard"
    case insights = "Insights"
    case trends = "Trends"
    case activity = "Activity"
    case socialHub = "Social_Hub"
    case leaderboard = "Leaderboard"
    case followRequests = "Follow_Requests"
    case followersList = "Followers_List"
    case followingList = "Following_List"
    case userSearch = "User_Search"
    case profile = "Profile"
    case userProfile = "User_Profile"
    case settings = "Settings"
    case dataSources = "Data_Sources"
    case nutrition = "Nutrition"
    case recommendations = "Recommendations"
    case report = "Report"
    case geminiDebug = "Gemini_Debug"
}

// MARK: - User Properties

enum AnalyticsUserProperty: String {
    case carTier = "car_tier"
    case carTierIndex = "car_tier_index"
    case healthScoreRange = "health_score_range"
    case language = "app_language"
    case friendsCount = "friends_count"
    case dataSourcesCount = "data_sources_count"
    case accountCreatedDate = "account_created_date"
}

// MARK: - Analytics Service

final class AnalyticsService {

    static let shared = AnalyticsService()

    private init() {}

    // MARK: - Screen Tracking

    /// Log a screen view event
    func logScreenView(_ screen: AnalyticsScreen, additionalParams: [String: Any]? = nil) {
        var params: [String: Any] = [
            AnalyticsParameterScreenName: screen.rawValue,
            AnalyticsParameterScreenClass: screen.rawValue
        ]

        if let additional = additionalParams {
            params.merge(additional) { _, new in new }
        }

        Analytics.logEvent(AnalyticsEventScreenView, parameters: params)
    }

    // MARK: - Event Logging

    /// Log a custom event with optional parameters
    func logEvent(_ event: AnalyticsEvent, parameters: [String: Any]? = nil) {
        Analytics.logEvent(event.rawValue, parameters: parameters)
    }

    // MARK: - Dashboard Events

    func logDashboardRefresh(period: String) {
        logEvent(.dashboardRefresh, parameters: [
            "period": period
        ])
    }

    func logPeriodChanged(from oldPeriod: String, to newPeriod: String) {
        logEvent(.periodChanged, parameters: [
            "from_period": oldPeriod,
            "to_period": newPeriod
        ])
    }

    func logScoreViewed(score: Int, carTier: String) {
        logEvent(.scoreViewed, parameters: [
            "score": score,
            "car_tier": carTier
        ])
    }

    // MARK: - Report Events

    func logReportGenerated(period: String, success: Bool, duration: TimeInterval? = nil) {
        var params: [String: Any] = [
            "period": period,
            "success": success
        ]
        if let duration = duration {
            params["duration_seconds"] = Int(duration)
        }
        logEvent(.reportGenerated, parameters: params)
    }

    // MARK: - Social Events

    func logFriendRequestSent(toUserId: String) {
        logEvent(.friendRequestSent, parameters: [
            "target_user_id": toUserId
        ])
    }

    func logFriendRequestAccepted(fromUserId: String) {
        logEvent(.friendRequestAccepted, parameters: [
            "from_user_id": fromUserId
        ])
    }

    func logFriendRequestDeclined(fromUserId: String) {
        logEvent(.friendRequestDeclined, parameters: [
            "from_user_id": fromUserId
        ])
    }

    func logFriendRemoved(userId: String) {
        logEvent(.friendRemoved, parameters: [
            "removed_user_id": userId
        ])
    }

    func logLeaderboardViewed(friendsCount: Int, userRank: Int?) {
        var params: [String: Any] = [
            "friends_count": friendsCount
        ]
        if let rank = userRank {
            params["user_rank"] = rank
        }
        logEvent(.leaderboardViewed, parameters: params)
    }

    func logUserProfileViewed(userId: String, isFriend: Bool) {
        logEvent(.userProfileViewed, parameters: [
            "viewed_user_id": userId,
            "is_friend": isFriend
        ])
    }

    func logFollowRequestSent(toUserId: String) {
        logEvent(.followRequestSent, parameters: [
            "target_user_id": toUserId
        ])
    }

    func logFollowed(userId: String) {
        logEvent(.followed, parameters: [
            "followed_user_id": userId
        ])
    }

    func logUnfollowed(userId: String) {
        logEvent(.unfollowed, parameters: [
            "unfollowed_user_id": userId
        ])
    }

    func logRivalCardTapped(rivalUserId: String) {
        logEvent(.rivalCardTapped, parameters: [
            "rival_user_id": rivalUserId
        ])
    }

    func logInviteFriendsTapped() {
        logEvent(.inviteFriendsTapped)
    }

    // MARK: - Car Tier Events

    func logCarTierChanged(from oldTier: String, to newTier: String, newScore: Int) {
        logEvent(.carTierChanged, parameters: [
            "from_tier": oldTier,
            "to_tier": newTier,
            "new_score": newScore
        ])
    }

    func logCarTierViewed(tier: String, score: Int) {
        logEvent(.carTierViewed, parameters: [
            "car_tier": tier,
            "score": score
        ])
    }

    // MARK: - Data Source Events

    func logDataSourceConnected(source: String) {
        logEvent(.dataSourceConnected, parameters: [
            "source": source
        ])
    }

    func logDataSourceDisconnected(source: String) {
        logEvent(.dataSourceDisconnected, parameters: [
            "source": source
        ])
    }

    // MARK: - User Action Events

    func logShareAction(contentType: String, method: String? = nil) {
        var params: [String: Any] = [
            "content_type": contentType
        ]
        if let method = method {
            params["method"] = method
        }
        logEvent(.shareAction, parameters: params)
    }

    func logLanguageChanged(from oldLanguage: String, to newLanguage: String) {
        logEvent(.languageChanged, parameters: [
            "from_language": oldLanguage,
            "to_language": newLanguage
        ])
    }

    func logLogin(method: String) {
        logEvent(.loggedIn, parameters: [
            AnalyticsParameterMethod: method
        ])
    }

    func logSignUp(method: String) {
        logEvent(.signedUp, parameters: [
            AnalyticsParameterMethod: method
        ])
    }

    func logLogout() {
        logEvent(.loggedOut)
    }

    // MARK: - Error Events

    func logError(code: String, message: String, screen: AnalyticsScreen? = nil) {
        var params: [String: Any] = [
            "error_code": code,
            "error_message": message
        ]
        if let screen = screen {
            params["screen"] = screen.rawValue
        }
        logEvent(.errorOccurred, parameters: params)
    }

    // MARK: - User Properties

    /// Set a user property
    func setUserProperty(_ property: AnalyticsUserProperty, value: String?) {
        Analytics.setUserProperty(value, forName: property.rawValue)
    }

    /// Update car tier user property
    func setCarTier(_ tier: CarTier) {
        setUserProperty(.carTier, value: tier.name)
        setUserProperty(.carTierIndex, value: String(tier.tierIndex))
    }

    /// Update health score range (buckets: 0-20, 21-40, 41-60, 61-80, 81-100)
    func setHealthScoreRange(score: Int) {
        let range: String
        switch score {
        case 0...20: range = "0-20_critical"
        case 21...40: range = "21-40_poor"
        case 41...60: range = "41-60_moderate"
        case 61...80: range = "61-80_good"
        default: range = "81-100_excellent"
        }
        setUserProperty(.healthScoreRange, value: range)
    }

    /// Update language user property
    func setLanguage(_ language: String) {
        setUserProperty(.language, value: language)
    }

    /// Update friends count user property
    func setFriendsCount(_ count: Int) {
        setUserProperty(.friendsCount, value: String(count))
    }

    /// Update data sources count
    func setDataSourcesCount(_ count: Int) {
        setUserProperty(.dataSourcesCount, value: String(count))
    }

    // MARK: - User ID

    /// Set the user ID for analytics (call after login)
    func setUserId(_ userId: String?) {
        Analytics.setUserID(userId)
    }

    /// Reset analytics data (call on logout)
    func resetAnalyticsData() {
        Analytics.setUserID(nil)
        // Clear user properties
        setUserProperty(.carTier, value: nil)
        setUserProperty(.carTierIndex, value: nil)
        setUserProperty(.healthScoreRange, value: nil)
        setUserProperty(.friendsCount, value: nil)
        setUserProperty(.dataSourcesCount, value: nil)
    }
}
