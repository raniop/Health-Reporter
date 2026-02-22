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

    /// The set of HealthKit types we need to read (safe — skips any nil types)
    private var typesToRead: Set<HKObjectType> {
        var types: Set<HKObjectType> = []

        // Activity
        let quantityIds: [HKQuantityTypeIdentifier] = [
            .stepCount, .activeEnergyBurned, .appleExerciseTime,
            .heartRate, .restingHeartRate, .heartRateVariabilitySDNN
        ]
        for id in quantityIds {
            if let t = HKQuantityType.quantityType(forIdentifier: id) { types.insert(t) }
        }

        let categoryIds: [HKCategoryTypeIdentifier] = [
            .appleStandHour, .sleepAnalysis
        ]
        for id in categoryIds {
            if let t = HKCategoryType.categoryType(forIdentifier: id) { types.insert(t) }
        }

        // Activity summary for goals
        types.insert(HKObjectType.activitySummaryType())
        return types
    }

    /// Requests HealthKit authorization for Watch-available types.
    /// Safe to call multiple times - concurrent calls will await the same result.
    func requestAuthorization() async throws -> Bool {
        guard isHealthKitAvailable else {
            print("⌚️ [HK] ❌ HealthKit NOT AVAILABLE on this device!")
            throw WatchHealthKitError.notAvailable
        }

        // If already authorized, return immediately
        if isAuthorized {
            print("⌚️ [HK] Already authorized — skipping")
            return true
        }

        // If there's an existing authorization task in progress, await its result
        if let existingTask = authorizationTask {
            print("⌚️ [HK] Awaiting existing authorization task...")
            return try await existingTask.value
        }

        print("⌚️ [HK] Requesting authorization for \(typesToRead.count) types...")

        // Create a new authorization task
        let task = Task<Bool, Error> {
            defer { self.authorizationTask = nil }

            let success = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
                healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
                    if let error = error {
                        print("⌚️ [HK] ❌ Authorization error: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    } else {
                        print("⌚️ [HK] Authorization result: \(success ? "✅ granted" : "⚠️ denied")")
                        continuation.resume(returning: success)
                    }
                }
            }

            self.isAuthorized = success
            if success {
                self.logAuthorizationStatuses()
            }
            return success
        }

        authorizationTask = task
        return try await task.value
    }

    /// Logs the authorization status for each HealthKit type (for debugging)
    /// Note: For READ-only types, Apple always returns .sharingDenied (privacy protection)
    /// This is normal - it doesn't mean the user denied access
    private func logAuthorizationStatuses() {
        print("⌚️ [HK] Authorization statuses:")
        for type in typesToRead {
            let status = healthStore.authorizationStatus(for: type)
            let statusStr: String
            switch status {
            case .notDetermined: statusStr = "NOT_DETERMINED"
            case .sharingDenied: statusStr = "SHARING_DENIED (normal for read-only)"
            case .sharingAuthorized: statusStr = "AUTHORIZED"
            @unknown default: statusStr = "UNKNOWN"
            }
            // Shorten the identifier for readability
            let shortId = type.identifier.replacingOccurrences(of: "HKQuantityTypeIdentifier", with: "")
                .replacingOccurrences(of: "HKCategoryTypeIdentifier", with: "")
            print("⌚️ [HK]   \(shortId) → \(statusStr)")
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
            results.append("Steps: \(steps.map { "\(Int($0))" } ?? "nil")")
        } catch {
            results.append("Steps ERROR: \(error.localizedDescription)")
        }

        do {
            let hr = try await fetchLatestQuantity(.heartRate)
            results.append("HR: \(hr.map { "\(Int($0))" } ?? "nil")")
        } catch {
            results.append("HR ERROR: \(error.localizedDescription)")
        }

        do {
            let cal = try await fetchSumQuantity(.activeEnergyBurned, start: startOfDay, end: now)
            results.append("Cal: \(cal.map { "\(Int($0))" } ?? "nil")")
        } catch {
            results.append("Cal ERROR: \(error.localizedDescription)")
        }

        let diagnostic = results.joined(separator: "\n")
        print("⌚️ HealthKit Diagnostic:\n\(diagnostic)")
        return diagnostic
    }

    /// Ensures authorization and fetches data - convenience method for startup
    func ensureAuthorizationAndFetch() async -> WatchHealthData? {
        print("⌚️ [HK] ensureAuthorizationAndFetch starting...")
        let startTime = CFAbsoluteTimeGetCurrent()
        do {
            let authorized = try await requestAuthorization()
            guard authorized else {
                print("⌚️ [HK] ❌ Not authorized, cannot fetch local data")
                return nil
            }
            let data = try await fetchTodayData()
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            print("⌚️ [HK] ✅ ensureAuthorizationAndFetch complete in \(String(format: "%.2f", elapsed))s — steps=\(data.steps), hr=\(data.heartRate)")
            return data
        } catch {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            print("⌚️ [HK] ❌ Auth or fetch error after \(String(format: "%.2f", elapsed))s: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Data Fetching

    /// Fetches today's health data for standalone mode
    func fetchTodayData() async throws -> WatchHealthData {
        let fetchStart = CFAbsoluteTimeGetCurrent()
        print("⌚️ [HK] fetchTodayData starting...")

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
        // Sleep query: start from 18:00 (6pm) yesterday — matches iPhone's HealthKitManager logic.
        // This captures last night's sleep without including the previous day's naps.
        let sleepQueryStart = calendar.date(byAdding: .hour, value: -6, to: startOfDay) ?? startOfDay
        async let sleepHours = fetchSleepHours(start: sleepQueryStart, end: now)

        let stepsValue = try await steps ?? 0
        let caloriesValue = try await calories ?? 0
        let exerciseValue = try await exercise ?? 0
        let standHours = try await standHoursCount ?? 0
        let heartRateValue = try await heartRate ?? 0
        let restingHRValue = try await restingHR ?? 0
        let hrvValue = try await hrv ?? 0
        let sleepValue = try await sleepHours ?? 0

        let queriesElapsed = CFAbsoluteTimeGetCurrent() - fetchStart

        // Detailed logging for debugging
        print("⌚️ [HK] 📊 fetchTodayData results (queries took \(String(format: "%.2f", queriesElapsed))s):")
        print("⌚️ [HK]   steps=\(Int(stepsValue)), calories=\(Int(caloriesValue)), exercise=\(Int(exerciseValue))min")
        print("⌚️ [HK]   standHours=\(Int(standHours)), heartRate=\(Int(heartRateValue))bpm, restingHR=\(Int(restingHRValue))bpm")
        print("⌚️ [HK]   hrv=\(Int(hrvValue))ms, sleep=\(String(format: "%.1f", sleepValue))h")
        print("⌚️ [HK]   timeRange: \(startOfDay) → \(now)")

        // Flag any suspiciously empty values
        if stepsValue == 0 && caloriesValue == 0 && heartRateValue == 0 {
            print("⌚️ [HK] ⚠️ ALL values are 0 — HealthKit may not have data yet or permissions issue")
        }

        // Fetch real activity goals
        let goalsStart = CFAbsoluteTimeGetCurrent()
        let goals = await fetchActivityGoals()
        let goalsElapsed = CFAbsoluteTimeGetCurrent() - goalsStart
        print("⌚️ [HK] 🎯 Goals fetched in \(String(format: "%.2f", goalsElapsed))s: move=\(goals.move)kcal, exercise=\(goals.exercise)min, stand=\(goals.stand)hrs")

        let totalElapsed = CFAbsoluteTimeGetCurrent() - fetchStart
        print("⌚️ [HK] ✅ fetchTodayData complete in \(String(format: "%.2f", totalElapsed))s")

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
            moveGoal: goals.move,
            exerciseMinutes: Int(exerciseValue),
            exerciseGoal: goals.exercise,
            standHours: Int(standHours),
            standGoal: goals.stand,
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

    // MARK: - Activity Goals

    /// Fetches today's activity goals from HKActivitySummary
    func fetchActivityGoals() async -> (move: Int, exercise: Int, stand: Int) {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.era, .year, .month, .day], from: Date())
        components.calendar = calendar
        let predicate = HKQuery.predicate(forActivitySummariesBetweenStart: components, end: components)

        do {
            let goals: (Int, Int, Int) = try await withCheckedThrowingContinuation { continuation in
                let query = HKActivitySummaryQuery(predicate: predicate) { _, summaries, error in
                    if let error = error {
                        print("⌚️ [HK] ❌ Activity goals query error: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                        return
                    }
                    if let summary = summaries?.first {
                        let move = Int(summary.activeEnergyBurnedGoal.doubleValue(for: .kilocalorie()))
                        let exercise = Int(summary.appleExerciseTimeGoal.doubleValue(for: .minute()))
                        let stand = Int(summary.appleStandHoursGoal.doubleValue(for: .count()))
                        print("⌚️ [HK] 🎯 Raw goals from ActivitySummary: move=\(move), exercise=\(exercise), stand=\(stand)")
                        continuation.resume(returning: (
                            move > 0 ? move : 500,
                            exercise > 0 ? exercise : 30,
                            stand > 0 ? stand : 12
                        ))
                    } else {
                        print("⌚️ [HK] ⚠️ No ActivitySummary found for today — using defaults (500/30/12)")
                        continuation.resume(returning: (500, 30, 12))
                    }
                }
                healthStore.execute(query)
            }
            return goals
        } catch {
            print("⌚️ [HK] ❌ Activity goals fetch failed: \(error.localizedDescription) — using defaults (500/30/12)")
            return (500, 30, 12)
        }
    }

    // MARK: - Private Helpers

    private func fetchSumQuantity(_ identifier: HKQuantityTypeIdentifier, start: Date, end: Date) async throws -> Double? {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            print("⌚️ [HK] ⚠️ Unknown quantity type: \(identifier.rawValue)")
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
                    print("⌚️ [HK] ❌ Sum query error for \(identifier.rawValue): \(error.localizedDescription)")
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
            print("⌚️ [HK] ⚠️ Unknown quantity type: \(identifier.rawValue)")
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
                    print("⌚️ [HK] ❌ Latest query error for \(identifier.rawValue): \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }

                guard let sample = samples?.first as? HKQuantitySample else {
                    print("⌚️ [HK] ⚠️ No samples found for \(identifier.rawValue)")
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
            print("⌚️ [HK] ⚠️ Sleep analysis type not available")
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
                    print("⌚️ [HK] ❌ Sleep query error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }

                guard let samples = samples as? [HKCategorySample] else {
                    print("⌚️ [HK] ⚠️ No sleep samples found")
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

                // Merge overlapping intervals before summing (same as iPhone's HealthKitManager)
                let intervals: [(start: Date, end: Date)] = asleepSamples.map { ($0.startDate, $0.endDate) }
                let merged = Self.mergeOverlappingSleepIntervals(intervals)
                let totalSeconds = merged.reduce(0.0) { sum, iv in
                    sum + iv.end.timeIntervalSince(iv.start)
                }

                let hours = totalSeconds / 3600.0
                print("⌚️ [HK] 😴 Sleep: \(samples.count) total samples, \(asleepSamples.count) asleep, \(merged.count) merged intervals = \(String(format: "%.1f", hours))h")
                continuation.resume(returning: hours)
            }
            healthStore.execute(query)
        }
    }

    /// Merge overlapping sleep segments — summing merged intervals, not raw sum.
    /// Identical to iPhone's HealthKitManager.mergeOverlappingSleepIntervals().
    private static func mergeOverlappingSleepIntervals(_ intervals: [(start: Date, end: Date)]) -> [(start: Date, end: Date)] {
        guard !intervals.isEmpty else { return [] }
        let sorted = intervals.sorted { $0.start < $1.start }
        var out: [(start: Date, end: Date)] = [sorted[0]]
        for i in 1..<sorted.count {
            let cur = sorted[i]
            let last = out.last!
            if cur.start <= last.end {
                out[out.count - 1] = (last.start, max(cur.end, last.end))
            } else {
                out.append(cur)
            }
        }
        return out
    }

    private func fetchStandHours(start: Date, end: Date) async throws -> Double? {
        guard let standType = HKCategoryType.categoryType(forIdentifier: .appleStandHour) else {
            print("⌚️ [HK] ⚠️ Stand hour type not available")
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
                    print("⌚️ [HK] ❌ Stand hours query error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }

                guard let samples = samples as? [HKCategorySample] else {
                    print("⌚️ [HK] ⚠️ No stand hour samples found")
                    continuation.resume(returning: nil)
                    return
                }

                // Count only hours where user stood (value == 0 means stood)
                let standHours = samples.filter { $0.value == HKCategoryValueAppleStandHour.stood.rawValue }.count
                print("⌚️ [HK] 🧍 Stand: \(samples.count) total samples, \(standHours) stood hours")
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
