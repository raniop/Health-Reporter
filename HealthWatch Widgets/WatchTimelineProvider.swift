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

    static var placeholder: WatchComplicationData {
        WatchComplicationData(
            healthScore: 72,
            healthStatus: "Good",
            reliabilityScore: 85,
            carTierIndex: 2,
            carName: "BMW M3",
            carEmoji: "🏎️",
            carTierLabel: "Good Condition",
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

// MARK: - Data Loader

struct WatchWidgetDataLoader {
    static let appGroupID = "group.com.rani.Health-Reporter"
    static let watchDataKey = "watchHealthData"

    static func loadData() -> WatchComplicationData {
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
            print("WatchWidget: Failed to access App Group")
            return .placeholder
        }

        guard let data = userDefaults.data(forKey: watchDataKey) else {
            print("WatchWidget: No data found, using placeholder")
            return .placeholder
        }

        do {
            let watchData = try JSONDecoder().decode(WatchComplicationData.self, from: data)
            print("WatchWidget: Loaded data - Score: \(watchData.healthScore)")
            return watchData
        } catch {
            print("WatchWidget: Decode error: \(error)")
            return .placeholder
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
