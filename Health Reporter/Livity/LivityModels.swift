//
//  LivityModels.swift
//  Health Reporter
//
//  Data models for the Livity-inspired UI: daily metric bundle + habit model.
//

import Foundation
import SwiftUI

// MARK: - Daily metrics (what the Overview tab displays for a given day)

struct LivityDailyMetrics {
    var date: Date

    // Body Battery (0-100)
    var bodyBattery: Int?
    var bodyBatteryPhase: BodyBatteryPhase?

    // Stress (0-100) + today's stats
    var stressNow: Int?
    var stressAverage: Int?
    var stressPeak: Int?
    var stressLow: Int?

    // Strain (0-100 percentage of daily target)
    var strainPercent: Double?
    var totalEnergyKcal: Double?
    var activeEnergyKcal: Double?
    var steps: Int?
    var strainBucket: String?   // e.g. "Bottom 33%"

    // Strain/energy/activity history (last 30 days, oldest→newest, today last).
    // Missing days are 0. Used for the "Monthly Trends" mini-charts.
    var strainHistory: [Double] = []
    var activeEnergyHistory: [Double] = []
    var totalEnergyHistory: [Double] = []
    var stepsHistory: [Double] = []
    var exerciseMinutesHistory: [Double] = []
    var floorsClimbedHistory: [Double] = []
    var exerciseMinutes: Double?
    var floorsClimbed: Double?

    // Sleep
    var sleepScore: Double?       // 0-100
    var sleepDeepMinutes: Double?
    var sleepCoreMinutes: Double?
    var sleepREMMinutes: Double?
    var sleepAwakeMinutes: Double?
    var sleepTotalMinutes: Double?
    var sleepBucket: String?

    // Sleep history (30 days, oldest→newest). Minutes per stage, per night.
    var sleepDeepHistory: [Double] = []
    var sleepCoreHistory: [Double] = []
    var sleepREMHistory: [Double] = []
    var sleepAwakeHistory: [Double] = []
    var sleepTotalHistory: [Double] = []
    var sleepScoreHistory: [Double] = []

    // Heart rate zone distribution (minutes in each of 5 zones, today).
    // Bounds represent upper-bound BPM for zones 1–4 (zone 5 is above bounds[3]).
    var heartZoneMinutes: [Double] = [0, 0, 0, 0, 0]
    var heartZoneBounds: [Int] = [131, 143, 155, 167]

    // Daily-average histories of cardiovascular metrics (oldest→newest, today last).
    // 0 entries indicate no measurement that day. Used for the Stress/Recovery trends.
    var hrvHistory: [Double] = []
    var restingHRHistory: [Double] = []
    var respiratoryRateHistory: [Double] = []
    var spo2History: [Double] = []
    var wristTempHistory: [Double] = []

    // Actual end-date of the most recent HealthKit sample for each recovery
    // metric (today's sample only). nil when no sample was recorded today —
    // never substitute Date() because that would imply a measurement that
    // didn't happen.
    var hrvSampleDate: Date?
    var restingHRSampleDate: Date?
    var respiratoryRateSampleDate: Date?
    var spo2SampleDate: Date?
    var wristTempSampleDate: Date?

    // Intraday stress series: (timestamp, stress 0-100) computed from HR samples
    // via Karvonen reserve. Used to draw the today's Stress chart and the
    // low/medium/high time-in-band breakdown.
    var stressIntraday: [(date: Date, value: Int)] = []

    // Today's workouts (HKWorkout)
    var workouts: [LivityWorkout] = []

    // User profile (from HealthKit characteristics + most recent samples).
    // Used to personalise goals and zone bounds. nil when user hasn't logged.
    var ageYears: Int?
    var biologicalSex: String?  // "male" / "female" / "other"
    var heightCm: Double?
    /// Estimated nightly bedtime times for the last N nights, ordered oldest→newest.
    /// Lets us derive sleep schedule consistency without inventing values.
    var bedtimeHistory: [Date?] = []
    var wakeTimeHistory: [Date?] = []

    // Recovery
    var recoveryScore: Double?    // 0-100
    var hrv: Double?
    var restingHR: Double?
    var respiratoryRate: Double?   // breaths per minute
    var spo2: Double?              // blood oxygen %
    var wristTempFahrenheit: Double?
    var recoveryBucket: String?

    // Cardio fitness (VO2 max, ml/kg/min) — most recent measurement + history
    var vo2Max: Double?
    var vo2MaxSampleDate: Date?
    var vo2MaxHistory: [Double] = []

    // Mindful minutes (sum today) + 30-day history
    var mindfulMinutes: Double?
    var mindfulMinutesHistory: [Double] = []

    // Atrial fibrillation burden (% of time today, iOS 16+)
    var atrialFibBurdenPct: Double?
    var atrialFibBurdenHistory: [Double] = []

    // Sleeping breathing disturbances (count of nightly events, iOS 18+)
    var sleepBreathingDisturbances: Double?
    var sleepBreathingDisturbancesHistory: [Double] = []

    // Blood pressure (most recent today, mmHg) + history
    var bloodPressureSystolic: Double?
    var bloodPressureDiastolic: Double?
    var bloodPressureSampleDate: Date?
    var bloodPressureSystolicHistory: [Double] = []
    var bloodPressureDiastolicHistory: [Double] = []

    // Blood glucose (most recent today, mg/dL) + history
    var bloodGlucose: Double?
    var bloodGlucoseSampleDate: Date?
    var bloodGlucoseHistory: [Double] = []

    // Distances walked/ran/cycled/swam today, in km
    var distanceWalkingRunningKm: Double?
    var distanceCyclingKm: Double?
    var distanceSwimmingKm: Double?

    // Walking speed today (m/s, average) + history
    var walkingSpeed: Double?
    var walkingSpeedHistory: [Double] = []

    // Walking steadiness today (% — Apple Watch fall risk)
    var walkingSteadiness: Double?

    // Body composition — most recent measurements
    var bodyFatPercent: Double?
    var leanBodyMassKg: Double?
    var bodyMassIndex: Double?
    var waistCircumferenceCm: Double?

    // Audio exposure (today's averages, dB)
    var environmentalAudioDb: Double?
    var headphoneAudioDb: Double?

    // Stand hours today (Apple Watch — count of hours user stood ≥ 1 min)
    var standHoursToday: Int?

    // Symptoms logged today — name + severity (1=mild,2=moderate,3=severe).
    var symptomsToday: [(name: String, severity: Int)] = []

    // Mood / state of mind logs today (iOS 18+)
    var moodLogCount: Int?
    var moodValenceAvg: Double?      // -1.0 (very unpleasant) → +1.0 (very pleasant)

    // Nutrition / Energy Balance
    var energyLogged: Bool
    var caloriesConsumed: Double?
    var caloriesBurned: Double?
    var dietaryProtein: Double?       // grams
    var dietaryCarbs: Double?         // grams
    var dietaryFat: Double?           // grams
    var bodyMassKg: Double?

    // Energy Balance history (30 days, oldest→newest), kcal per day
    var caloriesConsumedHistory: [Double] = []
    var caloriesBurnedHistory: [Double] = []
    var proteinHistory: [Double] = []

    // Time in daylight
    var daylightMinutes: Int?
    var daylightPercentVsGoal: Double?   // negative if below
    var daylightHistory: [Int] = []      // most recent 30 days (oldest → today)

    static var empty: LivityDailyMetrics {
        LivityDailyMetrics(
            date: Date(),
            bodyBattery: nil,
            bodyBatteryPhase: nil,
            stressNow: nil,
            stressAverage: nil,
            stressPeak: nil,
            stressLow: nil,
            strainPercent: nil,
            totalEnergyKcal: nil,
            activeEnergyKcal: nil,
            steps: nil,
            strainBucket: nil,
            sleepScore: nil,
            sleepDeepMinutes: nil,
            sleepREMMinutes: nil,
            sleepAwakeMinutes: nil,
            sleepTotalMinutes: nil,
            sleepBucket: nil,
            recoveryScore: nil,
            hrv: nil,
            restingHR: nil,
            respiratoryRate: nil,
            spo2: nil,
            wristTempFahrenheit: nil,
            recoveryBucket: nil,
            energyLogged: false,
            caloriesConsumed: nil,
            caloriesBurned: nil,
            daylightMinutes: nil,
            daylightPercentVsGoal: nil
        )
    }
}

struct BodyBatteryPhase {
    let kind: BodyPhaseKind
    let name: String           // e.g., "Afternoon Dip"
    let startTime: String      // "13:52"
    let endTime: String        // "16:13"
    let subtitle: String       // "Battery drains faster"
}

/// Identifies which chronobiology phase the user is currently in. Drives both
/// the look of the Body Battery phase pill (icon + tint) and the dynamic
/// reordering of cards on the Overview tab — what's most relevant *right now*
/// floats to the top and gets the "featured" treatment.
enum BodyPhaseKind {
    case earlyMorning, morningPeak, midday, afternoonDip, evening, earlyNight, circadianNadir

    /// SF Symbol shown inside the pill — sunrise/sun/moon depending on the phase.
    var pillIcon: String {
        switch self {
        case .earlyMorning:   return "sunrise.fill"
        case .morningPeak:    return "sun.max.fill"
        case .midday:         return "sun.haze.fill"
        case .afternoonDip:   return "cloud.sun.fill"
        case .evening:        return "sunset.fill"
        case .earlyNight:     return "moon.stars.fill"
        case .circadianNadir: return "moon.zzz.fill"
        }
    }

    /// Pill background — soft theme tint that matches the time of day.
    var pillTint: Color {
        switch self {
        case .earlyMorning:   return LivityTheme.infoTint
        case .morningPeak:    return LivityTheme.warningTint
        case .midday:         return LivityTheme.warningTint
        case .afternoonDip:   return LivityTheme.badTint
        case .evening:        return LivityTheme.warningTint
        case .earlyNight:     return LivityTheme.infoTint
        case .circadianNadir: return LivityTheme.chipFill
        }
    }

    /// Foreground tint for the icon + label inside the pill.
    var pillAccent: Color {
        switch self {
        case .earlyMorning:   return LivityTheme.info
        case .morningPeak:    return LivityTheme.warning
        case .midday:         return LivityTheme.warning
        case .afternoonDip:   return LivityTheme.bad
        case .evening:        return LivityTheme.warning
        case .earlyNight:     return LivityTheme.info
        case .circadianNadir: return LivityTheme.textSecondary
        }
    }
}

struct LivityWorkout: Identifiable {
    let id = UUID()
    let activityName: String
    let icon: String
    let durationMinutes: Double
    let activeEnergyKcal: Double?
    let distanceKm: Double?
    let startDate: Date
    let endDate: Date
}

// MARK: - Stress descriptor

enum LivityStressBand {
    case relaxed, low, medium, high

    var label: String {
        switch self {
        case .relaxed: return "livity.stress.relaxed".localized
        case .low: return "livity.stress.lowLevel".localized
        case .medium: return "livity.stress.moderate".localized
        case .high: return "livity.stress.high".localized
        }
    }

    var color: Color {
        switch self {
        case .relaxed, .low: return LivityTheme.good
        case .medium: return LivityTheme.warning
        case .high: return LivityTheme.bad
        }
    }

    static func from(value: Int) -> LivityStressBand {
        switch value {
        case ..<25: return .relaxed
        case 25..<40: return .low
        case 40..<60: return .medium
        default: return .high
        }
    }
}

// MARK: - Habit model

enum HabitType: String, CaseIterable, Identifiable, Codable {
    case steps
    case floorsClimbed
    case caloriesBurned
    case caloriesConsumed
    case proteinIntake
    case waterIntake
    case sunExposure
    case sleepDuration
    case bedtime
    case workoutCount
    case workoutDistance
    case workoutDuration

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .steps: return "livity.habitType.steps".localized
        case .floorsClimbed: return "livity.habitType.floorsClimbed".localized
        case .caloriesBurned: return "livity.habitType.caloriesBurned".localized
        case .caloriesConsumed: return "livity.habitType.caloriesConsumed".localized
        case .proteinIntake: return "livity.habitType.proteinIntake".localized
        case .waterIntake: return "livity.habitType.waterIntake".localized
        case .sunExposure: return "livity.habitType.sunExposure".localized
        case .sleepDuration: return "livity.habitType.sleepDuration".localized
        case .bedtime: return "livity.habitType.bedtime".localized
        case .workoutCount: return "livity.habitType.workoutCount".localized
        case .workoutDistance: return "livity.habitType.workoutDistance".localized
        case .workoutDuration: return "livity.habitType.workoutDuration".localized
        }
    }

    var icon: String {
        switch self {
        case .steps: return "figure.walk"
        case .floorsClimbed: return "figure.stairs"
        case .caloriesBurned: return "flame.fill"
        case .caloriesConsumed: return "fork.knife"
        case .proteinIntake: return "drop.fill"
        case .waterIntake: return "drop"
        case .sunExposure: return "sun.max.fill"
        case .sleepDuration: return "bed.double.fill"
        case .bedtime: return "moon.fill"
        case .workoutCount: return "figure.mixed.cardio"
        case .workoutDistance: return "figure.run"
        case .workoutDuration: return "stopwatch"
        }
    }

    var unit: String {
        switch self {
        case .steps: return "livity.unit.steps".localized
        case .floorsClimbed: return "livity.unit.floors".localized
        case .caloriesBurned, .caloriesConsumed: return "livity.unit.kcal".localized
        case .proteinIntake: return "livity.unit.g".localized
        case .waterIntake: return "livity.unit.ml".localized
        case .sunExposure, .workoutDuration: return "livity.unit.min".localized
        case .sleepDuration: return "livity.unit.h".localized
        case .bedtime: return ""
        case .workoutCount: return "livity.unit.workouts".localized
        case .workoutDistance: return "livity.unit.km".localized
        }
    }

    var suggestedGoals: [Double] {
        switch self {
        case .steps: return [5_000, 8_000, 10_000]
        case .floorsClimbed: return [5, 10, 20]
        case .caloriesBurned: return [300, 500, 750]
        case .caloriesConsumed: return [1_500, 2_000, 2_500]
        case .proteinIntake: return [60, 100, 140]
        case .waterIntake: return [1_500, 2_000, 2_500]
        case .sunExposure: return [15, 30, 60]
        case .sleepDuration: return [6, 7, 8]
        case .bedtime: return [21, 22, 23]
        case .workoutCount: return [1, 2, 3]
        case .workoutDistance: return [3, 5, 10]
        case .workoutDuration: return [20, 30, 60]
        }
    }

    var defaultGoal: Double {
        suggestedGoals[safe: 2] ?? suggestedGoals.last ?? 10_000
    }
}

enum HabitFrequency: String, Codable, CaseIterable, Identifiable {
    case daily, weekly, monthly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .daily: return "livity.freq.daily".localized
        case .weekly: return "livity.freq.weekly".localized
        case .monthly: return "livity.freq.monthly".localized
        }
    }
    var subtitle: String {
        switch self {
        case .daily: return "livity.freq.daily.subtitle".localized
        case .weekly: return "livity.freq.weekly.subtitle".localized
        case .monthly: return "livity.freq.monthly.subtitle".localized
        }
    }
}

enum HabitColor: String, Codable, CaseIterable, Identifiable {
    case green, orange, yellow, blue, purple, indigo, red, pink
    var id: String { rawValue }
    var color: Color {
        switch self {
        case .green: return Color(red: 0.27, green: 0.78, blue: 0.38)
        case .orange: return Color(red: 0.98, green: 0.58, blue: 0.22)
        case .yellow: return Color(red: 0.99, green: 0.82, blue: 0.20)
        case .blue: return Color(red: 0.40, green: 0.76, blue: 0.98)
        case .purple: return Color(red: 0.66, green: 0.42, blue: 0.92)
        case .indigo: return Color(red: 0.36, green: 0.32, blue: 0.82)
        case .red: return Color(red: 0.95, green: 0.30, blue: 0.30)
        case .pink: return Color(red: 0.96, green: 0.36, blue: 0.56)
        }
    }
}

struct Habit: Identifiable, Codable, Equatable {
    var id: UUID
    var type: HabitType
    var frequency: HabitFrequency
    var goal: Double
    var color: HabitColor
    var dailyReminders: Bool
    var goalCompletedNotif: Bool
    var progressReminder: Bool
    var reminderHour: Int       // 0-23
    var reminderMinute: Int     // 0-59
    var syncHistoricalData: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        type: HabitType,
        frequency: HabitFrequency = .daily,
        goal: Double,
        color: HabitColor = .green,
        dailyReminders: Bool = true,
        goalCompletedNotif: Bool = true,
        progressReminder: Bool = true,
        reminderHour: Int = 19,
        reminderMinute: Int = 0,
        syncHistoricalData: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.frequency = frequency
        self.goal = goal
        self.color = color
        self.dailyReminders = dailyReminders
        self.goalCompletedNotif = goalCompletedNotif
        self.progressReminder = progressReminder
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.syncHistoricalData = syncHistoricalData
        self.createdAt = createdAt
    }
}

// MARK: - Habit progress for a single day

struct HabitDayProgress: Codable, Equatable {
    let date: Date       // normalized to start of day
    let value: Double
    let met: Bool        // whether goal was met that day
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
