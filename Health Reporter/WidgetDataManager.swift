//
//  WidgetDataManager.swift
//  Health Reporter
//
//  Manages data sharing between the main app and widgets via App Groups
//

import Foundation
import WidgetKit
import UIKit

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

    // User info
    var userName: String
}

/// Manages widget data updates
final class WidgetDataManager {
    static let shared = WidgetDataManager()

    private let appGroupID = "group.com.rani.Health-Reporter"
    private let dataKey = "widgetData"

    private init() {}

    /// Updates widget data from current health metrics
    /// - Parameter syncToWatch: Whether to also send data to Apple Watch (default true)
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
        carTierIndex: Int,
        userName: String = "",
        syncToWatch: Bool = true
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
            carTierIndex: carTierIndex,
            userName: userName
        )

        saveData(data)
        refreshWidgets()

        // Send to Apple Watch only if requested (Home screen only)
        if syncToWatch {
            sendToWatch(data)
        }
    }

    /// Convenience method to update from HealthDashboard data
    /// Sends all data to Watch including score, status, steps, sleep, and car tier
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
        carTier: CarTier? = nil,
        userName: String = "",
        // Score breakdown for Watch
        recoveryScore: Int? = nil,
        sleepScore: Int? = nil,
        nervousSystemScore: Int? = nil,
        energyScore: Int? = nil,
        activityScore: Int? = nil,
        loadBalanceScore: Int? = nil
    ) {
        // Get car tier from score if not provided
        let tier = carTier ?? CarTierEngine.tierForScore(score)

        // Store score breakdown for Watch BEFORE sending
        scoreBreakdown = (recoveryScore, sleepScore, nervousSystemScore, energyScore, activityScore, loadBalanceScore)

        // Save to widgets AND sync to Watch with all data
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
            carTierIndex: tier.tierIndex,
            userName: userName,
            syncToWatch: true  // Sync all data to Watch
        )
    }

    /// Score breakdown for Watch - stored separately
    private(set) var scoreBreakdown: (recovery: Int?, sleep: Int?, nervousSystem: Int?, energy: Int?, activity: Int?, loadBalance: Int?)?

    /// Update widget with Gemini car data (from Insights)
    /// Note: Does NOT sync to Watch - only Home screen syncs to Watch
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
        sleepHours: Double? = nil,
        userName: String = ""
    ) {
        // Get tier index from score for the progress bar
        let tier = CarTierEngine.tierForScore(score)

        // Don't sync to Watch - Insights uses different score (car tier, 90-day average)
        // Only Home screen (InsightsDashboard) should sync to Watch with daily mainScore
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
            carTierIndex: tier.tierIndex,
            userName: userName,
            syncToWatch: false  // Don't override Home screen data
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

// MARK: - Apple Watch Integration

extension WidgetDataManager {
    /// Sends only car tier data to Apple Watch (score/status calculated locally on Watch)
    func sendCarDataToWatch(tier: CarTier) {
        print("📱➡️⌚️ Sending car data to Watch: car=\(tier.name), tier=\(tier.tierIndex)")
        WatchConnectivityManager.shared.sendCarDataToWatch(
            carName: tier.name,
            carEmoji: tier.emoji,
            carTierIndex: tier.tierIndex,
            carTierLabel: tier.tierLabel
        )
    }

    /// Sends full data to Apple Watch via WatchConnectivity
    private func sendToWatch(_ data: SharedWidgetData) {
        // Get Gemini car data from cache
        let geminiCar = AnalysisCache.loadSelectedCar()
        let geminiScore = AnalysisCache.loadHealthScore()

        print("📱➡️⌚️ Sending to Watch: score=\(data.healthScore), geminiCar=\(geminiCar?.name ?? "nil"), geminiScore=\(geminiScore ?? 0), steps=\(data.steps)")
        WatchConnectivityManager.shared.sendWidgetDataToWatch(
            healthScore: data.healthScore,
            healthStatus: data.healthStatus,
            steps: data.steps,
            calories: data.calories,
            exerciseMinutes: data.exerciseMinutes,
            standHours: data.standHours,
            heartRate: data.heartRate,
            hrv: data.hrv,
            sleepHours: data.sleepHours,
            carName: data.carName,
            carEmoji: data.carEmoji,
            carTierIndex: data.carTierIndex,
            carTierLabel: CarTierEngine.tierForScore(data.healthScore).tierLabel,
            // Score breakdown
            recoveryScore: scoreBreakdown?.recovery,
            sleepScore: scoreBreakdown?.sleep,
            nervousSystemScore: scoreBreakdown?.nervousSystem,
            energyScore: scoreBreakdown?.energy,
            activityScore: scoreBreakdown?.activity,
            loadBalanceScore: scoreBreakdown?.loadBalance,
            // Gemini car data (for CarTierView on Watch)
            geminiCarName: geminiCar?.name,
            geminiCarScore: geminiScore
        )
    }
}

// MARK: - Car Image Management

extension WidgetDataManager {
    private var carImageFileName: String { "widget_car_image.jpg" }

    /// Saves car image to App Group for widget access
    func saveCarImage(_ image: UIImage) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            print("WidgetDataManager: Failed to get App Group container")
            return
        }

        let imageURL = containerURL.appendingPathComponent(carImageFileName)

        // Compress and save as JPEG for smaller file size
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("WidgetDataManager: Failed to convert image to JPEG")
            return
        }

        do {
            try imageData.write(to: imageURL)
            print("WidgetDataManager: Car image saved to App Group")

            // Refresh widgets to show new image
            refreshWidgets()
        } catch {
            print("WidgetDataManager: Failed to save car image - \(error)")
        }
    }

    /// Returns the URL of the saved car image (for widget to load)
    func getCarImageURL() -> URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }

        let imageURL = containerURL.appendingPathComponent(carImageFileName)

        if FileManager.default.fileExists(atPath: imageURL.path) {
            return imageURL
        }
        return nil
    }
}
