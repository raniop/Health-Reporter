//
//  BedtimePayloadBuilder.swift
//  Health Reporter
//
//  Gathers last 48h of HealthKit data + 21-day baselines and formats into
//  the JSON payload expected by the Gemini bedtime recommendation prompt.
//

import Foundation

// MARK: - Payload Models

struct BedtimeUserProfile: Codable {
    let timezone: String
    let preferredWakeTime: String?
    let typicalSleepNeedHours: Double?
    let age: Int?
    let sex: String?
    let trainingGoal: String?
}

struct BedtimeBaselines21d: Codable {
    let hrvBaselineMs: Double?
    let hrvIqrMs: Double?
    let rhrBaselineBpm: Double?
    let rhrIqrBpm: Double?
    let sleepBaselineHours: Double?
    let sleepIqrHours: Double?
    let bedtimeBaseline: String?
    let wakeTimeBaseline: String?
}

struct BedtimeDayEntry: Codable {
    let date: String
    let sleepHours: Double?
    let deepSleepHours: Double?
    let remSleepHours: Double?
    let restingHR: Double?
    let hrvMs: Double?
    let steps: Int?
    let activeCalories: Double?
    let workouts: [BedtimeWorkout]?
    let naps: [BedtimeNap]?
}

struct BedtimeWorkout: Codable {
    let startTime: String
    let endTime: String
    let type: String
    let intensityHint: String?
    let activeCalories: Double?
}

struct BedtimeNap: Codable {
    let startTime: String
    let durationMin: Int
}

struct BedtimeUpcoming: Codable {
    let wakeTimeTomorrow: String?
    let earlyCommitment: String?
}

struct BedtimePayload: Codable {
    let userProfile: BedtimeUserProfile
    let baselines21d: BedtimeBaselines21d
    let last48h: [BedtimeDayEntry]
    let upcoming: BedtimeUpcoming

    func toJSONString() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Builder

final class BedtimePayloadBuilder {

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "HH:mm"
        return f
    }()

    // MARK: - Reasonable Ranges (same as GeminiHealthPayloadBuilder)

    private let ranges: [String: ClosedRange<Double>] = [
        "sleepHours": 2.0...14.0,
        "deepSleepHours": 0.5...5.0,
        "remSleepHours": 0.5...4.0,
        "hrvMs": 15.0...150.0,
        "restingHR": 35.0...100.0,
        "steps": 500.0...80000.0,
        "activeCalories": 50.0...5000.0,
    ]

    // MARK: - Helpers

    private func normalizeMissing(_ value: Double?) -> Double? {
        guard let v = value else { return nil }
        if v == 0 || v.isNaN || v.isInfinite { return nil }
        return v
    }

    private func isOutlier(_ metric: String, value: Double) -> Bool {
        guard let range = ranges[metric] else { return false }
        return !range.contains(value)
    }

    private func validValues(_ entries: [RawDailyHealthEntry], keyPath: KeyPath<RawDailyHealthEntry, Double?>, metric: String) -> [Double] {
        return entries.compactMap { normalizeMissing($0[keyPath: keyPath]) }
            .filter { !isOutlier(metric, value: $0) }
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Inter-quartile range
    private func iqr(_ values: [Double]) -> Double? {
        guard values.count >= 4 else { return nil }
        let sorted = values.sorted()
        let q1Index = sorted.count / 4
        let q3Index = (sorted.count * 3) / 4
        return sorted[q3Index] - sorted[q1Index]
    }

    // MARK: - Build

    func build(from rawDays: [RawDailyHealthEntry]) -> BedtimePayload {
        let sorted = rawDays.sorted { $0.date < $1.date }
        let calendar = Calendar.current

        // --- Last 48h (yesterday + day before yesterday) ---
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let dayBefore = calendar.date(byAdding: .day, value: -2, to: today)!

        let last48hEntries = sorted.filter { entry in
            let entryDay = calendar.startOfDay(for: entry.date)
            return entryDay == yesterday || entryDay == dayBefore
        }

        let last48h = last48hEntries.map { entry -> BedtimeDayEntry in
            BedtimeDayEntry(
                date: dateFormatter.string(from: entry.date),
                sleepHours: normalizeMissing(entry.sleepHours),
                deepSleepHours: normalizeMissing(entry.deepSleepHours),
                remSleepHours: normalizeMissing(entry.remSleepHours),
                restingHR: normalizeMissing(entry.restingHR),
                hrvMs: normalizeMissing(entry.hrvMs),
                steps: normalizeMissing(entry.steps).map { Int($0) },
                activeCalories: normalizeMissing(entry.activeCalories),
                workouts: nil,  // HealthKit workout details not in RawDailyHealthEntry
                naps: nil
            )
        }

        // --- 21-day baselines ---
        let last21Days = Array(sorted.suffix(21))

        let sleepValues = validValues(last21Days, keyPath: \.sleepHours, metric: "sleepHours")
        let hrvValues = validValues(last21Days, keyPath: \.hrvMs, metric: "hrvMs")
        let rhrValues = validValues(last21Days, keyPath: \.restingHR, metric: "restingHR")

        let baselines = BedtimeBaselines21d(
            hrvBaselineMs: average(hrvValues),
            hrvIqrMs: iqr(hrvValues),
            rhrBaselineBpm: average(rhrValues),
            rhrIqrBpm: iqr(rhrValues),
            sleepBaselineHours: average(sleepValues),
            sleepIqrHours: iqr(sleepValues),
            bedtimeBaseline: nil,
            wakeTimeBaseline: buildWakeTimeBaseline()
        )

        // --- User profile ---
        let wakeTime = buildPreferredWakeTime()
        let sleepGoal = BedtimeNotificationManager.shared.sleepGoalHours
        print("🌙 [BedtimePayload] sleepGoal=\(sleepGoal)h, wakeTime=\(wakeTime ?? "nil"), sleepBaseline=\(average(sleepValues) ?? 0)h")
        let userProfile = BedtimeUserProfile(
            timezone: TimeZone.current.identifier,
            preferredWakeTime: wakeTime,
            typicalSleepNeedHours: BedtimeNotificationManager.shared.sleepGoalHours,
            age: nil,
            sex: nil,
            trainingGoal: nil
        )

        // --- Upcoming ---
        let upcoming = BedtimeUpcoming(
            wakeTimeTomorrow: wakeTime,
            earlyCommitment: nil
        )

        return BedtimePayload(
            userProfile: userProfile,
            baselines21d: baselines,
            last48h: last48h,
            upcoming: upcoming
        )
    }

    // MARK: - Wake Time from Morning Notification

    private func buildPreferredWakeTime() -> String? {
        let manager = MorningNotificationManager.shared
        guard manager.isEnabled else { return "07:00" }
        return String(format: "%02d:%02d", manager.notificationHour, manager.notificationMinute)
    }

    private func buildWakeTimeBaseline() -> String? {
        return buildPreferredWakeTime()
    }
}
