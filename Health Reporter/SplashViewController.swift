import UIKit
import HealthKit
import FirebaseAuth

/// Dynamic Splash Screen that loads data in the background
/// Displayed instead of the static LaunchScreen.storyboard and performs data loading
class SplashViewController: UIViewController {

    // MARK: - UI Elements
    private let logoImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "LaunchLogoNew"))
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "AION"
        label.font = .boldSystemFont(ofSize: 30)
        label.textColor = .white  // Always white in Splash (fixed dark background)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let accentBar: UIView = {
        let view = UIView()
        view.backgroundColor = AIONDesign.accentSecondary  // Turquoise
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "splash.healthReport".localized
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = UIColor(red: 0.612, green: 0.584, blue: 0.557, alpha: 1.0)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = AIONDesign.accentSecondary
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "loading".localized
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = UIColor(red: 0.612, green: 0.584, blue: 0.557, alpha: 1.0)
        label.textAlignment = .center
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        startLoading()
    }

    // MARK: - Setup

    private func setupUI() {
        // Dark background like LaunchScreen
        view.backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.118, alpha: 1.0)

        // Add elements
        view.addSubview(logoImageView)
        view.addSubview(titleLabel)
        view.addSubview(accentBar)
        view.addSubview(subtitleLabel)
        view.addSubview(loadingIndicator)
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            // Logo - centered with upward offset
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -80),
            logoImageView.widthAnchor.constraint(equalToConstant: 200),
            logoImageView.heightAnchor.constraint(equalToConstant: 200),

            // Title - below logo
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 16),

            // Accent bar - below title
            accentBar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            accentBar.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            accentBar.widthAnchor.constraint(equalToConstant: 50),
            accentBar.heightAnchor.constraint(equalToConstant: 4),

            // Subtitle - below bar
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: accentBar.bottomAnchor, constant: 16),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),

            // Loading indicator - below everything
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),

            // Status label - below indicator
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: loadingIndicator.bottomAnchor, constant: 12),
        ])
    }

    // MARK: - Loading

    private func startLoading() {
        // Show loading
        loadingIndicator.startAnimating()
        UIView.animate(withDuration: 0.3) {
            self.statusLabel.alpha = 1
        }

        #if DEBUG
        // If this is a test user - inject mock data and go to Onboarding
        // The Onboarding will request HealthKit permissions and call Gemini with mock data
        if DebugTestHelper.isTestUser(email: FirebaseAuth.Auth.auth().currentUser?.email) {
            print("🧪 [Splash] Test user detected - setting up mock data and going to Onboarding")
            // Important! Inject mock data here because we may not have gone through Login
            DebugTestHelper.shared.setupTestUserData()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.transitionToMain()
            }
            return
        }
        #endif

        // Check if HealthKit is available
        guard HealthKitManager.shared.isHealthDataAvailable() else {
            transitionToMain()
            return
        }

        // Request HealthKit authorization
        HealthKitManager.shared.requestAuthorization { [weak self] success, _ in
            guard let self = self else { return }

            if !success {
                // If no permission - go to main screen anyway
                DispatchQueue.main.async {
                    self.transitionToMain()
                }
                return
            }

            // Load data
            self.loadHealthData()
        }
    }

    private func loadHealthData() {
        DispatchQueue.main.async {
            self.statusLabel.text = "splash.syncAppleHealth".localized
        }

        // Load health data
        HealthKitManager.shared.fetchAllHealthData(for: .week) { [weak self] data, _ in
            guard let self = self else { return }

            // Save to cache
            HealthDataCache.shared.healthData = data

            DispatchQueue.main.async {
                self.statusLabel.text = "splash.processingData".localized
            }

            // Calculate HealthScore and sync to Firestore in background
            self.calculateAndSyncHealthScore()

            // Load chart data
            HealthKitManager.shared.fetchChartData(for: .week) { [weak self] bundle in
                guard let self = self else { return }

                // Save to cache
                HealthDataCache.shared.chartBundle = bundle

                // Trigger Gemini analysis in background (non-blocking UI)
                self.triggerBackgroundGeminiAnalysis(healthData: data, chartBundle: bundle)

                DispatchQueue.main.async {
                    self.transitionToMain()
                }
            }
        }
    }

    /// Calculate HealthScore from 90-day data and sync to Firestore
    private func calculateAndSyncHealthScore() {
        HealthKitManager.shared.fetchDailyHealthData(days: 90) { dailyEntries in
            let healthResult = HealthScoreEngine.shared.calculate(from: dailyEntries)
            AnalysisCache.saveHealthScoreResult(healthResult)

            // Sync to Firestore (leaderboard and friend search)
            let score = healthResult.healthScoreInt
            let tier = CarTierEngine.tierForScore(score)
            // Use car name from Gemini if available in cache
            let cachedCarName = AnalysisCache.loadSelectedCar()?.name
            print("🚗 [Splash] Syncing score with cachedCarName: \(cachedCarName ?? "nil")")
            LeaderboardFirestoreSync.syncScore(score: score, tier: tier, geminiCarName: cachedCarName)

            // Save yesterday's steps for morning notification (separate from daily activity)
            let calendar = Calendar.current
            let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
            let yesterdayStart = calendar.startOfDay(for: yesterday)
            if let yesterdayEntry = dailyEntries.first(where: { calendar.isDate($0.date, inSameDayAs: yesterdayStart) }) {
                let steps = Int(yesterdayEntry.steps ?? 0)
                let calories = Int(yesterdayEntry.activeCalories ?? 0)
                AnalysisCache.saveYesterdayActivity(steps: steps, calories: calories)
                print("📊 [Splash] Saved YESTERDAY's activity: steps=\(steps), calories=\(calories)")
            }

            // Calculate daily mainScore from DailyMetrics (same as InsightsDashboard)
            // This ensures mainScore is always fresh and correct, not stale from cache
            let historicalData = dailyEntries.map { entry -> HealthDataModel in
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
            let todayModel = historicalData.last ?? HealthDataModel()

            DailyMetricsEngine.shared.calculateDailyMetrics(
                todayData: todayModel,
                historicalData: historicalData,
                period: .day
            ) { [weak self] dailyMetrics in
                guard let self = self else { return }

                // Save the fresh daily mainScore
                let freshMainScore: Int
                if let mainScore = dailyMetrics.mainScore {
                    freshMainScore = Int(mainScore)
                    let scoreLevel = RangeLevel.from(score: mainScore)
                    let freshStatus = "score.description.\(scoreLevel.rawValue)".localized
                    AnalysisCache.saveMainScore(freshMainScore, status: freshStatus)
                    print("📱 [Splash] ✅ Calculated fresh dailyMainScore=\(freshMainScore) from DailyMetrics")
                } else {
                    // No enough data for mainScore - use 0
                    freshMainScore = 0
                    print("📱 [Splash] ⚠️ DailyMetrics.mainScore is nil (not enough data)")
                }

                // Send to watch - latest day data with fresh daily score
                let todayEntry = dailyEntries.last
                let displayScore = freshMainScore
                let healthStatus: String
                if freshMainScore > 0 {
                    let scoreLevel = RangeLevel.from(score: Double(freshMainScore))
                    healthStatus = "score.description.\(scoreLevel.rawValue)".localized
                } else {
                    healthStatus = ""
                }

                print("📱 [Splash] DEBUG: freshMainScore=\(freshMainScore), gemini90d=\(score), displayScore=\(displayScore)")

                // Fetch fresh exercise and stand data from HealthKit for today
                let startOfDay = calendar.startOfDay(for: Date())
                let endOfDay = Date()

                HealthKitManager.shared.fetchExerciseMinutes(startDate: startOfDay, endDate: endOfDay) { exerciseMinutes in
                    HealthKitManager.shared.fetchStandHours(startDate: startOfDay, endDate: endOfDay) { standHours in
                        DispatchQueue.main.async {
                            let exercise = Int(exerciseMinutes ?? 0)
                            let stand = Int(standHours ?? 0)

                            // Check: if Gemini data exists in cache - use it for widget
                            let geminiCar = AnalysisCache.loadSelectedCar()
                            let geminiScore = AnalysisCache.loadHealthScore()
                            let userName = Auth.auth().currentUser?.displayName ?? ""

                            if let geminiCarName = geminiCar?.name, let geminiScoreValue = geminiScore {
                                // Has Gemini data - update widget with car name and score from Gemini
                                let geminiTier = CarTierEngine.tierForScore(geminiScoreValue)

                                // Prefetch car image for faster loading in Insights tab
                                if let wikiName = geminiCar?.wikiName, !wikiName.isEmpty {
                                    WidgetDataManager.shared.prefetchCarImage(wikiName: wikiName)
                                }
                                WidgetDataManager.shared.updateFromInsights(
                                    score: geminiScoreValue,
                                    dailyScore: displayScore,  // Daily score for secondary display
                                    status: healthStatus,
                                    carName: geminiCarName,
                                    carEmoji: geminiTier.emoji,
                                    steps: Int(todayEntry?.steps ?? 0),
                                    activeCalories: Int(todayEntry?.activeCalories ?? 0),
                                    exerciseMinutes: exercise,
                                    standHours: stand,
                                    restingHR: todayEntry?.restingHR.map { Int($0) },
                                    hrv: todayEntry?.hrvMs.map { Int($0) },
                                    sleepHours: todayEntry?.sleepHours,
                                    userName: userName
                                )
                                print("📱 [Splash] Widget updated with Gemini data: car=\(geminiCarName), score=\(geminiScoreValue), user=\(userName)")

                                // Send to watch - with daily score (not Gemini!) to maintain consistency
                                // ALWAYS use Gemini car name - never generic tier names
                                WatchConnectivityManager.shared.sendWidgetDataToWatch(
                                    healthScore: displayScore,
                                    healthStatus: healthStatus,
                                    steps: Int(todayEntry?.steps ?? 0),
                                    calories: Int(todayEntry?.activeCalories ?? 0),
                                    exerciseMinutes: exercise,
                                    standHours: stand,
                                    heartRate: todayEntry?.restingHR.map { Int($0) } ?? 0,
                                    hrv: todayEntry?.hrvMs.map { Int($0) } ?? 0,
                                    sleepHours: todayEntry?.sleepHours ?? 0,
                                    carName: geminiCarName,  // Use Gemini car name, not tier.name
                                    carEmoji: geminiTier.emoji,
                                    carTierIndex: geminiTier.tierIndex,
                                    carTierLabel: geminiTier.tierLabel,
                                    geminiCarName: geminiCarName,
                                    geminiCarScore: geminiScoreValue
                                )
                            } else {
                                // No Gemini data - use regular score (calculated from HealthScore)
                                // Note: updateFromDashboard will use empty car name since no Gemini data
                                WidgetDataManager.shared.updateFromDashboard(
                                    score: displayScore,
                                    status: healthStatus,
                                    steps: Int(todayEntry?.steps ?? 0),
                                    activeCalories: Int(todayEntry?.activeCalories ?? 0),
                                    exerciseMinutes: exercise,
                                    standHours: stand,
                                    restingHR: todayEntry?.restingHR.map { Int($0) },
                                    hrv: todayEntry?.hrvMs.map { Int($0) },
                                    sleepHours: todayEntry?.sleepHours,
                                    carTier: CarTierEngine.tierForScore(displayScore),
                                    userName: userName
                                )
                                print("📱 [Splash] Widget updated - no Gemini data yet, score=\(displayScore), user=\(userName)")
                            }
                            print("📱 [Splash] Sent to Watch: score=\(displayScore), steps=\(Int(todayEntry?.steps ?? 0)), exercise=\(exercise), stand=\(stand)")
                        }
                    }
                }
            } // end DailyMetricsEngine callback
        }
    }

    // MARK: - Transition

    private func transitionToMain() {
        loadingIndicator.stopAnimating()

        guard let window = view.window else {
            // Fallback if no window
            let nextVC = getNextViewController()
            if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
                sceneDelegate.window?.rootViewController = nextVC
                sceneDelegate.window?.makeKeyAndVisible()
            }
            return
        }

        let nextVC = getNextViewController()

        // Smooth transition animation
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: {
            window.rootViewController = nextVC
        }, completion: nil)
    }

    /// Returns the next ViewController - Onboarding for new user, Main for existing user
    private func getNextViewController() -> UIViewController {
        #if DEBUG
        // Test user always goes to Onboarding (including HealthKit permissions and Gemini)
        if DebugTestHelper.isTestUser(email: FirebaseAuth.Auth.auth().currentUser?.email) {
            print("🧪 [Splash] Test user - forcing OnboardingPageViewController")
            return OnboardingPageViewController()
        }
        #endif

        // Check if Onboarding should be shown (new user or test user)
        if OnboardingManager.shouldShowOnboarding(isSignUp: false, additionalUserInfo: nil) {
            print("🧪 [Splash] User needs onboarding - showing OnboardingPageViewController")
            return OnboardingPageViewController()
        }

        // Existing user - go straight to main screen
        print("🧪 [Splash] Existing user - showing MainTabBarController")
        return MainTabBarController()
    }

    // MARK: - Background Gemini Analysis

    /// Triggers Gemini analysis in the background immediately on app launch
    /// The analysis runs in parallel with the transition to Dashboard and does not block the UI
    private func triggerBackgroundGeminiAnalysis(healthData: HealthDataModel?, chartBundle: AIONChartDataBundle?) {
        guard let data = healthData, data.hasRealData else {
            return
        }

        // Create hash for cache check
        let healthDataHash: String
        if let bundle = chartBundle {
            healthDataHash = AnalysisCache.generateHealthDataHash(from: bundle)
        } else {
            healthDataHash = AnalysisCache.generateHealthDataHash(from: data)
        }

        // Check if Gemini call is needed (has data changed?)
        // Using hasSignificantChange like in Dashboard for consistency
        let shouldRun: Bool
        if let bundle = chartBundle {
            shouldRun = AnalysisCache.hasSignificantChange(currentBundle: bundle)
        } else {
            shouldRun = AnalysisCache.shouldRunAnalysis(forceAnalysis: false, currentHealthDataHash: healthDataHash)
        }

        guard shouldRun else {
            // Send notification to update UI from cache
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: HealthDashboardViewController.analysisDidCompleteNotification,
                    object: nil
                )
            }
            return
        }

        // Run on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            let calendar = Calendar.current
            let now = Date()

            guard let curStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)),
                  let curEnd = calendar.date(byAdding: .day, value: 6, to: curStart),
                  let prevStart = calendar.date(byAdding: .weekOfYear, value: -1, to: curStart),
                  let prevEnd = calendar.date(byAdding: .day, value: 6, to: prevStart) else {
                return
            }

            let group = DispatchGroup()
            var currentWeek: WeeklyHealthSnapshot?
            var previousWeek: WeeklyHealthSnapshot?

            group.enter()
            HealthKitManager.shared.createWeeklySnapshot(weekStartDate: prevStart, weekEndDate: prevEnd) {
                previousWeek = $0
                group.leave()
            }

            group.enter()
            HealthKitManager.shared.createWeeklySnapshot(weekStartDate: curStart, weekEndDate: curEnd, previousWeekSnapshot: nil) {
                currentWeek = $0
                group.leave()
            }

            group.notify(queue: .global(qos: .userInitiated)) {
                guard let current = currentWeek, let previous = previousWeek else {
                    return
                }

                GeminiService.shared.analyzeHealthDataWithWeeklyComparison(
                    data,
                    currentWeek: current,
                    previousWeek: previous,
                    chartBundle: chartBundle
                ) { insights, _, _, error in
                    if error != nil {
                        return
                    }

                    if let insights = insights {
                        AnalysisCache.save(insights: insights, healthDataHash: healthDataHash)
                        AnalysisFirestoreSync.saveIfLoggedIn(insights: insights, recommendations: "")
                    }

                    // Send notification to update the UI
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: HealthDashboardViewController.analysisDidCompleteNotification,
                            object: nil
                        )
                    }
                }
            }
        }
    }
}
