//
//  WatchDataManager.swift
//  Health Reporter Watch App
//
//  Manages health data storage and updates for the Watch app.
//
//  DATA OWNERSHIP:
//  - iPhone owns: healthScore, healthStatus, car, tier, gemini, score breakdown
//  - Watch owns: ALL HealthKit metrics (steps, HR, sleep, calories, exercise, stand, HRV)
//
//  The Watch fetches HealthKit data locally every 5 minutes via a repeating timer.
//  iPhone only sends scores/car/tier — never HealthKit metrics.
//

import Foundation
import Combine
import WidgetKit
import WatchKit
import HealthKit

/// Manages Watch health data with observable state.
/// All data mutations go through `dataQueue` to prevent race conditions.
/// All @Published property mutations are dispatched to the main thread.
class WatchDataManager: ObservableObject {
    static let shared = WatchDataManager()

    @Published var healthData: WatchHealthData = .placeholder
    @Published var isLoading: Bool = false
    @Published var lastError: String?

    // MARK: - Serial queue for thread-safe data merges

    private let dataQueue = DispatchQueue(label: "com.healthreporter.watchdata.merge", qos: .userInitiated)

    // MARK: - Debounce

    /// Minimum time between context updates (iPhone pushes)
    private var lastUpdateTimestamp: Date = .distantPast
    private let minUpdateInterval: TimeInterval = 0.5

    /// Minimum time between full refresh cycles
    private var lastRefreshTimestamp: Date = .distantPast
    private let minRefreshInterval: TimeInterval = 5.0

    // MARK: - Periodic refresh timer

    /// Timer that fires every 5 minutes to refresh HealthKit data
    private var refreshTimer: Timer?
    private let autoRefreshInterval: TimeInterval = 300 // 5 minutes

    // MARK: - Day-change tracking

    /// Tracks the last known calendar day so we can detect midnight crossover
    private var lastKnownDay: Int = 0

    // MARK: - Background HealthKit observers

    private var observerQueries: [HKObserverQuery] = []
    private var backgroundDeliveryEnabled = false

    // MARK: - Init

    private init() {
        print("⌚ [DataManager] Initializing...")
        lastKnownDay = Calendar.current.component(.day, from: Date())
        loadData()
        setupBackgroundHealthKitObservers()
        scheduleNextBackgroundRefresh()
    }

    // MARK: - Load from disk

    /// Loads data from App Group storage.
    /// If the cached data is from a previous day, resets daily HealthKit fields to 0.
    func loadData() {
        var loaded = WatchDataStorage.loadData()
        let isPlaceholder = loaded.lastUpdated == Date.distantPast

        // Midnight reset: if cached data is from yesterday, zero out daily metrics
        if !isPlaceholder && !Calendar.current.isDateInToday(loaded.lastUpdated) {
            print("⌚ [DataManager] 🌙 Day changed! Resetting daily HealthKit metrics to 0")
            loaded.steps = 0
            loaded.moveCalories = 0
            loaded.exerciseMinutes = 0
            loaded.standHours = 0
            loaded.heartRate = 0
            loaded.sleepHours = 0
            // Keep iPhone-owned fields (score, car, tier) — they persist across days
            WatchDataStorage.saveData(loaded)
        }

        print("⌚ [DataManager] Loaded from disk: score=\(loaded.healthScore), steps=\(loaded.steps), car=\(loaded.carName), isPlaceholder=\(isPlaceholder)")

        if Thread.isMainThread {
            healthData = loaded
        } else {
            DispatchQueue.main.async { self.healthData = loaded }
        }
    }

    // MARK: - Save & publish

    /// Updates health data, saves to storage, and reloads widget timelines.
    /// Called from dataQueue-protected contexts.
    private func commitData(_ newData: WatchHealthData) {
        // Save to disk first (can happen on any thread)
        WatchDataStorage.saveData(newData)

        // Update published property on main thread
        DispatchQueue.main.async {
            self.healthData = newData
        }

        // Reload widgets
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - iPhone data updates (scores/car/tier ONLY)

    /// Updates scores/car/tier from WatchConnectivity context (from iPhone).
    /// NEVER touches HealthKit fields — Watch owns those.
    func updateFromContext(_ context: [String: Any]) {
        dataQueue.async { [weak self] in
            guard let self = self else { return }

            // Debounce rapid updates
            let now = Date()
            guard now.timeIntervalSince(self.lastUpdateTimestamp) >= self.minUpdateInterval else {
                print("⌚ [DataManager] Debounced context update (too fast)")
                return
            }
            self.lastUpdateTimestamp = now

            // Try full scores payload
            if let data = context["watchHealthData"] as? Data {
                do {
                    let phoneData = try JSONDecoder().decode(WatchHealthData.self, from: data)
                    print("⌚ [DataManager] 📥 Phone scores decoded: score=\(phoneData.healthScore), car=\(phoneData.carName), tier=\(phoneData.carTierIndex)")

                    // MERGE: Only take iPhone-owned fields. NEVER touch HealthKit metrics.
                    var merged = self.healthData  // Start from current state (has fresh HealthKit data)

                    // iPhone-OWNED fields: always take from phone
                    merged.healthScore = phoneData.healthScore
                    merged.healthStatus = phoneData.healthStatus
                    merged.reliabilityScore = phoneData.reliabilityScore
                    merged.carTierIndex = phoneData.carTierIndex
                    merged.carName = phoneData.carName
                    merged.carEmoji = phoneData.carEmoji
                    merged.carTierLabel = phoneData.carTierLabel
                    merged.geminiCarName = phoneData.geminiCarName
                    merged.geminiCarScore = phoneData.geminiCarScore
                    merged.geminiCarTierIndex = phoneData.geminiCarTierIndex
                    merged.recoveryScore = phoneData.recoveryScore ?? merged.recoveryScore
                    merged.sleepScore = phoneData.sleepScore ?? merged.sleepScore
                    merged.nervousSystemScore = phoneData.nervousSystemScore ?? merged.nervousSystemScore
                    merged.energyScore = phoneData.energyScore ?? merged.energyScore
                    merged.activityScore = phoneData.activityScore ?? merged.activityScore
                    merged.loadBalanceScore = phoneData.loadBalanceScore ?? merged.loadBalanceScore

                    // HealthKit fields: NEVER touched — Watch owns them
                    // merged.steps, .heartRate, .sleepHours, etc. stay as-is

                    merged.isFromPhone = true
                    merged.lastUpdated = Date()

                    print("⌚ [DataManager] ✅ Scores merge: score=\(merged.healthScore), car=\(merged.carName), steps=\(merged.steps) (local), hr=\(merged.heartRate) (local)")
                    self.commitData(merged)
                    DispatchQueue.main.async { self.isLoading = false }
                } catch {
                    print("⌚ [DataManager] ❌ Failed to decode phone data: \(error.localizedDescription)")
                    DispatchQueue.main.async { self.lastError = "Failed to decode data from iPhone" }
                }
                return
            }

            // Try car-only update
            if let carName = context["carName"] as? String,
               let carEmoji = context["carEmoji"] as? String,
               let carTierIndex = context["carTierIndex"] as? Int,
               let carTierLabel = context["carTierLabel"] as? String {
                print("⌚ [DataManager] 🚗 Car-only update: \(carName) (tier \(carTierIndex))")
                var updated = self.healthData
                updated.carName = carName
                updated.carEmoji = carEmoji
                updated.carTierIndex = carTierIndex
                updated.carTierLabel = carTierLabel
                updated.lastUpdated = Date()
                self.commitData(updated)
                return
            }

            print("⌚ [DataManager] ⚠️ Context update had no recognizable payload")
        }
    }

    /// Updates only car tier data from phone
    func updateCarDataOnly(carName: String, carEmoji: String, carTierIndex: Int, carTierLabel: String) {
        dataQueue.async { [weak self] in
            guard let self = self else { return }
            print("⌚ [DataManager] 🚗 Car-only direct update: \(carName) (tier \(carTierIndex))")
            var updated = self.healthData
            updated.carName = carName
            updated.carEmoji = carEmoji
            updated.carTierIndex = carTierIndex
            updated.carTierLabel = carTierLabel
            updated.lastUpdated = Date()
            self.commitData(updated)
        }
    }

    // MARK: - Refresh

    /// Requests data refresh:
    /// 1. Fetches local HealthKit data (Watch owns all metrics)
    /// 2. Requests scores/car from iPhone (if reachable)
    /// Debounced to avoid rapid duplicate requests.
    func requestRefresh() {
        let now = Date()
        guard now.timeIntervalSince(lastRefreshTimestamp) >= minRefreshInterval else {
            print("⌚ [DataManager] 🔄 Refresh debounced (last: \(Int(now.timeIntervalSince(lastRefreshTimestamp)))s ago)")
            return
        }
        lastRefreshTimestamp = now

        // Check for day change (midnight crossover)
        checkForDayChange()

        let phoneReachable = WatchConnectivityManager.shared.isReachable
        print("⌚ [DataManager] 🔄 Starting refresh (phone reachable: \(phoneReachable))")

        DispatchQueue.main.async { self.isLoading = true }

        // 1. Fetch local HealthKit data (Watch owns ALL metrics)
        Task {
            await self.fetchAndMergeHealthKit()
            DispatchQueue.main.async { self.isLoading = false }
        }

        // 2. Request scores/car from iPhone (if reachable)
        if phoneReachable {
            WatchConnectivityManager.shared.requestDataFromPhone()
        }
    }

    /// Detects midnight crossover and resets daily metrics
    private func checkForDayChange() {
        let currentDay = Calendar.current.component(.day, from: Date())
        if currentDay != lastKnownDay {
            print("⌚ [DataManager] 🌙 Midnight crossover detected! Day \(lastKnownDay) → \(currentDay)")
            lastKnownDay = currentDay

            dataQueue.sync {
                var reset = self.healthData
                reset.steps = 0
                reset.moveCalories = 0
                reset.exerciseMinutes = 0
                reset.standHours = 0
                reset.heartRate = 0
                reset.sleepHours = 0
                self.commitData(reset)
            }
        }
    }

    // MARK: - Periodic Auto-Refresh

    /// Starts a repeating timer that refreshes HealthKit data every 5 minutes.
    /// Call this once when the app becomes active.
    func startPeriodicRefresh() {
        // Don't create duplicate timers
        guard refreshTimer == nil else {
            print("⌚ [DataManager] ⏱️ Periodic refresh already running")
            return
        }
        print("⌚ [DataManager] ⏱️ Starting periodic HealthKit refresh (every \(Int(autoRefreshInterval))s)")
        refreshTimer = Timer.scheduledTimer(withTimeInterval: autoRefreshInterval, repeats: true) { [weak self] _ in
            print("⌚ [DataManager] ⏱️ Periodic refresh fired")
            Task {
                await self?.fetchAndMergeHealthKit()
            }
        }
    }

    /// Stops the periodic refresh timer (when app goes to background)
    func stopPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        print("⌚ [DataManager] ⏱️ Periodic refresh stopped")
    }

    /// Ensures HealthKit authorization at app launch
    func ensureHealthKitAuthorization() {
        Task {
            do {
                let _ = try await WatchHealthKitManager.shared.requestAuthorization()
                print("⌚ [DataManager] ✅ HealthKit authorized")
            } catch {
                print("⌚ [DataManager] ⚠️ HealthKit auth error (non-fatal): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Background HealthKit Observers

    /// Sets up HKObserverQuery + enableBackgroundDelivery for key metrics.
    /// This allows the app to be woken in the background when new HealthKit data arrives.
    private func setupBackgroundHealthKitObservers() {
        guard !backgroundDeliveryEnabled else { return }
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let healthStore = HKHealthStore()

        // Key types to observe — these change frequently on the watch
        let observedTypes: [(HKQuantityTypeIdentifier, HKUpdateFrequency)] = [
            (.stepCount, .immediate),
            (.activeEnergyBurned, .immediate),
            (.heartRate, .immediate),
            (.appleExerciseTime, .hourly),
            (.restingHeartRate, .hourly),
            (.heartRateVariabilitySDNN, .hourly),
        ]

        for (typeId, frequency) in observedTypes {
            guard let sampleType = HKQuantityType.quantityType(forIdentifier: typeId) else { continue }

            // Enable background delivery
            healthStore.enableBackgroundDelivery(for: sampleType, frequency: frequency) { success, error in
                if success {
                    print("⌚ [DataManager] ✅ Background delivery enabled for \(typeId.rawValue)")
                } else if let error = error {
                    print("⌚ [DataManager] ⚠️ Background delivery failed for \(typeId.rawValue): \(error.localizedDescription)")
                }
            }

            // Create observer query
            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completionHandler, error in
                if let error = error {
                    print("⌚ [DataManager] ⚠️ Observer error for \(typeId.rawValue): \(error.localizedDescription)")
                    completionHandler()
                    return
                }

                print("⌚ [DataManager] 📡 HealthKit update for \(typeId.rawValue) — fetching fresh data")
                Task {
                    await self?.fetchAndMergeHealthKit()
                    completionHandler()
                }
            }

            healthStore.execute(query)
            observerQueries.append(query)
        }

        backgroundDeliveryEnabled = true
        print("⌚ [DataManager] ✅ Background HealthKit observers set up for \(observedTypes.count) types")
    }

    // MARK: - Background Refresh Scheduling

    /// Schedules the next WKApplicationRefreshBackgroundTask.
    /// The system will wake the app in ~15 minutes to refresh data.
    func scheduleNextBackgroundRefresh() {
        let preferredDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes from now
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: preferredDate,
            userInfo: nil
        ) { error in
            if let error = error {
                print("⌚ [DataManager] ⚠️ Failed to schedule background refresh: \(error.localizedDescription)")
            } else {
                print("⌚ [DataManager] ⏰ Background refresh scheduled for ~\(preferredDate)")
            }
        }
    }

    /// Called when the system wakes the app via WKApplicationRefreshBackgroundTask
    func handleBackgroundRefresh() async {
        print("⌚ [DataManager] 🔄 Background refresh task executing")
        checkForDayChange()
        await fetchAndMergeHealthKit()
        scheduleNextBackgroundRefresh()
    }

    // MARK: - Local HealthKit fetch + merge

    /// Fetches HealthKit data and merges it atomically with current state.
    /// Only updates HealthKit-owned fields. NEVER touches iPhone-owned fields.
    private func fetchAndMergeHealthKit() async {
        // Authorize (fire-and-forget errors)
        do {
            let _ = try await WatchHealthKitManager.shared.requestAuthorization()
        } catch {
            print("⌚ [DataManager] ⚠️ Auth error (non-fatal): \(error.localizedDescription)")
        }

        // Fetch HealthKit metrics
        do {
            let localData = try await WatchHealthKitManager.shared.fetchTodayData()
            print("⌚ [DataManager] 📊 Local HealthKit: steps=\(localData.steps), cal=\(localData.moveCalories), ex=\(localData.exerciseMinutes)m, stand=\(localData.standHours)h, hr=\(localData.heartRate), rhr=\(localData.restingHeartRate), hrv=\(localData.hrv), sleep=\(localData.sleepHours)h")

            // Merge atomically on serial queue
            dataQueue.sync {
                var merged = self.healthData  // Read LATEST state (has iPhone scores)

                // Only update HealthKit-owned fields
                merged.steps = localData.steps
                merged.heartRate = localData.heartRate
                merged.restingHeartRate = localData.restingHeartRate
                merged.hrv = localData.hrv
                merged.sleepHours = localData.sleepHours
                merged.moveCalories = localData.moveCalories
                merged.exerciseMinutes = localData.exerciseMinutes
                merged.standHours = localData.standHours

                // Update goals from HealthKit if they are non-zero
                if localData.moveGoal > 0 { merged.moveGoal = localData.moveGoal }
                if localData.exerciseGoal > 0 { merged.exerciseGoal = localData.exerciseGoal }
                if localData.standGoal > 0 { merged.standGoal = localData.standGoal }

                merged.lastUpdated = Date()

                print("⌚ [DataManager] ✅ HealthKit merge: score=\(merged.healthScore), steps=\(merged.steps), hr=\(merged.heartRate), sleep=\(merged.sleepHours)h, car=\(merged.carName)")
                self.commitData(merged)
            }
        } catch {
            print("⌚ [DataManager] ❌ Local HealthKit fetch failed: \(error.localizedDescription)")
            DispatchQueue.main.async { self.lastError = "Failed to fetch local data" }
        }
    }
}
