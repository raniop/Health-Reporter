//
//  AIONDashboardComponents.swift
//  Health Reporter
//
//  קומפוננטות דשבורד בסגנון Synthesis – צבעי לוגו, כרטיסים, STOP/START/WATCH.
//

import UIKit

// MARK: - כפתור מידע (i) לכרטיסים – קטן, משמאל
final class CardInfoButton: UIButton {
    var explanation: String = ""

    static func make(explanation: String) -> CardInfoButton {
        let b = CardInfoButton(type: .system)
        b.explanation = explanation
        b.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 10, weight: .medium)
        b.setImage(UIImage(systemName: "info.circle.fill", withConfiguration: config), for: .normal)
        b.tintColor = AIONDesign.accentPrimary.withAlphaComponent(0.85)
        b.backgroundColor = AIONDesign.accentPrimary.withAlphaComponent(0.12)
        b.layer.cornerRadius = 9
        b.clipsToBounds = true
        NSLayoutConstraint.activate([
            b.widthAnchor.constraint(equalToConstant: 20),
            b.heightAnchor.constraint(equalToConstant: 20),
        ])
        return b
    }
}

// MARK: - Card Explanations - Localized
enum CardExplanations {
    static var readiness: String { "explanation.readiness".localized }
    static var hrv: String { "explanation.hrv".localized }
    static var sleep: String { "explanation.sleep".localized }
    static var strain: String { "explanation.strain".localized }
    static var efficiency: String { "explanation.efficiency".localized }
    static var bioSleep: String { "explanation.bioSleep".localized }
    static var bioTemp: String { "explanation.bioTemp".localized }
    static var bioRhrOrTemp: String { "explanation.bioRhrOrTemp".localized }
    static var directives: String { "explanation.directives".localized }
    static var insight: String { "explanation.insight".localized }
    static var correlation: String { "explanation.correlation".localized }
    static var pValue: String { "explanation.pValue".localized }
    static var sampleSize: String { "explanation.sampleSize".localized }
    static var biometrics: String { "explanation.biometrics".localized }
    static var focus: String { "explanation.focus".localized }
    static var profileHeight: String { "explanation.profileHeight".localized }
    static var profileWeight: String { "explanation.profileWeight".localized }
    static var highlights: String { "explanation.highlights".localized }
    static var profileAge: String { "explanation.profileAge".localized }
    static var activitySteps: String { "explanation.activitySteps".localized }
    static var activityDistance: String { "explanation.activityDistance".localized }
    static var activityCalories: String { "explanation.activityCalories".localized }
    static var activityExercise: String { "explanation.activityExercise".localized }
    static var activityFlights: String { "explanation.activityFlights".localized }
    static var activityMove: String { "explanation.activityMove".localized }
    static var activityStand: String { "explanation.activityStand".localized }
    static var activityCycling: String { "explanation.activityCycling".localized }
    static var activitySwimming: String { "explanation.activitySwimming".localized }
}

// MARK: - KPI Ring (עיגול ערך + תווית)
final class KPIRingView: UIView {
    private let valueLabel = UILabel()
    private let titleLabel = UILabel()
    private let deltaLabel = UILabel()
    private let ringLayer = CAShapeLayer()
    private let bgRingLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        backgroundColor = AIONDesign.surface
        layer.cornerRadius = AIONDesign.cornerRadius
        clipsToBounds = true

        valueLabel.font = .systemFont(ofSize: 22, weight: .bold)
        valueLabel.textColor = AIONDesign.accentPrimary
        valueLabel.textAlignment = .center
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = AIONDesign.captionFont()
        titleLabel.textColor = AIONDesign.textSecondary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        deltaLabel.font = .systemFont(ofSize: 11, weight: .medium)
        deltaLabel.textColor = AIONDesign.accentSuccess
        deltaLabel.textAlignment = .center
        deltaLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(valueLabel)
        addSubview(titleLabel)
        addSubview(deltaLabel)

        NSLayoutConstraint.activate([
            valueLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -10),
            titleLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            deltaLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            deltaLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let r = min(bounds.width, bounds.height) / 2 - 10
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let path = UIBezierPath(arcCenter: center, radius: r, startAngle: -.pi / 2, endAngle: .pi * 1.5, clockwise: true)
        if bgRingLayer.superlayer == nil {
            bgRingLayer.path = path.cgPath
            bgRingLayer.fillColor = UIColor.clear.cgColor
            bgRingLayer.strokeColor = UIColor.systemGray4.cgColor
            bgRingLayer.lineWidth = 4
            layer.addSublayer(bgRingLayer)
        }
        if ringLayer.superlayer == nil {
            ringLayer.path = path.cgPath
            ringLayer.fillColor = UIColor.clear.cgColor
            ringLayer.strokeColor = AIONDesign.accentPrimary.cgColor
            ringLayer.lineWidth = 4
            ringLayer.lineCap = .round
            layer.insertSublayer(ringLayer, above: bgRingLayer)
        }
        bgRingLayer.frame = bounds
        ringLayer.frame = bounds
    }

    func configure(value: String, title: String, delta: String?, progress: CGFloat = 1) {
        valueLabel.text = value
        titleLabel.text = title
        deltaLabel.text = delta
        deltaLabel.isHidden = delta == nil || delta?.isEmpty == true
        ringLayer.strokeEnd = min(1, max(0, progress))
    }
}

// MARK: - Bio-Stack Card (שינה / טמפ') - עם תמיכה בגרף מגמה
final class BioStackCardView: UIView {
    // MARK: - UI Elements
    private let headerStack = UIStackView()  // כותרת + אייקון בשורה אחת
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()       // "ממוצע: X"
    private let barView = UIView()
    private let barFill = UIView()
    private let subtitleLabel = UILabel()
    private let chartContainer = UIView()
    private let minLabel = UILabel()
    private let maxLabel = UILabel()

    // נתוני גרף
    private var trendDataPoints: [Double] = []
    private var chartColor: UIColor = AIONDesign.accentPrimary
    private var showingTrend: Bool = false
    private var isPositiveTrendGood: Bool = true

    private var barProgress: CGFloat = 0

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Setup UI מאפס
    private func setupUI() {
        backgroundColor = AIONDesign.surface
        layer.cornerRadius = AIONDesign.cornerRadius

        // Header Stack: [Title] [Icon] - מימין לשמאל
        headerStack.axis = .horizontal
        headerStack.spacing = 4
        headerStack.alignment = .center
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        // Icon
        iconView.tintColor = AIONDesign.accentPrimary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 16).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 16).isActive = true

        // Title
        titleLabel.font = AIONDesign.captionFont()
        titleLabel.textColor = AIONDesign.textSecondary
        titleLabel.textAlignment = .right
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        // הוספה ל-header stack (סדר מימין לשמאל)
        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(iconView)

        // Value Label - "ממוצע: X"
        valueLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        valueLabel.textColor = AIONDesign.textPrimary
        valueLabel.textAlignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        // Progress Bar
        barView.backgroundColor = UIColor.systemGray4
        barView.layer.cornerRadius = 2
        barView.clipsToBounds = true
        barView.translatesAutoresizingMaskIntoConstraints = false
        barView.isHidden = true

        barFill.backgroundColor = AIONDesign.accentPrimary
        barFill.layer.cornerRadius = 2
        barView.addSubview(barFill)

        // Subtitle
        subtitleLabel.font = .systemFont(ofSize: 10, weight: .regular)
        subtitleLabel.textColor = AIONDesign.textTertiary
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 1
        subtitleLabel.adjustsFontSizeToFitWidth = true
        subtitleLabel.minimumScaleFactor = 0.7
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.isHidden = true

        // Chart Container
        chartContainer.backgroundColor = .clear
        chartContainer.translatesAutoresizingMaskIntoConstraints = false
        chartContainer.clipsToBounds = false
        chartContainer.isHidden = true

        // Min/Max Labels
        minLabel.font = .systemFont(ofSize: 8, weight: .medium)
        minLabel.textColor = AIONDesign.textTertiary
        minLabel.textAlignment = .left
        minLabel.translatesAutoresizingMaskIntoConstraints = false
        minLabel.isHidden = true

        maxLabel.font = .systemFont(ofSize: 8, weight: .medium)
        maxLabel.textColor = AIONDesign.textTertiary
        maxLabel.textAlignment = .left
        maxLabel.translatesAutoresizingMaskIntoConstraints = false
        maxLabel.isHidden = true

        // Add subviews
        addSubview(headerStack)
        addSubview(valueLabel)
        addSubview(barView)
        addSubview(subtitleLabel)
        addSubview(chartContainer)
        addSubview(minLabel)
        addSubview(maxLabel)

        // MARK: - Constraints
        NSLayoutConstraint.activate([
            // Header (כותרת + אייקון) - בגובה כפתור info שנמצא ב-8 מלמעלה
            headerStack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            headerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),

            // Value ("ממוצע") - צמוד מתחת לכותרת, ללא רווח
            valueLabel.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 2),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),

            // Chart - מתחיל אחרי ה-value
            chartContainer.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 6),
            chartContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 26),
            chartContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            chartContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),

            // Min/Max labels בצד שמאל של הגרף
            maxLabel.topAnchor.constraint(equalTo: chartContainer.topAnchor),
            maxLabel.trailingAnchor.constraint(equalTo: chartContainer.leadingAnchor, constant: -2),
            minLabel.bottomAnchor.constraint(equalTo: chartContainer.bottomAnchor),
            minLabel.trailingAnchor.constraint(equalTo: chartContainer.leadingAnchor, constant: -2),

            // Progress bar (למצב יום)
            barView.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 8),
            barView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            barView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            barView.heightAnchor.constraint(equalToConstant: 6),

            // Subtitle בתחתית
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            subtitleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
    }

    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()
        barFill.frame = CGRect(x: 0, y: 0, width: barView.bounds.width * barProgress, height: barView.bounds.height)
        if showingTrend {
            drawTrendChart()
        }
    }

    // MARK: - Configure (מצב יום אחד עם progress bar)
    func configure(icon: String, title: String, value: String, progress: CGFloat?, subtitle: String? = nil) {
        showingTrend = false
        iconView.image = UIImage(systemName: icon)
        titleLabel.text = title
        valueLabel.text = value
        barProgress = progress ?? 0

        barView.isHidden = progress == nil
        chartContainer.isHidden = true
        minLabel.isHidden = true
        maxLabel.isHidden = true

        if let sub = subtitle, !sub.isEmpty {
            subtitleLabel.text = sub
            subtitleLabel.isHidden = false
        } else {
            subtitleLabel.isHidden = true
        }
        setNeedsLayout()
    }

    // MARK: - Configure Trend (מצב 7/30 ימים עם גרף)
    func configureTrend(icon: String, title: String, value: String, subtitle: String?, dataPoints: [Double], isPositiveTrendGood: Bool = true) {
        showingTrend = true
        self.isPositiveTrendGood = isPositiveTrendGood
        iconView.image = UIImage(systemName: icon)
        titleLabel.text = title
        valueLabel.text = value
        trendDataPoints = dataPoints

        // חישוב צבע לפי מגמה
        chartColor = calculateTrendColor(dataPoints: dataPoints, isPositiveTrendGood: isPositiveTrendGood)

        barView.isHidden = true
        chartContainer.isHidden = false

        // שנתות min/max
        if let minVal = dataPoints.min(), let maxVal = dataPoints.max() {
            minLabel.text = String(format: "%.0f", minVal)
            maxLabel.text = String(format: "%.0f", maxVal)
            minLabel.isHidden = false
            maxLabel.isHidden = false
        }

        if let sub = subtitle, !sub.isEmpty {
            subtitleLabel.text = sub
            subtitleLabel.isHidden = false
        } else {
            subtitleLabel.isHidden = true
        }
        setNeedsLayout()
    }

    // MARK: - Trend Color Calculation
    private func calculateTrendColor(dataPoints: [Double], isPositiveTrendGood: Bool) -> UIColor {
        guard dataPoints.count >= 2 else { return AIONDesign.accentPrimary }

        let midPoint = dataPoints.count / 2
        let firstHalf = Array(dataPoints.prefix(midPoint))
        let secondHalf = Array(dataPoints.suffix(dataPoints.count - midPoint))

        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)

        let isIncreasing = secondAvg > firstAvg
        let changePercent = abs(secondAvg - firstAvg) / max(firstAvg, 1) * 100

        if changePercent < 3 {
            return AIONDesign.accentPrimary // יציב
        }

        let isGoodTrend = isPositiveTrendGood ? isIncreasing : !isIncreasing
        return isGoodTrend ? AIONDesign.accentSuccess : UIColor(red: 1.0, green: 0.35, blue: 0.35, alpha: 1.0)
    }

    // MARK: - Draw Chart
    private func drawTrendChart() {
        chartContainer.layer.sublayers?.forEach { $0.removeFromSuperlayer() }

        guard !trendDataPoints.isEmpty, chartContainer.bounds.width > 0 else { return }

        let width = chartContainer.bounds.width
        let height = chartContainer.bounds.height
        let paddingX: CGFloat = 6
        let paddingY: CGFloat = 8

        let minVal = trendDataPoints.min() ?? 0
        let maxVal = trendDataPoints.max() ?? 100
        let range = maxVal - minVal

        let stepX = (width - paddingX * 2) / CGFloat(max(1, trendDataPoints.count - 1))
        var points: [CGPoint] = []
        let chartHeight = height - paddingY * 2

        for (index, value) in trendDataPoints.enumerated() {
            let x = paddingX + CGFloat(index) * stepX
            let y: CGFloat
            if range < 0.01 {
                y = height / 2
            } else {
                let normalized = (value - minVal) / range
                y = paddingY + (1 - normalized) * chartHeight
            }
            points.append(CGPoint(x: x, y: y))
        }

        // קו הגרף
        let path = UIBezierPath()
        if let first = points.first {
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }

        let lineLayer = CAShapeLayer()
        lineLayer.path = path.cgPath
        lineLayer.strokeColor = chartColor.cgColor
        lineLayer.fillColor = UIColor.clear.cgColor
        lineLayer.lineWidth = 3
        lineLayer.lineCap = .round
        lineLayer.lineJoin = .round
        chartContainer.layer.addSublayer(lineLayer)

        // Gradient fill
        let fillPath = UIBezierPath()
        if let first = points.first {
            fillPath.move(to: CGPoint(x: first.x, y: height))
            fillPath.addLine(to: first)
            for point in points.dropFirst() {
                fillPath.addLine(to: point)
            }
            if let last = points.last {
                fillPath.addLine(to: CGPoint(x: last.x, y: height))
            }
            fillPath.close()
        }

        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = chartContainer.bounds
        gradientLayer.colors = [
            chartColor.withAlphaComponent(0.3).cgColor,
            chartColor.withAlphaComponent(0.02).cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]

        let maskLayer = CAShapeLayer()
        maskLayer.path = fillPath.cgPath
        gradientLayer.mask = maskLayer
        chartContainer.layer.insertSublayer(gradientLayer, at: 0)

        // נקודות בקצוות
        if points.count >= 2 {
            for idx in [0, points.count - 1] {
                let dot = CAShapeLayer()
                let dotPath = UIBezierPath(arcCenter: points[idx], radius: 3, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                dot.path = dotPath.cgPath
                dot.fillColor = chartColor.cgColor
                chartContainer.layer.addSublayer(dot)
            }
        }
    }
}

// MARK: - Bio Trend Card (גרף מגמה קטן לשינה/RHR)

final class BioTrendCardView: UIView {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let chartContainer = UIView()

    // נקודות הגרף
    private var dataPoints: [Double] = []
    private var chartColor: UIColor = AIONDesign.accentPrimary

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        backgroundColor = AIONDesign.surface
        layer.cornerRadius = AIONDesign.cornerRadius

        iconView.tintColor = AIONDesign.accentPrimary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = AIONDesign.captionFont()
        titleLabel.textColor = AIONDesign.textSecondary
        titleLabel.textAlignment = .right
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        valueLabel.font = .systemFont(ofSize: 16, weight: .bold)
        valueLabel.textColor = AIONDesign.textPrimary
        valueLabel.textAlignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.font = .systemFont(ofSize: 10, weight: .regular)
        subtitleLabel.textColor = AIONDesign.textTertiary
        subtitleLabel.textAlignment = .right
        subtitleLabel.numberOfLines = 1
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        chartContainer.backgroundColor = .clear
        chartContainer.translatesAutoresizingMaskIntoConstraints = false
        chartContainer.clipsToBounds = true

        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(valueLabel)
        addSubview(subtitleLabel)
        addSubview(chartContainer)

        NSLayoutConstraint.activate([
            iconView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -AIONDesign.spacing),
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: AIONDesign.spacing),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: AIONDesign.spacing),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: AIONDesign.spacing),
            titleLabel.trailingAnchor.constraint(equalTo: iconView.leadingAnchor, constant: -8),

            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -AIONDesign.spacing),

            subtitleLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 0),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -AIONDesign.spacing),

            chartContainer.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 4),
            chartContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: AIONDesign.spacing),
            chartContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -AIONDesign.spacing),
            chartContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -AIONDesign.spacing),
            chartContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 40),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        drawChart()
    }

    func configure(icon: String, title: String, value: String, subtitle: String?, dataPoints: [Double], color: UIColor = AIONDesign.accentPrimary) {
        iconView.image = UIImage(systemName: icon)
        titleLabel.text = title
        valueLabel.text = value
        subtitleLabel.text = subtitle ?? ""
        subtitleLabel.isHidden = subtitle == nil || subtitle?.isEmpty == true
        self.dataPoints = dataPoints
        self.chartColor = color
        setNeedsLayout()
    }

    private func drawChart() {
        // נקה layers ישנים
        chartContainer.layer.sublayers?.forEach { $0.removeFromSuperlayer() }

        guard !dataPoints.isEmpty, chartContainer.bounds.width > 0 else { return }

        let width = chartContainer.bounds.width
        let height = chartContainer.bounds.height
        let padding: CGFloat = 2

        // מציאת min/max עם padding
        let minVal = (dataPoints.min() ?? 0)
        let maxVal = (dataPoints.max() ?? 100)
        let range = max(maxVal - minVal, 1)

        // חישוב נקודות
        let stepX = (width - padding * 2) / CGFloat(max(1, dataPoints.count - 1))
        var points: [CGPoint] = []

        for (index, value) in dataPoints.enumerated() {
            let x = padding + CGFloat(index) * stepX
            let normalizedY = (value - minVal) / range
            let y = height - padding - (normalizedY * (height - padding * 2))
            points.append(CGPoint(x: x, y: y))
        }

        // ציור הקו
        let path = UIBezierPath()
        if let first = points.first {
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }

        let lineLayer = CAShapeLayer()
        lineLayer.path = path.cgPath
        lineLayer.strokeColor = chartColor.cgColor
        lineLayer.fillColor = UIColor.clear.cgColor
        lineLayer.lineWidth = 2
        lineLayer.lineCap = .round
        lineLayer.lineJoin = .round
        chartContainer.layer.addSublayer(lineLayer)

        // ציור gradient מתחת לקו
        let fillPath = UIBezierPath()
        if let first = points.first {
            fillPath.move(to: CGPoint(x: first.x, y: height))
            fillPath.addLine(to: first)
            for point in points.dropFirst() {
                fillPath.addLine(to: point)
            }
            if let last = points.last {
                fillPath.addLine(to: CGPoint(x: last.x, y: height))
            }
            fillPath.close()
        }

        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = chartContainer.bounds
        gradientLayer.colors = [
            chartColor.withAlphaComponent(0.3).cgColor,
            chartColor.withAlphaComponent(0.05).cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]

        let maskLayer = CAShapeLayer()
        maskLayer.path = fillPath.cgPath
        gradientLayer.mask = maskLayer

        chartContainer.layer.insertSublayer(gradientLayer, at: 0)

        // נקודות על הגרף (ראשון ואחרון)
        if points.count >= 2 {
            for idx in [0, points.count - 1] {
                let dot = CAShapeLayer()
                let dotPath = UIBezierPath(arcCenter: points[idx], radius: 3, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                dot.path = dotPath.cgPath
                dot.fillColor = chartColor.cgColor
                chartContainer.layer.addSublayer(dot)
            }
        }
    }
}

// MARK: - Gradient Border Extension
extension UIView {
    func addGradientBorder(colors: [UIColor], width: CGFloat, cornerRadius: CGFloat) {
        let gradient = CAGradientLayer()
        gradient.frame = bounds
        gradient.colors = colors.map(\.cgColor)
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.cornerRadius = cornerRadius

        let shape = CAShapeLayer()
        shape.lineWidth = width
        shape.path = UIBezierPath(roundedRect: bounds.insetBy(dx: width / 2, dy: width / 2), cornerRadius: cornerRadius).cgPath
        shape.fillColor = UIColor.clear.cgColor
        shape.strokeColor = UIColor.white.cgColor
        gradient.mask = shape

        // Remove old gradient border if exists
        layer.sublayers?.removeAll { $0.name == "gradientBorder" }
        gradient.name = "gradientBorder"
        layer.addSublayer(gradient)
    }

    func updateGradientBorderFrame() {
        guard let gradient = layer.sublayers?.first(where: { $0.name == "gradientBorder" }) as? CAGradientLayer,
              let shape = gradient.mask as? CAShapeLayer else { return }
        gradient.frame = bounds
        let w = shape.lineWidth
        shape.path = UIBezierPath(roundedRect: bounds.insetBy(dx: w / 2, dy: w / 2), cornerRadius: layer.cornerRadius).cgPath
    }
}

// MARK: - Directives Card (STOP / START / WATCH)
final class DirectivesCardView: UIView {
    private static let placeholderIcon = "circle.dashed"
    private let stack = UIStackView()
    private var stopRow: (label: UILabel, body: UILabel, icon: UIImageView, wrap: UIView)?
    private var startRow: (label: UILabel, body: UILabel, icon: UIImageView, wrap: UIView)?
    private var watchRow: (label: UILabel, body: UILabel, icon: UIImageView, wrap: UIView)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateGradientBorderFrame()
    }

    private func setup() {
        backgroundColor = AIONDesign.surface
        layer.cornerRadius = AIONDesign.cornerRadiusLarge
        semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute

        stack.axis = .vertical
        stack.spacing = AIONDesign.spacingLarge
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        let stop = makeRow(label: "directives.stop".localized, color: AIONDesign.accentDanger)
        let start = makeRow(label: "directives.start".localized, color: AIONDesign.accentSuccess)
        let watch = makeRow(label: "directives.watch".localized, color: AIONDesign.accentWarning)
        stopRow = (stop.0, stop.1, stop.2, stop.3)
        startRow = (start.0, start.1, start.2, start.3)
        watchRow = (watch.0, watch.1, watch.2, watch.3)

        stack.addArrangedSubview(stop.3)
        stack.addArrangedSubview(start.3)
        stack.addArrangedSubview(watch.3)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: AIONDesign.spacingLarge),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: AIONDesign.spacing),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -AIONDesign.spacing),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -AIONDesign.spacingLarge),
        ])
    }

    private func makeRow(label: String, color: UIColor) -> (UILabel, UILabel, UIImageView, UIView) {
        let l = UILabel()
        l.text = label
        l.font = .systemFont(ofSize: 13, weight: .bold)
        l.textColor = color
        l.textAlignment = LocalizationManager.shared.textAlignment

        let b = UILabel()
        b.font = .systemFont(ofSize: 14, weight: .regular)
        b.textColor = AIONDesign.textPrimary
        b.textAlignment = LocalizationManager.shared.textAlignment
        b.numberOfLines = 0

        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = AIONDesign.textTertiary
        let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        iv.image = UIImage(systemName: Self.placeholderIcon, withConfiguration: cfg)
        iv.isHidden = true

        let wrap = UIView()
        wrap.addSubview(l)
        wrap.addSubview(b)
        wrap.addSubview(iv)
        l.translatesAutoresizingMaskIntoConstraints = false
        b.translatesAutoresizingMaskIntoConstraints = false
        iv.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            l.topAnchor.constraint(equalTo: wrap.topAnchor),
            l.trailingAnchor.constraint(equalTo: wrap.trailingAnchor),
            b.topAnchor.constraint(equalTo: l.bottomAnchor, constant: 4),
            b.leadingAnchor.constraint(equalTo: wrap.leadingAnchor),
            b.trailingAnchor.constraint(equalTo: wrap.trailingAnchor),
            b.bottomAnchor.constraint(equalTo: wrap.bottomAnchor),
            iv.topAnchor.constraint(equalTo: l.bottomAnchor, constant: 4),
            iv.leadingAnchor.constraint(equalTo: wrap.leadingAnchor),
            iv.widthAnchor.constraint(equalToConstant: 20),
            iv.heightAnchor.constraint(equalToConstant: 20),
        ])
        return (l, b, iv, wrap)
    }

    private func setRow(_ row: (label: UILabel, body: UILabel, icon: UIImageView, wrap: UIView)?, value: String, color: UIColor) {
        guard let row = row else { return }
        let isEmpty = value.isEmpty || value == "—"
        if isEmpty {
            row.body.text = ""
            row.body.isHidden = true
            row.icon.isHidden = false
        } else {
            row.body.attributedText = AIONDesign.attributedStringRTL(value, font: .systemFont(ofSize: 14, weight: .regular), color: color)
            row.body.isHidden = false
            row.icon.isHidden = true
        }
    }

    func configure(stop: String, start: String, watch: String) {
        hidePlaceholder()
        let b: (String) -> String = { s in s == "—" ? "—" : AIONDirectivesParser.bullet(s) }
        setRow(stopRow, value: b(stop), color: AIONDesign.textPrimary)
        setRow(startRow, value: b(start), color: AIONDesign.textPrimary)
        setRow(watchRow, value: b(watch), color: AIONDesign.textPrimary)
    }

    func showPlaceholder() {
        let msg = "dashboard.runAnalysisForRecommendations".localized
        // Hide all rows when showing placeholder
        stopRow?.wrap.isHidden = true
        startRow?.wrap.isHidden = true
        watchRow?.wrap.isHidden = true

        // Show placeholder message in a centered way
        if placeholderLabel == nil {
            let label = UILabel()
            label.font = .systemFont(ofSize: 14, weight: .regular)
            label.textColor = AIONDesign.textTertiary
            label.textAlignment = .center
            label.numberOfLines = 0
            label.translatesAutoresizingMaskIntoConstraints = false

            // Create a container with extra top padding to avoid info button
            let container = UIView()
            container.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(label)
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
                label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            ])

            stack.addArrangedSubview(container)
            placeholderContainer = container
            placeholderLabel = label
        }
        placeholderLabel?.text = msg
        placeholderContainer?.isHidden = false
    }

    private var placeholderLabel: UILabel?
    private var placeholderContainer: UIView?

    func hidePlaceholder() {
        placeholderContainer?.isHidden = true
        stopRow?.wrap.isHidden = false
        startRow?.wrap.isHidden = false
        watchRow?.wrap.isHidden = false
    }
}

// MARK: - Activity Rings View (Apple-style)

/// טבעות פעילות בסגנון Apple Fitness
final class ActivityRingsView: UIView {

    // Ring colors matching Apple's Activity app
    private let moveColor = UIColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 1.0)    // Red
    private let exerciseColor = UIColor(red: 0.0, green: 0.87, blue: 0.34, alpha: 1.0) // Green
    private let standColor = UIColor(red: 0.0, green: 0.78, blue: 0.89, alpha: 1.0)    // Cyan/Blue

    private let moveRingBg = CAShapeLayer()
    private let moveRingFg = CAShapeLayer()
    private let exerciseRingBg = CAShapeLayer()
    private let exerciseRingFg = CAShapeLayer()
    private let standRingBg = CAShapeLayer()
    private let standRingFg = CAShapeLayer()

    private let moveLabel = UILabel()
    private let exerciseLabel = UILabel()
    private let standLabel = UILabel()

    private let moveValueLabel = UILabel()
    private let exerciseValueLabel = UILabel()
    private let standValueLabel = UILabel()

    private var ringSize: CGFloat = 100
    private let ringWidth: CGFloat = 12
    private let ringGap: CGFloat = 4

    // Store current progress values to preserve during layout
    private var currentMoveProgress: CGFloat = 0
    private var currentExerciseProgress: CGFloat = 0
    private var currentStandProgress: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        backgroundColor = AIONDesign.surface
        layer.cornerRadius = AIONDesign.cornerRadiusLarge
        clipsToBounds = true

        // Add ring layers
        [moveRingBg, exerciseRingBg, standRingBg, moveRingFg, exerciseRingFg, standRingFg].forEach {
            layer.addSublayer($0)
        }

        // Configure labels
        configureLabel(moveLabel, text: "dashboard.move".localized, color: moveColor)
        configureLabel(exerciseLabel, text: "dashboard.exercise".localized, color: exerciseColor)
        configureLabel(standLabel, text: "dashboard.stand".localized, color: standColor)

        configureValueLabel(moveValueLabel)
        configureValueLabel(exerciseValueLabel)
        configureValueLabel(standValueLabel)

        [moveLabel, exerciseLabel, standLabel, moveValueLabel, exerciseValueLabel, standValueLabel].forEach { addSubview($0) }
    }

    private func configureLabel(_ label: UILabel, text: String, color: UIColor) {
        label.text = text
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = color
        label.textAlignment = LocalizationManager.shared.textAlignment
        label.translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureValueLabel(_ label: UILabel) {
        label.font = .systemFont(ofSize: 13, weight: .bold)
        label.textColor = AIONDesign.textPrimary
        label.textAlignment = LocalizationManager.shared.textAlignment
        label.translatesAutoresizingMaskIntoConstraints = false
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        drawRings()
        layoutLabels()
    }

    private func drawRings() {
        let isRTL = LocalizationManager.shared.currentLanguage.isRTL
        let centerX = isRTL ? bounds.width * 0.35 : bounds.width * 0.65
        let centerY = bounds.height / 2
        let center = CGPoint(x: centerX, y: centerY)
        ringSize = min(bounds.width * 0.55, bounds.height - 20)

        let outerRadius = ringSize / 2 - ringWidth / 2
        let middleRadius = outerRadius - ringWidth - ringGap
        let innerRadius = middleRadius - ringWidth - ringGap

        // Move ring (outer - red)
        configureRing(bg: moveRingBg, fg: moveRingFg, center: center, radius: outerRadius, color: moveColor, currentProgress: currentMoveProgress)

        // Exercise ring (middle - green)
        configureRing(bg: exerciseRingBg, fg: exerciseRingFg, center: center, radius: middleRadius, color: exerciseColor, currentProgress: currentExerciseProgress)

        // Stand ring (inner - cyan)
        configureRing(bg: standRingBg, fg: standRingFg, center: center, radius: innerRadius, color: standColor, currentProgress: currentStandProgress)
    }

    private func configureRing(bg: CAShapeLayer, fg: CAShapeLayer, center: CGPoint, radius: CGFloat, color: UIColor, currentProgress: CGFloat) {
        let startAngle = -CGFloat.pi / 2
        let endAngle = startAngle + 2 * CGFloat.pi

        let path = UIBezierPath(arcCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)

        bg.path = path.cgPath
        bg.fillColor = UIColor.clear.cgColor
        bg.strokeColor = color.withAlphaComponent(0.2).cgColor
        bg.lineWidth = ringWidth
        bg.lineCap = .round

        fg.path = path.cgPath
        fg.fillColor = UIColor.clear.cgColor
        fg.strokeColor = color.cgColor
        fg.lineWidth = ringWidth
        fg.lineCap = .round
        // Preserve current progress value instead of resetting to 0
        fg.strokeEnd = currentProgress
    }

    private func layoutLabels() {
        let isRTL = LocalizationManager.shared.currentLanguage.isRTL
        let spacing: CGFloat = 28
        let labelWidth = bounds.width * 0.42 - 12

        // In RTL: labels on right (x = 0.58), In LTR: labels on left (x = 12)
        let labelsX: CGFloat = isRTL ? bounds.width * 0.58 : 12

        // Move
        moveLabel.frame = CGRect(x: labelsX, y: bounds.height / 2 - spacing * 1.5 - 8, width: labelWidth, height: 16)
        moveValueLabel.frame = CGRect(x: labelsX, y: moveLabel.frame.maxY, width: labelWidth, height: 18)

        // Exercise
        exerciseLabel.frame = CGRect(x: labelsX, y: bounds.height / 2 - 8, width: labelWidth, height: 16)
        exerciseValueLabel.frame = CGRect(x: labelsX, y: exerciseLabel.frame.maxY, width: labelWidth, height: 18)

        // Stand
        standLabel.frame = CGRect(x: labelsX, y: bounds.height / 2 + spacing * 1.5 - 8, width: labelWidth, height: 16)
        standValueLabel.frame = CGRect(x: labelsX, y: standLabel.frame.maxY, width: labelWidth, height: 18)
    }

    /// Configure rings with values
    /// - Parameters:
    ///   - moveCalories: Active calories burned
    ///   - moveGoal: Move goal (default 500)
    ///   - exerciseMinutes: Exercise minutes
    ///   - exerciseGoal: Exercise goal (default 30)
    ///   - standHours: Stand hours
    ///   - standGoal: Stand goal (default 12)
    func configure(moveCalories: Double?, moveGoal: Double = 500,
                   exerciseMinutes: Double?, exerciseGoal: Double = 30,
                   standHours: Double?, standGoal: Double = 12,
                   animated: Bool = true) {

        let move = moveCalories ?? 0
        let exercise = exerciseMinutes ?? 0
        let stand = standHours ?? 0

        let moveProgress = min(move / moveGoal, 1.5) // Allow overflow up to 150%
        let exerciseProgress = min(exercise / exerciseGoal, 1.5)
        let standProgress = min(stand / standGoal, 1.5)

        // Store progress values for layout preservation
        currentMoveProgress = CGFloat(moveProgress)
        currentExerciseProgress = CGFloat(exerciseProgress)
        currentStandProgress = CGFloat(standProgress)

        // Update labels
        moveValueLabel.text = "\(Int(move))/\(Int(moveGoal)) \("unit.kcal".localized)"
        exerciseValueLabel.text = "\(Int(exercise))/\(Int(exerciseGoal)) \("unit.min".localized)"
        standValueLabel.text = "\(Int(stand))/\(Int(standGoal)) \("unit.hr".localized)"

        // Animate rings
        if animated {
            animateRing(moveRingFg, to: moveProgress)
            animateRing(exerciseRingFg, to: exerciseProgress)
            animateRing(standRingFg, to: standProgress)
        } else {
            moveRingFg.strokeEnd = CGFloat(moveProgress)
            exerciseRingFg.strokeEnd = CGFloat(exerciseProgress)
            standRingFg.strokeEnd = CGFloat(standProgress)
        }
    }

    private func animateRing(_ layer: CAShapeLayer, to value: Double) {
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = layer.strokeEnd
        animation.toValue = CGFloat(value)
        animation.duration = 0.8
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.strokeEnd = CGFloat(value)
        layer.add(animation, forKey: "strokeEndAnimation")
    }

    /// Configure with placeholder
    func showPlaceholder() {
        currentMoveProgress = 0
        currentExerciseProgress = 0
        currentStandProgress = 0

        moveValueLabel.text = "—/500 \("unit.kcal".localized)"
        exerciseValueLabel.text = "—/30 \("unit.min".localized)"
        standValueLabel.text = "—/12 \("unit.hr".localized)"
        moveRingFg.strokeEnd = 0
        exerciseRingFg.strokeEnd = 0
        standRingFg.strokeEnd = 0
    }
}

// MARK: - Activity Stats Card (Compact horizontal stats)

/// כרטיס סטטיסטיקות פעילות קומפקטי
final class ActivityStatsCardView: UIView {

    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        backgroundColor = AIONDesign.surface
        layer.cornerRadius = AIONDesign.cornerRadius
        clipsToBounds = true

        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
    }

    func configure(steps: Double?, distance: Double?, flights: Double?, workouts: Int?) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Steps
        if let steps = steps, steps > 0 {
            stack.addArrangedSubview(makeStatItem(
                icon: "figure.walk",
                value: formatNumber(steps),
                label: "activity.steps".localized,
                color: UIColor.systemOrange
            ))
        }

        // Distance
        if let dist = distance, dist > 0 {
            stack.addArrangedSubview(makeStatItem(
                icon: "location.fill",
                value: String(format: "%.1f", dist),
                label: "unit.km".localized,
                color: UIColor.systemBlue
            ))
        }

        // Flights
        if let flights = flights, flights > 0 {
            stack.addArrangedSubview(makeStatItem(
                icon: "arrow.up.right",
                value: "\(Int(flights))",
                label: "activity.floors".localized,
                color: UIColor.systemPurple
            ))
        }

        // Workouts
        if let workouts = workouts, workouts > 0 {
            stack.addArrangedSubview(makeStatItem(
                icon: "flame.fill",
                value: "\(workouts)",
                label: "activity.workouts".localized,
                color: UIColor.systemRed
            ))
        }

        // If empty, show placeholder
        if stack.arrangedSubviews.isEmpty {
            stack.addArrangedSubview(makeStatItem(
                icon: "figure.walk",
                value: "—",
                label: "activity.steps".localized,
                color: UIColor.systemGray
            ))
        }
    }

    private func makeStatItem(icon: String, value: String, label: String, color: UIColor) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 16, weight: .bold)
        valueLabel.textColor = AIONDesign.textPrimary
        valueLabel.textAlignment = .center
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = label
        titleLabel.font = .systemFont(ofSize: 10, weight: .medium)
        titleLabel.textColor = AIONDesign.textSecondary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(iconView)
        container.addSubview(valueLabel)
        container.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: container.topAnchor),
            iconView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            valueLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 4),
            valueLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            titleLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 2),
            titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])

        return container
    }

    private func formatNumber(_ num: Double) -> String {
        if num >= 1000 {
            return String(format: "%.1fK", num / 1000)
        }
        return "\(Int(num))"
    }
}

// MARK: - Parse STOP / START / WATCH from insights text
enum AIONDirectivesParser {
    static func parse(from text: String) -> (stop: String, start: String, watch: String)? {
        let lines = text.components(separatedBy: .newlines)
        var stop: String?, start: String?, watch: String?
        for (idx, line) in lines.enumerated() {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.contains("**STOP:**") || t.contains("STOP:") {
                let content = t.replacingOccurrences(of: "**STOP:**", with: "").replacingOccurrences(of: "STOP:", with: "").trimmingCharacters(in: .whitespaces)
                stop = content.isEmpty && idx + 1 < lines.count ? lines[idx + 1].trimmingCharacters(in: .whitespaces) : content
                if stop?.isEmpty == true { stop = nil }
            } else if t.contains("**START:**") || t.contains("START:") {
                let content = t.replacingOccurrences(of: "**START:**", with: "").replacingOccurrences(of: "START:", with: "").trimmingCharacters(in: .whitespaces)
                start = content.isEmpty && idx + 1 < lines.count ? lines[idx + 1].trimmingCharacters(in: .whitespaces) : content
                if start?.isEmpty == true { start = nil }
            } else if t.contains("**WATCH:**") || t.contains("WATCH:") {
                let content = t.replacingOccurrences(of: "**WATCH:**", with: "").replacingOccurrences(of: "WATCH:", with: "").trimmingCharacters(in: .whitespaces)
                watch = content.isEmpty && idx + 1 < lines.count ? lines[idx + 1].trimmingCharacters(in: .whitespaces) : content
                if watch?.isEmpty == true { watch = nil }
            }
        }
        guard stop != nil || start != nil || watch != nil else { return nil }
        return (stop ?? "—", start ?? "—", watch ?? "—")
    }

    /// מסיר מקף בתחילת משפט ומחליף ב־• יפה.
    static func bullet(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("- ") { t = String(t.dropFirst(2)).trimmingCharacters(in: .whitespaces) }
        else if t.hasPrefix("-") { t = String(t.dropFirst()).trimmingCharacters(in: .whitespaces) }
        return t.isEmpty ? t : "• " + t
    }
}
