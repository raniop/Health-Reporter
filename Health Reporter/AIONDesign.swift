//
//  AIONDesign.swift
//  Health Reporter
//
//  ערכת עיצוב חדשה לגמרי – AION Performance Lab.
//  Light mode, warm neutrals, bold typography.
//

import UIKit

enum AIONDesign {
    // MARK: - Surfaces
    static let background = UIColor(hex: "#F8F6F3")!
    static let surface = UIColor(hex: "#FFFFFF")!
    static let surfaceElevated = UIColor(hex: "#FFFFFF")!
    static let separator = UIColor(hex: "#E8E4DE")!

    // MARK: - Text
    static let textPrimary = UIColor(hex: "#1A1A1A")!
    static let textSecondary = UIColor(hex: "#6B6560")!
    static let textTertiary = UIColor(hex: "#9C958E")!

    // MARK: - Accents (Pro Lab)
    static let accentPrimary = UIColor(hex: "#E85D04")!   // Warm orange
    static let accentSecondary = UIColor(hex: "#0D7EA7")! // Teal blue
    static let accentSuccess = UIColor(hex: "#2D6A4F")!
    static let accentWarning = UIColor(hex: "#CA6702")!
    static let accentDanger = UIColor(hex: "#9D0208")!

    // MARK: - Chart colors
    static let chartRecovery = UIColor(hex: "#0D7EA7")!
    static let chartStrain = UIColor(hex: "#E85D04")!
    static let chartSleep = UIColor(hex: "#5C4D7D")!
    static let chartGlucose = UIColor(hex: "#CA6702")!

    // MARK: - Layout
    static let cornerRadius: CGFloat = 14
    static let cornerRadiusLarge: CGFloat = 20
    static let spacing: CGFloat = 12
    static let spacingLarge: CGFloat = 20

    // MARK: - Typography
    static func titleFont() -> UIFont { .systemFont(ofSize: 22, weight: .bold) }
    static func headlineFont() -> UIFont { .systemFont(ofSize: 17, weight: .semibold) }
    static func bodyFont() -> UIFont { .systemFont(ofSize: 15, weight: .regular) }
    static func captionFont() -> UIFont { .systemFont(ofSize: 12, weight: .medium) }
}
