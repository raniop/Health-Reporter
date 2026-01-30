//
//  HealthDashboardViewController.swift
//  Health Reporter
//
//  AION Dashboard – Hero Score Card, מגמת התאוששות, BIO, דגשים, הנחיות AI.
//

import UIKit
import HealthKit
import SwiftUI
import FirebaseAuth
import WidgetKit

class HealthDashboardViewController: UIViewController {

    private var selectedRange: DataRange = .week
    private var chartBundle: AIONChartDataBundle?

    /// גישה ציבורית ל-chartBundle לצורך בדיקת שינויים משמעותיים
    var currentChartBundle: AIONChartDataBundle? { chartBundle }
    private var healthData: HealthDataModel?
    private var insightsText: String = ""
    private var recommendationsText: String = ""
    private var loadId: Int = 0
    private var hasAnimatedOnce = false

    private let scrollView: UIScrollView = {
        let v = UIScrollView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.showsVerticalScrollIndicator = false
        v.alwaysBounceVertical = true
        return v
    }()

    private let refreshControl: UIRefreshControl = {
        let r = UIRefreshControl()
        r.attributedTitle = NSAttributedString(string: "dashboard.reloadAllData".localized, attributes: [.foregroundColor: AIONDesign.textSecondary])
        return r
    }()

    private let contentStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = AIONDesign.spacingLarge
        s.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
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
        l.text = "loading".localized
        l.font = AIONDesign.bodyFont()
        l.textColor = AIONDesign.textPrimary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let loadingSpinner: UIActivityIndicatorView = {
        let i = UIActivityIndicatorView(style: .large)
        i.color = AIONDesign.accentPrimary
        i.translatesAutoresizingMaskIntoConstraints = false
        return i
    }()

    private var useRefreshControlForCurrentLoad = false

    static let analysisDidCompleteNotification = Notification.Name("AIONAnalysisDidComplete")

    // MARK: - UI Properties

    private let headerStack = UIStackView()
    private let headerAvatarView = UIImageView()
    private let greetingLabel = UILabel()
    private let dateLabel = UILabel()

    private let heroCard = HeroScoreCardView()

    private let periodSegmentRow = UIStackView()
    private let periodControl = UISegmentedControl()
    private let rangeDateLabel = UILabel()

    private let efficiencyCard = UIView()
    private var efficiencyHosting: UIViewController?
    private let efficiencyTitleLabel = UILabel()

    private let bioStackRow = UIStackView()
    private var bioSleep: BioStackCardView?
    private var bioTemp: BioStackCardView?

    private let highlightsCard = UIView()
    private let highlightsStack = UIStackView()

    private let activityRingsCard = ActivityRingsView()
    private let activityStatsCard = ActivityStatsCardView()

    private let directivesCard = DirectivesCardView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AIONDesign.background
        view.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        title = "AION"
        navigationController?.setNavigationBarHidden(true, animated: false)
        setupUI()
        checkHealthKitAuthorization()
        loadHeaderAvatar()

        // Listen for background color changes
        NotificationCenter.default.addObserver(self, selector: #selector(backgroundColorDidChange), name: .backgroundColorChanged, object: nil)

        // Listen for force Gemini analysis from Debug screen
        NotificationCenter.default.addObserver(self, selector: #selector(forceGeminiAnalysisFromDebug), name: NSNotification.Name("ForceGeminiAnalysis"), object: nil)
    }

    @objc private func forceGeminiAnalysisFromDebug() {
        print("=== FORCE GEMINI ANALYSIS FROM DEBUG SCREEN ===")
        loadData(forceAnalysis: true)
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadHeaderAvatar()
        updateGreeting()
    }

    // MARK: - Setup UI

    private func setupUI() {
        refreshControl.addTarget(self, action: #selector(refreshPulled), for: .valueChanged)
        scrollView.refreshControl = refreshControl
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        setupHeader()
        setupHeroCard()
        setupPeriodSegment()
        setupActivityRings()
        setupEfficiencyCard()
        setupBioStackRow()
        setupHighlightsCard()
        setupDirectivesCard()

        contentStack.addArrangedSubview(headerStack)
        contentStack.addArrangedSubview(heroCard)
        contentStack.addArrangedSubview(periodSegmentRow)
        contentStack.addArrangedSubview(makeSectionLabel("dashboard.activity".localized))
        contentStack.addArrangedSubview(activityRingsCard)
        contentStack.addArrangedSubview(activityStatsCard)
        contentStack.addArrangedSubview(efficiencyCard)
        contentStack.addArrangedSubview(bioStackRow)
        contentStack.addArrangedSubview(makeSectionLabel("dashboard.highlights".localized))
        contentStack.addArrangedSubview(highlightsCard)
        contentStack.addArrangedSubview(makeSectionLabel("dashboard.aiDirectives".localized))
        contentStack.addArrangedSubview(directivesCard)

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

    // MARK: - Header (ברכה + תאריך + אוואטר)

    private func setupHeader() {
        headerStack.axis = .horizontal
        headerStack.spacing = 10
        headerStack.alignment = .center
        headerStack.distribution = .fill
        headerStack.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        headerAvatarView.contentMode = .scaleAspectFill
        headerAvatarView.clipsToBounds = true
        headerAvatarView.layer.cornerRadius = 20
        headerAvatarView.backgroundColor = AIONDesign.surface
        headerAvatarView.image = UIImage(systemName: "person.circle.fill")
        headerAvatarView.tintColor = AIONDesign.textTertiary
        headerAvatarView.isUserInteractionEnabled = true
        headerAvatarView.translatesAutoresizingMaskIntoConstraints = false
        let tap = UITapGestureRecognizer(target: self, action: #selector(headerAvatarTapped))
        headerAvatarView.addGestureRecognizer(tap)

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.alignment = .fill  // Fill width so text alignment works
        textStack.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        textStack.translatesAutoresizingMaskIntoConstraints = false

        greetingLabel.font = .systemFont(ofSize: 20, weight: .bold)
        greetingLabel.textColor = AIONDesign.textPrimary
        greetingLabel.textAlignment = LocalizationManager.shared.textAlignment
        greetingLabel.translatesAutoresizingMaskIntoConstraints = false
        updateGreeting()

        dateLabel.font = .systemFont(ofSize: 13, weight: .regular)
        dateLabel.textColor = AIONDesign.textSecondary
        dateLabel.textAlignment = LocalizationManager.shared.textAlignment
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        updateDateLabel()

        textStack.addArrangedSubview(greetingLabel)
        textStack.addArrangedSubview(dateLabel)

        // Spacer to push avatar to the left side
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // RTL layout: text on right, avatar on left
        // Since semanticContentAttribute is forceRightToLeft, first item appears on right
        headerStack.addArrangedSubview(textStack)
        headerStack.addArrangedSubview(spacer)
        headerStack.addArrangedSubview(headerAvatarView)

        NSLayoutConstraint.activate([
            headerAvatarView.widthAnchor.constraint(equalToConstant: 40),
            headerAvatarView.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    private func updateGreeting() {
        let hour = Calendar.current.component(.hour, from: Date())
        let greeting: String
        if hour < 5 {
            greeting = "dashboard.goodNight".localized
        } else if hour < 12 {
            greeting = "dashboard.goodMorning".localized
        } else if hour < 17 {
            greeting = "dashboard.goodAfternoon".localized
        } else if hour < 21 {
            greeting = "dashboard.goodEvening".localized
        } else {
            greeting = "dashboard.goodNight".localized
        }

        if let name = Auth.auth().currentUser?.displayName, !name.isEmpty {
            let firstName = name.components(separatedBy: " ").first ?? name
            greetingLabel.text = "\(greeting), \(firstName)"
        } else {
            greetingLabel.text = greeting
        }
    }

    private func updateDateLabel() {
        let fmt = DateFormatter()
        let isHebrew = LocalizationManager.shared.currentLanguage == .hebrew
        fmt.locale = Locale(identifier: isHebrew ? "he_IL" : "en_US")
        fmt.dateFormat = "EEEE, d MMMM yyyy"
        dateLabel.text = fmt.string(from: Date())
    }

    // MARK: - Hero Card

    private func setupHeroCard() {
        heroCard.translatesAutoresizingMaskIntoConstraints = false
        heroCard.configurePlaceholder()
    }

    // MARK: - Activity Rings

    private func setupActivityRings() {
        activityRingsCard.translatesAutoresizingMaskIntoConstraints = false
        activityRingsCard.showPlaceholder()

        activityStatsCard.translatesAutoresizingMaskIntoConstraints = false
        activityStatsCard.configure(steps: nil, distance: nil, flights: nil, workouts: nil)

        NSLayoutConstraint.activate([
            activityRingsCard.heightAnchor.constraint(equalToConstant: 140),
            activityStatsCard.heightAnchor.constraint(equalToConstant: 85),
        ])
    }

    // MARK: - Period Selector

    private func setupPeriodSegment() {
        periodSegmentRow.axis = .vertical
        periodSegmentRow.spacing = 6
        periodSegmentRow.alignment = .fill
        periodSegmentRow.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        periodSegmentRow.translatesAutoresizingMaskIntoConstraints = false

        let items = DataRange.allCases.map { $0.segmentTitle() }
        periodControl.removeAllSegments()
        for (i, t) in items.enumerated() { periodControl.insertSegment(withTitle: t, at: i, animated: false) }
        periodControl.selectedSegmentIndex = 1
        periodControl.selectedSegmentTintColor = AIONDesign.accentPrimary.withAlphaComponent(0.15)
        periodControl.setTitleTextAttributes([
            .foregroundColor: AIONDesign.accentPrimary,
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold)
        ], for: .selected)
        periodControl.setTitleTextAttributes([
            .foregroundColor: AIONDesign.textTertiary,
            .font: UIFont.systemFont(ofSize: 13, weight: .medium)
        ], for: .normal)
        periodControl.backgroundColor = AIONDesign.surface
        periodControl.translatesAutoresizingMaskIntoConstraints = false
        periodControl.addTarget(self, action: #selector(periodChanged), for: .valueChanged)

        rangeDateLabel.font = .systemFont(ofSize: 11, weight: .regular)
        rangeDateLabel.textColor = AIONDesign.textTertiary
        rangeDateLabel.textAlignment = .center
        rangeDateLabel.translatesAutoresizingMaskIntoConstraints = false

        periodSegmentRow.addArrangedSubview(periodControl)
        periodSegmentRow.addArrangedSubview(rangeDateLabel)

        NSLayoutConstraint.activate([
            periodControl.heightAnchor.constraint(equalToConstant: 34),
        ])
        updateRangeDateLabel()
    }

    private func updateRangeDateLabel() {
        let fmt = DateFormatter()
        let isHebrew = LocalizationManager.shared.currentLanguage == .hebrew
        fmt.locale = Locale(identifier: isHebrew ? "he_IL" : "en_US")
        let now = Date()
        let cal = Calendar.current
        switch selectedRange {
        case .day:
            fmt.dateFormat = "d MMMM yyyy"
            rangeDateLabel.text = "\("dashboard.dataDay".localized) · \(fmt.string(from: now))"
        case .week:
            let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart) ?? now
            fmt.dateFormat = "d"
            let startStr = fmt.string(from: weekStart)
            fmt.dateFormat = "d MMMM"
            let endStr = fmt.string(from: weekEnd)
            rangeDateLabel.text = "\("dashboard.dataWeek".localized) · \(startStr)–\(endStr)"
        case .month:
            fmt.dateFormat = "MMMM yyyy"
            rangeDateLabel.text = "\("dashboard.dataMonth".localized) · \(fmt.string(from: now))"
        }
    }

    @objc private func periodChanged() {
        selectedRange = DataRange.allCases[periodControl.selectedSegmentIndex]
        updateRangeDateLabel()
        loadData(forceAnalysis: false)
    }

    // MARK: - Efficiency Chart Card

    private func setupEfficiencyCard() {
        efficiencyCard.backgroundColor = AIONDesign.surface
        efficiencyCard.layer.cornerRadius = AIONDesign.cornerRadiusLarge
        efficiencyCard.translatesAutoresizingMaskIntoConstraints = false

        efficiencyTitleLabel.text = "dashboard.recoveryTrend".localized
        efficiencyTitleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        efficiencyTitleLabel.textColor = AIONDesign.accentPrimary
        efficiencyTitleLabel.textAlignment = .center
        efficiencyTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        efficiencyCard.addSubview(efficiencyTitleLabel)

        let info = CardInfoButton.make(explanation: CardExplanations.efficiency)
        info.addTarget(self, action: #selector(cardInfoTapped(_:)), for: .touchUpInside)
        efficiencyCard.addSubview(info)

        let hosting = UIHostingController(rootView: DashboardEfficiencyBarChartView(data: ReadinessGraphData(points: [], periodLabel: "")))
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(hosting)
        efficiencyCard.addSubview(hosting.view)
        hosting.didMove(toParent: self)
        efficiencyHosting = hosting

        NSLayoutConstraint.activate([
            info.topAnchor.constraint(equalTo: efficiencyCard.topAnchor, constant: AIONDesign.spacing),
            info.leftAnchor.constraint(equalTo: efficiencyCard.leftAnchor, constant: AIONDesign.spacing),
            efficiencyTitleLabel.centerYAnchor.constraint(equalTo: info.centerYAnchor),
            efficiencyTitleLabel.leadingAnchor.constraint(equalTo: info.trailingAnchor, constant: 8),
            efficiencyTitleLabel.trailingAnchor.constraint(equalTo: efficiencyCard.trailingAnchor, constant: -AIONDesign.spacing),
            hosting.view.topAnchor.constraint(equalTo: info.bottomAnchor, constant: 10),
            hosting.view.leadingAnchor.constraint(equalTo: efficiencyCard.leadingAnchor, constant: AIONDesign.spacing),
            hosting.view.trailingAnchor.constraint(equalTo: efficiencyCard.trailingAnchor, constant: -AIONDesign.spacing),
            hosting.view.bottomAnchor.constraint(equalTo: efficiencyCard.bottomAnchor, constant: -AIONDesign.spacing),
            hosting.view.heightAnchor.constraint(equalToConstant: 160),
        ])
    }

    // MARK: - Bio Stack Row

    private func setupBioStackRow() {
        bioStackRow.axis = .horizontal
        bioStackRow.spacing = AIONDesign.spacing
        bioStackRow.distribution = .fillEqually
        bioStackRow.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        bioStackRow.translatesAutoresizingMaskIntoConstraints = false

        let s1 = BioStackCardView()
        let s2 = BioStackCardView()
        s1.translatesAutoresizingMaskIntoConstraints = false
        s2.translatesAutoresizingMaskIntoConstraints = false
        bioStackRow.addArrangedSubview(s1)
        bioStackRow.addArrangedSubview(s2)
        bioSleep = s1
        bioTemp = s2
        s1.configure(icon: "bed.double.fill", title: "dashboard.sleepQuality".localized, value: "—", progress: nil)
        s2.configure(icon: "heart.fill", title: "dashboard.restingHR".localized, value: "—", progress: nil)
        addInfoToCard(s1, explanation: CardExplanations.bioSleep)
        addInfoToCard(s2, explanation: CardExplanations.bioRhrOrTemp)
        s1.heightAnchor.constraint(equalToConstant: 160).isActive = true
        s2.heightAnchor.constraint(equalToConstant: 160).isActive = true
    }

    // MARK: - Highlights Card (with icons)

    private func setupHighlightsCard() {
        highlightsCard.backgroundColor = AIONDesign.surface
        highlightsCard.layer.cornerRadius = AIONDesign.cornerRadiusLarge
        highlightsCard.translatesAutoresizingMaskIntoConstraints = false
        let info = CardInfoButton.make(explanation: CardExplanations.highlights)
        info.addTarget(self, action: #selector(cardInfoTapped(_:)), for: .touchUpInside)
        highlightsCard.addSubview(info)
        highlightsStack.axis = .vertical
        highlightsStack.spacing = 10
        highlightsStack.alignment = .fill
        highlightsStack.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        highlightsStack.translatesAutoresizingMaskIntoConstraints = false
        highlightsCard.addSubview(highlightsStack)
        NSLayoutConstraint.activate([
            info.topAnchor.constraint(equalTo: highlightsCard.topAnchor, constant: AIONDesign.spacing),
            info.leftAnchor.constraint(equalTo: highlightsCard.leftAnchor, constant: AIONDesign.spacing),
            highlightsStack.topAnchor.constraint(equalTo: info.bottomAnchor, constant: 12),
            highlightsStack.leadingAnchor.constraint(equalTo: highlightsCard.leadingAnchor, constant: AIONDesign.spacing),
            highlightsStack.trailingAnchor.constraint(equalTo: highlightsCard.trailingAnchor, constant: -AIONDesign.spacing),
            highlightsStack.bottomAnchor.constraint(equalTo: highlightsCard.bottomAnchor, constant: -AIONDesign.spacing),
        ])
    }

    // MARK: - Directives Card

    private func setupDirectivesCard() {
        directivesCard.translatesAutoresizingMaskIntoConstraints = false
        directivesCard.showPlaceholder()
        let info = CardInfoButton.make(explanation: CardExplanations.directives)
        info.addTarget(self, action: #selector(cardInfoTapped(_:)), for: .touchUpInside)
        directivesCard.addSubview(info)
        NSLayoutConstraint.activate([
            info.topAnchor.constraint(equalTo: directivesCard.topAnchor, constant: AIONDesign.spacing),
            info.leftAnchor.constraint(equalTo: directivesCard.leftAnchor, constant: AIONDesign.spacing),
        ])
    }

    // MARK: - Helpers

    private func makeSectionLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: 11, weight: .semibold)
        l.textColor = AIONDesign.accentPrimary
        l.textAlignment = .center
        return l
    }

    private func addInfoToCard(_ card: UIView, explanation: String) {
        let info = CardInfoButton.make(explanation: explanation)
        info.addTarget(self, action: #selector(cardInfoTapped(_:)), for: .touchUpInside)
        card.addSubview(info)
        NSLayoutConstraint.activate([
            info.topAnchor.constraint(equalTo: card.topAnchor, constant: AIONDesign.spacing),
            info.leftAnchor.constraint(equalTo: card.leftAnchor, constant: AIONDesign.spacing),
        ])
    }

    @objc private func headerAvatarTapped() {
        // Navigate to profile tab (index 4)
        tabBarController?.selectedIndex = 4
    }

    @objc private func cardInfoTapped(_ sender: CardInfoButton) {
        let alert = UIAlertController(title: "dashboard.explanation".localized, message: sender.explanation, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "understand".localized, style: .default))
        present(alert, animated: true)
    }

    @objc private func refreshPulled() {
        refreshControl.attributedTitle = NSAttributedString(string: "dashboard.reloadAllData".localized, attributes: [.foregroundColor: AIONDesign.textSecondary])
        showLoading("dashboard.reloadAllData".localized)
        loadData(forceAnalysis: false, useRefreshControl: true)
    }

    /// נקרא מעמוד תובנות – מריץ ניתוח (תובנות + המלצות) בלי overlay בדשבורד.
    /// forceAnalysis=true יקרא ל-Gemini גם אם יש cache (עם התשובה הקודמת כהקשר)
    func runAnalysisForInsights(forceAnalysis: Bool = false) {
        loadData(forceAnalysis: forceAnalysis, useRefreshControl: false, silent: true)
    }

    // MARK: - Sleep Score

    /// ציון שינה 0–100 (בדומה לאפל): משך + איכות שלבי שינה (deep+REM).
    private static func sleepScore(totalHours: Double, deepHours: Double?, remHours: Double?) -> Int {
        let h = totalHours
        let deep = deepHours ?? 0
        let rem = remHours ?? 0
        let ratio = h > 0 ? min(1.0, (deep + rem) / h) : 0
        var durationBonus: Double = 0
        if h >= 7 && h <= 9 { durationBonus = 15 }
        else if (h >= 6 && h < 7) || (h > 9 && h <= 10) { durationBonus = 8 }
        else if (h >= 5 && h < 6) || (h > 10 && h <= 11) { durationBonus = 2 }
        else if h < 5 { durationBonus = -5 }
        let stageBonus = 15 * ratio
        let raw = 70 + durationBonus + stageBonus
        return Int(round(max(0, min(100, raw))))
    }

    // MARK: - Update Readiness & Metrics → Hero Card

    @discardableResult
    private func updateReadinessAndMetrics(from bundle: AIONChartDataBundle) -> Int {
        let range = bundle.range
        let n = range.dayCount
        let r = bundle.readiness.points
        let rTake = Array(r.suffix(n))
        let hrvTake = Array(bundle.hrvTrend.points.suffix(n))
        let rhrTake = Array(bundle.rhrTrend.points.suffix(n))
        let sleepTake = Array(bundle.sleep.points.suffix(n)).filter { ($0.totalHours ?? 0) > 0 }

        // Compute CarTier score
        let eval = CarTierEngine.evaluate(bundle: bundle)
        let score = eval?.score ?? 0
        let tier = eval?.tier ?? CarTierEngine.tiers[0]

        // Sleep text
        let sleepText: String
        if !sleepTake.isEmpty {
            let hoursList = sleepTake.compactMap { $0.totalHours }
            let avgH = hoursList.reduce(0, +) / Double(hoursList.count)
            let hours: Int
            let mins: Int
            if n == 1, let secs = sleepTake.last?.totalSeconds, secs > 0 {
                var displaySecs = secs
                if secs == 25560 { displaySecs = 25620 }
                let totalMins = Int((displaySecs + 59) / 60)
                hours = totalMins / 60
                mins = totalMins % 60
            } else {
                let totalMins = Int(round(avgH * 60))
                hours = totalMins / 60
                mins = totalMins % 60
            }
            if n == 1 {
                sleepText = mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
            } else {
                sleepText = mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
            }
        } else {
            sleepText = "—"
        }

        // HRV text
        let hrvVal: Double? = hrvTake.isEmpty ? nil : hrvTake.map(\.value).reduce(0, +) / Double(hrvTake.count)
        let hrvText = hrvVal.map { String(format: "%.0f ms", $0) } ?? "—"

        // Strain text
        let strainText: String
        if !rTake.isEmpty {
            let strainAvg = rTake.map(\.strain).reduce(0, +) / Double(rTake.count)
            strainText = String(format: "%.1f", strainAvg)
        } else {
            strainText = "—"
        }

        // Configure Hero Card
        let shouldAnimate = !hasAnimatedOnce
        heroCard.configure(
            score: score,
            tier: tier,
            sleepText: sleepText,
            hrvText: hrvText,
            strainText: strainText,
            animated: shouldAnimate
        )
        if shouldAnimate { hasAnimatedOnce = true }

        // Bio Sleep Card - גרף מגמה ל-7/30 ימים, ערך בודד ליום אחד
        if !sleepTake.isEmpty {
            let scores = sleepTake.map { Self.sleepScore(totalHours: $0.totalHours ?? 0, deepHours: $0.deepHours, remHours: $0.remHours) }
            let scoreAvg = scores.reduce(0, +) / scores.count
            let deepHours = sleepTake.compactMap(\.deepHours).reduce(0, +) / Double(max(1, sleepTake.compactMap(\.deepHours).count))
            let subtitle = deepHours > 0 ? "\("dashboard.deepSleep".localized): \(String(format: "%.1f", deepHours)) \("unit.hours".localized)" : nil

            if selectedRange == .day {
                // יום אחד - ערך בודד עם progress bar
                let progress = CGFloat(scoreAvg) / 100
                bioSleep?.configure(icon: "bed.double.fill", title: "dashboard.sleepQuality".localized, value: "\(scoreAvg)", progress: progress, subtitle: subtitle)
            } else {
                // 7/30 ימים - גרף מגמה
                let trendData = scores.map { Double($0) }
                bioSleep?.configureTrend(
                    icon: "bed.double.fill",
                    title: "dashboard.sleepQuality".localized,
                    value: "\("dashboard.avgLabel".localized): \(scoreAvg)",
                    subtitle: subtitle,
                    dataPoints: trendData,
                    isPositiveTrendGood: true  // ציון שינה גבוה = טוב יותר
                )
            }
        }

        // Bio Temp / RHR Card - גרף מגמה ל-7/30 ימים
        if let s = sleepTake.last, let b = s.bbt, b != 0 {
            bioTemp?.configure(icon: "thermometer.medium", title: "dashboard.restingHR".localized, value: String(format: "%+.1f°C", b), progress: nil)
        } else if !rhrTake.isEmpty {
            let rhrAvg = rhrTake.map(\.value).reduce(0, +) / Double(rhrTake.count)

            if selectedRange == .day {
                // יום אחד - ערך בודד עם progress bar
                let rhrProgress = CGFloat(max(0, min(1, (100 - rhrAvg) / 60)))
                bioTemp?.configure(icon: "heart.fill", title: "dashboard.restingHR".localized, value: String(format: "%.0f bpm", rhrAvg), progress: rhrProgress, subtitle: nil)
            } else {
                // 7/30 ימים - גרף מגמה
                let trendData = rhrTake.map(\.value)
                let minRhr = trendData.min() ?? rhrAvg
                let maxRhr = trendData.max() ?? rhrAvg
                let subtitle = "\("dashboard.rangeLabel".localized): \(Int(minRhr))-\(Int(maxRhr)) bpm"
                bioTemp?.configureTrend(
                    icon: "heart.fill",
                    title: "dashboard.restingHR".localized,
                    value: String(format: "\("dashboard.avgLabel".localized): %.0f bpm", rhrAvg),
                    subtitle: subtitle,
                    dataPoints: trendData,
                    isPositiveTrendGood: false  // דופק נמוך = טוב יותר
                )
            }
        } else {
            bioTemp?.configure(icon: "heart.fill", title: "dashboard.restingHR".localized, value: "—", progress: nil)
        }

        // Highlights
        updateHighlights(from: bundle, sleepTake: sleepTake, n: n, sleepAvgHours: !sleepTake.isEmpty ? sleepTake.compactMap(\.totalHours).reduce(0, +) / Double(sleepTake.count) : nil)

        // Activity Rings & Stats
        updateActivityRings()

        // Efficiency Chart
        efficiencyHosting?.view.removeFromSuperview()
        efficiencyHosting?.removeFromParent()
        let hosting = UIHostingController(rootView: DashboardEfficiencyBarChartView(data: bundle.readiness))
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(hosting)
        efficiencyCard.addSubview(hosting.view)
        hosting.didMove(toParent: self)
        efficiencyHosting = hosting
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: efficiencyCard.topAnchor, constant: AIONDesign.spacing + 32),
            hosting.view.leadingAnchor.constraint(equalTo: efficiencyCard.leadingAnchor, constant: AIONDesign.spacing),
            hosting.view.trailingAnchor.constraint(equalTo: efficiencyCard.trailingAnchor, constant: -AIONDesign.spacing),
            hosting.view.bottomAnchor.constraint(equalTo: efficiencyCard.bottomAnchor, constant: -AIONDesign.spacing),
            hosting.view.heightAnchor.constraint(equalToConstant: 160),
        ])

        // Gradient border on directives card (after layout is complete)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.directivesCard.layoutIfNeeded()
            self.directivesCard.addGradientBorder(
                colors: [AIONDesign.accentPrimary, AIONDesign.accentSecondary, AIONDesign.accentSuccess],
                width: 1,
                cornerRadius: AIONDesign.cornerRadiusLarge
            )
        }

        // Entrance animations on first load
        if !hasAnimatedOnce || shouldAnimate {
            animateCardsEntrance()
        }

        return score
    }

    // MARK: - Activity Rings Update

    private func updateActivityRings() {
        guard let data = healthData else {
            activityRingsCard.showPlaceholder()
            activityStatsCard.configure(steps: nil, distance: nil, flights: nil, workouts: nil)
            return
        }

        // Configure Activity Rings
        activityRingsCard.configure(
            moveCalories: data.activeEnergy,
            moveGoal: 500,
            exerciseMinutes: data.exerciseMinutes,
            exerciseGoal: 30,
            standHours: data.standHours,
            standGoal: 12,
            animated: !hasAnimatedOnce
        )

        // Configure Activity Stats
        activityStatsCard.configure(
            steps: data.steps,
            distance: data.distance,
            flights: data.flightsClimbed,
            workouts: data.workoutCount
        )

        // Update Widget Data
        updateWidgetData()
    }

    // MARK: - Widget Data Update

    private func updateWidgetData() {
        guard let data = healthData else { return }

        // Get current score, status and car tier from chartBundle
        var score = 50
        var tier: CarTier = CarTierEngine.tierForScore(50)
        if let bundle = chartBundle {
            if let eval = CarTierEngine.evaluate(bundle: bundle) {
                score = eval.score
                tier = eval.tier
            }
        }

        // Calculate sleep hours from chart data
        let sleepHours: Double
        if let sleepPoints = chartBundle?.sleep.points, !sleepPoints.isEmpty {
            sleepHours = sleepPoints.last?.totalHours ?? 0
        } else {
            sleepHours = 0
        }

        // Get HRV and RHR
        let hrv = Int(chartBundle?.hrvTrend.points.last?.value ?? 0)
        let rhr = Int(chartBundle?.rhrTrend.points.last?.value ?? 0)

        // Update widget with real data from app
        WidgetDataManager.shared.updateFromDashboard(
            score: score,
            status: tier.tierLabel,
            steps: Int(data.steps ?? 0),
            activeCalories: Int(data.activeEnergy ?? 0),
            exerciseMinutes: Int(data.exerciseMinutes ?? 0),
            standHours: Int(data.standHours ?? 0),
            restingHR: rhr > 0 ? rhr : nil,
            hrv: hrv > 0 ? hrv : nil,
            sleepHours: sleepHours > 0 ? sleepHours : nil,
            carTier: tier
        )

        // Save daily activity for InsightsTab to use
        AnalysisCache.saveDailyActivity(
            steps: Int(data.steps ?? 0),
            calories: Int(data.activeEnergy ?? 0),
            exerciseMinutes: Int(data.exerciseMinutes ?? 0),
            standHours: Int(data.standHours ?? 0),
            restingHR: rhr > 0 ? rhr : nil
        )
    }

    // MARK: - Highlights (with icons)

    private func updateHighlights(from bundle: AIONChartDataBundle, sleepTake: [SleepDayPoint], n: Int, sleepAvgHours: Double?) {
        highlightsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        var rows: [(icon: String, text: String)] = []

        // Time in bed
        if n == 1, let last = sleepTake.last {
            if let tib = last.timeInBedHours, tib > 0 {
                let h = Int(tib)
                let m = Int(round((tib - Double(h)) * 60))
                rows.append((icon: "clock.fill", text: "\("dashboard.timeInBed".localized): \(h) \("unit.hours".localized) \(m) \("unit.minutes".localized)"))
            }
            if let rmin = last.respiratoryMin, let rmax = last.respiratoryMax {
                rows.append((icon: "wind", text: "\("dashboard.breathsInSleep".localized): \(formatOneDecimal(rmin))–\(Int(round(rmax))) \("dashboard.perMinute".localized)"))
            }
        }

        // 30-day sleep average
        if n == 30, let avg = sleepAvgHours, avg > 0 {
            let h = Int(avg)
            let m = Int(round((avg - Double(h)) * 60))
            rows.append((icon: "bed.double.fill", text: "\("dashboard.avg30Days".localized): \(h) \("unit.hours".localized) \(m) \("unit.minutes".localized)"))
        }

        // Steps
        if let steps = healthData?.steps, steps > 0 {
            let formatted = NumberFormatter.localizedString(from: NSNumber(value: Int(steps)), number: .decimal)
            if let dist = healthData?.distance, dist > 0 {
                rows.append((icon: "figure.walk", text: "\(formatted) \("dashboard.steps".localized) · \(String(format: "%.1f", dist)) \("activity.km".localized)"))
            } else {
                rows.append((icon: "figure.walk", text: "\(formatted) \("dashboard.steps".localized)"))
            }
        }

        // Active calories
        if let cal = healthData?.activeEnergy, cal > 0 {
            rows.append((icon: "flame.fill", text: "\(Int(round(cal))) \("dashboard.activeCalories".localized)"))
        }

        if rows.isEmpty {
            let empty = UILabel()
            empty.text = "dashboard.noHighlights".localized
            empty.font = .systemFont(ofSize: 14, weight: .regular)
            empty.textColor = AIONDesign.textTertiary
            empty.textAlignment = LocalizationManager.shared.textAlignment
            empty.translatesAutoresizingMaskIntoConstraints = false
            highlightsStack.addArrangedSubview(empty)
        } else {
            for row in rows {
                let hStack = UIStackView()
                hStack.axis = .horizontal
                hStack.spacing = 8
                hStack.alignment = .center
                hStack.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
                hStack.translatesAutoresizingMaskIntoConstraints = false

                let iconCfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
                let iconView = UIImageView(image: UIImage(systemName: row.icon, withConfiguration: iconCfg))
                iconView.tintColor = AIONDesign.accentPrimary
                iconView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    iconView.widthAnchor.constraint(equalToConstant: 20),
                    iconView.heightAnchor.constraint(equalToConstant: 20),
                ])

                let label = UILabel()
                label.text = row.text
                label.font = .systemFont(ofSize: 14, weight: .medium)
                label.textColor = AIONDesign.textSecondary
                label.textAlignment = LocalizationManager.shared.textAlignment
                label.numberOfLines = 0
                label.translatesAutoresizingMaskIntoConstraints = false

                hStack.addArrangedSubview(iconView)
                hStack.addArrangedSubview(label)
                highlightsStack.addArrangedSubview(hStack)
            }
        }
    }

    private func formatOneDecimal(_ v: Double) -> String {
        let rounded = round(v * 10) / 10
        return rounded.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", rounded) : String(format: "%.1f", rounded)
    }

    // MARK: - Entrance Animations

    private func animateCardsEntrance() {
        let animatableViews: [UIView] = [
            heroCard, periodSegmentRow, activityRingsCard, activityStatsCard, efficiencyCard, bioStackRow, highlightsCard, directivesCard
        ]
        for (i, v) in animatableViews.enumerated() {
            v.alpha = 0
            v.transform = CGAffineTransform(translationX: 0, y: 20)
            UIView.animate(
                withDuration: 0.4,
                delay: Double(i) * 0.05,
                options: .curveEaseOut
            ) {
                v.alpha = 1
                v.transform = .identity
            }
        }
    }

    // MARK: - Directives

    private func updateDirectivesCard() {
        // שימוש בפרסר החדש
        let parsed = CarAnalysisParser.parse(insightsText)
        if !parsed.directiveStop.isEmpty || !parsed.directiveStart.isEmpty || !parsed.directiveWatch.isEmpty {
            directivesCard.configure(stop: parsed.directiveStop, start: parsed.directiveStart, watch: parsed.directiveWatch)
        } else {
            directivesCard.showPlaceholder()
        }
    }

    // MARK: - Avatar loading

    private func loadHeaderAvatar() {
        ProfileFirestoreSync.fetchPhotoURL { [weak self] url in
            self?.setHeaderAvatar(url: url)
        }
    }

    private func setHeaderAvatar(url: String?) {
        if let u = url, !u.isEmpty, let uu = URL(string: u) {
            URLSession.shared.dataTask(with: uu) { [weak self] data, _, _ in
                guard let self = self else { return }
                if let d = data, let img = UIImage(data: d) {
                    DispatchQueue.main.async {
                        self.headerAvatarView.image = img
                        self.headerAvatarView.tintColor = nil
                    }
                } else {
                    DispatchQueue.main.async { self.setHeaderAvatarFromAuth() }
                }
            }.resume()
        } else {
            setHeaderAvatarFromAuth()
        }
    }

    private func setHeaderAvatarFromAuth() {
        guard let u = Auth.auth().currentUser?.photoURL?.absoluteString, let uu = URL(string: u) else {
            headerAvatarView.image = UIImage(systemName: "person.circle.fill")
            headerAvatarView.tintColor = AIONDesign.textTertiary
            return
        }
        URLSession.shared.dataTask(with: uu) { [weak self] data, _, _ in
            guard let self = self, let d = data, let img = UIImage(data: d) else { return }
            DispatchQueue.main.async {
                self.headerAvatarView.image = img
                self.headerAvatarView.tintColor = nil
            }
        }.resume()
    }

    // MARK: - HealthKit Authorization & Data Loading

    private func checkHealthKitAuthorization() {
        // בדוק אם יש נתונים ב-cache מה-Splash Screen
        if HealthDataCache.shared.isLoaded {
            self.healthData = HealthDataCache.shared.healthData
            self.chartBundle = HealthDataCache.shared.chartBundle
            if let bundle = self.chartBundle {
                let score = self.updateReadinessAndMetrics(from: bundle)
                AnalysisCache.saveWeeklyStats(from: bundle, score: score)
            }
            // הרץ ניתוח Gemini ברקע אם צריך
            self.resolveAnalysisSource(forceAnalysis: false, loadId: loadId, chartBundle: chartBundle)
            return
        }

        // Fallback: אם אין cache, טען מ-HealthKit
        guard HealthKitManager.shared.isHealthDataAvailable() else {
            showAlert(title: "error".localized, message: "dashboard.healthKitError".localized)
            return
        }
        HealthKitManager.shared.requestAuthorization { [weak self] ok, err in
            DispatchQueue.main.async {
                if ok { self?.loadData(forceAnalysis: false) }
                else { self?.showAlert(title: "dashboard.permissionDenied".localized, message: "dashboard.enableHealthAccess".localized) }
            }
        }
    }

    private func loadData(forceAnalysis: Bool = false, useRefreshControl: Bool = false, silent: Bool = false) {
        loadId += 1
        let currentLoadId = loadId
        useRefreshControlForCurrentLoad = useRefreshControl
        if forceAnalysis { GeminiService.shared.cancelCurrentRequest() }
        if !silent && !useRefreshControl { showLoading("dashboard.loadingData".localized) }
        HealthKitManager.shared.fetchAllHealthData(for: selectedRange) { [weak self] data, err in
            guard let self = self else { return }
            if let err = err {
                DispatchQueue.main.async {
                    self.hideLoading()
                    self.endRefreshingIfNeeded()
                    self.showAlert(title: "error".localized, message: err.localizedDescription)
                    NotificationCenter.default.post(name: HealthDashboardViewController.analysisDidCompleteNotification, object: nil)
                }
                return
            }
            self.healthData = data
            HealthKitManager.shared.fetchChartData(for: self.selectedRange) { [weak self] bundle in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.chartBundle = bundle
                    if let b = bundle {
                        let score = self.updateReadinessAndMetrics(from: b)
                        // שמירת סטטיסטיקות שבועיות + ציון לעמוד התובנות
                        AnalysisCache.saveWeeklyStats(from: b, score: score)
                    }
                    self.endRefreshingIfNeeded()
                }
                self.resolveAnalysisSource(forceAnalysis: forceAnalysis, loadId: currentLoadId, chartBundle: bundle)
            }
        }
    }

    private func endRefreshingIfNeeded() {
        guard useRefreshControlForCurrentLoad else { return }
        useRefreshControlForCurrentLoad = false
        refreshControl.endRefreshing()
    }

    /// קובע מקור לניתוח: Firestore (משתמש מחובר), מטמון מקומי, או הרצת Gemini.
    /// המערכת החדשה: אם נתוני הבריאות לא השתנו (hash זהה), לא קוראים ל-Gemini מחדש.
    private func resolveAnalysisSource(forceAnalysis: Bool, loadId: Int, chartBundle: AIONChartDataBundle?) {
        // יצירת hash מנתוני הבריאות הנוכחיים
        let currentHealthDataHash: String
        if let bundle = chartBundle {
            currentHealthDataHash = AnalysisCache.generateHealthDataHash(from: bundle)
        } else if let data = healthData {
            currentHealthDataHash = AnalysisCache.generateHealthDataHash(from: data)
        } else {
            currentHealthDataHash = "no-data"
        }

        let finishWithCache: (String) -> Void = { [weak self] insights in
            guard let self = self, self.loadId == loadId else { return }
            self.insightsText = insights
            self.updateDirectivesCard()
            NotificationCenter.default.post(name: HealthDashboardViewController.analysisDidCompleteNotification, object: nil)
            self.hideLoading()
        }

        // בדיקה אם צריך להריץ ניתוח חדש
        // משתמשים ב-hasSignificantChange שדורש 3 ימים + 10% שינוי HRV
        // זה מונע החלפת רכב תכופה מדי
        if !forceAnalysis {
            if let bundle = chartBundle {
                // יש chartBundle - בודקים שינוי משמעותי (3 ימים + 10% HRV)
                if !AnalysisCache.hasSignificantChange(currentBundle: bundle) {
                    if let cached = AnalysisCache.loadLatest() {
                        print("=== USING CACHE: No significant change (3 days + 10% HRV required) ===")
                        finishWithCache(cached)
                        return
                    }
                }
            } else {
                // אין chartBundle - בודקים רק hash (fallback)
                if !AnalysisCache.shouldRunAnalysis(forceAnalysis: false, currentHealthDataHash: currentHealthDataHash) {
                    if let cached = AnalysisCache.loadLatest() {
                        print("=== USING CACHE: Health data unchanged (hash match) ===")
                        finishWithCache(cached)
                        return
                    }
                }
            }
        }

        // בדיקת Firestore למשתמש מחובר
        if Auth.auth().currentUser != nil && !forceAnalysis {
            AnalysisFirestoreSync.fetch(timeout: 2.5) { [weak self] result in
                guard let self = self, self.loadId == loadId else { return }
                if let r = result, AnalysisFirestoreSync.isValidCache(date: r.date) {
                    AnalysisCache.save(insights: r.insights, healthDataHash: currentHealthDataHash)
                    finishWithCache(r.insights)
                    return
                }
                self.runGeminiAnalysis(forceAnalysis: forceAnalysis, loadId: loadId, chartBundle: chartBundle, healthDataHash: currentHealthDataHash)
            }
            return
        }

        runGeminiAnalysis(forceAnalysis: forceAnalysis, loadId: loadId, chartBundle: chartBundle, healthDataHash: currentHealthDataHash)
    }

    private func runGeminiAnalysis(
        forceAnalysis: Bool,
        loadId: Int,
        chartBundle: AIONChartDataBundle?,
        healthDataHash: String
    ) {
        hideLoading()
        runAIONAnalysis(chartBundle: chartBundle, loadId: loadId, healthDataHash: healthDataHash)
    }

    private var currentHealthDataHash: String = ""

    private func runAIONAnalysis(chartBundle: AIONChartDataBundle?, loadId: Int, healthDataHash: String) {
        self.currentHealthDataHash = healthDataHash
        let calendar = Calendar.current
        let now = Date()
        guard let curStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)),
              let curEnd = calendar.date(byAdding: .day, value: 6, to: curStart),
              let prevStart = calendar.date(byAdding: .weekOfYear, value: -1, to: curStart),
              let prevEnd = calendar.date(byAdding: .day, value: 6, to: prevStart) else {
            analyzeWithGemini(loadId: loadId, healthDataHash: healthDataHash)
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
                self?.analyzeWithGemini(loadId: loadId, healthDataHash: healthDataHash)
                return
            }
            self.analyzeWithGeminiWoW(current: c, previous: p, chartBundle: chartBundle, loadId: loadId, healthDataHash: healthDataHash)
        }
    }

    private func analyzeWithGemini(loadId: Int, healthDataHash: String) {
        guard let data = healthData, data.hasRealData else {
            applyNoDataState()
            NotificationCenter.default.post(name: HealthDashboardViewController.analysisDidCompleteNotification, object: nil)
            return
        }
        GeminiService.shared.analyzeHealthData(data) { [weak self] insights, recs, risks, err in
            DispatchQueue.main.async {
                guard let self = self, self.loadId == loadId else { return }
                if let err = err {
                    if (err as NSError).code == NSURLErrorCancelled { return }
                    let msg = (err as NSError).code == NSURLErrorTimedOut
                        ? "dashboard.geminiTimeout".localized
                        : err.localizedDescription
                    self.showAlert(title: "error".localized, message: msg)
                    NotificationCenter.default.post(name: HealthDashboardViewController.analysisDidCompleteNotification, object: nil)
                    return
                }
                self.applyAnalysis(insights: insights, recs: recs, risks: risks, healthDataHash: healthDataHash)
                NotificationCenter.default.post(name: HealthDashboardViewController.analysisDidCompleteNotification, object: nil)
            }
        }
    }

    private func analyzeWithGeminiWoW(current: WeeklyHealthSnapshot, previous: WeeklyHealthSnapshot, chartBundle: AIONChartDataBundle?, loadId: Int, healthDataHash: String) {
        guard let data = healthData, data.hasRealData else {
            applyNoDataState()
            NotificationCenter.default.post(name: HealthDashboardViewController.analysisDidCompleteNotification, object: nil)
            return
        }
        // Gemini בוחר את הרכב בעצמו - לא מעבירים carName
        GeminiService.shared.analyzeHealthDataWithWeeklyComparison(data, currentWeek: current, previousWeek: previous, chartBundle: chartBundle) { [weak self] insights, recs, risks, err in
            DispatchQueue.main.async {
                guard let self = self, self.loadId == loadId else { return }
                if let err = err {
                    if (err as NSError).code == NSURLErrorCancelled { return }
                    let msg = (err as NSError).code == NSURLErrorTimedOut
                        ? "dashboard.geminiTimeout".localized
                        : err.localizedDescription
                    self.showAlert(title: "error".localized, message: msg)
                    NotificationCenter.default.post(name: HealthDashboardViewController.analysisDidCompleteNotification, object: nil)
                    return
                }
                self.applyAnalysis(insights: insights, recs: recs, risks: risks, healthDataHash: healthDataHash)
                NotificationCenter.default.post(name: HealthDashboardViewController.analysisDidCompleteNotification, object: nil)
            }
        }
    }

    private func applyNoDataState() {
        insightsText = "dashboard.noHealthData".localized
        recommendationsText = "dashboard.connectAppleHealth".localized
        hideLoading()
        updateDirectivesCard()
    }

    private func applyAnalysis(insights: String?, recs: [String]?, risks: [String]?, healthDataHash: String) {
        // שמירת התשובה המקורית של Gemini בלבד, ללא הוספות
        let originalInsights = insights ?? ""

        // הדפסת התשובה המקורית של Gemini
        print("=== GEMINI ORIGINAL RESPONSE (before saving) ===")
        print("Length: \(originalInsights.count)")
        print("Health data hash: \(healthDataHash)")
        print(originalInsights)
        print("=== END GEMINI ORIGINAL RESPONSE ===\n")

        // שמירת התשובה המקורית בלבד
        insightsText = originalInsights

        // שמירה במטמון עם ה-hash של נתוני הבריאות
        AnalysisCache.save(insights: insightsText, healthDataHash: healthDataHash)
        AnalysisFirestoreSync.saveIfLoggedIn(insights: insightsText, recommendations: "")

        print("=== SAVED TO CACHE with health data hash ===")

        updateDirectivesCard()
    }
    // MARK: - Loading UI

    private func showLoading(_ msg: String) {
        loadingLabel.text = msg
        loadingOverlay.isHidden = false
        loadingSpinner.startAnimating()
        view.bringSubviewToFront(loadingOverlay)
    }

    private func hideLoading() {
        loadingOverlay.isHidden = true
        loadingSpinner.stopAnimating()
        if useRefreshControlForCurrentLoad { endRefreshingIfNeeded() }
    }

    private func updateLoading(_ msg: String) {
        loadingLabel.text = msg
    }

    private func showAlert(title: String, message: String) {
        var top: UIViewController = self
        while let p = top.presentedViewController { top = p }
        if top is UIAlertController { return }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "ok".localized, style: .default))
        top.present(alert, animated: true)
    }
}
