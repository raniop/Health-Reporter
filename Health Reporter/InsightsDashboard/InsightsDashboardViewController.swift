//
//  InsightsDashboardViewController.swift
//  Health Reporter
//
//  מסך ראשי חדש - Insights Dashboard
//  מציג משמעות ולא נתונים גולמיים
//

import UIKit

final class InsightsDashboardViewController: UIViewController {

    // MARK: - Properties

    private var dailyMetrics: DailyMetrics?
    private var starMetrics: StarMetrics?
    private var currentPeriodData: HealthDataModel?  // נתוני התקופה הנוכחית
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
                }
            }
        }
    }

    private func updateUI() {
        guard let metrics = dailyMetrics, let stars = starMetrics else { return }

        // Update header
        headerView.configure()

        // Update hero section
        heroSection.configure(
            mainScore: metrics.mainScore,
            energyForecast: metrics.energyForecast,
            parentVC: self
        )

        // שמירת הציון הראשי היומי ושליחה לשעון
        if let mainScore = metrics.mainScore {
            let scoreInt = Int(mainScore)
            let scoreLevel = RangeLevel.from(score: mainScore)
            let healthStatus = "score.description.\(scoreLevel.rawValue)".localized

            AnalysisCache.saveMainScore(scoreInt, status: healthStatus)

            // NOTE: לא שולחים לשעון ממסך תובנות - רק מהדשבורד הראשי
            // כדי למנוע שיבוש נתונים בשעון עקב ציונים שונים בין המסכים
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
            parentVC: self
        )

        // Update sleep section
        sleepSectionView.configure(
            quality: metrics.sleepQuality,
            debt: metrics.sleepDebt,
            consistency: metrics.sleepConsistency,
            parentVC: self
        )

        // Update training section
        trainingSectionView.configure(
            strain: metrics.trainingStrain,
            loadBalance: metrics.loadBalance,
            cardioTrend: metrics.cardioFitnessTrend,
            parentVC: self
        )

        // Update activity section
        activitySectionView.configure(
            goals: metrics.dailyGoals,
            activityScore: metrics.activityScore,
            parentVC: self
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
        let detailVC = MetricDetailViewController(metric: metric)
        present(detailVC, animated: true)
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
