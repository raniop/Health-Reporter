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
        s.semanticContentAttribute = .forceRightToLeft
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let periodLabel: UILabel = {
        let l = UILabel()
        l.font = AIONDesign.captionFont()
        l.textColor = AIONDesign.textTertiary
        l.textAlignment = .right
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
        l.textColor = .white
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let loadingSpinner: UIActivityIndicatorView = {
        let i = UIActivityIndicatorView(style: .large)
        i.color = .white
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
    private var analyzingSpinner: UIActivityIndicatorView?

    private enum AnalysisCache {
        static let keyInsights = "AION.CachedInsights"
        static let keyRecommendations = "AION.CachedRecommendations"
        static let keyLastDate = "AION.LastAnalysisDate"
        static let maxAgeSeconds: TimeInterval = 24 * 3600
        static let fileName = "last_analysis.json"

        static var storageDirectory: URL? {
            guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
            let dir = base.appendingPathComponent("HealthReporter", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        }

        static var fileURL: URL? { storageDirectory?.appendingPathComponent(fileName) }

        /// שומר במכשיר: UserDefaults + קובץ ב־Application Support. הנתונים נשמרים תמיד לחזרה לעיון.
        static func save(insights: String, recommendations: String) {
            let now = Date()
            UserDefaults.standard.set(insights, forKey: keyInsights)
            UserDefaults.standard.set(recommendations, forKey: keyRecommendations)
            UserDefaults.standard.set(now, forKey: keyLastDate)
            guard let url = fileURL else { return }
            let payload: [String: Any] = [
                "insights": insights,
                "recommendations": recommendations,
                "date": ISO8601DateFormatter().string(from: now)
            ]
            guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
            try? data.write(to: url)
        }

        /// טוען מטמון: קודם UserDefaults; אם ריק – מקובץ מקומי. מחזיר nil אם אין נתונים או עברו 24h (לגבי שימוש כקאש).
        static func load() -> (insights: String, recommendations: String)? {
            if let fromUD = loadFromUserDefaults(), fromUD.2 { return (fromUD.0, fromUD.1) }
            if let fromFile = loadFromFile(), fromFile.2 { return (fromFile.0, fromFile.1) }
            return nil
        }

        private static func loadFromUserDefaults() -> (String, String, Bool)? {
            guard let last = UserDefaults.standard.object(forKey: keyLastDate) as? Date,
                  let ins = UserDefaults.standard.string(forKey: keyInsights),
                  let rec = UserDefaults.standard.string(forKey: keyRecommendations),
                  !ins.isEmpty else { return nil }
            let valid = Date().timeIntervalSince(last) < maxAgeSeconds
            return (ins, rec, valid)
        }

        private static func loadFromFile() -> (String, String, Bool)? {
            guard let url = fileURL, let data = try? Data(contentsOf: url),
                  let raw = try? JSONSerialization.jsonObject(with: data),
                  let json = raw as? [String: Any],
                  let ins = json["insights"] as? String, !ins.isEmpty,
                  let rec = json["recommendations"] as? String,
                  let dateStr = json["date"] as? String,
                  let last = ISO8601DateFormatter().date(from: dateStr) else { return nil }
            let valid = Date().timeIntervalSince(last) < maxAgeSeconds
            UserDefaults.standard.set(ins, forKey: keyInsights)
            UserDefaults.standard.set(rec, forKey: keyRecommendations)
            UserDefaults.standard.set(last, forKey: keyLastDate)
            return (ins, rec, valid)
        }

        static func shouldUseCache(forceAnalysis: Bool) -> Bool {
            guard !forceAnalysis else { return false }
            if let fromUD = loadFromUserDefaults() { return fromUD.2 }
            if let fromFile = loadFromFile() { return fromFile.2 }
            return false
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AIONDesign.background
        view.semanticContentAttribute = .forceRightToLeft
        title = "AION"
        setupUI()
        segmentControl.addTarget(self, action: #selector(periodChanged), for: .valueChanged)
        refreshButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)
        updatePeriodLabel()
        checkHealthKitAuthorization()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        recommendationsButton?.layer.borderColor = AIONDesign.separator.resolvedColor(with: traitCollection).cgColor
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
        card.semanticContentAttribute = .forceRightToLeft
        card.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = title
        label.font = AIONDesign.captionFont()
        label.textColor = AIONDesign.textSecondary
        label.textAlignment = .right
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
        var config = UIButton.Configuration.plain()
        config.title = "תובנות AION"
        config.baseForegroundColor = .white
        config.background.backgroundColor = AIONDesign.accentSecondary
        config.background.cornerRadius = AIONDesign.cornerRadius
        config.titleTextAttributesTransformer = .init { incoming in
            var out = incoming
            out.font = AIONDesign.headlineFont()
            return out
        }

        let insights = UIButton(type: .system)
        insights.configuration = config
        insights.translatesAutoresizingMaskIntoConstraints = false
        insights.semanticContentAttribute = .forceRightToLeft
        insights.addTarget(self, action: #selector(showInsightsTapped), for: .touchUpInside)

        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = .white
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        insights.addSubview(spinner)

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
        analyzingSpinner = spinner

        NSLayoutConstraint.activate([
            spinner.centerYAnchor.constraint(equalTo: insights.centerYAnchor),
            spinner.leadingAnchor.constraint(equalTo: insights.leadingAnchor, constant: 16)
        ])

        insights.heightAnchor.constraint(equalToConstant: 50).isActive = true
        recs.heightAnchor.constraint(equalToConstant: 50).isActive = true
        actionsStack.addArrangedSubview(insights)
        actionsStack.addArrangedSubview(recs)
    }

    private func setAnalyzingState() {
        guard let btn = insightsButton else { return }
        var config = btn.configuration ?? .plain()
        config.title = "מנתח"
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 40, bottom: 0, trailing: 16)
        btn.configuration = config
        btn.isEnabled = false
        analyzingSpinner?.startAnimating()
        recommendationsButton?.isEnabled = false
        recommendationsButton?.alpha = 0.45
        recommendationsButton?.setTitleColor(AIONDesign.textTertiary, for: .disabled)
    }

    private func clearAnalyzingState() {
        guard let btn = insightsButton else { return }
        var config = btn.configuration ?? .plain()
        config.title = "תובנות AION"
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        btn.configuration = config
        btn.isEnabled = true
        analyzingSpinner?.stopAnimating()
        recommendationsButton?.isEnabled = true
        recommendationsButton?.alpha = 1
    }

    private func updatePeriodLabel() {
        periodLabel.text = selectedRange.displayLabel()
    }

    @objc private func periodChanged() {
        selectedRange = DataRange.allCases[segmentControl.selectedSegmentIndex]
        updatePeriodLabel()
        loadData(forceAnalysis: false)
    }

    @objc private func refreshTapped() {
        loadData(forceAnalysis: true)
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
                if ok { self?.loadData(forceAnalysis: false) }
                else { self?.showAlert(title: "הרשאה נדחתה", message: "אנא אפשר גישה לנתוני בריאות בהגדרות.") }
            }
        }
    }

    private func loadData(forceAnalysis: Bool = false) {
        loadId += 1
        let currentLoadId = loadId
        if forceAnalysis { GeminiService.shared.cancelCurrentRequest() }
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
                }
                if AnalysisCache.shouldUseCache(forceAnalysis: forceAnalysis),
                   let cached = AnalysisCache.load() {
                    DispatchQueue.main.async {
                        guard self.loadId == currentLoadId else { return }
                        self.insightsText = cached.insights
                        self.recommendationsText = cached.recommendations
                    }
                    return
                }
                DispatchQueue.main.async { self.setAnalyzingState() }
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
        AnalysisCache.save(insights: insightsText, recommendations: recommendationsText)
    }

    private func rebuildCharts() {
        chartsContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard let b = chartBundle else {
            print("[ChartDebug] rebuildCharts: no bundle, using placeholders")
            addChartPlaceholders()
            return
        }
        print("[ChartDebug] rebuildCharts: building 6 charts")
        chartsContainer.addArrangedSubview(makeChartCardWithHosting(title: "1. מטריצת מוכנות (התאוששות vs עומס)", chartView: ReadinessChartView(data: b.readiness), height: 180))
        chartsContainer.addArrangedSubview(makeChartCardWithHosting(title: "2. יעילות קרדיו (דופק vs מרחק)", chartView: EfficiencyChartView(data: b.efficiency), height: 180))
        let (t3, v3) = pickChartForSlot3(b)
        chartsContainer.addArrangedSubview(makeChartCardWithHosting(title: t3, chartView: v3, height: 180))
        let (t4, v4) = pickChartForSlot4(b)
        chartsContainer.addArrangedSubview(makeChartCardWithHosting(title: t4, chartView: v4, height: 180))
        chartsContainer.addArrangedSubview(makeChartCardWithHosting(title: "5. איזון אוטונומי", chartView: AutonomicRadarChartView(data: b.autonomic), height: 180))
        let (t6, v6) = pickChartForSlot6(b)
        chartsContainer.addArrangedSubview(makeChartCardWithHosting(title: t6, chartView: v6, height: 180))
        print("[ChartDebug] rebuildCharts: slot3 title=\(t3), slot4 title=\(t4), slot6 title=\(t6)")
        chartsContainer.setNeedsLayout()
        chartsContainer.layoutIfNeeded()
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    private func pickChartForSlot3(_ b: AIONChartDataBundle) -> (String, AnyView) {
        let sleepWithData = b.sleep.points.filter { ($0.totalHours ?? 0) > 0 }
        let sleepOk = !sleepWithData.isEmpty
        print("[ChartDebug] Slot3: sleep points=\(b.sleep.points.count), with totalHours>0=\(sleepWithData.count), sleepOk=\(sleepOk)")
        if sleepOk {
            print("[ChartDebug] Slot3 → ארכיטקטורת שינה (primary)")
            return ("3. ארכיטקטורת שינה", AnyView(SleepArchitectureChartView(data: b.sleep)))
        }
        if let (t, v) = firstAlternativeChart(bundle: b, prefix: "3") {
            print("[ChartDebug] Slot3 → alternative: \(t)")
            return (t, v)
        }
        print("[ChartDebug] Slot3 → placeholder")
        return ("3. ארכיטקטורת שינה", AnyView(ChartPlaceholderView(message: "אין נתוני שינה להצגה", icon: "bed.double.fill")))
    }

    private func pickChartForSlot4(_ b: AIONChartDataBundle) -> (String, AnyView) {
        let hasGlucose = b.glucoseEnergy.points.contains { $0.glucose != nil }
        let hasEnergy = b.glucoseEnergy.points.contains { ($0.activeEnergy ?? 0) > 0 }
        let geOk = hasGlucose || hasEnergy
        print("[ChartDebug] Slot4: glucoseEnergy points=\(b.glucoseEnergy.points.count), hasGlucose=\(hasGlucose), hasEnergy=\(hasEnergy), geOk=\(geOk)")
        if geOk {
            if hasEnergy && !hasGlucose {
                print("[ChartDebug] Slot4 → אנרגיה פעילה (energy-only)")
                return ("4. אנרגיה פעילה", AnyView(ActiveEnergyChartView(data: b.glucoseEnergy)))
            }
            print("[ChartDebug] Slot4 → גלוקוז ואנרגיה (primary)")
            return ("4. גלוקוז ואנרגיה", AnyView(GlucoseEnergyChartView(data: b.glucoseEnergy)))
        }
        if let (t, v) = firstAlternativeChart(bundle: b, prefix: "4") {
            print("[ChartDebug] Slot4 → alternative: \(t)")
            return (t, v)
        }
        print("[ChartDebug] Slot4 → placeholder")
        return ("4. גלוקוז ואנרגיה", AnyView(ChartPlaceholderView(message: "אין נתוני גלוקוז או אנרגיה להצגה", icon: "flame.fill")))
    }

    private func pickChartForSlot6(_ b: AIONChartDataBundle) -> (String, AnyView) {
        let nutOk = b.nutrition.points.prefix(7).contains { (($0.protein ?? 0) > 0) || (($0.carbs ?? 0) > 0) || (($0.fat ?? 0) > 0) }
        if nutOk { return ("6. תזונה vs יעדים", AnyView(NutritionChartView(data: b.nutrition))) }
        if let (t, v) = firstAlternativeChart(bundle: b, prefix: "6") { return (t, v) }
        return ("6. תזונה vs יעדים", AnyView(ChartPlaceholderView(message: "אין נתוני תזונה להצגה", icon: "leaf.fill")))
    }

    /// חלופות עם נתונים **בטוחים** (Recovery/Strain) ראשונות – תמיד יש readiness.
    /// סדר: מגמת התאוששות → מגמת עומס (תמיד קיימים), ואז צעדים, מרחק וכו'.
    private func firstAlternativeChart(bundle b: AIONChartDataBundle, prefix: String) -> (String, AnyView)? {
        print("[ChartDebug] firstAlternativeChart prefix=\(prefix): readiness.points=\(b.readiness.points.count)")
        if !b.readiness.points.isEmpty {
            let useStrain = (prefix == "4")
            if useStrain {
                return ("\(prefix). מגמת עומס", AnyView(StrainTrendChartView(data: b.readiness)))
            }
            return ("\(prefix). מגמת התאוששות", AnyView(RecoveryTrendChartView(data: b.readiness)))
        }
        if b.steps.points.contains(where: { $0.steps > 0 }) {
            return ("\(prefix). צעדים יומיים", AnyView(StepsChartView(data: b.steps)))
        }
        if b.efficiency.points.contains(where: { ($0.distanceKm ?? 0) > 0 }) {
            return ("\(prefix). מרחק (ק\"מ)", AnyView(DistanceChartView(data: b.efficiency)))
        }
        if b.glucoseEnergy.points.contains(where: { ($0.activeEnergy ?? 0) > 0 }) {
            return ("\(prefix). אנרגיה פעילה", AnyView(ActiveEnergyChartView(data: b.glucoseEnergy)))
        }
        if !b.rhrTrend.points.isEmpty {
            return ("\(prefix). דופק מנוחה (מגמה)", AnyView(RHRTrendChartView(data: b.rhrTrend)))
        }
        if b.efficiency.points.contains(where: { $0.avgHeartRate != nil }) {
            return ("\(prefix). דופק ממוצע (מגמה)", AnyView(AvgHeartRateTrendChartView(data: b.efficiency)))
        }
        if !b.hrvTrend.points.isEmpty {
            return ("\(prefix). HRV (מגמה)", AnyView(HRVTrendChartView(data: b.hrvTrend)))
        }
        return nil
    }

    private func makeChartCardWithHosting<Content: View>(title: String, chartView: Content, height: CGFloat) -> UIView {
        let card = UIView()
        card.backgroundColor = AIONDesign.surface
        card.layer.cornerRadius = AIONDesign.cornerRadius
        card.translatesAutoresizingMaskIntoConstraints = false
        card.semanticContentAttribute = .forceRightToLeft

        let label = UILabel()
        label.text = title
        label.font = AIONDesign.captionFont()
        label.textColor = AIONDesign.textSecondary
        label.textAlignment = .right
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
