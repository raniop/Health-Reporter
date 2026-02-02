//
//  DailyMetricsEngine.swift
//  Health Reporter
//
//  מנוע חישוב 15 המדדים היומיים
//

import Foundation
import HealthKit

final class DailyMetricsEngine {

    static let shared = DailyMetricsEngine()
    private init() {}

    // MARK: - Main Calculation

    /// מחשב את כל 15 המדדים היומיים (או שבועיים/חודשיים לפי period)
    func calculateDailyMetrics(
        todayData: HealthDataModel,
        historicalData: [HealthDataModel],
        period: TimePeriod = .day,
        completion: @escaping (DailyMetrics) -> Void
    ) {
        // קביעת חלונות זמן לפי התקופה הנבחרת
        let (primaryWindow, secondaryWindow, tertiaryWindow) = windowSizes(for: period)

        let last7Days = Array(historicalData.suffix(primaryWindow))
        let last14Days = Array(historicalData.suffix(secondaryWindow))
        let last28Days = Array(historicalData.suffix(tertiaryWindow))

        // עבור שבוע/חודש - אגרגציה של נתוני התקופה
        let periodData: HealthDataModel
        switch period {
        case .day:
            periodData = todayData
        case .week:
            periodData = aggregateData(Array(historicalData.suffix(7)))
        case .month:
            periodData = aggregateData(Array(historicalData.suffix(30)))
        }

        // Calculate each metric (using periodData for aggregated values)
        let nervousSystem = calculateNervousSystemBalance(today: periodData, last7: last7Days, last28: last28Days)
        let recoveryReadiness = calculateRecoveryReadiness(today: periodData, last7: last7Days)
        let recoveryDebt = calculateRecoveryDebt(last7: last7Days)
        let stressLoad = calculateStressLoadIndex(today: periodData, last28: last28Days)
        let morningFresh = calculateMorningFreshness(today: periodData, last28: last28Days)

        let sleepQual = calculateSleepQuality(today: periodData)
        let sleepConsist = calculateSleepConsistency(last14: last14Days)
        let sleepDebtMetric = calculateSleepDebt(last7: last7Days)

        let trainStrain = calculateTrainingStrain(today: periodData)
        let loadBal = calculateLoadBalance(last7: last7Days, last28: last28Days)
        let energyFore = calculateEnergyForecast(today: periodData, recoveryReadiness: recoveryReadiness)
        let workoutRead = calculateWorkoutReadiness(nervousSystem: nervousSystem, sleepQuality: sleepQual, recoveryReadiness: recoveryReadiness)

        let actScore = calculateActivityScore(today: periodData, last90: historicalData)
        let dailyGoalsMetric = calculateDailyGoals(today: periodData)
        let cardioTrend = calculateCardioFitnessTrend(last7: last7Days, last28: last28Days)

        let metrics = DailyMetrics(
            nervousSystemBalance: nervousSystem,
            recoveryReadiness: recoveryReadiness,
            recoveryDebt: recoveryDebt,
            stressLoadIndex: stressLoad,
            morningFreshness: morningFresh,
            sleepQuality: sleepQual,
            sleepConsistency: sleepConsist,
            sleepDebt: sleepDebtMetric,
            trainingStrain: trainStrain,
            loadBalance: loadBal,
            energyForecast: energyFore,
            workoutReadiness: workoutRead,
            activityScore: actScore,
            dailyGoals: dailyGoalsMetric,
            cardioFitnessTrend: cardioTrend
        )

        completion(metrics)
    }

    // MARK: - Individual Metric Calculations

    /// 1. איזון מערכת העצבים
    private func calculateNervousSystemBalance(
        today: HealthDataModel,
        last7: [HealthDataModel],
        last28: [HealthDataModel]
    ) -> NervousSystemBalance {

        let hrv7d = average(last7.compactMap { normalize($0.heartRateVariability) })
        let hrv28d = average(last28.compactMap { normalize($0.heartRateVariability) })
        let rhr7d = average(last7.compactMap { normalize($0.restingHeartRate) })
        let rhr28d = average(last28.compactMap { normalize($0.restingHeartRate) })

        var hrvComponent: Double?
        var rhrComponent: Double?
        var finalScore: Double?

        // HRV component
        if let h7 = hrv7d, let h28 = hrv28d, h28 > 0 {
            let hrvRatio = h7 / h28
            // Interpolate: 0.75 → 30, 1.0 → 80, 1.2 → 95
            hrvComponent = interpolate(value: hrvRatio, from: (0.75, 30), mid: (1.0, 80), to: (1.2, 95))
        }

        // RHR component (lower is better, so inverse)
        if let r7 = rhr7d, let r28 = rhr28d, r28 > 0 {
            let rhrDelta = r28 - r7 // positive = improvement
            // Interpolate: -5 → 30, 0 → 70, +5 → 95
            rhrComponent = interpolate(value: rhrDelta, from: (-5, 30), mid: (0, 70), to: (5, 95))
        }

        // Combine with weights
        if let hrv = hrvComponent, let rhr = rhrComponent {
            finalScore = hrv * 0.65 + rhr * 0.35
        } else if let hrv = hrvComponent {
            finalScore = hrv
        } else if let rhr = rhrComponent {
            finalScore = rhr
        }

        let reliability = calculateReliability(dataPoints: last7.count, minimum: 5, good: 14)
        let trend = calculateTrend(recent: hrv7d, baseline: hrv28d, higherIsBetter: true)

        return NervousSystemBalance(
            value: finalScore?.clamped(to: 0...100),
            reliability: reliability,
            trend: trend,
            hrvComponent: hrvComponent,
            rhrComponent: rhrComponent
        )
    }

    /// 2. מוכנות להתאוששות
    private func calculateRecoveryReadiness(today: HealthDataModel, last7: [HealthDataModel]) -> RecoveryReadiness {
        // Calculate readiness from components
        let hrv = normalize(today.heartRateVariability)
        let rhr = normalize(today.restingHeartRate)
        let sleepHours = normalize(today.sleepHours)

        // Get baselines from last 7 days
        let hrvBaseline = average(last7.compactMap { normalize($0.heartRateVariability) })
        let rhrBaseline = average(last7.compactMap { normalize($0.restingHeartRate) })

        var hrvScore: Double?
        var rhrScore: Double?
        var sleepScore: Double?

        // HRV Score (0-100)
        if let h = hrv, let baseline = hrvBaseline, baseline > 0 {
            let ratio = h / baseline
            hrvScore = interpolate(value: ratio, from: (0.7, 20), mid: (1.0, 70), to: (1.3, 100))
        }

        // RHR Score (0-100) - lower is better
        if let r = rhr, let baseline = rhrBaseline, baseline > 0 {
            let ratio = r / baseline
            rhrScore = interpolate(value: ratio, from: (1.15, 20), mid: (1.0, 70), to: (0.85, 100))
        }

        // Sleep Score (0-100)
        if let s = sleepHours {
            sleepScore = interpolate(value: s, from: (5.0, 30), mid: (7.0, 75), to: (8.5, 100))
        }

        // Combine scores with weights: HRV 35%, RHR 25%, Sleep 30%, base 10%
        var totalScore: Double?
        var totalWeight = 0.0

        if let h = hrvScore { totalScore = (totalScore ?? 0) + h * 0.35; totalWeight += 0.35 }
        if let r = rhrScore { totalScore = (totalScore ?? 0) + r * 0.25; totalWeight += 0.25 }
        if let s = sleepScore { totalScore = (totalScore ?? 0) + s * 0.30; totalWeight += 0.30 }

        if totalWeight > 0 {
            totalScore = (totalScore ?? 0) / totalWeight
        }

        let reliability: DataReliability
        let dataCount = [hrv, rhr, sleepHours].compactMap { $0 }.count
        reliability = dataCount >= 3 ? .high : (dataCount >= 2 ? .medium : .low)

        return RecoveryReadiness(
            value: totalScore?.clamped(to: 0...100),
            reliability: reliability,
            trend: nil,
            hrvScore: hrvScore,
            rhrScore: rhrScore,
            sleepScore: sleepScore,
            strainScore: nil
        )
    }

    /// 3. חוב התאוששות
    private func calculateRecoveryDebt(last7: [HealthDataModel]) -> RecoveryDebt {
        var debtSum = 0.0
        var validDays = 0

        for day in last7 {
            // צריך לפחות נתון שינה כדי לחשב readiness
            guard let sleep = normalize(day.sleepHours), sleep > 0 else { continue }

            let dayReadiness = interpolate(value: sleep, from: (5.0, 30), mid: (7.0, 65), to: (9.0, 90))

            // Simple strain estimate based on exercise
            let strain = (day.exerciseMinutes ?? 0) / 30.0 * 3.0 // ~3 strain per 30min exercise

            // Recovery surplus/deficit for the day
            let dailyBalance = dayReadiness - (strain * 10)
            debtSum += dailyBalance
            validDays += 1
        }

        // צריך לפחות יום אחד עם נתונים
        guard validDays > 0 else {
            return RecoveryDebt(
                value: nil,
                reliability: .low,
                trend: nil
            )
        }

        let avgDebt = debtSum / Double(validDays)
        let reliability = calculateReliability(dataPoints: validDays, minimum: 3, good: 7)

        return RecoveryDebt(
            value: avgDebt.clamped(to: -50...50),
            reliability: reliability,
            trend: nil
        )
    }

    /// 4. מדד עומס לחץ
    private func calculateStressLoadIndex(
        today: HealthDataModel,
        last28: [HealthDataModel]
    ) -> StressLoadIndex {

        let hrvBaseline = average(last28.compactMap { normalize($0.heartRateVariability) })
        let rhrBaseline = average(last28.compactMap { normalize($0.restingHeartRate) })

        var hrvDepression: Double?
        var rhrElevation: Double?
        var sleepDeficit: Double?

        // HRV depression (how much below baseline)
        if let todayHRV = normalize(today.heartRateVariability), let baseline = hrvBaseline, baseline > 0 {
            let ratio = todayHRV / baseline
            // ratio < 1 = depression. Convert to 0-100 stress score
            hrvDepression = max(0, (1 - ratio) * 100)
        }

        // RHR elevation (how much above baseline)
        if let todayRHR = normalize(today.restingHeartRate), let baseline = rhrBaseline, baseline > 0 {
            let ratio = todayRHR / baseline
            // ratio > 1 = elevation. Convert to 0-100 stress score
            rhrElevation = max(0, (ratio - 1) * 100)
        }

        // Sleep deficit
        if let sleepHours = normalize(today.sleepHours) {
            let target = 7.5
            let deficit = max(0, target - sleepHours)
            sleepDeficit = (deficit / target) * 100
        }

        var finalScore: Double?
        let components = [hrvDepression, rhrElevation, sleepDeficit].compactMap { $0 }
        if !components.isEmpty {
            // Weighted: HRV 40%, RHR 30%, Sleep 30%
            var sum = 0.0
            var weight = 0.0
            if let h = hrvDepression { sum += h * 0.4; weight += 0.4 }
            if let r = rhrElevation { sum += r * 0.3; weight += 0.3 }
            if let s = sleepDeficit { sum += s * 0.3; weight += 0.3 }
            finalScore = weight > 0 ? sum / weight : nil
        }

        let reliability = calculateReliability(dataPoints: components.count, minimum: 1, good: 3)

        return StressLoadIndex(
            value: finalScore?.clamped(to: 0...100),
            reliability: reliability,
            trend: nil,
            hrvDepression: hrvDepression,
            rhrElevation: rhrElevation,
            sleepDeficit: sleepDeficit
        )
    }

    /// 5. רעננות בוקר
    private func calculateMorningFreshness(
        today: HealthDataModel,
        last28: [HealthDataModel]
    ) -> MorningFreshness {

        // Sleep score component
        var sleepScore: Double?
        if let hours = normalize(today.sleepHours) {
            sleepScore = interpolate(value: hours, from: (5.0, 30), mid: (7.0, 70), to: (8.5, 95))
        }

        let rhr28d = average(last28.compactMap { normalize($0.restingHeartRate) })
        var rhrDeltaScore: Double?
        if let todayRHR = normalize(today.restingHeartRate), let baseline = rhr28d {
            let delta = baseline - todayRHR // positive = today is lower = good
            rhrDeltaScore = interpolate(value: delta, from: (-5, 20), mid: (0, 60), to: (5, 95))
        }

        let hrv28d = average(last28.compactMap { normalize($0.heartRateVariability) })
        var hrvRatioScore: Double?
        if let todayHRV = normalize(today.heartRateVariability), let baseline = hrv28d, baseline > 0 {
            let ratio = todayHRV / baseline
            hrvRatioScore = interpolate(value: ratio, from: (0.75, 20), mid: (1.0, 70), to: (1.25, 95))
        }

        var finalScore: Double?
        if let sleep = sleepScore {
            var sum = sleep * 0.5
            var weight = 0.5

            if let rhr = rhrDeltaScore { sum += rhr * 0.25; weight += 0.25 }
            if let hrv = hrvRatioScore { sum += hrv * 0.25; weight += 0.25 }

            finalScore = sum / weight
        }

        let hasData = [sleepScore, rhrDeltaScore, hrvRatioScore].compactMap { $0 }.count
        let reliability = calculateReliability(dataPoints: hasData, minimum: 1, good: 3)

        return MorningFreshness(
            value: finalScore?.clamped(to: 0...100),
            reliability: reliability,
            trend: nil
        )
    }

    /// 6. איכות שינה
    private func calculateSleepQuality(today: HealthDataModel) -> SleepQuality {
        let duration = normalize(today.sleepHours)
        let deep = normalize(today.sleepDeepHours)
        let rem = normalize(today.sleepRemHours)

        var deepPercent: Double?
        var remPercent: Double?
        var efficiency: Double?
        var score: Double?

        if let d = duration, d > 0 {
            // Duration score (0-40 points)
            var durationScore = interpolate(value: d, from: (5.0, 10), mid: (7.0, 30), to: (8.5, 40))

            // Deep sleep score (0-25 points)
            var deepScore = 0.0
            if let dp = deep {
                deepPercent = (dp / d) * 100
                // Target: 15-20% deep sleep
                deepScore = interpolate(value: deepPercent!, from: (10, 10), mid: (17.5, 25), to: (25, 20))
            }

            // REM score (0-20 points)
            var remScore = 0.0
            if let r = rem {
                remPercent = (r / d) * 100
                // Target: 20-25% REM
                remScore = interpolate(value: remPercent!, from: (15, 10), mid: (22.5, 20), to: (30, 15))
            }

            // Efficiency estimation
            if let dp = deep, let r = rem {
                efficiency = min(100, ((dp + r) / d) * 100 + 50)
                let effScore = interpolate(value: efficiency!, from: (70, 5), mid: (85, 12), to: (95, 15))
                score = durationScore + deepScore + remScore + effScore
            } else {
                score = durationScore + deepScore + remScore
            }
        }

        let dataCount = [duration, deep, rem].compactMap { $0 }.count
        let reliability = calculateReliability(dataPoints: dataCount, minimum: 1, good: 3)

        return SleepQuality(
            value: score?.clamped(to: 0...100),
            reliability: reliability,
            trend: nil,
            durationHours: duration,
            deepPercent: deepPercent,
            remPercent: remPercent,
            efficiency: efficiency
        )
    }

    /// 7. עקביות שינה
    private func calculateSleepConsistency(last14: [HealthDataModel]) -> SleepConsistency {
        let durations = last14.compactMap { normalize($0.sleepHours) }

        guard durations.count >= 5 else {
            return SleepConsistency(
                value: nil,
                reliability: .insufficient,
                trend: nil,
                bedtimeStdDev: nil,
                wakeTimeStdDev: nil,
                durationStdDev: nil
            )
        }

        let durationStdDev = standardDeviation(durations)

        // Convert stdDev to score: lower stdDev = higher score
        // stdDev of 0.5h = 90 points, 1h = 70 points, 2h = 40 points
        var score: Double?
        if let std = durationStdDev {
            score = interpolate(value: std, from: (0.5, 90), mid: (1.0, 70), to: (2.0, 40))
        }

        let reliability = calculateReliability(dataPoints: durations.count, minimum: 5, good: 10)

        return SleepConsistency(
            value: score?.clamped(to: 0...100),
            reliability: reliability,
            trend: nil,
            bedtimeStdDev: nil,
            wakeTimeStdDev: nil,
            durationStdDev: durationStdDev.map { $0 * 60 } // Convert to minutes
        )
    }

    /// 8. חוב שינה
    private func calculateSleepDebt(last7: [HealthDataModel]) -> SleepDebt {
        let target = 7.5
        var totalDebt = 0.0
        var validDays = 0

        for day in last7 {
            if let hours = normalize(day.sleepHours) {
                totalDebt += (target - hours)
                validDays += 1
            }
        }

        let reliability = calculateReliability(dataPoints: validDays, minimum: 3, good: 7)

        return SleepDebt(
            value: validDays > 0 ? totalDebt : nil,
            reliability: reliability,
            trend: nil
        )
    }

    /// 9. עומס אימון
    private func calculateTrainingStrain(today: HealthDataModel) -> InsightTrainingStrain {
        // Simple strain calculation based on exercise minutes
        let exerciseMin = today.exerciseMinutes ?? 0
        let strain = min(10.0, exerciseMin / 30.0 * 3.0) // ~3 strain per 30 min

        let hasWorkout = exerciseMin > 0
        let reliability: DataReliability = hasWorkout ? .high : .medium

        return InsightTrainingStrain(
            value: strain,
            reliability: reliability,
            trend: nil
        )
    }

    /// 10. איזון עומסים (ACWR)
    private func calculateLoadBalance(
        last7: [HealthDataModel],
        last28: [HealthDataModel]
    ) -> LoadBalance {

        // Calculate strain for each day
        let acuteStrains = last7.map { min(10.0, ($0.exerciseMinutes ?? 0) / 30.0 * 3.0) }
        let chronicStrains = last28.map { min(10.0, ($0.exerciseMinutes ?? 0) / 30.0 * 3.0) }

        guard !acuteStrains.isEmpty, !chronicStrains.isEmpty else {
            return LoadBalance(
                value: nil,
                reliability: .insufficient,
                trend: nil,
                acwr: nil,
                acute7d: nil,
                chronic28d: nil
            )
        }

        let acute7d = acuteStrains.reduce(0, +) / Double(max(1, acuteStrains.count))
        let chronic28d = chronicStrains.reduce(0, +) / Double(max(1, chronicStrains.count))

        var acwr: Double?
        var score: Double?

        if chronic28d > 0.1 { // Avoid division by very small numbers
            acwr = acute7d / chronic28d
            // Optimal ACWR: 0.8-1.3 = 85-95 points
            if let ratio = acwr {
                if ratio < 0.8 {
                    score = interpolate(value: ratio, from: (0.4, 40), mid: (0.6, 60), to: (0.8, 85))
                } else if ratio <= 1.3 {
                    score = interpolate(value: ratio, from: (0.8, 85), mid: (1.0, 95), to: (1.3, 85))
                } else {
                    score = interpolate(value: ratio, from: (1.3, 85), mid: (1.5, 50), to: (2.0, 20))
                }
            }
        } else {
            // No chronic training - balanced by default
            score = 70
            acwr = 1.0
        }

        let reliability = calculateReliability(dataPoints: chronicStrains.filter { $0 > 0 }.count, minimum: 7, good: 21)

        return LoadBalance(
            value: score?.clamped(to: 0...100),
            reliability: reliability,
            trend: nil,
            acwr: acwr,
            acute7d: acute7d,
            chronic28d: chronic28d
        )
    }

    /// 11. תחזית אנרגיה
    private func calculateEnergyForecast(
        today: HealthDataModel,
        recoveryReadiness: RecoveryReadiness
    ) -> EnergyForecast {

        // אם אין נתוני readiness, אין תחזית אנרגיה
        guard let readinessContribution = recoveryReadiness.value else {
            return EnergyForecast(
                value: nil,
                reliability: .low,
                trend: nil,
                readinessContribution: nil,
                sleepBoost: nil,
                strainDrain: nil,
                hrvBoost: nil
            )
        }

        var sleepBoost = 0.0
        if let hours = normalize(today.sleepHours) {
            sleepBoost = (hours - 7) * 5 // +/- 5 points per hour difference from 7
        }

        let exerciseMin = today.exerciseMinutes ?? 0
        let strain = min(10.0, exerciseMin / 30.0 * 3.0)
        let strainDrain = strain * -2 // Each strain point costs 2 energy points

        var hrvBoost = 0.0
        if let hrv = normalize(today.heartRateVariability) {
            // Simplified: assume baseline of 50ms
            hrvBoost = (hrv - 50) * 0.5
        }

        let finalScore = readinessContribution + sleepBoost + strainDrain + hrvBoost

        return EnergyForecast(
            value: finalScore.clamped(to: 0...100),
            reliability: .high,
            trend: nil,
            readinessContribution: readinessContribution,
            sleepBoost: sleepBoost,
            strainDrain: strainDrain,
            hrvBoost: hrvBoost
        )
    }

    /// 12. מוכנות לאימון
    private func calculateWorkoutReadiness(
        nervousSystem: NervousSystemBalance,
        sleepQuality: SleepQuality,
        recoveryReadiness: RecoveryReadiness
    ) -> WorkoutReadiness {

        // צריך לפחות 2 מדדים אמיתיים כדי לחשב מוכנות לאימון
        let hasData = [recoveryReadiness.value, sleepQuality.value, nervousSystem.value].compactMap { $0 }.count

        guard hasData >= 2 else {
            return WorkoutReadiness(
                value: nil,
                reliability: .low,
                trend: nil,
                recoveryWeight: nil,
                sleepWeight: nil,
                autonomicWeight: nil
            )
        }

        let recoveryWeight = recoveryReadiness.value
        let sleepWeight = sleepQuality.value
        let autonomicWeight = nervousSystem.value

        // חשב ממוצע רק מהערכים הקיימים
        let values = [recoveryWeight, sleepWeight, autonomicWeight].compactMap { $0 }
        let score = values.reduce(0, +) / Double(values.count)

        let reliability = calculateReliability(dataPoints: hasData, minimum: 1, good: 3)

        return WorkoutReadiness(
            value: score.clamped(to: 0...100),
            reliability: reliability,
            trend: nil,
            recoveryWeight: recoveryWeight,
            sleepWeight: sleepWeight,
            autonomicWeight: autonomicWeight
        )
    }

    /// 13. ציון פעילות
    private func calculateActivityScore(
        today: HealthDataModel,
        last90: [HealthDataModel]
    ) -> ActivityScore {

        let baseline90 = average(last90.compactMap { normalize($0.steps) }.filter { $0 > 0 })

        var stepsRatio: Double?
        if let todaySteps = normalize(today.steps), let baseline = baseline90, baseline > 0 {
            stepsRatio = todaySteps / baseline
        }

        // Calculate consistency (how many of last 7 days met goal)
        let last7 = last90.suffix(7)
        let daysMetGoal = last7.filter { ($0.steps ?? 0) >= 8000 }.count
        let consistencyScore = Double(daysMetGoal) / 7.0 * 100

        var score: Double?
        if let ratio = stepsRatio {
            // stepsRatio * 0.7 + consistency * 0.3
            let ratioScore = min(100, ratio * 100)
            score = ratioScore * 0.7 + consistencyScore * 0.3
        }

        let reliability = calculateReliability(dataPoints: last90.count, minimum: 14, good: 60)

        return ActivityScore(
            value: score?.clamped(to: 0...100),
            reliability: reliability,
            trend: nil,
            stepsRatio: stepsRatio,
            consistencyScore: consistencyScore
        )
    }

    /// 14. יעדים יומיים
    private func calculateDailyGoals(today: HealthDataModel) -> DailyGoals {
        let moveGoal = 500.0 // kcal
        let exerciseGoal = 30.0 // minutes
        let standGoal = 12.0 // hours

        let movePercent = min(100, (today.activeEnergy ?? 0) / moveGoal * 100)
        let exercisePercent = min(100, (today.exerciseMinutes ?? 0) / exerciseGoal * 100)
        let standPercent = min(100, (today.standHours ?? 0) / standGoal * 100)

        let avgPercent = (movePercent + exercisePercent + standPercent) / 3

        let hasData = [today.activeEnergy, today.exerciseMinutes, today.standHours].compactMap { $0 }.count
        let reliability = calculateReliability(dataPoints: hasData, minimum: 1, good: 3)

        return DailyGoals(
            value: avgPercent,
            reliability: reliability,
            trend: nil,
            movePercent: movePercent,
            exercisePercent: exercisePercent,
            standPercent: standPercent
        )
    }

    /// 15. מגמת כושר לב-ריאה
    private func calculateCardioFitnessTrend(
        last7: [HealthDataModel],
        last28: [HealthDataModel]
    ) -> CardioFitnessTrend {

        let vo2max7d = average(last7.compactMap { normalize($0.vo2Max) })
        let vo2max28d = average(last28.compactMap { normalize($0.vo2Max) })

        var percentChange: Double?
        var trend: MetricTrend?

        if let recent = vo2max7d, let baseline = vo2max28d, baseline > 0 {
            percentChange = ((recent - baseline) / baseline) * 100

            if let change = percentChange {
                if change > 2 { trend = .improving }
                else if change < -2 { trend = .declining }
                else { trend = .stable }
            }
        }

        let dataCount = last28.compactMap { normalize($0.vo2Max) }.count
        let reliability = calculateReliability(dataPoints: dataCount, minimum: 3, good: 10)

        return CardioFitnessTrend(
            value: percentChange,
            reliability: reliability,
            trend: trend,
            vo2max7d: vo2max7d,
            vo2max28d: vo2max28d
        )
    }

    // MARK: - Helper Functions

    private func normalize(_ value: Double?) -> Double? {
        guard let v = value, v != 0, !v.isNaN, !v.isInfinite else { return nil }
        return v
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func standardDeviation(_ values: [Double]) -> Double? {
        guard values.count > 1 else { return nil }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)
        return sqrt(variance)
    }

    private func interpolate(
        value: Double,
        from: (Double, Double),
        mid: (Double, Double),
        to: (Double, Double)
    ) -> Double {
        if value <= from.0 { return from.1 }
        if value >= to.0 { return to.1 }

        if value <= mid.0 {
            // Interpolate between from and mid
            let ratio = (value - from.0) / (mid.0 - from.0)
            return from.1 + ratio * (mid.1 - from.1)
        } else {
            // Interpolate between mid and to
            let ratio = (value - mid.0) / (to.0 - mid.0)
            return mid.1 + ratio * (to.1 - mid.1)
        }
    }

    private func calculateReliability(dataPoints: Int, minimum: Int, good: Int) -> DataReliability {
        if dataPoints < minimum { return .insufficient }
        if dataPoints < good / 2 { return .low }
        if dataPoints < good { return .medium }
        return .high
    }

    private func calculateTrend(recent: Double?, baseline: Double?, higherIsBetter: Bool) -> MetricTrend? {
        guard let r = recent, let b = baseline, b > 0 else { return nil }

        let change = (r - b) / b

        if higherIsBetter {
            if change > 0.05 { return .improving }
            if change < -0.05 { return .declining }
        } else {
            if change > 0.05 { return .declining }
            if change < -0.05 { return .improving }
        }

        return .stable
    }

    // MARK: - Period Helpers

    /// קביעת גדלי חלונות זמן לפי התקופה
    private func windowSizes(for period: TimePeriod) -> (primary: Int, secondary: Int, tertiary: Int) {
        switch period {
        case .day:
            return (7, 14, 28)      // יומי: 7 ימים, 14 ימים, 28 ימים
        case .week:
            return (7, 28, 56)      // שבועי: שבוע, 4 שבועות, 8 שבועות
        case .month:
            return (30, 60, 90)     // חודשי: 30 יום, 60 יום, 90 יום
        }
    }

    /// אגרגציה של נתונים לתקופה (ממוצעים)
    private func aggregateData(_ data: [HealthDataModel]) -> HealthDataModel {
        guard !data.isEmpty else { return HealthDataModel() }

        var aggregated = HealthDataModel()

        // Steps - סכום
        let stepsValues = data.compactMap { normalize($0.steps) }
        aggregated.steps = stepsValues.isEmpty ? nil : stepsValues.reduce(0, +)

        // Active Energy - סכום
        let energyValues = data.compactMap { normalize($0.activeEnergy) }
        aggregated.activeEnergy = energyValues.isEmpty ? nil : energyValues.reduce(0, +)

        // Exercise Minutes - סכום
        let exerciseValues = data.compactMap { normalize($0.exerciseMinutes) }
        aggregated.exerciseMinutes = exerciseValues.isEmpty ? nil : exerciseValues.reduce(0, +)

        // Sleep Hours - ממוצע
        let sleepValues = data.compactMap { normalize($0.sleepHours) }
        aggregated.sleepHours = average(sleepValues)

        // Deep Sleep - ממוצע
        let deepValues = data.compactMap { normalize($0.sleepDeepHours) }
        aggregated.sleepDeepHours = average(deepValues)

        // REM Sleep - ממוצע
        let remValues = data.compactMap { normalize($0.sleepRemHours) }
        aggregated.sleepRemHours = average(remValues)

        // HRV - ממוצע
        let hrvValues = data.compactMap { normalize($0.heartRateVariability) }
        aggregated.heartRateVariability = average(hrvValues)

        // RHR - ממוצע
        let rhrValues = data.compactMap { normalize($0.restingHeartRate) }
        aggregated.restingHeartRate = average(rhrValues)

        // VO2 Max - ממוצע
        let vo2Values = data.compactMap { normalize($0.vo2Max) }
        aggregated.vo2Max = average(vo2Values)

        // Stand Hours - ממוצע
        let standValues = data.compactMap { normalize($0.standHours) }
        aggregated.standHours = average(standValues)

        return aggregated
    }
}

// MARK: - Extensions

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
