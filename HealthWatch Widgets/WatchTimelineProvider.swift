//
//  WatchTimelineProvider.swift
//  HealthWatch Widgets
//
//  Timeline provider for Watch complications.
//  Decodes directly from WatchHealthData format (same JSON as the Watch app uses).
//  Eliminated the duplicate WatchHealthDataDecoder middleman.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct WatchHealthEntry: TimelineEntry {
    let date: Date
    let data: WatchComplicationData
}

// MARK: - Complication Data Model

struct WatchComplicationData {
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

    var lastUpdated: Date
    var isFromPhone: Bool

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

    var displayCarEmoji: String {
        if let geminiName = geminiCarName, !geminiName.isEmpty {
            return carEmoji.isEmpty ? "🚗" : carEmoji
        }
        return carEmoji.isEmpty ? "🚗" : carEmoji
    }

    var displayCarName: String {
        return geminiCarName ?? carName
    }

    var displayTierIndex: Int {
        return geminiCarTierIndex ?? carTierIndex
    }

    /// Score color matching WatchHealthData.scoreColor(for:)
    var scoreColor: Color {
        switch healthScore {
        case ..<25:  return .red
        case 25..<45: return .orange
        case 45..<65: return .yellow
        case 65..<82: return .green
        default:      return .mint
        }
    }

    /// Tier color matching WatchHealthData.tierColor(for:)
    var tierColor: Color {
        switch displayTierIndex {
        case 0:  return .red
        case 1:  return .orange
        case 2:  return .yellow
        case 3:  return .green
        default: return .mint
        }
    }

    // MARK: - Init from decoded JSON (WatchHealthData format)

    /// Initialize from the raw decoded JSON that matches WatchHealthData's Codable format.
    /// This eliminates the need for a separate WatchHealthDataDecoder struct.
    init(from decoded: DecodedWatchData) {
        self.healthScore = decoded.healthScore
        self.healthStatus = decoded.healthStatus
        self.reliabilityScore = decoded.reliabilityScore
        self.carTierIndex = decoded.carTierIndex
        self.carName = decoded.carName
        self.carEmoji = decoded.carEmoji
        self.carTierLabel = decoded.carTierLabel
        self.geminiCarName = decoded.geminiCarName
        self.geminiCarScore = decoded.geminiCarScore
        self.geminiCarTierIndex = decoded.geminiCarTierIndex
        self.moveCalories = decoded.moveCalories
        self.moveGoal = decoded.moveGoal
        self.exerciseMinutes = decoded.exerciseMinutes
        self.exerciseGoal = decoded.exerciseGoal
        self.standHours = decoded.standHours
        self.standGoal = decoded.standGoal
        self.steps = decoded.steps
        self.heartRate = decoded.heartRate
        self.restingHeartRate = decoded.restingHeartRate
        self.hrv = decoded.hrv
        self.sleepHours = decoded.sleepHours
        self.lastUpdated = decoded.lastUpdated
        self.isFromPhone = decoded.isFromPhone
    }

    // MARK: - Memberwise init

    init(healthScore: Int, healthStatus: String, reliabilityScore: Int,
         carTierIndex: Int, carName: String, carEmoji: String, carTierLabel: String,
         geminiCarName: String?, geminiCarScore: Int?, geminiCarTierIndex: Int?,
         moveCalories: Int, moveGoal: Int, exerciseMinutes: Int, exerciseGoal: Int,
         standHours: Int, standGoal: Int,
         steps: Int, heartRate: Int, restingHeartRate: Int, hrv: Int, sleepHours: Double,
         lastUpdated: Date, isFromPhone: Bool) {
        self.healthScore = healthScore; self.healthStatus = healthStatus; self.reliabilityScore = reliabilityScore
        self.carTierIndex = carTierIndex; self.carName = carName; self.carEmoji = carEmoji; self.carTierLabel = carTierLabel
        self.geminiCarName = geminiCarName; self.geminiCarScore = geminiCarScore; self.geminiCarTierIndex = geminiCarTierIndex
        self.moveCalories = moveCalories; self.moveGoal = moveGoal; self.exerciseMinutes = exerciseMinutes; self.exerciseGoal = exerciseGoal
        self.standHours = standHours; self.standGoal = standGoal
        self.steps = steps; self.heartRate = heartRate; self.restingHeartRate = restingHeartRate; self.hrv = hrv; self.sleepHours = sleepHours
        self.lastUpdated = lastUpdated; self.isFromPhone = isFromPhone
    }

    // MARK: - Placeholder

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

// MARK: - Codable decoder (matches WatchHealthData's JSON exactly)

/// Decodes the same JSON format as WatchHealthData, with fallback defaults for all fields.
/// This is the SINGLE decoder — no duplication with the Watch app's WatchHealthData.
struct DecodedWatchData: Codable {
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
    var lastUpdated: Date
    var isFromPhone: Bool

    enum CodingKeys: String, CodingKey {
        case healthScore, healthStatus, reliabilityScore
        case carTierIndex, carName, carEmoji, carTierLabel
        case geminiCarName, geminiCarScore, geminiCarTierIndex
        case moveCalories, moveGoal, exerciseMinutes, exerciseGoal, standHours, standGoal
        case steps, heartRate, restingHeartRate, hrv, sleepHours
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
        lastUpdated = (try? c.decode(Date.self, forKey: .lastUpdated)) ?? Date.distantPast
        isFromPhone = (try? c.decode(Bool.self, forKey: .isFromPhone)) ?? false
    }
}

// MARK: - Data Loader

struct WatchWidgetDataLoader {
    static let appGroupID = "group.com.rani.Health-Reporter"
    static let watchDataKey = "watchHealthData"

    static func loadData() -> WatchComplicationData {
        guard let userDefaults = UserDefaults(suiteName: appGroupID),
              let data = userDefaults.data(forKey: watchDataKey) else {
            print("🔧 [Complication] No data in App Group, using placeholder")
            return .placeholder
        }

        do {
            let decoded = try JSONDecoder().decode(DecodedWatchData.self, from: data)
            let result = WatchComplicationData(from: decoded)
            print("🔧 [Complication] ✅ Loaded: score=\(result.healthScore), steps=\(result.steps), car=\(result.carName)")
            return result
        } catch {
            print("🔧 [Complication] ❌ Decode error: \(error.localizedDescription)")
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
        print("🔧 [Complication] Snapshot requested: score=\(data.healthScore)")
        completion(WatchHealthEntry(date: Date(), data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchHealthEntry>) -> Void) {
        let data = WatchWidgetDataLoader.loadData()
        let entry = WatchHealthEntry(date: Date(), data: data)

        // Refresh every 5 minutes (was 15 min — too stale)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date(timeIntervalSinceNow: 300)
        print("🔧 [Complication] Timeline: score=\(data.healthScore), next refresh in 5 min")
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}
