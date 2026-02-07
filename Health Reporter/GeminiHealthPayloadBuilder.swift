//
//  GeminiHealthPayloadBuilder.swift
//  Health Reporter
//
//  Builder for processing health data before sending to Gemini.
//  Handles missing values, outliers, and coverage calculation.
//

import Foundation

// MARK: - Daily Payload (last 14 days)

struct GeminiDayPayload: Codable {
    let date: String
    let sleepHours: Double?
    let deepSleepHours: Double?
    let remSleepHours: Double?
    let hrvMs: Double?
    let restingHR: Double?
    let vo2max: Double?
    let steps: Int?
    let activeCalories: Double?
    let trainingLoad: Double?
    let readinessScore: Double?
    let weightKg: Double?
    let bodyFatPercent: Double?
    let missingFields: [String]
    let outlierFields: [String]
}

// MARK: - Weekly Payload (13 weeks)

struct GeminiWeekPayload: Codable {
    let weekNumber: Int  // 1 = last week, 13 = 3 months ago
    let startDate: String
    let endDate: String
    let avgSleepHours: Double?
    let avgDeepSleepHours: Double?
    let avgRemSleepHours: Double?
    let avgHrvMs: Double?
    let avgRestingHR: Double?
    let avgSteps: Double?
    let totalActiveCalories: Double?
    let avgTrainingLoad: Double?
    let avgReadinessScore: Double?
    let avgVO2max: Double?
    let workoutCount: Int?
    let validDaysCount: Int  // how many days with data in the week
}

// MARK: - Main Payload

struct GeminiHealthPayload: Codable {
    let dateRange: DateRangeInfo
    let units: [String: String]

    // 13 weeks for trends
    let weeklySummary: [GeminiWeekPayload]

    // 14 days for current state
    let dailyLast14: [GeminiDayPayload]

    // Metadata
    let coverageValidDays: [String: Int]
    let dataQualityStatus: [String: String]  // INSUFFICIENT / LIMITED / GOOD / HIGH_CONFIDENCE
    let dataQualityFlags: [String]  // Warning flags
    let dataReliabilityScore: Int  // 0-100
    let totalDays: Int

    struct DateRangeInfo: Codable {
        let start: String
        let end: String
    }

    func toJSONString() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Raw Daily Entry (input from HealthKit)

struct RawDailyHealthEntry {
    let date: Date
    var sleepHours: Double?
    var deepSleepHours: Double?
    var remSleepHours: Double?
    var hrvMs: Double?
    var restingHR: Double?
    var vo2max: Double?
    var steps: Double?
    var activeCalories: Double?
    var trainingLoad: Double?
    var readinessScore: Double?
    var weightKg: Double?
    var bodyFatPercent: Double?
    var workoutCount: Int?
}

// MARK: - Builder

final class GeminiHealthPayloadBuilder {

    // MARK: - Reasonable Ranges (Outlier detection)

    private let ranges: [String: ClosedRange<Double>] = [
        "sleepHours": 2.0...14.0,
        "deepSleepHours": 0.5...5.0,
        "remSleepHours": 0.5...4.0,
        "hrvMs": 15.0...150.0,
        "restingHR": 35.0...100.0,
        "vo2max": 25.0...85.0,
        "steps": 500.0...80000.0,
        "activeCalories": 50.0...5000.0,
        "trainingLoad": 0.0...5000.0,
        "readinessScore": 0.0...100.0,
        "weightKg": 30.0...200.0,
        "bodyFatPercent": 3.0...45.0
    ]

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Normalize Missing Values

    /// Convert: 0/nil/NaN → nil (meaning "no measurement")
    private func normalizeMissing(_ value: Double?) -> Double? {
        guard let v = value else { return nil }
        if v == 0 { return nil }
        if v.isNaN { return nil }
        if v.isInfinite { return nil }
        return v
    }

    private func normalizeMissingInt(_ value: Int?) -> Int? {
        guard let v = value else { return nil }
        if v == 0 { return nil }
        return v
    }

    // MARK: - Outlier Detection

    private func isOutlier(_ metric: String, value: Double) -> Bool {
        guard let range = ranges[metric] else { return false }
        return !range.contains(value)
    }

    // MARK: - Build Payload

    func build(from rawDays: [RawDailyHealthEntry]) -> GeminiHealthPayload {
        let sorted = rawDays.sorted { $0.date < $1.date }
        let totalDays = sorted.count

        // Build daily payloads for last 14 days
        let last14 = buildDailyLast14(from: sorted)

        // Build weekly summaries (13 weeks)
        let weeklySummary = buildWeeklySummary(from: sorted)

        // Calculate coverage
        let coverage = calculateCoverage(from: sorted)

        // Determine data quality status for each metric
        let qualityStatus = determineQualityStatus(coverage: coverage, totalDays: totalDays)

        // Generate flags
        let flags = generateFlags(from: sorted, coverage: coverage)

        // Calculate reliability score
        let reliabilityScore = calculateReliabilityScore(coverage: coverage, totalDays: totalDays)

        let start = sorted.first?.date ?? Date()
        let end = sorted.last?.date ?? Date()

        return GeminiHealthPayload(
            dateRange: GeminiHealthPayload.DateRangeInfo(
                start: dateFormatter.string(from: start),
                end: dateFormatter.string(from: end)
            ),
            units: [
                "sleepHours": "hours",
                "deepSleepHours": "hours",
                "remSleepHours": "hours",
                "hrvMs": "ms",
                "restingHR": "bpm",
                "vo2max": "ml/kg/min",
                "steps": "count",
                "activeCalories": "kcal",
                "trainingLoad": "score",
                "readinessScore": "0-100",
                "weightKg": "kg",
                "bodyFatPercent": "%"
            ],
            weeklySummary: weeklySummary,
            dailyLast14: last14,
            coverageValidDays: coverage,
            dataQualityStatus: qualityStatus,
            dataQualityFlags: flags,
            dataReliabilityScore: reliabilityScore,
            totalDays: totalDays
        )
    }

    // MARK: - Build Daily Last 14

    private func buildDailyLast14(from sorted: [RawDailyHealthEntry]) -> [GeminiDayPayload] {
        let last14Days = Array(sorted.suffix(14))

        return last14Days.map { entry in
            var missing: [String] = []
            var outliers: [String] = []

            // Normalize values
            let sleep = normalizeMissing(entry.sleepHours)
            let deep = normalizeMissing(entry.deepSleepHours)
            let rem = normalizeMissing(entry.remSleepHours)
            let hrv = normalizeMissing(entry.hrvMs)
            let rhr = normalizeMissing(entry.restingHR)
            let vo2 = normalizeMissing(entry.vo2max)
            let steps = normalizeMissing(entry.steps)
            let calories = normalizeMissing(entry.activeCalories)
            let load = normalizeMissing(entry.trainingLoad)
            let readiness = normalizeMissing(entry.readinessScore)
            let weight = normalizeMissing(entry.weightKg)
            let bf = normalizeMissing(entry.bodyFatPercent)

            // Track missing fields
            if sleep == nil { missing.append("sleepHours") }
            if hrv == nil { missing.append("hrvMs") }
            if rhr == nil { missing.append("restingHR") }
            if vo2 == nil { missing.append("vo2max") }
            if steps == nil { missing.append("steps") }
            if calories == nil { missing.append("activeCalories") }
            if weight == nil { missing.append("weightKg") }
            if bf == nil { missing.append("bodyFatPercent") }

            // Track outliers
            if let v = sleep, isOutlier("sleepHours", value: v) { outliers.append("sleepHours") }
            if let v = deep, isOutlier("deepSleepHours", value: v) { outliers.append("deepSleepHours") }
            if let v = rem, isOutlier("remSleepHours", value: v) { outliers.append("remSleepHours") }
            if let v = hrv, isOutlier("hrvMs", value: v) { outliers.append("hrvMs") }
            if let v = rhr, isOutlier("restingHR", value: v) { outliers.append("restingHR") }
            if let v = vo2, isOutlier("vo2max", value: v) { outliers.append("vo2max") }
            if let v = steps, isOutlier("steps", value: v) { outliers.append("steps") }
            if let v = calories, isOutlier("activeCalories", value: v) { outliers.append("activeCalories") }
            if let v = load, isOutlier("trainingLoad", value: v) { outliers.append("trainingLoad") }
            if let v = weight, isOutlier("weightKg", value: v) { outliers.append("weightKg") }
            if let v = bf, isOutlier("bodyFatPercent", value: v) { outliers.append("bodyFatPercent") }

            return GeminiDayPayload(
                date: dateFormatter.string(from: entry.date),
                sleepHours: sleep,
                deepSleepHours: deep,
                remSleepHours: rem,
                hrvMs: hrv,
                restingHR: rhr,
                vo2max: vo2,
                steps: steps != nil ? Int(steps!) : nil,
                activeCalories: calories,
                trainingLoad: load,
                readinessScore: readiness,
                weightKg: weight,
                bodyFatPercent: bf,
                missingFields: missing,
                outlierFields: outliers
            )
        }
    }

    // MARK: - Build Weekly Summary

    private func buildWeeklySummary(from sorted: [RawDailyHealthEntry]) -> [GeminiWeekPayload] {
        let calendar = Calendar.current
        var weeks: [GeminiWeekPayload] = []

        // Group by week (13 weeks)
        guard let endDate = sorted.last?.date else { return [] }

        for weekIndex in 0..<13 {
            let weekEndOffset = -weekIndex * 7
            let weekStartOffset = weekEndOffset - 6

            guard let weekEnd = calendar.date(byAdding: .day, value: weekEndOffset, to: endDate),
                  let weekStart = calendar.date(byAdding: .day, value: weekStartOffset, to: endDate) else {
                continue
            }

            // Filter entries for this week
            let weekEntries = sorted.filter { entry in
                entry.date >= calendar.startOfDay(for: weekStart) &&
                entry.date <= calendar.startOfDay(for: weekEnd).addingTimeInterval(86400 - 1)
            }

            if weekEntries.isEmpty {
                // Empty week
                weeks.append(GeminiWeekPayload(
                    weekNumber: weekIndex + 1,
                    startDate: dateFormatter.string(from: weekStart),
                    endDate: dateFormatter.string(from: weekEnd),
                    avgSleepHours: nil,
                    avgDeepSleepHours: nil,
                    avgRemSleepHours: nil,
                    avgHrvMs: nil,
                    avgRestingHR: nil,
                    avgSteps: nil,
                    totalActiveCalories: nil,
                    avgTrainingLoad: nil,
                    avgReadinessScore: nil,
                    avgVO2max: nil,
                    workoutCount: nil,
                    validDaysCount: 0
                ))
                continue
            }

            // Calculate averages (excluding nil/0 values)
            let sleepValues = weekEntries.compactMap { normalizeMissing($0.sleepHours) }.filter { !isOutlier("sleepHours", value: $0) }
            let deepValues = weekEntries.compactMap { normalizeMissing($0.deepSleepHours) }.filter { !isOutlier("deepSleepHours", value: $0) }
            let remValues = weekEntries.compactMap { normalizeMissing($0.remSleepHours) }.filter { !isOutlier("remSleepHours", value: $0) }
            let hrvValues = weekEntries.compactMap { normalizeMissing($0.hrvMs) }.filter { !isOutlier("hrvMs", value: $0) }
            let rhrValues = weekEntries.compactMap { normalizeMissing($0.restingHR) }.filter { !isOutlier("restingHR", value: $0) }
            let stepsValues = weekEntries.compactMap { normalizeMissing($0.steps) }.filter { !isOutlier("steps", value: $0) }
            let caloriesValues = weekEntries.compactMap { normalizeMissing($0.activeCalories) }.filter { !isOutlier("activeCalories", value: $0) }
            let loadValues = weekEntries.compactMap { normalizeMissing($0.trainingLoad) }.filter { !isOutlier("trainingLoad", value: $0) }
            let readinessValues = weekEntries.compactMap { normalizeMissing($0.readinessScore) }.filter { !isOutlier("readinessScore", value: $0) }
            let vo2Values = weekEntries.compactMap { normalizeMissing($0.vo2max) }.filter { !isOutlier("vo2max", value: $0) }
            let workoutCount = weekEntries.compactMap { $0.workoutCount }.reduce(0, +)

            // Count valid days (has at least one meaningful metric)
            let validDays = weekEntries.filter { entry in
                normalizeMissing(entry.sleepHours) != nil ||
                normalizeMissing(entry.hrvMs) != nil ||
                normalizeMissing(entry.steps) != nil ||
                normalizeMissing(entry.activeCalories) != nil
            }.count

            weeks.append(GeminiWeekPayload(
                weekNumber: weekIndex + 1,
                startDate: dateFormatter.string(from: weekStart),
                endDate: dateFormatter.string(from: weekEnd),
                avgSleepHours: sleepValues.isEmpty ? nil : sleepValues.reduce(0, +) / Double(sleepValues.count),
                avgDeepSleepHours: deepValues.isEmpty ? nil : deepValues.reduce(0, +) / Double(deepValues.count),
                avgRemSleepHours: remValues.isEmpty ? nil : remValues.reduce(0, +) / Double(remValues.count),
                avgHrvMs: hrvValues.isEmpty ? nil : hrvValues.reduce(0, +) / Double(hrvValues.count),
                avgRestingHR: rhrValues.isEmpty ? nil : rhrValues.reduce(0, +) / Double(rhrValues.count),
                avgSteps: stepsValues.isEmpty ? nil : stepsValues.reduce(0, +) / Double(stepsValues.count),
                totalActiveCalories: caloriesValues.isEmpty ? nil : caloriesValues.reduce(0, +),
                avgTrainingLoad: loadValues.isEmpty ? nil : loadValues.reduce(0, +) / Double(loadValues.count),
                avgReadinessScore: readinessValues.isEmpty ? nil : readinessValues.reduce(0, +) / Double(readinessValues.count),
                avgVO2max: vo2Values.isEmpty ? nil : vo2Values.reduce(0, +) / Double(vo2Values.count),
                workoutCount: workoutCount > 0 ? workoutCount : nil,
                validDaysCount: validDays
            ))
        }

        return weeks
    }

    // MARK: - Calculate Coverage

    private func calculateCoverage(from sorted: [RawDailyHealthEntry]) -> [String: Int] {
        var coverage: [String: Int] = [
            "sleepHours": 0,
            "hrvMs": 0,
            "restingHR": 0,
            "vo2max": 0,
            "steps": 0,
            "activeCalories": 0,
            "trainingLoad": 0,
            "readinessScore": 0,
            "weightKg": 0,
            "bodyFatPercent": 0
        ]

        for entry in sorted {
            if let v = normalizeMissing(entry.sleepHours), !isOutlier("sleepHours", value: v) {
                coverage["sleepHours", default: 0] += 1
            }
            if let v = normalizeMissing(entry.hrvMs), !isOutlier("hrvMs", value: v) {
                coverage["hrvMs", default: 0] += 1
            }
            if let v = normalizeMissing(entry.restingHR), !isOutlier("restingHR", value: v) {
                coverage["restingHR", default: 0] += 1
            }
            if let v = normalizeMissing(entry.vo2max), !isOutlier("vo2max", value: v) {
                coverage["vo2max", default: 0] += 1
            }
            if let v = normalizeMissing(entry.steps), !isOutlier("steps", value: v) {
                coverage["steps", default: 0] += 1
            }
            if let v = normalizeMissing(entry.activeCalories), !isOutlier("activeCalories", value: v) {
                coverage["activeCalories", default: 0] += 1
            }
            if let v = normalizeMissing(entry.trainingLoad), !isOutlier("trainingLoad", value: v) {
                coverage["trainingLoad", default: 0] += 1
            }
            if let v = normalizeMissing(entry.readinessScore), !isOutlier("readinessScore", value: v) {
                coverage["readinessScore", default: 0] += 1
            }
            if let v = normalizeMissing(entry.weightKg), !isOutlier("weightKg", value: v) {
                coverage["weightKg", default: 0] += 1
            }
            if let v = normalizeMissing(entry.bodyFatPercent), !isOutlier("bodyFatPercent", value: v) {
                coverage["bodyFatPercent", default: 0] += 1
            }
        }

        return coverage
    }

    // MARK: - Determine Quality Status

    private func determineQualityStatus(coverage: [String: Int], totalDays: Int) -> [String: String] {
        var status: [String: String] = [:]

        for (metric, count) in coverage {
            if count < 5 {
                status[metric] = "INSUFFICIENT_DATA"
            } else if count < 14 {
                status[metric] = "LIMITED_DATA"
            } else if count < 30 {
                status[metric] = "GOOD_DATA"
            } else {
                status[metric] = "HIGH_CONFIDENCE_DATA"
            }
        }

        return status
    }

    // MARK: - Generate Flags

    private func generateFlags(from sorted: [RawDailyHealthEntry], coverage: [String: Int]) -> [String] {
        var flags: [String] = []

        // Check for data gaps (more than 5 consecutive days without data)
        var consecutiveMissing = 0
        for entry in sorted {
            let hasData = normalizeMissing(entry.sleepHours) != nil ||
                          normalizeMissing(entry.hrvMs) != nil ||
                          normalizeMissing(entry.steps) != nil
            if hasData {
                consecutiveMissing = 0
            } else {
                consecutiveMissing += 1
                if consecutiveMissing == 5 {
                    flags.append("DATA_GAP_WARNING: More than 5 consecutive days without data")
                }
            }
        }

        // Check for insufficient data metrics
        for (metric, count) in coverage {
            if count < 5 {
                flags.append("INSUFFICIENT_DATA: \(metric) (\(count)/90 days)")
            }
        }

        // Check for potential sensor errors (large daily jumps)
        for i in 1..<sorted.count {
            let prev = sorted[i-1]
            let curr = sorted[i]

            // HRV jump > 40%
            if let prevHRV = normalizeMissing(prev.hrvMs),
               let currHRV = normalizeMissing(curr.hrvMs),
               prevHRV > 0 {
                let change = abs(currHRV - prevHRV) / prevHRV
                if change > 0.4 {
                    let dateStr = dateFormatter.string(from: curr.date)
                    flags.append("POTENTIAL_SENSOR_ERROR: HRV change of \(Int(change * 100))% on \(dateStr)")
                }
            }

            // RHR jump > 30%
            if let prevRHR = normalizeMissing(prev.restingHR),
               let currRHR = normalizeMissing(curr.restingHR),
               prevRHR > 0 {
                let change = abs(currRHR - prevRHR) / prevRHR
                if change > 0.3 {
                    let dateStr = dateFormatter.string(from: curr.date)
                    flags.append("POTENTIAL_SENSOR_ERROR: RHR change of \(Int(change * 100))% on \(dateStr)")
                }
            }
        }

        return flags
    }

    // MARK: - Calculate Reliability Score

    private func calculateReliabilityScore(coverage: [String: Int], totalDays: Int) -> Int {
        guard totalDays > 0 else { return 0 }

        // Weight key metrics
        let weights: [String: Double] = [
            "sleepHours": 0.25,
            "hrvMs": 0.20,
            "restingHR": 0.15,
            "steps": 0.15,
            "activeCalories": 0.10,
            "vo2max": 0.05,
            "weightKg": 0.05,
            "bodyFatPercent": 0.05
        ]

        var weightedSum = 0.0
        var totalWeight = 0.0

        for (metric, weight) in weights {
            let count = coverage[metric] ?? 0
            let percentage = Double(count) / Double(totalDays)
            weightedSum += percentage * weight
            totalWeight += weight
        }

        let score = (weightedSum / totalWeight) * 100
        return Int(min(100, max(0, score)))
    }
}
