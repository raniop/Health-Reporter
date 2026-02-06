//
//  ScoreDetailWithGraphViewController.swift
//  Health Reporter
//
//  Bottom sheet with score explanation + 7-day bar chart
//  Reusable for all metric detail views
//

import UIKit

// MARK: - Configuration

/// Configuration for the reusable score detail bottom sheet
struct ScoreDetailConfig {
    let title: String
    let iconName: String
    let iconColor: UIColor
    let todayValue: String
    let todayValueColor: UIColor
    let explanationText: String
    let unit: String?
    let subtitle: String?

    // 7-day chart data
    let history: [BarChartDataPoint]
    let barColor: UIColor
    let averageValue: Double?
    let averageLabel: String?
    let valueFormatter: ((Double) -> String)?
    let scaleRange: ClosedRange<Double>?
}

// MARK: - Score Detail View Controller

final class ScoreDetailWithGraphViewController: UIViewController {

    private let config: ScoreDetailConfig
    private let targetLineColor = UIColor(red: 0.4, green: 0.75, blue: 0.95, alpha: 1.0)

    init(config: ScoreDetailConfig) {
        self.config = config
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.selectedDetentIdentifier = .medium
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AIONDesign.background
        setupUI()
    }

    // MARK: - Setup UI

    private func setupUI() {
        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -48)
        ])

        // Icon
        let iconView = UIImageView(image: UIImage(systemName: config.iconName))
        iconView.tintColor = config.iconColor
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 44),
            iconView.heightAnchor.constraint(equalToConstant: 44)
        ])
        stack.addArrangedSubview(iconView)

        // Title
        let titleLabel = UILabel()
        titleLabel.text = config.title
        titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = AIONDesign.textPrimary
        titleLabel.textAlignment = .center
        stack.addArrangedSubview(titleLabel)

        // Score value
        let scoreLabel = UILabel()
        scoreLabel.text = config.todayValue
        scoreLabel.font = UIFont.systemFont(ofSize: 48, weight: .bold)
        scoreLabel.textColor = config.todayValueColor
        scoreLabel.textAlignment = .center
        stack.addArrangedSubview(scoreLabel)

        // Optional subtitle
        if let subtitle = config.subtitle {
            let subtitleLabel = UILabel()
            subtitleLabel.text = subtitle
            subtitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            subtitleLabel.textColor = AIONDesign.textSecondary
            subtitleLabel.textAlignment = .center
            stack.addArrangedSubview(subtitleLabel)
        }

        // 7-Day Chart Section
        if !config.history.isEmpty {
            stack.setCustomSpacing(24, after: stack.arrangedSubviews.last!)

            let chartSection = createChartSection(isRTL: isRTL)
            chartSection.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(chartSection)
            NSLayoutConstraint.activate([
                chartSection.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
                chartSection.trailingAnchor.constraint(equalTo: stack.trailingAnchor)
            ])

            stack.setCustomSpacing(24, after: chartSection)
        }

        // Explanation
        let explanationLabel = UILabel()
        explanationLabel.text = config.explanationText
        explanationLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        explanationLabel.textColor = AIONDesign.textSecondary
        explanationLabel.textAlignment = .center
        explanationLabel.numberOfLines = 0
        stack.addArrangedSubview(explanationLabel)
    }

    // MARK: - Chart Section (Average + Bars)

    private func createChartSection(isRTL: Bool) -> UIView {
        let container = UIView()

        // Title: "Last 7 Days"
        let sectionTitle = UILabel()
        sectionTitle.text = "chart.7day.title".localized
        sectionTitle.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        sectionTitle.textColor = AIONDesign.textTertiary
        sectionTitle.textAlignment = isRTL ? .right : .left
        sectionTitle.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(sectionTitle)

        // Chart content: average on leading side, bars on trailing
        let chartRow = UIStackView()
        chartRow.axis = .horizontal
        chartRow.spacing = 12
        chartRow.alignment = .bottom
        chartRow.semanticContentAttribute = isRTL ? .forceRightToLeft : .forceLeftToRight
        chartRow.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(chartRow)

        // Average display
        let avgView = createAverageDisplay(isRTL: isRTL)
        avgView.setContentHuggingPriority(.required, for: .horizontal)
        chartRow.addArrangedSubview(avgView)

        // Bar chart
        let barChart = createBarChart(isRTL: isRTL)
        chartRow.addArrangedSubview(barChart)

        NSLayoutConstraint.activate([
            sectionTitle.topAnchor.constraint(equalTo: container.topAnchor),
            sectionTitle.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            sectionTitle.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            chartRow.topAnchor.constraint(equalTo: sectionTitle.bottomAnchor, constant: 10),
            chartRow.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            chartRow.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            chartRow.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    // MARK: - Average Display

    private func createAverageDisplay(isRTL: Bool) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 2

        let titleLabel = UILabel()
        titleLabel.text = config.averageLabel ?? "chart.average".localized
        titleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = AIONDesign.textSecondary
        stack.addArrangedSubview(titleLabel)

        let validValues = config.history.map(\.value).filter { $0 > 0 }
        let avg = config.averageValue ?? (validValues.isEmpty ? nil : validValues.reduce(0, +) / Double(validValues.count))

        if let avg = avg {
            let formatter = config.valueFormatter ?? { "\(Int($0))" }
            let valueLabel = UILabel()
            valueLabel.text = formatter(avg)
            valueLabel.font = .systemFont(ofSize: 28, weight: .bold)
            valueLabel.textColor = AIONDesign.textPrimary
            stack.addArrangedSubview(valueLabel)
        } else {
            let noData = UILabel()
            noData.text = "--"
            noData.font = .systemFont(ofSize: 28, weight: .bold)
            noData.textColor = AIONDesign.textTertiary
            stack.addArrangedSubview(noData)
        }

        return stack
    }

    // MARK: - Bar Chart (same style as sleep chart)

    private func createBarChart(isRTL: Bool) -> UIView {
        let container = UIView()

        let chartHeight: CGFloat = 100
        let barWidth: CGFloat = 28
        let barSpacing: CGFloat = 6

        let entries = config.history
        let validValues = entries.map(\.value).filter { $0 > 0 }

        // Compute average for the line
        let actualAvg: Double
        if let avg = config.averageValue {
            actualAvg = avg
        } else {
            actualAvg = validValues.isEmpty ? 0 : validValues.reduce(0, +) / Double(validValues.count)
        }

        // Dynamic range (zoom-in like sleep chart)
        let minData = validValues.min() ?? 0
        let maxData = validValues.max() ?? 100
        let range = max(maxData - minData, 10.0) // at least 10 units range
        let displayMin = max(0, minData - range * 0.3)
        let displayMax = maxData + range * 0.3

        // Bars stack
        let barsStack = UIStackView()
        barsStack.axis = .horizontal
        barsStack.spacing = barSpacing
        barsStack.alignment = .bottom
        barsStack.distribution = .equalSpacing
        barsStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(barsStack)

        // Day labels stack
        let daysStack = UIStackView()
        daysStack.axis = .horizontal
        daysStack.spacing = barSpacing
        daysStack.alignment = .center
        daysStack.distribution = .equalSpacing
        daysStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(daysStack)

        let formatter = config.valueFormatter ?? { "\(Int($0))" }

        for entry in entries {
            // Tappable bar container
            let barContainer = TappableScoreBar(
                dataPoint: entry,
                isRTL: isRTL,
                valueFormatter: formatter
            )
            barContainer.translatesAutoresizingMaskIntoConstraints = false

            let bar = UIView()
            let hasData = entry.value > 0
            bar.backgroundColor = hasData
                ? (entry.isToday ? config.barColor : config.barColor.withAlphaComponent(0.3))
                : AIONDesign.textTertiary.withAlphaComponent(0.2)
            bar.layer.cornerRadius = 4
            bar.layer.cornerCurve = .continuous
            bar.translatesAutoresizingMaskIntoConstraints = false
            bar.isUserInteractionEnabled = false
            barContainer.addSubview(bar)

            // Calculate bar height
            var barHeight: CGFloat = 4
            if hasData {
                let normalized = (entry.value - displayMin) / (displayMax - displayMin)
                barHeight = max(chartHeight * CGFloat(normalized), 8)
            }

            NSLayoutConstraint.activate([
                barContainer.widthAnchor.constraint(equalToConstant: barWidth),
                barContainer.heightAnchor.constraint(equalToConstant: chartHeight),

                bar.bottomAnchor.constraint(equalTo: barContainer.bottomAnchor),
                bar.leadingAnchor.constraint(equalTo: barContainer.leadingAnchor),
                bar.trailingAnchor.constraint(equalTo: barContainer.trailingAnchor),
                bar.heightAnchor.constraint(equalToConstant: barHeight)
            ])

            barsStack.addArrangedSubview(barContainer)

            // Day label
            let dayLabel = UILabel()
            dayLabel.text = entry.dayLabel
            dayLabel.font = .systemFont(ofSize: 11, weight: .medium)
            dayLabel.textColor = entry.isToday ? AIONDesign.textPrimary : AIONDesign.textSecondary
            dayLabel.textAlignment = .center
            dayLabel.translatesAutoresizingMaskIntoConstraints = false
            dayLabel.widthAnchor.constraint(equalToConstant: barWidth).isActive = true
            daysStack.addArrangedSubview(dayLabel)
        }

        // Average line
        if actualAvg > 0 {
            let avgNormalized = (actualAvg - displayMin) / (displayMax - displayMin)
            let avgLineY = CGFloat(avgNormalized) * chartHeight

            let avgLine = UIView()
            avgLine.backgroundColor = targetLineColor
            avgLine.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(avgLine)

            NSLayoutConstraint.activate([
                avgLine.bottomAnchor.constraint(equalTo: barsStack.bottomAnchor, constant: -avgLineY),
                avgLine.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                avgLine.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                avgLine.heightAnchor.constraint(equalToConstant: 2)
            ])
        }

        NSLayoutConstraint.activate([
            barsStack.topAnchor.constraint(equalTo: container.topAnchor),
            barsStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            barsStack.heightAnchor.constraint(equalToConstant: chartHeight),

            daysStack.topAnchor.constraint(equalTo: barsStack.bottomAnchor, constant: 4),
            daysStack.leadingAnchor.constraint(equalTo: barsStack.leadingAnchor),
            daysStack.trailingAnchor.constraint(equalTo: barsStack.trailingAnchor),
            daysStack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }
}

// MARK: - Tappable Score Bar (Generic)

final class TappableScoreBar: UIView {

    private let dataPoint: BarChartDataPoint
    private let isRTL: Bool
    private let valueFormatter: (Double) -> String

    init(dataPoint: BarChartDataPoint, isRTL: Bool, valueFormatter: @escaping (Double) -> String) {
        self.dataPoint = dataPoint
        self.isRTL = isRTL
        self.valueFormatter = valueFormatter
        super.init(frame: .zero)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleTap() {
        guard dataPoint.value > 0 else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: isRTL ? "he_IL" : "en_US")
        dateFormatter.dateFormat = isRTL ? "EEEE, d בMMMM" : "EEEE, MMMM d"
        let dateStr = dateFormatter.string(from: dataPoint.date)
        let valueStr = valueFormatter(dataPoint.value)

        showTooltip(dateStr: dateStr, valueStr: valueStr)
    }

    private func showTooltip(dateStr: String, valueStr: String) {
        guard let window = window else { return }

        // Remove previous tooltip
        window.subviews.filter { $0.tag == 9998 }.forEach { $0.removeFromSuperview() }

        let tooltip = UIView()
        tooltip.tag = 9998
        tooltip.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        tooltip.layer.cornerRadius = 10
        tooltip.translatesAutoresizingMaskIntoConstraints = false

        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 4
        contentStack.alignment = .center
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        tooltip.addSubview(contentStack)

        let dateLabel = UILabel()
        dateLabel.text = dateStr
        dateLabel.font = .systemFont(ofSize: 12, weight: .medium)
        dateLabel.textColor = .white.withAlphaComponent(0.7)
        dateLabel.textAlignment = .center

        let valueLabel = UILabel()
        valueLabel.text = valueStr
        valueLabel.font = .systemFont(ofSize: 16, weight: .bold)
        valueLabel.textColor = .white
        valueLabel.textAlignment = .center

        contentStack.addArrangedSubview(dateLabel)
        contentStack.addArrangedSubview(valueLabel)

        // Small arrow
        let arrow = UIView()
        arrow.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        arrow.translatesAutoresizingMaskIntoConstraints = false
        arrow.transform = CGAffineTransform(rotationAngle: .pi / 4)
        tooltip.addSubview(arrow)

        window.addSubview(tooltip)

        let barFrame = convert(bounds, to: window)
        let tooltipWidth: CGFloat = 150
        let screenWidth = window.bounds.width
        let padding: CGFloat = 12

        var tooltipCenterX = barFrame.midX
        if tooltipCenterX + tooltipWidth / 2 > screenWidth - padding {
            tooltipCenterX = screenWidth - padding - tooltipWidth / 2
        }
        if tooltipCenterX - tooltipWidth / 2 < padding {
            tooltipCenterX = padding + tooltipWidth / 2
        }

        let arrowOffsetX = barFrame.midX - tooltipCenterX

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: tooltip.topAnchor, constant: 8),
            contentStack.leadingAnchor.constraint(equalTo: tooltip.leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(equalTo: tooltip.trailingAnchor, constant: -12),
            contentStack.bottomAnchor.constraint(equalTo: tooltip.bottomAnchor, constant: -12),

            arrow.widthAnchor.constraint(equalToConstant: 12),
            arrow.heightAnchor.constraint(equalToConstant: 12),
            arrow.centerXAnchor.constraint(equalTo: tooltip.centerXAnchor, constant: arrowOffsetX),
            arrow.bottomAnchor.constraint(equalTo: tooltip.bottomAnchor, constant: 4),

            tooltip.centerXAnchor.constraint(equalTo: window.leadingAnchor, constant: tooltipCenterX),
            tooltip.bottomAnchor.constraint(equalTo: window.topAnchor, constant: barFrame.minY - 8)
        ])

        // Animate in
        tooltip.alpha = 0
        tooltip.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
            tooltip.alpha = 1
            tooltip.transform = .identity
        }

        // Auto dismiss after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            UIView.animate(withDuration: 0.2, animations: {
                tooltip.alpha = 0
                tooltip.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            }) { _ in
                tooltip.removeFromSuperview()
            }
        }
    }
}

// MARK: - Helper: Build ScoreDetailConfig from metric

extension ScoreDetailConfig {

    /// Create config for a metric using its DailyScoreEntry history
    static func from(
        metric: any InsightMetric,
        scoreHistory: [DailyScoreEntry],
        iconName: String? = nil,
        iconColor: UIColor? = nil,
        barColor: UIColor? = nil,
        explanation: String? = nil
    ) -> ScoreDetailConfig {
        let metricColor = iconColor ?? StarMetricsCalculator.color(for: metric)
        let metricIcon = iconName ?? StarMetricsCalculator.icon(for: metric.id)

        let history = scoreHistory.map { entry in
            BarChartDataPoint(
                date: entry.date,
                dayLabel: entry.dayOfWeekShort,
                value: entry.value(for: metric.id) ?? 0,
                isToday: Calendar.current.isDateInToday(entry.date)
            )
        }

        let validValues = history.map(\.value).filter { $0 > 0 }
        let avg = validValues.isEmpty ? nil : validValues.reduce(0, +) / Double(validValues.count)

        return ScoreDetailConfig(
            title: metric.nameKey.localized,
            iconName: metricIcon,
            iconColor: metricColor,
            todayValue: metric.displayValue,
            todayValueColor: metricColor,
            explanationText: explanation ?? StarMetricsCalculator.whyItMatters(for: metric.id),
            unit: nil,
            subtitle: nil,
            history: history,
            barColor: barColor ?? metricColor,
            averageValue: avg,
            averageLabel: "chart.average".localized,
            valueFormatter: { "\(Int($0))" },
            scaleRange: 0...100
        )
    }
}
