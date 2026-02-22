//
//  BedtimeCalculator.swift
//  Health Reporter
//
//  Pure Swift implementation of bedtime recommendation algorithm.
//  Replaces the Gemini-based calculation with deterministic logic.
//

import Foundation

// MARK: - Result Model

struct BedtimeCalculationResult {
    let recommendedBedtime: Date
    let recommendedBedtimeLocal: String   // "HH:mm"
    let wakeTimeTargetLocal: String       // "HH:mm"
    let sleepNeedTonightMinutes: Int
    let components: Components
    let drivers: [Driver]
    let assumptions: [String]

    struct Components {
        let baseSleepNeedMinutes: Int
        let sleepDebtMinutes: Int
        let recoveryPenaltyMinutes: Int
        let loadAdjustmentMinutes: Int
        let latencyMinutes: Int
    }

    struct Driver {
        let key: String
        let value: String
        let impactMinutes: Int
    }
}

// MARK: - Calculator

final class BedtimeCalculator {

    private let calendar = Calendar.current

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()

    // MARK: - Main Entry Point

    func calculate(
        entries: [RawDailyHealthEntry],
        sleepGoalHours: Double
    ) -> BedtimeCalculationResult {
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let dayBefore = calendar.date(byAdding: .day, value: -2, to: today)!

        let sorted = entries.sorted { $0.date < $1.date }
        let last21 = Array(sorted.suffix(21))

        let yesterdayEntry = sorted.first { calendar.isDate($0.date, inSameDayAs: yesterday) }
        let dayBeforeEntry = sorted.first { calendar.isDate($0.date, inSameDayAs: dayBefore) }

        var assumptions: [String] = []
        var drivers: [BedtimeCalculationResult.Driver] = []

        // --- A) Wake Time Target ---
        let wakeTimeTarget = resolveWakeTimeTarget(entries: last21, assumptions: &assumptions)

        // --- B) Base Sleep Need ---
        let baseSleepNeedMinutes = resolveBaseSleepNeed(
            sleepGoalHours: sleepGoalHours,
            baselineEntries: last21,
            assumptions: &assumptions
        )

        // --- C) Sleep Debt (last 48h) ---
        let sleepDebtMinutes = calculateSleepDebt(
            baseSleepNeedMinutes: baseSleepNeedMinutes,
            yesterday: yesterdayEntry,
            dayBefore: dayBeforeEntry,
            drivers: &drivers
        )

        // --- D) Recovery Penalty ---
        let recoveryPenaltyMinutes = calculateRecoveryPenalty(
            yesterday: yesterdayEntry,
            dayBefore: dayBeforeEntry,
            baselineEntries: last21,
            drivers: &drivers,
            assumptions: &assumptions
        )

        // --- E) Training Load Adjustment ---
        let loadAdjustmentMinutes = calculateLoadAdjustment(
            yesterday: yesterdayEntry,
            dayBefore: dayBeforeEntry,
            drivers: &drivers
        )

        // --- F) Latency ---
        let latencyMinutes = 20

        // --- G) Compute Final Bedtime ---
        let sleepNeedTonightMinutes = baseSleepNeedMinutes + sleepDebtMinutes
            + recoveryPenaltyMinutes + loadAdjustmentMinutes

        let totalMinutesBeforeWake = sleepNeedTonightMinutes + latencyMinutes
        let rawBedtime = calendar.date(byAdding: .minute, value: -totalMinutesBeforeWake, to: wakeTimeTarget)!

        let bedtime = applyFloorCeiling(
            rawBedtime: rawBedtime,
            sleepDebtMinutes: sleepDebtMinutes,
            recoveryPenaltyMinutes: recoveryPenaltyMinutes,
            assumptions: &assumptions
        )

        print("🌙 [BedtimeCalc] wake=\(timeFormatter.string(from: wakeTimeTarget)) base=\(baseSleepNeedMinutes) debt=\(sleepDebtMinutes) recovery=\(recoveryPenaltyMinutes) load=\(loadAdjustmentMinutes) latency=\(latencyMinutes) → raw=\(timeFormatter.string(from: rawBedtime)) → final=\(timeFormatter.string(from: bedtime))")

        return BedtimeCalculationResult(
            recommendedBedtime: bedtime,
            recommendedBedtimeLocal: timeFormatter.string(from: bedtime),
            wakeTimeTargetLocal: timeFormatter.string(from: wakeTimeTarget),
            sleepNeedTonightMinutes: sleepNeedTonightMinutes,
            components: .init(
                baseSleepNeedMinutes: baseSleepNeedMinutes,
                sleepDebtMinutes: sleepDebtMinutes,
                recoveryPenaltyMinutes: recoveryPenaltyMinutes,
                loadAdjustmentMinutes: loadAdjustmentMinutes,
                latencyMinutes: latencyMinutes
            ),
            drivers: drivers,
            assumptions: assumptions
        )
    }

    // MARK: - A) Wake Time Target

    private func resolveWakeTimeTarget(
        entries: [RawDailyHealthEntry],
        assumptions: inout [String]
    ) -> Date {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!

        // Use real wake times from HealthKit (filter to reasonable range 04:00-14:00)
        let wakeTimes = entries.compactMap { $0.wakeTime }
        let reasonableWakeTimes = wakeTimes.filter { wt in
            let hour = calendar.component(.hour, from: wt)
            return hour >= 4 && hour <= 14
        }

        if reasonableWakeTimes.count >= 3 {
            let avgMinutes = reasonableWakeTimes.map { wt -> Double in
                let comps = calendar.dateComponents([.hour, .minute], from: wt)
                return Double(comps.hour ?? 7) * 60.0 + Double(comps.minute ?? 0)
            }.reduce(0, +) / Double(reasonableWakeTimes.count)

            let hour = Int(avgMinutes / 60)
            let minute = Int(avgMinutes.truncatingRemainder(dividingBy: 60))
            print("🌙 [BedtimeCalc] Wake time: 21-day avg = \(hour):\(String(format: "%02d", minute)) (from \(reasonableWakeTimes.count) samples)")
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: tomorrow)!
        }

        // Fallback: morning notification time
        let manager = MorningNotificationManager.shared
        if manager.isEnabled {
            assumptions.append("Used morning notification time as wake target (insufficient sleep data)")
            print("🌙 [BedtimeCalc] Wake time: fallback to morning notification \(manager.notificationHour):\(String(format: "%02d", manager.notificationMinute))")
            return calendar.date(bySettingHour: manager.notificationHour, minute: manager.notificationMinute, second: 0, of: tomorrow)!
        }

        // Final fallback: 07:00
        assumptions.append("Used default 07:00 wake time (no data available)")
        print("🌙 [BedtimeCalc] Wake time: fallback to default 07:00")
        return calendar.date(bySettingHour: 7, minute: 0, second: 0, of: tomorrow)!
    }

    // MARK: - B) Base Sleep Need

    private func resolveBaseSleepNeed(
        sleepGoalHours: Double,
        baselineEntries: [RawDailyHealthEntry],
        assumptions: inout [String]
    ) -> Int {
        if sleepGoalHours > 0 {
            return Int(sleepGoalHours * 60)
        }

        let sleepValues = baselineEntries.compactMap { $0.sleepHours }.filter { $0 > 2 && $0 < 14 }
        if !sleepValues.isEmpty {
            assumptions.append("Used 21-day sleep average as base need")
            return Int((sleepValues.reduce(0, +) / Double(sleepValues.count)) * 60)
        }

        assumptions.append("Used default 450 min base sleep need")
        return 450
    }

    // MARK: - C) Sleep Debt

    private func calculateSleepDebt(
        baseSleepNeedMinutes: Int,
        yesterday: RawDailyHealthEntry?,
        dayBefore: RawDailyHealthEntry?,
        drivers: inout [BedtimeCalculationResult.Driver]
    ) -> Int {
        let baseNeed = Double(baseSleepNeedMinutes)
        let yesterdaySleepMin = (yesterday?.sleepHours ?? 0) * 60
        let dayBeforeSleepMin = (dayBefore?.sleepHours ?? 0) * 60

        let debt = max(0, baseNeed - yesterdaySleepMin) + max(0, baseNeed - dayBeforeSleepMin)
        let clamped = min(max(Int(debt), 0), 90)

        if clamped > 0 {
            let yesterdayH = String(format: "%.1f", yesterday?.sleepHours ?? 0)
            let dayBeforeH = String(format: "%.1f", dayBefore?.sleepHours ?? 0)
            drivers.append(.init(
                key: "sleep_debt",
                value: "Sleep debt: \(clamped) min (slept \(yesterdayH)h + \(dayBeforeH)h vs \(String(format: "%.1f", baseNeed / 60))h need)",
                impactMinutes: clamped
            ))
        }
        return clamped
    }

    // MARK: - D) Recovery Penalty

    private func calculateRecoveryPenalty(
        yesterday: RawDailyHealthEntry?,
        dayBefore: RawDailyHealthEntry?,
        baselineEntries: [RawDailyHealthEntry],
        drivers: inout [BedtimeCalculationResult.Driver],
        assumptions: inout [String]
    ) -> Int {
        var penalty = 0

        // HRV check
        let hrvValues = baselineEntries.compactMap { $0.hrvMs }.filter { $0 > 15 && $0 < 150 }
        let hrvBaseline = hrvValues.isEmpty ? nil : hrvValues.reduce(0, +) / Double(hrvValues.count)

        if let hrvBaseline = hrvBaseline, let hrvYesterday = yesterday?.hrvMs, hrvBaseline > 0 {
            let hrvDeltaPct = (hrvYesterday - hrvBaseline) / hrvBaseline
            if hrvDeltaPct <= -0.15 {
                penalty += 30
                drivers.append(.init(key: "hrv", value: "HRV dropped \(Int(hrvDeltaPct * 100))% vs baseline", impactMinutes: 30))
            } else if hrvDeltaPct <= -0.10 {
                penalty += 20
                drivers.append(.init(key: "hrv", value: "HRV dropped \(Int(hrvDeltaPct * 100))% vs baseline", impactMinutes: 20))
            }
        } else {
            assumptions.append("HRV data unavailable, skipped HRV recovery check")
        }

        // RHR check
        let rhrValues = baselineEntries.compactMap { $0.restingHR }.filter { $0 > 35 && $0 < 100 }
        let rhrBaseline = rhrValues.isEmpty ? nil : rhrValues.reduce(0, +) / Double(rhrValues.count)

        if let rhrBaseline = rhrBaseline, let rhrYesterday = yesterday?.restingHR {
            let rhrDelta = rhrYesterday - rhrBaseline
            if rhrDelta >= 5 {
                penalty += 25
                drivers.append(.init(key: "rhr", value: "RHR rose +\(Int(rhrDelta)) bpm vs baseline", impactMinutes: 25))
            } else if rhrDelta >= 3 {
                penalty += 15
                drivers.append(.init(key: "rhr", value: "RHR rose +\(Int(rhrDelta)) bpm vs baseline", impactMinutes: 15))
            }
        } else {
            assumptions.append("RHR data unavailable, skipped RHR recovery check")
        }

        // Deep sleep drop
        if let deepYesterday = yesterday?.deepSleepHours, let deepDayBefore = dayBefore?.deepSleepHours,
           deepDayBefore > 0, deepYesterday < deepDayBefore * 0.6 {
            penalty += 15
            drivers.append(.init(key: "deep_sleep", value: "Deep sleep dropped significantly", impactMinutes: 15))
        }

        // Short sleep
        if let sleepYesterday = yesterday?.sleepHours, sleepYesterday < 6.0 {
            penalty += 20
            drivers.append(.init(key: "short_sleep", value: "Slept only \(String(format: "%.1f", sleepYesterday))h yesterday", impactMinutes: 20))
        }

        return min(max(penalty, 0), 90)
    }

    // MARK: - E) Training Load Adjustment

    private func calculateLoadAdjustment(
        yesterday: RawDailyHealthEntry?,
        dayBefore: RawDailyHealthEntry?,
        drivers: inout [BedtimeCalculationResult.Driver]
    ) -> Int {
        let cal48h = (yesterday?.activeCalories ?? 0) + (dayBefore?.activeCalories ?? 0)

        if cal48h > 3000 {
            drivers.append(.init(key: "training_load", value: "Very high activity (\(Int(cal48h)) cal/48h)", impactMinutes: 20))
            return 20
        } else if cal48h > 2000 {
            drivers.append(.init(key: "training_load", value: "High activity (\(Int(cal48h)) cal/48h)", impactMinutes: 10))
            return 10
        }
        return 0
    }

    // MARK: - G) Floor / Ceiling

    private func applyFloorCeiling(
        rawBedtime: Date,
        sleepDebtMinutes: Int,
        recoveryPenaltyMinutes: Int,
        assumptions: inout [String]
    ) -> Date {
        let today = calendar.startOfDay(for: Date())
        let floor = calendar.date(bySettingHour: 20, minute: 30, second: 0, of: today)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let ceiling = calendar.date(bySettingHour: 1, minute: 0, second: 0, of: tomorrow)!

        if rawBedtime < floor {
            let canBreakFloor = sleepDebtMinutes >= 60 && recoveryPenaltyMinutes >= 40
            if canBreakFloor {
                assumptions.append("Bedtime before 20:30 allowed due to high sleep debt + recovery penalty")
                return rawBedtime
            }
            assumptions.append("Bedtime capped at 20:30 floor (calculated \(timeFormatter.string(from: rawBedtime)))")
            return floor
        }

        if rawBedtime > ceiling {
            assumptions.append("Bedtime capped at 01:00 ceiling")
            return ceiling
        }

        return rawBedtime
    }
}
