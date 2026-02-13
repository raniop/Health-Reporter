//
//  WatchHealthKitManager.swift
//  Health Reporter Watch App
//
//  Manages HealthKit queries for standalone Watch mode
//

import Foundation
import HealthKit

/// Manages HealthKit access on Apple Watch for standalone mode
class WatchHealthKitManager {
    static let shared = WatchHealthKitManager()

    private let healthStore = HKHealthStore()

    /// Track whether we've already requested authorization this session
    private(set) var isAuthorized: Bool = false
    private var authorizationTask: Task<Bool, Error>?

    private init() {}

    // MARK: - Authorization

    /// Checks if HealthKit is available
    var isHealthKitAvailable: Bool {
        return HKHealthStore.isHealthDataAvailable()
    }

    /// The set of HealthKit types we need to read
    private var typesToRead: Set<HKObjectType> {
        [
            // Activity
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKCategoryType.categoryType(forIdentifier: .appleStandHour)!,

            // Heart
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!,
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,

            // Sleep
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!,
        ]
    }

    /// Requests HealthKit authorization for Watch-available types.
    /// Safe to call multiple times - concurrent calls will await the same result.
    func requestAuthorization() async throws -> Bool {
        guard isHealthKitAvailable else {
            print("⌚️ HealthKit: NOT AVAILABLE on this device!")
            throw WatchHealthKitError.notAvailable
        }

        // If already authorized, return immediately
        if isAuthorized {
            return true
        }

        // If there's an existing authorization task in progress, await its result
        if let existingTask = authorizationTask {
            print("⌚️ HealthKit: Awaiting existing authorization task...")
            return try await existingTask.value
        }

        // Create a new authorization task
        let task = Task<Bool, Error> {
            print("⌚️ HealthKit: Requesting authorization for \(typesToRead.count) types...")

            let success = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
                healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
                    if let error = error {
                        print("⌚️ HealthKit: Authorization ERROR: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    } else {
                        print("⌚️ HealthKit: requestAuthorization callback success=\(success)")
                        continuation.resume(returning: success)
                    }
                }
            }

            self.isAuthorized = success
            logAuthorizationStatuses()
            return success
        }

        authorizationTask = task
        return try await task.value
    }

    /// Logs the authorization status for each HealthKit type (for debugging)
    /// Note: For READ-only types, Apple always returns .sharingDenied (privacy protection)
    /// This is normal - it doesn't mean the user denied access
    private func logAuthorizationStatuses() {
        for type in typesToRead {
            let status = healthStore.authorizationStatus(for: type)
            let statusStr: String
            switch status {
            case .notDetermined: statusStr = "NOT_DETERMINED"
            case .sharingDenied: statusStr = "SHARING_DENIED (normal for read-only)"
            case .sharingAuthorized: statusStr = "AUTHORIZED"
            @unknown default: statusStr = "UNKNOWN"
            }
            print("⌚️ HealthKit: \(type.identifier) → \(statusStr)")
        }
    }

    /// Performs a quick diagnostic query to check if HealthKit data is actually accessible
    func runDiagnostic() async -> String {
        guard isHealthKitAvailable else { return "HealthKit NOT available" }

        var results: [String] = []

        // Try to read step count to verify read access works
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        do {
            let steps = try await fetchSumQuantity(.stepCount, start: startOfDay, end: now)
            results.append("Steps: \(steps != nil ? "\(Int(steps!))" : "nil")")
        } catch {
            results.append("Steps ERROR: \(error.localizedDescription)")
        }

        do {
            let hr = try await fetchLatestQuantity(.heartRate)
            results.append("HR: \(hr != nil ? "\(Int(hr!))" : "nil")")
        } catch {
            results.append("HR ERROR: \(error.localizedDescription)")
        }

        do {
            let cal = try await fetchSumQuantity(.activeEnergyBurned, start: startOfDay, end: now)
            results.append("Cal: \(cal != nil ? "\(Int(cal!))" : "nil")")
        } catch {
            results.append("Cal ERROR: \(error.localizedDescription)")
        }

        let diagnostic = results.joined(separator: "\n")
        print("⌚️ HealthKit Diagnostic:\n\(diagnostic)")
        return diagnostic
    }

    /// Ensures authorization and fetches data - convenience method for startup
    func ensureAuthorizationAndFetch() async -> WatchHealthData? {
        do {
            let authorized = try await requestAuthorization()
            guard authorized else {
                print("⌚️ HealthKit: Not authorized, cannot fetch local data")
                return nil
            }
            let data = try await fetchTodayData()
            print("⌚️ HealthKit: Local fetch successful - score=\(data.healthScore), steps=\(data.steps)")
            return data
        } catch {
            print("⌚️ HealthKit: Auth or fetch error: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Data Fetching

    /// Fetches today's health data for standalone mode
    func fetchTodayData() async throws -> WatchHealthData {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        async let steps = fetchSumQuantity(.stepCount, start: startOfDay, end: now)
        async let calories = fetchSumQuantity(.activeEnergyBurned, start: startOfDay, end: now)
        async let exercise = fetchSumQuantity(.appleExerciseTime, start: startOfDay, end: now)
        async let standHoursCount = fetchStandHours(start: startOfDay, end: now)
        async let heartRate = fetchLatestQuantity(.heartRate)
        async let restingHR = fetchLatestQuantity(.restingHeartRate)
        async let hrv = fetchLatestQuantity(.heartRateVariabilitySDNN)
        async let sleepHours = fetchSleepHours(start: calendar.date(byAdding: .day, value: -1, to: startOfDay)!, end: now)

        let stepsValue = try await steps ?? 0
        let caloriesValue = try await calories ?? 0
        let exerciseValue = try await exercise ?? 0
        let standHours = try await standHoursCount ?? 0
        let heartRateValue = try await heartRate ?? 0
        let restingHRValue = try await restingHR ?? 0
        let hrvValue = try await hrv ?? 0
        let sleepValue = try await sleepHours ?? 0

        // Detailed logging for debugging
        print("⌚️ HealthKit fetchTodayData results:")
        print("  steps=\(stepsValue), calories=\(caloriesValue), exercise=\(exerciseValue)")
        print("  standHours=\(standHours), heartRate=\(heartRateValue), restingHR=\(restingHRValue)")
        print("  hrv=\(hrvValue), sleep=\(sleepValue)h")
        print("  timeRange: \(startOfDay) → \(now)")

        // Return raw HealthKit metrics only - no score/tier calculation
        // Real health score and car tier come only from iPhone
        return WatchHealthData(
            healthScore: 0,
            healthStatus: "",
            reliabilityScore: 0,
            carTierIndex: 0,
            carName: "",
            carEmoji: "",
            carTierLabel: "",
            geminiCarName: nil,
            geminiCarScore: nil,
            geminiCarTierIndex: nil,
            moveCalories: Int(caloriesValue),
            moveGoal: 500,
            exerciseMinutes: Int(exerciseValue),
            exerciseGoal: 30,
            standHours: Int(standHours),
            standGoal: 12,
            steps: Int(stepsValue),
            heartRate: Int(heartRateValue),
            restingHeartRate: Int(restingHRValue),
            hrv: Int(hrvValue),
            sleepHours: sleepValue,
            recoveryScore: nil,
            sleepScore: nil,
            nervousSystemScore: nil,
            energyScore: nil,
            activityScore: nil,
            loadBalanceScore: nil,
            lastUpdated: Date(),
            isFromPhone: false
        )
    }

    // MARK: - Private Helpers

    private func fetchSumQuantity(_ identifier: HKQuantityTypeIdentifier, start: Date, end: Date) async throws -> Double? {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let unit = self.preferredUnit(for: identifier)
                let value = statistics?.sumQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    private func fetchLatestQuantity(_ identifier: HKQuantityTypeIdentifier) async throws -> Double? {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return nil
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }

                let unit = self.preferredUnit(for: identifier)
                let value = sample.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    private func fetchSleepHours(start: Date, end: Date) async throws -> Double? {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: nil)
                    return
                }

                // Filter for asleep states only
                let asleepSamples = samples.filter { sample in
                    if #available(watchOS 9.0, *) {
                        return sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                               sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                               sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                    } else {
                        return sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue
                    }
                }

                let totalSeconds = asleepSamples.reduce(0.0) { sum, sample in
                    sum + sample.endDate.timeIntervalSince(sample.startDate)
                }

                let hours = totalSeconds / 3600.0
                continuation.resume(returning: hours)
            }
            healthStore.execute(query)
        }
    }

    private func fetchStandHours(start: Date, end: Date) async throws -> Double? {
        guard let standType = HKCategoryType.categoryType(forIdentifier: .appleStandHour) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: standType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: nil)
                    return
                }

                // Count only hours where user stood (value == 0 means stood)
                let standHours = samples.filter { $0.value == HKCategoryValueAppleStandHour.stood.rawValue }.count
                continuation.resume(returning: Double(standHours))
            }
            healthStore.execute(query)
        }
    }

    private func preferredUnit(for identifier: HKQuantityTypeIdentifier) -> HKUnit {
        switch identifier {
        case .stepCount:
            return .count()
        case .activeEnergyBurned:
            return .kilocalorie()
        case .appleExerciseTime, .appleStandTime:
            return .minute()
        case .heartRate, .restingHeartRate:
            return HKUnit.count().unitDivided(by: .minute())
        case .heartRateVariabilitySDNN:
            return .secondUnit(with: .milli)
        default:
            return .count()
        }
    }

}

// MARK: - Errors

enum WatchHealthKitError: Error, LocalizedError {
    case notAvailable
    case authorizationDenied
    case queryFailed

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .authorizationDenied:
            return "HealthKit authorization was denied"
        case .queryFailed:
            return "Failed to query HealthKit data"
        }
    }
}
