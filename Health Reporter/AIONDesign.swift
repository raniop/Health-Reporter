//
//  AIONDesign.swift
//  Health Reporter
//
//  ערכת עיצוב – Pro Lab / Synthesis. תמיד כהה, צבעי לוגו (ציאן/טורקיז/ירוק).
//

import UIKit

enum AIONDesign {
    // MARK: - Surfaces (dark-only, כמו התמונות)
    static let background = UIColor(hex: "#0D0D0F")!
    static let surface = UIColor(hex: "#1C1C1E")!
    static let surfaceElevated = UIColor(hex: "#252528")!
    static let separator = UIColor(hex: "#3A3A3C")!

    // MARK: - Text
    static let textPrimary = UIColor(hex: "#FFFFFF")!
    static let textSecondary = UIColor(hex: "#EBEBF5")!.withAlphaComponent(0.65)
    static let textTertiary = UIColor(hex: "#EBEBF5")!.withAlphaComponent(0.45)

    // MARK: - Accents (גרדיאנט הלוגו: ירוק ליים → טורקיז → ציאן)
    static let accentPrimary = UIColor(hex: "#00B4D8")!   // ציאן – מרכז הלוגו
    static let accentSecondary = UIColor(hex: "#00C9A7")! // טורקיז
    static let accentSuccess = UIColor(hex: "#7BED9F")!   // ירוק ליים – עלה/צמיחה
    static let accentWarning = UIColor(hex: "#CA6702")!
    static let accentDanger = UIColor(hex: "#9D0208")!

    // MARK: - Chart colors (בהתאמה ללוגו)
    static let chartRecovery = UIColor(hex: "#00B4D8")!
    static let chartStrain = UIColor(hex: "#00C9A7")!
    static let chartSleep = UIColor(hex: "#5C4D7D")!
    static let chartGlucose = UIColor(hex: "#7BED9F")!

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

    static func resolveBackground(_ trait: UITraitCollection) -> UIColor { background }
    static func resolveSurface(_ trait: UITraitCollection) -> UIColor { surface }
    static func resolveTextPrimary(_ trait: UITraitCollection) -> UIColor { textPrimary }
    static func resolveTextSecondary(_ trait: UITraitCollection) -> UIColor { textSecondary }
    static func resolveTextTertiary(_ trait: UITraitCollection) -> UIColor { textTertiary }
    static func resolveSeparator(_ trait: UITraitCollection) -> UIColor { separator }

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
