//
//  HealthTier.swift
//  Health Reporter
//
//  Minimal tier mapping — score (0-100) to visual tier (emoji, color, label).
//  Car name & score always come from Gemini. This only provides the visual tier.
//

import UIKit

struct HealthTier {
    let emoji: String
    let tierLabel: String   // Localized tier label
    let tierIndex: Int      // 0-4
    let color: UIColor
    let imageName: String   // Asset catalog image name

    // MARK: - 5 Tier Levels

    private static var allTiers: [HealthTier] {
        [
            HealthTier(emoji: "🚙", tierLabel: "insights.needsAttention".localized, tierIndex: 0, color: AIONDesign.accentDanger,    imageName: "CarFiatPanda"),
            HealthTier(emoji: "🚗", tierLabel: "insights.okay".localized,           tierIndex: 1, color: AIONDesign.accentWarning,   imageName: "CarToyotaCorolla"),
            HealthTier(emoji: "🏎️", tierLabel: "insights.goodCondition".localized,  tierIndex: 2, color: AIONDesign.accentPrimary,   imageName: "CarBMWM3"),
            HealthTier(emoji: "🏎️", tierLabel: "insights.excellent".localized,      tierIndex: 3, color: AIONDesign.accentSecondary, imageName: "CarPorsche911"),
            HealthTier(emoji: "🏎️", tierLabel: "insights.peakPerformance".localized,tierIndex: 4, color: AIONDesign.accentSuccess,   imageName: "CarFerrariSF90"),
        ]
    }

    /// Map a health/car score (0-100) to a visual tier.
    static func forScore(_ score: Int) -> HealthTier {
        switch score {
        case 0..<25:  return allTiers[0]
        case 25..<45: return allTiers[1]
        case 45..<65: return allTiers[2]
        case 65..<82: return allTiers[3]
        default:      return allTiers[4]
        }
    }

    /// Lookup tier by index (0-4). Returns nil for out-of-range.
    static func forIndex(_ index: Int) -> HealthTier? {
        guard allTiers.indices.contains(index) else { return nil }
        return allTiers[index]
    }
}
