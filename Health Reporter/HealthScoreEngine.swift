//
//  HealthScoreEngine.swift
//  Health Reporter
//
//  מנוע חישוב ציוני בריאות מקומי (ללא LLM).
//  מחשב HealthScore (0-100) ו-ReliabilityScore (0-100).
//

import Foundation

// MARK: - Enums

/// סטטוס כיסוי נתונים
enum CoverageStatus: String, Codable {
    case unavailable    // < 5 ימים תקינים
    case limited        // 5-13 ימים (משקל × 0.6)
    case good           // 14-29 ימים (משקל × 1.0)
    case highCoverage   // >= 30 ימים (משקל × 1.05)

    var weightMultiplier: Double {
        switch self {
        case .unavailable: return 0.0
        case .limited: return 0.6
        case .good: return 1.0
        case .highCoverage: return 1.05
        }
    }

    static func from(validDays: Int) -> CoverageStatus {
        switch validDays {
        case ..<5: return .unavailable
        case 5..<14: return .limited
        case 14..<30: return .good
        default: return .highCoverage
        }
    }
}

/// דומיינים של בריאות
enum HealthDomain: String, CaseIterable, Codable {
    case recovery       // HRV, RHR, readiness, stress
    case sleep          // sleepHours
    case fitness        // VO2max, trainingLoad trend
    case loadBalance    // Acute/Chronic ratio
    case activityBase   // steps, consistency

    var baseWeight: Double {
        switch self {
        case .recovery: return 0.30
        case .sleep: return 0.20
        case .fitness: return 0.20
        case .loadBalance: return 0.20
        case .activityBase: return 0.10
        }
    }

    var displayName: String {
        switch self {
        case .recovery: return "Recovery"
        case .sleep: return "Sleep"
        case .fitness: return "Fitness"
        case .loadBalance: return "Load Balance"
        case .activityBase: return "Activity"
        }
    }
}

/// מדדי בריאות
enum HealthMetric: String, CaseIterable, Codable {
    case sleepHours
    case hrvMs
    case restingHR
    case vo2max
    case steps
    case trainingLoad
    case stressScore
    case readinessScore

    var validRange: ClosedRange<Double> {
        switch self {
        case .sleepHours: return 2.0...12.0
        case .hrvMs: return 15.0...150.0
        case .restingHR: return 35.0...100.0
        case .vo2max: return 25.0...85.0
        case .steps: return 500.0...80000.0
        case .trainingLoad: return 0.0...5000.0
        case .stressScore: return 0.0...100.0
        case .readinessScore: return 0.0...100.0
        }
    }

    var domain: HealthDomain {
        switch self {
        case .hrvMs, .restingHR, .readinessScore, .stressScore: return .recovery
        case .sleepHours: return .sleep
        case .vo2max: return .fitness
        case .trainingLoad: return .loadBalance
        case .steps: return .activityBase
        }
    }
}

// MARK: - Result Types

struct MetricBreakdown: Codable {
    let metricName: String
    let rawValue: Double?
    let normalizedScore: Double
    let coverage90: Int
    let coverage14: Int
    let coverageStatus: CoverageStatus
    let weightMultiplier: Double
    let notes: String
}

struct DomainBreakdown: Codable {
    let domainName: String
    let rawWeight: Double
    let normalizedWeight: Double
    let domainScore: Double
    let usedMetrics: [MetricBreakdown]
    let notes: String
}

struct HealthScoringResult: Codable {
    let healthScore: Double
    let reliabilityScore: Double
    let includedDomains: [DomainBreakdown]
    let excludedDomains: [String]
    let metricCoverage90: [String: Int]
    let metricCoverage14: [String: Int]
    let outlierCounts: [String: Int]
    let dataGapFlags: [String: Bool]
    let calculatedAt: Date

    // Convenience properties
    var healthScoreInt: Int { Int(round(healthScore)) }
    var reliabilityScoreInt: Int { Int(round(reliabilityScore)) }
    var isHighReliability: Bool { reliabilityScore >= 70 }
    var isLowReliability: Bool { reliabilityScore < 40 }
}

// MARK: - Internal Types

private struct CleanedDayEntry {
    let date: Date
    var sleepHours: Double?
    var hrvMs: Double?
    var restingHR: Double?
    var vo2max: Double?
    var steps: Double?
    var trainingLoad: Double?
    var stressScore: Double?
    var readinessScore: Double?
}

private struct CleanedData {
    let entries: [Date: CleanedDayEntry]
    let sortedDates: [Date]
    let outlierCounts: [HealthMetric: Int]
    let totalDays: Int
}

private struct CoverageResult {
    let coverage90: [HealthMetric: Int]
    let coverage14: [HealthMetric: Int]
    let coverageStatus: [HealthMetric: CoverageStatus]
    let dataGaps: [String: Bool]
}

private struct Averages {
    var sleep7d: Double?
    var sleep28d: Double?
    var sleep90d: Double?
    var hrv7d: Double?
    var hrv28d: Double?
    var hrv90d: Double?
    var rhr7d: Double?
    var rhr90d: Double?
    var vo2max7d: Double?
    var vo2max90d: Double?
    var readiness7d: Double?
    var stress7d: Double?
    var trainingLoad7d: Double?
    var trainingLoad28d: Double?
    var steps7d: Double?
    var steps90d: Double?
    var daysWithStepsOver6000in7d: Int = 0
}

private struct DomainResult {
    let domain: HealthDomain
    let score: Double
    let weight: Double
    let breakdown: DomainBreakdown
    let isAvailable: Bool
}

// MARK: - Engine

final class HealthScoreEngine {

    // MARK: - Singleton
    static let shared = HealthScoreEngine()
    private init() {}

    // MARK: - Configuration
    struct Configuration {
        var minDaysForMetric: Int = 5
        var limitedCoverageThreshold: Int = 14
        var highCoverageThreshold: Int = 30
        var coverageTargetSleep: Double = 0.6
        var coverageTargetHRV: Double = 0.6
        var coverageTargetOthers: Double = 0.8
        var gapPenaltyDays: Int = 5
        var outlierPenaltyThreshold: Double = 0.05
    }

    var configuration = Configuration()

    // MARK: - Public API

    func calculate(from entries: [RawDailyHealthEntry]) -> HealthScoringResult {
        // Handle empty data
        guard !entries.isEmpty else {
            return createEmptyResult()
        }

        // Step 0: Clean data
        let cleanedData = cleanData(from: entries)

        // Step 1: Calculate coverage
        let coverage = calculateCoverage(from: cleanedData)

        // Steps 2-4: Calculate domain scores
        let domainResults = calculateDomainScores(cleanedData: cleanedData, coverage: coverage)

        // Step 5: Calculate final health score
        let (healthScore, includedDomains, excludedDomains) = calculateFinalHealthScore(domainResults: domainResults)

        // Step 6: Calculate reliability score
        let reliabilityScore = calculateReliabilityScore(
            coverage: coverage,
            outlierCounts: cleanedData.outlierCounts,
            totalDays: cleanedData.totalDays
        )

        // Step 7: Build result
        return HealthScoringResult(
            healthScore: healthScore,
            reliabilityScore: reliabilityScore,
            includedDomains: includedDomains,
            excludedDomains: excludedDomains,
            metricCoverage90: coverage.coverage90.reduce(into: [:]) { $0[$1.key.rawValue] = $1.value },
            metricCoverage14: coverage.coverage14.reduce(into: [:]) { $0[$1.key.rawValue] = $1.value },
            outlierCounts: cleanedData.outlierCounts.reduce(into: [:]) { $0[$1.key.rawValue] = $1.value },
            dataGapFlags: coverage.dataGaps,
            calculatedAt: Date()
        )
    }

    func calculateAsync(from entries: [RawDailyHealthEntry], completion: @escaping (HealthScoringResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.calculate(from: entries)
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    // MARK: - Step 0: Data Cleaning

    private func cleanData(from entries: [RawDailyHealthEntry]) -> CleanedData {
        var cleanedEntries: [Date: CleanedDayEntry] = [:]
        var outlierCounts: [HealthMetric: Int] = [:]

        for metric in HealthMetric.allCases {
            outlierCounts[metric] = 0
        }

        for entry in entries {
            var cleaned = CleanedDayEntry(date: entry.date)

            cleaned.sleepHours = cleanValue(entry.sleepHours, metric: .sleepHours, outlierCounts: &outlierCounts)
            cleaned.hrvMs = cleanValue(entry.hrvMs, metric: .hrvMs, outlierCounts: &outlierCounts)
            cleaned.restingHR = cleanValue(entry.restingHR, metric: .restingHR, outlierCounts: &outlierCounts)
            cleaned.vo2max = cleanValue(entry.vo2max, metric: .vo2max, outlierCounts: &outlierCounts)
            cleaned.steps = cleanValue(entry.steps, metric: .steps, outlierCounts: &outlierCounts)
            cleaned.trainingLoad = cleanValue(entry.trainingLoad, metric: .trainingLoad, outlierCounts: &outlierCounts)
            // Note: stressScore not in RawDailyHealthEntry, skip for now
            cleaned.readinessScore = cleanValue(entry.readinessScore, metric: .readinessScore, outlierCounts: &outlierCounts)

            cleanedEntries[entry.date] = cleaned
        }

        let sortedDates = cleanedEntries.keys.sorted()

        return CleanedData(
            entries: cleanedEntries,
            sortedDates: sortedDates,
            outlierCounts: outlierCounts,
            totalDays: entries.count
        )
    }

    private func cleanValue(_ value: Double?, metric: HealthMetric, outlierCounts: inout [HealthMetric: Int]) -> Double? {
        // Step 1: Normalize missing (nil, 0, NaN, Inf => nil)
        guard let v = value, v != 0, !v.isNaN, !v.isInfinite else {
            return nil
        }

        // Step 2: Check outlier range
        let range = metric.validRange
        if !range.contains(v) {
            outlierCounts[metric, default: 0] += 1
            return nil
        }

        return v
    }

    // MARK: - Step 1: Coverage Calculation

    private func calculateCoverage(from cleanedData: CleanedData) -> CoverageResult {
        var coverage90: [HealthMetric: Int] = [:]
        var coverage14: [HealthMetric: Int] = [:]

        for metric in HealthMetric.allCases {
            coverage90[metric] = 0
            coverage14[metric] = 0
        }

        let last14Dates = Set(cleanedData.sortedDates.suffix(14))

        for (date, entry) in cleanedData.entries {
            let isLast14 = last14Dates.contains(date)

            if entry.sleepHours != nil {
                coverage90[.sleepHours, default: 0] += 1
                if isLast14 { coverage14[.sleepHours, default: 0] += 1 }
            }
            if entry.hrvMs != nil {
                coverage90[.hrvMs, default: 0] += 1
                if isLast14 { coverage14[.hrvMs, default: 0] += 1 }
            }
            if entry.restingHR != nil {
                coverage90[.restingHR, default: 0] += 1
                if isLast14 { coverage14[.restingHR, default: 0] += 1 }
            }
            if entry.vo2max != nil {
                coverage90[.vo2max, default: 0] += 1
                if isLast14 { coverage14[.vo2max, default: 0] += 1 }
            }
            if entry.steps != nil {
                coverage90[.steps, default: 0] += 1
                if isLast14 { coverage14[.steps, default: 0] += 1 }
            }
            if entry.trainingLoad != nil {
                coverage90[.trainingLoad, default: 0] += 1
                if isLast14 { coverage14[.trainingLoad, default: 0] += 1 }
            }
            if entry.readinessScore != nil {
                coverage90[.readinessScore, default: 0] += 1
                if isLast14 { coverage14[.readinessScore, default: 0] += 1 }
            }
        }

        // Determine coverage status
        var coverageStatus: [HealthMetric: CoverageStatus] = [:]
        for (metric, count) in coverage90 {
            coverageStatus[metric] = CoverageStatus.from(validDays: count)
        }

        // Detect gaps
        let dataGaps = detectDataGaps(cleanedData: cleanedData, metrics: [.sleepHours, .hrvMs])

        return CoverageResult(
            coverage90: coverage90,
            coverage14: coverage14,
            coverageStatus: coverageStatus,
            dataGaps: dataGaps
        )
    }

    private func detectDataGaps(cleanedData: CleanedData, metrics: [HealthMetric]) -> [String: Bool] {
        var gaps: [String: Bool] = [:]

        for metric in metrics {
            var consecutiveMissing = 0
            var hasLargeGap = false

            for date in cleanedData.sortedDates {
                let entry = cleanedData.entries[date]
                let hasValue: Bool

                switch metric {
                case .sleepHours: hasValue = entry?.sleepHours != nil
                case .hrvMs: hasValue = entry?.hrvMs != nil
                default: hasValue = false
                }

                if hasValue {
                    consecutiveMissing = 0
                } else {
                    consecutiveMissing += 1
                    if consecutiveMissing > configuration.gapPenaltyDays {
                        hasLargeGap = true
                        break
                    }
                }
            }

            gaps[metric.rawValue] = hasLargeGap
        }

        return gaps
    }

    // MARK: - Step 2-3: Metric Normalization

    /// Linear interpolation between anchor points
    private func interpolate(value: Double, anchors: [(Double, Double)]) -> Double {
        guard anchors.count >= 2 else { return 50 }

        let sorted = anchors.sorted { $0.0 < $1.0 }

        // Below minimum anchor
        if value <= sorted.first!.0 {
            return sorted.first!.1
        }

        // Above maximum anchor
        if value >= sorted.last!.0 {
            return sorted.last!.1
        }

        // Find bracketing anchors and interpolate
        for i in 0..<(sorted.count - 1) {
            let (x1, y1) = sorted[i]
            let (x2, y2) = sorted[i + 1]

            if value >= x1 && value <= x2 {
                let t = (value - x1) / (x2 - x1)
                return y1 + t * (y2 - y1)
            }
        }

        return 50 // Fallback
    }

    // 1) Sleep Score
    private func normalizeSleep(avg7d: Double?, avg28d: Double?, avg90d: Double?) -> Double? {
        guard let sleep = avg7d ?? avg28d ?? avg90d else { return nil }

        // Anchors: <=5h->40, 6h->60, 7h->80, 8h->95, 9h->90, >=10h->80
        let anchors: [(Double, Double)] = [
            (5.0, 40.0),
            (6.0, 60.0),
            (7.0, 80.0),
            (8.0, 95.0),
            (9.0, 90.0),
            (10.0, 80.0)
        ]

        return interpolate(value: sleep, anchors: anchors)
    }

    // 2) HRV Score (relative to baseline)
    private func normalizeHRV(avg7d: Double?, baseline90d: Double?, baseline28d: Double?) -> Double? {
        let baseline = baseline90d ?? baseline28d
        guard let hrv7d = avg7d, let base = baseline, base > 0 else { return nil }

        let ratio = hrv7d / base

        // Anchors: <=0.75->40, 0.85->60, 1.00->80, 1.10->90, >=1.20->95
        let anchors: [(Double, Double)] = [
            (0.75, 40.0),
            (0.85, 60.0),
            (1.00, 80.0),
            (1.10, 90.0),
            (1.20, 95.0)
        ]

        return interpolate(value: ratio, anchors: anchors)
    }

    // 3) RHR Score (lower is better)
    private func normalizeRHR(avg7d: Double?, baseline90d: Double?) -> Double? {
        guard let rhr7d = avg7d, let base = baseline90d, base > 0 else { return nil }

        let delta = base - rhr7d  // Positive = improvement

        // Anchors: <=-5->40, -2->60, 0->75, +3->88, >=+6->95
        let anchors: [(Double, Double)] = [
            (-5.0, 40.0),
            (-2.0, 60.0),
            (0.0, 75.0),
            (3.0, 88.0),
            (6.0, 95.0)
        ]

        return interpolate(value: delta, anchors: anchors)
    }

    // 4) Readiness Score (already 0-100)
    private func normalizeReadiness(avg7d: Double?) -> Double? {
        guard let readiness = avg7d else { return nil }
        return min(100, max(0, readiness))
    }

    // 5) Stress Score (lower is better)
    private func normalizeStress(avg7d: Double?) -> Double? {
        guard let stress = avg7d else { return nil }

        // Ranges: 0-25=>90, 25-50=>75, 50-75=>60, 75-100=>45
        let anchors: [(Double, Double)] = [
            (0.0, 90.0),
            (25.0, 90.0),
            (50.0, 75.0),
            (75.0, 60.0),
            (100.0, 45.0)
        ]

        return interpolate(value: stress, anchors: anchors)
    }

    // 6) VO2max Score (relative to baseline)
    private func normalizeVO2max(avg7d: Double?, baseline90d: Double?) -> Double? {
        guard let vo27d = avg7d, let base = baseline90d, base > 0 else { return nil }

        let ratio = vo27d / base

        // Anchors: <=0.95->60, 1.00->75, 1.05->88, >=1.10->95
        let anchors: [(Double, Double)] = [
            (0.95, 60.0),
            (1.00, 75.0),
            (1.05, 88.0),
            (1.10, 95.0)
        ]

        return interpolate(value: ratio, anchors: anchors)
    }

    // 7) Load Balance Score (Acute/Chronic ratio)
    private func normalizeLoadBalance(acute7d: Double?, chronic28d: Double?) -> Double? {
        guard let acute = acute7d, let chronic = chronic28d, chronic > 0 else { return nil }

        let ratio = acute / chronic

        // Optimal: 0.8-1.2
        switch ratio {
        case 0.8...1.2: return 90
        case 0.7..<0.8: return 75
        case 1.2..<1.3: return 75
        case 0.6..<0.7: return 60
        case 1.3..<1.4: return 60
        default: return 45
        }
    }

    // 8) Activity Base Score (steps ratio + consistency)
    private func normalizeActivityBase(
        stepsAvg7d: Double?,
        stepsAvg90d: Double?,
        daysWithStepsOver6000in7d: Int
    ) -> Double? {
        // Steps ratio score (70% weight)
        var stepsRatioScore: Double?
        if let steps7d = stepsAvg7d, let steps90d = stepsAvg90d, steps90d > 0 {
            let ratio = steps7d / steps90d
            let anchors: [(Double, Double)] = [
                (0.70, 55.0),
                (0.85, 70.0),
                (1.00, 80.0),
                (1.15, 90.0),
                (1.30, 95.0)
            ]
            stepsRatioScore = interpolate(value: ratio, anchors: anchors)
        }

        // Consistency score (30% weight)
        let consistencyScore: Double
        switch daysWithStepsOver6000in7d {
        case 5...7: consistencyScore = 90
        case 3...4: consistencyScore = 75
        case 1...2: consistencyScore = 55
        default: consistencyScore = 40
        }

        // Combine
        if let srs = stepsRatioScore {
            return srs * 0.7 + consistencyScore * 0.3
        } else if daysWithStepsOver6000in7d > 0 {
            return consistencyScore
        } else {
            return nil
        }
    }

    // MARK: - Step 4: Domain Calculation

    private func calculateDomainScores(cleanedData: CleanedData, coverage: CoverageResult) -> [DomainResult] {
        let averages = calculateAverages(from: cleanedData)

        var results: [DomainResult] = []

        // Recovery Domain
        results.append(calculateRecoveryDomain(averages: averages, coverage: coverage))

        // Sleep Domain
        results.append(calculateSleepDomain(averages: averages, coverage: coverage))

        // Fitness Domain
        results.append(calculateFitnessDomain(averages: averages, coverage: coverage))

        // Load Balance Domain
        results.append(calculateLoadBalanceDomain(averages: averages, coverage: coverage))

        // Activity Base Domain
        results.append(calculateActivityBaseDomain(averages: averages, coverage: coverage))

        return results
    }

    private func calculateAverages(from cleanedData: CleanedData) -> Averages {
        let calendar = Calendar.current
        let sortedDates = cleanedData.sortedDates
        guard let today = sortedDates.last else { return Averages() }

        func datesInRange(days: Int) -> [Date] {
            sortedDates.filter { date in
                guard let daysAgo = calendar.dateComponents([.day], from: date, to: today).day else { return false }
                return daysAgo >= 0 && daysAgo < days
            }
        }

        func average(_ values: [Double?]) -> Double? {
            let valid = values.compactMap { $0 }
            guard !valid.isEmpty else { return nil }
            return valid.reduce(0, +) / Double(valid.count)
        }

        let dates7d = datesInRange(days: 7)
        let dates28d = datesInRange(days: 28)
        let dates90d = sortedDates

        var avg = Averages()

        // Sleep
        avg.sleep7d = average(dates7d.map { cleanedData.entries[$0]?.sleepHours })
        avg.sleep28d = average(dates28d.map { cleanedData.entries[$0]?.sleepHours })
        avg.sleep90d = average(dates90d.map { cleanedData.entries[$0]?.sleepHours })

        // HRV
        avg.hrv7d = average(dates7d.map { cleanedData.entries[$0]?.hrvMs })
        avg.hrv28d = average(dates28d.map { cleanedData.entries[$0]?.hrvMs })
        avg.hrv90d = average(dates90d.map { cleanedData.entries[$0]?.hrvMs })

        // RHR
        avg.rhr7d = average(dates7d.map { cleanedData.entries[$0]?.restingHR })
        avg.rhr90d = average(dates90d.map { cleanedData.entries[$0]?.restingHR })

        // VO2max
        avg.vo2max7d = average(dates7d.map { cleanedData.entries[$0]?.vo2max })
        avg.vo2max90d = average(dates90d.map { cleanedData.entries[$0]?.vo2max })

        // Readiness
        avg.readiness7d = average(dates7d.map { cleanedData.entries[$0]?.readinessScore })

        // Stress (not available in current data model)
        avg.stress7d = nil

        // Training Load
        avg.trainingLoad7d = average(dates7d.map { cleanedData.entries[$0]?.trainingLoad })
        avg.trainingLoad28d = average(dates28d.map { cleanedData.entries[$0]?.trainingLoad })

        // Steps
        avg.steps7d = average(dates7d.map { cleanedData.entries[$0]?.steps })
        avg.steps90d = average(dates90d.map { cleanedData.entries[$0]?.steps })

        // Count days with steps >= 6000 in last 7 days
        avg.daysWithStepsOver6000in7d = dates7d.filter { date in
            if let steps = cleanedData.entries[date]?.steps, steps >= 6000 {
                return true
            }
            return false
        }.count

        return avg
    }

    // MARK: - Domain Calculators

    private func calculateRecoveryDomain(averages: Averages, coverage: CoverageResult) -> DomainResult {
        let domain = HealthDomain.recovery
        var metrics: [MetricBreakdown] = []
        var totalWeight = 0.0
        var weightedSum = 0.0

        // Internal weights for Recovery domain
        let internalWeights: [(HealthMetric, Double)] = [
            (.hrvMs, 0.35),
            (.restingHR, 0.25),
            (.readinessScore, 0.30),
            (.stressScore, 0.10)
        ]

        for (metric, baseWeight) in internalWeights {
            let status = coverage.coverageStatus[metric] ?? .unavailable
            guard status != .unavailable else { continue }

            let multiplier = status.weightMultiplier
            let adjustedWeight = baseWeight * multiplier

            var normalizedScore: Double?
            var rawValue: Double?

            switch metric {
            case .hrvMs:
                normalizedScore = normalizeHRV(avg7d: averages.hrv7d, baseline90d: averages.hrv90d, baseline28d: averages.hrv28d)
                rawValue = averages.hrv7d
            case .restingHR:
                normalizedScore = normalizeRHR(avg7d: averages.rhr7d, baseline90d: averages.rhr90d)
                rawValue = averages.rhr7d
            case .readinessScore:
                normalizedScore = normalizeReadiness(avg7d: averages.readiness7d)
                rawValue = averages.readiness7d
            case .stressScore:
                normalizedScore = normalizeStress(avg7d: averages.stress7d)
                rawValue = averages.stress7d
            default:
                continue
            }

            if let score = normalizedScore {
                totalWeight += adjustedWeight
                weightedSum += score * adjustedWeight

                metrics.append(MetricBreakdown(
                    metricName: metric.rawValue,
                    rawValue: rawValue,
                    normalizedScore: score,
                    coverage90: coverage.coverage90[metric] ?? 0,
                    coverage14: coverage.coverage14[metric] ?? 0,
                    coverageStatus: status,
                    weightMultiplier: multiplier,
                    notes: ""
                ))
            }
        }

        let isAvailable = totalWeight > 0
        let domainScore = isAvailable ? weightedSum / totalWeight : 0

        // Apply high coverage bonus (max +2 points)
        var finalScore = domainScore
        if coverage.coverageStatus[.hrvMs] == .highCoverage ||
           coverage.coverageStatus[.restingHR] == .highCoverage {
            finalScore = min(100, domainScore + 2)
        }

        let breakdown = DomainBreakdown(
            domainName: domain.displayName,
            rawWeight: domain.baseWeight,
            normalizedWeight: 0, // Will be set in final calculation
            domainScore: finalScore,
            usedMetrics: metrics,
            notes: isAvailable ? "" : "Insufficient data for recovery domain"
        )

        print("Domain[\(domain.rawValue)]: score=\(finalScore), available=\(isAvailable), metrics=\(metrics.count)")

        return DomainResult(
            domain: domain,
            score: finalScore,
            weight: domain.baseWeight,
            breakdown: breakdown,
            isAvailable: isAvailable
        )
    }

    private func calculateSleepDomain(averages: Averages, coverage: CoverageResult) -> DomainResult {
        let domain = HealthDomain.sleep
        let metric = HealthMetric.sleepHours
        let status = coverage.coverageStatus[metric] ?? .unavailable

        guard status != .unavailable else {
            return DomainResult(
                domain: domain,
                score: 0,
                weight: domain.baseWeight,
                breakdown: DomainBreakdown(
                    domainName: domain.displayName,
                    rawWeight: domain.baseWeight,
                    normalizedWeight: 0,
                    domainScore: 0,
                    usedMetrics: [],
                    notes: "Insufficient sleep data"
                ),
                isAvailable: false
            )
        }

        let normalizedScore = normalizeSleep(avg7d: averages.sleep7d, avg28d: averages.sleep28d, avg90d: averages.sleep90d) ?? 50

        // Apply high coverage bonus
        var finalScore = normalizedScore
        if status == .highCoverage {
            finalScore = min(100, normalizedScore + 2)
        }

        let breakdown = DomainBreakdown(
            domainName: domain.displayName,
            rawWeight: domain.baseWeight,
            normalizedWeight: 0,
            domainScore: finalScore,
            usedMetrics: [
                MetricBreakdown(
                    metricName: metric.rawValue,
                    rawValue: averages.sleep7d,
                    normalizedScore: normalizedScore,
                    coverage90: coverage.coverage90[metric] ?? 0,
                    coverage14: coverage.coverage14[metric] ?? 0,
                    coverageStatus: status,
                    weightMultiplier: status.weightMultiplier,
                    notes: ""
                )
            ],
            notes: ""
        )

        print("Domain[\(domain.rawValue)]: score=\(finalScore), sleep7d=\(averages.sleep7d ?? 0)")

        return DomainResult(
            domain: domain,
            score: finalScore,
            weight: domain.baseWeight,
            breakdown: breakdown,
            isAvailable: true
        )
    }

    private func calculateFitnessDomain(averages: Averages, coverage: CoverageResult) -> DomainResult {
        let domain = HealthDomain.fitness
        var metrics: [MetricBreakdown] = []
        var totalWeight = 0.0
        var weightedSum = 0.0

        // VO2max (primary)
        let vo2Status = coverage.coverageStatus[.vo2max] ?? .unavailable
        if vo2Status != .unavailable {
            if let score = normalizeVO2max(avg7d: averages.vo2max7d, baseline90d: averages.vo2max90d) {
                let weight = 0.7 * vo2Status.weightMultiplier
                totalWeight += weight
                weightedSum += score * weight

                metrics.append(MetricBreakdown(
                    metricName: HealthMetric.vo2max.rawValue,
                    rawValue: averages.vo2max7d,
                    normalizedScore: score,
                    coverage90: coverage.coverage90[.vo2max] ?? 0,
                    coverage14: coverage.coverage14[.vo2max] ?? 0,
                    coverageStatus: vo2Status,
                    weightMultiplier: vo2Status.weightMultiplier,
                    notes: ""
                ))
            }
        }

        // Training load trend (secondary)
        let loadStatus = coverage.coverageStatus[.trainingLoad] ?? .unavailable
        if loadStatus != .unavailable, let load7d = averages.trainingLoad7d, let load28d = averages.trainingLoad28d, load28d > 0 {
            // Higher load = more fitness building
            let ratio = load7d / load28d
            let trendScore: Double
            switch ratio {
            case 1.1...: trendScore = 90  // Building
            case 0.9..<1.1: trendScore = 80  // Maintaining
            case 0.7..<0.9: trendScore = 65  // Detraining slightly
            default: trendScore = 50  // Significant detraining
            }

            let weight = 0.3 * loadStatus.weightMultiplier
            totalWeight += weight
            weightedSum += trendScore * weight

            metrics.append(MetricBreakdown(
                metricName: "trainingLoadTrend",
                rawValue: ratio,
                normalizedScore: trendScore,
                coverage90: coverage.coverage90[.trainingLoad] ?? 0,
                coverage14: coverage.coverage14[.trainingLoad] ?? 0,
                coverageStatus: loadStatus,
                weightMultiplier: loadStatus.weightMultiplier,
                notes: ""
            ))
        }

        let isAvailable = totalWeight > 0
        let domainScore = isAvailable ? weightedSum / totalWeight : 0

        let breakdown = DomainBreakdown(
            domainName: domain.displayName,
            rawWeight: domain.baseWeight,
            normalizedWeight: 0,
            domainScore: domainScore,
            usedMetrics: metrics,
            notes: isAvailable ? "" : "Insufficient fitness data"
        )

        print("Domain[\(domain.rawValue)]: score=\(domainScore), available=\(isAvailable)")

        return DomainResult(
            domain: domain,
            score: domainScore,
            weight: domain.baseWeight,
            breakdown: breakdown,
            isAvailable: isAvailable
        )
    }

    private func calculateLoadBalanceDomain(averages: Averages, coverage: CoverageResult) -> DomainResult {
        let domain = HealthDomain.loadBalance
        let status = coverage.coverageStatus[.trainingLoad] ?? .unavailable

        guard status != .unavailable else {
            return DomainResult(
                domain: domain,
                score: 0,
                weight: domain.baseWeight,
                breakdown: DomainBreakdown(
                    domainName: domain.displayName,
                    rawWeight: domain.baseWeight,
                    normalizedWeight: 0,
                    domainScore: 0,
                    usedMetrics: [],
                    notes: "Insufficient training load data"
                ),
                isAvailable: false
            )
        }

        let normalizedScore = normalizeLoadBalance(acute7d: averages.trainingLoad7d, chronic28d: averages.trainingLoad28d) ?? 75

        let ratio: Double? = {
            guard let acute = averages.trainingLoad7d, let chronic = averages.trainingLoad28d, chronic > 0 else { return nil }
            return acute / chronic
        }()

        let breakdown = DomainBreakdown(
            domainName: domain.displayName,
            rawWeight: domain.baseWeight,
            normalizedWeight: 0,
            domainScore: normalizedScore,
            usedMetrics: [
                MetricBreakdown(
                    metricName: "acuteChronicRatio",
                    rawValue: ratio,
                    normalizedScore: normalizedScore,
                    coverage90: coverage.coverage90[.trainingLoad] ?? 0,
                    coverage14: coverage.coverage14[.trainingLoad] ?? 0,
                    coverageStatus: status,
                    weightMultiplier: status.weightMultiplier,
                    notes: ""
                )
            ],
            notes: ""
        )

        print("Domain[\(domain.rawValue)]: score=\(normalizedScore), ratio=\(ratio ?? 0)")

        return DomainResult(
            domain: domain,
            score: normalizedScore,
            weight: domain.baseWeight,
            breakdown: breakdown,
            isAvailable: true
        )
    }

    private func calculateActivityBaseDomain(averages: Averages, coverage: CoverageResult) -> DomainResult {
        let domain = HealthDomain.activityBase
        let status = coverage.coverageStatus[.steps] ?? .unavailable

        guard status != .unavailable else {
            return DomainResult(
                domain: domain,
                score: 0,
                weight: domain.baseWeight,
                breakdown: DomainBreakdown(
                    domainName: domain.displayName,
                    rawWeight: domain.baseWeight,
                    normalizedWeight: 0,
                    domainScore: 0,
                    usedMetrics: [],
                    notes: "Insufficient steps data"
                ),
                isAvailable: false
            )
        }

        let normalizedScore = normalizeActivityBase(
            stepsAvg7d: averages.steps7d,
            stepsAvg90d: averages.steps90d,
            daysWithStepsOver6000in7d: averages.daysWithStepsOver6000in7d
        ) ?? 50

        let breakdown = DomainBreakdown(
            domainName: domain.displayName,
            rawWeight: domain.baseWeight,
            normalizedWeight: 0,
            domainScore: normalizedScore,
            usedMetrics: [
                MetricBreakdown(
                    metricName: HealthMetric.steps.rawValue,
                    rawValue: averages.steps7d,
                    normalizedScore: normalizedScore,
                    coverage90: coverage.coverage90[.steps] ?? 0,
                    coverage14: coverage.coverage14[.steps] ?? 0,
                    coverageStatus: status,
                    weightMultiplier: status.weightMultiplier,
                    notes: "Consistency: \(averages.daysWithStepsOver6000in7d)/7 days >= 6000 steps"
                )
            ],
            notes: ""
        )

        print("Domain[\(domain.rawValue)]: score=\(normalizedScore), steps7d=\(averages.steps7d ?? 0), consistency=\(averages.daysWithStepsOver6000in7d)")

        return DomainResult(
            domain: domain,
            score: normalizedScore,
            weight: domain.baseWeight,
            breakdown: breakdown,
            isAvailable: true
        )
    }

    // MARK: - Step 5: Final Health Score

    private func calculateFinalHealthScore(domainResults: [DomainResult]) -> (score: Double, includedDomains: [DomainBreakdown], excludedDomains: [String]) {
        let availableDomains = domainResults.filter { $0.isAvailable }
        let excludedDomainNames = domainResults.filter { !$0.isAvailable }.map { $0.domain.displayName }

        // Handle edge case: no domains available
        guard !availableDomains.isEmpty else {
            return (50.0, [], HealthDomain.allCases.map { $0.displayName })
        }

        // Normalize weights to sum to 1.0
        let totalWeight = availableDomains.reduce(0.0) { $0 + $1.weight }

        var normalizedBreakdowns: [DomainBreakdown] = []
        var weightedSum = 0.0

        for domain in availableDomains {
            let normalizedWeight = domain.weight / totalWeight
            weightedSum += domain.score * normalizedWeight

            // Update breakdown with normalized weight
            let updatedBreakdown = DomainBreakdown(
                domainName: domain.breakdown.domainName,
                rawWeight: domain.breakdown.rawWeight,
                normalizedWeight: normalizedWeight,
                domainScore: domain.breakdown.domainScore,
                usedMetrics: domain.breakdown.usedMetrics,
                notes: domain.breakdown.notes
            )
            normalizedBreakdowns.append(updatedBreakdown)
        }

        // Clamp final score
        let finalScore = min(100, max(0, weightedSum))

        return (finalScore, normalizedBreakdowns, excludedDomainNames)
    }

    // MARK: - Step 6: Reliability Score

    private func calculateReliabilityScore(
        coverage: CoverageResult,
        outlierCounts: [HealthMetric: Int],
        totalDays: Int
    ) -> Double {
        // A) Coverage component (0-80)
        let criticalMetrics: [(HealthMetric, Double, Double)] = [
            (.sleepHours, 20.0, configuration.coverageTargetSleep),
            (.hrvMs, 20.0, configuration.coverageTargetHRV),
            (.restingHR, 15.0, configuration.coverageTargetOthers),
            (.trainingLoad, 15.0, configuration.coverageTargetOthers),
            (.steps, 10.0, configuration.coverageTargetOthers)
        ]

        var coverageComponent = 0.0
        for (metric, weight, target) in criticalMetrics {
            let count = coverage.coverage90[metric] ?? 0
            let ratio = Double(count) / 90.0
            let metricReliability = weight * min(1.0, ratio / target)
            coverageComponent += metricReliability
        }

        // B) Freshness component (0-20)
        var freshnessComponent = 0.0
        if (coverage.coverage14[.sleepHours] ?? 0) >= 8 { freshnessComponent += 6 }
        if (coverage.coverage14[.hrvMs] ?? 0) >= 8 { freshnessComponent += 6 }
        if (coverage.coverage14[.restingHR] ?? 0) >= 10 { freshnessComponent += 3 }
        if (coverage.coverage14[.trainingLoad] ?? 0) >= 10 { freshnessComponent += 3 }
        if (coverage.coverage14[.steps] ?? 0) >= 10 { freshnessComponent += 2 }

        // C) Penalties
        var penalties = 0.0

        // Gap penalty: >5 consecutive days without sleep or HRV
        if coverage.dataGaps[HealthMetric.sleepHours.rawValue] == true ||
           coverage.dataGaps[HealthMetric.hrvMs.rawValue] == true {
            penalties += 10
        }

        // Outlier penalty: >5% of days with outliers in critical metrics
        let criticalOutlierMetrics: [HealthMetric] = [.sleepHours, .hrvMs, .restingHR]
        let totalOutliers = criticalOutlierMetrics.reduce(0) { $0 + (outlierCounts[$1] ?? 0) }
        if totalDays > 0 && Double(totalOutliers) / Double(totalDays * criticalOutlierMetrics.count) > configuration.outlierPenaltyThreshold {
            penalties += 5
        }

        // Final reliability score
        let reliabilityScore = coverageComponent + freshnessComponent - penalties
        return min(100, max(0, reliabilityScore))
    }

    // MARK: - Helpers

    private func createEmptyResult() -> HealthScoringResult {
        return HealthScoringResult(
            healthScore: 50.0,
            reliabilityScore: 0.0,
            includedDomains: [],
            excludedDomains: HealthDomain.allCases.map { $0.displayName },
            metricCoverage90: [:],
            metricCoverage14: [:],
            outlierCounts: [:],
            dataGapFlags: [:],
            calculatedAt: Date()
        )
    }
}
