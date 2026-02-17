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
        editButton.backgroundColor = AIONDesign.surfaceElevated
        editButton.layer.cornerRadius = btnSize / 2
        let editCfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        editButton.setImage(UIImage(systemName: "pencil", withConfiguration: editCfg), for: .normal)
        editButton.tintColor = AIONDesign.accentPrimary
        editButton.addTarget(self, action: #selector(editTapped), for: .touchUpInside)
        editButton.translatesAutoresizingMaskIntoConstraints = false

        // Bell button
        bellButton.backgroundColor = AIONDesign.surfaceElevated
        bellButton.layer.cornerRadius = btnSize / 2
        let bellCfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        bellButton.setImage(UIImage(systemName: "bell.fill", withConfiguration: bellCfg), for: .normal)
        bellButton.tintColor = AIONDesign.textPrimary
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
        avatarImageView.backgroundColor = AIONDesign.surface
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
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = AIONDesign.cornerRadiusLarge
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

        // Glass background
        addSubview(glassBlur)
        NSLayoutConstraint.activate([
            glassBlur.topAnchor.constraint(equalTo: topAnchor),
            glassBlur.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassBlur.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassBlur.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // Animated gradient border
        borderGradientLayer.colors = [
            AIONDesign.accentPrimary.cgColor,
            AIONDesign.accentSecondary.cgColor,
            AIONDesign.accentSuccess.cgColor,
            AIONDesign.accentPrimary.cgColor,
        ]
        borderGradientLayer.startPoint = CGPoint(x: 0, y: 0)
        borderGradientLayer.endPoint = CGPoint(x: 1, y: 1)
        borderGradientLayer.type = .conic
        borderGradientLayer.locations = [0, 0.33, 0.66, 1.0]
        layer.addSublayer(borderGradientLayer)

        borderShapeLayer.fillColor = UIColor.clear.cgColor
        borderShapeLayer.strokeColor = UIColor.white.cgColor
        borderShapeLayer.lineWidth = 2.0
        borderGradientLayer.mask = borderShapeLayer

        // Glow
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
        explanationLabel.textColor = AIONDesign.textTertiary
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
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: AIONDesign.cornerRadiusLarge)
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
        if score >= 60 { return AIONDesign.accentSecondary }
        if score >= 40 { return AIONDesign.accentWarning }
        return AIONDesign.accentDanger
    }

    private func chartColor(for metricId: String) -> Color {
        switch metricId {
        case "sleep_quality", "sleep_consistency", "sleep_debt":
            return Color(uiColor: UIColor(hex: "#5C4D7D") ?? .purple)
        case "training_strain", "load_balance":
            return Color(uiColor: AIONDesign.accentSecondary)
        case "energy_forecast", "workout_readiness":
            return Color(uiColor: AIONDesign.accentSuccess)
        default:
            return Color(uiColor: AIONDesign.accentPrimary)
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
                    .foregroundStyle(Color(uiColor: AIONDesign.textTertiary))
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

        // Glass background
        addSubview(glassBlur)
        NSLayoutConstraint.activate([
            glassBlur.topAnchor.constraint(equalTo: topAnchor),
            glassBlur.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassBlur.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassBlur.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // Subtle glow
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
        if score >= 60 { return AIONDesign.accentSecondary }
        if score >= 40 { return AIONDesign.accentWarning }
        return AIONDesign.accentDanger
    }

    private func chartColor(for metricId: String) -> Color {
        switch metricId {
        case "sleep_quality", "sleep_consistency", "sleep_debt":
            return Color(uiColor: UIColor(hex: "#5C4D7D") ?? .purple)
        case "training_strain", "load_balance":
            return Color(uiColor: AIONDesign.accentSecondary)
        case "energy_forecast", "workout_readiness":
            return Color(uiColor: AIONDesign.accentSuccess)
        default:
            return Color(uiColor: AIONDesign.accentPrimary)
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

        // Glass background
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: AIONDesign.glassBlurStyle))
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

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: AIONDesign.glassBlurStyle))
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
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    private struct Section {
        let title: String
        let metrics: [(id: String, nameKey: String, iconName: String, category: String)]
    }
    private var sections: [Section] = []

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
        view.backgroundColor = AIONDesign.background
        title = "home.edit".localized

        buildSections()
        setupTableView()
        setupNavBar()
    }

    private func buildSections() {
        let all = HomeMetricSelection.allAvailableMetrics
        sections = [
            Section(title: "home.select.hero".localized, metrics: all),
            Section(title: "home.select.secondary".localized, metrics: all.filter { $0.id != selection.heroMetricId }),
        ]
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.backgroundColor = AIONDesign.background
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupNavBar() {
        let saveBtn = UIBarButtonItem(title: "save".localized, style: .done, target: self, action: #selector(saveTapped))
        saveBtn.tintColor = AIONDesign.accentPrimary
        navigationItem.rightBarButtonItem = saveBtn

        let resetBtn = UIBarButtonItem(title: "home.reset.defaults".localized, style: .plain, target: self, action: #selector(resetTapped))
        resetBtn.tintColor = AIONDesign.textSecondary
        navigationItem.leftBarButtonItem = resetBtn
    }

    @objc private func saveTapped() {
        // Validate: need exactly 4 secondary metrics
        guard selection.secondaryMetricIds.count == 4 else {
            let alert = UIAlertController(
                title: nil,
                message: "home.select.secondary".localized,
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
        buildSections()
        tableView.reloadData()
    }
}

extension MetricSelectionViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].metrics.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let metric = sections[indexPath.section].metrics[indexPath.row]

        var content = cell.defaultContentConfiguration()
        content.text = metric.nameKey.localized
        let cfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        content.image = UIImage(systemName: metric.iconName, withConfiguration: cfg)
        content.imageProperties.tintColor = AIONDesign.accentPrimary
        content.textProperties.color = AIONDesign.textPrimary
        cell.contentConfiguration = content
        cell.backgroundColor = AIONDesign.surface

        // Selection state
        if indexPath.section == 0 {
            // Hero: radio
            cell.accessoryType = metric.id == selection.heroMetricId ? .checkmark : .none
        } else {
            // Secondary: checkbox
            cell.accessoryType = selection.secondaryMetricIds.contains(metric.id) ? .checkmark : .none
        }
        cell.tintColor = AIONDesign.accentPrimary

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let metric = sections[indexPath.section].metrics[indexPath.row]

        if indexPath.section == 0 {
            // Hero: single select
            selection.heroMetricId = metric.id
            // Remove from secondary if it was there
            selection.secondaryMetricIds.removeAll { $0 == metric.id }
            buildSections()
            tableView.reloadData()
        } else {
            // Secondary: toggle
            if selection.secondaryMetricIds.contains(metric.id) {
                selection.secondaryMetricIds.removeAll { $0 == metric.id }
            } else {
                if selection.secondaryMetricIds.count < 4 {
                    selection.secondaryMetricIds.append(metric.id)
                }
            }
            tableView.reloadData()
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
