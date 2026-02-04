//
//  MetricModels.swift
//  Health Reporter
//
//  מודלים עבור כל המדדים המחושבים - Daily, Weekly, Monthly
//

import Foundation

// MARK: - Metric Protocol

/// פרוטוקול בסיסי לכל מדד
protocol InsightMetric {
    var id: String { get }
    var nameKey: String { get }
    var value: Double? { get }
    var displayValue: String { get }
    var category: MetricCategory { get }
    var reliability: DataReliability { get }
    var trend: MetricTrend? { get }
}

// MARK: - Enums

/// קטגוריות מדדים
enum MetricCategory: String, CaseIterable {
    case recovery
    case sleep
    case stress
    case load
    case performance
    case habit

    var iconName: String {
        switch self {
        case .recovery: return "heart.circle"
        case .sleep: return "moon.zzz"
        case .stress: return "brain.head.profile"
        case .load: return "figure.run"
        case .performance: return "flame"
        case .habit: return "checkmark.circle"
        }
    }

    var colorHex: String {
        switch self {
        case .recovery: return "#4CAF50"
        case .sleep: return "#9C27B0"
        case .stress: return "#FF9800"
        case .load: return "#2196F3"
        case .performance: return "#F44336"
        case .habit: return "#00BCD4"
        }
    }
}

/// מגמת מדד
enum MetricTrend: String {
    case improving = "improving"
    case stable = "stable"
    case declining = "declining"

    var iconName: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down.right"
        }
    }

    var localizationKey: String {
        return "trend.\(rawValue)"
    }
}

/// אמינות נתונים
enum DataReliability: String {
    case high = "high"       // 14+ days of data
    case medium = "medium"   // 7-13 days
    case low = "low"         // 5-6 days
    case insufficient = "insufficient" // <5 days

    var confidenceScore: Double {
        switch self {
        case .high: return 1.0
        case .medium: return 0.75
        case .low: return 0.5
        case .insufficient: return 0.0
        }
    }

    var localizationKey: String {
        return "reliability.\(rawValue)"
    }
}

/// רמת מוכנות לאימון
enum WorkoutReadinessLevel: String, CaseIterable {
    case skip = "skip"
    case light = "light"
    case moderate = "moderate"
    case full = "full"
    case push = "push"

    var localizationKey: String {
        return "workout.readiness.\(rawValue)"
    }

    var score: Int {
        switch self {
        case .skip: return 0
        case .light: return 25
        case .moderate: return 50
        case .full: return 75
        case .push: return 100
        }
    }

    static func from(score: Double) -> WorkoutReadinessLevel {
        switch score {
        case 0..<20: return .skip
        case 20..<40: return .light
        case 40..<60: return .moderate
        case 60..<80: return .full
        default: return .push
        }
    }
}

/// רמת טווח (Low/Medium/High)
enum RangeLevel: String {
    case veryLow = "very_low"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case veryHigh = "very_high"

    var localizationKey: String {
        return "level.\(rawValue)"
    }

    static func from(score: Double, scale: ClosedRange<Double> = 0...100) -> RangeLevel {
        let normalized = (score - scale.lowerBound) / (scale.upperBound - scale.lowerBound) * 100
        switch normalized {
        case 0..<20: return .veryLow
        case 20..<40: return .low
        case 40..<60: return .medium
        case 60..<80: return .high
        default: return .veryHigh
        }
    }
}

// MARK: - Daily Metrics (15)

/// 1. איזון מערכת העצבים
struct NervousSystemBalance: InsightMetric {
    let id = "nervous_system_balance"
    let nameKey = "metric.nervous_system_balance"
    let value: Double?
    let category: MetricCategory = .recovery
    let reliability: DataReliability
    let trend: MetricTrend?

    let hrvComponent: Double?
    let rhrComponent: Double?

    var displayValue: String {
        guard let v = value else { return "--" }
        return "\(Int(v))"
    }

    var level: RangeLevel {
        guard let v = value else { return .medium }
        return RangeLevel.from(score: v)
    }

    var explanationKey: String {
        return "metric.nervous_system_balance.explanation.\(level.rawValue)"
    }
}

/// 2. מוכנות להתאוששות
struct RecoveryReadiness: InsightMetric {
    let id = "recovery_readiness"
    let nameKey = "metric.recovery_readiness"
    let value: Double?
    let category: MetricCategory = .recovery
    let reliability: DataReliability
    let trend: MetricTrend?

    let hrvScore: Double?
    let rhrScore: Double?
    let sleepScore: Double?
    let strainScore: Double?

    var displayValue: String {
        guard let v = value else { return "--" }
        return "\(Int(v))"
    }

    var level: RangeLevel {
        guard let v = value else { return .medium }
        return RangeLevel.from(score: v)
    }
}

/// 3. חוב התאוששות
struct RecoveryDebt: InsightMetric {
    let id = "recovery_debt"
    let nameKey = "metric.recovery_debt"
    let value: Double? // -50 to +50
    let category: MetricCategory = .recovery
    let reliability: DataReliability
    let trend: MetricTrend?

    var displayValue: String {
        guard let v = value else { return "--" }
        let sign = v >= 0 ? "+" : ""
        return "\(sign)\(Int(v))"
    }

    var isInSurplus: Bool {
        guard let v = value else { return false }
        return v > 0
    }

    var explanationKey: String {
        if isInSurplus {
            return "metric.recovery_debt.surplus"
        } else {
            return "metric.recovery_debt.deficit"
        }
    }
}

/// 4. מדד עומס לחץ
struct StressLoadIndex: InsightMetric {
    let id = "stress_load_index"
    let nameKey = "metric.stress_load_index"
    let value: Double?
    let category: MetricCategory = .stress
    let reliability: DataReliability
    let trend: MetricTrend?

    let hrvDepression: Double?
    let rhrElevation: Double?
    let sleepDeficit: Double?

    var displayValue: String {
        guard let v = value else { return "--" }
        return "\(Int(v))"
    }

    var level: RangeLevel {
        guard let v = value else { return .medium }
        // For stress, high value = bad
        return RangeLevel.from(score: v)
    }
}

/// 5. רעננות בוקר
struct MorningFreshness: InsightMetric {
    let id = "morning_freshness"
    let nameKey = "metric.morning_freshness"
    let value: Double?
    let category: MetricCategory = .recovery
    let reliability: DataReliability
    let trend: MetricTrend?

    var displayValue: String {
        guard let v = value else { return "--" }
        return "\(Int(v))"
    }

    var level: RangeLevel {
        guard let v = value else { return .medium }
        return RangeLevel.from(score: v)
    }
}

/// 6. איכות שינה
struct SleepQuality: InsightMetric {
    let id = "sleep_quality"
    let nameKey = "metric.sleep_quality"
    let value: Double?
    let category: MetricCategory = .sleep
    let reliability: DataReliability
    let trend: MetricTrend?

    let durationHours: Double?
    let deepPercent: Double?
    let remPercent: Double?
    let efficiency: Double?

    var displayValue: String {
        guard let v = value else { return "--" }
        return "\(Int(v))"
    }

    var level: RangeLevel {
        guard let v = value else { return .medium }
        return RangeLevel.from(score: v)
    }
}

/// 7. עקביות שינה
struct SleepConsistency: InsightMetric {
    let id = "sleep_consistency"
    let nameKey = "metric.sleep_consistency"
    let value: Double?
    let category: MetricCategory = .habit
    let reliability: DataReliability
    let trend: MetricTrend?

    let bedtimeStdDev: Double? // minutes
    let wakeTimeStdDev: Double? // minutes
    let durationStdDev: Double? // minutes

    var displayValue: String {
        guard let v = value else { return "--" }
        return "\(Int(v))"
    }
}

/// 8. דגש שינה (בסגנון אפל)
struct SleepHighlight: InsightMetric {
    let id = "sleep_highlight"
    let nameKey = "metric.sleep_highlight"
    let value: Double? // ממוצע שעות השינה
    let category: MetricCategory = .sleep
    let reliability: DataReliability
    let trend: MetricTrend?

    /// נתוני שינה יומיים לגרף (7 ימים אחרונים)
    let dailySleepData: [DailySleepEntry]

    /// יעד שינה (ברירת מחדל 7.5 שעות)
    let targetHours: Double

    var displayValue: String {
        guard let v = value else { return "--" }
        let hours = Int(v)
        let minutes = Int((v - Double(hours)) * 60)
        return "\(hours)h \(minutes)m"
    }

    /// פורמט תצוגה עברי: "X שע׳ Y דק׳"
    var displayValueHebrew: String {
        guard let v = value else { return "--" }
        let hours = Int(v)
        let minutes = Int((v - Double(hours)) * 60)
        return "\(hours) שע׳ \(minutes) דק׳"
    }

    /// האם הממוצע מתחת ליעד
    var isBelowTarget: Bool {
        guard let v = value else { return false }
        return v < targetHours
    }
}

/// נתון שינה יומי לגרף
struct DailySleepEntry {
    let date: Date
    let hours: Double
    let dayOfWeekShort: String // א׳, ב׳, ג׳... או Mon, Tue...

    /// גובה יחסי לגרף (0-1)
    func relativeHeight(maxHours: Double) -> CGFloat {
        guard maxHours > 0 else { return 0 }
        return CGFloat(min(hours / maxHours, 1.0))
    }
}

// שמירה לתאימות לאחור
typealias SleepDebt = SleepHighlight

/// 9. עומס אימון
struct InsightTrainingStrain: InsightMetric {
    let id = "training_strain"
    let nameKey = "metric.training_strain"
    let value: Double? // 0-10
    let category: MetricCategory = .load
    let reliability: DataReliability
    let trend: MetricTrend?

    var displayValue: String {
        guard let v = value else { return "--" }
        return String(format: "%.1f", v)
    }

    var level: RangeLevel {
        guard let v = value else { return .medium }
        return RangeLevel.from(score: v * 10) // Scale to 0-100
    }
}

/// 10. איזון עומסים (ACWR)
struct LoadBalance: InsightMetric {
    let id = "load_balance"
    let nameKey = "metric.load_balance"
    let value: Double? // 0-100
    let category: MetricCategory = .load
    let reliability: DataReliability
    let trend: MetricTrend?

    let acwr: Double? // actual ratio
    let acute7d: Double?
    let chronic28d: Double?

    var displayValue: String {
        guard let v = value else { return "--" }
        return "\(Int(v))"
    }

    var zone: LoadZone {
        guard let ratio = acwr else { return .optimal }
        switch ratio {
        case 0..<0.8: return .detraining
        case 0.8..<1.3: return .optimal
        case 1.3..<1.5: return .overreaching
        default: return .danger
        }
    }

    enum LoadZone: String {
        case detraining = "detraining"
        case optimal = "optimal"
        case overreaching = "overreaching"
        case danger = "danger"

        var localizationKey: String {
            return "load.zone.\(rawValue)"
        }
    }
}

/// 11. תחזית אנרגיה
struct EnergyForecast: InsightMetric {
    let id = "energy_forecast"
    let nameKey = "metric.energy_forecast"
    let value: Double?
    let category: MetricCategory = .performance
    let reliability: DataReliability
    let trend: MetricTrend?

    let readinessContribution: Double?
    let sleepBoost: Double?
    let strainDrain: Double?
    let hrvBoost: Double?

    var displayValue: String {
        guard let v = value else { return "--" }
        return "\(Int(v))"
    }

    var level: RangeLevel {
        guard let v = value else { return .medium }
        return RangeLevel.from(score: v)
    }

    var explanationKey: String {
        return "metric.energy_forecast.explanation.\(level.rawValue)"
    }
}

/// 12. מוכנות לאימון
struct WorkoutReadiness: InsightMetric {
    let id = "workout_readiness"
    let nameKey = "metric.workout_readiness"
    let value: Double?
    let category: MetricCategory = .performance
    let reliability: DataReliability
    let trend: MetricTrend?

    let recoveryWeight: Double?
    let sleepWeight: Double?
    let autonomicWeight: Double?

    var displayValue: String {
        return readinessLevel.localizationKey.localized
    }

    var readinessLevel: WorkoutReadinessLevel {
        guard let v = value else { return .moderate }
        return WorkoutReadinessLevel.from(score: v)
    }
}

/// 13. ציון פעילות
struct ActivityScore: InsightMetric {
    let id = "activity_score"
    let nameKey = "metric.activity_score"
    let value: Double?
    let category: MetricCategory = .habit
    let reliability: DataReliability
    let trend: MetricTrend?

    let stepsRatio: Double?
    let consistencyScore: Double?

    var displayValue: String {
        guard let v = value else { return "--" }
        return "\(Int(v))"
    }
}

/// 14. יעדים יומיים
struct DailyGoals: InsightMetric {
    let id = "daily_goals"
    let nameKey = "metric.daily_goals"
    let value: Double? // 0-100%
    let category: MetricCategory = .habit
    let reliability: DataReliability
    let trend: MetricTrend?

    let movePercent: Double?
    let exercisePercent: Double?
    let standPercent: Double?

    var displayValue: String {
        guard let v = value else { return "--" }
        return "\(Int(v))%"
    }
}

/// 15. מגמת כושר לב-ריאה
struct CardioFitnessTrend: InsightMetric {
    let id = "cardio_fitness_trend"
    let nameKey = "metric.cardio_fitness_trend"
    let value: Double? // percentage change
    let category: MetricCategory = .performance
    let reliability: DataReliability
    let trend: MetricTrend?

    let vo2max7d: Double?
    let vo2max28d: Double?

    var displayValue: String {
        guard let v = value else { return "--" }
        let sign = v >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", v))%"
    }
}

// MARK: - Star Metrics Container

/// 5 מדדי כוכב שמייחדים את האפליקציה
struct StarMetrics {
    let nervousSystemBalance: NervousSystemBalance
    let recoveryDebt: RecoveryDebt
    let energyForecast: EnergyForecast
    let workoutReadiness: WorkoutReadiness
    let consistencyScore: Double? // Monthly metric brought forward

    var allMetrics: [any InsightMetric] {
        return [nervousSystemBalance, recoveryDebt, energyForecast, workoutReadiness]
    }
}

// MARK: - Daily Metrics Container

struct DailyMetrics {
    // Recovery Domain
    let nervousSystemBalance: NervousSystemBalance
    let recoveryReadiness: RecoveryReadiness
    let recoveryDebt: RecoveryDebt
    let stressLoadIndex: StressLoadIndex
    let morningFreshness: MorningFreshness

    // Sleep Domain
    let sleepQuality: SleepQuality
    let sleepConsistency: SleepConsistency
    let sleepDebt: SleepDebt

    // Load/Performance Domain
    let trainingStrain: InsightTrainingStrain
    let loadBalance: LoadBalance
    let energyForecast: EnergyForecast
    let workoutReadiness: WorkoutReadiness

    // Activity/Habit Domain
    let activityScore: ActivityScore
    let dailyGoals: DailyGoals
    let cardioFitnessTrend: CardioFitnessTrend

    /// Main health score for the day (composite)
    /// מחזיר nil אם אין מספיק נתונים אמיתיים (לפחות 3 מדדים)
    var mainScore: Double? {
        let weights: [(Double?, Double)] = [
            (recoveryReadiness.value, 0.25),
            (sleepQuality.value, 0.20),
            (nervousSystemBalance.value, 0.20),
            (energyForecast.value, 0.15),
            (activityScore.value, 0.10),
            (loadBalance.value, 0.10)
        ]

        var totalWeight = 0.0
        var weightedSum = 0.0
        var validMetricsCount = 0

        for (value, weight) in weights {
            if let v = value {
                weightedSum += v * weight
                totalWeight += weight
                validMetricsCount += 1
            }
        }

        // צריך לפחות 3 מדדים אמיתיים כדי להציג ציון
        guard validMetricsCount >= 3, totalWeight > 0 else { return nil }
        return weightedSum / totalWeight
    }

    var allMetrics: [any InsightMetric] {
        return [
            nervousSystemBalance, recoveryReadiness, recoveryDebt,
            stressLoadIndex, morningFreshness,
            sleepQuality, sleepConsistency, sleepDebt,
            trainingStrain, loadBalance, energyForecast, workoutReadiness,
            activityScore, dailyGoals, cardioFitnessTrend
        ]
    }
}
