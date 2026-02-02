//
//  StarMetricsCalculator.swift
//  Health Reporter
//
//  חישוב 5 מדדי הכוכב המייחדים את האפליקציה
//

import Foundation
import UIKit

final class StarMetricsCalculator {

    static let shared = StarMetricsCalculator()
    private init() {}

    /// מחשב את 5 מדדי הכוכב מתוך המדדים היומיים
    func calculateStarMetrics(from dailyMetrics: DailyMetrics, monthlyConsistency: Double? = nil) -> StarMetrics {
        return StarMetrics(
            nervousSystemBalance: dailyMetrics.nervousSystemBalance,
            recoveryDebt: dailyMetrics.recoveryDebt,
            energyForecast: dailyMetrics.energyForecast,
            workoutReadiness: dailyMetrics.workoutReadiness,
            consistencyScore: monthlyConsistency
        )
    }

    // MARK: - Star Metric Descriptions

    /// תיאור קצר למה המדד חשוב
    static func whyItMatters(for metricId: String) -> String {
        switch metricId {
        case "nervous_system_balance":
            return "star.nervous_system.why".localized
        case "recovery_debt":
            return "star.recovery_debt.why".localized
        case "energy_forecast":
            return "star.energy_forecast.why".localized
        case "workout_readiness":
            return "star.workout_readiness.why".localized
        case "consistency_score":
            return "star.consistency.why".localized
        default:
            return ""
        }
    }

    /// המלצת פעולה בהתבסס על ערך המדד
    static func actionAdvice(for metric: any InsightMetric) -> String {
        switch metric.id {
        case "nervous_system_balance":
            guard let value = metric.value else { return "" }
            if value >= 70 {
                return "star.nervous_system.action.high".localized
            } else if value >= 40 {
                return "star.nervous_system.action.medium".localized
            } else {
                return "star.nervous_system.action.low".localized
            }

        case "recovery_debt":
            guard let debt = metric as? RecoveryDebt, let value = debt.value else { return "" }
            if value > 10 {
                return "star.recovery_debt.action.surplus".localized
            } else if value < -10 {
                return "star.recovery_debt.action.deficit".localized
            } else {
                return "star.recovery_debt.action.balanced".localized
            }

        case "energy_forecast":
            guard let value = metric.value else { return "" }
            if value >= 70 {
                return "star.energy_forecast.action.high".localized
            } else if value >= 40 {
                return "star.energy_forecast.action.medium".localized
            } else {
                return "star.energy_forecast.action.low".localized
            }

        case "workout_readiness":
            guard let workout = metric as? WorkoutReadiness else { return "" }
            switch workout.readinessLevel {
            case .push: return "star.workout_readiness.action.push".localized
            case .full: return "star.workout_readiness.action.full".localized
            case .moderate: return "star.workout_readiness.action.moderate".localized
            case .light: return "star.workout_readiness.action.light".localized
            case .skip: return "star.workout_readiness.action.skip".localized
            }

        default:
            return ""
        }
    }

    // MARK: - Visual Helpers

    /// צבע עבור ערך המדד
    static func color(for metric: any InsightMetric) -> UIColor {
        guard let value = metric.value else { return AIONDesign.textSecondary }

        // Special handling for recovery debt
        if metric.id == "recovery_debt" {
            if value > 5 { return AIONDesign.accentSuccess }     // statusPositive
            if value < -5 { return AIONDesign.accentDanger }     // statusNegative
            return AIONDesign.accentWarning                       // statusNeutral
        }

        // Standard 0-100 scale
        switch value {
        case 0..<30: return AIONDesign.accentDanger              // statusNegative
        case 30..<60: return AIONDesign.accentWarning            // statusNeutral
        case 60..<80: return AIONDesign.accentSuccess            // statusPositive
        default: return AIONDesign.accentPrimary
        }
    }

    /// אייקון עבור המדד
    static func icon(for metricId: String) -> String {
        switch metricId {
        case "nervous_system_balance": return "waveform.path.ecg"
        case "recovery_debt": return "arrow.up.arrow.down.circle"
        case "energy_forecast": return "bolt.fill"
        case "workout_readiness": return "figure.strengthtraining.traditional"
        case "consistency_score": return "checkmark.seal"
        default: return "star.fill"
        }
    }
}
