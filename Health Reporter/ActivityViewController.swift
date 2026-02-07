//
//  ActivityViewController.swift
//  Health Reporter
//
//  Activity page – only relevant metrics, graphs, Pro Lab design. Built from scratch.
//

import UIKit
import HealthKit
import SwiftUI

final class ActivityViewController: UIViewController {

    private var selectedRange: DataRange = .week
    private var summary: ActivitySummary?
    private var timeSeries: HealthKitManager.ActivityTimeSeries?
    private var stepsHosting: UIViewController?
    private var distanceHosting: UIViewController?
    private var energyHosting: UIViewController?

    private let scrollView: UIScrollView = {
        let v = UIScrollView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.showsVerticalScrollIndicator = true
        v.alwaysBounceVertical = true
        return v
    }()

    private let refreshControl: UIRefreshControl = {
        let r = UIRefreshControl()
        r.attributedTitle = NSAttributedString(string: "activity.loadingActivity".localized, attributes: [.foregroundColor: AIONDesign.textSecondary])
        return r
    }()

    private let stack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = AIONDesign.spacingLarge
        s.alignment = .fill
        s.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let periodControl = UISegmentedControl()
    private let rangeLabel = UILabel()
    private let heroCard = UIView()
    private let heroGradient = CAGradientLayer()
    private let activityRingsCard = ActivityRingsView()
    private let summaryRow1 = UIStackView()
    private let summaryRow2 = UIStackView()
    private let secondaryRow = UIStackView()
    private let stepsChartCard = UIView()
    private let distanceChartCard = UIView()
    private let energyChartCard = UIView()
    private var stepsValueLabel: UILabel?
    private var distanceValueLabel: UILabel?
    private var caloriesValueLabel: UILabel?
    private var exerciseValueLabel: UILabel?
    private var flightsValueLabel: UILabel?
    private var moveValueLabel: UILabel?
    private var standValueLabel: UILabel?

    override func viewDidLoad() {
        super.viewDidLoad()
        // title removed - managed by parent UnifiedTrendsActivityViewController
        view.backgroundColor = AIONDesign.background
        view.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        setupUI()
        loadData()

        // Listen for background color changes
        NotificationCenter.default.addObserver(self, selector: #selector(backgroundColorDidChange), name: .backgroundColorChanged, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func backgroundColorDidChange() {
        view.backgroundColor = AIONDesign.background
        navigationController?.navigationBar.barStyle = AIONDesign.navBarStyle
        navigationController?.navigationBar.barTintColor = AIONDesign.background
        navigationController?.navigationBar.backgroundColor = AIONDesign.background
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: AIONDesign.textPrimary]
    }

    private func setupUI() {
        scrollView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(refreshPulled), for: .valueChanged)
        view.addSubview(scrollView)
        scrollView.addSubview(stack)

        let periodCol = UIStackView()
        periodCol.axis = .vertical
        periodCol.spacing = 8
        periodCol.alignment = .fill
        periodCol.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        periodCol.translatesAutoresizingMaskIntoConstraints = false

        for (i, r) in DataRange.allCases.enumerated() {
            periodControl.insertSegment(withTitle: r.segmentTitle(), at: i, animated: false)
        }
        periodControl.selectedSegmentIndex = 1
        periodControl.selectedSegmentTintColor = AIONDesign.surfaceElevated
        periodControl.setTitleTextAttributes([.foregroundColor: AIONDesign.textPrimary], for: .selected)
        periodControl.setTitleTextAttributes([.foregroundColor: AIONDesign.textTertiary], for: .normal)
        periodControl.backgroundColor = AIONDesign.surface
        periodControl.translatesAutoresizingMaskIntoConstraints = false
        periodControl.addTarget(self, action: #selector(periodChanged), for: .valueChanged)

        rangeLabel.font = .systemFont(ofSize: 13, weight: .medium)
        rangeLabel.textColor = AIONDesign.textSecondary
        rangeLabel.textAlignment = .center
        rangeLabel.numberOfLines = 1
        rangeLabel.adjustsFontSizeToFitWidth = true
        rangeLabel.translatesAutoresizingMaskIntoConstraints = false

        periodCol.addArrangedSubview(periodControl)
        periodCol.addArrangedSubview(rangeLabel)
        stack.addArrangedSubview(periodCol)

        setupHero()
        setupActivityRings()
        setupSummaryCards()
        setupSecondaryCards()
        setupChartCards()

        NSLayoutConstraint.activate([
            periodControl.heightAnchor.constraint(equalToConstant: 36),
            rangeLabel.heightAnchor.constraint(equalToConstant: 20),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: AIONDesign.spacingLarge),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: AIONDesign.spacing),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -AIONDesign.spacing),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -AIONDesign.spacingLarge),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -AIONDesign.spacing * 2),
        ])
    }

    private func setupHero() {
        heroCard.backgroundColor = AIONDesign.surface
        heroCard.layer.cornerRadius = AIONDesign.cornerRadiusLarge
        heroCard.translatesAutoresizingMaskIntoConstraints = false
        heroGradient.colors = [
            AIONDesign.accentPrimary.withAlphaComponent(0.12).cgColor,
            AIONDesign.accentSuccess.withAlphaComponent(0.06).cgColor,
        ]
        heroGradient.startPoint = CGPoint(x: 0, y: 0)
        heroGradient.endPoint = CGPoint(x: 1, y: 1)
        heroCard.layer.insertSublayer(heroGradient, at: 0)

        let icon = UIImageView(image: UIImage(systemName: "figure.run"))
        icon.tintColor = AIONDesign.accentPrimary
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        let title = UILabel()
        title.text = "activity.activityTitle".localized
        title.font = .systemFont(ofSize: 22, weight: .bold)
        title.textColor = AIONDesign.textPrimary
        title.textAlignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false
        let sub = UILabel()
        sub.text = "activity.stepsDistanceCalories".localized
        sub.font = .systemFont(ofSize: 13, weight: .medium)
        sub.textColor = AIONDesign.textSecondary
        sub.textAlignment = .center
        sub.translatesAutoresizingMaskIntoConstraints = false

        heroCard.addSubview(icon)
        heroCard.addSubview(title)
        heroCard.addSubview(sub)
        stack.addArrangedSubview(heroCard)

        NSLayoutConstraint.activate([
            heroCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 88),
            icon.widthAnchor.constraint(equalToConstant: 32),
            icon.heightAnchor.constraint(equalToConstant: 32),
            icon.topAnchor.constraint(equalTo: heroCard.topAnchor, constant: AIONDesign.spacing),
            icon.centerXAnchor.constraint(equalTo: heroCard.centerXAnchor),
            title.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 8),
            title.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: AIONDesign.spacing),
            title.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -AIONDesign.spacing),
            sub.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
            sub.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: AIONDesign.spacing),
            sub.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -AIONDesign.spacing),
            sub.bottomAnchor.constraint(equalTo: heroCard.bottomAnchor, constant: -AIONDesign.spacing),
        ])
    }

    private func setupActivityRings() {
        stack.addArrangedSubview(makeSectionLabel("activity.activityRings".localized))

        activityRingsCard.translatesAutoresizingMaskIntoConstraints = false
        activityRingsCard.showPlaceholder()
        stack.addArrangedSubview(activityRingsCard)

        NSLayoutConstraint.activate([
            activityRingsCard.heightAnchor.constraint(equalToConstant: 160),
        ])
    }

    private func setupSummaryCards() {
        stack.addArrangedSubview(makeSectionLabel("activity.summary".localized))

        summaryRow1.axis = .horizontal
        summaryRow1.spacing = AIONDesign.spacing
        summaryRow1.distribution = .fillEqually
        summaryRow1.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        summaryRow1.translatesAutoresizingMaskIntoConstraints = false
        summaryRow2.axis = .horizontal
        summaryRow2.spacing = AIONDesign.spacing
        summaryRow2.distribution = .fillEqually
        summaryRow2.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        summaryRow2.translatesAutoresizingMaskIntoConstraints = false

        let (c1, l1) = makeMetricCard("activity.stepsMetric".localized, unit: "", explanation: CardExplanations.activitySteps, icon: "figure.walk", iconColor: .systemCyan)
        let (c2, l2) = makeMetricCard("activity.distanceMetric".localized, unit: "activity.km".localized, explanation: CardExplanations.activityDistance, icon: "map.fill", iconColor: .systemGreen)
        let (c3, l3) = makeMetricCard("activity.caloriesMetric".localized, unit: "kcal", explanation: CardExplanations.activityCalories, icon: "flame.fill", iconColor: .systemOrange)
        let (c4, l4) = makeMetricCard("activity.exerciseMetric".localized, unit: "activity.min".localized, explanation: CardExplanations.activityExercise, icon: "timer", iconColor: .systemPink)
        stepsValueLabel = l1
        distanceValueLabel = l2
        caloriesValueLabel = l3
        exerciseValueLabel = l4
        summaryRow1.addArrangedSubview(c1)
        summaryRow1.addArrangedSubview(c2)
        summaryRow2.addArrangedSubview(c3)
        summaryRow2.addArrangedSubview(c4)
        [summaryRow1, summaryRow2].forEach { row in
            row.heightAnchor.constraint(equalToConstant: 96).isActive = true
            stack.addArrangedSubview(row)
        }
    }

    private func setupSecondaryCards() {
        secondaryRow.axis = .horizontal
        secondaryRow.spacing = AIONDesign.spacing
        secondaryRow.distribution = .fillEqually
        secondaryRow.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        secondaryRow.translatesAutoresizingMaskIntoConstraints = false

        let (c1, l1) = makeMetricCard("activity.floorsMetric".localized, unit: "", explanation: CardExplanations.activityFlights, icon: "stairs", iconColor: .systemPurple)
        let (c2, l2) = makeMetricCard("activity.moveMetric".localized, unit: "kcal", explanation: CardExplanations.activityMove, icon: "flame.circle.fill", iconColor: .systemRed)
        let (c3, l3) = makeMetricCard("activity.standMetric".localized, unit: "activity.hours".localized, explanation: CardExplanations.activityStand, icon: "figure.stand", iconColor: .systemTeal)
        flightsValueLabel = l1
        moveValueLabel = l2
        standValueLabel = l3
        [c1, c2, c3].forEach { secondaryRow.addArrangedSubview($0) }
        secondaryRow.heightAnchor.constraint(equalToConstant: 88).isActive = true
        stack.addArrangedSubview(secondaryRow)
    }

    private func makeMetricCard(_ title: String, unit: String, explanation: String, icon: String, iconColor: UIColor = AIONDesign.accentPrimary) -> (UIView, UILabel) {
        let card = UIView()
        card.backgroundColor = AIONDesign.surface
        card.layer.cornerRadius = AIONDesign.cornerRadius
        card.translatesAutoresizingMaskIntoConstraints = false

        let info = CardInfoButton.make(explanation: explanation)
        info.addTarget(self, action: #selector(infoTapped(_:)), for: .touchUpInside)
        card.addSubview(info)

        // Icon
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconConfig))
        iconView.tintColor = iconColor
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(iconView)

        let tl = UILabel()
        tl.text = title
        tl.font = .systemFont(ofSize: 11, weight: .medium)
        tl.textColor = AIONDesign.textSecondary
        tl.textAlignment = .center
        tl.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(tl)

        let vl = UILabel()
        vl.text = "—"
        vl.font = .systemFont(ofSize: 17, weight: .bold)
        vl.textColor = AIONDesign.textPrimary
        vl.textAlignment = .center
        vl.adjustsFontSizeToFitWidth = true
        vl.minimumScaleFactor = 0.7
        vl.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(vl)

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        // Common constraints
        NSLayoutConstraint.activate([
            info.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            iconView.centerYAnchor.constraint(equalTo: info.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),
            tl.topAnchor.constraint(equalTo: info.bottomAnchor, constant: 8),
            tl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            tl.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            vl.topAnchor.constraint(equalTo: tl.bottomAnchor, constant: 4),
            vl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            vl.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            vl.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -8),
        ])

        // Info button and icon position based on language direction
        // LTR (English): icon on LEFT, info on RIGHT
        // RTL (Hebrew): icon on RIGHT, info on LEFT
        if isRTL {
            info.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: AIONDesign.spacing).isActive = true
            iconView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -AIONDesign.spacing).isActive = true
        } else {
            info.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -AIONDesign.spacing).isActive = true
            iconView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: AIONDesign.spacing).isActive = true
        }
        return (card, vl)
    }

    private func setupChartCards() {
        func addChartCard(_ container: UIView, title: String, infoMsg: String, placeholderHost: UIHostingController<ChartPlaceholderView>) {
            container.backgroundColor = AIONDesign.surface
            container.layer.cornerRadius = AIONDesign.cornerRadiusLarge
            container.translatesAutoresizingMaskIntoConstraints = false
            placeholderHost.view.clipsToBounds = false

            let hl = UILabel()
            hl.text = title
            hl.font = .systemFont(ofSize: 12, weight: .semibold)
            hl.textColor = AIONDesign.accentPrimary
            hl.textAlignment = LocalizationManager.shared.textAlignment
            hl.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(hl)

            let info = CardInfoButton.make(explanation: infoMsg)
            info.addTarget(self, action: #selector(infoTapped(_:)), for: .touchUpInside)
            container.addSubview(info)

            placeholderHost.view.backgroundColor = .clear
            placeholderHost.view.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(placeholderHost.view)
            addChild(placeholderHost)
            placeholderHost.didMove(toParent: self)

            let isRTL = LocalizationManager.shared.currentLanguage.isRTL

            // Common constraints
            NSLayoutConstraint.activate([
                info.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
                hl.centerYAnchor.constraint(equalTo: info.centerYAnchor),
                placeholderHost.view.topAnchor.constraint(equalTo: info.bottomAnchor, constant: 8),
                placeholderHost.view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: AIONDesign.spacing),
                placeholderHost.view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -AIONDesign.spacing),
                placeholderHost.view.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -AIONDesign.spacing),
                placeholderHost.view.heightAnchor.constraint(equalToConstant: 180),
            ])

            // RTL/LTR specific constraints
            // RTL (Hebrew): info on LEFT, title on right. LTR (English): info on RIGHT, title on left
            if isRTL {
                NSLayoutConstraint.activate([
                    info.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: AIONDesign.spacing),
                    hl.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -AIONDesign.spacing),
                    hl.leadingAnchor.constraint(greaterThanOrEqualTo: info.trailingAnchor, constant: 8),
                ])
            } else {
                NSLayoutConstraint.activate([
                    info.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -AIONDesign.spacing),
                    hl.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: AIONDesign.spacing),
                    hl.trailingAnchor.constraint(lessThanOrEqualTo: info.leadingAnchor, constant: -8),
                ])
            }
        }

        let placeholders = [
            UIHostingController(rootView: ChartPlaceholderView(message: "loading".localized, icon: "chart.bar.fill")),
            UIHostingController(rootView: ChartPlaceholderView(message: "loading".localized, icon: "figure.walk")),
            UIHostingController(rootView: ChartPlaceholderView(message: "loading".localized, icon: "flame.fill")),
        ]
        addChartCard(stepsChartCard, title: "activity.stepsChart".localized, infoMsg: CardExplanations.activitySteps, placeholderHost: placeholders[0])
        addChartCard(distanceChartCard, title: "activity.distanceChart".localized, infoMsg: CardExplanations.activityDistance, placeholderHost: placeholders[1])
        addChartCard(energyChartCard, title: "activity.caloriesChart".localized, infoMsg: CardExplanations.activityCalories, placeholderHost: placeholders[2])
        stepsHosting = placeholders[0]
        distanceHosting = placeholders[1]
        energyHosting = placeholders[2]

        stack.addArrangedSubview(makeSectionLabel("activity.charts".localized))
        stack.addArrangedSubview(stepsChartCard)
        stack.addArrangedSubview(distanceChartCard)
        stack.addArrangedSubview(energyChartCard)
    }

    private func makeSectionLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: 11, weight: .semibold)
        l.textColor = AIONDesign.accentPrimary
        l.textAlignment = .center
        return l
    }

    @objc private func infoTapped(_ sender: CardInfoButton) {
        let alert = UIAlertController(title: "dashboard.explanation".localized, message: sender.explanation, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "understand".localized, style: .default))
        present(alert, animated: true)
    }

    @objc private func periodChanged() {
        selectedRange = DataRange.allCases[periodControl.selectedSegmentIndex]
        loadData()
    }

    @objc private func refreshPulled() {
        loadData(useRefreshControl: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        heroGradient.frame = heroCard.bounds
        heroGradient.cornerRadius = heroCard.layer.cornerRadius
    }

    private func loadData(useRefreshControl: Bool = false) {
        rangeLabel.text = selectedRange.displayLabel()
        if !useRefreshControl { showLoading(true) }
        HealthKitManager.shared.requestAuthorization { [weak self] success, _ in
            guard let self = self, success else {
                if !useRefreshControl { self?.showLoading(false) }
                if useRefreshControl { self?.refreshControl.endRefreshing() }
                return
            }
            let g = DispatchGroup()
            var summary: ActivitySummary?
            var series: HealthKitManager.ActivityTimeSeries?

            g.enter()
            HealthKitManager.shared.fetchActivityForRange(self.selectedRange) { s in
                summary = s
                g.leave()
            }
            g.enter()
            HealthKitManager.shared.fetchActivityTimeSeries(self.selectedRange) { ts in
                series = ts
                g.leave()
            }
            g.notify(queue: .main) { [weak self] in
                guard let self = self else { return }
                self.showLoading(false)
                if useRefreshControl { self.refreshControl.endRefreshing() }
                self.summary = summary
                self.timeSeries = series
                self.updateSummary()
                self.updateCharts()
            }
        }
    }

    private var loadingOverlay: UIView?
    private func showLoading(_ show: Bool) {
        if show {
            let ov = UIView()
            ov.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            ov.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(ov)
            let sp = UIActivityIndicatorView(style: .medium)
            sp.color = .white
            sp.translatesAutoresizingMaskIntoConstraints = false
            sp.startAnimating()
            ov.addSubview(sp)
            NSLayoutConstraint.activate([
                ov.topAnchor.constraint(equalTo: view.topAnchor),
                ov.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                ov.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                ov.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                sp.centerXAnchor.constraint(equalTo: ov.centerXAnchor),
                sp.centerYAnchor.constraint(equalTo: ov.centerYAnchor),
            ])
            loadingOverlay = ov
        } else {
            loadingOverlay?.removeFromSuperview()
            loadingOverlay = nil
        }
    }

    private func updateSummary() {
        guard let s = summary else {
            [stepsValueLabel, distanceValueLabel, caloriesValueLabel, exerciseValueLabel, flightsValueLabel, moveValueLabel, standValueLabel]
                .forEach { $0??.text = "—" }
            activityRingsCard.showPlaceholder()
            return
        }
        func fmt(_ v: Double?, _ f: (Double) -> String, _ u: String) -> String {
            guard let x = v, x >= 0 else { return u.isEmpty ? "—" : "—" }
            return u.isEmpty ? f(x) : "\(f(x)) \(u)"
        }
        stepsValueLabel?.text = fmt(s.steps, { String(format: "%.0f", $0) }, "")
        distanceValueLabel?.text = fmt(s.distanceKm, { String(format: "%.2f", $0) }, "activity.km".localized)
        caloriesValueLabel?.text = fmt(s.activeEnergyKcal, { String(format: "%.0f", $0) }, "kcal")
        exerciseValueLabel?.text = fmt(s.exerciseMinutes, { String(format: "%.0f", $0) }, "activity.min".localized)
        flightsValueLabel?.text = fmt(s.flightsClimbed, { String(format: "%.0f", $0) }, "")
        moveValueLabel?.text = fmt(s.activeEnergyKcal, { String(format: "%.0f", $0) }, "kcal")
        standValueLabel?.text = fmt(s.standHours, { String(format: "%.1f", $0) }, "activity.hours".localized)

        // Update Activity Rings - adjust goal by range
        let multiplier: Double
        switch selectedRange {
        case .day: multiplier = 1.0
        case .week: multiplier = 7.0
        case .month: multiplier = 30.0
        }

        activityRingsCard.configure(
            moveCalories: s.activeEnergyKcal,
            moveGoal: 500 * multiplier,
            exerciseMinutes: s.exerciseMinutes,
            exerciseGoal: 30 * multiplier,
            standHours: s.standHours,
            standGoal: 12 * multiplier,
            animated: true
        )
    }

    private func updateCharts() {
        let stepsData = timeSeries?.steps ?? StepsGraphData(points: [], periodLabel: "")
        let distData = timeSeries?.distance ?? EfficiencyGraphData(points: [], periodLabel: "")
        let energyData = timeSeries?.energy ?? GlucoseEnergyGraphData(points: [], periodLabel: "")

        let hasSteps = stepsData.points.contains { $0.steps > 0 }
        let hasDist = distData.points.contains { ($0.distanceKm ?? 0) > 0 }
        let hasEnergy = energyData.points.contains { ($0.activeEnergy ?? 0) > 0 }

        if hasSteps {
            replaceChartHost(&stepsHosting, in: stepsChartCard, with: UIHostingController(rootView: StepsChartView(data: stepsData)))
        } else {
            replaceChartHost(&stepsHosting, in: stepsChartCard, with: UIHostingController(rootView: ChartPlaceholderView(message: "activity.noStepsData".localized, icon: "chart.bar.fill")))
        }
        if hasDist {
            replaceChartHost(&distanceHosting, in: distanceChartCard, with: UIHostingController(rootView: DistanceChartView(data: distData)))
        } else {
            replaceChartHost(&distanceHosting, in: distanceChartCard, with: UIHostingController(rootView: ChartPlaceholderView(message: "activity.noDistanceData".localized, icon: "figure.walk")))
        }
        if hasEnergy {
            replaceChartHost(&energyHosting, in: energyChartCard, with: UIHostingController(rootView: ActiveEnergyChartView(data: energyData)))
        } else {
            replaceChartHost(&energyHosting, in: energyChartCard, with: UIHostingController(rootView: ChartPlaceholderView(message: "activity.noCaloriesData".localized, icon: "flame.fill")))
        }
    }

    private func replaceChartHost(_ stored: inout UIViewController?, in card: UIView, with newHost: UIHostingController<some View>) {
        stored?.view.removeFromSuperview()
        stored?.removeFromParent()
        newHost.view.backgroundColor = .clear
        newHost.view.clipsToBounds = false
        newHost.view.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(newHost.view)
        addChild(newHost)
        newHost.didMove(toParent: self)
        NSLayoutConstraint.activate([
            newHost.view.topAnchor.constraint(equalTo: card.topAnchor, constant: 48),
            newHost.view.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            newHost.view.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            newHost.view.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -AIONDesign.spacing),
            newHost.view.heightAnchor.constraint(equalToConstant: 180),
        ])
        stored = newHost
    }
}
