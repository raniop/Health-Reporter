//
//  HealthDashboardViewController.swift
//  Health Reporter
//
//  AION Performance Lab – עיצוב חדש, 6 גרפים, בחירת טווח (יום/שבוע/חודש).
//

import UIKit
import HealthKit
import SwiftUI

class HealthDashboardViewController: UIViewController {

    private var selectedRange: DataRange = .week
    private var chartBundle: AIONChartDataBundle?
    private var healthData: HealthDataModel?
    private var insightsText: String = ""
    private var recommendationsText: String = ""
    private var loadId: Int = 0

    private let scrollView: UIScrollView = {
        let v = UIScrollView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.showsVerticalScrollIndicator = false
        return v
    }()

    private let contentStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = AIONDesign.spacingLarge
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let periodLabel: UILabel = {
        let l = UILabel()
        l.font = AIONDesign.captionFont()
        l.textColor = AIONDesign.textTertiary
        l.textAlignment = .center
        l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let segmentControl: UISegmentedControl = {
        let items = DataRange.allCases.map { $0.segmentTitle() }
        let s = UISegmentedControl(items: items)
        s.selectedSegmentIndex = 1
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let refreshButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("רענן נתונים", for: .normal)
        b.titleLabel?.font = AIONDesign.headlineFont()
        b.backgroundColor = AIONDesign.accentPrimary
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = AIONDesign.cornerRadius
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let loadingOverlay: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()

    private let loadingLabel: UILabel = {
        let l = UILabel()
        l.text = "טוען..."
        l.font = AIONDesign.bodyFont()
        l.textColor = AIONDesign.textPrimary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let loadingSpinner: UIActivityIndicatorView = {
        let i = UIActivityIndicatorView(style: .large)
        i.translatesAutoresizingMaskIntoConstraints = false
        return i
    }()

    private let chartsContainer: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = AIONDesign.spacingLarge
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let actionsStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = AIONDesign.spacing
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private var insightsButton: UIButton?
    private var recommendationsButton: UIButton?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AIONDesign.background
        title = "AION"
        setupUI()
        segmentControl.addTarget(self, action: #selector(periodChanged), for: .valueChanged)
        refreshButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)
        updatePeriodLabel()
        checkHealthKitAuthorization()
    }

    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        contentStack.addArrangedSubview(periodLabel)
        contentStack.addArrangedSubview(segmentControl)
        contentStack.addArrangedSubview(refreshButton)
        contentStack.addArrangedSubview(chartsContainer)
        contentStack.addArrangedSubview(actionsStack)

        refreshButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        segmentControl.heightAnchor.constraint(equalToConstant: 36).isActive = true

        addChartPlaceholders()
        addActionButtons()

        view.addSubview(loadingOverlay)
        loadingOverlay.addSubview(loadingSpinner)
        loadingOverlay.addSubview(loadingLabel)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: AIONDesign.spacingLarge),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: AIONDesign.spacing),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -AIONDesign.spacing),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -AIONDesign.spacingLarge),

            loadingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            loadingSpinner.centerXAnchor.constraint(equalTo: loadingOverlay.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: loadingOverlay.centerYAnchor, constant: -24),
            loadingLabel.topAnchor.constraint(equalTo: loadingSpinner.bottomAnchor, constant: 16),
            loadingLabel.centerXAnchor.constraint(equalTo: loadingOverlay.centerXAnchor),
        ])
    }

    private func addChartPlaceholders() {
        let titles = [
            "1. מטריצת מוכנות (התאוששות vs עומס)",
            "2. יעילות קרדיו (דופק vs מרחק)",
            "3. ארכיטקטורת שינה",
            "4. גלוקוז ואנרגיה",
            "5. איזון אוטונומי",
            "6. תזונה vs יעדים",
        ]
        for t in titles {
            let card = makeChartCard(title: t, height: 180)
            chartsContainer.addArrangedSubview(card)
        }
    }

    private func makeChartCard(title: String, height: CGFloat) -> UIView {
        let card = UIView()
        card.backgroundColor = AIONDesign.surface
        card.layer.cornerRadius = AIONDesign.cornerRadius
        card.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = title
        label.font = AIONDesign.captionFont()
        label.textColor = AIONDesign.textSecondary
        label.translatesAutoresizingMaskIntoConstraints = false

        let container = UIView()
        container.backgroundColor = AIONDesign.background
        container.layer.cornerRadius = AIONDesign.cornerRadius - 4
        container.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(label)
        card.addSubview(container)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: AIONDesign.spacing),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: AIONDesign.spacing),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -AIONDesign.spacing),
            container.topAnchor.constraint(equalTo: label.bottomAnchor, constant: AIONDesign.spacing),
            container.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: AIONDesign.spacing),
            container.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -AIONDesign.spacing),
            container.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -AIONDesign.spacing),
            container.heightAnchor.constraint(equalToConstant: height),
        ])
        return card
    }

    private func addActionButtons() {
        let insights = UIButton(type: .system)
        insights.setTitle("תובנות AION", for: .normal)
        insights.titleLabel?.font = AIONDesign.headlineFont()
        insights.backgroundColor = AIONDesign.accentSecondary
        insights.setTitleColor(.white, for: .normal)
        insights.layer.cornerRadius = AIONDesign.cornerRadius
        insights.translatesAutoresizingMaskIntoConstraints = false
        insights.addTarget(self, action: #selector(showInsightsTapped), for: .touchUpInside)

        let recs = UIButton(type: .system)
        recs.setTitle("המלצות", for: .normal)
        recs.titleLabel?.font = AIONDesign.headlineFont()
        recs.backgroundColor = AIONDesign.surface
        recs.setTitleColor(AIONDesign.accentPrimary, for: .normal)
        recs.layer.cornerRadius = AIONDesign.cornerRadius
        recs.layer.borderWidth = 1
        recs.layer.borderColor = AIONDesign.separator.cgColor
        recs.translatesAutoresizingMaskIntoConstraints = false
        recs.addTarget(self, action: #selector(showRecommendationsTapped), for: .touchUpInside)

        insightsButton = insights
        recommendationsButton = recs

        [insights, recs].forEach {
            $0.heightAnchor.constraint(equalToConstant: 50).isActive = true
            actionsStack.addArrangedSubview($0)
        }
    }

    private func setAnalyzingState() {
        insightsButton?.setTitle("מנתח...", for: .normal)
        insightsButton?.isEnabled = false
        recommendationsButton?.isEnabled = false
    }

    private func clearAnalyzingState() {
        insightsButton?.setTitle("תובנות AION", for: .normal)
        insightsButton?.isEnabled = true
        recommendationsButton?.isEnabled = true
    }

    private func updatePeriodLabel() {
        periodLabel.text = selectedRange.displayLabel()
    }

    @objc private func periodChanged() {
        selectedRange = DataRange.allCases[segmentControl.selectedSegmentIndex]
        updatePeriodLabel()
        loadData()
    }

    @objc private func refreshTapped() {
        loadData()
    }

    @objc private func showInsightsTapped() {
        guard !insightsText.isEmpty else {
            showAlert(title: "אין נתונים", message: "הנתונים טוענים או שהניתוח עדיין רץ. נא להמתין או לרענן.")
            return
        }
        let vc = InsightsViewController()
        vc.insightsText = insightsText
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    @objc private func showRecommendationsTapped() {
        guard !recommendationsText.isEmpty else {
            showAlert(title: "אין נתונים", message: "הנתונים טוענים או שהניתוח עדיין רץ. נא להמתין או לרענן.")
            return
        }
        let vc = RecommendationsViewController()
        vc.recommendationsText = recommendationsText
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    private func checkHealthKitAuthorization() {
        guard HealthKitManager.shared.isHealthDataAvailable() else {
            showAlert(title: "שגיאה", message: "HealthKit לא זמין במכשיר זה.")
            return
        }
        HealthKitManager.shared.requestAuthorization { [weak self] ok, err in
            DispatchQueue.main.async {
                if ok { self?.loadData() }
                else { self?.showAlert(title: "הרשאה נדחתה", message: "אנא אפשר גישה לנתוני בריאות בהגדרות.") }
            }
        }
    }

    private func loadData() {
        loadId += 1
        let currentLoadId = loadId
        GeminiService.shared.cancelCurrentRequest()
        showLoading("טוען נתונים...")
        HealthKitManager.shared.fetchAllHealthData(for: selectedRange) { [weak self] data, err in
            guard let self = self else { return }
            if let err = err {
                DispatchQueue.main.async {
                    self.hideLoading()
                    self.showAlert(title: "שגיאה", message: err.localizedDescription)
                }
                return
            }
            self.healthData = data
            HealthKitManager.shared.fetchChartData(for: self.selectedRange) { [weak self] bundle in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.chartBundle = bundle
                    self.rebuildCharts()
                    self.hideLoading()
                    self.setAnalyzingState()
                }
                self.runAIONAnalysis(chartBundle: bundle, loadId: currentLoadId)
            }
        }
    }

    private func runAIONAnalysis(chartBundle: AIONChartDataBundle?, loadId: Int) {
        let calendar = Calendar.current
        let now = Date()
        guard let curStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)),
              let curEnd = calendar.date(byAdding: .day, value: 6, to: curStart),
              let prevStart = calendar.date(byAdding: .weekOfYear, value: -1, to: curStart),
              let prevEnd = calendar.date(byAdding: .day, value: 6, to: prevStart) else {
            analyzeWithGemini(loadId: loadId)
            return
        }
        let g = DispatchGroup()
        var cur: WeeklyHealthSnapshot?
        var prev: WeeklyHealthSnapshot?
        g.enter()
        HealthKitManager.shared.createWeeklySnapshot(weekStartDate: prevStart, weekEndDate: prevEnd) { prev = $0; g.leave() }
        g.enter()
        HealthKitManager.shared.createWeeklySnapshot(weekStartDate: curStart, weekEndDate: curEnd, previousWeekSnapshot: nil) { cur = $0; g.leave() }
        g.notify(queue: .main) { [weak self] in
            guard let self = self, let c = cur, let p = prev else {
                self?.analyzeWithGemini(loadId: loadId)
                return
            }
            self.analyzeWithGeminiWoW(current: c, previous: p, chartBundle: chartBundle, loadId: loadId)
        }
    }

    private func analyzeWithGemini(loadId: Int) {
        guard let data = healthData else {
            clearAnalyzingState()
            return
        }
        GeminiService.shared.analyzeHealthData(data) { [weak self] insights, recs, risks, err in
            DispatchQueue.main.async {
                guard let self = self, self.loadId == loadId else { return }
                self.clearAnalyzingState()
                if let err = err {
                    if (err as NSError).code == NSURLErrorCancelled { return }
                    let msg = (err as NSError).code == NSURLErrorTimedOut
                        ? "הבקשה ל‑Gemini התמשכה מדי. ייתכן חיבור איטי או עומס – נסה שוב."
                        : err.localizedDescription
                    self.showAlert(title: "שגיאה", message: msg)
                    return
                }
                self.applyAnalysis(insights: insights, recs: recs, risks: risks)
            }
        }
    }

    private func analyzeWithGeminiWoW(current: WeeklyHealthSnapshot, previous: WeeklyHealthSnapshot, chartBundle: AIONChartDataBundle?, loadId: Int) {
        guard let data = healthData else {
            clearAnalyzingState()
            return
        }
        GeminiService.shared.analyzeHealthDataWithWeeklyComparison(data, currentWeek: current, previousWeek: previous, chartBundle: chartBundle) { [weak self] insights, recs, risks, err in
            DispatchQueue.main.async {
                guard let self = self, self.loadId == loadId else { return }
                self.clearAnalyzingState()
                if let err = err {
                    if (err as NSError).code == NSURLErrorCancelled { return }
                    let msg = (err as NSError).code == NSURLErrorTimedOut
                        ? "הבקשה ל‑Gemini התמשכה מדי. ייתכן חיבור איטי או עומס – נסה שוב."
                        : err.localizedDescription
                    self.showAlert(title: "שגיאה", message: msg)
                    return
                }
                self.applyAnalysis(insights: insights, recs: recs, risks: risks)
            }
        }
    }

    private func applyAnalysis(insights: String?, recs: [String]?, risks: [String]?) {
        var text = insights ?? "לא התקבלו תובנות."
        if let r = recs, !r.isEmpty {
            text += "\n\nהמלצות:\n"
            r.enumerated().forEach { text += "\($0.offset + 1). \($0.element)\n" }
        }
        if let r = risks, !r.isEmpty {
            text += "\n\nגורמי סיכון:\n"
            r.enumerated().forEach { text += "\($0.offset + 1). \($0.element)\n" }
        }
        insightsText = text
        recommendationsText = (recs ?? []).joined(separator: "\n\n")
        if recommendationsText.isEmpty { recommendationsText = "אין המלצות זמינות כרגע." }
    }

    private func rebuildCharts() {
        chartsContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard let b = chartBundle else {
            addChartPlaceholders()
            return
        }
        chartsContainer.addArrangedSubview(makeChartCardWithHosting(title: "1. מטריצת מוכנות (התאוששות vs עומס)", chartView: ReadinessChartView(data: b.readiness), height: 180))
        chartsContainer.addArrangedSubview(makeChartCardWithHosting(title: "2. יעילות קרדיו (דופק vs מרחק)", chartView: EfficiencyChartView(data: b.efficiency), height: 180))
        chartsContainer.addArrangedSubview(makeChartCardWithHosting(title: "3. ארכיטקטורת שינה", chartView: SleepArchitectureChartView(data: b.sleep), height: 180))
        chartsContainer.addArrangedSubview(makeChartCardWithHosting(title: "4. גלוקוז ואנרגיה", chartView: GlucoseEnergyChartView(data: b.glucoseEnergy), height: 180))
        chartsContainer.addArrangedSubview(makeChartCardWithHosting(title: "5. איזון אוטונומי", chartView: AutonomicRadarChartView(data: b.autonomic), height: 180))
        chartsContainer.addArrangedSubview(makeChartCardWithHosting(title: "6. תזונה vs יעדים", chartView: NutritionChartView(data: b.nutrition), height: 180))
    }

    private func makeChartCardWithHosting<Content: View>(title: String, chartView: Content, height: CGFloat) -> UIView {
        let card = UIView()
        card.backgroundColor = AIONDesign.surface
        card.layer.cornerRadius = AIONDesign.cornerRadius
        card.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = title
        label.font = AIONDesign.captionFont()
        label.textColor = AIONDesign.textSecondary
        label.translatesAutoresizingMaskIntoConstraints = false

        let hosting = UIHostingController(rootView: chartView)
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(hosting)
        card.addSubview(label)
        card.addSubview(hosting.view)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: AIONDesign.spacing),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: AIONDesign.spacing),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -AIONDesign.spacing),
            hosting.view.topAnchor.constraint(equalTo: label.bottomAnchor, constant: AIONDesign.spacing),
            hosting.view.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: AIONDesign.spacing),
            hosting.view.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -AIONDesign.spacing),
            hosting.view.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -AIONDesign.spacing),
            hosting.view.heightAnchor.constraint(equalToConstant: height),
        ])
        hosting.didMove(toParent: self)
        return card
    }

    private func showLoading(_ msg: String) {
        loadingLabel.text = msg
        loadingOverlay.isHidden = false
        loadingSpinner.startAnimating()
        view.bringSubviewToFront(loadingOverlay)
    }

    private func hideLoading() {
        loadingOverlay.isHidden = true
        loadingSpinner.stopAnimating()
    }

    private func updateLoading(_ msg: String) {
        loadingLabel.text = msg
    }

    private func showAlert(title: String, message: String) {
        var top: UIViewController = self
        while let p = top.presentedViewController { top = p }
        if top is UIAlertController { return }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "אישור", style: .default))
        top.present(alert, animated: true)
    }
}
