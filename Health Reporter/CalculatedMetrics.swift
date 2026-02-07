//
//  CalculatedMetrics.swift
//  Health Reporter
//
//  Calculated metrics engine for metrics that Garmin/Oura devices don't sync to Apple Health:
//  - Readiness Score (similar to Oura/WHOOP)
//  - Training Strain
//  - Sleep Efficiency
//

import Foundation
import HealthKit

// MARK: - Readiness Score

/// Calculated readiness score (0-100)
struct ReadinessScore {
    let score: Int                      // 0-100
    let components: ReadinessComponents
    let dataSource: HealthDataSource
    let calculatedAt: Date
    let isCalculated: Bool              // true = calculated, false = from device

    /// Score description
    var description: String {
        switch score {
        case 85...100: return "Excellent"
        case 70..<85: return "Good"
        case 50..<70: return "Moderate"
        case 30..<50: return "Low"
        default: return "Very Low"
        }
    }

    /// Color by score
    var colorHex: String {
        switch score {
        case 85...100: return "#34C759"  // green
        case 70..<85: return "#30D158"   // light green
        case 50..<70: return "#FFD60A"   // yellow
        case 30..<50: return "#FF9F0A"   // orange
        default: return "#FF453A"        // red
        }
    }
}

/// Readiness score components
struct ReadinessComponents {
    let hrvScore: Double?           // HRV score (0-100)
    let rhrScore: Double?           // Resting heart rate score (0-100)
    let sleepScore: Double?         // Sleep score (0-100)
    let recoveryTrend: Double?      // Recovery trend (-1 to +1)
    let previousDayStrain: Double?  // Previous day strain (0-10)

    /// Component weights
    static let hrvWeight: Double = 0.35
    static let rhrWeight: Double = 0.25
    static let sleepWeight: Double = 0.30
    static let recoveryWeight: Double = 0.10
}

// MARK: - Training Strain

/// Calculated training strain
struct TrainingStrain {
    let score: Double                           // 0-10 (or 0-21 in WHOOP style)
    let heartRateZones: [Int: TimeInterval]     // zone -> time in seconds
    let peakHR: Double?
    let avgHR: Double?
    let duration: TimeInterval
    let trainingEffect: TrainingEffect
    let calculatedAt: Date

    /// Normalized score to 0-10
    var normalizedScore: Double {
        min(10, score)
    }

    /// Strain description
    var description: String {
        switch normalizedScore {
        case 8...10: return "Very High Load"
        case 6..<8: return "High Load"
        case 4..<6: return "Moderate Load"
        case 2..<4: return "Light Load"
        default: return "Recovery"
        }
    }
}

/// Training effect
/// NOTE: These raw values were previously Hebrew strings. Changing them breaks deserialization
/// of any previously persisted/encoded TrainingEffect values. A data migration may be needed.
enum TrainingEffect: String, Codable {
    case recovery = "Recovery"
    case maintaining = "Maintaining"
    case improving = "Improving"
    case highlyImproving = "Highly Improving"
    case overreaching = "Overreaching"

    var colorHex: String {
        switch self {
        case .recovery: return "#34C759"
        case .maintaining: return "#30D158"
        case .improving: return "#FFD60A"
        case .highlyImproving: return "#FF9F0A"
        case .overreaching: return "#FF453A"
        }
    }
}

// MARK: - Sleep Metrics

/// Sleep efficiency
struct SleepEfficiency {
    let percentage: Double          // 0-100
    let totalSleepTime: TimeInterval
    let timeInBed: TimeInterval
    let awakeTime: TimeInterval

    var description: String {
        switch percentage {
        case 90...100: return "Excellent"
        case 85..<90: return "Very Good"
        case 80..<85: return "Good"
        case 70..<80: return "Moderate"
        default: return "Low"
        }
    }
}

/// Detailed sleep stages
struct DetailedSleepStages {
    let deepSleep: TimeInterval
    let remSleep: TimeInterval
    let lightSleep: TimeInterval
    let awakeTime: TimeInterval
    let totalSleep: TimeInterval
    let timeInBed: TimeInterval

    /// Stage percentages
    var deepPercent: Double { totalSleep > 0 ? (deepSleep / totalSleep) * 100 : 0 }
    var remPercent: Double { totalSleep > 0 ? (remSleep / totalSleep) * 100 : 0 }
    var lightPercent: Double { totalSleep > 0 ? (lightSleep / totalSleep) * 100 : 0 }

    /// Whether stages are within healthy range
    var isHealthy: Bool {
        // Deep: 13-23%, REM: 20-25%
        return deepPercent >= 13 && remPercent >= 20
    }
}

// MARK: - Calculated Metrics Engine

/// Calculated metrics engine
final class CalculatedMetricsEngine {
    static let shared = CalculatedMetricsEngine()

    private init() {}

    // MARK: - Readiness Score

    /// Calculate readiness score
    func calculateReadinessScore(
        hrv: Double?,
        hrvBaseline7Day: Double?,
        rhr: Double?,
        rhrBaseline7Day: Double?,
        sleepHours: Double?,
        sleepEfficiency: Double?,
        previousDayStrain: Double?,
        dataSource: HealthDataSource = .autoDetect
    ) -> ReadinessScore {

        var components = ReadinessComponents(
            hrvScore: nil,
            rhrScore: nil,
            sleepScore: nil,
            recoveryTrend: nil,
            previousDayStrain: previousDayStrain
        )

        var totalScore: Double = 0
        var totalWeight: Double = 0

        // 1. HRV Score (35%)
        if let hrv = hrv, let baseline = hrvBaseline7Day, baseline > 0 {
            // Higher HRV relative to baseline = better
            let ratio = hrv / baseline
            let hrvScore = min(100, max(0, ratio * 100))
            components = ReadinessComponents(
                hrvScore: hrvScore,
                rhrScore: components.rhrScore,
                sleepScore: components.sleepScore,
                recoveryTrend: components.recoveryTrend,
                previousDayStrain: components.previousDayStrain
            )
            totalScore += hrvScore * ReadinessComponents.hrvWeight
            totalWeight += ReadinessComponents.hrvWeight
        }

        // 2. RHR Score (25%)
        if let rhr = rhr, let baseline = rhrBaseline7Day, baseline > 0 {
            // Lower RHR relative to baseline = better
            let deviation = (baseline - rhr) / baseline
            let rhrScore = min(100, max(0, 85 + deviation * 50))
            components = ReadinessComponents(
                hrvScore: components.hrvScore,
                rhrScore: rhrScore,
                sleepScore: components.sleepScore,
                recoveryTrend: components.recoveryTrend,
                previousDayStrain: components.previousDayStrain
            )
            totalScore += rhrScore * ReadinessComponents.rhrWeight
            totalWeight += ReadinessComponents.rhrWeight
        }

        // 3. Sleep Score (30%)
        if let hours = sleepHours {
            // 7-9 hours = excellent, less or more = less optimal
            var sleepScore: Double
            if hours >= 7 && hours <= 9 {
                sleepScore = 100
            } else if hours >= 6 && hours < 7 {
                sleepScore = 80
            } else if hours > 9 && hours <= 10 {
                sleepScore = 85
            } else if hours >= 5 && hours < 6 {
                sleepScore = 60
            } else {
                sleepScore = max(20, 40 + hours * 5)
            }

            // Bonus for sleep efficiency
            if let efficiency = sleepEfficiency, efficiency > 85 {
                sleepScore = min(100, sleepScore + 5)
            }

            components = ReadinessComponents(
                hrvScore: components.hrvScore,
                rhrScore: components.rhrScore,
                sleepScore: sleepScore,
                recoveryTrend: components.recoveryTrend,
                previousDayStrain: components.previousDayStrain
            )
            totalScore += sleepScore * ReadinessComponents.sleepWeight
            totalWeight += ReadinessComponents.sleepWeight
        }

        // 4. Recovery from previous strain (10%)
        if let strain = previousDayStrain {
            // High strain on previous day reduces readiness
            let recoveryPenalty = max(0, (strain - 5) * 5)
            let recoveryScore = max(50, 100 - recoveryPenalty)
            components = ReadinessComponents(
                hrvScore: components.hrvScore,
                rhrScore: components.rhrScore,
                sleepScore: components.sleepScore,
                recoveryTrend: nil,
                previousDayStrain: strain
            )
            totalScore += recoveryScore * ReadinessComponents.recoveryWeight
            totalWeight += ReadinessComponents.recoveryWeight
        }

        // Normalize by actual weights
        let finalScore: Int
        if totalWeight > 0 {
            finalScore = Int(round(totalScore / totalWeight))
        } else {
            finalScore = 0 // No data = score 0 (will show "--")
        }

        return ReadinessScore(
            score: min(100, max(0, finalScore)),
            components: components,
            dataSource: dataSource,
            calculatedAt: Date(),
            isCalculated: true
        )
    }

    // MARK: - Training Strain

    /// Calculate training strain from heart rate samples
    func calculateTrainingStrain(
        heartRateSamples: [(value: Double, date: Date)],
        maxHR: Double,
        restingHR: Double = 60
    ) -> TrainingStrain {

        guard !heartRateSamples.isEmpty, maxHR > restingHR else {
            return TrainingStrain(
                score: 0,
                heartRateZones: [:],
                peakHR: nil,
                avgHR: nil,
                duration: 0,
                trainingEffect: .recovery,
                calculatedAt: Date()
            )
        }

        var zones: [Int: TimeInterval] = [1: 0, 2: 0, 3: 0, 4: 0, 5: 0]
        var totalHR: Double = 0
        var peakHR: Double = 0
        var totalDuration: TimeInterval = 0

        // Distribute into zones
        let sortedSamples = heartRateSamples.sorted { $0.date < $1.date }

        for i in 0..<sortedSamples.count {
            let hr = sortedSamples[i].value
            totalHR += hr
            peakHR = max(peakHR, hr)

            // Calculate time until next sample
            let duration: TimeInterval
            if i < sortedSamples.count - 1 {
                duration = sortedSamples[i + 1].date.timeIntervalSince(sortedSamples[i].date)
            } else {
                duration = 60 // last sample - 1 minute
            }

            // Cap duration to reasonable limit (up to 5 minutes)
            let cappedDuration = min(duration, 300)
            totalDuration += cappedDuration

            // Determine zone by percentage of max heart rate
            let hrPercent = (hr - restingHR) / (maxHR - restingHR) * 100
            let zone: Int
            switch hrPercent {
            case ..<50: zone = 1
            case 50..<60: zone = 2
            case 60..<70: zone = 3
            case 70..<80: zone = 4
            default: zone = 5
            }

            zones[zone, default: 0] += cappedDuration
        }

        // Calculate TRIMP (Training Impulse)
        // Weights: Zone 1=1, Zone 2=2, Zone 3=4, Zone 4=7, Zone 5=10
        let zoneMultipliers: [Int: Double] = [1: 1, 2: 2, 3: 4, 4: 7, 5: 10]
        var trimp: Double = 0

        for (zone, duration) in zones {
            let hours = duration / 3600
            trimp += hours * (zoneMultipliers[zone] ?? 1)
        }

        // Normalize to 0-10
        let normalizedScore = min(10, trimp)

        // Determine training effect
        let effect: TrainingEffect
        switch normalizedScore {
        case 0..<2: effect = .recovery
        case 2..<4: effect = .maintaining
        case 4..<6: effect = .improving
        case 6..<8: effect = .highlyImproving
        default: effect = .overreaching
        }

        let avgHR = heartRateSamples.isEmpty ? nil : totalHR / Double(heartRateSamples.count)

        return TrainingStrain(
            score: normalizedScore,
            heartRateZones: zones,
            peakHR: peakHR > 0 ? peakHR : nil,
            avgHR: avgHR,
            duration: totalDuration,
            trainingEffect: effect,
            calculatedAt: Date()
        )
    }

    // MARK: - Sleep Efficiency

    /// Calculate sleep efficiency
    func calculateSleepEfficiency(
        totalSleepTime: TimeInterval,
        timeInBed: TimeInterval
    ) -> SleepEfficiency {
        guard timeInBed > 0 else {
            return SleepEfficiency(
                percentage: 0,
                totalSleepTime: totalSleepTime,
                timeInBed: timeInBed,
                awakeTime: 0
            )
        }

        let efficiency = (totalSleepTime / timeInBed) * 100
        let awakeTime = timeInBed - totalSleepTime

        return SleepEfficiency(
            percentage: min(100, max(0, efficiency)),
            totalSleepTime: totalSleepTime,
            timeInBed: timeInBed,
            awakeTime: max(0, awakeTime)
        )
    }

    // MARK: - HRV Trend

    /// Calculate HRV trend
    func calculateHRVTrend(
        recentHRV: [Double],        // last 7 days
        baselineHRV: Double         // 30-day average
    ) -> Double {
        guard !recentHRV.isEmpty, baselineHRV > 0 else { return 0 }

        let recentAvg = recentHRV.reduce(0, +) / Double(recentHRV.count)
        let deviation = (recentAvg - baselineHRV) / baselineHRV

        // Clamped to -1 to +1
        return min(1, max(-1, deviation))
    }

    // MARK: - Max Heart Rate Estimation

    /// Estimate max heart rate by age
    func estimateMaxHeartRate(age: Int) -> Double {
        // Tanaka formula: 208 - 0.7 * age
        return 208 - 0.7 * Double(age)
    }

    /// Estimate age from observed max heart rate
    func estimateAgeFromMaxHR(observedMaxHR: Double) -> Int {
        // Inverse of Tanaka formula
        return Int((208 - observedMaxHR) / 0.7)
    }

    // MARK: - Sleep Score (Oura-like)

    /// Oura-style sleep score
    func calculateSleepScore(
        totalHours: Double,
        deepHours: Double?,
        remHours: Double?,
        efficiency: Double?,
        latency: TimeInterval? = nil     // time to fall asleep
    ) -> Int {
        var score: Double = 0
        var weight: Double = 0

        // 1. Sleep duration (40%)
        let durationScore: Double
        switch totalHours {
        case 7...9: durationScore = 100
        case 6..<7: durationScore = 80
        case 5..<6: durationScore = 60
        case 9..<10: durationScore = 90
        default: durationScore = max(20, totalHours * 10)
        }
        score += durationScore * 0.4
        weight += 0.4

        // 2. Deep sleep (25%) - target: 1.5-2 hours
        if let deep = deepHours {
            let deepScore: Double
            switch deep {
            case 1.5...2.5: deepScore = 100
            case 1..<1.5: deepScore = 75
            case 2.5..<3: deepScore = 90
            default: deepScore = max(30, deep * 40)
            }
            score += deepScore * 0.25
            weight += 0.25
        }

        // 3. REM (20%) - target: 1.5-2.5 hours
        if let rem = remHours {
            let remScore: Double
            switch rem {
            case 1.5...2.5: remScore = 100
            case 1..<1.5: remScore = 70
            case 2.5..<3: remScore = 90
            default: remScore = max(30, rem * 35)
            }
            score += remScore * 0.2
            weight += 0.2
        }

        // 4. Efficiency (15%)
        if let eff = efficiency {
            let effScore: Double
            switch eff {
            case 90...100: effScore = 100
            case 85..<90: effScore = 90
            case 80..<85: effScore = 75
            default: effScore = max(30, eff)
            }
            score += effScore * 0.15
            weight += 0.15
        }

        // Normalize
        let finalScore = weight > 0 ? score / weight : 50
        return Int(round(min(100, max(0, finalScore))))
    }
}
