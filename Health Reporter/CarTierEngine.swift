//
//  CarTierEngine.swift
//  Health Reporter
//
//  Deterministic car tier engine – maps a calculated health score to a fixed car.
//  The car changes only when the tier changes, not on every refresh.
//

import UIKit

struct CarTier {
    let name: String        // English car name
    let emoji: String       // Car-related emoji
    let tierLabel: String   // Hebrew tier label
    let tierIndex: Int      // 0-4 for gauge positioning
    let color: UIColor      // Color for the tier
    let imageName: String   // Asset catalog image name
}

enum CarTierEngine {

    // MARK: - 5 Tier Levels

    static var tiers: [CarTier] {
        [
            CarTier(name: "Fiat Panda",               emoji: "🚙", tierLabel: "insights.needsAttention".localized, tierIndex: 0, color: AIONDesign.accentDanger,    imageName: "CarFiatPanda"),
            CarTier(name: "Toyota Corolla",            emoji: "🚗", tierLabel: "insights.okay".localized,           tierIndex: 1, color: AIONDesign.accentWarning,   imageName: "CarToyotaCorolla"),
            CarTier(name: "BMW M3",                    emoji: "🏎️", tierLabel: "insights.goodCondition".localized,  tierIndex: 2, color: AIONDesign.accentPrimary,   imageName: "CarBMWM3"),
            CarTier(name: "Porsche 911 Turbo",         emoji: "🏎️", tierLabel: "insights.excellent".localized,      tierIndex: 3, color: AIONDesign.accentSecondary, imageName: "CarPorsche911"),
            CarTier(name: "Ferrari SF90 Stradale",     emoji: "🏎️", tierLabel: "insights.peakPerformance".localized,tierIndex: 4, color: AIONDesign.accentSuccess,   imageName: "CarFerrariSF90"),
        ]
    }

    /// Calculate composite health score (0-100) from available metrics.
    /// Weights: readiness 40%, sleep 25%, HRV 20%, strain balance 15%.
    static func computeHealthScore(
        readinessAvg: Double?,
        sleepHoursAvg: Double?,
        hrvAvg: Double?,
        strainAvg: Double?
    ) -> Int {
        var total: Double = 0
        var weightSum: Double = 0

        if let r = readinessAvg {
            total += min(100, max(0, r)) * 0.40
            weightSum += 0.40
        }
        if let s = sleepHoursAvg {
            let sleepScore: Double
            if s >= 7.5      { sleepScore = 100 }
            else if s >= 7.0 { sleepScore = 85 }
            else if s >= 6.0 { sleepScore = 60 }
            else if s >= 5.0 { sleepScore = 35 }
            else             { sleepScore = 15 }
            total += sleepScore * 0.25
            weightSum += 0.25
        }
        if let h = hrvAvg {
            // HRV in ms – typical range 20-80; normalize to 0-100
            let normalized = min(100, max(0, (h - 10) * (100.0 / 70.0)))
            total += normalized * 0.20
            weightSum += 0.20
        }
        if let st = strainAvg {
            // Moderate strain (3-6) is optimal
            let strainScore: Double
            if st >= 3 && st <= 6      { strainScore = 85 }
            else if st >= 2 && st <= 7 { strainScore = 65 }
            else                       { strainScore = 40 }
            total += strainScore * 0.15
            weightSum += 0.15
        }

        guard weightSum > 0 else { return 0 } // No data = score 0 (will show "--")
        let score = total / weightSum
        return Int(round(max(0, min(100, score))))
    }

    /// Map score to tier
    static func tierForScore(_ score: Int) -> CarTier {
        switch score {
        case 0..<25:  return tiers[0]
        case 25..<45: return tiers[1]
        case 45..<65: return tiers[2]
        case 65..<82: return tiers[3]
        default:      return tiers[4]
        }
    }

    /// Hash for detecting tier changes (for cache invalidation)
    static func tierHash(score: Int) -> String {
        "tier_\(tierForScore(score).tierIndex)"
    }

    /// Calculate score + tier from chart data. Returns nil if no real data exists.
    static func evaluate(bundle: AIONChartDataBundle) -> (score: Int, tier: CarTier)? {
        guard bundle.hasRealData else { return nil }

        let n = bundle.range.dayCount
        let readinessPoints = Array(bundle.readiness.points.suffix(n))
        let hrvPoints = Array(bundle.hrvTrend.points.suffix(n))
        let sleepPoints = Array(bundle.sleep.points.suffix(n)).filter { ($0.totalHours ?? 0) > 0 }

        let readinessAvg: Double? = readinessPoints.isEmpty ? nil :
            readinessPoints.map(\.recovery).reduce(0, +) / Double(readinessPoints.count)

        let sleepAvg: Double? = sleepPoints.isEmpty ? nil :
            sleepPoints.compactMap(\.totalHours).reduce(0, +) / Double(sleepPoints.count)

        let hrvAvg: Double? = hrvPoints.isEmpty ? nil :
            hrvPoints.map(\.value).reduce(0, +) / Double(hrvPoints.count)

        let strainAvg: Double? = readinessPoints.isEmpty ? nil :
            readinessPoints.map(\.strain).reduce(0, +) / Double(readinessPoints.count)

        let score = computeHealthScore(
            readinessAvg: readinessAvg,
            sleepHoursAvg: sleepAvg,
            hrvAvg: hrvAvg,
            strainAvg: strainAvg
        )
        return (score, tierForScore(score))
    }

    // MARK: - New Engine Integration

    /// Calculate score + tier using the new HealthScoreEngine.
    /// Also returns the detailed result for debugging/UI.
    static func evaluateWithNewEngine(entries: [RawDailyHealthEntry]) -> (score: Int, tier: CarTier, result: HealthScoringResult)? {
        guard !entries.isEmpty else { return nil }

        let result = HealthScoreEngine.shared.calculate(from: entries)
        let score = result.healthScoreInt
        let tier = tierForScore(score)

        return (score, tier, result)
    }
}
