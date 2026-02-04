import UIKit
import HealthKit
import FirebaseAuth

/// Splash Screen דינמי שטוען נתונים ברקע
/// מוצג במקום LaunchScreen.storyboard הסטטי ומבצע את טעינת הנתונים
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
        label.textColor = .white  // תמיד לבן ב-Splash (רקע כהה קבוע)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let accentBar: UIView = {
        let view = UIView()
        view.backgroundColor = AIONDesign.accentSecondary  // טורקיז
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
        // רקע כהה כמו ב-LaunchScreen
        view.backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.118, alpha: 1.0)

        // הוספת אלמנטים
        view.addSubview(logoImageView)
        view.addSubview(titleLabel)
        view.addSubview(accentBar)
        view.addSubview(subtitleLabel)
        view.addSubview(loadingIndicator)
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            // Logo - מרכז עם offset למעלה
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -80),
            logoImageView.widthAnchor.constraint(equalToConstant: 200),
            logoImageView.heightAnchor.constraint(equalToConstant: 200),

            // Title - מתחת ללוגו
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 16),

            // Accent bar - מתחת לכותרת
            accentBar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            accentBar.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            accentBar.widthAnchor.constraint(equalToConstant: 50),
            accentBar.heightAnchor.constraint(equalToConstant: 4),

            // Subtitle - מתחת לפס
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: accentBar.bottomAnchor, constant: 16),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),

            // Loading indicator - מתחת לכל
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),

            // Status label - מתחת ל-indicator
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: loadingIndicator.bottomAnchor, constant: 12),
        ])
    }

    // MARK: - Loading

    private func startLoading() {
        // הצג loading
        loadingIndicator.startAnimating()
        UIView.animate(withDuration: 0.3) {
            self.statusLabel.alpha = 1
        }

        // בדוק אם HealthKit זמין
        guard HealthKitManager.shared.isHealthDataAvailable() else {
            transitionToMain()
            return
        }

        // בקש הרשאות HealthKit
        HealthKitManager.shared.requestAuthorization { [weak self] success, _ in
            guard let self = self else { return }

            if !success {
                // אם אין הרשאה - עבור למסך הראשי בכל זאת
                DispatchQueue.main.async {
                    self.transitionToMain()
                }
                return
            }

            // טען נתונים
            self.loadHealthData()
        }
    }

    private func loadHealthData() {
        DispatchQueue.main.async {
            self.statusLabel.text = "splash.syncAppleHealth".localized
        }

        // טעינת נתוני בריאות
        HealthKitManager.shared.fetchAllHealthData(for: .week) { [weak self] data, _ in
            guard let self = self else { return }

            // שמור ב-cache
            HealthDataCache.shared.healthData = data

            DispatchQueue.main.async {
                self.statusLabel.text = "splash.processingData".localized
            }

            // חישוב HealthScore וסנכרון ל-Firestore ברקע
            self.calculateAndSyncHealthScore()

            // טעינת נתוני גרפים
            HealthKitManager.shared.fetchChartData(for: .week) { [weak self] bundle in
                guard let self = self else { return }

                // שמור ב-cache
                HealthDataCache.shared.chartBundle = bundle

                // הפעלת ניתוח ג'מיני ברקע (לא חוסם UI)
                self.triggerBackgroundGeminiAnalysis(healthData: data, chartBundle: bundle)

                DispatchQueue.main.async {
                    self.transitionToMain()
                }
            }
        }
    }

    /// חישוב HealthScore מנתוני 90 יום וסנכרון ל-Firestore
    private func calculateAndSyncHealthScore() {
        HealthKitManager.shared.fetchDailyHealthData(days: 90) { dailyEntries in
            let healthResult = HealthScoreEngine.shared.calculate(from: dailyEntries)
            AnalysisCache.saveHealthScoreResult(healthResult)

            // סנכרון ל-Firestore (לידרבורד וחיפוש חברים)
            let score = healthResult.healthScoreInt
            let tier = CarTierEngine.tierForScore(score)
            // שימוש בשם הרכב מ-Gemini אם קיים במטמון
            let cachedCarName = AnalysisCache.loadSelectedCar()?.name
            print("🚗 [Splash] Syncing score with cachedCarName: \(cachedCarName ?? "nil")")
            LeaderboardFirestoreSync.syncScore(score: score, tier: tier, geminiCarName: cachedCarName)

            // שליחה לשעון - נתוני היום האחרון
            // עדיפות: mainScore (הציון היומי) > healthScoreInt (ציון 90 יום)
            let todayEntry = dailyEntries.last
            let displayScore = AnalysisCache.loadMainScore() ?? score
            // עדיפות ל-status השמור (מ-InsightsDashboard), אחרת חשב מהציון
            let healthStatus: String
            if let savedStatus = AnalysisCache.loadMainScoreStatus() {
                healthStatus = savedStatus
            } else {
                let scoreLevel = RangeLevel.from(score: Double(displayScore))
                healthStatus = "score.description.\(scoreLevel.rawValue)".localized
            }

            // Fetch fresh exercise and stand data from HealthKit for today
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            let endOfDay = Date()

            HealthKitManager.shared.fetchExerciseMinutes(startDate: startOfDay, endDate: endOfDay) { exerciseMinutes in
                HealthKitManager.shared.fetchStandHours(startDate: startOfDay, endDate: endOfDay) { standHours in
                    DispatchQueue.main.async {
                        let exercise = Int(exerciseMinutes ?? 0)
                        let stand = Int(standHours ?? 0)

                        // בדיקה: אם יש נתוני Gemini ב-cache - להשתמש בהם לווידג'ט
                        let geminiCar = AnalysisCache.loadSelectedCar()
                        let geminiScore = AnalysisCache.loadHealthScore()
                        let userName = Auth.auth().currentUser?.displayName ?? ""

                        if let geminiCarName = geminiCar?.name, let geminiScoreValue = geminiScore {
                            // יש נתוני Gemini - עדכון ווידג'ט עם שם הרכב והציון מ-Gemini
                            let geminiTier = CarTierEngine.tierForScore(geminiScoreValue)
                            WidgetDataManager.shared.updateFromInsights(
                                score: geminiScoreValue,
                                dailyScore: displayScore,  // הציון היומי לתצוגה משנית
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

                            // שליחה לשעון - עם הציון היומי (לא Gemini!) כדי לשמור על עקביות
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
                                carName: tier.name,
                                carEmoji: tier.emoji,
                                carTierIndex: tier.tierIndex,
                                carTierLabel: tier.tierLabel,
                                geminiCarName: geminiCarName,
                                geminiCarScore: geminiScoreValue
                            )
                        } else {
                            // אין נתוני Gemini - להשתמש בציון רגיל (מחושב מ-HealthScore)
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
                                carTier: tier,
                                userName: userName
                            )
                            print("📱 [Splash] Widget updated with calculated tier: car=\(tier.name), score=\(displayScore), user=\(userName)")
                        }
                        print("📱 [Splash] Sent to Watch: score=\(displayScore), steps=\(Int(todayEntry?.steps ?? 0)), exercise=\(exercise), stand=\(stand)")
                    }
                }
            }
        }
    }

    // MARK: - Transition

    private func transitionToMain() {
        loadingIndicator.stopAnimating()

        guard let window = view.window else {
            // Fallback אם אין window
            let main = MainTabBarController()
            if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
                sceneDelegate.window?.rootViewController = main
                sceneDelegate.window?.makeKeyAndVisible()
            }
            return
        }

        let main = MainTabBarController()

        // אנימציית מעבר חלקה
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: {
            window.rootViewController = main
        }, completion: nil)
    }

    // MARK: - Background Gemini Analysis

    /// מפעיל ניתוח ג'מיני ברקע מיד עם עליית האפליקציה
    /// הניתוח רץ במקביל למעבר ל-Dashboard ולא חוסם את ה-UI
    private func triggerBackgroundGeminiAnalysis(healthData: HealthDataModel?, chartBundle: AIONChartDataBundle?) {
        guard let data = healthData, data.hasRealData else {
            return
        }

        // יצירת hash לבדיקת cache
        let healthDataHash: String
        if let bundle = chartBundle {
            healthDataHash = AnalysisCache.generateHealthDataHash(from: bundle)
        } else {
            healthDataHash = AnalysisCache.generateHealthDataHash(from: data)
        }

        // בדיקה אם צריך לקרוא ל-Gemini (האם הנתונים השתנו?)
        // משתמשים ב-hasSignificantChange כמו ב-Dashboard לעקביות
        let shouldRun: Bool
        if let bundle = chartBundle {
            shouldRun = AnalysisCache.hasSignificantChange(currentBundle: bundle)
        } else {
            shouldRun = AnalysisCache.shouldRunAnalysis(forceAnalysis: false, currentHealthDataHash: healthDataHash)
        }

        guard shouldRun else {
            // שליחת notification לעדכון UI מה-cache
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: HealthDashboardViewController.analysisDidCompleteNotification,
                    object: nil
                )
            }
            return
        }

        // הרצה ב-background thread
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

                    // שליחת נוטיפיקציה לעדכון ה-UI
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
