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

    /// Serial queue to ensure updates are processed one at a time
    private let updateQueue = DispatchQueue(label: "com.rani.Health-Reporter.watchDataManager", qos: .userInitiated)

    /// Flag to prevent duplicate updates within short time window
    private var lastUpdateTimestamp: Date = .distantPast
    private let minUpdateInterval: TimeInterval = 0.5 // 500ms minimum between updates

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

    /// Updates ALL data from WatchConnectivity context (from iPhone) - serialized
    func updateFromContext(_ context: [String: Any]) {
        // Serialize updates to prevent race conditions
        updateQueue.async { [weak self] in
            guard let self = self else { return }

            // Debounce rapid updates
            let now = Date()
            if now.timeIntervalSince(self.lastUpdateTimestamp) < self.minUpdateInterval {
                print("⌚️ WatchDataManager: Skipping rapid update (debounced)")
                return
            }
            self.lastUpdateTimestamp = now

            guard let data = context["watchHealthData"] as? Data else {
                print("WatchDataManager: No watchHealthData in context")
                return
            }

            do {
                var phoneData = try JSONDecoder().decode(WatchHealthData.self, from: data)
                phoneData.isFromPhone = true
                phoneData.lastUpdated = Date()

                // Update on main actor
                DispatchQueue.main.async {
                    self.updateData(phoneData)
                    print("⌚️ WatchDataManager: Received data - score=\(phoneData.healthScore), move=\(phoneData.moveCalories), exercise=\(phoneData.exerciseMinutes), stand=\(phoneData.standHours)")
                }
            } catch {
                print("⌚️ WatchDataManager: Failed to decode context data: \(error)")
                DispatchQueue.main.async {
                    self.lastError = "Failed to decode data from iPhone"
                }
            }
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
            recoveryScore: nil,
            sleepScore: nil,
            nervousSystemScore: nil,
            energyScore: nil,
            activityScore: nil,
            loadBalanceScore: nil,
            lastUpdated: Date(),
            isFromPhone: true
        )
    }

    /// Requests data refresh from iPhone, with fallback to local HealthKit
    func requestRefresh() {
        // Check if iPhone is reachable
        if WatchConnectivityManager.shared.isReachable {
            // iPhone is reachable - request data from it
            WatchConnectivityManager.shared.requestDataFromPhone()
        } else {
            // iPhone not reachable - fetch local data from HealthKit on Watch
            print("⌚️ WatchDataManager: iPhone not reachable, fetching local HealthKit data")
            fetchLocalHealthKitData()
        }
    }

    /// Fetches health data from local HealthKit on Watch (fallback when iPhone not reachable)
    private func fetchLocalHealthKitData() {
        Task {
            do {
                let localData = try await WatchHealthKitManager.shared.fetchTodayData()
                self.healthData = localData
                WatchDataStorage.saveData(localData)
                WidgetCenter.shared.reloadAllTimelines()
                print("⌚️ WatchDataManager: Using local HealthKit data - score=\(localData.healthScore), steps=\(localData.steps), exercise=\(localData.exerciseMinutes)")
            } catch {
                print("⌚️ WatchDataManager: Failed to fetch local HealthKit data: \(error)")
                self.lastError = "Failed to fetch local data"
            }
        }
    }
}
