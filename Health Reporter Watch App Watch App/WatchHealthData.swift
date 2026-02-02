//
//  WatchHealthData.swift
//  Health Reporter Watch App
//
//  Shared data model for Watch app and complications
//

import Foundation

/// Lightweight health data model optimized for Apple Watch
struct WatchHealthData: Codable {
    // MARK: - Core Scores (Daily)
    var healthScore: Int       // Daily score for HomeView
    var healthStatus: String
    var reliabilityScore: Int

    // MARK: - Car Tier (based on daily score)
    var carTierIndex: Int
    var carName: String
    var carEmoji: String
    var carTierLabel: String

    // MARK: - Gemini Car Data (90-day average, for CarTierView)
    var geminiCarName: String?      // Car name from Gemini
    var geminiCarScore: Int?        // 90-day average score
    var geminiCarTierIndex: Int?    // Tier based on 90-day score

    // MARK: - Activity Rings
    var moveCalories: Int
    var moveGoal: Int
    var exerciseMinutes: Int
    var exerciseGoal: Int
    var standHours: Int
    var standGoal: Int

    // MARK: - Key Metrics
    var steps: Int
    var heartRate: Int
    var restingHeartRate: Int
    var hrv: Int
    var sleepHours: Double

    // MARK: - Score Breakdown (for "Why" screen)
    var recoveryScore: Int?      // 25% weight
    var sleepScore: Int?         // 20% weight
    var nervousSystemScore: Int? // 20% weight
    var energyScore: Int?        // 15% weight
    var activityScore: Int?      // 10% weight
    var loadBalanceScore: Int?   // 10% weight

    // MARK: - Metadata
    var lastUpdated: Date
    var isFromPhone: Bool  // true = synced from iPhone, false = calculated locally on Watch

    // MARK: - Computed Properties

    var moveProgress: Double {
        guard moveGoal > 0 else { return 0 }
        return Double(moveCalories) / Double(moveGoal)
    }

    var exerciseProgress: Double {
        guard exerciseGoal > 0 else { return 0 }
        return Double(exerciseMinutes) / Double(exerciseGoal)
    }

    var standProgress: Double {
        guard standGoal > 0 else { return 0 }
        return Double(standHours) / Double(standGoal)
    }

    var formattedSleepHours: String {
        let hours = Int(sleepHours)
        let minutes = Int((sleepHours - Double(hours)) * 60)
        if minutes > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(hours)h"
    }

    var isStale: Bool {
        // Data is considered stale if older than 30 minutes
        return Date().timeIntervalSince(lastUpdated) > 1800
    }

    // MARK: - Placeholder

    static var placeholder: WatchHealthData {
        WatchHealthData(
            healthScore: 0,
            healthStatus: "ממתין לנתונים...",
            reliabilityScore: 0,
            carTierIndex: 0,
            carName: "--",
            carEmoji: "⏳",
            carTierLabel: "ממתין...",
            geminiCarName: nil,
            geminiCarScore: nil,
            geminiCarTierIndex: nil,
            moveCalories: 0,
            moveGoal: 500,
            exerciseMinutes: 0,
            exerciseGoal: 30,
            standHours: 0,
            standGoal: 12,
            steps: 0,
            heartRate: 0,
            restingHeartRate: 0,
            hrv: 0,
            sleepHours: 0,
            recoveryScore: nil,
            sleepScore: nil,
            nervousSystemScore: nil,
            energyScore: nil,
            activityScore: nil,
            loadBalanceScore: nil,
            lastUpdated: Date.distantPast,
            isFromPhone: false
        )
    }

    static var empty: WatchHealthData {
        WatchHealthData(
            healthScore: 0,
            healthStatus: "--",
            reliabilityScore: 0,
            carTierIndex: 0,
            carName: "--",
            carEmoji: "🚗",
            carTierLabel: "--",
            geminiCarName: nil,
            geminiCarScore: nil,
            geminiCarTierIndex: nil,
            moveCalories: 0,
            moveGoal: 500,
            exerciseMinutes: 0,
            exerciseGoal: 30,
            standHours: 0,
            standGoal: 12,
            steps: 0,
            heartRate: 0,
            restingHeartRate: 0,
            hrv: 0,
            sleepHours: 0,
            recoveryScore: nil,
            sleepScore: nil,
            nervousSystemScore: nil,
            energyScore: nil,
            activityScore: nil,
            loadBalanceScore: nil,
            lastUpdated: Date.distantPast,
            isFromPhone: false
        )
    }
}

// MARK: - App Group Storage

struct WatchDataStorage {
    static let appGroupID = "group.com.rani.Health-Reporter"
    static let watchDataKey = "watchHealthData"
    static let lastSyncKey = "lastWatchSync"

    /// Loads Watch health data from App Group UserDefaults
    static func loadData() -> WatchHealthData {
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
            print("WatchDataStorage: Failed to access App Group")
            return .placeholder
        }

        guard let data = userDefaults.data(forKey: watchDataKey) else {
            print("WatchDataStorage: No data found, using placeholder")
            return .placeholder
        }

        do {
            let watchData = try JSONDecoder().decode(WatchHealthData.self, from: data)
            print("WatchDataStorage: Loaded data - Score: \(watchData.healthScore)")
            return watchData
        } catch {
            print("WatchDataStorage: Decode error: \(error)")
            return .placeholder
        }
    }

    /// Saves Watch health data to App Group UserDefaults
    static func saveData(_ data: WatchHealthData) {
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
            print("WatchDataStorage: Failed to access App Group")
            return
        }

        do {
            let encoded = try JSONEncoder().encode(data)
            userDefaults.set(encoded, forKey: watchDataKey)
            userDefaults.set(Date(), forKey: lastSyncKey)
            userDefaults.synchronize()
            print("WatchDataStorage: Data saved - Score: \(data.healthScore)")
        } catch {
            print("WatchDataStorage: Failed to encode data: \(error)")
        }
    }

    /// Gets the last sync date
    static func getLastSyncDate() -> Date? {
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
            return nil
        }
        return userDefaults.object(forKey: lastSyncKey) as? Date
    }
}
