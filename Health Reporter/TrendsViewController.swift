//
//  TrendsViewController.swift
//  Health Reporter
//
//  מגמות / קורלציות ביולוגיות – סגנון Biological Correlations.
//

import UIKit
import SwiftUI

final class TrendsViewController: UIViewController {

    private var chartBundle: AIONChartDataBundle?
    private var selectedDays = 30
    private var correlationValLabel: UILabel?
    private var correlationImpLabel: UILabel?
    private var pValueLabel: UILabel?
    private var sampleSizeLabel: UILabel?
    private var chartHosting: UIViewController?
    private var insightMainLabel: UILabel?
    private var bioHrvLabel: UILabel?
    private var bioStrainLabel: UILabel?
    private var bioRhrLabel: UILabel?
    private var bioStepsLabel: UILabel?
    private var bioExerciseLabel: UILabel?
    private var focus1Label: UILabel?
    private var focus2Label: UILabel?

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let timeframeStack = UIStackView()
    private let insightCard = UIView()
    private let correlationCard = UIView()
    private let statsRow = UIStackView()
    private let biometricsRow = UIStackView()
    private let activityRow = UIStackView()
    private let focusStack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        // title removed - managed by parent UnifiedTrendsActivityViewController
        view.backgroundColor = AIONDesign.background
        view.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        setupTimeframe()
        setupInsightCard()
        setupCorrelationCard()
        setupStatsRow()
        setupBiometricsRow()
        setupActivityRow()
        setupFocusAreas()
        setupStack()
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

    private func setupTimeframe() {
        let labels = ["7D", "30D", "90D", "1Y"]
        timeframeStack.axis = .horizontal
        timeframeStack.spacing = 20
        timeframeStack.distribution = .fillEqually
        timeframeStack.translatesAutoresizingMaskIntoConstraints = false
        for (i, t) in labels.enumerated() {
            let b = UIButton(type: .system)
            b.setTitle(t, for: .normal)
            b.tag = i
            b.addTarget(self, action: #selector(timeframeTapped(_:)), for: .touchUpInside)
            b.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
            timeframeStack.addArrangedSubview(b)
            updateTimeframeStyle(button: b, selected: selectedDays == [7, 30, 90, 365][i])
        }
    }

    private func updateTimeframeStyle(button: UIButton, selected: Bool) {
        button.setTitleColor(selected ? AIONDesign.textPrimary : AIONDesign.textTertiary, for: .normal)
        let days = [7, 30, 90, 365][button.tag]
        if selected { selectedDays = days }
    }

    @objc private func timeframeTapped(_ sender: UIButton) {
        for v in timeframeStack.arrangedSubviews {
            guard let b = v as? UIButton else { continue }
            updateTimeframeStyle(button: b, selected: b == sender)
        }
        selectedDays = [7, 30, 90, 365][sender.tag]
        loadData()
    }

    private func setupInsightCard() {
        insightCard.backgroundColor = AIONDesign.surface
        insightCard.layer.cornerRadius = AIONDesign.cornerRadius
        insightCard.translatesAutoresizingMaskIntoConstraints = false

        let pro = UILabel()
        pro.text = "PRO-LAB INSIGHT"
        pro.font = .systemFont(ofSize: 11, weight: .bold)
        pro.textColor = AIONDesign.accentPrimary
        pro.textAlignment = .center

        let main = UILabel()
        main.text = "trends.loadingBiometrics".localized
        main.font = .systemFont(ofSize: 17, weight: .bold)
        main.textColor = AIONDesign.textPrimary
        main.textAlignment = .center
        main.numberOfLines = 0
        insightMainLabel = main

        let sub = UILabel()
        sub.text = "trends.basedOnPeriod".localized
        sub.font = .systemFont(ofSize: 13, weight: .regular)
        sub.textColor = AIONDesign.textSecondary
        sub.textAlignment = .center
        sub.numberOfLines = 0

        [pro, main, sub].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        insightCard.addSubview(pro)
        insightCard.addSubview(main)
        insightCard.addSubview(sub)
        let info = CardInfoButton.make(explanation: CardExplanations.insight)
        info.addTarget(self, action: #selector(cardInfoTapped(_:)), for: .touchUpInside)
        insightCard.addSubview(info)
        NSLayoutConstraint.activate([
            pro.topAnchor.constraint(equalTo: insightCard.topAnchor, constant: AIONDesign.spacing + 4),
            pro.leadingAnchor.constraint(equalTo: insightCard.leadingAnchor, constant: AIONDesign.spacing),
            pro.trailingAnchor.constraint(equalTo: insightCard.trailingAnchor, constant: -AIONDesign.spacing),
            main.topAnchor.constraint(equalTo: pro.bottomAnchor, constant: 10),
            main.leadingAnchor.constraint(equalTo: insightCard.leadingAnchor, constant: AIONDesign.spacing),
            main.trailingAnchor.constraint(equalTo: insightCard.trailingAnchor, constant: -AIONDesign.spacing),
            sub.topAnchor.constraint(equalTo: main.bottomAnchor, constant: 8),
            sub.leadingAnchor.constraint(equalTo: insightCard.leadingAnchor, constant: AIONDesign.spacing),
            sub.trailingAnchor.constraint(equalTo: insightCard.trailingAnchor, constant: -AIONDesign.spacing),
            sub.bottomAnchor.constraint(equalTo: insightCard.bottomAnchor, constant: -(AIONDesign.spacing + 6)),
            info.topAnchor.constraint(equalTo: insightCard.topAnchor, constant: AIONDesign.spacing),
            info.leftAnchor.constraint(equalTo: insightCard.leftAnchor, constant: AIONDesign.spacing),
        ])
    }

    @objc private func cardInfoTapped(_ sender: CardInfoButton) {
        let alert = UIAlertController(title: "dashboard.explanation".localized, message: sender.explanation, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "understand".localized, style: .default))
        present(alert, animated: true)
    }

    private func setupCorrelationCard() {
        correlationCard.backgroundColor = AIONDesign.surface
        correlationCard.layer.cornerRadius = AIONDesign.cornerRadius
        correlationCard.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = "trends.correlationEfficiency".localized
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.textColor = AIONDesign.textPrimary
        title.textAlignment = .center

        let val = UILabel()
        val.text = "—"
        val.font = .systemFont(ofSize: 28, weight: .bold)
        val.textColor = AIONDesign.accentPrimary
        val.textAlignment = .center

        let imp = UILabel()
        imp.text = ""
        imp.font = .systemFont(ofSize: 13, weight: .medium)
        imp.textColor = AIONDesign.accentSuccess
        imp.textAlignment = .center

        correlationValLabel = val
        correlationImpLabel = imp
        [title, val, imp].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        correlationCard.addSubview(title)
        correlationCard.addSubview(val)
        correlationCard.addSubview(imp)
        let info = CardInfoButton.make(explanation: CardExplanations.correlation)
        info.addTarget(self, action: #selector(cardInfoTapped(_:)), for: .touchUpInside)
        correlationCard.addSubview(info)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: correlationCard.topAnchor, constant: AIONDesign.spacing + 4),
            title.leadingAnchor.constraint(equalTo: correlationCard.leadingAnchor, constant: AIONDesign.spacing),
            title.trailingAnchor.constraint(equalTo: correlationCard.trailingAnchor, constant: -AIONDesign.spacing),
            val.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 10),
            val.leadingAnchor.constraint(equalTo: correlationCard.leadingAnchor, constant: AIONDesign.spacing),
            imp.centerYAnchor.constraint(equalTo: val.centerYAnchor),
            imp.trailingAnchor.constraint(equalTo: correlationCard.trailingAnchor, constant: -AIONDesign.spacing),
            val.trailingAnchor.constraint(lessThanOrEqualTo: imp.leadingAnchor, constant: -8),
            info.topAnchor.constraint(equalTo: correlationCard.topAnchor, constant: AIONDesign.spacing),
            info.leftAnchor.constraint(equalTo: correlationCard.leftAnchor, constant: AIONDesign.spacing),
        ])
    }

    private func addCorrelationChart(bundle: AIONChartDataBundle) {
        chartHosting?.view.removeFromSuperview()
        chartHosting?.removeFromParent()
        guard let anchor = correlationValLabel else { return }
        let chart = RecoveryTrendChartView(data: bundle.readiness)
        let hosting = UIHostingController(rootView: chart)
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(hosting)
        correlationCard.addSubview(hosting.view)
        hosting.didMove(toParent: self)
        chartHosting = hosting
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: anchor.bottomAnchor, constant: AIONDesign.spacing),
            hosting.view.leadingAnchor.constraint(equalTo: correlationCard.leadingAnchor, constant: AIONDesign.spacing),
            hosting.view.trailingAnchor.constraint(equalTo: correlationCard.trailingAnchor, constant: -AIONDesign.spacing),
            hosting.view.heightAnchor.constraint(equalToConstant: 160),
            hosting.view.bottomAnchor.constraint(equalTo: correlationCard.bottomAnchor, constant: -AIONDesign.spacing),
        ])
    }

    private func setupStatsRow() {
        statsRow.axis = .horizontal
        statsRow.spacing = AIONDesign.spacing
        statsRow.distribution = .fillEqually
        statsRow.translatesAutoresizingMaskIntoConstraints = false

        let (p, pLbl) = makeStatCard(title: "trends.pValue".localized, value: "—", explanation: CardExplanations.pValue)
        let (s, sLbl) = makeStatCard(title: "trends.sampleSize".localized, value: "—", explanation: CardExplanations.sampleSize)
        pValueLabel = pLbl
        sampleSizeLabel = sLbl
        statsRow.addArrangedSubview(p)
        statsRow.addArrangedSubview(s)
    }

    private func setupBiometricsRow() {
        biometricsRow.axis = .horizontal
        biometricsRow.spacing = AIONDesign.spacing
        biometricsRow.distribution = .fillEqually
        biometricsRow.translatesAutoresizingMaskIntoConstraints = false
        let (c1, l1) = makeBioCard("trends.avgHrv".localized, value: "— ms", icon: "heart.fill")
        let (c2, l2) = makeBioCard("trends.strain".localized, value: "—", icon: "bolt.fill")
        let (c3, l3) = makeBioCard("trends.restingHR".localized, value: "— bpm", icon: "waveform.path.ecg")
        bioHrvLabel = l1
        bioStrainLabel = l2
        bioRhrLabel = l3
        [c1, c2, c3].forEach { biometricsRow.addArrangedSubview($0) }
        biometricsRow.heightAnchor.constraint(equalToConstant: 96).isActive = true
    }

    private func setupActivityRow() {
        activityRow.axis = .horizontal
        activityRow.spacing = AIONDesign.spacing
        activityRow.distribution = .fillEqually
        activityRow.translatesAutoresizingMaskIntoConstraints = false
        let (c1, l1) = makeBioCard("trends.steps".localized, value: "—", icon: "figure.walk", color: .systemOrange, explanation: CardExplanations.activitySteps)
        let (c2, l2) = makeBioCard("trends.exerciseMinutes".localized, value: "— \("activity.min".localized)", icon: "flame.fill", color: .systemGreen, explanation: CardExplanations.activityExercise)
        bioStepsLabel = l1
        bioExerciseLabel = l2
        [c1, c2].forEach { activityRow.addArrangedSubview($0) }
        activityRow.heightAnchor.constraint(equalToConstant: 96).isActive = true
    }

    private func makeBioCard(_ title: String, value: String, icon: String, color: UIColor? = nil, explanation: String = CardExplanations.biometrics) -> (UIView, UILabel) {
        let c = UIView()
        c.backgroundColor = AIONDesign.surface
        c.layer.cornerRadius = AIONDesign.cornerRadius
        let iv = UIImageView(image: UIImage(systemName: icon))
        iv.tintColor = color ?? AIONDesign.accentPrimary
        iv.contentMode = .scaleAspectFit
        let t = UILabel()
        t.text = title
        t.font = .systemFont(ofSize: 10, weight: .semibold)
        t.textColor = AIONDesign.textSecondary
        t.textAlignment = .center
        let v = UILabel()
        v.text = value
        v.font = .systemFont(ofSize: 15, weight: .bold)
        v.textColor = AIONDesign.textPrimary
        v.textAlignment = .center
        [iv, t, v].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        c.addSubview(iv)
        c.addSubview(t)
        c.addSubview(v)
        let info = CardInfoButton.make(explanation: explanation)
        info.addTarget(self, action: #selector(cardInfoTapped(_:)), for: .touchUpInside)
        c.addSubview(info)
        NSLayoutConstraint.activate([
            iv.topAnchor.constraint(equalTo: c.topAnchor, constant: 12),
            iv.centerXAnchor.constraint(equalTo: c.centerXAnchor),
            iv.widthAnchor.constraint(equalToConstant: 18),
            iv.heightAnchor.constraint(equalToConstant: 18),
            t.topAnchor.constraint(equalTo: iv.bottomAnchor, constant: 8),
            t.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 8),
            t.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -8),
            v.topAnchor.constraint(equalTo: t.bottomAnchor, constant: 6),
            v.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 8),
            v.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -8),
            v.bottomAnchor.constraint(equalTo: c.bottomAnchor, constant: -14),
            info.topAnchor.constraint(equalTo: c.topAnchor, constant: 10),
            info.leftAnchor.constraint(equalTo: c.leftAnchor, constant: AIONDesign.spacing),
        ])
        return (c, v)
    }

    private func setupFocusAreas() {
        focusStack.axis = .vertical
        focusStack.spacing = AIONDesign.spacing
        focusStack.translatesAutoresizingMaskIntoConstraints = false
        let header = UILabel()
        header.text = "trends.focusAreas".localized
        header.font = .systemFont(ofSize: 12, weight: .bold)
        header.textColor = AIONDesign.accentPrimary
        header.textAlignment = LocalizationManager.shared.textAlignment
        let (f1, l1) = makeFocusRow(icon: "moon.fill", text: "trends.sleepConsistency".localized)
        let (f2, l2) = makeFocusRow(icon: "arrow.up.forward", text: "trends.vo2Opportunity".localized)
        focus1Label = l1
        focus2Label = l2
        focusStack.addArrangedSubview(header)
        focusStack.addArrangedSubview(f1)
        focusStack.addArrangedSubview(f2)
    }

    private func makeFocusRow(icon: String, text: String) -> (UIView, UILabel) {
        let row = UIView()
        row.backgroundColor = AIONDesign.surface
        row.layer.cornerRadius = AIONDesign.cornerRadius
        let iv = UIImageView(image: UIImage(systemName: icon))
        iv.tintColor = AIONDesign.accentSecondary
        iv.contentMode = .scaleAspectFit
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: 14, weight: .regular)
        l.textColor = AIONDesign.textPrimary
        l.textAlignment = LocalizationManager.shared.textAlignment
        l.numberOfLines = 0
        [iv, l].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        row.addSubview(iv)
        row.addSubview(l)
        let info = CardInfoButton.make(explanation: CardExplanations.focus)
        info.addTarget(self, action: #selector(cardInfoTapped(_:)), for: .touchUpInside)
        row.addSubview(info)
        NSLayoutConstraint.activate([
            info.topAnchor.constraint(equalTo: row.topAnchor, constant: 12),
            info.leftAnchor.constraint(equalTo: row.leftAnchor, constant: AIONDesign.spacing),
            iv.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -AIONDesign.spacing),
            iv.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            iv.widthAnchor.constraint(equalToConstant: 24),
            iv.heightAnchor.constraint(equalToConstant: 24),
            l.topAnchor.constraint(equalTo: row.topAnchor, constant: 12),
            l.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -14),
            l.leadingAnchor.constraint(equalTo: info.trailingAnchor, constant: 10),
            l.trailingAnchor.constraint(equalTo: iv.leadingAnchor, constant: -10),
        ])
        return (row, l)
    }

    private func makeStatCard(title: String, value: String, explanation: String) -> (UIView, UILabel) {
        let c = UIView()
        c.backgroundColor = AIONDesign.surface
        c.layer.cornerRadius = AIONDesign.cornerRadius
        let t = UILabel()
        t.text = title
        t.font = .systemFont(ofSize: 11, weight: .medium)
        t.textColor = AIONDesign.textSecondary
        t.textAlignment = .center
        let v = UILabel()
        v.text = value
        v.font = .systemFont(ofSize: 15, weight: .bold)
        v.textColor = AIONDesign.textPrimary
        v.textAlignment = .center
        [t, v].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        c.addSubview(t)
        c.addSubview(v)
        let info = CardInfoButton.make(explanation: explanation)
        info.addTarget(self, action: #selector(cardInfoTapped(_:)), for: .touchUpInside)
        c.addSubview(info)
        NSLayoutConstraint.activate([
            t.topAnchor.constraint(equalTo: c.topAnchor, constant: AIONDesign.spacing + 6),
            t.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 10),
            t.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -10),
            v.topAnchor.constraint(equalTo: t.bottomAnchor, constant: 10),
            v.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 10),
            v.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -10),
            v.bottomAnchor.constraint(equalTo: c.bottomAnchor, constant: -(AIONDesign.spacing + 8)),
            info.topAnchor.constraint(equalTo: c.topAnchor, constant: 10),
            info.leftAnchor.constraint(equalTo: c.leftAnchor, constant: AIONDesign.spacing),
        ])
        return (c, v)
    }

    private func sectionHeader(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: 11, weight: .bold)
        l.textColor = AIONDesign.accentPrimary
        l.textAlignment = LocalizationManager.shared.textAlignment
        return l
    }

    private func setupStack() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        view.addSubview(scrollView)
        stack.axis = .vertical
        stack.spacing = AIONDesign.spacingLarge
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        stack.addArrangedSubview(timeframeStack)
        stack.addArrangedSubview(insightCard)
        stack.addArrangedSubview(correlationCard)
        stack.addArrangedSubview(statsRow)
        stack.addArrangedSubview(sectionHeader("trends.bioTrends".localized))
        stack.addArrangedSubview(biometricsRow)
        stack.addArrangedSubview(sectionHeader("trends.activity".localized))
        stack.addArrangedSubview(activityRow)
        stack.addArrangedSubview(focusStack)

        NSLayoutConstraint.activate([
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

    private func loadData() {
        let range: DataRange = selectedDays <= 7 ? .day : (selectedDays <= 30 ? .week : .month)
        HealthKitManager.shared.fetchChartData(for: range) { [weak self] bundle in
            DispatchQueue.main.async {
                self?.chartBundle = bundle
                self?.updateInsightFromBundle(bundle)
                self?.updateBiometricsAndFocus(bundle)
                self?.updateCorrelationStats(bundle)
                if let b = bundle { self?.addCorrelationChart(bundle: b) }
            }
        }

        // Fetch activity data for the selected period
        loadActivityData()
    }

    private func loadActivityData() {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -selectedDays, to: endDate) ?? endDate

        let group = DispatchGroup()
        var totalSteps: Double = 0
        var totalExercise: Double = 0

        // Fetch steps
        group.enter()
        HealthKitManager.shared.fetchSteps(startDate: startDate, endDate: endDate) { steps in
            totalSteps = steps ?? 0
            group.leave()
        }

        // Fetch exercise minutes
        group.enter()
        HealthKitManager.shared.fetchExerciseMinutes(startDate: startDate, endDate: endDate) { minutes in
            totalExercise = minutes ?? 0
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            self?.updateActivityLabels(steps: totalSteps, exerciseMinutes: totalExercise)
        }
    }

    private func updateActivityLabels(steps: Double, exerciseMinutes: Double) {
        // Format steps
        if steps > 0 {
            if steps >= 1000 {
                bioStepsLabel?.text = String(format: "%.1fK", steps / 1000)
            } else {
                bioStepsLabel?.text = String(format: "%.0f", steps)
            }
        } else {
            bioStepsLabel?.text = "—"
        }

        // Format exercise minutes
        if exerciseMinutes > 0 {
            bioExerciseLabel?.text = String(format: "%.0f \("activity.min".localized)", exerciseMinutes)
        } else {
            bioExerciseLabel?.text = "— \("activity.min".localized)"
        }
    }

    private func updateCorrelationStats(_ bundle: AIONChartDataBundle?) {
        guard let b = bundle, b.hasRealData else {
            correlationValLabel?.text = "—"
            correlationImpLabel?.text = ""
            pValueLabel?.text = "—"
            sampleSizeLabel?.text = "—"
            insightMainLabel?.text = "trends.noBiometricData".localized
            return
        }
        let r = b.readiness.points
        let sampleCount = r.count
        sampleSizeLabel?.text = "\(sampleCount) pts"

        // חישוב קורלציה בסיסית בין recovery ל-strain
        guard sampleCount >= 3 else {
            correlationValLabel?.text = "—"
            correlationImpLabel?.text = "trends.need3Days".localized
            pValueLabel?.text = "—"
            return
        }
        let recoveries = r.map(\.recovery)
        let strains = r.map(\.strain)
        let meanR = recoveries.reduce(0, +) / Double(sampleCount)
        let meanS = strains.reduce(0, +) / Double(sampleCount)
        var num: Double = 0, denR: Double = 0, denS: Double = 0
        for i in 0..<sampleCount {
            let dr = recoveries[i] - meanR
            let ds = strains[i] - meanS
            num += dr * ds
            denR += dr * dr
            denS += ds * ds
        }
        let den = sqrt(denR * denS)
        if den > 0 {
            let corr = num / den
            correlationValLabel?.text = String(format: "%.2f", corr)
            correlationImpLabel?.text = corr > 0 ? "trends.positiveCorrelation".localized : (corr < -0.3 ? "trends.negativeCorrelation".localized : "")
            // P-value approximation (t-test for Pearson r)
            let t = corr * sqrt(Double(sampleCount - 2) / (1 - corr * corr))
            let abst = abs(t)
            if abst > 3.5 { pValueLabel?.text = "< 0.001" }
            else if abst > 2.5 { pValueLabel?.text = "< 0.01" }
            else if abst > 2.0 { pValueLabel?.text = "< 0.05" }
            else { pValueLabel?.text = "> 0.05" }
        } else {
            correlationValLabel?.text = "—"
            correlationImpLabel?.text = ""
            pValueLabel?.text = "—"
        }
    }

    private func updateInsightFromBundle(_ bundle: AIONChartDataBundle?) {
        guard let b = bundle, b.hasRealData else {
            insightMainLabel?.text = "trends.noBiometricData".localized
            return
        }
        let sleep = b.sleep.points
        let r = b.readiness.points
        let n = min(selectedDays, 30)
        if let lastSleep = sleep.last, let h = lastSleep.totalHours, h >= 7, r.count >= 2 {
            let last = r[r.count - 1].recovery
            let prev = r[r.count - 2].recovery
            let delta = prev > 0 ? Int(round((last - prev) / prev * 100)) : 0
            insightMainLabel?.text = String(format: "trends.sleepBoostsRecovery".localized, String(format: "%.0f", h), delta)
        } else {
            insightMainLabel?.text = String(format: "trends.basedOnDays".localized, n)
        }
    }

    private func updateBiometricsAndFocus(_ bundle: AIONChartDataBundle?) {
        guard let b = bundle, b.hasRealData else {
            bioHrvLabel?.text = "— ms"
            bioStrainLabel?.text = "—"
            bioRhrLabel?.text = "— bpm"
            focus1Label?.text = "trends.noDataConnect".localized
            focus2Label?.text = "trends.sleepActivityData".localized
            return
        }
        let hrv = b.hrvTrend.points
        let avgHrv = hrv.isEmpty ? nil : hrv.map(\.value).reduce(0, +) / Double(hrv.count)
        bioHrvLabel?.text = avgHrv.map { String(format: "%.0f ms", $0) } ?? "— ms"
        if let last = b.readiness.points.last {
            bioStrainLabel?.text = String(format: "%.1f", last.strain)
        }
        let rhr = b.rhrTrend.points
        let avgRhr = rhr.isEmpty ? nil : rhr.map(\.value).reduce(0, +) / Double(rhr.count)
        bioRhrLabel?.text = avgRhr.map { String(format: "%.0f bpm", $0) } ?? "— bpm"

        let sleep = b.sleep.points
        if sleep.count >= 2, let a = sleep.last?.totalHours, let b0 = sleep.dropLast().last?.totalHours, a > 0, b0 > 0 {
            let diff = abs(a - b0) * 60
            focus1Label?.text = String(format: "trends.sleepGap".localized, Int(diff))
        } else {
            focus1Label?.text = "trends.sleepConsistency".localized
        }
        if let last = b.readiness.points.last, last.recovery >= 75 {
            focus2Label?.text = "trends.goodRecovery".localized
        } else {
            focus2Label?.text = "trends.trainingOpportunity".localized
        }
    }
}
