//
//  WatchHealthData.swift
//  Health Reporter Watch App
//
//  Shared data model for Watch app, iPhone, and complications
//

import Foundation
import SwiftUI

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
    var heartRate: Int           // Latest/current heart rate
    var restingHeartRate: Int    // Resting heart rate (separate metric)
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

    // MARK: - Memberwise Init

    init(healthScore: Int, healthStatus: String, reliabilityScore: Int,
         carTierIndex: Int, carName: String, carEmoji: String, carTierLabel: String,
         geminiCarName: String?, geminiCarScore: Int?, geminiCarTierIndex: Int?,
         moveCalories: Int, moveGoal: Int, exerciseMinutes: Int, exerciseGoal: Int,
         standHours: Int, standGoal: Int,
         steps: Int, heartRate: Int, restingHeartRate: Int, hrv: Int, sleepHours: Double,
         recoveryScore: Int?, sleepScore: Int?, nervousSystemScore: Int?,
         energyScore: Int?, activityScore: Int?, loadBalanceScore: Int?,
         lastUpdated: Date, isFromPhone: Bool) {
        self.healthScore = healthScore; self.healthStatus = healthStatus; self.reliabilityScore = reliabilityScore
        self.carTierIndex = carTierIndex; self.carName = carName; self.carEmoji = carEmoji; self.carTierLabel = carTierLabel
        self.geminiCarName = geminiCarName; self.geminiCarScore = geminiCarScore; self.geminiCarTierIndex = geminiCarTierIndex
        self.moveCalories = moveCalories; self.moveGoal = moveGoal; self.exerciseMinutes = exerciseMinutes; self.exerciseGoal = exerciseGoal
        self.standHours = standHours; self.standGoal = standGoal
        self.steps = steps; self.heartRate = heartRate; self.restingHeartRate = restingHeartRate; self.hrv = hrv; self.sleepHours = sleepHours
        self.recoveryScore = recoveryScore; self.sleepScore = sleepScore; self.nervousSystemScore = nervousSystemScore
        self.energyScore = energyScore; self.activityScore = activityScore; self.loadBalanceScore = loadBalanceScore
        self.lastUpdated = lastUpdated; self.isFromPhone = isFromPhone
    }

    // MARK: - Codable (backward-compatible)

    enum CodingKeys: String, CodingKey {
        case healthScore, healthStatus, reliabilityScore
        case carTierIndex, carName, carEmoji, carTierLabel
        case geminiCarName, geminiCarScore, geminiCarTierIndex
        case moveCalories, moveGoal, exerciseMinutes, exerciseGoal, standHours, standGoal
        case steps, heartRate, restingHeartRate, hrv, sleepHours
        case recoveryScore, sleepScore, nervousSystemScore, energyScore, activityScore, loadBalanceScore
        case lastUpdated, isFromPhone
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        healthScore = (try? c.decode(Int.self, forKey: .healthScore)) ?? 0
        healthStatus = (try? c.decode(String.self, forKey: .healthStatus)) ?? ""
        reliabilityScore = (try? c.decode(Int.self, forKey: .reliabilityScore)) ?? 0
        carTierIndex = (try? c.decode(Int.self, forKey: .carTierIndex)) ?? 0
        carName = (try? c.decode(String.self, forKey: .carName)) ?? "--"
        carEmoji = (try? c.decode(String.self, forKey: .carEmoji)) ?? "🚗"
        carTierLabel = (try? c.decode(String.self, forKey: .carTierLabel)) ?? ""
        geminiCarName = try? c.decode(String.self, forKey: .geminiCarName)
        geminiCarScore = try? c.decode(Int.self, forKey: .geminiCarScore)
        geminiCarTierIndex = try? c.decode(Int.self, forKey: .geminiCarTierIndex)
        moveCalories = (try? c.decode(Int.self, forKey: .moveCalories)) ?? 0
        moveGoal = (try? c.decode(Int.self, forKey: .moveGoal)) ?? 0
        exerciseMinutes = (try? c.decode(Int.self, forKey: .exerciseMinutes)) ?? 0
        exerciseGoal = (try? c.decode(Int.self, forKey: .exerciseGoal)) ?? 0
        standHours = (try? c.decode(Int.self, forKey: .standHours)) ?? 0
        standGoal = (try? c.decode(Int.self, forKey: .standGoal)) ?? 0
        steps = (try? c.decode(Int.self, forKey: .steps)) ?? 0
        heartRate = (try? c.decode(Int.self, forKey: .heartRate)) ?? 0
        restingHeartRate = (try? c.decode(Int.self, forKey: .restingHeartRate)) ?? 0
        hrv = (try? c.decode(Int.self, forKey: .hrv)) ?? 0
        sleepHours = (try? c.decode(Double.self, forKey: .sleepHours)) ?? 0
        recoveryScore = try? c.decode(Int.self, forKey: .recoveryScore)
        sleepScore = try? c.decode(Int.self, forKey: .sleepScore)
        nervousSystemScore = try? c.decode(Int.self, forKey: .nervousSystemScore)
        energyScore = try? c.decode(Int.self, forKey: .energyScore)
        activityScore = try? c.decode(Int.self, forKey: .activityScore)
        loadBalanceScore = try? c.decode(Int.self, forKey: .loadBalanceScore)
        lastUpdated = (try? c.decode(Date.self, forKey: .lastUpdated)) ?? Date.distantPast
        isFromPhone = (try? c.decode(Bool.self, forKey: .isFromPhone)) ?? false
    }

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
        Date().timeIntervalSince(lastUpdated) > 14400 // 4 hours
    }

    // MARK: - Shared Color Logic

    /// Score color used across Watch app views and complications
    static func scoreColor(for score: Int) -> Color {
        switch score {
        case ..<25:  return .red
        case 25..<45: return .orange
        case 45..<65: return .yellow
        case 65..<82: return .green
        default:      return .mint
        }
    }

    /// Tier color used for car tier progress bars and labels
    static func tierColor(for tierIndex: Int) -> Color {
        switch tierIndex {
        case 0:  return .red
        case 1:  return .orange
        case 2:  return .yellow
        case 3:  return .green
        default: return .mint
        }
    }

    // MARK: - Placeholder

    static var placeholder: WatchHealthData {
        WatchHealthData(
            healthScore: 0,
            healthStatus: "watch.status.waitingForData".localizedWatch,
            reliabilityScore: 0,
            carTierIndex: 0,
            carName: "--",
            carEmoji: "⏳",
            carTierLabel: "watch.status.waiting".localizedWatch,
            geminiCarName: nil,
            geminiCarScore: nil,
            geminiCarTierIndex: nil,
            moveCalories: 0,
            moveGoal: 0,
            exerciseMinutes: 0,
            exerciseGoal: 0,
            standHours: 0,
            standGoal: 0,
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
            moveGoal: 0,
            exerciseMinutes: 0,
            exerciseGoal: 0,
            standHours: 0,
            standGoal: 0,
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
    private static let migrationKey = "watchDataMigration_v2"

    /// One-time migration: clears old cached data that may be incompatible with the new model.
    /// Called BEFORE WatchDataManager.shared is first accessed to prevent decode crashes.
    static func migrateIfNeeded() {
        let standard = UserDefaults.standard
        guard !standard.bool(forKey: migrationKey) else { return }
        // Wipe old cached data from App Group
        if let ud = UserDefaults(suiteName: appGroupID) {
            ud.removeObject(forKey: watchDataKey)
            ud.removeObject(forKey: lastSyncKey)
            ud.synchronize()
        }
        standard.set(true, forKey: migrationKey)
        print("⌚️ WatchDataStorage: v2 migration — cleared stale cache")
    }

    /// Loads Watch health data from App Group UserDefaults
    static func loadData() -> WatchHealthData {
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
            return .placeholder
        }
        guard let data = userDefaults.data(forKey: watchDataKey) else {
            return .placeholder
        }
        do {
            return try JSONDecoder().decode(WatchHealthData.self, from: data)
        } catch {
            // Corrupt or incompatible cache — wipe it
            userDefaults.removeObject(forKey: watchDataKey)
            return .placeholder
        }
    }

    /// Saves Watch health data to App Group UserDefaults
    static func saveData(_ data: WatchHealthData) {
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else { return }
        do {
            let encoded = try JSONEncoder().encode(data)
            userDefaults.set(encoded, forKey: watchDataKey)
            userDefaults.set(Date(), forKey: lastSyncKey)
        } catch {
            print("WatchDataStorage: Failed to encode: \(error)")
        }
    }

    /// Gets the last sync date
    static func getLastSyncDate() -> Date? {
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else { return nil }
        return userDefaults.object(forKey: lastSyncKey) as? Date
    }
}
