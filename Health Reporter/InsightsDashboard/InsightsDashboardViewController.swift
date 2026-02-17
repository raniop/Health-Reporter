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

    private var dailyMetrics: DailyMetrics?
    private var starMetrics: StarMetrics?
    private var currentPeriodData: HealthDataModel?
    private var storedHistoricalData: [HealthDataModel] = []
    private var scoreHistory: [DailyScoreEntry] = []
    private var isLoading = true
    private var selectedPeriod: TimePeriod = .day
    private var lastUpdatedTime: Date?
    private var metricSelection = HomeMetricSelection.load()
    private var recommendations: HomeRecommendations?
    private var hasPlayedEntrance = false
    private var lastRecsHealthData: HealthDataModel?
    private var lastRecsDailyMetrics: DailyMetrics?

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
        isLoading = true
        if !isPullToRefresh {
            loadingIndicator.startAnimating()
            contentStack.isHidden = true
        }

        let dataRange: DataRange
        switch selectedPeriod {
        case .day: dataRange = .day
        case .week: dataRange = .week
        case .month: dataRange = .month
        }

        #if DEBUG
        if DebugTestHelper.isTestUser(email: Auth.auth().currentUser?.email),
           let mockData = HealthDataCache.shared.healthData,
           let mockBundle = HealthDataCache.shared.chartBundle {
            print("🧪 [InsightsDashboard] Test user - using mock health data")
            loadDataWithMockData(mockData: mockData, mockBundle: mockBundle)
            return
        }
        #endif

        HealthKitManager.shared.fetchAllHealthData(for: dataRange) { [weak self] periodData, error in
            guard let self = self, let periodModel = periodData else {
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.loadingIndicator.stopAnimating()
                    self?.refreshControl.endRefreshing()
                    self?.contentStack.isHidden = false
                }
                return
            }

            HealthKitManager.shared.fetchDailyHealthData(days: 90) { historicalEntries in
                let historicalData = historicalEntries.map { entry -> HealthDataModel in
                    var model = HealthDataModel()
                    model.date = entry.date
                    model.steps = entry.steps
                    model.heartRateVariability = entry.hrvMs
                    model.restingHeartRate = entry.restingHR
                    model.sleepHours = entry.sleepHours
                    model.sleepDeepHours = entry.deepSleepHours
                    model.sleepRemHours = entry.remSleepHours
                    model.activeEnergy = entry.activeCalories
                    model.vo2Max = entry.vo2max
                    return model
                }

                self.storedHistoricalData = historicalData

                DailyMetricsEngine.shared.calculateDailyMetrics(
                    todayData: periodModel,
                    historicalData: historicalData,
                    period: self.selectedPeriod
                ) { dailyMetrics in
                    DispatchQueue.main.async {
                        self.currentPeriodData = periodModel
                        self.dailyMetrics = dailyMetrics
                        self.starMetrics = StarMetricsCalculator.shared.calculateStarMetrics(from: dailyMetrics)
                        self.lastUpdatedTime = Date()
                        self.updateUI()
                        self.isLoading = false
                        self.loadingIndicator.stopAnimating()
                        self.refreshControl.endRefreshing()
                        self.contentStack.isHidden = false
                        self.playEntranceAnimationIfNeeded()
                    }

                    // 7-day score history
                    DailyMetricsEngine.shared.calculate7DayHistory(
                        fullHistoricalData: historicalData
                    ) { [weak self] history in
                        guard let self = self else { return }
                        self.scoreHistory = history
                        DispatchQueue.main.async {
                            self.updateUI()
                        }
                    }

                    // Fetch AI recommendations
                    self.fetchRecommendations(healthData: periodModel, dailyMetrics: dailyMetrics)
                }
            }
        }
    }

    #if DEBUG
    private func loadDataWithMockData(mockData: HealthDataModel, mockBundle: AIONChartDataBundle) {
        var historicalData: [HealthDataModel] = []
        for i in 0..<mockBundle.steps.points.count {
            var dayModel = HealthDataModel()
            dayModel.date = mockBundle.steps.points[i].date
            dayModel.steps = mockBundle.steps.points[i].steps
            if i < mockBundle.hrvTrend.points.count {
                dayModel.heartRateVariability = mockBundle.hrvTrend.points[i].value
            }
            if i < mockBundle.rhrTrend.points.count {
                dayModel.restingHeartRate = mockBundle.rhrTrend.points[i].value
            }
            if i < mockBundle.sleep.points.count {
                dayModel.sleepHours = mockBundle.sleep.points[i].totalHours
                dayModel.sleepDeepHours = mockBundle.sleep.points[i].deepHours
                dayModel.sleepRemHours = mockBundle.sleep.points[i].remHours
            }
            if i < mockBundle.glucoseEnergy.points.count {
                dayModel.activeEnergy = mockBundle.glucoseEnergy.points[i].activeEnergy
            }
            historicalData.append(dayModel)
        }

        DailyMetricsEngine.shared.calculateDailyMetrics(
            todayData: mockData,
            historicalData: historicalData,
            period: self.selectedPeriod
        ) { dailyMetrics in
            DispatchQueue.main.async {
                self.currentPeriodData = mockData
                self.dailyMetrics = dailyMetrics
                self.starMetrics = StarMetricsCalculator.shared.calculateStarMetrics(from: dailyMetrics)
                self.lastUpdatedTime = Date()
                self.updateUI()
                self.isLoading = false
                self.loadingIndicator.stopAnimating()
                self.refreshControl.endRefreshing()
                self.contentStack.isHidden = false
                self.playEntranceAnimationIfNeeded()
            }
        }
    }
    #endif

    // MARK: - Update UI

    private func updateUI() {
        guard let metrics = dailyMetrics else { return }

        // Header
        headerView.configure(lastUpdated: lastUpdatedTime)

        // Save score data (keep existing behaviour)
        if let mainScore = metrics.mainScore {
            let scoreInt = Int(mainScore)
            let scoreLevel = RangeLevel.from(score: mainScore)
            let healthStatus = "score.description.\(scoreLevel.rawValue)".localized
            AnalysisCache.saveMainScore(scoreInt, status: healthStatus)
        }
        if selectedPeriod == .day {
            AnalysisCache.saveScoreBreakdown(
                recovery: metrics.recoveryReadiness.value.map { Int($0) },
                sleep: metrics.sleepQuality.value.map { Int($0) },
                nervousSystem: metrics.nervousSystemBalance.value.map { Int($0) },
                energy: metrics.energyForecast.value.map { Int($0) },
                activity: metrics.activityScore.value.map { Int($0) },
                loadBalance: metrics.loadBalance.value.map { Int($0) }
            )
        }

        // Hero card
        let heroMetric = findMetric(id: metricSelection.heroMetricId, in: metrics)
        let heroChartData = buildChartData(for: metricSelection.heroMetricId)
        let heroExplanation = explanationText(for: metricSelection.heroMetricId)
        heroCard.configure(
            metric: heroMetric,
            metricId: metricSelection.heroMetricId,
            chartData: heroChartData,
            explanationText: heroExplanation
        )

        // Secondary cards
        for (i, cardView) in secondaryCards.enumerated() {
            guard i < metricSelection.secondaryMetricIds.count else { continue }
            let metricId = metricSelection.secondaryMetricIds[i]
            let metric = findMetric(id: metricId, in: metrics)
            let chartData = buildChartData(for: metricId)
            let explanation = explanationText(for: metricId)
            cardView.configure(metric: metric, metricId: metricId, chartData: chartData, explanationText: explanation)
        }

        // Recommendations
        recommendationsSection.configure(recommendations: recommendations)
    }

    // MARK: - Metric Lookup Helpers

    private func findMetric(id: String, in metrics: DailyMetrics) -> (any InsightMetric)? {
        if id == "main_score" || id == "health_score" {
            // mainScore is a computed Double, not an InsightMetric — wrap it
            return metrics.allMetrics.first { $0.id == "recovery_readiness" }.map { _ in
                MainScoreProxy(value: metrics.mainScore)
            }
        }
        return metrics.allMetrics.first { $0.id == id }
    }

    private func buildChartData(for metricId: String) -> [BarChartDataPoint] {
        scoreHistory.map { entry in
            BarChartDataPoint(
                date: entry.date,
                dayLabel: entry.dayOfWeekShort,
                value: entry.value(for: metricId) ?? 0,
                isToday: Calendar.current.isDateInToday(entry.date)
            )
        }
    }

    private func explanationText(for metricId: String) -> String {
        let key = "explanation.\(metricId)"
        let localized = key.localized
        return localized != key ? localized : ""
    }

    // MARK: - Actions

    private func heroCardTapped() {
        guard let metrics = dailyMetrics else { return }
        let metric = findMetric(id: metricSelection.heroMetricId, in: metrics)
        guard let m = metric else { return }
        let config = ScoreDetailConfig.from(metric: m, scoreHistory: scoreHistory)
        let detailVC = ScoreDetailWithGraphViewController(config: config)
        present(detailVC, animated: true)
    }

    private func secondaryCardTapped(index: Int) {
        guard let metrics = dailyMetrics,
              index < metricSelection.secondaryMetricIds.count else { return }
        let metricId = metricSelection.secondaryMetricIds[index]
        guard let m = findMetric(id: metricId, in: metrics) else { return }
        let config = ScoreDetailConfig.from(metric: m, scoreHistory: scoreHistory)
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

    private func fetchRecommendations(healthData: HealthDataModel, dailyMetrics: DailyMetrics) {
        print("🏠 [HomeRecs] fetchRecommendations called — always fresh from Gemini")

        // Store for retry
        lastRecsHealthData = healthData
        lastRecsDailyMetrics = dailyMetrics

        // Show loading state
        DispatchQueue.main.async {
            self.recommendationsSection.configure(recommendations: nil)
        }

        GeminiService.shared.generateHomeRecommendations(
            healthData: healthData,
            dailyMetrics: dailyMetrics
        ) { [weak self] recs in
            if let recs = recs {
                print("🏠 [HomeRecs] Got recommendations ✅ medical=\(recs.medical.prefix(50))...")
            } else {
                print("🏠 [HomeRecs] Gemini returned nil ❌ — lastHomeRecsHadNoData=\(GeminiService.shared.lastHomeRecsHadNoData)")
            }
            DispatchQueue.main.async {
                self?.recommendations = recs
                if let recs = recs {
                    self?.recommendationsSection.isHidden = false
                    self?.recommendationsSection.configure(recommendations: recs)
                } else if GeminiService.shared.lastHomeRecsHadNoData {
                    // No health data available — hide the section entirely
                    print("🏠 [HomeRecs] No health data — hiding recommendations section")
                    self?.recommendationsSection.isHidden = true
                } else {
                    // API error — show retry
                    self?.recommendationsSection.isHidden = false
                    self?.recommendationsSection.showError()
                }
            }
        }
    }

    private func retryRecommendations() {
        guard let healthData = lastRecsHealthData, let dailyMetrics = lastRecsDailyMetrics else {
            print("🏠 [HomeRecs] Retry — no stored data, calling loadData()")
            loadData()
            return
        }
        print("🏠 [HomeRecs] Retry tapped — fetching fresh recommendations")
        fetchRecommendations(healthData: healthData, dailyMetrics: dailyMetrics)
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

// MARK: - MainScoreProxy (wraps the composite mainScore as InsightMetric)

private struct MainScoreProxy: InsightMetric {
    let id = "main_score"
    let nameKey = "dashboard.healthScore"
    let value: Double?
    let category: MetricCategory = .performance
    let reliability: DataReliability = .high
    let trend: MetricTrend? = nil

    var displayValue: String {
        guard let v = value else { return "--" }
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
