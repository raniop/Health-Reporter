//
//  AIONDesign.swift
//  Health Reporter
//
//  Design system – Glassmorphism: cyan/teal background, frosted-glass cards, orange accents.
//

import UIKit

// MARK: - Background Colors

private let kBackgroundColorKey = "AION.BackgroundColor"

enum BackgroundColor: String, CaseIterable {
    case midnight = "#0A2A3C"      // Default - deep dark teal
    case charcoal = "#0D3B52"      // Medium dark teal
    case navy = "#071E30"          // Very dark navy
    case forest = "#0E4D5C"        // Dark cyan
    case wine = "#1A3045"          // Dark blue-grey
    case slate = "#0B3348"         // Dark teal-blue
    case light = "#E0F7FA"         // Light cyan

    var color: UIColor {
        UIColor(hex: rawValue)!
    }

    var displayName: String {
        switch self {
        case .midnight: return "Teal"
        case .charcoal: return "Ocean"
        case .navy: return "Navy"
        case .forest: return "Cyan"
        case .wine: return "Deep Blue"
        case .slate: return "Blue Teal"
        case .light: return "Light"
        }
    }

    /// Whether this is a light background (requires dark text)
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
    // MARK: - Surfaces (dynamic based on light/dark background)
    static var background: UIColor {
        BackgroundColor.current.color
    }
    /// Gradient background colors for views (top to bottom)
    static var backgroundGradientColors: [CGColor] {
        BackgroundColor.current.isLight
            ? [UIColor(hex: "#E0F7FA")!.cgColor, UIColor(hex: "#B2EBF2")!.cgColor]
            : [UIColor(hex: "#0D3B52")!.cgColor, UIColor(hex: "#0E6E78")!.cgColor, UIColor(hex: "#14998D")!.cgColor]
    }
    static var surface: UIColor {
        BackgroundColor.current.isLight
            ? UIColor.white.withAlphaComponent(0.6)
            : UIColor.white.withAlphaComponent(0.08)
    }
    static var surfaceElevated: UIColor {
        BackgroundColor.current.isLight
            ? UIColor.white.withAlphaComponent(0.75)
            : UIColor.white.withAlphaComponent(0.12)
    }
    static var separator: UIColor {
        BackgroundColor.current.isLight
            ? UIColor(hex: "#C6C6C8")!
            : UIColor.white.withAlphaComponent(0.15)
    }

    // MARK: - Navigation Bar Style
    static var navBarStyle: UIBarStyle {
        BackgroundColor.current.isLight ? .default : .black
    }

    // MARK: - Text (dynamic based on light/dark background)
    static var textPrimary: UIColor {
        BackgroundColor.current.isLight
            ? UIColor(hex: "#0A2A3C")!
            : UIColor.white
    }
    static var textSecondary: UIColor {
        BackgroundColor.current.isLight
            ? UIColor(hex: "#1A4A5E")!.withAlphaComponent(0.7)
            : UIColor.white.withAlphaComponent(0.7)
    }
    static var textTertiary: UIColor {
        BackgroundColor.current.isLight
            ? UIColor(hex: "#1A4A5E")!.withAlphaComponent(0.4)
            : UIColor.white.withAlphaComponent(0.45)
    }

    // MARK: - Accents (cyan/teal/lime logo theme)
    static let accentPrimary = UIColor(hex: "#00BFFF")!   // Deep Sky Blue – logo cyan
    static let accentSecondary = UIColor(hex: "#00CED1")!  // Dark Turquoise – logo teal
    static let accentSuccess = UIColor(hex: "#7FFF00")!    // Chartreuse – logo lime
    static let accentWarning = UIColor(hex: "#FF6B35")!    // Orange
    static let accentDanger = UIColor(hex: "#EF4444")!

    // MARK: - Chart colors
    static let chartRecovery = UIColor(hex: "#00BFFF")!
    static let chartStrain = UIColor(hex: "#00CED1")!
    static let chartSleep = UIColor(hex: "#36D1DC")!
    static let chartGlucose = UIColor(hex: "#7FFF00")!

    // MARK: - Layout
    static let cornerRadius: CGFloat = 16
    static let cornerRadiusLarge: CGFloat = 24
    static let cornerRadiusSmall: CGFloat = 10
    static let spacing: CGFloat = 12
    static let spacingLarge: CGFloat = 20
    static let spacingSmall: CGFloat = 8

    // MARK: - Glass Morphism
    static var glassBlurStyle: UIBlurEffect.Style {
        .light   // Always light – avoids dark/black tint on dark backgrounds
    }
    /// Alpha for the blur view itself (lower = more transparent glass)
    static let glassBlurAlpha: CGFloat = 0.35
    static let glassTintAlpha: CGFloat = 0.04
    static let glassBorderAlpha: CGFloat = 0.2
    /// Glass card background: clear – the blur handles the frosted look
    static var glassCardBackground: UIColor {
        .clear
    }
    /// Glass card border color – thin and subtle
    static var glassCardBorder: UIColor {
        UIColor.white.withAlphaComponent(0.2)
    }

    // MARK: - Shadows
    struct ShadowStyle {
        let color: UIColor
        let offset: CGSize
        let radius: CGFloat
        let opacity: Float

        static let small = ShadowStyle(color: UIColor(hex: "#0A2A3C")!, offset: CGSize(width: 0, height: 2), radius: 8, opacity: 0.15)
        static let medium = ShadowStyle(color: UIColor(hex: "#0A2A3C")!, offset: CGSize(width: 0, height: 4), radius: 16, opacity: 0.2)
        static let large = ShadowStyle(color: UIColor(hex: "#0A2A3C")!, offset: CGSize(width: 0, height: 8), radius: 24, opacity: 0.25)
        static let glow = ShadowStyle(color: accentPrimary, offset: .zero, radius: 20, opacity: 0.35)
    }

    // MARK: - Gradients
    static let primaryGradient: [CGColor] = [accentPrimary.cgColor, accentSecondary.cgColor]
    static let successGradient: [CGColor] = [accentSuccess.cgColor, UIColor(hex: "#66CC00")!.cgColor]
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

    /// Paragraph with dynamic alignment based on language
    static func localizedParagraphStyle() -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        let isRTL = LocalizationManager.shared.currentLanguage.isRTL
        p.alignment = isRTL ? .right : .left
        p.baseWritingDirection = isRTL ? .rightToLeft : .leftToRight
        return p
    }

    /// Creates an NSAttributedString with dynamic alignment based on language
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

// MARK: - Gradient Background View (auto-resizing)

/// A reusable gradient background view that auto-resizes via Auto Layout.
final class AIONGradientBackgroundView: UIView {
    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradientLayer.colors = AIONDesign.backgroundGradientColors
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        layer.insertSublayer(gradientLayer, at: 0)
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}

// MARK: - UIViewController Gradient Extension

extension UIViewController {
    private static let gradientBgTag = 9990

    /// Adds the AION gradient background to the view. Safe to call multiple times (idempotent).
    @discardableResult
    func applyAIONGradientBackground() -> UIView {
        view.backgroundColor = AIONDesign.background
        // Remove existing gradient background if present
        if let existing = view.viewWithTag(UIViewController.gradientBgTag) {
            existing.removeFromSuperview()
        }
        let bgView = AIONGradientBackgroundView()
        bgView.tag = UIViewController.gradientBgTag
        bgView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(bgView, at: 0)
        NSLayoutConstraint.activate([
            bgView.topAnchor.constraint(equalTo: view.topAnchor),
            bgView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bgView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bgView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        return bgView
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
