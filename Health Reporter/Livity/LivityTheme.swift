//
//  LivityTheme.swift
//  Health Reporter
//
//  Design tokens for the Livity-inspired UI. Adapts to system light/dark mode:
//  - Light: cream background, soft pastel card tints, near-black text.
//  - Dark:  near-black background, deep jewel-tone card tints, near-white text.
//

import SwiftUI
import UIKit

private func livityColor(light: UIColor, dark: UIColor) -> Color {
    Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
}

private func rgb(_ r: Double, _ g: Double, _ b: Double) -> UIColor {
    UIColor(red: r, green: g, blue: b, alpha: 1)
}

enum LivityTheme {
    // MARK: - Surfaces
    static let background = livityColor(
        light: rgb(0.955, 0.955, 0.965),
        dark:  rgb(0.00,  0.00,  0.00)
    )
    static let cardFill = livityColor(
        light: rgb(0.965, 0.965, 0.970),
        dark:  rgb(0.09,  0.09,  0.10)
    )
    static let chipFill = livityColor(
        light: rgb(0.930, 0.930, 0.940),
        dark:  rgb(0.16,  0.16,  0.18)
    )

    // MARK: - Text
    static let textPrimary = livityColor(
        light: rgb(0.08, 0.08, 0.10),
        dark:  rgb(0.96, 0.96, 0.98)
    )
    static let textSecondary = livityColor(
        light: rgb(0.42, 0.42, 0.46),
        dark:  rgb(0.62, 0.62, 0.66)
    )
    static let textTertiary = livityColor(
        light: rgb(0.62, 0.62, 0.66),
        dark:  rgb(0.48, 0.48, 0.52)
    )

    // MARK: - Status tints (card backgrounds)
    static let goodTint = livityColor(
        light: rgb(0.85, 0.95, 0.87),
        dark:  rgb(0.04, 0.13, 0.07)
    )
    static let warningTint = livityColor(
        light: rgb(0.99, 0.92, 0.85),
        dark:  rgb(0.17, 0.10, 0.03)
    )
    static let badTint = livityColor(
        light: rgb(0.99, 0.90, 0.90),
        dark:  rgb(0.17, 0.05, 0.06)
    )
    static let infoTint = livityColor(
        light: rgb(0.87, 0.94, 0.99),
        dark:  rgb(0.04, 0.09, 0.18)
    )
    static let neutralTint = livityColor(
        light: rgb(0.92, 0.93, 0.96),
        dark:  rgb(0.10, 0.11, 0.14)
    )
    static let cautionTint = livityColor(
        light: rgb(1.00, 0.95, 0.78),
        dark:  rgb(0.17, 0.13, 0.02)
    )

    // MARK: - Accent colors (rings, numbers, icons — vivid in both modes)
    static let good = Color(red: 0.27, green: 0.78, blue: 0.38)               // #44C661 green
    static let warning = Color(red: 0.98, green: 0.58, blue: 0.22)            // #FA9438 orange
    static let caution = Color(red: 0.98, green: 0.78, blue: 0.13)            // #FAC721 golden yellow
    static let bad = Color(red: 0.95, green: 0.30, blue: 0.30)                // #F24D4D red
    static let info = Color(red: 0.22, green: 0.55, blue: 0.95)               // #3A8CF3 blue
    static let accent = Color(red: 0.22, green: 0.60, blue: 0.95)             // #3798F2 primary blue
    static let purple = Color(red: 0.56, green: 0.36, blue: 0.86)             // daylight purple

    // MARK: - Outlines
    static let separator = livityColor(
        light: rgb(0.85, 0.85, 0.87),
        dark:  rgb(0.22, 0.22, 0.25)
    )
    static let ringTrack = livityColor(
        light: rgb(0.86, 0.86, 0.88),
        dark:  rgb(0.22, 0.22, 0.25)
    )

    // MARK: - Layout
    static let cardRadius: CGFloat = 20
    static let cardInnerRadius: CGFloat = 14
    static let horizontalPadding: CGFloat = 16
    static let cardSpacing: CGFloat = 12
    static let cardPadding: CGFloat = 16
}

// MARK: - UIKit bridge

/// UIColor counterparts of every adaptive `LivityTheme` token, for use from UIKit
/// view controllers that haven't been migrated to SwiftUI yet. They share the same
/// dark/light adaptation logic so screens look consistent across the codebase.
enum LivityUIColor {
    static let background    = adaptive(light: rgb(0.955, 0.955, 0.965), dark: rgb(0.00, 0.00, 0.00))
    static let cardFill      = adaptive(light: rgb(0.965, 0.965, 0.970), dark: rgb(0.09, 0.09, 0.10))
    static let chipFill      = adaptive(light: rgb(0.930, 0.930, 0.940), dark: rgb(0.16, 0.16, 0.18))
    static let textPrimary   = adaptive(light: rgb(0.08, 0.08, 0.10),    dark: rgb(0.96, 0.96, 0.98))
    static let textSecondary = adaptive(light: rgb(0.42, 0.42, 0.46),    dark: rgb(0.62, 0.62, 0.66))
    static let textTertiary  = adaptive(light: rgb(0.62, 0.62, 0.66),    dark: rgb(0.48, 0.48, 0.52))
    static let separator     = adaptive(light: rgb(0.85, 0.85, 0.87),    dark: rgb(0.22, 0.22, 0.25))
    static let info          = UIColor(red: 0.22, green: 0.55, blue: 0.95, alpha: 1)
    static let good          = UIColor(red: 0.27, green: 0.78, blue: 0.38, alpha: 1)
    static let warning       = UIColor(red: 0.98, green: 0.58, blue: 0.22, alpha: 1)
    static let bad           = UIColor(red: 0.95, green: 0.30, blue: 0.30, alpha: 1)
    static let caution       = UIColor(red: 0.98, green: 0.78, blue: 0.13, alpha: 1)
    static let purple        = UIColor(red: 0.56, green: 0.36, blue: 0.86, alpha: 1)

    // Soft status tints used as card backgrounds — UIKit mirror of the SwiftUI
    // tint constants on LivityTheme, so legacy UIViewControllers can paint
    // cards in the same pastel language as the SwiftUI surfaces.
    static let infoTint      = adaptive(light: rgb(0.87, 0.94, 0.99), dark: rgb(0.04, 0.09, 0.18))
    static let goodTint      = adaptive(light: rgb(0.85, 0.95, 0.87), dark: rgb(0.04, 0.13, 0.07))
    static let warningTint   = adaptive(light: rgb(0.99, 0.92, 0.85), dark: rgb(0.17, 0.10, 0.03))
    static let badTint       = adaptive(light: rgb(0.99, 0.90, 0.90), dark: rgb(0.17, 0.05, 0.06))
    static let neutralTint   = adaptive(light: rgb(0.92, 0.93, 0.96), dark: rgb(0.10, 0.11, 0.14))
    static let cautionTint   = adaptive(light: rgb(1.00, 0.95, 0.78), dark: rgb(0.17, 0.13, 0.02))
    static let purpleTint    = adaptive(light: rgb(0.93, 0.90, 0.99), dark: rgb(0.10, 0.06, 0.18))

    private static func adaptive(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? dark : light }
    }
}

// MARK: - Status enum for coloring cards

enum LivityStatus {
    case good, warning, bad, info, neutral

    var tint: Color {
        switch self {
        case .good: return LivityTheme.goodTint
        case .warning: return LivityTheme.warningTint
        case .bad: return LivityTheme.badTint
        case .info: return LivityTheme.infoTint
        case .neutral: return LivityTheme.neutralTint
        }
    }

    var accent: Color {
        switch self {
        case .good: return LivityTheme.good
        case .warning: return LivityTheme.warning
        case .bad: return LivityTheme.bad
        case .info: return LivityTheme.info
        case .neutral: return LivityTheme.textSecondary
        }
    }
}

// MARK: - Typography

extension Font {
    static let livityLargeNumber = Font.system(size: 44, weight: .bold, design: .default)
    static let livityCardNumber = Font.system(size: 34, weight: .bold, design: .default)
    static let livityCardTitle = Font.system(size: 13, weight: .semibold, design: .default)
    static let livitySectionTitle = Font.system(size: 12, weight: .semibold, design: .default)
    static let livityCaption = Font.system(size: 12, weight: .medium, design: .default)
    static let livityBody = Font.system(size: 15, weight: .regular, design: .default)
    static let livityButton = Font.system(size: 16, weight: .semibold, design: .default)
    static let livityChip = Font.system(size: 13, weight: .medium, design: .default)
}
