//
//  AppColors.swift
//  Health Reporter
//
//  Color palette matching the glassmorphism design: cyan → teal → lime accents.
//

import UIKit

enum AppColors {
    // MARK: - Logo palette (gradient: blue → teal → lime)
    static let logoBlue = UIColor(hex: "#00BFFF")!   // Deep Sky Blue
    static let logoTeal = UIColor(hex: "#00CED1")!   // Dark Turquoise
    static let logoLime = UIColor(hex: "#7FFF00")!   // Chartreuse

    // MARK: - Surfaces (dark teal background)
    static let backgroundDeepCharcoal = UIColor(hex: "#0A2A3C")!
    static let surfaceCard = UIColor.white.withAlphaComponent(0.15)

    // MARK: - Semantic accents
    static let primaryAccent = UIColor(hex: "#00BFFF")!
    static let secondaryAccent = UIColor(hex: "#00CED1")!
    static let warningCrimson = UIColor(hex: "#EF4444")!

    // MARK: - Text & borders
    static let textPrimary = UIColor.white
    static let textSecondary = UIColor.white.withAlphaComponent(0.7)
    static let borderOverlay = UIColor.white.withAlphaComponent(0.2)
    static let glassmorphism = UIColor.white.withAlphaComponent(0.12)

    // MARK: - Layout
    static let borderRadius: CGFloat = 16
    static let spacingUnit: CGFloat = 8

    /// Header gradient colors (top → bottom): teal → cyan → light teal
    static var headerGradientColors: [CGColor] {
        [UIColor(hex: "#0D3B52")!.cgColor, UIColor(hex: "#0E6E78")!.cgColor, UIColor(hex: "#14998D")!.cgColor]
    }
}
