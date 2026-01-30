//
//  AIONDesign.swift
//  Health Reporter
//
//  ערכת עיצוב – Pro Lab / Synthesis. תמיד כהה, צבעי לוגו (ציאן/טורקיז/ירוק).
//

import UIKit

// MARK: - Background Colors

private let kBackgroundColorKey = "AION.BackgroundColor"

enum BackgroundColor: String, CaseIterable {
    case midnight = "#0D0D0F"      // ברירת מחדל - שחור כהה
    case charcoal = "#1A1A1D"      // אפור כהה
    case navy = "#0A1628"          // כחול כהה
    case forest = "#0D1A14"        // ירוק כהה
    case wine = "#1A0D14"          // בורדו כהה
    case slate = "#1C1F26"         // אפור-כחול
    case light = "#F5F5F7"         // רקע בהיר/לבן

    var color: UIColor {
        UIColor(hex: rawValue)!
    }

    var displayName: String {
        switch self {
        case .midnight: return "לילה"
        case .charcoal: return "פחם"
        case .navy: return "כחול עמוק"
        case .forest: return "יער"
        case .wine: return "יין"
        case .slate: return "צפחה"
        case .light: return "בהיר"
        }
    }

    /// האם זה רקע בהיר (דורש טקסט כהה)
    var isLight: Bool {
        self == .light
    }

    static var current: BackgroundColor {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: kBackgroundColorKey),
                  let color = BackgroundColor(rawValue: rawValue) else {
                return .midnight
            }
            return color
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: kBackgroundColorKey)
        }
    }
}

enum AIONDesign {
    // MARK: - Surfaces (דינמי לפי רקע בהיר/כהה)
    static var background: UIColor {
        BackgroundColor.current.color
    }
    static var surface: UIColor {
        BackgroundColor.current.isLight
            ? UIColor(hex: "#FFFFFF")!
            : UIColor(hex: "#1C1C1E")!
    }
    static var surfaceElevated: UIColor {
        BackgroundColor.current.isLight
            ? UIColor(hex: "#F0F0F2")!
            : UIColor(hex: "#252528")!
    }
    static var separator: UIColor {
        BackgroundColor.current.isLight
            ? UIColor(hex: "#C6C6C8")!
            : UIColor(hex: "#3A3A3C")!
    }

    // MARK: - Navigation Bar Style
    static var navBarStyle: UIBarStyle {
        BackgroundColor.current.isLight ? .default : .black
    }

    // MARK: - Text (דינמי לפי רקע בהיר/כהה)
    static var textPrimary: UIColor {
        BackgroundColor.current.isLight
            ? UIColor(hex: "#000000")!
            : UIColor(hex: "#FFFFFF")!
    }
    static var textSecondary: UIColor {
        BackgroundColor.current.isLight
            ? UIColor(hex: "#3C3C43")!.withAlphaComponent(0.6)
            : UIColor(hex: "#EBEBF5")!.withAlphaComponent(0.65)
    }
    static var textTertiary: UIColor {
        BackgroundColor.current.isLight
            ? UIColor(hex: "#3C3C43")!.withAlphaComponent(0.3)
            : UIColor(hex: "#EBEBF5")!.withAlphaComponent(0.45)
    }

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
