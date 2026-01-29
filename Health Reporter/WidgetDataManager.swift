//
//  WidgetDataManager.swift
//  Health Reporter
//
//  Manages data sharing between the main app and widgets via App Groups
//

import Foundation
import WidgetKit

/// Data structure shared with widgets (must match HealthWidgetData in widget extension)
struct SharedWidgetData: Codable {
    var healthScore: Int
    var healthStatus: String
    var steps: Int
    var stepsGoal: Int
    var calories: Int
    var caloriesGoal: Int
    var exerciseMinutes: Int
    var exerciseGoal: Int
    var standHours: Int
    var standGoal: Int
    var heartRate: Int
    var hrv: Int
    var sleepHours: Double
    var lastUpdated: Date

    // Car tier info
    var carName: String
    var carEmoji: String
    var carImageName: String
    var carTierIndex: Int
}

/// Manages widget data updates
final class WidgetDataManager {
    static let shared = WidgetDataManager()

    private let appGroupID = "group.com.rani.Health-Reporter"
    private let dataKey = "widgetData"

    private init() {}

    /// Updates widget data from current health metrics
    func updateWidgetData(
        healthScore: Int,
        healthStatus: String,
        steps: Int,
        calories: Int,
        exerciseMinutes: Int,
        standHours: Int,
        heartRate: Int,
        hrv: Int,
        sleepHours: Double,
        carName: String,
        carEmoji: String,
        carImageName: String,
        carTierIndex: Int
    ) {
        let data = SharedWidgetData(
            healthScore: healthScore,
            healthStatus: healthStatus,
            steps: steps,
            stepsGoal: 10000,
            calories: calories,
            caloriesGoal: 500,
            exerciseMinutes: exerciseMinutes,
            exerciseGoal: 30,
            standHours: standHours,
            standGoal: 12,
            heartRate: heartRate,
            hrv: hrv,
            sleepHours: sleepHours,
            lastUpdated: Date(),
            carName: carName,
            carEmoji: carEmoji,
            carImageName: carImageName,
            carTierIndex: carTierIndex
        )

        saveData(data)
        refreshWidgets()
    }

    /// Convenience method to update from HealthDashboard data
    func updateFromDashboard(
        score: Int,
        status: String,
        steps: Int,
        activeCalories: Int,
        exerciseMinutes: Int,
        standHours: Int,
        restingHR: Int?,
        hrv: Int?,
        sleepHours: Double?,
        carTier: CarTier? = nil
    ) {
        // Get car tier from score if not provided
        let tier = carTier ?? CarTierEngine.tierForScore(score)

        updateWidgetData(
            healthScore: score,
            healthStatus: status,
            steps: steps,
            calories: activeCalories,
            exerciseMinutes: exerciseMinutes,
            standHours: standHours,
            heartRate: restingHR ?? 0,
            hrv: hrv ?? 0,
            sleepHours: sleepHours ?? 0,
            carName: tier.name,
            carEmoji: tier.emoji,
            carImageName: tier.imageName,
            carTierIndex: tier.tierIndex
        )
    }

    /// Update widget with Gemini car data (from Insights)
    func updateFromInsights(
        score: Int,
        status: String,
        carName: String,
        carEmoji: String,
        steps: Int = 0,
        activeCalories: Int = 0,
        exerciseMinutes: Int = 0,
        standHours: Int = 0,
        restingHR: Int? = nil,
        hrv: Int? = nil,
        sleepHours: Double? = nil
    ) {
        // Get tier index from score for the progress bar
        let tier = CarTierEngine.tierForScore(score)

        updateWidgetData(
            healthScore: score,
            healthStatus: status,
            steps: steps,
            calories: activeCalories,
            exerciseMinutes: exerciseMinutes,
            standHours: standHours,
            heartRate: restingHR ?? 0,
            hrv: hrv ?? 0,
            sleepHours: sleepHours ?? 0,
            carName: carName,
            carEmoji: carEmoji,
            carImageName: "",  // Will use emoji instead
            carTierIndex: tier.tierIndex
        )
    }

    /// Saves data to App Group UserDefaults
    private func saveData(_ data: SharedWidgetData) {
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
            print("WidgetDataManager: ❌ Failed to access App Group")
            return
        }

        do {
            let encoded = try JSONEncoder().encode(data)
            userDefaults.set(encoded, forKey: dataKey)
            userDefaults.synchronize()  // Force sync
            print("WidgetDataManager: ✅ Data saved - Score: \(data.healthScore), Car: \(data.carName), Status: \(data.healthStatus)")
        } catch {
            print("WidgetDataManager: ❌ Failed to encode data - \(error)")
        }
    }

    /// Triggers widget refresh
    func refreshWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
        print("WidgetDataManager: Widgets refreshed")
    }

    /// Loads current widget data (for debugging)
    func loadCurrentData() -> SharedWidgetData? {
        guard let userDefaults = UserDefaults(suiteName: appGroupID),
              let data = userDefaults.data(forKey: dataKey),
              let widgetData = try? JSONDecoder().decode(SharedWidgetData.self, from: data) else {
            return nil
        }
        return widgetData
    }
}

// MARK: - Extension for Background Updates

extension WidgetDataManager {
    /// Call this from background fetch or after significant health data updates
    func scheduleWidgetUpdate() {
        refreshWidgets()
    }
}
