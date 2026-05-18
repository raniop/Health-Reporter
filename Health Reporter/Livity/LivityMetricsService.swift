//
//  LivityMetricsService.swift
//  Health Reporter
//
//  Fetches the daily metric bundle for a given date, directly from HealthKit.
//  Uses simplified scoring algorithms; we can swap these for richer models later.
//

import Foundation
import HealthKit

final class LivityMetricsService {
    static let shared = LivityMetricsService()
    private let store = HKHealthStore()
    private init() {}

    /// How many days of history we pull for trends, percentile baselines, and
    /// year-over-year comparisons. 365 days = a full annual cycle, deep enough
    /// to give every percentile/average a meaningful denominator without
    /// pulling unbounded data on devices with years of HealthKit history.
    private static let historyDays = 365

    /// In-memory cache of the most recent successful `fetchDaily` per calendar
    /// day. Lets the splash screen pre-warm today's metrics so the Overview tab
    /// renders real numbers the instant it appears, instead of "—" while a
    /// fresh query runs.
    private var cache: [Date: LivityDailyMetrics] = [:]
    private let cacheQueue = DispatchQueue(label: "livity.metrics.cache")

    func cachedMetrics(for date: Date) -> LivityDailyMetrics? {
        let key = Calendar.current.startOfDay(for: date)
        return cacheQueue.sync { cache[key] }
    }

    private func setCache(_ metrics: LivityDailyMetrics, for date: Date) {
        let key = Calendar.current.startOfDay(for: date)
        cacheQueue.sync { cache[key] = metrics }
    }

    /// Ensure we have asked for read access to Time in Daylight. iOS deduplicates the prompt;
    /// this just guarantees the new HealthKit type surfaces its permission sheet even if the
    /// upfront auth call was made before the type was added to the read set.
    func ensureDaylightAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        if #available(iOS 17.0, *) {
            guard let type = HKQuantityType.quantityType(forIdentifier: .timeInDaylight) else { return }
            store.requestAuthorization(toShare: nil, read: [type]) { _, _ in }
        }
    }

    // Entry point used by the Overview screen.
    func fetchDaily(for date: Date, completion: @escaping (LivityDailyMetrics) -> Void) {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? date

        let group = DispatchGroup()
        var result = LivityDailyMetrics.empty
        result.date = dayStart

        // Steps
        group.enter()
        sumQuantity(.stepCount, unit: .count(), from: dayStart, to: dayEnd) { value in
            if let value { result.steps = Int(value) }
            group.leave()
        }

        // Active energy
        group.enter()
        sumQuantity(.activeEnergyBurned, unit: .kilocalorie(), from: dayStart, to: dayEnd) { value in
            result.activeEnergyKcal = value
            group.leave()
        }

        // Basal energy
        var basal: Double?
        group.enter()
        sumQuantity(.basalEnergyBurned, unit: .kilocalorie(), from: dayStart, to: dayEnd) { value in
            basal = value
            group.leave()
        }

        // Resting HR (most recent for day) — keep the real sample timestamp so
        // the Recovery snapshot's "Last measured" line reflects an actual
        // measurement, not the moment of view-load.
        group.enter()
        mostRecentQuantityWithDate(.restingHeartRate, unit: HKUnit(from: "count/min"), from: dayStart, to: dayEnd) { value, date in
            result.restingHR = value
            result.restingHRSampleDate = date
            group.leave()
        }

        // HRV (most recent for day)
        group.enter()
        mostRecentQuantityWithDate(.heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli), from: dayStart, to: dayEnd) { value, date in
            result.hrv = value
            result.hrvSampleDate = date
            group.leave()
        }

        // Respiratory rate (most recent)
        group.enter()
        mostRecentQuantityWithDate(.respiratoryRate, unit: HKUnit(from: "count/min"), from: dayStart, to: dayEnd) { value, date in
            result.respiratoryRate = value
            result.respiratoryRateSampleDate = date
            group.leave()
        }

        // Blood oxygen (most recent, as percent 0-100)
        group.enter()
        mostRecentQuantityWithDate(.oxygenSaturation, unit: .percent(), from: dayStart, to: dayEnd) { value, date in
            if let v = value { result.spo2 = v * 100 }
            result.spo2SampleDate = date
            group.leave()
        }

        // Wrist temperature — sleeping wrist temp (available iOS 17+) in Fahrenheit.
        if #available(iOS 17.0, *) {
            group.enter()
            mostRecentQuantityWithDate(.appleSleepingWristTemperature, unit: .degreeFahrenheit(), from: dayStart, to: dayEnd) { value, date in
                result.wristTempFahrenheit = value
                result.wristTempSampleDate = date
                group.leave()
            }
        }

        // Time in daylight (today)
        if #available(iOS 17.0, *) {
            group.enter()
            sumQuantity(.timeInDaylight, unit: .second(), from: dayStart, to: dayEnd) { value in
                if let value {
                    result.daylightMinutes = Int(value / 60)
                }
                group.leave()
            }

            // 30-day history for the mini trend chart.
            group.enter()
            fetchDaylightHistory(endingOn: dayStart, days: Self.historyDays) { history in
                result.daylightHistory = history
                group.leave()
            }
        }

        // Sleep stages (for the session that ended on or near `date`)
        group.enter()
        fetchSleepStages(targetDay: dayStart) { stages in
            result.sleepDeepMinutes = stages.deep
            result.sleepCoreMinutes = stages.core
            result.sleepREMMinutes = stages.rem
            result.sleepAwakeMinutes = stages.awake
            result.sleepTotalMinutes = stages.totalAsleep
            group.leave()
        }

        // 30-day sleep stage history (for Monthly Trends on the Sleep detail).
        var sleepHistory: [SleepStageSummary] = []
        group.enter()
        fetchSleepHistory(endingOn: dayStart, days: Self.historyDays) { history in
            sleepHistory = history
            group.leave()
        }

        // Bedtime / wake-time history for the Sleep Inconsistencies card.
        group.enter()
        fetchBedtimeWakeHistory(endingOn: dayStart, days: 90) { history in
            result.bedtimeHistory = history.map { $0.0 }
            result.wakeTimeHistory = history.map { $0.1 }
            group.leave()
        }

        // Heart rate samples (for stress approximation + zone distribution).
        // We need timestamps for the intraday stress chart, so fetch with dates.
        var hrSamplesWithTimes: [(Date, Double)] = []
        group.enter()
        fetchHRSamplesWithTimes(from: dayStart, to: dayEnd) { samples in
            hrSamplesWithTimes = samples
            group.leave()
        }

        // Heart rate zone distribution (minutes in each zone).
        // Max HR comes from the user's setting (Profile → Heart Preferences) when
        // set to manual; otherwise we fall back to 220 − age. Threshold percentages
        // follow the standard 60/70/80/90 % MaxHR splits.
        let age = Self.fetchAgeYears(store: store) ?? 30
        let prefs = ProfileStore.shared
        let maxHR: Int = (prefs.hrMaxSource == .manual && prefs.hrMaxManual > 0)
            ? prefs.hrMaxManual
            : max(120, 220 - age)
        let zoneBounds: (Int, Int, Int, Int) = (
            Int(Double(maxHR) * 0.60),
            Int(Double(maxHR) * 0.70),
            Int(Double(maxHR) * 0.80),
            Int(Double(maxHR) * 0.90)
        )
        var hrZones: [Double] = [0, 0, 0, 0, 0]
        group.enter()
        fetchHRZoneDistribution(from: dayStart, to: dayEnd, bounds: zoneBounds) { minutes in
            hrZones = minutes
            group.leave()
        }

        // Workouts for the day
        group.enter()
        fetchWorkouts(from: dayStart, to: dayEnd) { workouts in
            result.workouts = workouts
            group.leave()
        }

        // User characteristics — required to personalise zones / formulas.
        // These are synchronous reads but kept in the group for ordering.
        result.ageYears = Self.fetchAgeYears(store: store)
        result.biologicalSex = Self.fetchBiologicalSex(store: store)
        group.enter()
        fetchMostRecentHeightCm { value in
            result.heightCm = value
            group.leave()
        }

        // Dietary energy (for Energy Balance)
        group.enter()
        sumQuantity(.dietaryEnergyConsumed, unit: .kilocalorie(), from: dayStart, to: dayEnd) { value in
            if let v = value, v > 0 {
                result.caloriesConsumed = v
                result.energyLogged = true
            }
            group.leave()
        }

        // Dietary macros
        group.enter()
        sumQuantity(.dietaryProtein, unit: .gram(), from: dayStart, to: dayEnd) { value in
            result.dietaryProtein = value
            group.leave()
        }
        group.enter()
        sumQuantity(.dietaryCarbohydrates, unit: .gram(), from: dayStart, to: dayEnd) { value in
            result.dietaryCarbs = value
            group.leave()
        }
        group.enter()
        sumQuantity(.dietaryFatTotal, unit: .gram(), from: dayStart, to: dayEnd) { value in
            result.dietaryFat = value
            group.leave()
        }

        // Body mass (most recent ever — weight doesn't reset per day)
        group.enter()
        fetchMostRecentBodyMassKg { value in
            result.bodyMassKg = value
            group.leave()
        }

        // Macro + calorie history for the Energy Balance trend chart.
        // We capture the raw arrays here and patch the last entry with today's live
        // value inside the `group.notify` block, where `result.*` is guaranteed set.
        var rawCaloriesHistory: [Double] = []
        var rawProteinHistory: [Double] = []
        group.enter()
        fetchDailySumHistory(.dietaryEnergyConsumed, unit: .kilocalorie(), endingOn: dayStart, days: Self.historyDays) { history in
            rawCaloriesHistory = history; group.leave()
        }
        group.enter()
        fetchDailySumHistory(.dietaryProtein, unit: .gram(), endingOn: dayStart, days: Self.historyDays) { history in
            rawProteinHistory = history; group.leave()
        }

        // Exercise time (today)
        group.enter()
        sumQuantity(.appleExerciseTime, unit: .minute(), from: dayStart, to: dayEnd) { value in
            result.exerciseMinutes = value
            group.leave()
        }

        // Floors climbed (today)
        group.enter()
        sumQuantity(.flightsClimbed, unit: .count(), from: dayStart, to: dayEnd) { value in
            result.floorsClimbed = value
            group.leave()
        }

        // 30-day history for "Monthly Trends" mini-charts.
        var activeHistory: [Double] = []
        var basalHistory: [Double] = []
        var stepsHistory: [Double] = []
        var exerciseHistory: [Double] = []
        var floorsHistory: [Double] = []

        group.enter()
        fetchDailySumHistory(.activeEnergyBurned, unit: .kilocalorie(), endingOn: dayStart, days: Self.historyDays) { history in
            activeHistory = history; group.leave()
        }
        group.enter()
        fetchDailySumHistory(.basalEnergyBurned, unit: .kilocalorie(), endingOn: dayStart, days: Self.historyDays) { history in
            basalHistory = history; group.leave()
        }
        group.enter()
        fetchDailySumHistory(.stepCount, unit: .count(), endingOn: dayStart, days: Self.historyDays) { history in
            stepsHistory = history; group.leave()
        }
        group.enter()
        fetchDailySumHistory(.appleExerciseTime, unit: .minute(), endingOn: dayStart, days: Self.historyDays) { history in
            exerciseHistory = history; group.leave()
        }
        group.enter()
        // Recovery monthly trends — daily averages, oldest→newest, today last.
        // These power the sparklines + "vs 30-day avg" rows on the Recovery
        // detail. Days without samples are stored as 0 and stripped out by the
        // UI before computing baselines.
        group.enter()
        fetchDailyAverageHistory(.heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli), endingOn: dayStart, days: Self.historyDays) { history in
            result.hrvHistory = history
            group.leave()
        }
        group.enter()
        fetchDailyAverageHistory(.restingHeartRate, unit: HKUnit(from: "count/min"), endingOn: dayStart, days: Self.historyDays) { history in
            result.restingHRHistory = history
            group.leave()
        }
        group.enter()
        fetchDailyAverageHistory(.respiratoryRate, unit: HKUnit(from: "count/min"), endingOn: dayStart, days: Self.historyDays) { history in
            result.respiratoryRateHistory = history
            group.leave()
        }
        group.enter()
        fetchDailyAverageHistory(.oxygenSaturation, unit: .percent(), endingOn: dayStart, days: Self.historyDays) { history in
            // SpO2 samples come back as 0.0–1.0 fractions; the UI shows percent.
            result.spo2History = history.map { $0 * 100 }
            group.leave()
        }
        if #available(iOS 17.0, *) {
            group.enter()
            fetchDailyAverageHistory(.appleSleepingWristTemperature, unit: .degreeFahrenheit(), endingOn: dayStart, days: Self.historyDays) { history in
                result.wristTempHistory = history
                group.leave()
            }
        }

        // ===== EXPANDED HEALTHKIT COVERAGE =====
        // Every read below comes straight from HealthKit — no synthesised
        // values. Each query feeds either a today-snapshot field or a
        // 30/365-day history series; the UI strips zero-fill days before
        // averaging so missing measurements don't bias the baseline.

        // VO2 max (Cardio Fitness) — most recent + 365-day history.
        group.enter()
        mostRecentQuantityWithDate(.vo2Max, unit: HKUnit(from: "ml/(kg*min)"), from: cal.date(byAdding: .day, value: -365, to: dayEnd) ?? dayStart, to: dayEnd) { value, date in
            result.vo2Max = value
            result.vo2MaxSampleDate = date
            group.leave()
        }
        group.enter()
        fetchDailyAverageHistory(.vo2Max, unit: HKUnit(from: "ml/(kg*min)"), endingOn: dayStart, days: Self.historyDays) { history in
            result.vo2MaxHistory = history
            group.leave()
        }

        // Mindful minutes — sum of mindfulSession category durations today.
        group.enter()
        fetchMindfulMinutesToday(from: dayStart, to: dayEnd) { minutes in
            result.mindfulMinutes = minutes
            group.leave()
        }
        group.enter()
        fetchMindfulMinutesHistory(endingOn: dayStart, days: Self.historyDays) { history in
            result.mindfulMinutesHistory = history
            group.leave()
        }

        // Atrial fibrillation burden (% of time, iOS 16+).
        if #available(iOS 16.0, *) {
            group.enter()
            mostRecentQuantity(.atrialFibrillationBurden, unit: .percent(), from: dayStart, to: dayEnd) { value in
                if let v = value { result.atrialFibBurdenPct = v * 100 }
                group.leave()
            }
            group.enter()
            fetchDailyAverageHistory(.atrialFibrillationBurden, unit: .percent(), endingOn: dayStart, days: Self.historyDays) { history in
                result.atrialFibBurdenHistory = history.map { $0 * 100 }
                group.leave()
            }
        }

        // Sleeping breathing disturbances (iOS 18+). Apple stores this as a
        // discrete quantity (notElevated = 0, elevated = 1) per night — not a
        // sum — so we use most-recent / discreteAverage. Treat any non-zero
        // value as "elevated" for the today snapshot.
        if #available(iOS 18.0, *) {
            group.enter()
            mostRecentQuantity(.appleSleepingBreathingDisturbances, unit: .count(), from: dayStart, to: dayEnd) { value in
                result.sleepBreathingDisturbances = value
                group.leave()
            }
            group.enter()
            fetchDailyAverageHistory(.appleSleepingBreathingDisturbances, unit: .count(), endingOn: dayStart, days: Self.historyDays) { history in
                result.sleepBreathingDisturbancesHistory = history
                group.leave()
            }
        }

        // Blood pressure — paired systolic + diastolic, most recent today.
        group.enter()
        mostRecentQuantityWithDate(.bloodPressureSystolic, unit: HKUnit.millimeterOfMercury(), from: dayStart, to: dayEnd) { value, date in
            result.bloodPressureSystolic = value
            result.bloodPressureSampleDate = date
            group.leave()
        }
        group.enter()
        mostRecentQuantity(.bloodPressureDiastolic, unit: HKUnit.millimeterOfMercury(), from: dayStart, to: dayEnd) { value in
            result.bloodPressureDiastolic = value
            group.leave()
        }
        group.enter()
        fetchDailyAverageHistory(.bloodPressureSystolic, unit: HKUnit.millimeterOfMercury(), endingOn: dayStart, days: Self.historyDays) { history in
            result.bloodPressureSystolicHistory = history
            group.leave()
        }
        group.enter()
        fetchDailyAverageHistory(.bloodPressureDiastolic, unit: HKUnit.millimeterOfMercury(), endingOn: dayStart, days: Self.historyDays) { history in
            result.bloodPressureDiastolicHistory = history
            group.leave()
        }

        // Blood glucose — most recent today (mg/dL).
        let mgPerDl = HKUnit.gramUnit(with: .milli).unitDivided(by: HKUnit.literUnit(with: .deci))
        group.enter()
        mostRecentQuantityWithDate(.bloodGlucose, unit: mgPerDl, from: dayStart, to: dayEnd) { value, date in
            result.bloodGlucose = value
            result.bloodGlucoseSampleDate = date
            group.leave()
        }
        group.enter()
        fetchDailyAverageHistory(.bloodGlucose, unit: mgPerDl, endingOn: dayStart, days: Self.historyDays) { history in
            result.bloodGlucoseHistory = history
            group.leave()
        }

        // Distances by activity (km, today).
        group.enter()
        sumQuantity(.distanceWalkingRunning, unit: HKUnit.meterUnit(with: .kilo), from: dayStart, to: dayEnd) { value in
            result.distanceWalkingRunningKm = value
            group.leave()
        }
        group.enter()
        sumQuantity(.distanceCycling, unit: HKUnit.meterUnit(with: .kilo), from: dayStart, to: dayEnd) { value in
            result.distanceCyclingKm = value
            group.leave()
        }
        group.enter()
        sumQuantity(.distanceSwimming, unit: HKUnit.meterUnit(with: .kilo), from: dayStart, to: dayEnd) { value in
            result.distanceSwimmingKm = value
            group.leave()
        }

        // Walking speed (m/s, today's average) + history.
        let mPerSec = HKUnit.meter().unitDivided(by: HKUnit.second())
        group.enter()
        mostRecentQuantity(.walkingSpeed, unit: mPerSec, from: dayStart, to: dayEnd) { value in
            result.walkingSpeed = value
            group.leave()
        }
        group.enter()
        fetchDailyAverageHistory(.walkingSpeed, unit: mPerSec, endingOn: dayStart, days: Self.historyDays) { history in
            result.walkingSpeedHistory = history
            group.leave()
        }

        // Walking steadiness (% — Apple Watch fall risk).
        group.enter()
        mostRecentQuantity(.appleWalkingSteadiness, unit: .percent(), from: dayStart, to: dayEnd) { value in
            if let v = value { result.walkingSteadiness = v * 100 }
            group.leave()
        }

        // Body composition — most-recent values within today, fallback to last
        // ever recorded (these don't reset daily).
        group.enter()
        fetchMostRecentEverQuantity(.bodyFatPercentage, unit: .percent()) { value in
            if let v = value { result.bodyFatPercent = v * 100 }
            group.leave()
        }
        group.enter()
        fetchMostRecentEverQuantity(.leanBodyMass, unit: .gramUnit(with: .kilo)) { value in
            result.leanBodyMassKg = value
            group.leave()
        }
        group.enter()
        fetchMostRecentEverQuantity(.bodyMassIndex, unit: HKUnit.count()) { value in
            result.bodyMassIndex = value
            group.leave()
        }
        group.enter()
        fetchMostRecentEverQuantity(.waistCircumference, unit: .meterUnit(with: .centi)) { value in
            result.waistCircumferenceCm = value
            group.leave()
        }

        // Audio exposure (today's average dB) — environmental + headphone.
        group.enter()
        mostRecentQuantity(.environmentalAudioExposure, unit: .decibelAWeightedSoundPressureLevel(), from: dayStart, to: dayEnd) { value in
            result.environmentalAudioDb = value
            group.leave()
        }
        group.enter()
        mostRecentQuantity(.headphoneAudioExposure, unit: .decibelAWeightedSoundPressureLevel(), from: dayStart, to: dayEnd) { value in
            result.headphoneAudioDb = value
            group.leave()
        }

        // Stand hours today (Apple Watch).
        group.enter()
        countStandHours(from: dayStart, to: dayEnd) { hours in
            result.standHoursToday = hours
            group.leave()
        }

        // Symptoms logged today — name + severity.
        group.enter()
        fetchSymptomsToday(from: dayStart, to: dayEnd) { symptoms in
            result.symptomsToday = symptoms
            group.leave()
        }

        // Mood / state of mind logs today (iOS 18+).
        if #available(iOS 18.0, *) {
            group.enter()
            fetchMoodToday(from: dayStart, to: dayEnd) { count, valence in
                result.moodLogCount = count
                result.moodValenceAvg = valence
                group.leave()
            }
        }

        fetchDailySumHistory(.flightsClimbed, unit: .count(), endingOn: dayStart, days: Self.historyDays) { history in
            floorsHistory = history; group.leave()
        }

        group.notify(queue: .main) {
            // Derived scoring (placeholder algorithms)
            let totalEnergy = (basal ?? 0) + (result.activeEnergyKcal ?? 0)
            result.totalEnergyKcal = totalEnergy > 0 ? totalEnergy : nil
            result.caloriesBurned = result.totalEnergyKcal

            // Strain: % of the user's *own* recent baseline rather than a fixed
            // 500 kcal / 10k step target. We average the 30-day non-zero active
            // burn and steps; if there is too little history we fall back to
            // Apple's Move-ring-style defaults so the metric is still meaningful.
            let activeBaseline = Self.average(activeHistory.dropLast()) ?? 500
            let stepsBaseline = Self.average(stepsHistory.dropLast()) ?? 10_000
            let activeFraction = min(1.5, (result.activeEnergyKcal ?? 0) / max(1, activeBaseline))
            let stepsFraction = min(1.5, Double(result.steps ?? 0) / max(1, stepsBaseline))
            let strain = min(100, (activeFraction * 0.5 + stepsFraction * 0.5) * 100)
            result.strainPercent = strain
            result.strainBucket = Self.strainBucket(for: strain)

            // Compose history arrays. All are 365 entries, oldest→newest, aligned by day.
            // The very-last bucket (today / the selected date) is OVERWRITTEN with the
            // live `result.*` value because HKStatisticsCollectionQuery sometimes lags
            // behind real-time samples for the current day — without this patch the
            // hero ring shows real numbers but the trend rows show 0.
            func patchToday(_ history: [Double], with liveValue: Double?) -> [Double] {
                guard !history.isEmpty, let live = liveValue else { return history }
                var arr = history
                arr[arr.count - 1] = live
                return arr
            }
            let patchedActive = patchToday(activeHistory, with: result.activeEnergyKcal)
            let patchedBasal = patchToday(basalHistory, with: basal)
            let patchedSteps = patchToday(stepsHistory, with: result.steps.map(Double.init))
            let patchedExercise = patchToday(exerciseHistory, with: result.exerciseMinutes)
            let patchedFloors = patchToday(floorsHistory, with: result.floorsClimbed)
            result.activeEnergyHistory = patchedActive
            result.stepsHistory = patchedSteps
            result.exerciseMinutesHistory = patchedExercise
            result.floorsClimbedHistory = patchedFloors
            let count = max(patchedActive.count, patchedBasal.count)
            if count > 0 {
                result.totalEnergyHistory = (0..<count).map { i in
                    let a = i < patchedActive.count ? patchedActive[i] : 0
                    let b = i < patchedBasal.count ? patchedBasal[i] : 0
                    return a + b
                }
                result.caloriesBurnedHistory = result.totalEnergyHistory
            }
            if patchedActive.count == patchedSteps.count, !patchedActive.isEmpty {
                let activeBaselineForHistory = Self.average(patchedActive.dropLast()) ?? 500
                let stepsBaselineForHistory = Self.average(patchedSteps.dropLast()) ?? 10_000
                result.strainHistory = zip(patchedActive, patchedSteps).map { active, stepsV in
                    let af = min(1.5, active / max(1, activeBaselineForHistory))
                    let sf = min(1.5, stepsV / max(1, stepsBaselineForHistory))
                    return min(100, (af * 0.5 + sf * 0.5) * 100)
                }
            }

            // Sleep score: minutes asleep vs the user's *own* configured sleep goal.
            let sleepGoal = (ProfileStore.shared.sleepGoalHours * 60)
            if let totalAsleep = result.sleepTotalMinutes, totalAsleep > 0, sleepGoal > 0 {
                let score = min(100, (totalAsleep / sleepGoal) * 100)
                result.sleepScore = score
                result.sleepBucket = Self.bucket(for: score)
            } else {
                result.sleepScore = nil
                result.sleepBucket = nil
            }

            // Patch nutrition histories with today's live values (same lag fix as above).
            result.caloriesConsumedHistory = patchToday(rawCaloriesHistory, with: result.caloriesConsumed)
            result.proteinHistory = patchToday(rawProteinHistory, with: result.dietaryProtein)

            // Sleep history arrays (30 days, oldest→newest).
            if !sleepHistory.isEmpty {
                result.sleepDeepHistory = sleepHistory.map { $0.deep }
                result.sleepCoreHistory = sleepHistory.map { $0.core }
                result.sleepREMHistory = sleepHistory.map { $0.rem }
                result.sleepAwakeHistory = sleepHistory.map { $0.awake }
                result.sleepTotalHistory = sleepHistory.map { $0.totalAsleep }
                let goalMinutes = (ProfileStore.shared.sleepGoalHours * 60)
                result.sleepScoreHistory = sleepHistory.map { stats in
                    stats.totalAsleep > 0 && goalMinutes > 0
                        ? min(100, (stats.totalAsleep / goalMinutes) * 100)
                        : 0
                }
            }

            // Recovery: HRV + RHR on a realistic scale.
            // HRV 20ms → 0pts, 100ms → 50pts.    RHR 75bpm → 0pts, 40bpm → 50pts.
            // Sum = 0-100. 100% requires both legitimately excellent (~100ms HRV, ~40 RHR).
            if let hrv = result.hrv, hrv > 0, let rhr = result.restingHR, rhr > 0 {
                let hrvComponent = max(0, min(1, (hrv - 20.0) / 80.0)) * 50
                let rhrComponent = max(0, min(1, (75.0 - rhr) / 35.0)) * 50
                let recovery = hrvComponent + rhrComponent
                result.recoveryScore = recovery
                result.recoveryBucket = Self.bucket(for: recovery)
            } else {
                // No reliable data — leave as nil so the UI can show "—" instead of a misleading number.
                result.recoveryScore = nil
                result.recoveryBucket = nil
            }

            // Heart zone distribution for the day
            result.heartZoneMinutes = hrZones
            result.heartZoneBounds = [zoneBounds.0, zoneBounds.1, zoneBounds.2, zoneBounds.3]

            // Stress: percent of the user's HR reserve (Karvonen formula).
            // Resting HR comes from the user's Heart Preferences when set to manual,
            // otherwise from HealthKit. Same for Max HR.
            let prefsForStress = ProfileStore.shared
            let resolvedRestingHR: Double? = (prefsForStress.restingHRSource == .manual && prefsForStress.restingHRManual > 0)
                ? Double(prefsForStress.restingHRManual)
                : result.restingHR
            let resolvedMaxHR: Double? = (prefsForStress.hrMaxSource == .manual && prefsForStress.hrMaxManual > 0)
                ? Double(prefsForStress.hrMaxManual)
                : result.ageYears.map { max(120, 220 - Double($0)) }
            if !hrSamplesWithTimes.isEmpty,
               let resting = resolvedRestingHR,
               let maxHR = resolvedMaxHR {
                let reserve = max(1, maxHR - resting)
                func intensity(_ hr: Double) -> Int {
                    Int(min(100, max(0, (hr - resting) / reserve * 100)).rounded())
                }
                let intradayValues = hrSamplesWithTimes.map { ($0.0, intensity($0.1)) }
                result.stressIntraday = intradayValues
                let bpms = hrSamplesWithTimes.map { $0.1 }
                let avg = bpms.reduce(0, +) / Double(bpms.count)
                let peak = bpms.max() ?? avg
                let low = bpms.min() ?? avg
                result.stressNow = intradayValues.last?.1 ?? intensity(avg)
                result.stressAverage = intensity(avg)
                result.stressPeak = intensity(peak)
                result.stressLow = intensity(low)
            } else {
                result.stressIntraday = []
                result.stressNow = nil
                result.stressAverage = nil
                result.stressPeak = nil
                result.stressLow = nil
            }

            // Body Battery: simple blend — recovery up, strain down, stress down
            let recoveryFactor = (result.recoveryScore ?? 50) / 100.0
            let strainFactor = (result.strainPercent ?? 0) / 100.0
            let stressFactor = Double(result.stressNow ?? 0) / 100.0
            let battery = 50 + recoveryFactor * 50 - strainFactor * 30 - stressFactor * 20
            result.bodyBattery = Int(max(5, min(100, battery)))

            // Phase detection (simple time-of-day heuristic)
            result.bodyBatteryPhase = Self.currentPhase(for: Date())

            // Daylight % vs the user's configured goal (default 60 min — Apple HK guideline).
            if let minutes = result.daylightMinutes {
                let goal: Double = 60
                result.daylightPercentVsGoal = (Double(minutes) - goal) / goal * 100
            }

            self.setCache(result, for: date)
            completion(result)
        }
    }

    // MARK: - Buckets

    /// Returns the average of the non-zero entries, or nil if none.
    private static func average(_ values: ArraySlice<Double>) -> Double? {
        let nonZero = values.filter { $0 > 0 }
        guard !nonZero.isEmpty else { return nil }
        return nonZero.reduce(0, +) / Double(nonZero.count)
    }

    private static func strainBucket(for value: Double) -> String {
        switch value {
        case ..<33: return "livity.bucket.bottom33".localized
        case ..<67: return "livity.bucket.middle33".localized
        default: return "livity.bucket.top33".localized
        }
    }

    private static func bucket(for value: Double) -> String {
        switch value {
        case ..<40: return "livity.bucket.bottom40".localized
        case ..<70: return "livity.bucket.middle40".localized
        default: return "livity.bucket.top40".localized
        }
    }

    /// Returns the standard chronobiology phase for the given hour. These are
    /// textbook ranges (rounded to whole hours) — same for everybody, since we
    /// don't yet have the intraday data needed to personalise them.
    private static func currentPhase(for date: Date) -> BodyBatteryPhase? {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<8:
            return BodyBatteryPhase(kind: .earlyMorning, name: "livity.phase.earlyMorning".localized, startTime: "05:00", endTime: "08:00", subtitle: "livity.phase.earlyMorning.subtitle".localized)
        case 8..<12:
            return BodyBatteryPhase(kind: .morningPeak, name: "livity.phase.morningPeak".localized, startTime: "08:00", endTime: "12:00", subtitle: "livity.phase.morningPeak.subtitle".localized)
        case 12..<14:
            return BodyBatteryPhase(kind: .midday, name: "livity.phase.midday".localized, startTime: "12:00", endTime: "14:00", subtitle: "livity.phase.midday.subtitle".localized)
        case 14..<17:
            return BodyBatteryPhase(kind: .afternoonDip, name: "livity.phase.afternoonDip".localized, startTime: "14:00", endTime: "16:00", subtitle: "livity.phase.afternoonDip.subtitle".localized)
        case 17..<21:
            return BodyBatteryPhase(kind: .evening, name: "livity.phase.evening".localized, startTime: "17:00", endTime: "21:00", subtitle: "livity.phase.evening.subtitle".localized)
        case 21..<24, 0..<2:
            return BodyBatteryPhase(kind: .earlyNight, name: "livity.phase.earlyNight".localized, startTime: "22:00", endTime: "03:00", subtitle: "livity.phase.earlyNight.subtitle".localized)
        default:
            return BodyBatteryPhase(kind: .circadianNadir, name: "livity.phase.circadianNadir".localized, startTime: "03:00", endTime: "05:00", subtitle: "livity.phase.circadianNadir.subtitle".localized)
        }
    }

    // MARK: - HealthKit helpers

    /// 30-day daily minutes of daylight, ordered oldest→newest, ending on (and including) `endingOn`.
    @available(iOS 17.0, *)
    private func fetchDaylightHistory(endingOn endDay: Date, days: Int, completion: @escaping ([Int]) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .timeInDaylight) else { completion([]); return }
        let cal = Calendar.current
        let end = cal.date(byAdding: .day, value: 1, to: endDay) ?? endDay
        guard let start = cal.date(byAdding: .day, value: -(days - 1), to: endDay) else { completion([]); return }
        let interval = DateComponents(day: 1)
        let query = HKStatisticsCollectionQuery(
            quantityType: type,
            quantitySamplePredicate: nil,
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: interval
        )
        query.initialResultsHandler = { _, collection, error in
            var minutes: [Int] = []
            collection?.enumerateStatistics(from: start, to: end) { stat, _ in
                let seconds = stat.sumQuantity()?.doubleValue(for: .second()) ?? 0
                minutes.append(Int(seconds / 60))
            }
            let nonZero = minutes.filter { $0 > 0 }.count
            print("[Livity] daylight history: \(minutes.count) days, \(nonZero) with data, err=\(error?.localizedDescription ?? "nil")")
            DispatchQueue.main.async { completion(minutes) }
        }
        store.execute(query)
    }

    /// All HKWorkout samples that started or ended within the day.
    private func fetchWorkouts(from: Date, to: Date, completion: @escaping ([LivityWorkout]) -> Void) {
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: [])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
            let workouts = (samples as? [HKWorkout]) ?? []
            let mapped: [LivityWorkout] = workouts.map { workout in
                // Use the legacy convenience accessors — they're deprecated in iOS 18 but
                // still return values, and avoid branching on iOS version for stats lookups.
                let kcal = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
                let km: Double? = {
                    guard let meters = workout.totalDistance?.doubleValue(for: .meter()) else { return nil }
                    return meters / 1000
                }()
                return LivityWorkout(
                    activityName: Self.workoutName(workout.workoutActivityType),
                    icon: Self.workoutIcon(workout.workoutActivityType),
                    durationMinutes: workout.duration / 60,
                    activeEnergyKcal: kcal,
                    distanceKm: km,
                    startDate: workout.startDate,
                    endDate: workout.endDate
                )
            }
            DispatchQueue.main.async { completion(mapped) }
        }
        store.execute(query)
    }

    private static func workoutName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .hiking: return "Hiking"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "Strength"
        case .highIntensityIntervalTraining: return "HIIT"
        case .pilates: return "Pilates"
        case .dance: return "Dance"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .stairs, .stairClimbing: return "Stairs"
        case .mixedCardio: return "Cardio"
        case .coreTraining: return "Core"
        case .crossTraining: return "Cross-training"
        case .soccer: return "Soccer"
        case .basketball: return "Basketball"
        case .tennis: return "Tennis"
        case .other: return "Workout"
        default: return "Workout"
        }
    }

    private static func workoutIcon(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "figure.run"
        case .walking, .hiking: return "figure.walk"
        case .cycling: return "bicycle"
        case .swimming: return "figure.pool.swim"
        case .yoga, .pilates: return "figure.yoga"
        case .functionalStrengthTraining, .traditionalStrengthTraining, .coreTraining: return "dumbbell.fill"
        case .highIntensityIntervalTraining, .crossTraining, .mixedCardio: return "flame.fill"
        case .elliptical: return "figure.elliptical"
        case .rowing: return "figure.rower"
        case .stairs, .stairClimbing: return "figure.stairs"
        case .soccer: return "soccerball"
        case .basketball: return "basketball.fill"
        case .tennis: return "figure.tennis"
        default: return "figure.mixed.cardio"
        }
    }

    /// Age in completed years from HealthKit's stored date of birth, if granted.
    private static func fetchAgeYears(store: HKHealthStore) -> Int? {
        guard let dob = try? store.dateOfBirthComponents().date else { return nil }
        return Calendar.current.dateComponents([.year], from: dob, to: Date()).year
    }

    /// Biological sex string: "male" / "female" / "other" / nil when not granted.
    private static func fetchBiologicalSex(store: HKHealthStore) -> String? {
        guard let sex = try? store.biologicalSex().biologicalSex else { return nil }
        switch sex {
        case .male: return "male"
        case .female: return "female"
        case .other: return "other"
        case .notSet: return nil
        @unknown default: return nil
        }
    }

    /// Most recent height ever recorded, in cm.
    private func fetchMostRecentHeightCm(completion: @escaping (Double?) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .height) else { completion(nil); return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
            let cm = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: .meterUnit(with: .centi))
            DispatchQueue.main.async { completion(cm) }
        }
        store.execute(query)
    }

    /// Most recent body mass ever recorded, in kg.
    private func fetchMostRecentBodyMassKg(completion: @escaping (Double?) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { completion(nil); return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
            let kg = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: .gramUnit(with: .kilo))
            DispatchQueue.main.async { completion(kg) }
        }
        store.execute(query)
    }

    /// Daily cumulative sums for the last `days` days, oldest→newest, ending on (and including) `endingOn`.
    /// Missing days become 0 so the returned array is always exactly `days` long and aligned by calendar day.
    private func fetchDailySumHistory(_ id: HKQuantityTypeIdentifier, unit: HKUnit, endingOn endDay: Date, days: Int, completion: @escaping ([Double]) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { completion([]); return }
        let cal = Calendar.current
        let anchor = cal.startOfDay(for: endDay)
        guard let start = cal.date(byAdding: .day, value: -(days - 1), to: anchor),
              let end = cal.date(byAdding: .day, value: 1, to: anchor) else {
            completion([]); return
        }
        let query = HKStatisticsCollectionQuery(
            quantityType: type,
            quantitySamplePredicate: nil,
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: DateComponents(day: 1)
        )
        query.initialResultsHandler = { _, collection, _ in
            var values: [Double] = []
            collection?.enumerateStatistics(from: start, to: end) { stat, _ in
                values.append(stat.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            DispatchQueue.main.async { completion(values) }
        }
        store.execute(query)
    }

    /// Daily *averages* (one value per calendar day) for a discrete metric like
    /// HRV, resting HR, respiratory rate, SpO2, wrist temperature. Returns
    /// exactly `days` values aligned by day, with 0.0 for days that had no
    /// samples. Used by the Recovery detail's monthly-trend cards.
    private func fetchDailyAverageHistory(_ id: HKQuantityTypeIdentifier, unit: HKUnit, endingOn endDay: Date, days: Int, completion: @escaping ([Double]) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { completion([]); return }
        let cal = Calendar.current
        let anchor = cal.startOfDay(for: endDay)
        guard let start = cal.date(byAdding: .day, value: -(days - 1), to: anchor),
              let end = cal.date(byAdding: .day, value: 1, to: anchor) else {
            completion([]); return
        }
        let query = HKStatisticsCollectionQuery(
            quantityType: type,
            quantitySamplePredicate: nil,
            options: .discreteAverage,
            anchorDate: start,
            intervalComponents: DateComponents(day: 1)
        )
        query.initialResultsHandler = { _, collection, _ in
            var values: [Double] = []
            collection?.enumerateStatistics(from: start, to: end) { stat, _ in
                values.append(stat.averageQuantity()?.doubleValue(for: unit) ?? 0)
            }
            DispatchQueue.main.async { completion(values) }
        }
        store.execute(query)
    }

    private func sumQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit, from: Date, to: Date, completion: @escaping (Double?) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { completion(nil); return }
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            completion(result?.sumQuantity()?.doubleValue(for: unit))
        }
        store.execute(query)
    }

    private func mostRecentQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit, from: Date, to: Date, completion: @escaping (Double?) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { completion(nil); return }
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .mostRecent) { _, result, _ in
            completion(result?.mostRecentQuantity()?.doubleValue(for: unit))
        }
        store.execute(query)
    }

    /// Same as `mostRecentQuantity` but also returns the *actual* end-date of
    /// the underlying sample. Used by recovery-detail snapshots that surface a
    /// "Last measured" timestamp — that timestamp must reflect a real Apple
    /// Health record, not the moment the user opened the screen.
    private func mostRecentQuantityWithDate(_ id: HKQuantityTypeIdentifier, unit: HKUnit, from: Date, to: Date, completion: @escaping (Double?, Date?) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { completion(nil, nil); return }
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .mostRecent) { _, result, _ in
            let value = result?.mostRecentQuantity()?.doubleValue(for: unit)
            let date = result?.mostRecentQuantityDateInterval()?.end
            completion(value, date)
        }
        store.execute(query)
    }

    /// Most recent sample of `id` ever recorded — used for body-composition
    /// metrics (BMI, body fat %, lean mass, waist) that don't reset per day.
    /// Falls back to nil only when the user has never logged the metric.
    private func fetchMostRecentEverQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit, completion: @escaping (Double?) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { completion(nil); return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
            let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
            DispatchQueue.main.async { completion(value) }
        }
        store.execute(query)
    }

    /// Sum of mindfulness session durations today (in minutes). Pulls every
    /// `.mindfulSession` sample whose interval overlaps the day window and
    /// adds up its duration — the standard way Apple Health reports mindful
    /// minutes per day.
    private func fetchMindfulMinutesToday(from: Date, to: Date, completion: @escaping (Double?) -> Void) {
        guard let type = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { completion(nil); return }
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: [])
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let total = (samples ?? []).reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 60.0 }
            DispatchQueue.main.async { completion(total > 0 ? total : nil) }
        }
        store.execute(query)
    }

    /// Daily mindful minutes for the trend chart. Bucketed by calendar day
    /// using each session's `startDate`; sessions that span midnight contribute
    /// to the day they began.
    private func fetchMindfulMinutesHistory(endingOn endDay: Date, days: Int, completion: @escaping ([Double]) -> Void) {
        guard let type = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { completion([]); return }
        let cal = Calendar.current
        let endExclusive = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: endDay)) ?? endDay
        let startInclusive = cal.date(byAdding: .day, value: -(days - 1), to: cal.startOfDay(for: endDay)) ?? endDay
        let predicate = HKQuery.predicateForSamples(withStart: startInclusive, end: endExclusive, options: [])
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            var perDay: [Date: Double] = [:]
            for s in (samples ?? []) {
                let day = cal.startOfDay(for: s.startDate)
                perDay[day, default: 0] += s.endDate.timeIntervalSince(s.startDate) / 60.0
            }
            var out: [Double] = []
            out.reserveCapacity(days)
            for offset in 0..<days {
                let day = cal.date(byAdding: .day, value: -(days - 1 - offset), to: cal.startOfDay(for: endDay))!
                out.append(perDay[day] ?? 0)
            }
            DispatchQueue.main.async { completion(out) }
        }
        store.execute(query)
    }

    /// Counts how many distinct hours today registered an Apple Stand Hour
    /// (HKCategoryValueAppleStandHour.stood). This is the same number Apple's
    /// Activity ring reports for the green stand ring.
    private func countStandHours(from: Date, to: Date, completion: @escaping (Int?) -> Void) {
        guard let type = HKObjectType.categoryType(forIdentifier: .appleStandHour) else { completion(nil); return }
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: [])
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let stood = (samples ?? []).compactMap { $0 as? HKCategorySample }
                .filter { $0.value == HKCategoryValueAppleStandHour.stood.rawValue }
                .count
            DispatchQueue.main.async { completion(stood) }
        }
        store.execute(query)
    }

    /// All symptom samples logged today, mapped to (display name, severity).
    /// HealthKit stores symptoms as category samples whose value is the
    /// severity (1=mild, 2=moderate, 3=severe). We iterate the full symptom
    /// catalogue since there's no single "any symptom" predicate.
    private func fetchSymptomsToday(from: Date, to: Date, completion: @escaping ([(name: String, severity: Int)]) -> Void) {
        let symptomCatalog: [(HKCategoryTypeIdentifier, String)] = [
            (.abdominalCramps, "Abdominal Cramps"),
            (.acne, "Acne"),
            (.appetiteChanges, "Appetite Changes"),
            (.bladderIncontinence, "Bladder Incontinence"),
            (.bloating, "Bloating"),
            (.breastPain, "Breast Pain"),
            (.chestTightnessOrPain, "Chest Tightness/Pain"),
            (.chills, "Chills"),
            (.constipation, "Constipation"),
            (.coughing, "Coughing"),
            (.diarrhea, "Diarrhea"),
            (.dizziness, "Dizziness"),
            (.drySkin, "Dry Skin"),
            (.fainting, "Fainting"),
            (.fatigue, "Fatigue"),
            (.fever, "Fever"),
            (.generalizedBodyAche, "Body Ache"),
            (.hairLoss, "Hair Loss"),
            (.headache, "Headache"),
            (.heartburn, "Heartburn"),
            (.hotFlashes, "Hot Flashes"),
            (.lossOfSmell, "Loss of Smell"),
            (.lossOfTaste, "Loss of Taste"),
            (.lowerBackPain, "Lower Back Pain"),
            (.memoryLapse, "Memory Lapse"),
            (.moodChanges, "Mood Changes"),
            (.nausea, "Nausea"),
            (.nightSweats, "Night Sweats"),
            (.pelvicPain, "Pelvic Pain"),
            (.rapidPoundingOrFlutteringHeartbeat, "Rapid Heartbeat"),
            (.runnyNose, "Runny Nose"),
            (.shortnessOfBreath, "Shortness of Breath"),
            (.sinusCongestion, "Sinus Congestion"),
            (.skippedHeartbeat, "Skipped Heartbeat"),
            (.sleepChanges, "Sleep Changes"),
            (.soreThroat, "Sore Throat"),
            (.vaginalDryness, "Vaginal Dryness"),
            (.vomiting, "Vomiting"),
            (.wheezing, "Wheezing")
        ]

        let inner = DispatchGroup()
        var collected: [(name: String, severity: Int)] = []
        let lock = NSLock()
        for (id, name) in symptomCatalog {
            guard let type = HKObjectType.categoryType(forIdentifier: id) else { continue }
            let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: [])
            inner.enter()
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                if let casted = samples as? [HKCategorySample] {
                    lock.lock()
                    for s in casted {
                        // Severity values: notPresent=1, mild=2, moderate=3, severe=4
                        // (see HKCategoryValueSeverity). Map to 1-3 scale for the UI.
                        let severity = max(1, min(3, s.value - 1))
                        collected.append((name, severity))
                    }
                    lock.unlock()
                }
                inner.leave()
            }
            store.execute(query)
        }
        inner.notify(queue: .main) {
            completion(collected.sorted { $0.severity > $1.severity })
        }
    }

    /// Apple's `stateOfMind` mood logs for today (iOS 18+). Returns the count
    /// of entries and the average valence (-1 very unpleasant → +1 very
    /// pleasant) so the UI can show a single mood readout.
    @available(iOS 18.0, *)
    private func fetchMoodToday(from: Date, to: Date, completion: @escaping (Int?, Double?) -> Void) {
        let type = HKSampleType.stateOfMindType()
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: [])
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let states = (samples ?? []).compactMap { $0 as? HKStateOfMind }
            guard !states.isEmpty else {
                DispatchQueue.main.async { completion(nil, nil) }
                return
            }
            let avg = states.reduce(0.0) { $0 + $1.valence } / Double(states.count)
            DispatchQueue.main.async { completion(states.count, avg) }
        }
        store.execute(query)
    }

    private struct SleepStageSummary {
        var deep: Double = 0
        var rem: Double = 0
        var core: Double = 0
        var awake: Double = 0
        var totalAsleep: Double = 0
    }

    /// Bedtime/wake-time history per night for the last `days` calendar days, oldest→newest.
    /// Each tuple is `(bedtime, wakeTime)` for the session attributed to that morning;
    /// `nil` slots mean no sleep was recorded that night.
    private func fetchBedtimeWakeHistory(endingOn endDay: Date, days: Int, completion: @escaping ([(Date?, Date?)]) -> Void) {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { completion([]); return }
        let cal = Calendar.current
        let anchor = cal.startOfDay(for: endDay)
        guard let windowStart = cal.date(byAdding: .day, value: -days, to: anchor),
              let windowEnd = cal.date(byAdding: .hour, value: 12, to: anchor) else {
            completion([]); return
        }
        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd, options: [])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
            // Bucket asleep samples by attributed morning, then take min(start) and max(end) per bucket.
            var bedByDay: [Date: Date] = [:]
            var wakeByDay: [Date: Date] = [:]
            for sample in (samples as? [HKCategorySample]) ?? [] {
                let asleep = (sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                    || sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                    || sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
                    || sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue)
                guard asleep else { continue }
                let endHour = cal.component(.hour, from: sample.endDate)
                let attributedDate: Date
                if endHour < 18 {
                    attributedDate = cal.startOfDay(for: sample.endDate)
                } else {
                    attributedDate = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: sample.endDate)) ?? sample.endDate
                }
                if let existing = bedByDay[attributedDate] {
                    if sample.startDate < existing { bedByDay[attributedDate] = sample.startDate }
                } else {
                    bedByDay[attributedDate] = sample.startDate
                }
                if let existing = wakeByDay[attributedDate] {
                    if sample.endDate > existing { wakeByDay[attributedDate] = sample.endDate }
                } else {
                    wakeByDay[attributedDate] = sample.endDate
                }
            }
            var result: [(Date?, Date?)] = []
            for i in stride(from: days - 1, through: 0, by: -1) {
                let day = cal.date(byAdding: .day, value: -i, to: anchor) ?? anchor
                result.append((bedByDay[day], wakeByDay[day]))
            }
            DispatchQueue.main.async { completion(result) }
        }
        store.execute(query)
    }

    /// 30-day sleep stage history, oldest→newest. Each entry aggregates the session that
    /// *ended* on that calendar day. Samples ending in the morning (before 18:00) are
    /// attributed to that day; samples ending in the evening are attributed to the next
    /// morning's session — which is the convention Apple Health uses in its summary.
    private func fetchSleepHistory(endingOn endDay: Date, days: Int, completion: @escaping ([SleepStageSummary]) -> Void) {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { completion([]); return }
        let cal = Calendar.current
        let anchor = cal.startOfDay(for: endDay)
        guard let windowStart = cal.date(byAdding: .day, value: -days, to: anchor),
              let windowEnd = cal.date(byAdding: .hour, value: 12, to: anchor) else {
            completion([]); return
        }
        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd, options: [])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
            var byDay: [Date: SleepStageSummary] = [:]
            for sample in (samples as? [HKCategorySample]) ?? [] {
                let endHour = cal.component(.hour, from: sample.endDate)
                let attributedDate: Date
                if endHour < 18 {
                    attributedDate = cal.startOfDay(for: sample.endDate)
                } else {
                    attributedDate = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: sample.endDate)) ?? sample.endDate
                }
                var stats = byDay[attributedDate] ?? SleepStageSummary()
                let duration = sample.endDate.timeIntervalSince(sample.startDate) / 60
                switch sample.value {
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                    stats.deep += duration; stats.totalAsleep += duration
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                    stats.rem += duration; stats.totalAsleep += duration
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                    stats.core += duration; stats.totalAsleep += duration
                case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                    stats.totalAsleep += duration
                case HKCategoryValueSleepAnalysis.awake.rawValue:
                    stats.awake += duration
                default: break
                }
                byDay[attributedDate] = stats
            }
            var result: [SleepStageSummary] = []
            for i in stride(from: days - 1, through: 0, by: -1) {
                let day = cal.date(byAdding: .day, value: -i, to: anchor) ?? anchor
                result.append(byDay[day] ?? SleepStageSummary())
            }
            DispatchQueue.main.async { completion(result) }
        }
        store.execute(query)
    }

    private func fetchSleepStages(targetDay: Date, completion: @escaping (SleepStageSummary) -> Void) {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { completion(SleepStageSummary()); return }
        let cal = Calendar.current
        // Window: 18:00 previous day → 12:00 target day (to capture the overnight session)
        let windowStart = cal.date(byAdding: .hour, value: -6, to: targetDay) ?? targetDay
        let windowEnd = cal.date(byAdding: .hour, value: 12, to: targetDay) ?? targetDay
        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd, options: [])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
            var summary = SleepStageSummary()
            for sample in (samples as? [HKCategorySample]) ?? [] {
                let duration = sample.endDate.timeIntervalSince(sample.startDate) / 60
                switch sample.value {
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                    summary.deep += duration
                    summary.totalAsleep += duration
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                    summary.rem += duration
                    summary.totalAsleep += duration
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                    summary.core += duration
                    summary.totalAsleep += duration
                case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                    summary.totalAsleep += duration
                case HKCategoryValueSleepAnalysis.awake.rawValue:
                    summary.awake += duration
                default: break
                }
            }
            completion(summary)
        }
        store.execute(query)
    }

    /// Estimates minutes spent in each HR zone for a given day. Each HR sample contributes the
    /// gap until the next sample, capped at 5 minutes (so an overnight silence doesn't count as
    /// a 12-hour zone-1 stint). Returns `[z1, z2, z3, z4, z5]` minutes.
    private func fetchHRZoneDistribution(from: Date, to: Date, bounds: (Int, Int, Int, Int), completion: @escaping ([Double]) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { completion([0, 0, 0, 0, 0]); return }
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
            let unit = HKUnit(from: "count/min")
            let list = (samples as? [HKQuantitySample]) ?? []
            var minutes: [Double] = [0, 0, 0, 0, 0]
            let maxGap: TimeInterval = 5 * 60
            for i in 0..<list.count {
                let s = list[i]
                let hr = Int(s.quantity.doubleValue(for: unit))
                let interval: TimeInterval
                if i + 1 < list.count {
                    interval = min(max(0, list[i + 1].startDate.timeIntervalSince(s.endDate)), maxGap)
                } else {
                    interval = min(s.endDate.timeIntervalSince(s.startDate), maxGap)
                }
                let mins = interval / 60
                switch hr {
                case ...bounds.0: minutes[0] += mins
                case (bounds.0 + 1)...bounds.1: minutes[1] += mins
                case (bounds.1 + 1)...bounds.2: minutes[2] += mins
                case (bounds.2 + 1)...bounds.3: minutes[3] += mins
                default: minutes[4] += mins
                }
            }
            DispatchQueue.main.async { completion(minutes) }
        }
        store.execute(query)
    }

    /// Heart-rate samples for the day with their timestamps, sorted by time.
    /// Used both for stress aggregates and for the intraday stress chart.
    private func fetchHRSamplesWithTimes(from: Date, to: Date, completion: @escaping ([(Date, Double)]) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { completion([]); return }
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
            let unit = HKUnit(from: "count/min")
            let pairs: [(Date, Double)] = (samples as? [HKQuantitySample])?.map {
                ($0.startDate, $0.quantity.doubleValue(for: unit))
            } ?? []
            DispatchQueue.main.async { completion(pairs) }
        }
        store.execute(query)
    }

    private func fetchHRSamples(from: Date, to: Date, completion: @escaping ([Double]) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { completion([]); return }
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let unit = HKUnit(from: "count/min")
            let values = (samples as? [HKQuantitySample])?.map { $0.quantity.doubleValue(for: unit) } ?? []
            completion(values)
        }
        store.execute(query)
    }

    // MARK: - Habit: fetch today's value for a given type (for habit progress display)

    /// All available historical daily totals for a habit, oldest→newest, up to (and including) `endingOn`.
    /// Probes HealthKit for the earliest sample of the quantity type, then aggregates daily sums from there.
    /// Days without samples are omitted (we don't need to persist zeros for the streak/heatmap).
    /// Returns an empty array for habit types that don't map to a cumulative-sum HK query
    /// (sleep, bedtime, workouts) — those fall back to "today-only" recording via `fetchHabitValue`.
    func fetchHabitHistory(type: HabitType, endingOn endDay: Date, completion: @escaping ([(date: Date, value: Double)]) -> Void) {
        func runSum(_ id: HKQuantityTypeIdentifier, unit: HKUnit, scale: Double = 1.0) {
            guard let hkType = HKQuantityType.quantityType(forIdentifier: id) else { completion([]); return }
            collectDailySums(type: hkType, unit: unit, scale: scale, endingOn: endDay, completion: completion)
        }

        switch type {
        case .steps:
            runSum(.stepCount, unit: .count())
        case .floorsClimbed:
            runSum(.flightsClimbed, unit: .count())
        case .caloriesBurned:
            runSum(.activeEnergyBurned, unit: .kilocalorie())
        case .caloriesConsumed:
            runSum(.dietaryEnergyConsumed, unit: .kilocalorie())
        case .proteinIntake:
            runSum(.dietaryProtein, unit: .gram())
        case .waterIntake:
            runSum(.dietaryWater, unit: .literUnit(with: .milli))
        case .sunExposure:
            if #available(iOS 17.0, *) {
                runSum(.timeInDaylight, unit: .second(), scale: 1.0 / 60.0)
            } else {
                completion([])
            }
        case .workoutCount:
            collectDailyWorkoutTotals(endingOn: endDay, metric: .count, completion: completion)
        case .workoutDistance:
            collectDailyWorkoutTotals(endingOn: endDay, metric: .distanceKm, completion: completion)
        case .workoutDuration:
            collectDailyWorkoutTotals(endingOn: endDay, metric: .durationMinutes, completion: completion)
        case .sleepDuration, .bedtime:
            completion([])
        }
    }

    private enum WorkoutDailyMetric { case count, distanceKm, durationMinutes }

    /// Daily workout aggregates over the last 3 years (matching `collectDailySums`),
    /// emitting only days that actually contain workouts.
    private func collectDailyWorkoutTotals(endingOn endDay: Date, metric: WorkoutDailyMetric, completion: @escaping ([(date: Date, value: Double)]) -> Void) {
        let cal = Calendar.current
        let endExclusive = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: endDay)) ?? endDay
        let start = cal.date(byAdding: .year, value: -3, to: endExclusive).map { cal.startOfDay(for: $0) } ?? cal.startOfDay(for: endDay)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: endExclusive, options: [])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
            let workouts = (samples as? [HKWorkout]) ?? []
            var perDay: [Date: Double] = [:]
            for w in workouts {
                let day = cal.startOfDay(for: w.startDate)
                let value: Double
                switch metric {
                case .count: value = 1
                case .distanceKm:
                    let meters = w.totalDistance?.doubleValue(for: .meter()) ?? 0
                    value = meters / 1000
                case .durationMinutes:
                    value = w.duration / 60
                }
                if value > 0 { perDay[day, default: 0] += value }
            }
            let sorted = perDay.sorted { $0.key < $1.key }.map { (date: $0.key, value: $0.value) }
            DispatchQueue.main.async { completion(sorted) }
        }
        store.execute(query)
    }

    private func collectDailySums(type: HKQuantityType, unit: HKUnit, scale: Double, endingOn endDay: Date, completion: @escaping ([(date: Date, value: Double)]) -> Void) {
        let cal = Calendar.current
        let endExclusive = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: endDay)) ?? endDay
        // 3-year lookback: more than enough for streaks, fast enough to aggregate in one query.
        // A limit-1 ascending HKSampleQuery to find the "true earliest" sample is accurate but
        // causes a long spin on users with years of dense step/HR data.
        let anchor = cal.date(byAdding: .year, value: -3, to: endExclusive).map { cal.startOfDay(for: $0) } ?? cal.startOfDay(for: endDay)

        let collection = HKStatisticsCollectionQuery(
            quantityType: type,
            quantitySamplePredicate: nil,
            options: .cumulativeSum,
            anchorDate: anchor,
            intervalComponents: DateComponents(day: 1)
        )
        collection.initialResultsHandler = { _, result, _ in
            var out: [(Date, Double)] = []
            result?.enumerateStatistics(from: anchor, to: endExclusive) { stat, _ in
                // Only keep days that actually have samples — skip implicit zero-fills.
                guard let qty = stat.sumQuantity() else { return }
                let v = qty.doubleValue(for: unit) * scale
                if v > 0 {
                    out.append((cal.startOfDay(for: stat.startDate), v))
                }
            }
            DispatchQueue.main.async { completion(out) }
        }
        store.execute(collection)
    }

    func fetchHabitValue(type: HabitType, on date: Date, completion: @escaping (Double) -> Void) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? date

        switch type {
        case .steps:
            sumQuantity(.stepCount, unit: .count(), from: start, to: end) { completion($0 ?? 0) }
        case .floorsClimbed:
            sumQuantity(.flightsClimbed, unit: .count(), from: start, to: end) { completion($0 ?? 0) }
        case .caloriesBurned:
            sumQuantity(.activeEnergyBurned, unit: .kilocalorie(), from: start, to: end) { completion($0 ?? 0) }
        case .caloriesConsumed:
            sumQuantity(.dietaryEnergyConsumed, unit: .kilocalorie(), from: start, to: end) { completion($0 ?? 0) }
        case .proteinIntake:
            sumQuantity(.dietaryProtein, unit: .gram(), from: start, to: end) { completion($0 ?? 0) }
        case .waterIntake:
            sumQuantity(.dietaryWater, unit: .literUnit(with: .milli), from: start, to: end) { completion($0 ?? 0) }
        case .sunExposure:
            if #available(iOS 17.0, *) {
                sumQuantity(.timeInDaylight, unit: .second(), from: start, to: end) { completion(($0 ?? 0) / 60) }
            } else {
                completion(0)
            }
        case .sleepDuration:
            fetchSleepStages(targetDay: start) { completion($0.totalAsleep / 60) }
        case .bedtime:
            completion(0) // Bedtime is tracked as a time, handled separately
        case .workoutCount:
            fetchWorkouts(from: start, to: end) { completion(Double($0.count)) }
        case .workoutDistance:
            fetchWorkouts(from: start, to: end) { workouts in
                let km = workouts.reduce(0.0) { $0 + ($1.distanceKm ?? 0) }
                completion(km)
            }
        case .workoutDuration:
            fetchWorkouts(from: start, to: end) { workouts in
                let minutes = workouts.reduce(0.0) { $0 + $1.durationMinutes }
                completion(minutes)
            }
        }
    }
}
