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

                // Update on main actor - phone data always takes priority (richer scores)
                DispatchQueue.main.async {
                    self.updateData(phoneData)
                    self.isLoading = false
                    print("⌚️ WatchDataManager: Received phone data - score=\(phoneData.healthScore), move=\(phoneData.moveCalories), exercise=\(phoneData.exerciseMinutes), stand=\(phoneData.standHours)")
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

    /// Requests data refresh - always fetches local HealthKit first, then upgrades from iPhone if available
    func requestRefresh() {
        isLoading = true

        // Fetch local HealthKit data and also request from iPhone in parallel
        Task {
            // Step 1: Authorize + fetch local HealthKit data
            await authorizeAndFetchLocal()

            // Step 2: Also try to get richer data from iPhone (includes advanced scores, Gemini car, etc.)
            if WatchConnectivityManager.shared.isReachable {
                print("⌚️ WatchDataManager: iPhone reachable - also requesting enriched data")
                WatchConnectivityManager.shared.requestDataFromPhone()
            } else {
                print("⌚️ WatchDataManager: iPhone not reachable - using local HealthKit data only")
            }
            self.isLoading = false
        }
    }

    /// Ensures HealthKit authorization is granted on Watch, then fetches initial data (called at app launch)
    func ensureHealthKitAuthorization() {
        Task {
            await authorizeAndFetchLocal()
        }
    }

    /// Single method that handles authorization + local HealthKit fetch sequentially (no race conditions)
    /// Only updates raw metrics (steps, HR, sleep, etc.) - never overwrites score/tier from iPhone
    private func authorizeAndFetchLocal() async {
        // Step 1: Request authorization (will only show prompt once)
        do {
            let _ = try await WatchHealthKitManager.shared.requestAuthorization()
        } catch {
            print("⌚️ WatchDataManager: HealthKit authorization error: \(error.localizedDescription)")
        }

        // Step 2: Fetch raw metrics from HealthKit
        do {
            let localData = try await WatchHealthKitManager.shared.fetchTodayData()

            // Merge local HealthKit metrics into existing data
            // Keep score/tier/car from iPhone (if available), only update raw metrics
            var merged = healthData
            merged.steps = localData.steps
            merged.heartRate = localData.heartRate
            merged.restingHeartRate = localData.restingHeartRate
            merged.hrv = localData.hrv
            merged.sleepHours = localData.sleepHours
            merged.moveCalories = localData.moveCalories
            merged.exerciseMinutes = localData.exerciseMinutes
            merged.standHours = localData.standHours
            merged.lastUpdated = Date()

            self.healthData = merged
            WatchDataStorage.saveData(merged)
            WidgetCenter.shared.reloadAllTimelines()
            print("⌚️ WatchDataManager: ✅ Local metrics updated - steps=\(merged.steps), hr=\(merged.heartRate), sleep=\(merged.sleepHours)h")
        } catch {
            print("⌚️ WatchDataManager: Failed to fetch local HealthKit data: \(error)")
            self.lastError = "Failed to fetch local data"
        }
    }
}
