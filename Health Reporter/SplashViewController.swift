import UIKit
import HealthKit
import FirebaseAuth

/// Dynamic Splash Screen that loads data and waits for Gemini analysis to complete
/// Displayed instead of the static LaunchScreen.storyboard
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

    private let progressBar: UIProgressView = {
        let bar = UIProgressView(progressViewStyle: .default)
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.progressTintColor = AIONDesign.accentSecondary
        bar.trackTintColor = UIColor.white.withAlphaComponent(0.1)
        bar.layer.cornerRadius = 2
        bar.clipsToBounds = true
        bar.progress = 0
        bar.alpha = 0
        return bar
    }()

    // MARK: - State
    private var hasTransitioned = false
    private var timeoutWorkItem: DispatchWorkItem?
    private var progressTimer: Timer?
    private var currentProgress: Float = 0

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
        view.addSubview(progressBar)

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

            // Progress bar - below subtitle
            progressBar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressBar.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 32),
            progressBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 60),
            progressBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -60),
            progressBar.heightAnchor.constraint(equalToConstant: 4),

            // Loading indicator - below progress bar
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 16),

            // Status label - below indicator
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: loadingIndicator.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
    }

    // MARK: - Progress Helpers

    private func updateProgress(_ value: Float, status: String, animated: Bool = true) {
        DispatchQueue.main.async {
            UIView.animate(withDuration: animated ? 0.4 : 0) {
                self.progressBar.setProgress(value, animated: animated)
                self.statusLabel.text = status
            }
        }
    }

    // MARK: - Loading

    private func startLoading() {
        // Show loading
        loadingIndicator.startAnimating()
        UIView.animate(withDuration: 0.3) {
            self.statusLabel.alpha = 1
            self.progressBar.alpha = 1
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

        // Check if onboarding is needed BEFORE doing any heavy work (HealthKit / Gemini)
        // This handles reinstall: Firebase Auth survives (Keychain) but UserDefaults is cleared
        if !OnboardingManager.hasCompletedOnboarding() {
            print("🔍 [Splash] Onboarding not completed locally — checking Firestore...")
            OnboardingManager.checkFirestoreCompletion { [weak self] wasCompleted in
                guard let self = self else { return }
                if wasCompleted {
                    print("✅ [Splash] Onboarding restored from Firestore — proceeding with normal load")
                    self.proceedWithHealthKitAndGemini()
                } else {
                    print("➡️ [Splash] Onboarding needed — skipping HealthKit/Gemini, going to Onboarding")
                    // Show brief splash (logo visible) then go to Onboarding
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.finishAndTransition()
                    }
                }
            }
            return
        }

        // Onboarding already completed — normal flow
        proceedWithHealthKitAndGemini()
    }

    /// Normal loading flow: request HealthKit, fetch data, run Gemini
    private func proceedWithHealthKitAndGemini() {
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
        // Step 1: Fetch health data (0% → 15%)
        updateProgress(0.05, status: "splash.syncAppleHealth".localized)

        HealthKitManager.shared.fetchAllHealthData(for: .week) { [weak self] data, _ in
            guard let self = self else { return }

            // Save to cache
            HealthDataCache.shared.healthData = data

            // Step 2: Fetch chart data (15% → 30%)
            self.updateProgress(0.15, status: "splash.processingData".localized)

            // Calculate HealthScore and sync to Firestore in background (non-blocking)
            self.calculateAndSyncHealthScore()

            HealthKitManager.shared.fetchChartData(for: .week) { [weak self] bundle in
                guard let self = self else { return }

                // Save to cache
                HealthDataCache.shared.chartBundle = bundle

                // Step 3: Run Gemini analysis with smooth progress (30% → 90%)
                self.updateProgress(0.3, status: "splash.analyzingAI".localized)
                self.startSmoothProgress(from: 0.3, to: 0.9, duration: 25)

                // Check if this is a language-change restart (force re-analysis)
                let languageChanged = UserDefaults.standard.bool(forKey: "AION.LanguageChangeNeedsReanalysis")
                if languageChanged {
                    UserDefaults.standard.removeObject(forKey: "AION.LanguageChangeNeedsReanalysis")
                    print("🌐 [Splash] Language changed — forcing Gemini re-analysis")
                }

                // Run Gemini analysis — wait for completion (no timeout, let it finish)
                AIONAnalysisOrchestrator.shared.ensureTodayResult(forceRefresh: languageChanged) { [weak self] result, _ in
                    guard let self = self, !self.hasTransitioned else { return }

                    // Stop smooth progress
                    self.stopSmoothProgress()

                    if let result = result {
                        print("✅ [Splash] Gemini analysis complete — healthScore: \(result.scores.healthScore ?? -1)")
                    } else {
                        print("⚠️ [Splash] Gemini returned nil — will show empty state on Home")
                    }

                    // Step 4: Ready! (→ 100%)
                    self.updateProgress(0.95, status: "splash.ready".localized)

                    // Brief pause to show "Ready!" before transitioning
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        self.finishAndTransition()
                    }
                }
            }
        }
    }

    // MARK: - Smooth Progress Animation

    /// Smoothly animates progress from `from` to `to` over `duration` seconds.
    /// Uses an ease-out curve so it starts fast and slows as it approaches the target.
    private func startSmoothProgress(from: Float, to: Float, duration: TimeInterval) {
        stopSmoothProgress()
        currentProgress = from
        let startTime = Date()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] timer in
            guard let self = self, !self.hasTransitioned else {
                timer.invalidate()
                return
            }
            let elapsed = Date().timeIntervalSince(startTime)
            let fraction = min(elapsed / duration, 1.0)
            // Ease-out: fast start, slow end (never reaches 'to' until Gemini completes)
            let eased = 1.0 - pow(1.0 - fraction, 2.5)
            let newProgress = from + Float(eased) * (to - from)
            self.currentProgress = newProgress
            self.updateProgress(newProgress, status: "splash.analyzingAI".localized)
        }
    }

    private func stopSmoothProgress() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func finishAndTransition() {
        guard !hasTransitioned else { return }
        hasTransitioned = true
        updateProgress(1.0, status: "splash.ready".localized)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.transitionToMain()
        }
    }

    /// Calculate HealthScore and sync to Firestore
    private func calculateAndSyncHealthScore() {
        HealthKitManager.shared.fetchDailyHealthData(days: 90) { dailyEntries in
            // Scores now come from Gemini — read from GeminiResultStore
            let score = GeminiResultStore.loadHealthScore() ?? 0
            let tier = HealthTier.forScore(score)
            let cachedCarName = GeminiResultStore.loadCarName() ?? AnalysisCache.loadSelectedCar()?.name
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

            // Use Gemini score directly — no local DailyMetrics calculation needed
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }

                // Use health score from Gemini (single source of truth)
                let freshMainScore = GeminiResultStore.loadHealthScore() ?? 0
                print("📱 [Splash] ✅ Using Gemini healthScore=\(freshMainScore)")

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

                            // Check: if Gemini data exists - use it for widget
                            let geminiCarName = GeminiResultStore.loadCarName()
                            let geminiWikiName = GeminiResultStore.loadCarWikiName()
                            let geminiScore = GeminiResultStore.loadCarScore()
                            let userName = Auth.auth().currentUser?.displayName ?? ""

                            if let geminiCarName = geminiCarName, let geminiScoreValue = geminiScore {
                                // Has Gemini data - update widget with car name and score from Gemini
                                let geminiTier = HealthTier.forScore(geminiScoreValue)

                                // Prefetch car image for faster loading in Insights tab
                                if let wikiName = geminiWikiName, !wikiName.isEmpty {
                                    WidgetDataManager.shared.prefetchCarImage(wikiName: wikiName)
                                }
                                WidgetDataManager.shared.updateFromInsights(
                                    score: displayScore,              // Daily health score as PRIMARY display
                                    dailyScore: nil,                  // No secondary score in widgets
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
                                print("📱 [Splash] Widget updated with Gemini data: car=\(geminiCarName), dailyScore=\(displayScore), gemini90d=\(geminiScoreValue), user=\(userName)")
                                // Watch sync is now handled by SceneDelegate's analysisDidComplete observer
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
                                    carTier: HealthTier.forScore(displayScore),
                                    userName: userName
                                )
                                print("📱 [Splash] Widget updated - no Gemini data yet, score=\(displayScore), user=\(userName)")
                            }
                            print("📱 [Splash] Widget data synced: score=\(displayScore), steps=\(Int(todayEntry?.steps ?? 0)), exercise=\(exercise), stand=\(stand)")
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
}
