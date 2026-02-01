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
    static let cornerRadiusSmall: CGFloat = 8
    static let spacing: CGFloat = 12
    static let spacingLarge: CGFloat = 20
    static let spacingSmall: CGFloat = 8

    // MARK: - Glass Morphism
    static var glassBlurStyle: UIBlurEffect.Style {
        BackgroundColor.current.isLight ? .systemUltraThinMaterialLight : .systemUltraThinMaterialDark
    }
    static let glassTintAlpha: CGFloat = 0.08
    static let glassBorderAlpha: CGFloat = 0.2

    // MARK: - Shadows
    struct ShadowStyle {
        let color: UIColor
        let offset: CGSize
        let radius: CGFloat
        let opacity: Float

        static let small = ShadowStyle(color: .black, offset: CGSize(width: 0, height: 2), radius: 4, opacity: 0.1)
        static let medium = ShadowStyle(color: .black, offset: CGSize(width: 0, height: 4), radius: 12, opacity: 0.15)
        static let large = ShadowStyle(color: .black, offset: CGSize(width: 0, height: 8), radius: 24, opacity: 0.2)
        static let glow = ShadowStyle(color: accentPrimary, offset: .zero, radius: 15, opacity: 0.4)
    }

    // MARK: - Gradients
    static let primaryGradient: [CGColor] = [accentPrimary.cgColor, accentSecondary.cgColor]
    static let successGradient: [CGColor] = [accentSecondary.cgColor, accentSuccess.cgColor]
    static let celebrationGradient: [CGColor] = [accentPrimary.cgColor, accentSecondary.cgColor, accentSuccess.cgColor]
    static let goldGradient: [CGColor] = [UIColor(hex: "#FFD700")!.cgColor, UIColor(hex: "#FFA500")!.cgColor]
    static let silverGradient: [CGColor] = [UIColor(hex: "#C0C0C0")!.cgColor, UIColor(hex: "#A8A8A8")!.cgColor]
    static let bronzeGradient: [CGColor] = [UIColor(hex: "#CD7F32")!.cgColor, UIColor(hex: "#8B4513")!.cgColor]

    // MARK: - Animation Durations
    static let animationFast: TimeInterval = 0.2
    static let animationMedium: TimeInterval = 0.35
    static let animationSlow: TimeInterval = 0.6

    // MARK: - Spring Animation
    static let springDamping: CGFloat = 0.7
    static let springVelocity: CGFloat = 0.5
    static let springDampingBouncy: CGFloat = 0.5

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

    /// פסקה עם יישור דינמי לפי שפה
    static func localizedParagraphStyle() -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        let isRTL = LocalizationManager.shared.currentLanguage.isRTL
        p.alignment = isRTL ? .right : .left
        p.baseWritingDirection = isRTL ? .rightToLeft : .leftToRight
        return p
    }

    /// מייצר NSAttributedString עם יישור דינמי לפי שפה
    static func attributedStringRTL(_ text: String, font: UIFont = .systemFont(ofSize: 15, weight: .regular), color: UIColor? = nil) -> NSAttributedString {
        let c = color ?? textPrimary
        return NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: c,
                .paragraphStyle: localizedParagraphStyle()
            ]
        )
    }
}

// MARK: - UIView Shadow Extension

extension UIView {
    func applyShadow(_ style: AIONDesign.ShadowStyle) {
        layer.shadowColor = style.color.cgColor
        layer.shadowOffset = style.offset
        layer.shadowRadius = style.radius
        layer.shadowOpacity = style.opacity
        layer.masksToBounds = false
    }

    func applyGlowEffect(color: UIColor = AIONDesign.accentPrimary, radius: CGFloat = 15, opacity: Float = 0.4) {
        layer.shadowColor = color.cgColor
        layer.shadowOffset = .zero
        layer.shadowRadius = radius
        layer.shadowOpacity = opacity
        layer.masksToBounds = false
    }

    func addGradientBorder(colors: [UIColor], width: CGFloat = 2, cornerRadius: CGFloat? = nil) {
        let gradient = CAGradientLayer()
        gradient.frame = bounds
        gradient.colors = colors.map { $0.cgColor }
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)

        let shape = CAShapeLayer()
        let radius = cornerRadius ?? layer.cornerRadius
        shape.lineWidth = width
        shape.path = UIBezierPath(roundedRect: bounds.insetBy(dx: width/2, dy: width/2), cornerRadius: radius).cgPath
        shape.strokeColor = UIColor.black.cgColor
        shape.fillColor = UIColor.clear.cgColor
        gradient.mask = shape

        layer.sublayers?.removeAll { $0.name == "gradientBorder" }
        gradient.name = "gradientBorder"
        layer.addSublayer(gradient)
    }

    func pulseAnimation(scale: CGFloat = 1.05, duration: TimeInterval = 0.15) {
        UIView.animate(withDuration: duration, animations: {
            self.transform = CGAffineTransform(scaleX: scale, y: scale)
        }) { _ in
            UIView.animate(withDuration: duration) {
                self.transform = .identity
            }
        }
    }

    func springAnimation(scale: CGFloat = 0.96, completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.1, animations: {
            self.transform = CGAffineTransform(scaleX: scale, y: scale)
        }) { _ in
            UIView.animate(
                withDuration: 0.3,
                delay: 0,
                usingSpringWithDamping: AIONDesign.springDampingBouncy,
                initialSpringVelocity: AIONDesign.springVelocity,
                options: [],
                animations: {
                    self.transform = .identity
                },
                completion: { _ in completion?() }
            )
        }
    }
}
