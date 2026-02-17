//
//  InsightsDashboardViewController.swift
//  Health Reporter
//
//  Main screen - Redesigned home with 5 customizable metrics + AI recommendations.
//

import UIKit
import FirebaseAuth

final class InsightsDashboardViewController: UIViewController {

    // MARK: - Properties

    private var geminiResult: GeminiDailyResult?
    private var isLoading = true
    private var lastUpdatedTime: Date?
    private var metricSelection = HomeMetricSelection.load()
    private var hasPlayedEntrance = false
    private var chartDataCache: [String: [BarChartDataPoint]] = [:]
    private var lastFailureReason: AnalysisFailureReason?

    // UI
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let headerView = HomeHeaderView()
    private let heroCard = HeroMetricCardView()
    private let secondaryGrid = UIStackView()   // 2x2 grid
    private let secondaryCards: [SecondaryMetricCardView] = (0..<4).map { _ in SecondaryMetricCardView() }
    private let recommendationsSection = AIRecommendationsSectionView()
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    private let refreshControl = UIRefreshControl()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()

        NotificationCenter.default.addObserver(
            self, selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleNotificationItemSaved),
            name: NSNotification.Name("NotificationItemSaved"), object: nil
        )
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func appWillEnterForeground() {
        loadData()
        updateBellBadge()
    }

    @objc private func handlePullToRefresh() { loadData() }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        updateBellBadge()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = AIONDesign.background
        configureSemanticDirection()

        // Scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = self
        view.addSubview(scrollView)

        // Pull-to-refresh
        refreshControl.tintColor = AIONDesign.accentPrimary
        refreshControl.addTarget(self, action: #selector(handlePullToRefresh), for: .valueChanged)
        scrollView.refreshControl = refreshControl

        // Content stack
        contentStack.axis = .vertical
        contentStack.spacing = 20
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        // Build 2x2 grid for secondary cards
        setupSecondaryGrid()

        // Add sections
        [headerView, heroCard, secondaryGrid, recommendationsSection].forEach {
            contentStack.addArrangedSubview($0)
        }

        // Loading
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.color = AIONDesign.accentPrimary
        view.addSubview(loadingIndicator)

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

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        // Callbacks
        headerView.onEditTapped = { [weak self] in self?.showMetricEditor() }
        headerView.onBellTapped = { [weak self] in self?.bellTapped() }

        heroCard.onTap = { [weak self] in self?.heroCardTapped() }

        for (i, card) in secondaryCards.enumerated() {
            card.onTap = { [weak self] in self?.secondaryCardTapped(index: i) }
        }

        recommendationsSection.onRetryTapped = { [weak self] in
            self?.retryRecommendations()
        }

        // Initially hidden for entrance animation
        contentStack.alpha = 0
    }

    private func setupSecondaryGrid() {
        secondaryGrid.axis = .vertical
        secondaryGrid.spacing = 12
        secondaryGrid.distribution = .fillEqually

        let row1 = UIStackView(arrangedSubviews: [secondaryCards[0], secondaryCards[1]])
        row1.axis = .horizontal
        row1.spacing = 12
        row1.distribution = .fillEqually

        let row2 = UIStackView(arrangedSubviews: [secondaryCards[2], secondaryCards[3]])
        row2.axis = .horizontal
        row2.spacing = 12
        row2.distribution = .fillEqually

        secondaryGrid.addArrangedSubview(row1)
        secondaryGrid.addArrangedSubview(row2)

        // Card heights
        NSLayoutConstraint.activate([
            row1.heightAnchor.constraint(equalToConstant: 170),
            row2.heightAnchor.constraint(equalToConstant: 170),
        ])
    }

    // MARK: - Data Loading

    private func loadData() {
        let isPullToRefresh = refreshControl.isRefreshing
        let forceRefresh = isPullToRefresh

        // On initial load, try cached result first (Splash already loaded it)
        if !forceRefresh, let cached = GeminiResultStore.load(), Calendar.current.isDateInToday(cached.date) {
            geminiResult = cached
            lastUpdatedTime = cached.date
            isLoading = false
            contentStack.isHidden = false
            removeEmptyState()
            updateUI()
            playEntranceAnimationIfNeeded()
            loadChartData()
            return
        }

        // Pull-to-refresh or no cached data — call orchestrator
        isLoading = true
        if !isPullToRefresh {
            loadingIndicator.startAnimating()
            contentStack.isHidden = true
        }

        AIONAnalysisOrchestrator.shared.ensureTodayResult(forceRefresh: forceRefresh) { [weak self] result, failureReason in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.geminiResult = result
                self.lastFailureReason = failureReason
                self.lastUpdatedTime = Date()
                self.isLoading = false
                self.loadingIndicator.stopAnimating()
                self.refreshControl.endRefreshing()
                self.contentStack.isHidden = false

                if result != nil {
                    self.removeEmptyState()
                    self.updateUI()
                    self.playEntranceAnimationIfNeeded()
                    self.loadChartData()
                } else {
                    self.showEmptyState()
                }
            }
        }
    }

    // MARK: - Update UI

    private func updateUI() {
        guard let result = geminiResult else { return }

        // Header
        headerView.configure(lastUpdated: lastUpdatedTime)

        // Hero card
        let heroMetric = geminiMetric(for: metricSelection.heroMetricId, from: result)
        let heroExplanation = geminiExplanation(for: metricSelection.heroMetricId, from: result)
        heroCard.configure(
            metric: heroMetric,
            metricId: metricSelection.heroMetricId,
            chartData: chartDataCache[metricSelection.heroMetricId] ?? [],
            explanationText: heroExplanation
        )

        // Secondary cards
        for (i, cardView) in secondaryCards.enumerated() {
            guard i < metricSelection.secondaryMetricIds.count else { continue }
            let metricId = metricSelection.secondaryMetricIds[i]
            let metric = geminiMetric(for: metricId, from: result)
            let explanation = geminiExplanation(for: metricId, from: result)
            cardView.configure(metric: metric, metricId: metricId, chartData: chartDataCache[metricId] ?? [], explanationText: explanation)
        }

        // Recommendations (from Gemini result — no separate API call)
        let recs = HomeRecommendations(
            medical: result.homeRecommendationMedical,
            sports: result.homeRecommendationSports,
            nutrition: result.homeRecommendationNutrition
        )
        let hasRecs = !recs.medical.isEmpty || !recs.sports.isEmpty || !recs.nutrition.isEmpty
        recommendationsSection.isHidden = !hasRecs
        if hasRecs {
            recommendationsSection.configure(recommendations: recs)
        }
    }

    // MARK: - Gemini Metric Helpers

    /// Maps a metric ID to a Gemini score value wrapped as InsightMetric
    private func geminiMetric(for metricId: String, from result: GeminiDailyResult) -> (any InsightMetric)? {
        let scores = result.scores
        switch metricId {
        case "main_score", "health_score":
            return GeminiMetricProxy(id: metricId, nameKey: "dashboard.healthScore", value: scores.healthScore.map { Double($0) }, category: .performance)
        case "sleep_quality":
            return GeminiMetricProxy(id: metricId, nameKey: "metric.sleep_quality", value: scores.sleepScore.map { Double($0) }, category: .sleep)
        case "recovery_readiness":
            return GeminiMetricProxy(id: metricId, nameKey: "metric.recovery_readiness", value: scores.readinessScore.map { Double($0) }, category: .recovery)
        case "energy_forecast":
            return GeminiMetricProxy(id: metricId, nameKey: "metric.energy_forecast", value: scores.energyScore.map { Double($0) }, category: .performance)
        case "training_strain":
            return GeminiMetricProxy(id: metricId, nameKey: "metric.training_strain", value: scores.trainingStrain, category: .load, isStrain: true)
        case "nervous_system_balance":
            return GeminiMetricProxy(id: metricId, nameKey: "metric.nervous_system_balance", value: scores.nervousSystemBalance.map { Double($0) }, category: .recovery)
        case "recovery_debt":
            return GeminiMetricProxy(id: metricId, nameKey: "metric.recovery_debt", value: scores.recoveryDebt.map { Double($0) }, category: .recovery)
        case "activity_score":
            return GeminiMetricProxy(id: metricId, nameKey: "metric.activity_score", value: scores.activityScore.map { Double($0) }, category: .habit)
        case "load_balance":
            return GeminiMetricProxy(id: metricId, nameKey: "metric.load_balance", value: scores.loadBalance.map { Double($0) }, category: .load)
        default:
            return nil
        }
    }

    /// Returns the Gemini explanation text for a given metric
    private func geminiExplanation(for metricId: String, from result: GeminiDailyResult) -> String {
        let scores = result.scores
        switch metricId {
        case "main_score", "health_score":
            return scores.healthScoreExplanation ?? ""
        case "sleep_quality":
            return scores.sleepScoreExplanation ?? ""
        case "recovery_readiness":
            return scores.readinessScoreExplanation ?? ""
        case "energy_forecast":
            return scores.energyScoreExplanation ?? ""
        case "training_strain":
            return scores.trainingStrainExplanation ?? ""
        case "nervous_system_balance":
            return scores.nervousSystemBalanceExplanation ?? ""
        case "recovery_debt":
            return scores.recoveryDebtExplanation ?? ""
        case "activity_score":
            return scores.activityScoreExplanation ?? ""
        case "load_balance":
            return scores.loadBalanceExplanation ?? ""
        default:
            return ""
        }
    }

    // MARK: - Chart Data

    /// Fetches 7-day HealthKit data and builds chart points for each metric.
    /// Today's value is overridden with the actual Gemini score.
    private func loadChartData() {
        HealthKitManager.shared.fetchDailyHealthData(days: 7) { [weak self] entries in
            guard let self = self else { return }
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())

            // Get last 7 entries (or fewer if less data)
            let last7 = Array(entries.suffix(7))
            guard !last7.isEmpty else { return }

            let isHebrew = LocalizationManager.shared.currentLanguage == .hebrew
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEE"
            dayFormatter.locale = isHebrew ? Locale(identifier: "he_IL") : Locale(identifier: "en_US")

            let allMetricIds = [
                "main_score", "health_score",
                "sleep_quality", "recovery_readiness", "energy_forecast",
                "training_strain", "nervous_system_balance", "recovery_debt",
                "activity_score", "load_balance"
            ]

            var charts: [String: [BarChartDataPoint]] = [:]

            for metricId in allMetricIds {
                charts[metricId] = last7.map { entry in
                    let value = self.healthKitValueForMetric(metricId, entry: entry)
                    let isToday = calendar.isDate(entry.date, inSameDayAs: today)
                    return BarChartDataPoint(
                        date: entry.date,
                        dayLabel: dayFormatter.string(from: entry.date),
                        value: value,
                        isToday: isToday
                    )
                }
            }

            // Override today's data point with actual Gemini score
            if let result = self.geminiResult {
                for metricId in allMetricIds {
                    if var points = charts[metricId],
                       let todayIdx = points.firstIndex(where: { $0.isToday }),
                       let geminiVal = self.geminiScoreValue(for: metricId, from: result) {
                        points[todayIdx] = BarChartDataPoint(
                            date: points[todayIdx].date,
                            dayLabel: points[todayIdx].dayLabel,
                            value: geminiVal,
                            isToday: true
                        )
                        charts[metricId] = points
                    }
                }
            }

            DispatchQueue.main.async {
                self.chartDataCache = charts
                // Re-render cards with chart data (only if we have Gemini data)
                if self.geminiResult != nil {
                    self.updateUI()
                }
            }
        }
    }

    /// Maps a metric ID to a scaled HealthKit value for chart display
    private func healthKitValueForMetric(_ metricId: String, entry: RawDailyHealthEntry) -> Double {
        switch metricId {
        case "main_score", "health_score":
            // Composite: average of sleep, HRV, and activity signals
            let sleepPart = min(100.0, ((entry.sleepHours ?? 0) / 8.0) * 100.0)
            let hrvPart = min(100.0, ((entry.hrvMs ?? 0) / 60.0) * 100.0)
            let actPart = min(100.0, ((entry.steps ?? 0) / 10000.0) * 100.0)
            let count = [entry.sleepHours, entry.hrvMs, entry.steps].compactMap({ $0 }).count
            return count > 0 ? (sleepPart + hrvPart + actPart) / Double(max(count, 1)) : 0
        case "sleep_quality":
            return min(100.0, ((entry.sleepHours ?? 0) / 8.0) * 100.0)
        case "recovery_readiness":
            // HRV-based: higher HRV = better readiness
            return min(100.0, ((entry.hrvMs ?? 0) / 60.0) * 100.0)
        case "energy_forecast":
            // Composite of HRV + sleep
            let sleepPart = min(100.0, ((entry.sleepHours ?? 0) / 8.0) * 100.0)
            let hrvPart = min(100.0, ((entry.hrvMs ?? 0) / 60.0) * 100.0)
            return (sleepPart + hrvPart) / 2.0
        case "training_strain":
            // Scale: 0-10 based on active calories
            return min(10.0, ((entry.activeCalories ?? 0) / 300.0) * 10.0)
        case "nervous_system_balance":
            // HRV-based
            return min(100.0, ((entry.hrvMs ?? 0) / 60.0) * 100.0)
        case "recovery_debt":
            // Lower sleep = more debt (inverted)
            let sleepRatio = min(1.0, (entry.sleepHours ?? 0) / 8.0)
            return (1.0 - sleepRatio) * 100.0
        case "activity_score":
            return min(100.0, ((entry.steps ?? 0) / 10000.0) * 100.0)
        case "load_balance":
            return min(100.0, ((entry.activeCalories ?? 0) / 500.0) * 100.0)
        default:
            return 0
        }
    }

    /// Gets the actual Gemini score for a metric to override today's chart point
    private func geminiScoreValue(for metricId: String, from result: GeminiDailyResult) -> Double? {
        let scores = result.scores
        switch metricId {
        case "main_score", "health_score":
            return scores.healthScore.map { Double($0) }
        case "sleep_quality":
            return scores.sleepScore.map { Double($0) }
        case "recovery_readiness":
            return scores.readinessScore.map { Double($0) }
        case "energy_forecast":
            return scores.energyScore.map { Double($0) }
        case "training_strain":
            return scores.trainingStrain
        case "nervous_system_balance":
            return scores.nervousSystemBalance.map { Double($0) }
        case "recovery_debt":
            return scores.recoveryDebt.map { Double($0) }
        case "activity_score":
            return scores.activityScore.map { Double($0) }
        case "load_balance":
            return scores.loadBalance.map { Double($0) }
        default:
            return nil
        }
    }

    // MARK: - Actions

    private func heroCardTapped() {
        guard let result = geminiResult else { return }
        guard let m = geminiMetric(for: metricSelection.heroMetricId, from: result) else { return }
        let explanation = geminiExplanation(for: metricSelection.heroMetricId, from: result)
        let config = ScoreDetailConfig.from(metric: m, scoreHistory: [], explanation: explanation.isEmpty ? nil : explanation)
        let detailVC = ScoreDetailWithGraphViewController(config: config)
        present(detailVC, animated: true)
    }

    private func secondaryCardTapped(index: Int) {
        guard let result = geminiResult,
              index < metricSelection.secondaryMetricIds.count else { return }
        let metricId = metricSelection.secondaryMetricIds[index]
        guard let m = geminiMetric(for: metricId, from: result) else { return }
        let explanation = geminiExplanation(for: metricId, from: result)
        let config = ScoreDetailConfig.from(metric: m, scoreHistory: [], explanation: explanation.isEmpty ? nil : explanation)
        let detailVC = ScoreDetailWithGraphViewController(config: config)
        present(detailVC, animated: true)
    }

    private func showMetricEditor() {
        let editorVC = MetricSelectionViewController(current: metricSelection)
        let nav = UINavigationController(rootViewController: editorVC)
        editorVC.onSave = { [weak self] newSelection in
            self?.metricSelection = newSelection
            self?.updateUI()
        }
        present(nav, animated: true)
    }

    // MARK: - AI Recommendations

    private func retryRecommendations() {
        // Force refresh from Gemini
        loadData()
    }

    // MARK: - Empty State

    private let emptyStateTag = 9999

    private func showEmptyState() {
        // Don't add twice
        guard view.viewWithTag(emptyStateTag) == nil else { return }

        // Choose icon and text based on failure reason
        let iconName: String
        let titleText: String
        let subtitleText: String

        switch lastFailureReason {
        case .geminiFailed:
            iconName = "wifi.exclamationmark"
            titleText = "dashboard.geminiFailed".localized
            subtitleText = "dashboard.geminiFailedSubtitle".localized
        case .noHealthData, .none:
            iconName = "heart.slash"
            titleText = "dashboard.noHealthData".localized
            subtitleText = "dashboard.noHealthDataSubtitle".localized
        }

        let container = UIView()
        container.tag = emptyStateTag
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)

        let icon = UIImageView(image: UIImage(systemName: iconName))
        icon.tintColor = AIONDesign.accentPrimary
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = titleText
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        title.textColor = .white
        title.textAlignment = .center
        title.numberOfLines = 0
        title.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = UILabel()
        subtitle.text = subtitleText
        subtitle.font = .systemFont(ofSize: 14, weight: .regular)
        subtitle.textColor = UIColor.white.withAlphaComponent(0.5)
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 0
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(icon)
        container.addSubview(title)
        container.addSubview(subtitle)

        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            container.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            container.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40),

            icon.topAnchor.constraint(equalTo: container.topAnchor),
            icon.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            icon.widthAnchor.constraint(equalToConstant: 48),
            icon.heightAnchor.constraint(equalToConstant: 48),

            title.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            title.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8),
            subtitle.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            subtitle.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            subtitle.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        // Fade in
        container.alpha = 0
        UIView.animate(withDuration: 0.3) { container.alpha = 1 }
    }

    private func removeEmptyState() {
        if let empty = view.viewWithTag(emptyStateTag) {
            empty.removeFromSuperview()
        }
    }

    // MARK: - Entrance Animations

    private func playEntranceAnimationIfNeeded() {
        guard !hasPlayedEntrance else { return }
        hasPlayedEntrance = true

        // Prepare views
        let animatableViews: [UIView] = [headerView, heroCard, secondaryGrid, recommendationsSection]
        for (i, view) in animatableViews.enumerated() {
            view.alpha = 0
            view.transform = CGAffineTransform(translationX: 0, y: 30)
        }
        contentStack.alpha = 1

        // Staggered entrance
        for (i, view) in animatableViews.enumerated() {
            UIView.animate(
                withDuration: 0.5,
                delay: Double(i) * 0.1,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.5,
                options: .curveEaseOut
            ) {
                view.alpha = 1
                view.transform = .identity
            }
        }
    }

    // MARK: - RTL/LTR

    private func configureSemanticDirection() {
        let rtl = LocalizationManager.shared.currentLanguage == .hebrew
        let sem: UISemanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        view.semanticContentAttribute = sem
        scrollView.semanticContentAttribute = sem
        contentStack.semanticContentAttribute = sem
        contentStack.alignment = .fill
    }

    // MARK: - Notifications Bell

    private func bellTapped() {
        let vc = NotificationsCenterViewController()
        vc.delegate = self
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true)
    }

    @objc private func handleNotificationItemSaved() { updateBellBadge() }

    private func updateBellBadge() {
        FriendsFirestoreSync.fetchUnreadNotificationsCount { [weak self] count in
            DispatchQueue.main.async {
                self?.headerView.updateBadge(count: count)
            }
        }
    }
}

// MARK: - UIScrollViewDelegate (Parallax)

extension InsightsDashboardViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offset = max(0, scrollView.contentOffset.y)  // Ignore negative (pull-to-refresh)
        // Subtle parallax: hero card scales down slightly as user scrolls down
        let scale = max(0.92, 1.0 - offset / 800.0)
        heroCard.transform = CGAffineTransform(scaleX: scale, y: scale)
    }
}

// MARK: - NotificationsCenterViewControllerDelegate

extension InsightsDashboardViewController: NotificationsCenterViewControllerDelegate {
    func notificationsCenterDidUpdate(_ controller: NotificationsCenterViewController) {
        headerView.updateBadge(count: 0)
        updateBellBadge()
    }
}

// MARK: - GeminiMetricProxy (wraps a Gemini score as InsightMetric)

private struct GeminiMetricProxy: InsightMetric {
    let id: String
    let nameKey: String
    let value: Double?
    let category: MetricCategory
    let reliability: DataReliability = .high
    let trend: MetricTrend? = nil
    var isStrain: Bool = false

    var displayValue: String {
        guard let v = value else { return "--" }
        if isStrain { return String(format: "%.1f", v) }
        return "\(Int(v))"
    }
}

// MARK: - Time Period Enum

enum TimePeriod: Int, CaseIterable {
    case day = 0
    case week = 1
    case month = 2

    var localizationKey: String {
        switch self {
        case .day: return "period.day"
        case .week: return "period.week"
        case .month: return "period.month"
        }
    }
}
