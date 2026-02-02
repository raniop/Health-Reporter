//
//  WatchDataManager.swift
//  Health Reporter Watch App
//
//  Manages health data storage and updates for the Watch app
//

import Foundation
import Combine
import WidgetKit

/// Manages Watch health data with observable state
@MainActor
class WatchDataManager: ObservableObject {
    static let shared = WatchDataManager()

    @Published var healthData: WatchHealthData = .placeholder
    @Published var isLoading: Bool = false
    @Published var lastError: String?

    private init() {
        loadData()
    }

    /// Loads data from App Group storage
    func loadData() {
        healthData = WatchDataStorage.loadData()
    }

    /// Updates health data and saves to storage
    func updateData(_ newData: WatchHealthData) {
        healthData = newData
        WatchDataStorage.saveData(newData)

        // Reload widget timelines
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Updates ALL data from WatchConnectivity context (from iPhone)
    func updateFromContext(_ context: [String: Any]) {
        guard let data = context["watchHealthData"] as? Data else {
            print("WatchDataManager: No watchHealthData in context")
            return
        }

        do {
            var phoneData = try JSONDecoder().decode(WatchHealthData.self, from: data)
            phoneData.isFromPhone = true
            phoneData.lastUpdated = Date()
            updateData(phoneData)
            print("⌚️ WatchDataManager: Received ALL data - score=\(phoneData.healthScore), geminiCar=\(phoneData.geminiCarName ?? "nil"), geminiScore=\(phoneData.geminiCarScore ?? 0), steps=\(phoneData.steps)")
        } catch {
            print("⌚️ WatchDataManager: Failed to decode context data: \(error)")
            lastError = "Failed to decode data from iPhone"
        }
    }

    /// Updates only car tier data from phone (for car-only updates)
    func updateCarDataOnly(carName: String, carEmoji: String, carTierIndex: Int, carTierLabel: String) {
        var updatedData = healthData
        updatedData.carName = carName
        updatedData.carEmoji = carEmoji
        updatedData.carTierIndex = carTierIndex
        updatedData.carTierLabel = carTierLabel
        updatedData.lastUpdated = Date()

        updateData(updatedData)
        print("⌚️ WatchDataManager: Updated car data only - car=\(carName), tier=\(carTierIndex)")
    }

    /// Creates WatchHealthData from iPhone widget data
    func createFromWidgetData(
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
        carTierIndex: Int,
        carTierLabel: String,
        geminiCarName: String? = nil,
        geminiCarScore: Int? = nil,
        geminiCarTierIndex: Int? = nil
    ) -> WatchHealthData {
        WatchHealthData(
            healthScore: healthScore,
            healthStatus: healthStatus,
            reliabilityScore: 85, // Default reliability
            carTierIndex: carTierIndex,
            carName: carName,
            carEmoji: carEmoji,
            carTierLabel: carTierLabel,
            geminiCarName: geminiCarName,
            geminiCarScore: geminiCarScore,
            geminiCarTierIndex: geminiCarTierIndex,
            moveCalories: calories,
            moveGoal: 500,
            exerciseMinutes: exerciseMinutes,
            exerciseGoal: 30,
            standHours: standHours,
            standGoal: 12,
            steps: steps,
            heartRate: heartRate,
            restingHeartRate: heartRate,
            hrv: hrv,
            sleepHours: sleepHours,
            lastUpdated: Date(),
            isFromPhone: true
        )
    }

    /// Requests data refresh from iPhone
    func requestRefresh() {
        WatchConnectivityManager.shared.requestDataFromPhone()
    }
}
