//
//  AppColors.swift
//  Health Reporter
//
//  Color palette matching the app logo: blue → teal → lime green gradient.
//

import UIKit

enum AppColors {
    // MARK: - Logo palette (gradient: blue bottom → teal → lime top)
    static let logoBlue = UIColor(hex: "#00BFFF")!   // Deep Sky Blue
    static let logoTeal = UIColor(hex: "#00CED1")!   // Dark Turquoise
    static let logoLime = UIColor(hex: "#7FFF00")!   // Chartreuse

    // MARK: - Surfaces (dark background matching logo)
    static let backgroundDeepCharcoal = UIColor(hex: "#121212")!
    static let surfaceCard = UIColor(hex: "#1E1E1E")!

    // MARK: - Semantic accents
    static let primaryAccent = logoLime
    static let secondaryAccent = logoTeal
    static let warningCrimson = UIColor(hex: "#E53935")!

    // MARK: - Text & borders
    static let textPrimary = UIColor(hex: "#FFFFFF")!
    static let textSecondary = UIColor(hex: "#A0A0A0")!
    static let borderOverlay = UIColor.white.withAlphaComponent(0.1)
    static let glassmorphism = UIColor.white.withAlphaComponent(0.05)

    // MARK: - Layout
    static let borderRadius: CGFloat = 16
    static let spacingUnit: CGFloat = 8

    /// Header gradient colors (top → bottom): lime → teal → blue
    static var headerGradientColors: [CGColor] {
        [logoLime.cgColor, logoTeal.cgColor, logoBlue.cgColor]
    }
}
