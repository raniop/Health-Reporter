//
//  AIONDesign.swift
//  Health Reporter
//
//  ערכת עיצוב – AION Performance Lab. תומך Light + Dark.
//

import UIKit

enum AIONDesign {
    // MARK: - Surfaces (dynamic)
    static let background = UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(hex: "#1C1C1E")! : UIColor(hex: "#F8F6F3")!
    }
    static let surface = UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(hex: "#2C2C2E")! : UIColor(hex: "#FFFFFF")!
    }
    static let surfaceElevated = UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(hex: "#3A3A3C")! : UIColor(hex: "#FFFFFF")!
    }
    static let separator = UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(hex: "#48484A")! : UIColor(hex: "#E8E4DE")!
    }

    // MARK: - Text (dynamic)
    static let textPrimary = UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(hex: "#FFFFFF")! : UIColor(hex: "#1A1A1A")!
    }
    static let textSecondary = UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(hex: "#EBEBF5")!.withAlphaComponent(0.6) : UIColor(hex: "#6B6560")!
    }
    static let textTertiary = UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(hex: "#EBEBF5")!.withAlphaComponent(0.4) : UIColor(hex: "#9C958E")!
    }

    // MARK: - Accents (נראים טוב בשניהם)
    static let accentPrimary = UIColor(hex: "#E85D04")!
    static let accentSecondary = UIColor(hex: "#0D7EA7")!
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

    /// מחזיר צבע בהתאם ל־trait collection של ה־view (לשימוש ב־layout)
    static func resolveBackground(_ trait: UITraitCollection) -> UIColor {
        background.resolvedColor(with: trait)
    }
    static func resolveSurface(_ trait: UITraitCollection) -> UIColor {
        surface.resolvedColor(with: trait)
    }
    static func resolveTextPrimary(_ trait: UITraitCollection) -> UIColor {
        textPrimary.resolvedColor(with: trait)
    }
    static func resolveTextSecondary(_ trait: UITraitCollection) -> UIColor {
        textSecondary.resolvedColor(with: trait)
    }
    static func resolveTextTertiary(_ trait: UITraitCollection) -> UIColor {
        textTertiary.resolvedColor(with: trait)
    }
    static func resolveSeparator(_ trait: UITraitCollection) -> UIColor {
        separator.resolvedColor(with: trait)
    }

    /// פסקה RTL לעברית – יישור לימין, כיוון כתיבה מימין לשמאל
    static func rtlParagraphStyle() -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.alignment = .right
        p.baseWritingDirection = .rightToLeft
        return p
    }

    /// מייצר NSAttributedString עם יישור עברית RTL
    static func attributedStringRTL(_ text: String, font: UIFont = .systemFont(ofSize: 15, weight: .regular), color: UIColor? = nil) -> NSAttributedString {
        let c = color ?? textPrimary
        return NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: c,
                .paragraphStyle: rtlParagraphStyle()
            ]
        )
    }
}
