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

    private init() {}

    // MARK: - Authorization

    /// Checks if HealthKit is available
    var isHealthKitAvailable: Bool {
        return HKHealthStore.isHealthDataAvailable()
    }

    /// Requests HealthKit authorization for Watch-available types
    func requestAuthorization() async throws -> Bool {
        guard isHealthKitAvailable else {
            throw WatchHealthKitError.notAvailable
        }

        let typesToRead: Set<HKObjectType> = [
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

        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
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

        // Calculate a simple health score for standalone mode
        let healthScore = calculateSimpleScore(
            steps: Int(stepsValue),
            exerciseMinutes: Int(exerciseValue),
            sleepHours: sleepValue,
            restingHR: Int(restingHRValue),
            hrv: Int(hrvValue)
        )

        let tier = tierForScore(healthScore)

        return WatchHealthData(
            healthScore: healthScore,
            healthStatus: tier.status,
            reliabilityScore: 60, // Lower reliability for standalone
            carTierIndex: tier.index,
            carName: tier.name,
            carEmoji: tier.emoji,
            carTierLabel: tier.label,
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

    // MARK: - Simple Scoring

    private func calculateSimpleScore(steps: Int, exerciseMinutes: Int, sleepHours: Double, restingHR: Int, hrv: Int) -> Int {
        var score: Double = 50 // Base score

        // Steps contribution (max 20 points)
        let stepsScore = min(20.0, Double(steps) / 10000.0 * 20.0)
        score += stepsScore

        // Exercise contribution (max 15 points)
        let exerciseScore = min(15.0, Double(exerciseMinutes) / 30.0 * 15.0)
        score += exerciseScore

        // Sleep contribution (max 25 points)
        if sleepHours >= 7.0 && sleepHours <= 9.0 {
            score += 25
        } else if sleepHours >= 6.0 {
            score += 15
        } else if sleepHours >= 5.0 {
            score += 5
        }

        // HRV contribution (max 10 points) - higher is better
        if hrv > 0 {
            let hrvScore = min(10.0, Double(hrv) / 60.0 * 10.0)
            score += hrvScore
        }

        // Resting HR contribution (max 10 points) - lower is better
        if restingHR > 0 && restingHR < 100 {
            let hrScore = max(0.0, 10.0 - Double(restingHR - 50) / 5.0)
            score += hrScore
        }

        return min(100, max(0, Int(score)))
    }

    private func tierForScore(_ score: Int) -> (index: Int, name: String, emoji: String, status: String, label: String) {
        switch score {
        case 0..<25:
            return (0, "Fiat Panda", "🚙", "Needs Attention", "Needs Attention")
        case 25..<45:
            return (1, "Toyota Corolla", "🚗", "Okay", "Okay")
        case 45..<65:
            return (2, "BMW M3", "🏎️", "Good", "Good Condition")
        case 65..<82:
            return (3, "Porsche 911 Turbo", "🏁", "Excellent", "Excellent")
        default:
            return (4, "Ferrari SF90 Stradale", "🏆", "Peak", "Peak Performance")
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
