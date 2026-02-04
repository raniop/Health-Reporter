//
//  WatchTimelineProvider.swift
//  HealthWatch Widgets
//
//  Timeline provider for Watch complications
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct WatchHealthEntry: TimelineEntry {
    let date: Date
    let data: WatchComplicationData
}

// MARK: - Complication Data Model

struct WatchComplicationData: Codable {
    var healthScore: Int
    var healthStatus: String
    var reliabilityScore: Int

    var carTierIndex: Int
    var carName: String
    var carEmoji: String
    var carTierLabel: String

    // Gemini car data (for complications)
    var geminiCarName: String?
    var geminiCarScore: Int?
    var geminiCarTierIndex: Int?

    var moveCalories: Int
    var moveGoal: Int
    var exerciseMinutes: Int
    var exerciseGoal: Int
    var standHours: Int
    var standGoal: Int

    var steps: Int
    var heartRate: Int
    var restingHeartRate: Int
    var hrv: Int
    var sleepHours: Double

    var lastUpdated: Date
    var isFromPhone: Bool

    // Computed properties
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

    /// Display emoji - prefers gemini car if available
    var displayCarEmoji: String {
        if let geminiName = geminiCarName, !geminiName.isEmpty {
            return carEmojiForName(geminiName)
        }
        return carEmoji
    }

    /// Display car name - prefers gemini car if available
    var displayCarName: String {
        return geminiCarName ?? carName
    }

    /// Display tier index - prefers gemini tier if available
    var displayTierIndex: Int {
        return geminiCarTierIndex ?? carTierIndex
    }

    /// Get car emoji based on car name
    private func carEmojiForName(_ name: String) -> String {
        let lowercased = name.lowercased()
        if lowercased.contains("f1") || lowercased.contains("formula") {
            return "🏎️"
        } else if lowercased.contains("lambo") || lowercased.contains("ferrari") || lowercased.contains("porsche") {
            return "🏎️"
        } else if lowercased.contains("tesla") || lowercased.contains("electric") {
            return "🚗"
        } else if lowercased.contains("truck") || lowercased.contains("pickup") {
            return "🛻"
        } else if lowercased.contains("suv") || lowercased.contains("jeep") {
            return "🚙"
        } else if lowercased.contains("bicycle") || lowercased.contains("bike") {
            return "🚲"
        } else if lowercased.contains("broken") || lowercased.contains("junk") {
            return "🚗"
        }
        return "🚗"
    }

    static var placeholder: WatchComplicationData {
        WatchComplicationData(
            healthScore: 72,
            healthStatus: "Good",
            reliabilityScore: 85,
            carTierIndex: 2,
            carName: "BMW M3",
            carEmoji: "🏎️",
            carTierLabel: "Good Condition",
            geminiCarName: nil,
            geminiCarScore: nil,
            geminiCarTierIndex: nil,
            moveCalories: 320,
            moveGoal: 500,
            exerciseMinutes: 25,
            exerciseGoal: 30,
            standHours: 8,
            standGoal: 12,
            steps: 6543,
            heartRate: 72,
            restingHeartRate: 58,
            hrv: 45,
            sleepHours: 7.5,
            lastUpdated: Date(),
            isFromPhone: true
        )
    }
}

// MARK: - Watch Health Data (matches Watch App's WatchHealthData)

struct WatchHealthDataForWidget: Codable {
    var healthScore: Int
    var healthStatus: String
    var reliabilityScore: Int
    var carTierIndex: Int
    var carName: String
    var carEmoji: String
    var carTierLabel: String
    var geminiCarName: String?
    var geminiCarScore: Int?
    var geminiCarTierIndex: Int?
    var moveCalories: Int
    var moveGoal: Int
    var exerciseMinutes: Int
    var exerciseGoal: Int
    var standHours: Int
    var standGoal: Int
    var steps: Int
    var heartRate: Int
    var restingHeartRate: Int
    var hrv: Int
    var sleepHours: Double

    // Score breakdown (optional - for "Why" screen on Watch)
    var recoveryScore: Int?
    var sleepScore: Int?
    var nervousSystemScore: Int?
    var energyScore: Int?
    var activityScore: Int?
    var loadBalanceScore: Int?

    var lastUpdated: Date
    var isFromPhone: Bool
}

// MARK: - Data Loader

struct WatchWidgetDataLoader {
    static let appGroupID = "group.com.rani.Health-Reporter"
    static let watchDataKey = "watchHealthData"

    /// Serial queue to synchronize access with WatchDataStorage (same queue label pattern)
    private static let storageQueue = DispatchQueue(label: "com.rani.Health-Reporter.watchWidgetStorage", qos: .userInitiated)

    static func loadData() -> WatchComplicationData {
        return storageQueue.sync {
            guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
                print("WatchWidget: Failed to access App Group")
                return .placeholder
            }

            guard let data = userDefaults.data(forKey: watchDataKey) else {
                print("WatchWidget: No data found, using placeholder")
                return .placeholder
            }

            do {
                // Decode as WatchHealthData (from Watch App) and convert to WatchComplicationData
                let watchData = try JSONDecoder().decode(WatchHealthDataForWidget.self, from: data)
                print("⌚️ Widget: Loaded - score=\(watchData.healthScore), move=\(watchData.moveCalories), exercise=\(watchData.exerciseMinutes), stand=\(watchData.standHours)")

                return WatchComplicationData(
                    healthScore: watchData.healthScore,
                    healthStatus: watchData.healthStatus,
                    reliabilityScore: watchData.reliabilityScore,
                    carTierIndex: watchData.carTierIndex,
                    carName: watchData.carName,
                    carEmoji: watchData.carEmoji,
                    carTierLabel: watchData.carTierLabel,
                    geminiCarName: watchData.geminiCarName,
                    geminiCarScore: watchData.geminiCarScore,
                    geminiCarTierIndex: watchData.geminiCarTierIndex,
                    moveCalories: watchData.moveCalories,
                    moveGoal: watchData.moveGoal,
                    exerciseMinutes: watchData.exerciseMinutes,
                    exerciseGoal: watchData.exerciseGoal,
                    standHours: watchData.standHours,
                    standGoal: watchData.standGoal,
                    steps: watchData.steps,
                    heartRate: watchData.heartRate,
                    restingHeartRate: watchData.restingHeartRate,
                    hrv: watchData.hrv,
                    sleepHours: watchData.sleepHours,
                    lastUpdated: watchData.lastUpdated,
                    isFromPhone: watchData.isFromPhone
                )
            } catch {
                print("WatchWidget: Decode error: \(error)")
                return .placeholder
            }
        }
    }
}

// MARK: - Timeline Provider

struct WatchHealthTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchHealthEntry {
        WatchHealthEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchHealthEntry) -> Void) {
        let data = WatchWidgetDataLoader.loadData()
        let entry = WatchHealthEntry(date: Date(), data: data)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchHealthEntry>) -> Void) {
        let data = WatchWidgetDataLoader.loadData()
        let entry = WatchHealthEntry(date: Date(), data: data)

        // Update every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}
