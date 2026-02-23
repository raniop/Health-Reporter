//
//  NewHomeViews.swift
//  Health Reporter
//
//  All views for the redesigned home screen:
//  HomeHeaderView, HeroMetricCardView, SecondaryMetricCardView,
//  MetricSelectionViewController, AIRecommendationsSectionView
//

import UIKit
import SwiftUI
import Charts
import FirebaseAuth

// MARK: - RTL Helper (private)

private var isRTL: Bool {
    LocalizationManager.shared.currentLanguage == .hebrew
}
private var semanticAttr: UISemanticContentAttribute {
    isRTL ? .forceRightToLeft : .forceLeftToRight
}
private var txtAlignment: NSTextAlignment {
    isRTL ? .right : .left
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Home Header View
// ═══════════════════════════════════════════════════════════════════

final class HomeHeaderView: UIView {

    var onEditTapped: (() -> Void)?
    var onBellTapped: (() -> Void)?

    private let greetingLabel = UILabel()
    private let dateLabel = UILabel()
    private let editButton = UIButton(type: .custom)
    private let bellButton = UIButton(type: .custom)
    private let bellBadgeLabel = UILabel()
    private let avatarImageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func updateBadge(count: Int) {
        if count > 0 {
            bellBadgeLabel.text = "\(count)"
            bellBadgeLabel.isHidden = false
            bellButton.tintColor = UIColor(hex: "#FF2D55") ?? .systemRed
        } else {
            bellBadgeLabel.isHidden = true
            bellButton.tintColor = AIONDesign.textPrimary
        }
    }

    func configure(lastUpdated: Date? = nil) {
        subviews.forEach { $0.removeFromSuperview() }

        let currentIsRTL = isRTL
        let currentAlignment: NSTextAlignment = currentIsRTL ? .right : .left

        // === Outer vertical stack: Row 1 (greeting + buttons) → Row 2 (date) ===
        let outerStack = UIStackView()
        outerStack.axis = .vertical
        outerStack.spacing = 0
        outerStack.alignment = .fill
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(outerStack)

        // === Row 1: Greeting + buttons ===
        let topRow = UIStackView()
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 8
        topRow.semanticContentAttribute = semanticAttr

        // Greeting label — flexible width, scales down gracefully for long names
        greetingLabel.font = .systemFont(ofSize: 24, weight: .bold)
        greetingLabel.textColor = AIONDesign.textPrimary
        greetingLabel.textAlignment = currentAlignment
        greetingLabel.adjustsFontSizeToFitWidth = true
        greetingLabel.minimumScaleFactor = 0.65
        greetingLabel.lineBreakMode = .byTruncatingTail
        greetingLabel.numberOfLines = 1
        greetingLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        greetingLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // Edit button (pencil in glass circle)
        let btnSize: CGFloat = 38
        editButton.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        editButton.layer.cornerRadius = btnSize / 2
        editButton.layer.borderWidth = 0.5
        editButton.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        let editCfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        editButton.setImage(UIImage(systemName: "pencil", withConfiguration: editCfg), for: .normal)
        editButton.tintColor = UIColor.white
        editButton.addTarget(self, action: #selector(editTapped), for: .touchUpInside)
        editButton.translatesAutoresizingMaskIntoConstraints = false

        // Bell button
        bellButton.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        bellButton.layer.cornerRadius = btnSize / 2
        bellButton.layer.borderWidth = 0.5
        bellButton.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        let bellCfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        bellButton.setImage(UIImage(systemName: "bell.fill", withConfiguration: bellCfg), for: .normal)
        bellButton.tintColor = UIColor.white
        bellButton.addTarget(self, action: #selector(bellTapped), for: .touchUpInside)
        bellButton.translatesAutoresizingMaskIntoConstraints = false
        bellButton.clipsToBounds = false

        // Badge
        bellBadgeLabel.font = .monospacedDigitSystemFont(ofSize: 9, weight: .black)
        bellBadgeLabel.textColor = .white
        bellBadgeLabel.backgroundColor = UIColor(hex: "#FF2D55") ?? .systemRed
        bellBadgeLabel.textAlignment = .center
        bellBadgeLabel.layer.cornerRadius = 8
        bellBadgeLabel.clipsToBounds = true
        bellBadgeLabel.frame = CGRect(x: 24, y: -2, width: 16, height: 16)
        bellBadgeLabel.isHidden = true
        bellButton.addSubview(bellBadgeLabel)

        // Avatar
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.layer.cornerRadius = 20
        avatarImageView.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false

        // Buttons have fixed size — greeting label fills the remaining space.
        // Always add in LTR logical order: greeting → buttons → avatar.
        // The semanticContentAttribute on topRow handles the visual flip for RTL
        // so greeting appears on the right and buttons on the left in Hebrew.
        topRow.addArrangedSubview(greetingLabel)
        topRow.addArrangedSubview(editButton)
        topRow.addArrangedSubview(bellButton)
        topRow.addArrangedSubview(avatarImageView)

        // === Row 2: Date (full width, no button competition) ===
        dateLabel.font = AIONDesign.captionFont()
        dateLabel.textColor = AIONDesign.textSecondary
        dateLabel.textAlignment = currentAlignment

        outerStack.addArrangedSubview(topRow)
        outerStack.addArrangedSubview(dateLabel)

        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: topAnchor),
            outerStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            outerStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            outerStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 40),
            avatarImageView.heightAnchor.constraint(equalToConstant: 40),
            editButton.widthAnchor.constraint(equalToConstant: btnSize),
            editButton.heightAnchor.constraint(equalToConstant: btnSize),
            bellButton.widthAnchor.constraint(equalToConstant: btnSize),
            bellButton.heightAnchor.constraint(equalToConstant: btnSize),
        ])

        // Content
        let hour = Calendar.current.component(.hour, from: Date())
        let greetingKey: String
        switch hour {
        case 5..<12:  greetingKey = "greeting.morning"
        case 12..<17: greetingKey = "greeting.afternoon"
        case 17..<21: greetingKey = "greeting.evening"
        default:      greetingKey = "greeting.night"
        }
        let greeting = greetingKey.localized
        if let name = Auth.auth().currentUser?.displayName, !name.isEmpty {
            let first = name.components(separatedBy: " ").first ?? name
            greetingLabel.text = "\(greeting), \(first)"
        } else {
            greetingLabel.text = greeting
        }

        let fmt = DateFormatter()
        fmt.dateStyle = .long
        fmt.locale = currentIsRTL ? Locale(identifier: "he_IL") : Locale(identifier: "en_US")
        dateLabel.text = fmt.string(from: Date())

        // Avatar
        if let user = Auth.auth().currentUser, let url = user.photoURL {
            avatarImageView.loadImageAsync(from: url)
        } else {
            avatarImageView.image = UIImage(systemName: "person.circle.fill")
            avatarImageView.tintColor = AIONDesign.textTertiary
        }
    }

    @objc private func editTapped() { onEditTapped?() }
    @objc private func bellTapped() { onBellTapped?() }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Hero Metric Card View (the WOW card)
// ═══════════════════════════════════════════════════════════════════

final class HeroMetricCardView: UIView {

    var onTap: (() -> Void)?

    // Layers
    private let glassBlur: UIVisualEffectView = {
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: AIONDesign.glassBlurStyle))
        blur.alpha = AIONDesign.glassBlurAlpha
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = 16
        blur.clipsToBounds = true
        return blur
    }()
    private let borderGradientLayer = CAGradientLayer()
    private let borderShapeLayer = CAShapeLayer()
    private var displayLink: CADisplayLink?

    // Subviews
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let trendIcon = UIImageView()
    private let chartHost = UIView()  // Container for SwiftUI chart
    private let explanationLabel = UILabel()

    // Glow
    private let glowLayer = CALayer()

    // State
    private var targetValue: Int = 0
    private var animStartTime: CFTimeInterval = 0
    private var counterDisplayLink: CADisplayLink?
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private var lastHapticValue: Int = -10
    private var hasAnimated = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        semanticContentAttribute = semanticAttr
        clipsToBounds = false

        // Frosted glass background
        backgroundColor = .clear
        layer.cornerRadius = 16
        layer.borderWidth = 0.5
        layer.borderColor = AIONDesign.glassCardBorder.cgColor

        addSubview(glassBlur)
        glassBlur.alpha = AIONDesign.glassBlurAlpha
        NSLayoutConstraint.activate([
            glassBlur.topAnchor.constraint(equalTo: topAnchor),
            glassBlur.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassBlur.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassBlur.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // Animated gradient border (subtle cyan glow)
        borderGradientLayer.colors = [
            UIColor.white.withAlphaComponent(0.4).cgColor,
            AIONDesign.accentPrimary.withAlphaComponent(0.3).cgColor,
            AIONDesign.accentSecondary.withAlphaComponent(0.3).cgColor,
            UIColor.white.withAlphaComponent(0.4).cgColor,
        ]
        borderGradientLayer.startPoint = CGPoint(x: 0, y: 0)
        borderGradientLayer.endPoint = CGPoint(x: 1, y: 1)
        borderGradientLayer.type = .conic
        borderGradientLayer.locations = [0, 0.33, 0.66, 1.0]
        layer.addSublayer(borderGradientLayer)

        borderShapeLayer.fillColor = UIColor.clear.cgColor
        borderShapeLayer.strokeColor = UIColor.white.cgColor
        borderShapeLayer.lineWidth = 1.5
        borderGradientLayer.mask = borderShapeLayer

        // Glow (cyan)
        glowLayer.shadowColor = AIONDesign.accentPrimary.cgColor
        glowLayer.shadowOpacity = 0
        glowLayer.shadowRadius = 20
        glowLayer.shadowOffset = .zero
        layer.insertSublayer(glowLayer, at: 0)

        // Content
        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 8
        contentStack.alignment = .center
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.semanticContentAttribute = semanticAttr
        addSubview(contentStack)

        // Title row: icon + title + trend
        let titleRow = UIStackView()
        titleRow.axis = .horizontal
        titleRow.spacing = 6
        titleRow.alignment = .center
        titleRow.semanticContentAttribute = semanticAttr

        let iconCfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = AIONDesign.accentPrimary
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
        ])

        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = AIONDesign.textSecondary

        let trendCfg = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        trendIcon.contentMode = .scaleAspectFit
        trendIcon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            trendIcon.widthAnchor.constraint(equalToConstant: 16),
            trendIcon.heightAnchor.constraint(equalToConstant: 16),
        ])

        titleRow.addArrangedSubview(iconView)
        titleRow.addArrangedSubview(titleLabel)
        titleRow.addArrangedSubview(trendIcon)

        // Value
        valueLabel.font = .systemFont(ofSize: 64, weight: .heavy)
        valueLabel.textColor = AIONDesign.textPrimary
        valueLabel.textAlignment = .center
        valueLabel.text = "--"

        // Chart container
        chartHost.translatesAutoresizingMaskIntoConstraints = false
        chartHost.backgroundColor = .clear

        // Explanation
        explanationLabel.font = .systemFont(ofSize: 12, weight: .regular)
        explanationLabel.textColor = .white
        explanationLabel.textAlignment = .center
        explanationLabel.numberOfLines = 2

        contentStack.addArrangedSubview(titleRow)
        contentStack.addArrangedSubview(valueLabel)
        contentStack.addArrangedSubview(chartHost)
        contentStack.addArrangedSubview(explanationLabel)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            chartHost.heightAnchor.constraint(equalToConstant: 80),
            chartHost.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            chartHost.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),
        ])

        // Tap gesture
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: 16)
        borderShapeLayer.path = path.cgPath
        borderGradientLayer.frame = bounds
        glowLayer.frame = bounds
        glowLayer.shadowPath = path.cgPath
    }

    // MARK: - Configure

    func configure(metric: (any InsightMetric)?, metricId: String, chartData: [BarChartDataPoint], explanationText: String) {
        // Icon
        let iconName = HomeMetricSelection.iconName(for: metricId)
        let cfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        iconView.image = UIImage(systemName: iconName, withConfiguration: cfg)

        // Title
        let nameKey = HomeMetricSelection.nameKey(for: metricId)
        titleLabel.text = nameKey.localized

        // Trend
        if let trend = metric?.trend {
            let trendCfg = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            trendIcon.image = UIImage(systemName: trend.iconName, withConfiguration: trendCfg)
            trendIcon.tintColor = trend == .improving ? AIONDesign.accentSuccess :
                                  trend == .declining ? AIONDesign.accentDanger : AIONDesign.textTertiary
            trendIcon.isHidden = false
        } else {
            trendIcon.isHidden = true
        }

        // Value with animation
        if let val = metric?.value {
            let intVal = Int(val)
            if !hasAnimated || intVal != targetValue {
                targetValue = intVal
                startCounterAnimation()
                hasAnimated = true
            }
            // Color based on score
            valueLabel.textColor = colorForScore(val)
        } else {
            valueLabel.text = "--"
            valueLabel.textColor = AIONDesign.textPrimary
        }

        // Explanation
        explanationLabel.text = explanationText

        // Chart
        setupChart(data: chartData, metricId: metricId)

        // Start gradient border rotation
        startBorderAnimation()

        // Start glow pulse
        startGlowPulse()
    }

    // MARK: - Chart (SwiftUI)

    private func setupChart(data: [BarChartDataPoint], metricId: String) {
        chartHost.subviews.forEach { $0.removeFromSuperview() }
        guard !data.isEmpty else { return }

        let chartView = HeroWeeklyChart(data: data, accentColor: chartColor(for: metricId))
        let hostVC = UIHostingController(rootView: chartView)
        hostVC.view.backgroundColor = .clear
        hostVC.view.translatesAutoresizingMaskIntoConstraints = false
        chartHost.addSubview(hostVC.view)
        NSLayoutConstraint.activate([
            hostVC.view.topAnchor.constraint(equalTo: chartHost.topAnchor),
            hostVC.view.leadingAnchor.constraint(equalTo: chartHost.leadingAnchor),
            hostVC.view.trailingAnchor.constraint(equalTo: chartHost.trailingAnchor),
            hostVC.view.bottomAnchor.constraint(equalTo: chartHost.bottomAnchor),
        ])
    }

    // MARK: - Animations

    private func startCounterAnimation() {
        counterDisplayLink?.invalidate()
        lightHaptic.prepare()
        lastHapticValue = -10
        valueLabel.text = "0"
        animStartTime = CACurrentMediaTime()
        counterDisplayLink = CADisplayLink(target: self, selector: #selector(counterTick))
        counterDisplayLink?.add(to: .main, forMode: .common)
    }

    @objc private func counterTick() {
        let elapsed = CACurrentMediaTime() - animStartTime
        let duration: CFTimeInterval = 0.8
        let progress = min(elapsed / duration, 1.0)
        // Ease out cubic
        let eased = 1.0 - pow(1.0 - progress, 3)
        let current = Int(Double(targetValue) * eased)
        valueLabel.text = "\(current)"

        // Haptic every 10 points
        if current - lastHapticValue >= 10 {
            lightHaptic.impactOccurred()
            lastHapticValue = current
        }

        if progress >= 1.0 {
            counterDisplayLink?.invalidate()
            counterDisplayLink = nil
            valueLabel.text = "\(targetValue)"
            // Bounce
            UIView.animate(withDuration: 0.15, animations: {
                self.valueLabel.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            }) { _ in
                UIView.animate(withDuration: 0.15) {
                    self.valueLabel.transform = .identity
                }
            }
        }
    }

    private func startBorderAnimation() {
        displayLink?.invalidate()
        displayLink = CADisplayLink(target: self, selector: #selector(rotateBorder))
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func rotateBorder() {
        let time = CACurrentMediaTime()
        let angle = time.truncatingRemainder(dividingBy: 4.0) / 4.0  // Full rotation every 4 seconds
        let rotation = CGFloat(angle * 2 * .pi)

        // Rotate the gradient by adjusting start/end points
        let cx: CGFloat = 0.5
        let cy: CGFloat = 0.5
        let radius: CGFloat = 0.5
        borderGradientLayer.startPoint = CGPoint(
            x: cx + radius * cos(rotation),
            y: cy + radius * sin(rotation)
        )
        borderGradientLayer.endPoint = CGPoint(
            x: cx + radius * cos(rotation + .pi),
            y: cy + radius * sin(rotation + .pi)
        )
    }

    private func startGlowPulse() {
        let anim = CABasicAnimation(keyPath: "shadowOpacity")
        anim.fromValue = 0.0
        anim.toValue = 0.4
        anim.duration = 2.0
        anim.autoreverses = true
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        glowLayer.add(anim, forKey: "glowPulse")
    }

    @objc private func handleTap() { onTap?() }

    private func colorForScore(_ score: Double) -> UIColor {
        if score >= 80 { return AIONDesign.accentSuccess }
        if score >= 60 { return UIColor.white }
        if score >= 40 { return AIONDesign.accentWarning }
        return AIONDesign.accentDanger
    }

    private func chartColor(for metricId: String) -> Color {
        switch metricId {
        case "sleep_quality", "sleep_consistency", "sleep_debt":
            return Color(uiColor: UIColor(hex: "#36D1DC") ?? .purple)
        case "training_strain", "load_balance":
            return Color(uiColor: AIONDesign.accentSecondary)
        case "energy_forecast", "workout_readiness":
            return Color(uiColor: AIONDesign.accentSuccess)
        default:
            return Color(uiColor: UIColor.white)
        }
    }

    deinit {
        displayLink?.invalidate()
        counterDisplayLink?.invalidate()
    }
}

// MARK: - Hero Weekly Chart (SwiftUI)

@available(iOS 16.0, *)
private struct HeroWeeklyChart: View {
    let data: [BarChartDataPoint]
    let accentColor: Color

    var body: some View {
        Chart {
            ForEach(Array(data.enumerated()), id: \.offset) { idx, point in
                // Area + Line
                AreaMark(
                    x: .value("Day", point.dayLabel),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [accentColor.opacity(0.3), accentColor.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Day", point.dayLabel),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(accentColor)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.catmullRom)

                // Highlight today
                if point.isToday {
                    PointMark(
                        x: .value("Day", point.dayLabel),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(accentColor)
                    .symbolSize(40)
                    .annotation(position: .top) {
                        Text("\(Int(point.value))")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(accentColor)
                    }
                }
            }
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel()
                    .foregroundStyle(Color.white)
                    .font(.system(size: 10))
            }
        }
        .chartPlotStyle { plotArea in
            plotArea.background(.clear)
        }
        .padding(.horizontal, 4)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Secondary Metric Card View
// ═══════════════════════════════════════════════════════════════════

final class SecondaryMetricCardView: UIView {

    var onTap: (() -> Void)?

    private let glassBlur: UIVisualEffectView = {
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: AIONDesign.glassBlurStyle))
        blur.alpha = AIONDesign.glassBlurAlpha
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = AIONDesign.cornerRadius
        blur.clipsToBounds = true
        return blur
    }()

    private let iconView = UIImageView()
    private let nameLabel = UILabel()
    private let valueLabel = UILabel()
    private let trendIcon = UIImageView()
    private let chartHost = UIView()
    private let explanationLabel = UILabel()
    private let glowLayer = CALayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        semanticContentAttribute = semanticAttr
        clipsToBounds = false
        layer.cornerRadius = AIONDesign.cornerRadius

        // Frosted glass background
        backgroundColor = .clear
        layer.borderWidth = 0.5
        layer.borderColor = AIONDesign.glassCardBorder.cgColor

        addSubview(glassBlur)
        glassBlur.alpha = AIONDesign.glassBlurAlpha
        NSLayoutConstraint.activate([
            glassBlur.topAnchor.constraint(equalTo: topAnchor),
            glassBlur.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassBlur.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassBlur.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // Subtle cyan glow
        glowLayer.shadowColor = AIONDesign.accentPrimary.cgColor
        glowLayer.shadowOpacity = 0.15
        glowLayer.shadowRadius = 12
        glowLayer.shadowOffset = .zero
        layer.insertSublayer(glowLayer, at: 0)

        // Content
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 6
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.semanticContentAttribute = semanticAttr
        addSubview(stack)

        // Top row: icon + name
        let topRow = UIStackView()
        topRow.axis = .horizontal
        topRow.spacing = 6
        topRow.alignment = .center
        topRow.semanticContentAttribute = semanticAttr

        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = AIONDesign.accentPrimary
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),
        ])

        nameLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        nameLabel.textColor = AIONDesign.textSecondary
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.7

        topRow.addArrangedSubview(iconView)
        topRow.addArrangedSubview(nameLabel)

        // Value row: value + trend
        let valueRow = UIStackView()
        valueRow.axis = .horizontal
        valueRow.spacing = 4
        valueRow.alignment = .lastBaseline
        valueRow.semanticContentAttribute = semanticAttr

        valueLabel.font = .systemFont(ofSize: 32, weight: .bold)
        valueLabel.textColor = AIONDesign.textPrimary
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.6

        trendIcon.contentMode = .scaleAspectFit
        trendIcon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            trendIcon.widthAnchor.constraint(equalToConstant: 14),
            trendIcon.heightAnchor.constraint(equalToConstant: 14),
        ])

        valueRow.addArrangedSubview(valueLabel)
        valueRow.addArrangedSubview(trendIcon)
        valueRow.addArrangedSubview(UIView()) // spacer

        // Chart
        chartHost.translatesAutoresizingMaskIntoConstraints = false
        chartHost.backgroundColor = .clear

        // Explanation
        explanationLabel.font = .systemFont(ofSize: 10, weight: .regular)
        explanationLabel.textColor = AIONDesign.textTertiary
        explanationLabel.numberOfLines = 1
        explanationLabel.textAlignment = txtAlignment

        stack.addArrangedSubview(topRow)
        stack.addArrangedSubview(valueRow)
        stack.addArrangedSubview(chartHost)
        stack.addArrangedSubview(explanationLabel)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            chartHost.heightAnchor.constraint(equalToConstant: 40),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: AIONDesign.cornerRadius)
        glowLayer.frame = bounds
        glowLayer.shadowPath = path.cgPath
    }

    func configure(metric: (any InsightMetric)?, metricId: String, chartData: [BarChartDataPoint], explanationText: String) {
        let iconName = HomeMetricSelection.iconName(for: metricId)
        let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        iconView.image = UIImage(systemName: iconName, withConfiguration: cfg)

        nameLabel.text = HomeMetricSelection.nameKey(for: metricId).localized
        nameLabel.textAlignment = txtAlignment

        if let val = metric?.value {
            valueLabel.text = metric?.displayValue ?? "\(Int(val))"
            valueLabel.textColor = colorForScore(val)
        } else {
            valueLabel.text = "--"
            valueLabel.textColor = AIONDesign.textPrimary
        }

        if let trend = metric?.trend {
            let tCfg = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            trendIcon.image = UIImage(systemName: trend.iconName, withConfiguration: tCfg)
            trendIcon.tintColor = trend == .improving ? AIONDesign.accentSuccess :
                                  trend == .declining ? AIONDesign.accentDanger : AIONDesign.textTertiary
            trendIcon.isHidden = false
        } else {
            trendIcon.isHidden = true
        }

        explanationLabel.text = explanationText

        // Mini bar chart
        setupMiniChart(data: chartData, metricId: metricId)
    }

    private func setupMiniChart(data: [BarChartDataPoint], metricId: String) {
        chartHost.subviews.forEach { $0.removeFromSuperview() }
        guard !data.isEmpty else { return }

        let color = chartColor(for: metricId)
        let chartView = MiniBarChart(data: data, accentColor: color)
        let host = UIHostingController(rootView: chartView)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        chartHost.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: chartHost.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: chartHost.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: chartHost.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: chartHost.bottomAnchor),
        ])
    }

    private func colorForScore(_ score: Double) -> UIColor {
        if score >= 80 { return AIONDesign.accentSuccess }
        if score >= 60 { return UIColor.white }
        if score >= 40 { return AIONDesign.accentWarning }
        return AIONDesign.accentDanger
    }

    private func chartColor(for metricId: String) -> Color {
        switch metricId {
        case "sleep_quality", "sleep_consistency", "sleep_debt":
            return Color(uiColor: UIColor(hex: "#36D1DC") ?? .purple)
        case "training_strain", "load_balance":
            return Color(uiColor: AIONDesign.accentSecondary)
        case "energy_forecast", "workout_readiness":
            return Color(uiColor: AIONDesign.accentSuccess)
        default:
            return Color(uiColor: UIColor.white.withAlphaComponent(0.7))
        }
    }

    @objc private func handleTap() { onTap?() }
}

// MARK: - Mini Bar Chart (SwiftUI)

@available(iOS 16.0, *)
private struct MiniBarChart: View {
    let data: [BarChartDataPoint]
    let accentColor: Color

    var body: some View {
        Chart {
            ForEach(Array(data.enumerated()), id: \.offset) { idx, point in
                BarMark(
                    x: .value("Day", point.dayLabel),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(point.isToday ? accentColor : accentColor.opacity(0.35))
                .cornerRadius(3)
            }
        }
        .chartYAxis(.hidden)
        .chartXAxis(.hidden)
        .chartPlotStyle { plotArea in
            plotArea.background(.clear)
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - AI Recommendations Section View
// ═══════════════════════════════════════════════════════════════════

final class AIRecommendationsSectionView: UIView {

    var onRetryTapped: (() -> Void)?

    private let sectionTitle = UILabel()
    private let medicalCard = RecommendationCard(
        icon: "stethoscope",
        color: AIONDesign.accentPrimary,
        titleKey: "home.recommendations.medical"
    )
    private let sportsCard = RecommendationCard(
        icon: "figure.run",
        color: AIONDesign.accentSecondary,
        titleKey: "home.recommendations.sports"
    )
    private let nutritionCard = RecommendationCard(
        icon: "fork.knife",
        color: AIONDesign.accentSuccess,
        titleKey: "home.recommendations.nutrition"
    )
    private let retryContainer = UIView()
    private let retryButton = UIButton(type: .system)
    private var cardsStack: UIStackView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        semanticContentAttribute = semanticAttr

        // Cards stack (medical, sports, nutrition)
        cardsStack = UIStackView(arrangedSubviews: [medicalCard, sportsCard, nutritionCard])
        cardsStack.axis = .vertical
        cardsStack.spacing = 10

        // Retry container — shown when recommendations fail
        setupRetryContainer()

        let stack = UIStackView(arrangedSubviews: [sectionTitle, cardsStack, retryContainer])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.semanticContentAttribute = semanticAttr
        addSubview(stack)

        sectionTitle.text = "home.recommendations.title".localized
        sectionTitle.font = .systemFont(ofSize: 18, weight: .bold)
        sectionTitle.textColor = AIONDesign.textPrimary
        sectionTitle.textAlignment = txtAlignment

        retryContainer.isHidden = true

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func setupRetryContainer() {
        retryContainer.translatesAutoresizingMaskIntoConstraints = false

        // Frosted glass background
        retryContainer.backgroundColor = .clear
        retryContainer.layer.borderWidth = 1
        retryContainer.layer.borderColor = AIONDesign.glassCardBorder.cgColor

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: AIONDesign.glassBlurStyle))
        blur.alpha = AIONDesign.glassBlurAlpha
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = AIONDesign.cornerRadius
        blur.clipsToBounds = true
        retryContainer.addSubview(blur)

        retryContainer.layer.cornerRadius = AIONDesign.cornerRadius

        // Error icon
        let iconCfg = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        let errorIcon = UIImageView(image: UIImage(systemName: "exclamationmark.icloud", withConfiguration: iconCfg))
        errorIcon.tintColor = AIONDesign.textSecondary
        errorIcon.contentMode = .scaleAspectFit
        errorIcon.translatesAutoresizingMaskIntoConstraints = false

        // Error message
        let errorLabel = UILabel()
        errorLabel.text = "home.recommendations.error".localized
        errorLabel.font = .systemFont(ofSize: 14, weight: .regular)
        errorLabel.textColor = AIONDesign.textSecondary
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0

        // Retry button
        retryButton.setTitle("home.recommendations.retry".localized, for: .normal)
        retryButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        retryButton.setTitleColor(.white, for: .normal)
        retryButton.backgroundColor = AIONDesign.accentPrimary
        retryButton.layer.cornerRadius = 12
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)

        // AI sparkle icon on button
        let sparkleCfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        let sparkleImage = UIImage(systemName: "sparkles", withConfiguration: sparkleCfg)
        retryButton.setImage(sparkleImage, for: .normal)
        retryButton.tintColor = .white
        retryButton.semanticContentAttribute = semanticAttr
        retryButton.imageEdgeInsets = isRTL
            ? UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 0)
            : UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 6)

        let innerStack = UIStackView(arrangedSubviews: [errorIcon, errorLabel, retryButton])
        innerStack.axis = .vertical
        innerStack.spacing = 10
        innerStack.alignment = .center
        innerStack.translatesAutoresizingMaskIntoConstraints = false
        retryContainer.addSubview(innerStack)

        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: retryContainer.topAnchor),
            blur.leadingAnchor.constraint(equalTo: retryContainer.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: retryContainer.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: retryContainer.bottomAnchor),

            innerStack.topAnchor.constraint(equalTo: retryContainer.topAnchor, constant: 20),
            innerStack.leadingAnchor.constraint(equalTo: retryContainer.leadingAnchor, constant: 20),
            innerStack.trailingAnchor.constraint(equalTo: retryContainer.trailingAnchor, constant: -20),
            innerStack.bottomAnchor.constraint(equalTo: retryContainer.bottomAnchor, constant: -20),

            retryButton.heightAnchor.constraint(equalToConstant: 44),
            retryButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
        ])
    }

    @objc private func retryTapped() {
        onRetryTapped?()
    }

    func configure(recommendations: HomeRecommendations?) {
        if let recs = recommendations {
            cardsStack.isHidden = false
            retryContainer.isHidden = true
            medicalCard.configure(text: recs.medical)
            sportsCard.configure(text: recs.sports)
            nutritionCard.configure(text: recs.nutrition)
        } else {
            cardsStack.isHidden = false
            retryContainer.isHidden = true
            medicalCard.showLoading()
            sportsCard.showLoading()
            nutritionCard.showLoading()
        }
    }

    func showError() {
        cardsStack.isHidden = true
        retryContainer.isHidden = false
    }
}

// MARK: - Single Recommendation Card

private final class RecommendationCard: UIView {

    private let accentColor: UIColor
    private let accentBar = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let shimmerLayer = CAGradientLayer()

    init(icon: String, color: UIColor, titleKey: String) {
        self.accentColor = color
        super.init(frame: .zero)

        // Frosted glass background
        backgroundColor = .clear
        layer.borderWidth = 0.5
        layer.borderColor = AIONDesign.glassCardBorder.cgColor

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: AIONDesign.glassBlurStyle))
        blur.alpha = AIONDesign.glassBlurAlpha
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = AIONDesign.cornerRadius
        blur.clipsToBounds = true
        addSubview(blur)

        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        layer.cornerRadius = AIONDesign.cornerRadius

        // Accent bar
        accentBar.backgroundColor = color
        accentBar.layer.cornerRadius = 2
        accentBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(accentBar)

        // Icon
        let cfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        iconView.image = UIImage(systemName: icon, withConfiguration: cfg)
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        // Title
        titleLabel.text = titleKey.localized
        titleLabel.font = .systemFont(ofSize: 14, weight: .bold)
        titleLabel.textColor = color
        titleLabel.textAlignment = txtAlignment

        // Message
        messageLabel.font = .systemFont(ofSize: 13, weight: .regular)
        messageLabel.textColor = AIONDesign.textSecondary
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = txtAlignment
        messageLabel.text = ""

        // Loading
        loadingIndicator.color = color
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [titleLabel, messageLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let contentStack = UIStackView(arrangedSubviews: [iconView, textStack])
        contentStack.axis = .horizontal
        contentStack.spacing = 12
        contentStack.alignment = .top
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.semanticContentAttribute = semanticAttr
        addSubview(contentStack)
        addSubview(loadingIndicator)

        let isCurrentRTL = isRTL

        NSLayoutConstraint.activate([
            accentBar.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            accentBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            accentBar.widthAnchor.constraint(equalToConstant: 4),

            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),

            loadingIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        // Accent bar + content stack positioning based on RTL
        if isCurrentRTL {
            NSLayoutConstraint.activate([
                accentBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
                contentStack.trailingAnchor.constraint(equalTo: accentBar.leadingAnchor, constant: -10),
                contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            ])
        } else {
            NSLayoutConstraint.activate([
                accentBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
                contentStack.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 10),
                contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            ])
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(text: String) {
        loadingIndicator.stopAnimating()
        stopShimmer()
        messageLabel.text = text
        messageLabel.isHidden = false
    }

    func showLoading() {
        messageLabel.isHidden = true
        loadingIndicator.startAnimating()
        startShimmer()
    }

    private func startShimmer() {
        shimmerLayer.removeFromSuperlayer()
        shimmerLayer.colors = [
            UIColor.clear.cgColor,
            accentColor.withAlphaComponent(0.08).cgColor,
            UIColor.clear.cgColor,
        ]
        shimmerLayer.startPoint = CGPoint(x: 0, y: 0.5)
        shimmerLayer.endPoint = CGPoint(x: 1, y: 0.5)
        shimmerLayer.locations = [0.0, 0.5, 1.0]
        shimmerLayer.frame = CGRect(x: 0, y: 0, width: 400, height: 100)
        layer.addSublayer(shimmerLayer)

        let anim = CABasicAnimation(keyPath: "locations")
        anim.fromValue = [-0.5, -0.25, 0.0]
        anim.toValue = [1.0, 1.25, 1.5]
        anim.duration = 1.5
        anim.repeatCount = .infinity
        shimmerLayer.add(anim, forKey: "shimmer")
    }

    private func stopShimmer() {
        shimmerLayer.removeAllAnimations()
        shimmerLayer.removeFromSuperlayer()
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Metric Selection View Controller
// ═══════════════════════════════════════════════════════════════════

final class MetricSelectionViewController: UIViewController {

    var onSave: ((HomeMetricSelection) -> Void)?

    private var selection: HomeMetricSelection
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // Section headers
    private let heroSectionHeader = UILabel()
    private let secondarySectionHeader = UILabel()

    // Card containers
    private let heroGrid = UIStackView()
    private let secondaryGrid = UIStackView()

    // All card views (reused)
    private var heroCardViews: [MetricPickerCardView] = []
    private var secondaryCardViews: [MetricPickerCardView] = []

    private let allMetrics = HomeMetricSelection.allAvailableMetrics

    init(current: HomeMetricSelection) {
        self.selection = current
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        applyAIONGradientBackground()
        title = "home.edit".localized

        setupNavBar()
        setupScrollView()
        buildCards()
        updateSelectionStates()
    }

    // MARK: - Layout

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL
        let attr: UISemanticContentAttribute = isRTL ? .forceRightToLeft : .forceLeftToRight
        contentStack.semanticContentAttribute = attr

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -32),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),
        ])
    }

    private func buildCards() {
        let isRTL = LocalizationManager.shared.currentLanguage.isRTL
        let attr: UISemanticContentAttribute = isRTL ? .forceRightToLeft : .forceLeftToRight

        // ── Hero Section ──
        configureSectionHeader(heroSectionHeader, text: "home.select.hero".localized)
        contentStack.addArrangedSubview(heroSectionHeader)

        heroGrid.axis = .vertical
        heroGrid.spacing = 10
        heroGrid.semanticContentAttribute = attr
        contentStack.addArrangedSubview(heroGrid)

        heroCardViews = allMetrics.map { metric in
            let card = MetricPickerCardView(mode: .hero)
            card.configure(iconName: metric.iconName, name: metric.nameKey.localized, category: metric.category)
            card.onTap = { [weak self] in self?.heroTapped(metric.id) }
            return card
        }
        layoutGrid(heroGrid, cards: heroCardViews)

        // ── Spacer ──
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 8).isActive = true
        contentStack.addArrangedSubview(spacer)

        // ── Secondary Section ──
        configureSectionHeader(secondarySectionHeader, text: secondaryHeaderText())
        contentStack.addArrangedSubview(secondarySectionHeader)

        secondaryGrid.axis = .vertical
        secondaryGrid.spacing = 10
        secondaryGrid.semanticContentAttribute = attr
        contentStack.addArrangedSubview(secondaryGrid)

        let secondaryMetrics = allMetrics.filter { $0.id != selection.heroMetricId }
        secondaryCardViews = secondaryMetrics.map { metric in
            let card = MetricPickerCardView(mode: .secondary)
            card.configure(iconName: metric.iconName, name: metric.nameKey.localized, category: metric.category)
            card.onTap = { [weak self] in self?.secondaryTapped(metric.id) }
            card.metricId = metric.id
            return card
        }
        layoutGrid(secondaryGrid, cards: secondaryCardViews)
    }

    private func layoutGrid(_ grid: UIStackView, cards: [MetricPickerCardView]) {
        grid.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL
        let attr: UISemanticContentAttribute = isRTL ? .forceRightToLeft : .forceLeftToRight

        for i in stride(from: 0, to: cards.count, by: 2) {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 10
            row.distribution = .fillEqually
            row.semanticContentAttribute = attr

            row.addArrangedSubview(cards[i])
            if i + 1 < cards.count {
                row.addArrangedSubview(cards[i + 1])
            } else {
                let spacer = UIView()
                row.addArrangedSubview(spacer)
            }
            grid.addArrangedSubview(row)
        }
    }

    private func configureSectionHeader(_ label: UILabel, text: String) {
        label.text = text
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = AIONDesign.textSecondary
        let isRTL = LocalizationManager.shared.currentLanguage.isRTL
        label.textAlignment = isRTL ? .right : .left
    }

    // MARK: - Selection Logic

    private func heroTapped(_ metricId: String) {
        let oldHero = selection.heroMetricId
        selection.heroMetricId = metricId
        selection.secondaryMetricIds.removeAll { $0 == metricId }

        // Rebuild secondary grid since available metrics changed
        rebuildSecondarySection(oldHero: oldHero)
        updateSelectionStates()
    }

    private func secondaryTapped(_ metricId: String) {
        if selection.secondaryMetricIds.contains(metricId) {
            selection.secondaryMetricIds.removeAll { $0 == metricId }
        } else {
            guard selection.secondaryMetricIds.count < HomeMetricSelection.maxSecondaryCount else {
                shakeMaxReached()
                return
            }
            selection.secondaryMetricIds.append(metricId)
        }
        updateSelectionStates()
    }

    private func rebuildSecondarySection(oldHero: String) {
        let secondaryMetrics = allMetrics.filter { $0.id != selection.heroMetricId }
        secondaryCardViews = secondaryMetrics.map { metric in
            let card = MetricPickerCardView(mode: .secondary)
            card.configure(iconName: metric.iconName, name: metric.nameKey.localized, category: metric.category)
            card.onTap = { [weak self] in self?.secondaryTapped(metric.id) }
            card.metricId = metric.id
            return card
        }
        layoutGrid(secondaryGrid, cards: secondaryCardViews)
        updateSelectionStates()
    }

    private func updateSelectionStates() {
        // Hero cards
        for (i, metric) in allMetrics.enumerated() {
            guard i < heroCardViews.count else { break }
            heroCardViews[i].setSelected(metric.id == selection.heroMetricId, animated: true)
        }

        // Secondary cards
        for card in secondaryCardViews {
            guard let metricId = card.metricId else { continue }
            card.setSelected(selection.secondaryMetricIds.contains(metricId), animated: true)
        }

        // Update header counter
        secondarySectionHeader.text = secondaryHeaderText()
    }

    private func secondaryHeaderText() -> String {
        let base = "home.select.secondary".localized
        let count = selection.secondaryMetricIds.count
        let max = HomeMetricSelection.maxSecondaryCount
        return "\(base) (\(count)/\(max))"
    }

    private func shakeMaxReached() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.values = [-6, 6, -4, 4, -2, 2, 0]
        animation.duration = 0.4
        secondarySectionHeader.layer.add(animation, forKey: "shake")

        // Brief flash the header
        UIView.animate(withDuration: 0.15) {
            self.secondarySectionHeader.textColor = AIONDesign.accentWarning
        } completion: { _ in
            UIView.animate(withDuration: 0.3) {
                self.secondarySectionHeader.textColor = AIONDesign.textSecondary
            }
        }
    }

    // MARK: - Nav Bar

    private func setupNavBar() {
        let saveBtn = UIBarButtonItem(title: "save".localized, style: .done, target: self, action: #selector(saveTapped))
        saveBtn.tintColor = AIONDesign.accentPrimary
        navigationItem.rightBarButtonItem = saveBtn

        let resetBtn = UIBarButtonItem(title: "home.reset.defaults".localized, style: .plain, target: self, action: #selector(resetTapped))
        resetBtn.tintColor = AIONDesign.textSecondary
        navigationItem.leftBarButtonItem = resetBtn
    }

    @objc private func saveTapped() {
        guard selection.isValid else {
            let min = HomeMetricSelection.minSecondaryCount
            let max = HomeMetricSelection.maxSecondaryCount
            let message = String(format: "home.select.secondary.range".localized, min, max)
            let alert = UIAlertController(
                title: nil,
                message: message,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "ok".localized, style: .default))
            present(alert, animated: true)
            return
        }
        HomeMetricSelection.save(selection)
        onSave?(selection)
        dismiss(animated: true)
    }

    @objc private func resetTapped() {
        selection = .defaultSelection
        rebuildSecondarySection(oldHero: "")
        updateSelectionStates()
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - MetricPickerCardView (Glass card for metric selection)
// ═══════════════════════════════════════════════════════════════════

private final class MetricPickerCardView: UIView {

    enum Mode { case hero, secondary }

    var onTap: (() -> Void)?
    var metricId: String?

    private let mode: Mode
    private var isSelectedState = false

    // Layers & views
    private let glassBlur: UIVisualEffectView = {
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: AIONDesign.glassBlurStyle))
        blur.alpha = AIONDesign.glassBlurAlpha
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = AIONDesign.cornerRadius
        blur.clipsToBounds = true
        return blur
    }()

    private let iconView = UIImageView()
    private let nameLabel = UILabel()
    private let categoryLabel = UILabel()
    private let selectionIndicator = UIView()
    private let indicatorIcon = UIImageView()
    private let borderLayer = CAGradientLayer()

    // Category → color mapping
    private static let categoryColors: [String: UIColor] = [
        "hero": AIONDesign.accentPrimary,
        "recovery": UIColor(hex: "#36D1DC")!,
        "sleep": UIColor(hex: "#5CEAD4")!,
        "stress": UIColor(hex: "#FF6B35")!,
        "load": UIColor(hex: "#00CED1")!,
        "performance": UIColor(hex: "#6EE7B7")!,
        "activity": UIColor(hex: "#FBBF24")!,
        "habit": UIColor(hex: "#36D1DC")!,
    ]

    init(mode: Mode) {
        self.mode = mode
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        let isRTL = LocalizationManager.shared.currentLanguage.isRTL
        let attr: UISemanticContentAttribute = isRTL ? .forceRightToLeft : .forceLeftToRight
        semanticContentAttribute = attr

        layer.cornerRadius = AIONDesign.cornerRadius
        clipsToBounds = false

        // Frosted glass background
        backgroundColor = .clear
        layer.borderWidth = 0.5
        layer.borderColor = AIONDesign.glassCardBorder.cgColor

        addSubview(glassBlur)
        NSLayoutConstraint.activate([
            glassBlur.topAnchor.constraint(equalTo: topAnchor),
            glassBlur.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassBlur.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassBlur.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // Gradient border (hidden by default)
        borderLayer.colors = AIONDesign.primaryGradient
        borderLayer.startPoint = CGPoint(x: 0, y: 0)
        borderLayer.endPoint = CGPoint(x: 1, y: 1)
        borderLayer.opacity = 0
        layer.addSublayer(borderLayer)

        // Content stack
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 6
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.semanticContentAttribute = attr
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])

        // Top row: icon + selection indicator
        let topRow = UIStackView()
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.semanticContentAttribute = attr

        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = AIONDesign.accentPrimary
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),
        ])

        // Selection indicator (circle with checkmark)
        selectionIndicator.translatesAutoresizingMaskIntoConstraints = false
        selectionIndicator.layer.cornerRadius = 11
        selectionIndicator.layer.borderWidth = 2
        selectionIndicator.layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
        selectionIndicator.backgroundColor = .clear
        NSLayoutConstraint.activate([
            selectionIndicator.widthAnchor.constraint(equalToConstant: 22),
            selectionIndicator.heightAnchor.constraint(equalToConstant: 22),
        ])

        indicatorIcon.contentMode = .scaleAspectFit
        indicatorIcon.tintColor = .white
        indicatorIcon.translatesAutoresizingMaskIntoConstraints = false
        selectionIndicator.addSubview(indicatorIcon)
        NSLayoutConstraint.activate([
            indicatorIcon.centerXAnchor.constraint(equalTo: selectionIndicator.centerXAnchor),
            indicatorIcon.centerYAnchor.constraint(equalTo: selectionIndicator.centerYAnchor),
            indicatorIcon.widthAnchor.constraint(equalToConstant: 12),
            indicatorIcon.heightAnchor.constraint(equalToConstant: 12),
        ])

        topRow.addArrangedSubview(iconView)
        topRow.addArrangedSubview(UIView()) // flexible spacer
        topRow.addArrangedSubview(selectionIndicator)

        // Name
        nameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textColor = AIONDesign.textPrimary
        nameLabel.numberOfLines = 2
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.75
        let isHebrew = LocalizationManager.shared.currentLanguage.isRTL
        nameLabel.textAlignment = isHebrew ? .right : .left

        // Category pill
        categoryLabel.font = .systemFont(ofSize: 10, weight: .medium)
        categoryLabel.textColor = AIONDesign.textTertiary
        categoryLabel.textAlignment = isHebrew ? .right : .left

        stack.addArrangedSubview(topRow)
        stack.addArrangedSubview(nameLabel)
        stack.addArrangedSubview(categoryLabel)

        // Fixed height
        heightAnchor.constraint(equalToConstant: 88).isActive = true

        // Tap gesture
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    func configure(iconName: String, name: String, category: String) {
        let cfg = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        iconView.image = UIImage(systemName: iconName, withConfiguration: cfg)

        let color = Self.categoryColors[category] ?? AIONDesign.accentPrimary
        iconView.tintColor = color

        nameLabel.text = name
        categoryLabel.text = category.capitalized

        borderLayer.colors = [color.cgColor, color.withAlphaComponent(0.4).cgColor]
    }

    func setSelected(_ selected: Bool, animated: Bool) {
        guard selected != isSelectedState else { return }
        isSelectedState = selected

        let update = {
            if selected {
                // Glowing border
                self.borderLayer.opacity = 1
                let accentCG: CGColor = {
                    if let colors = self.borderLayer.colors, let first = colors.first {
                        return first as! CGColor
                    }
                    return AIONDesign.accentPrimary.cgColor
                }()
                self.layer.shadowColor = accentCG
                self.layer.shadowOpacity = 0.35
                self.layer.shadowRadius = 8
                self.layer.shadowOffset = .zero

                // Filled indicator
                let color = UIColor(cgColor: accentCG)
                self.selectionIndicator.backgroundColor = color
                self.selectionIndicator.layer.borderColor = color.cgColor
                let iconCfg = UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)
                self.indicatorIcon.image = UIImage(systemName: "checkmark", withConfiguration: iconCfg)
                self.indicatorIcon.alpha = 1
            } else {
                // No border
                self.borderLayer.opacity = 0
                self.layer.shadowOpacity = 0

                // Empty indicator
                self.selectionIndicator.backgroundColor = .clear
                self.selectionIndicator.layer.borderColor = AIONDesign.textTertiary.cgColor
                self.indicatorIcon.image = nil
                self.indicatorIcon.alpha = 0
            }
        }

        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
                update()
                if selected {
                    self.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
                } else {
                    self.transform = .identity
                }
            } completion: { _ in
                if selected {
                    UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.3) {
                        self.transform = .identity
                    }
                }
            }
        } else {
            update()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Update gradient border mask
        borderLayer.frame = bounds
        let mask = CAShapeLayer()
        mask.lineWidth = 2
        mask.path = UIBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), cornerRadius: AIONDesign.cornerRadius).cgPath
        mask.strokeColor = UIColor.black.cgColor
        mask.fillColor = UIColor.clear.cgColor
        borderLayer.mask = mask
    }

    @objc private func tapped() {
        springAnimation {
            self.onTap?()
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Home Recommendations Model
// ═══════════════════════════════════════════════════════════════════

struct HomeRecommendations: Codable {
    let medical: String
    let sports: String
    let nutrition: String
}
