//
//  InsightsDashboardViewController.swift
//  Health Reporter
//
//  מסך ראשי חדש - Insights Dashboard
//  מציג משמעות ולא נתונים גולמיים
//

import UIKit
import FirebaseAuth

final class InsightsDashboardViewController: UIViewController {

    // MARK: - Properties

    private var dailyMetrics: DailyMetrics?
    private var starMetrics: StarMetrics?
    private var currentPeriodData: HealthDataModel?  // נתוני התקופה הנוכחית
    private var storedHistoricalData: [HealthDataModel] = []  // 90 days retained for 7-day charts
    private var scoreHistory: [DailyScoreEntry] = []           // 7-day computed score history
    private var isLoading = true
    private var selectedPeriod: TimePeriod = .day

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // Sections
    private let headerView = InsightsDashboardHeaderView()
    private let periodSelector = PeriodSelectorView()
    private let heroSection = HeroScoreSection()
    private let starMetricsBar = StarMetricsBarView()
    private let whyScoreSection = WhyScoreSection()
    private let recoverySectionView = RecoverySectionView()
    private let sleepSectionView = SleepSectionView()
    private let trainingSectionView = TrainingSectionView()
    private let activitySectionView = ActivitySectionCompact()
    private let guidanceCard = GuidanceCardView()

    private let loadingIndicator = UIActivityIndicatorView(style: .large)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()

        // Listen for app returning from background - refresh data
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func appWillEnterForeground() {
        // Refresh data when app returns from background (new data may be available)
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = AIONDesign.background

        // הגדרת כיוון סמנטי (RTL/LTR)
        configureSemanticDirection()

        // Scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)

        // Content stack
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        // Add sections to stack
        [headerView, periodSelector, heroSection, starMetricsBar,
         whyScoreSection, recoverySectionView, sleepSectionView,
         trainingSectionView, activitySectionView, guidanceCard].forEach {
            contentStack.addArrangedSubview($0)
        }

        // Loading indicator
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
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        // Setup callbacks
        periodSelector.onPeriodChanged = { [weak self] period in
            self?.handlePeriodChange(period)
        }

        whyScoreSection.isHidden = true // Initially collapsed
        heroSection.onWhyTapped = { [weak self] in
            self?.toggleWhySection()
        }

        heroSection.onCarTapped = { [weak self] in
            // Navigate to Insights tab when car cube is tapped
            self?.tabBarController?.selectedIndex = 2
        }

        heroSection.onSleepTapped = { [weak self] in
            self?.showSleepDetail()
        }

        starMetricsBar.onMetricTapped = { [weak self] metric in
            self?.showMetricDetail(metric)
        }
    }

    // MARK: - Data Loading

    private func loadData() {
        isLoading = true
        loadingIndicator.startAnimating()
        contentStack.isHidden = true

        // Determine data range based on selected period
        let dataRange: DataRange
        switch selectedPeriod {
        case .day: dataRange = .day
        case .week: dataRange = .week
        case .month: dataRange = .month
        }

        #if DEBUG
        // יוזר טסט - משתמשים בנתונים מדומים מה-cache
        if DebugTestHelper.isTestUser(email: FirebaseAuth.Auth.auth().currentUser?.email),
           let mockData = HealthDataCache.shared.healthData,
           let mockBundle = HealthDataCache.shared.chartBundle {
            print("🧪 [InsightsDashboard] Test user - using mock health data")
            loadDataWithMockData(mockData: mockData, mockBundle: mockBundle)
            return
        }
        #endif

        // Load data for selected period
        HealthKitManager.shared.fetchAllHealthData(for: dataRange) { [weak self] periodData, error in
            guard let self = self, let periodModel = periodData else {
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.loadingIndicator.stopAnimating()
                    self?.contentStack.isHidden = false
                }
                return
            }

            // Fetch historical data (90 days for all calculations)
            HealthKitManager.shared.fetchDailyHealthData(days: 90) { historicalEntries in
                // Convert RawDailyHealthEntry to HealthDataModel
                let historicalData = historicalEntries.map { entry -> HealthDataModel in
                    var model = HealthDataModel()
                    model.date = entry.date  // חשוב! צריך את התאריך לגרף השינה
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

                // Calculate metrics with period awareness
                // לוג נתוני periodModel
                print("📊 [Dashboard] periodModel for \(self.selectedPeriod): steps=\(periodModel.steps ?? 0), calories=\(periodModel.activeEnergy ?? 0)")

                // Retain historical data for 7-day chart calculations
                self.storedHistoricalData = historicalData

                DailyMetricsEngine.shared.calculateDailyMetrics(
                    todayData: periodModel,
                    historicalData: historicalData,
                    period: self.selectedPeriod
                ) { dailyMetrics in
                    DispatchQueue.main.async {
                        self.currentPeriodData = periodModel  // שמירת נתוני התקופה
                        self.dailyMetrics = dailyMetrics
                        self.starMetrics = StarMetricsCalculator.shared.calculateStarMetrics(from: dailyMetrics)
                        self.updateUI()
                        self.isLoading = false
                        self.loadingIndicator.stopAnimating()
                        self.contentStack.isHidden = false
                    }

                    // Compute 7-day score history in background
                    DailyMetricsEngine.shared.calculate7DayHistory(
                        fullHistoricalData: historicalData
                    ) { [weak self] history in
                        guard let self = self else { return }
                        self.scoreHistory = history
                        self.updateUI()  // Refresh to make history available to bottom sheets
                    }
                }
            }
        }
    }

    #if DEBUG
    /// טעינת נתונים מדומים ליוזר טסט
    private func loadDataWithMockData(mockData: HealthDataModel, mockBundle: AIONChartDataBundle) {
        print("🧪 [InsightsDashboard] Loading with mock data: steps=\(mockData.steps ?? 0), hrv=\(mockData.heartRateVariability ?? 0)")

        // יצירת היסטוריה מדומה מה-chartBundle (7 ימים)
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

        print("🧪 [InsightsDashboard] Mock data: steps=\(mockData.steps ?? 0), calories=\(mockData.activeEnergy ?? 0)")

        DailyMetricsEngine.shared.calculateDailyMetrics(
            todayData: mockData,
            historicalData: historicalData,
            period: self.selectedPeriod
        ) { dailyMetrics in
            DispatchQueue.main.async {
                self.currentPeriodData = mockData
                self.dailyMetrics = dailyMetrics
                self.starMetrics = StarMetricsCalculator.shared.calculateStarMetrics(from: dailyMetrics)
                self.updateUI()
                self.isLoading = false
                self.loadingIndicator.stopAnimating()
                self.contentStack.isHidden = false
            }
        }
    }
    #endif

    private func updateUI() {
        guard let metrics = dailyMetrics, let stars = starMetrics else { return }

        // Update header
        headerView.configure()

        // Update hero section with correct scores
        heroSection.configure(
            healthScore: metrics.mainScore != nil ? Int(metrics.mainScore!) : nil,
            carScore: getCarScore(),
            carName: getCarName(),
            sleepScore: metrics.sleepQuality.value != nil ? Int(metrics.sleepQuality.value!) : nil,
            energyForecast: metrics.energyForecast,
            parentVC: self,
            scoreHistory: self.scoreHistory
        )

        // שמירת הציון הראשי היומי
        if let mainScore = metrics.mainScore {
            let scoreInt = Int(mainScore)
            let scoreLevel = RangeLevel.from(score: mainScore)
            let healthStatus = "score.description.\(scoreLevel.rawValue)".localized

            AnalysisCache.saveMainScore(scoreInt, status: healthStatus)
        }

        // שמירת פירוט הציונים לשליחה לשעון (רק כשזה יום)
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

        // Update star metrics bar
        starMetricsBar.configure(with: stars)

        // Update why score section
        whyScoreSection.configure(with: metrics)

        // Update recovery section
        recoverySectionView.configure(
            readiness: metrics.recoveryReadiness,
            stressLoad: metrics.stressLoadIndex,
            morningFreshness: metrics.morningFreshness,
            parentVC: self,
            scoreHistory: self.scoreHistory
        )

        // Update sleep section
        sleepSectionView.configure(
            quality: metrics.sleepQuality,
            debt: metrics.sleepDebt,
            consistency: metrics.sleepConsistency,
            parentVC: self,
            scoreHistory: self.scoreHistory
        )

        // Update training section
        trainingSectionView.configure(
            strain: metrics.trainingStrain,
            loadBalance: metrics.loadBalance,
            cardioTrend: metrics.cardioFitnessTrend,
            parentVC: self,
            scoreHistory: self.scoreHistory
        )

        // Update activity section
        activitySectionView.configure(
            goals: metrics.dailyGoals,
            activityScore: metrics.activityScore,
            parentVC: self,
            scoreHistory: self.scoreHistory
        )

        // Update guidance card
        guidanceCard.configure(with: metrics, stars: stars)
    }

    // MARK: - Actions

    private func handlePeriodChange(_ period: TimePeriod) {
        guard period != selectedPeriod else { return }
        selectedPeriod = period
        loadData() // Reload data for new period
    }

    private func toggleWhySection() {
        UIView.animate(withDuration: 0.3) {
            self.whyScoreSection.isHidden.toggle()
            self.whyScoreSection.alpha = self.whyScoreSection.isHidden ? 0 : 1
        }
    }

    private func showMetricDetail(_ metric: any InsightMetric) {
        let config = ScoreDetailConfig.from(
            metric: metric,
            scoreHistory: self.scoreHistory
        )
        let detailVC = ScoreDetailWithGraphViewController(config: config)
        present(detailVC, animated: true)
    }

    private func showSleepDetail() {
        let alert = UIAlertController(
            title: "dashboard.sleepScore".localized,
            message: "explanation.sleepScore".localized,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "ok".localized, style: .default))
        present(alert, animated: true)
    }

    // MARK: - Score Helpers

    /// מחזיר את ציון הרכב - אותה לוגיקה כמו ב-InsightsTabViewController
    private func getCarScore() -> Int? {
        // עדיפות לציון השמור מ-HealthScoreEngine
        if let savedScore = AnalysisCache.loadHealthScore() {
            return savedScore
        }
        // fallback: חישוב מ-CarTierEngine
        let stats = AnalysisCache.loadWeeklyStats()
        let score = CarTierEngine.computeHealthScore(
            readinessAvg: stats?.readiness,
            sleepHoursAvg: stats?.sleepHours,
            hrvAvg: stats?.hrv,
            strainAvg: stats?.strain
        )
        return score > 0 ? score : nil
    }

    /// מחזיר את שם הרכב - רק מ-Gemini! אסור להציג שמות גנריים
    private func getCarName() -> String? {
        // ONLY return Gemini car name - NEVER use generic tier names
        if let savedCar = AnalysisCache.loadSelectedCar() {
            return savedCar.name
        }
        // No Gemini data = no car name (don't show generic tier names like Porsche/BMW)
        return nil
    }

    // MARK: - RTL/LTR Support

    private func configureSemanticDirection() {
        let isRTL = UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft
        let semanticAttribute: UISemanticContentAttribute = isRTL ? .forceRightToLeft : .forceLeftToRight

        view.semanticContentAttribute = semanticAttribute
        scrollView.semanticContentAttribute = semanticAttribute
        contentStack.semanticContentAttribute = semanticAttribute

        // הגדרת alignment לפי כיוון השפה
        contentStack.alignment = .fill
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
