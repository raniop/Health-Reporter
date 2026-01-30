//
//  InsightsTabViewController.swift
//  Health Reporter
//
//  מסך תובנות – עיצוב Premium עם Hero Card כמו בדשבורד
//

import UIKit

// MARK: - Padded Label for badges

private final class PaddedLabel: UILabel {
    var padding = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: padding))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + padding.left + padding.right,
                      height: size.height + padding.top + padding.bottom)
    }
}

// MARK: - Gradient Background View for Cards

private final class GradientCardBackground: UIView {
    private let gradientLayer = CAGradientLayer()

    init(color: UIColor) {
        super.init(frame: .zero)
        setupGradient(color: color)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupGradient(color: UIColor) {
        gradientLayer.colors = [
            color.withAlphaComponent(0.5).cgColor,
            color.withAlphaComponent(0.25).cgColor,
            color.withAlphaComponent(0.1).cgColor,
            AIONDesign.surface.cgColor
        ]
        gradientLayer.locations = [0.0, 0.3, 0.6, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gradientLayer, at: 0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}

// MARK: - Premium Insights Tab VC

final class InsightsTabViewController: UIViewController {

    // MARK: - UI Components

    private let scrollView: UIScrollView = {
        let v = UIScrollView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.showsVerticalScrollIndicator = false
        v.alwaysBounceVertical = true
        v.semanticContentAttribute = .forceRightToLeft
        return v
    }()

    private let stack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 16
        s.alignment = .fill
        s.semanticContentAttribute = .forceRightToLeft
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let loadingView: UIView = {
        let v = UIView()
        v.backgroundColor = AIONDesign.background
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()

    private let loadingSpinner: UIActivityIndicatorView = {
        let s = UIActivityIndicatorView(style: .large)
        s.color = AIONDesign.accentPrimary
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let loadingLabel: UILabel = {
        let l = UILabel()
        l.text = "מנתח נתונים..."
        l.font = .systemFont(ofSize: 16, weight: .medium)
        l.textColor = AIONDesign.textSecondary
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Colors (דינמי לפי רקע בהיר/כהה)

    private var bgColor: UIColor { AIONDesign.background }
    private var cardBgColor: UIColor { AIONDesign.surface }
    private var textWhite: UIColor { AIONDesign.textPrimary }
    private var textGray: UIColor { AIONDesign.textSecondary }
    private var textDarkGray: UIColor { AIONDesign.textTertiary }
    private let accentCyan = UIColor(red: 0.0, green: 0.85, blue: 0.95, alpha: 1.0)
    private let accentGreen = UIColor(red: 0.2, green: 0.9, blue: 0.5, alpha: 1.0)
    private let accentOrange = UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0)
    private let accentRed = UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
    private let accentPurple = UIColor(red: 0.6, green: 0.4, blue: 1.0, alpha: 1.0)
    private let accentBlue = UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0)

    // MARK: - Properties

    private var analysisObserver: NSObjectProtocol?
    private var confettiEmitter: ConfettiEmitter?
    private var particleBackground: ParticleBackground?
    private var isShowingDiscoveryFlow = false
    private var currentSupplements: [SupplementRecommendation] = []

    // Discovery UI elements (for animation access)
    private var discoveryContainer: UIView?
    private var discoveryMinHeightConstraint: NSLayoutConstraint?
    private var carCardView: UIView?

    // Animators - must be kept as properties to prevent deallocation
    private var typingAnimator: TypingAnimator?
    private var counterAnimator: NumberCounterAnimator?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "תובנות"
        view.backgroundColor = bgColor
        view.semanticContentAttribute = .forceRightToLeft

        setupUI()
        setupRefreshButton()
        setupAnalysisObserver()
        refreshContent()

        // Listen for background color changes
        NotificationCenter.default.addObserver(self, selector: #selector(backgroundColorDidChange), name: .backgroundColorChanged, object: nil)
    }

    @objc private func backgroundColorDidChange() {
        view.backgroundColor = AIONDesign.background
        navigationController?.navigationBar.barStyle = AIONDesign.navBarStyle
        navigationController?.navigationBar.barTintColor = AIONDesign.background
        navigationController?.navigationBar.backgroundColor = AIONDesign.background
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: textWhite]
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshContent()
    }

    deinit {
        if let o = analysisObserver { NotificationCenter.default.removeObserver(o) }
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(stack)

        view.addSubview(loadingView)
        loadingView.addSubview(loadingSpinner)
        loadingView.addSubview(loadingLabel)

        let edge: CGFloat = 16
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: edge),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: edge),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -edge),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -edge - 100),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -edge * 2),

            loadingView.topAnchor.constraint(equalTo: view.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            loadingSpinner.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: loadingView.centerYAnchor, constant: -20),
            loadingLabel.topAnchor.constraint(equalTo: loadingSpinner.bottomAnchor, constant: 16),
            loadingLabel.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
        ])
    }

    private func setupRefreshButton() {
        // כפתור ריפרש בצד שמאל
        let refreshBtn = UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"), style: .plain, target: self, action: #selector(refreshTapped))
        refreshBtn.tintColor = accentCyan
        navigationItem.leftBarButtonItem = refreshBtn

        // כפתור דיבאג בצד ימין
        let debugBtn = UIBarButtonItem(image: UIImage(systemName: "ant"), style: .plain, target: self, action: #selector(debugTapped))
        debugBtn.tintColor = .systemOrange
        navigationItem.rightBarButtonItem = debugBtn
    }

    @objc private func debugTapped() {
        let debugVC = GeminiDebugViewController()
        let nav = UINavigationController(rootViewController: debugVC)
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    private func setupAnalysisObserver() {
        analysisObserver = NotificationCenter.default.addObserver(
            forName: HealthDashboardViewController.analysisDidCompleteNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshContent()
        }
    }

    // MARK: - Actions

    @objc private func refreshTapped() {
        // בדיקה אם יש שינוי משמעותי בנתונים
        if let dashboard = (tabBarController?.viewControllers?.first as? UINavigationController)?.viewControllers.first as? HealthDashboardViewController,
           let bundle = dashboard.currentChartBundle {

            if !AnalysisCache.hasSignificantChange(currentBundle: bundle) {
                // אין שינוי משמעותי - הצג הודעה
                showNoSignificantChangeAlert()
                return
            }
        }

        // יש שינוי משמעותי או אין נתונים - קרא ל-Gemini
        showLoading()

        if let dashboard = (tabBarController?.viewControllers?.first as? UINavigationController)?.viewControllers.first as? HealthDashboardViewController {
            dashboard.runAnalysisForInsights(forceAnalysis: true)
        }
    }

    private func showNoSignificantChangeAlert() {
        let alert = UIAlertController(
            title: "אין שינוי משמעותי",
            message: "הנתונים שלך לא השתנו מספיק כדי להצדיק ניתוח חדש. הניתוח יתעדכן אוטומטית כשיהיה שינוי משמעותי ב-HRV, שינה או פעילות.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "הבנתי", style: .default))
        alert.addAction(UIAlertAction(title: "רענן בכל זאת", style: .destructive) { [weak self] _ in
            self?.forceRefresh()
        })
        present(alert, animated: true)
    }

    private func forceRefresh() {
        showLoading()
        if let dashboard = (tabBarController?.viewControllers?.first as? UINavigationController)?.viewControllers.first as? HealthDashboardViewController {
            dashboard.runAnalysisForInsights(forceAnalysis: true)
        }
    }

    // MARK: - Loading

    private func showLoading() {
        loadingView.isHidden = false
        loadingSpinner.startAnimating()
    }

    private func hideLoading() {
        loadingView.isHidden = true
        loadingSpinner.stopAnimating()
    }

    // MARK: - Content

    private func refreshContent() {
        hideLoading()

        // אם אנחנו באמצע flow של גילוי - לא למחוק
        if isShowingDiscoveryFlow {
            // בדיקה אם הניתוח הסתיים
            if let insights = AnalysisCache.loadLatest(), !insights.isEmpty {
                // יש תוצאות! אם עדיין בטעינה - נעבור לחשיפה
                // (זה מטופל ב-checkForResultsAndReveal)
            }
            return
        }

        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        discoveryContainer = nil
        carCardView = nil

        // ✅ בדיקה: אם המשתמש לא גילה עדיין - הצג Discovery Flow (גם אם יש cache)
        let hasDiscovered = UserDefaults.standard.bool(forKey: "AION.HasDiscoveredCar")
        if !hasDiscovered {
            addFirstTimeDiscoveryExperience()
            return
        }

        // ✅ בדיקה: אם יש רכב חדש ממתין לחשיפה - הצג Car Upgrade Reveal
        if AnalysisCache.hasPendingCarReveal() {
            addCarUpgradeRevealExperience()
            return
        }

        guard let insights = AnalysisCache.loadLatest(), !insights.isEmpty else {
            addEmptyState()
            return
        }

        // === DEBUG LOGS ===
        print("\n" + String(repeating: "=", count: 60))
        print("=== INSIGHTS TAB: GEMINI RESPONSE FROM CACHE ===")
        print(String(repeating: "=", count: 60))
        print("Raw insights length: \(insights.count) characters")
        print("\n--- RAW GEMINI RESPONSE ---")
        print(insights)
        print("--- END RAW RESPONSE ---\n")

        let parsed = CarAnalysisParser.parse(insights)

        // === DEBUG: Parsed values ===
        print("=== PARSED VALUES ===")
        print("Car Model: '\(parsed.carModel)'")
        print("Car Wiki Name: '\(parsed.carWikiName)'")
        print("Car Explanation: '\(parsed.carExplanation.prefix(200))...'")
        print("Engine: '\(parsed.engine.prefix(100))...'")
        print("Transmission: '\(parsed.transmission.prefix(100))...'")
        print("Suspension: '\(parsed.suspension.prefix(100))...'")
        print("Fuel Efficiency: '\(parsed.fuelEfficiency.prefix(100))...'")
        print("Electronics: '\(parsed.electronics.prefix(100))...'")
        print("Bottlenecks count: \(parsed.bottlenecks.count)")
        print("Warning Signals count: \(parsed.warningSignals.count)")
        print("Upgrades count: \(parsed.upgrades.count)")
        print("Directive STOP: '\(parsed.directiveStop)'")
        print("Directive START: '\(parsed.directiveStart)'")
        print("Directive WATCH: '\(parsed.directiveWatch)'")
        print("Summary: '\(parsed.summary.prefix(150))...'")
        print(String(repeating: "=", count: 60) + "\n")

        // Build Premium UI
        addHeader()
        addHeroCarCard(parsed: parsed)
        addWeeklyDataGrid(parsed: parsed)
        addPerformanceSection(parsed: parsed)
        addBottlenecksCard(parsed: parsed)
        addOptimizationCard(parsed: parsed)
        addTuneUpCard(parsed: parsed)
        addNutritionButton(parsed: parsed)
        addDirectivesCard(parsed: parsed)
        addSummaryCard(parsed: parsed)
    }

    // MARK: - Header

    private func addHeader() {
        let headerStack = UIStackView()
        headerStack.axis = .vertical
        headerStack.spacing = 4
        headerStack.alignment = .center

        let sparkle = UILabel()
        sparkle.text = "✨"
        sparkle.font = .systemFont(ofSize: 28)

        let title = UILabel()
        title.text = "תובנות AION"
        title.font = .systemFont(ofSize: 22, weight: .bold)
        title.textColor = textWhite

        let subtitle = UILabel()
        subtitle.text = "ניתוח ביומטרי מבוסס נתונים"
        subtitle.font = .systemFont(ofSize: 13, weight: .regular)
        subtitle.textColor = textGray

        let dateLabel = UILabel()
        if let d = AnalysisCache.lastUpdateDate() {
            let f = DateFormatter()
            f.locale = Locale(identifier: "he_IL")
            f.dateFormat = "d בMMMM yyyy"
            dateLabel.text = "עדכון אחרון: \(f.string(from: d))"
        }
        dateLabel.font = .systemFont(ofSize: 12, weight: .regular)
        dateLabel.textColor = textDarkGray

        headerStack.addArrangedSubview(sparkle)
        headerStack.addArrangedSubview(title)
        headerStack.addArrangedSubview(subtitle)
        headerStack.addArrangedSubview(dateLabel)

        stack.addArrangedSubview(headerStack)
    }

    // MARK: - Hero Car Card (Like Dashboard)

// MARK: - Hero Car Card (Like Dashboard)

private func addHeroCarCard(parsed: CarAnalysisResponse) {
    // Get score (for display only, not for car selection)
    let stats = AnalysisCache.loadWeeklyStats()
    let score: Int
    if let savedScore = AnalysisCache.loadHealthScore() {
        score = savedScore
        print("=== INSIGHTS: Using saved score from Dashboard: \(score) ===")
    } else {
        score = CarTierEngine.computeHealthScore(
            readinessAvg: stats?.readiness,
            sleepHoursAvg: stats?.sleepHours,
            hrvAvg: stats?.hrv,
            strainAvg: stats?.strain
        )
        print("=== INSIGHTS: No saved score, calculated: \(score) ===")
    }

    // Determine car name - priority: Gemini > Saved > Placeholder
    let cleanedGeminiCar = cleanCarName(parsed.carModel)
    let invalidWords = [
        "strain", "training", "score", "wiki", "generation", "first", "second", "third",
        "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth",
        "model year", "version", "series"
    ]
    let lowerCar = cleanedGeminiCar.lowercased()
    let containsInvalidWord = invalidWords.contains { lowerCar.contains($0) }
    let isValidGeminiCar = !cleanedGeminiCar.isEmpty && !containsInvalidWord && cleanedGeminiCar.count > 3 && cleanedGeminiCar.count < 40

    let carName: String
    let wikiName: String
    let explanation: String

    if isValidGeminiCar {
        // Gemini returned a valid car - check if changed and save
        carName = cleanedGeminiCar
        wikiName = parsed.carWikiName
        explanation = parsed.carExplanation
        AnalysisCache.checkAndSetCarChange(newCarName: carName, newWikiName: wikiName, newExplanation: explanation)
        print("=== INSIGHTS: Using Gemini car: \(carName) ===")
    } else if let savedCar = AnalysisCache.loadSelectedCar() {
        // Gemini didn't return valid car - use saved car
        carName = savedCar.name
        wikiName = savedCar.wikiName
        explanation = savedCar.explanation
        print("=== INSIGHTS: Using saved car: \(carName) ===")
    } else {
        // No car at all - show placeholder
        carName = "ממתין לניתוח..."
        wikiName = ""
        explanation = "הרכב שלך ייבחר לאחר ניתוח ראשון של הנתונים"
        print("=== INSIGHTS: No car available, showing placeholder ===")
    }

    // Determine status based on score
    let status: String
    switch score {
    case 80...100: status = "שיא ביצועים"
    case 65..<80: status = "מצוין"
    case 45..<65: status = "מצב טוב"
    case 25..<45: status = "בסדר"
    default: status = "צריך טיפול"
    }

    // Determine color based on score
    let tierColor: UIColor
    switch score {
    case 80...100: tierColor = AIONDesign.accentSuccess
    case 65..<80: tierColor = AIONDesign.accentSecondary
    case 45..<65: tierColor = AIONDesign.accentPrimary
    case 25..<45: tierColor = AIONDesign.accentWarning
    default: tierColor = AIONDesign.accentDanger
    }

    // Update widget with car name and real activity data
    let hrvValue = stats?.hrv ?? 0
    let sleepValue = stats?.sleepHours ?? 0
    let dailyActivity = AnalysisCache.loadDailyActivity()
    WidgetDataManager.shared.updateFromInsights(
        score: score,
        status: status,
        carName: carName,
        carEmoji: "🚗",
        steps: dailyActivity?.steps ?? 0,
        activeCalories: dailyActivity?.calories ?? 0,
        exerciseMinutes: dailyActivity?.exerciseMinutes ?? 0,
        standHours: dailyActivity?.standHours ?? 0,
        restingHR: dailyActivity?.restingHR ?? 0 > 0 ? dailyActivity?.restingHR : nil,
        hrv: hrvValue > 0 ? Int(hrvValue) : nil,
        sleepHours: sleepValue > 0 ? sleepValue : nil
    )

    // ✅ Card is the arrangedSubview (NO wrapper container)
    let card = UIView()
    card.backgroundColor = cardBgColor
    card.layer.cornerRadius = 20
    card.clipsToBounds = true
    card.translatesAutoresizingMaskIntoConstraints = false
    card.setContentHuggingPriority(.required, for: .vertical)
    card.setContentCompressionResistancePriority(.required, for: .vertical)

    self.discoveryContainer = card
    self.carCardView = card

    // Background image - לא קובעת גובה, רק ממלאת את הכרטיס
    class NoIntrinsicImageView: UIImageView {
        override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric) }
    }
    let bgImageView = NoIntrinsicImageView()
    bgImageView.contentMode = .scaleAspectFill
    bgImageView.clipsToBounds = true
    bgImageView.backgroundColor = UIColor(white: 0.15, alpha: 1)
    bgImageView.translatesAutoresizingMaskIntoConstraints = false

    // Gradient overlay - קל יותר כדי לראות את התמונה
    let gradientLayer = CAGradientLayer()
    gradientLayer.colors = [
        UIColor.black.withAlphaComponent(0.4).cgColor,
        UIColor.black.withAlphaComponent(0.1).cgColor,
        UIColor.black.withAlphaComponent(0.5).cgColor
    ]
    gradientLayer.locations = [0.0, 0.4, 1.0]

    let gradientView = UIView()
    gradientView.translatesAutoresizingMaskIntoConstraints = false
    gradientView.layer.insertSublayer(gradientLayer, at: 0)

    card.addSubview(bgImageView)
    card.addSubview(gradientView)

    // Load car image
    if !wikiName.isEmpty {
        fetchCarImageFromWikipedia(carName: wikiName, into: bgImageView, fallbackEmoji: "")
    }

    // Car name
    let carNameLabel = UILabel()
    carNameLabel.text = carName
    carNameLabel.font = .systemFont(ofSize: 28, weight: .heavy)
    carNameLabel.textColor = .white
    carNameLabel.textAlignment = .center
    carNameLabel.numberOfLines = 1
    carNameLabel.adjustsFontSizeToFitWidth = true
    carNameLabel.minimumScaleFactor = 0.7
    carNameLabel.layer.shadowColor = UIColor.black.cgColor
    carNameLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
    carNameLabel.layer.shadowOpacity = 1
    carNameLabel.layer.shadowRadius = 4
    carNameLabel.translatesAutoresizingMaskIntoConstraints = false

    // Status badge
    let statusBadge = PaddedLabel()
    statusBadge.text = status
    statusBadge.font = .systemFont(ofSize: 14, weight: .bold)
    statusBadge.textColor = .white
    statusBadge.backgroundColor = tierColor
    statusBadge.layer.cornerRadius = 16
    statusBadge.clipsToBounds = true
    statusBadge.translatesAutoresizingMaskIntoConstraints = false

    // Score
    let scoreLabel = UILabel()
    scoreLabel.text = "\(score)/100"
    scoreLabel.font = .systemFont(ofSize: 24, weight: .bold)
    scoreLabel.textColor = tierColor
    scoreLabel.layer.shadowColor = UIColor.black.cgColor
    scoreLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
    scoreLabel.layer.shadowOpacity = 0.8
    scoreLabel.layer.shadowRadius = 3
    scoreLabel.translatesAutoresizingMaskIntoConstraints = false

    // Progress bar
    let progressBar = AnimatedProgressBar()
    progressBar.progressColor = tierColor
    progressBar.translatesAutoresizingMaskIntoConstraints = false

    // Explanation
    let rawExplanation = explanation.isEmpty ? "הרכב נבחר על סמך ניתוח נתוני הבריאות שלך." : explanation
    let explanationText = cleanExplanationText(rawExplanation, carName: carName)

    let explanationLabel = UILabel()
    explanationLabel.text = explanationText
    explanationLabel.font = .systemFont(ofSize: 14, weight: .semibold)
    explanationLabel.textColor = .white
    explanationLabel.textAlignment = .right
    explanationLabel.numberOfLines = 0
    explanationLabel.layer.shadowColor = UIColor.black.cgColor
    explanationLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
    explanationLabel.layer.shadowOpacity = 0.8
    explanationLabel.layer.shadowRadius = 2
    explanationLabel.translatesAutoresizingMaskIntoConstraints = false
    explanationLabel.setContentHuggingPriority(.required, for: .vertical)
    explanationLabel.setContentCompressionResistancePriority(.required, for: .vertical)

    // Action buttons
    let buttonsStack = UIStackView()
    buttonsStack.axis = .horizontal
    buttonsStack.spacing = 12
    buttonsStack.distribution = .fillEqually
    buttonsStack.translatesAutoresizingMaskIntoConstraints = false

    let refreshButton = createActionButton(title: "🔄 בדוק שוב", action: #selector(rediscoverTapped))
    buttonsStack.addArrangedSubview(refreshButton)

    // Header row: score + badge
    let headerRow = UIStackView()
    headerRow.axis = .horizontal
    headerRow.alignment = .center
    headerRow.distribution = .fill
    headerRow.spacing = 8
    headerRow.translatesAutoresizingMaskIntoConstraints = false

    let spacer = UIView()
    spacer.translatesAutoresizingMaskIntoConstraints = false
    spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
    spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    headerRow.addArrangedSubview(spacer)
    headerRow.addArrangedSubview(scoreLabel)
    headerRow.addArrangedSubview(statusBadge)

    // Main content stack (packed)
    let contentStack = UIStackView()
    contentStack.axis = .vertical
//    contentStack.alignment = .fill
    contentStack.distribution = .fill
    contentStack.spacing = 8
    contentStack.translatesAutoresizingMaskIntoConstraints = false

    contentStack.addArrangedSubview(carNameLabel)
    contentStack.addArrangedSubview(headerRow)
    contentStack.addArrangedSubview(progressBar)
    contentStack.addArrangedSubview(explanationLabel)
    contentStack.addArrangedSubview(buttonsStack)

    card.addSubview(contentStack)

    // התוכן קובע את גובה הכרטיס, התמונה רק ממלאה אותו
    NSLayoutConstraint.activate([
        // התוכן קובע את הגובה
        contentStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
        contentStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
        contentStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
        contentStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),

        // תמונה - ממלאה את הכרטיס (לא קובעת גובה)
        bgImageView.topAnchor.constraint(equalTo: card.topAnchor),
        bgImageView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
        bgImageView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
        bgImageView.bottomAnchor.constraint(equalTo: card.bottomAnchor),

        // gradient על כל הכרטיס
        gradientView.topAnchor.constraint(equalTo: card.topAnchor),
        gradientView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
        gradientView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
        gradientView.bottomAnchor.constraint(equalTo: card.bottomAnchor),

        progressBar.heightAnchor.constraint(equalToConstant: 6),
        buttonsStack.heightAnchor.constraint(equalToConstant: 44),
    ])

    // Update gradient + progress
    DispatchQueue.main.async {
        gradientLayer.frame = gradientView.bounds
        progressBar.setProgress(CGFloat(score) / 100.0)
    }

    stack.addArrangedSubview(card)
}


    // MARK: - Car Name Cleaning

    private func cleanCarName(_ raw: String) -> String {
        var name = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // אם Gemini החזיר משפט ("אתה כרגע כמו ...")
        if let range = name.range(of: "כמו") {
            name = String(name[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }

        // הסרת תגיות ושרידים
        name = name
            .replacingOccurrences(of: "[CAR_WIKI:", with: "")
            .replacingOccurrences(of: "[CAR_WIKI]", with: "")
            .replacingOccurrences(of: "CAR_WIKI:", with: "")
            .replacingOccurrences(of: "CAR_WIKI", with: "")
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // הסרת סוגריים ומה שבתוכן
        if let parenIndex = name.firstIndex(of: "(") {
            name = String(name[..<parenIndex]).trimmingCharacters(in: .whitespaces)
        }

        // הסרת נקודה / נקודתיים בסוף
        while name.hasSuffix(".") || name.hasSuffix(":") {
            name = String(name.dropLast()).trimmingCharacters(in: .whitespaces)
        }

        return name
    }

    // MARK: - Explanation Cleaning

    private func cleanExplanationText(_ raw: String, carName: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1) הסרת כל מה שבסוגריים (Mk7 וכו') - תומך בכמה זוגות
        while let open = s.firstIndex(of: "("),
              let close = s[open...].firstIndex(of: ")") {
            s.removeSubrange(open...close)
        }

        // 2) ניקוי רווחים/פיסוק אחרי הסרת סוגריים
        while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }
        s = s.replacingOccurrences(of: " .", with: ".")
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)

        // Helper: case-insensitive replace
        func replaceCI(_ text: String, _ pattern: String, with replacement: String) -> String {
            return text.replacingOccurrences(of: pattern, with: replacement, options: [.caseInsensitive], range: nil)
        }

        // 3) אם ההסבר מתחיל בשם הרכב - להסיר אותו (כי כבר יש כותרת)
        // (case-insensitive)
        let prefixTrimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if prefixTrimmed.lowercased().hasPrefix(carName.lowercased()) {
            s = String(prefixTrimmed.dropFirst(carName.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            if let first = s.first, [".", ":", "–", "-"].contains(first) {
                s = String(s.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // 4) הסרת כפילויות רצופות של שם הרכב בתוך הטקסט (כולל "X. X", "X X", ובשבירת שורה)
        for _ in 0..<5 {
            s = replaceCI(s, "\(carName). \(carName)", with: "\(carName).")
            s = replaceCI(s, "\(carName) \(carName)", with: "\(carName)")
            s = replaceCI(s, "\(carName).\n\(carName)", with: "\(carName).")
            s = replaceCI(s, "\(carName)\n\(carName)", with: "\(carName)")
        }

        // 5) סינון שורות לא רצויות (שורה שהיא רק שם רכב / דגם משנה כמו "Golf Mk7")
        let lines = s
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let carLower = carName.lowercased()

        let filtered = lines.filter { line in
            let l = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let low = l.lowercased()

            // שורה שהיא רק שם הרכב (עם/בלי פיסוק)
            let normalized = low
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ":", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if normalized == carLower { return false }
            if normalized.hasPrefix(carLower) && normalized.count <= carLower.count + 2 { return false }

            // הסרת שורות "דגם משנה" כמו Golf Mk7 / Golf MK8 / GTI Mk7 וכו'
            // (אם יש mk + מספר/אות)
            if low.contains("mk") {
                // שורה קצרה שמכילה mk נחשבת "טאג דגם" -> נזרוק
                if l.count <= 18 { return false }
            }

            return true
        }

        // 6) הסרת שורות כפולות (case-insensitive)
        var seen = Set<String>()
        let unique = filtered.filter { line in
            let key = line.lowercased()
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }

        // 7) ניקוי אחרון: אם נשארה כפילות "X. X" בתוך שורה (case-insensitive)
        var out = unique.joined(separator: "\n")
        for _ in 0..<3 {
            out = replaceCI(out, "\(carName). \(carName)", with: "\(carName).")
            out = replaceCI(out, "\(carName) \(carName)", with: "\(carName)")
        }

        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }



    // MARK: - Health Score Calculation

    private func calculateHealthScore(stats: (sleepHours: Double, readiness: Double, strain: Double, hrv: Double)?) -> Int {
        guard let stats = stats else { return 50 }

        var score: Double = 0
        var factors: Double = 0

        // Sleep score (7-9 hours is optimal)
        if stats.sleepHours > 0 {
            let sleepScore: Double
            if stats.sleepHours >= 7 && stats.sleepHours <= 9 {
                sleepScore = 100
            } else if stats.sleepHours >= 6 && stats.sleepHours <= 10 {
                sleepScore = 75
            } else if stats.sleepHours >= 5 {
                sleepScore = 50
            } else {
                sleepScore = 25
            }
            score += sleepScore * 0.3
            factors += 0.3
        }

        // Readiness score (already 0-100)
        if stats.readiness > 0 {
            score += stats.readiness * 0.35
            factors += 0.35
        }

        // Strain score (lower is better for recovery, 2-5 is balanced)
        if stats.strain > 0 {
            let strainScore: Double
            if stats.strain >= 2 && stats.strain <= 5 {
                strainScore = 80
            } else if stats.strain < 2 {
                strainScore = 60  // Too low activity
            } else if stats.strain <= 7 {
                strainScore = 70
            } else {
                strainScore = 50  // Overtraining
            }
            score += strainScore * 0.15
            factors += 0.15
        }

        // HRV score (higher is better, 40-80ms is typical range)
        if stats.hrv > 0 {
            let hrvScore: Double
            if stats.hrv >= 60 {
                hrvScore = 100
            } else if stats.hrv >= 40 {
                hrvScore = 75
            } else if stats.hrv >= 25 {
                hrvScore = 50
            } else {
                hrvScore = 30
            }
            score += hrvScore * 0.2
            factors += 0.2
        }

        // Normalize if not all factors present
        if factors > 0 {
            score = score / factors
        } else {
            score = 50
        }

        return max(0, min(100, Int(score)))
    }

    private func getStatusInfo(score: Int) -> (text: String, color: UIColor, emoji: String) {
        switch score {
        case 80...100:
            return ("מצב מעולה", accentGreen, "🏎️")
        case 65..<80:
            return ("מצב טוב", accentCyan, "🚙")
        case 50..<65:
            return ("מצב בינוני", accentOrange, "🚗")
        case 35..<50:
            return ("צריך טיפול", accentOrange, "🚕")
        default:
            return ("דורש תשומת לב", accentRed, "🛻")
        }
    }

    // MARK: - Car Image Loading via Wikipedia API

    private func fetchCarImageFromWikipedia(carName: String, into imageView: UIImageView, fallbackEmoji: String) {
        // Generate candidate names: full name, then progressively shorter
        // e.g. "Tesla Model 3 Standard Range" -> ["Tesla Model 3 Standard Range", "Tesla Model 3 Standard", "Tesla Model 3"]
        let words = carName.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ").map(String.init)
        var candidates: [String] = []

        // Start with full name, then remove words from the end (minimum 2 words)
        for count in stride(from: words.count, through: max(2, words.count > 3 ? 2 : words.count), by: -1) {
            candidates.append(words.prefix(count).joined(separator: " "))
        }

        // Remove duplicates while preserving order
        var seen = Set<String>()
        candidates = candidates.filter { seen.insert($0).inserted }

        print("=== WIKI API: Will try candidates: \(candidates) ===")

        tryWikipediaCandidates(candidates: candidates, index: 0, into: imageView, fallbackEmoji: fallbackEmoji)
    }

    private func tryWikipediaCandidates(candidates: [String], index: Int, into imageView: UIImageView, fallbackEmoji: String) {
        guard index < candidates.count else {
            print("=== WIKI API: All candidates exhausted, showing fallback ===")
            DispatchQueue.main.async { [weak self] in
                self?.showFallbackEmoji(in: imageView, emoji: fallbackEmoji)
            }
            return
        }

        let carName = candidates[index]
        let wikiTitle = carName.replacingOccurrences(of: " ", with: "_")
        let apiURL = "https://en.wikipedia.org/api/rest_v1/page/summary/\(wikiTitle)"

        guard let url = URL(string: apiURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? apiURL) else {
            print("=== WIKI API: Invalid URL for '\(wikiTitle)' ===")
            tryWikipediaCandidates(candidates: candidates, index: index + 1, into: imageView, fallbackEmoji: fallbackEmoji)
            return
        }

        print("=== WIKI API: Trying candidate [\(index + 1)/\(candidates.count)] '\(carName)' -> \(url.absoluteString) ===")

        URLSession.shared.dataTask(with: url) { [weak self, weak imageView] data, response, error in
            guard let self = self, let imageView = imageView else { return }

            if let error = error {
                print("=== WIKI API ERROR: \(error.localizedDescription) ===")
                self.tryWikipediaCandidates(candidates: candidates, index: index + 1, into: imageView, fallbackEmoji: fallbackEmoji)
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("=== WIKI API: Failed to parse JSON for '\(carName)' ===")
                self.tryWikipediaCandidates(candidates: candidates, index: index + 1, into: imageView, fallbackEmoji: fallbackEmoji)
                return
            }

            // Extract thumbnail URL from response
            if let thumbnail = json["thumbnail"] as? [String: Any],
               let source = thumbnail["source"] as? String {
                // Change thumbnail size to 640px for better quality
                let thumbURL = source.replacingOccurrences(of: "/320px-", with: "/640px-")
                    .replacingOccurrences(of: "/330px-", with: "/640px-")

                guard let imageURL = URL(string: thumbURL) else {
                    self.tryWikipediaCandidates(candidates: candidates, index: index + 1, into: imageView, fallbackEmoji: fallbackEmoji)
                    return
                }

                print("=== WIKI API: Found thumbnail for '\(carName)' -> \(thumbURL) ===")

                // Download the actual image
                URLSession.shared.dataTask(with: imageURL) { [weak self, weak imageView] imgData, _, imgError in
                    DispatchQueue.main.async {
                        guard let self = self, let imageView = imageView else { return }

                        if let imgData = imgData, let image = UIImage(data: imgData) {
                            print("=== CAR IMAGE LOADED SUCCESSFULLY from '\(carName)' ===")
                            imageView.image = image
                            imageView.contentMode = .scaleAspectFill
                            imageView.backgroundColor = .clear

                            // Save car image for widget
                            WidgetDataManager.shared.saveCarImage(image)
                        } else {
                            print("=== CAR IMAGE: Failed to decode - \(imgError?.localizedDescription ?? "unknown") ===")
                            self.showFallbackEmoji(in: imageView, emoji: fallbackEmoji)
                        }
                    }
                }.resume()
            } else {
                print("=== WIKI API: No thumbnail for '\(carName)', trying next candidate ===")
                self.tryWikipediaCandidates(candidates: candidates, index: index + 1, into: imageView, fallbackEmoji: fallbackEmoji)
            }
        }.resume()
    }

    private func showFallbackEmoji(in imageView: UIImageView, emoji: String) {
        imageView.subviews.forEach { $0.removeFromSuperview() }
        let emojiLabel = UILabel()
        emojiLabel.text = emoji
        emojiLabel.font = .systemFont(ofSize: 60)
        emojiLabel.textAlignment = .center
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false
        imageView.addSubview(emojiLabel)
        imageView.backgroundColor = .clear
        NSLayoutConstraint.activate([
            emojiLabel.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            emojiLabel.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
        ])
    }

    // MARK: - Weekly Data Grid (4 boxes)

    private func addWeeklyDataGrid(parsed: CarAnalysisResponse) {
        let header = makeSectionHeader("נתוני השבוע", icon: nil, color: accentCyan)
        stack.addArrangedSubview(header)

        // Grid container
        let gridStack = UIStackView()
        gridStack.axis = .vertical
        gridStack.spacing = 12
        gridStack.translatesAutoresizingMaskIntoConstraints = false

        // Load real weekly stats from cache
        let stats = AnalysisCache.loadWeeklyStats()

        // Format sleep value
        let sleepValue: String
        if let s = stats?.sleepHours, s > 0 {
            let hours = Int(s)
            let minutes = Int((s - Double(hours)) * 60)
            sleepValue = "\(hours)h \(minutes)m Ø"
        } else {
            sleepValue = "-- Ø"
        }

        // Format readiness value
        let readinessValue: String
        if let r = stats?.readiness, r > 0 {
            readinessValue = String(format: "%.0f", r)
        } else {
            readinessValue = "--"
        }

        // Format strain value
        let strainValue: String
        if let st = stats?.strain, st > 0 {
            strainValue = String(format: "%.1f", st)
        } else {
            strainValue = "--"
        }

        // Format HRV value
        let hrvValue: String
        if let h = stats?.hrv, h > 0 {
            hrvValue = String(format: "%.0f ms", h)
        } else {
            hrvValue = "-- ms"
        }

        // Row 1
        let row1 = UIStackView()
        row1.axis = .horizontal
        row1.spacing = 12
        row1.distribution = .fillEqually

        let sleepBox = makeDataBox(
            icon: "bed.double.fill",
            title: "שינה",
            value: sleepValue,
            color: accentCyan,
            explanation: "ממוצע שעות שינה בשבוע האחרון. 7-9 שעות נחשב אופטימלי להתאוששות."
        )
        let readinessBox = makeDataBox(
            icon: "bolt.fill",
            title: "מוכנות",
            value: readinessValue,
            color: accentCyan,
            explanation: "ציון המוכנות שלך לאימון (0-100). מבוסס על שינה, HRV ועומס קודם."
        )

        row1.addArrangedSubview(sleepBox)
        row1.addArrangedSubview(readinessBox)

        // Row 2
        let row2 = UIStackView()
        row2.axis = .horizontal
        row2.spacing = 12
        row2.distribution = .fillEqually

        let strainBox = makeDataBox(
            icon: "flame.fill",
            title: "עומס",
            value: strainValue,
            color: accentOrange,
            explanation: "רמת העומס הפיזי השבועי (0-10). עומס מאוזן הוא 2-5."
        )
        let hrvBox = makeDataBox(
            icon: "waveform.path.ecg",
            title: "HRV",
            value: hrvValue,
            color: accentCyan,
            explanation: "שונות קצב הלב (Heart Rate Variability). ערך גבוה יותר מצביע על יכולת התאוששות טובה יותר."
        )

        row2.addArrangedSubview(strainBox)
        row2.addArrangedSubview(hrvBox)

        // Row 3 - Activity Data
        let row3 = UIStackView()
        row3.axis = .horizontal
        row3.spacing = 12
        row3.distribution = .fillEqually

        // Fetch activity data
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate

        // Steps value - will be updated async
        let stepsValue = "טוען..."
        let exerciseValue = "טוען..."

        let stepsBox = makeDataBox(
            icon: "figure.walk",
            title: "צעדים",
            value: stepsValue,
            color: accentOrange,
            explanation: "סה״כ צעדים בשבוע האחרון. מומלץ לשאוף ל-10,000 צעדים ביום."
        )

        let exerciseBox = makeDataBox(
            icon: "flame.fill",
            title: "דקות אימון",
            value: exerciseValue,
            color: accentGreen,
            explanation: "דקות פעילות גופנית בעצימות בינונית-גבוהה. מומלץ 150+ דקות בשבוע."
        )

        row3.addArrangedSubview(stepsBox)
        row3.addArrangedSubview(exerciseBox)

        gridStack.addArrangedSubview(row1)
        gridStack.addArrangedSubview(row2)
        gridStack.addArrangedSubview(row3)

        stack.addArrangedSubview(gridStack)

        // Async load activity data
        loadActivityDataForGrid(stepsBox: stepsBox, exerciseBox: exerciseBox, startDate: startDate, endDate: endDate)
    }

    private func loadActivityDataForGrid(stepsBox: UIView, exerciseBox: UIView, startDate: Date, endDate: Date) {
        let group = DispatchGroup()
        var totalSteps: Double = 0
        var totalExercise: Double = 0

        group.enter()
        HealthKitManager.shared.fetchSteps(startDate: startDate, endDate: endDate) { steps in
            totalSteps = steps ?? 0
            group.leave()
        }

        group.enter()
        HealthKitManager.shared.fetchExerciseMinutes(startDate: startDate, endDate: endDate) { minutes in
            totalExercise = minutes ?? 0
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }

            // Update steps label
            if let valueLabel = stepsBox.subviews.compactMap({ $0 as? UILabel }).first(where: { $0.font == .systemFont(ofSize: 22, weight: .bold) }) {
                if totalSteps > 0 {
                    if totalSteps >= 1000 {
                        valueLabel.text = String(format: "%.1fK", totalSteps / 1000)
                    } else {
                        valueLabel.text = String(format: "%.0f", totalSteps)
                    }
                } else {
                    valueLabel.text = "--"
                }
            }

            // Update exercise label
            if let valueLabel = exerciseBox.subviews.compactMap({ $0 as? UILabel }).first(where: { $0.font == .systemFont(ofSize: 22, weight: .bold) }) {
                if totalExercise > 0 {
                    valueLabel.text = String(format: "%.0f דק׳", totalExercise)
                } else {
                    valueLabel.text = "-- דק׳"
                }
            }
        }
    }

    private func makeDataBox(icon: String, title: String, value: String, color: UIColor, explanation: String) -> UIView {
        let box = UIView()
        box.backgroundColor = cardBgColor
        box.layer.cornerRadius = 16
        box.translatesAutoresizingMaskIntoConstraints = false

        // Info button (top left) - using CardInfoButton like the rest of the app
        let infoBtn = CardInfoButton.make(explanation: explanation)

        // Icon (top right)
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        // Title
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = textGray
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Value
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 22, weight: .bold)
        valueLabel.textColor = textWhite
        valueLabel.textAlignment = .center
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        box.addSubview(infoBtn)
        box.addSubview(iconView)
        box.addSubview(titleLabel)
        box.addSubview(valueLabel)

        NSLayoutConstraint.activate([
            box.heightAnchor.constraint(equalToConstant: 100),

            infoBtn.topAnchor.constraint(equalTo: box.topAnchor, constant: 12),
            infoBtn.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),

            iconView.topAnchor.constraint(equalTo: box.topAnchor, constant: 12),
            iconView.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
            titleLabel.centerXAnchor.constraint(equalTo: box.centerXAnchor),

            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            valueLabel.centerXAnchor.constraint(equalTo: box.centerXAnchor),
        ])

        return box
    }

    // MARK: - Performance Section (Expandable Cards)

    private func addPerformanceSection(parsed: CarAnalysisResponse) {
        let hasContent = !parsed.engine.isEmpty || !parsed.transmission.isEmpty ||
                         !parsed.suspension.isEmpty || !parsed.fuelEfficiency.isEmpty ||
                         !parsed.electronics.isEmpty

        guard hasContent else { return }

        let header = makeSectionHeader("תובנות AI", icon: nil, color: accentCyan)
        stack.addArrangedSubview(header)

        let items: [(emoji: String, title: String, content: String, color: UIColor)] = [
            ("🔥", "מנוע", parsed.engine, accentOrange),
            ("⚙️", "תיבת הילוכים", parsed.transmission, accentPurple),
            ("🛞", "מתלים", parsed.suspension, accentGreen),
            ("⛽", "יעילות דלק", parsed.fuelEfficiency, accentCyan),
            ("🧠", "אלקטרוניקה", parsed.electronics, accentBlue),
        ]

        for item in items {
            if !item.content.isEmpty {
                let card = makeExpandableCard(emoji: item.emoji, title: item.title, content: item.content, color: item.color)
                stack.addArrangedSubview(card)
            }
        }
    }

    private func makeExpandableCard(emoji: String, title: String, content: String, color: UIColor) -> UIView {
        let card = UIView()
        card.backgroundColor = cardBgColor
        card.layer.cornerRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false

        // Emoji
        let emojiLabel = UILabel()
        emojiLabel.text = emoji
        emojiLabel.font = .systemFont(ofSize: 20)
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false

        // Title
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = color
        titleLabel.textAlignment = .right
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Content - using UITextView for proper RTL text wrapping
        let contentTextView = UITextView()
        contentTextView.text = cleanDisplayText(content)
        contentTextView.font = .systemFont(ofSize: 14, weight: .regular)
        contentTextView.textColor = textWhite
        contentTextView.textAlignment = .right
        contentTextView.backgroundColor = .clear
        contentTextView.isEditable = false
        contentTextView.isScrollEnabled = false
        contentTextView.textContainerInset = .zero
        contentTextView.textContainer.lineFragmentPadding = 0
        contentTextView.semanticContentAttribute = .forceRightToLeft
        contentTextView.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(emojiLabel)
        card.addSubview(titleLabel)
        card.addSubview(contentTextView)

        NSLayoutConstraint.activate([
            emojiLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            emojiLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            titleLabel.centerYAnchor.constraint(equalTo: emojiLabel.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: emojiLabel.leadingAnchor, constant: -8),

            contentTextView.topAnchor.constraint(equalTo: emojiLabel.bottomAnchor, constant: 12),
            contentTextView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            contentTextView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            contentTextView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        return card
    }

    /// מנקה טקסט מתווים מיותרים (נקודתיים בתחילה, כוכביות בסוף וכו')
    private func cleanDisplayText(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // הסרת ":" או ": " מתחילת הטקסט
        while cleaned.hasPrefix(":") || cleaned.hasPrefix(" :") {
            if cleaned.hasPrefix(": ") {
                cleaned = String(cleaned.dropFirst(2))
            } else if cleaned.hasPrefix(":") {
                cleaned = String(cleaned.dropFirst(1))
            } else if cleaned.hasPrefix(" :") {
                cleaned = String(cleaned.dropFirst(2))
            }
            cleaned = cleaned.trimmingCharacters(in: .whitespaces)
        }

        // הסרת "*" מסוף הטקסט
        while cleaned.hasSuffix("*") || cleaned.hasSuffix(" *") {
            if cleaned.hasSuffix(" *") {
                cleaned = String(cleaned.dropLast(2))
            } else if cleaned.hasSuffix("*") {
                cleaned = String(cleaned.dropLast(1))
            }
            cleaned = cleaned.trimmingCharacters(in: .whitespaces)
        }

        return cleaned
    }

    // MARK: - Bottlenecks Card

    private func addBottlenecksCard(parsed: CarAnalysisResponse) {
        guard !parsed.bottlenecks.isEmpty || !parsed.warningSignals.isEmpty else { return }

        let card = UIView()
        card.backgroundColor = cardBgColor
        card.layer.cornerRadius = 16
        card.layer.borderWidth = 1
        card.layer.borderColor = accentOrange.withAlphaComponent(0.3).cgColor
        card.translatesAutoresizingMaskIntoConstraints = false

        let innerStack = UIStackView()
        innerStack.axis = .vertical
        innerStack.spacing = 12
        innerStack.alignment = .fill
        innerStack.translatesAutoresizingMaskIntoConstraints = false

        // Title row - positioned manually for correct RTL alignment
        let titleContainer = UIView()
        titleContainer.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill"))
        icon.tintColor = accentOrange
        icon.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = "מה מגביל את הביצועים?"
        title.font = .systemFont(ofSize: 16, weight: .bold)
        title.textColor = accentOrange
        title.textAlignment = .right
        title.translatesAutoresizingMaskIntoConstraints = false

        titleContainer.addSubview(icon)
        titleContainer.addSubview(title)

        NSLayoutConstraint.activate([
            icon.trailingAnchor.constraint(equalTo: titleContainer.trailingAnchor),
            icon.centerYAnchor.constraint(equalTo: titleContainer.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),

            title.trailingAnchor.constraint(equalTo: icon.leadingAnchor, constant: -8),
            title.centerYAnchor.constraint(equalTo: titleContainer.centerYAnchor),
            title.leadingAnchor.constraint(greaterThanOrEqualTo: titleContainer.leadingAnchor),

            titleContainer.heightAnchor.constraint(equalToConstant: 24),
        ])

        innerStack.addArrangedSubview(titleContainer)

        for item in parsed.bottlenecks {
            // Skip items that are just the question repeated
            if item.contains("מה מגביל את הביצועים") { continue }
            let row = makeWarningRow(text: item, color: accentOrange, iconName: "exclamationmark.triangle.fill")
            innerStack.addArrangedSubview(row)
        }

        for item in parsed.warningSignals {
            // Skip items that are just the question repeated
            if item.contains("מה מגביל את הביצועים") { continue }
            let row = makeWarningRow(text: item, color: accentRed, iconName: "exclamationmark.circle.fill")
            innerStack.addArrangedSubview(row)
        }

        card.addSubview(innerStack)
        NSLayoutConstraint.activate([
            innerStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            innerStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            innerStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            innerStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        stack.addArrangedSubview(card)
    }

    private func makeWarningRow(text: String, color: UIColor, iconName: String) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 10
        row.alignment = .top
        row.semanticContentAttribute = .forceRightToLeft

        let bullet = UILabel()
        bullet.text = "•"
        bullet.font = .systemFont(ofSize: 18, weight: .bold)
        bullet.textColor = color
        bullet.setContentHuggingPriority(.required, for: .horizontal)

        let textView = UITextView()
        textView.text = cleanDisplayText(text)
        textView.font = .systemFont(ofSize: 14, weight: .regular)
        textView.textColor = textWhite
        textView.textAlignment = .right
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.semanticContentAttribute = .forceRightToLeft

        row.addArrangedSubview(bullet)
        row.addArrangedSubview(textView)

        return row
    }

    // MARK: - Optimization Card

    private func addOptimizationCard(parsed: CarAnalysisResponse) {
        guard !parsed.upgrades.isEmpty || !parsed.skippedMaintenance.isEmpty || !parsed.stopImmediately.isEmpty else { return }

        let header = makeSectionHeader("תוכנית אופטימיזציה", icon: "wrench.and.screwdriver.fill", color: accentGreen)
        stack.addArrangedSubview(header)

        let card = UIView()
        card.backgroundColor = cardBgColor
        card.layer.cornerRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false

        let innerStack = UIStackView()
        innerStack.axis = .vertical
        innerStack.spacing = 14
        innerStack.alignment = .fill
        innerStack.translatesAutoresizingMaskIntoConstraints = false

        if !parsed.upgrades.isEmpty {
            let subHeader = makeSubHeader("שדרוגים מומלצים", color: accentGreen)
            innerStack.addArrangedSubview(subHeader)
            for item in parsed.upgrades {
                let row = makeCheckRow(text: item, color: accentGreen)
                innerStack.addArrangedSubview(row)
            }
        }

        if !parsed.skippedMaintenance.isEmpty {
            let subHeader = makeSubHeader("טיפול שמדלגים עליו", color: accentOrange)
            innerStack.addArrangedSubview(subHeader)
            for item in parsed.skippedMaintenance {
                let row = makeCheckRow(text: item, color: accentOrange)
                innerStack.addArrangedSubview(row)
            }
        }

        if !parsed.stopImmediately.isEmpty {
            let subHeader = makeSubHeader("להפסיק מיד", color: accentRed)
            innerStack.addArrangedSubview(subHeader)
            for item in parsed.stopImmediately {
                let row = makeCheckRow(text: item, color: accentRed)
                innerStack.addArrangedSubview(row)
            }
        }

        card.addSubview(innerStack)
        NSLayoutConstraint.activate([
            innerStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            innerStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            innerStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            innerStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        stack.addArrangedSubview(card)
    }

    private func makeCheckRow(text: String, color: UIColor) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 10
        row.alignment = .top
        row.semanticContentAttribute = .forceRightToLeft

        let checkIcon = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        checkIcon.tintColor = color
        checkIcon.translatesAutoresizingMaskIntoConstraints = false
        checkIcon.setContentHuggingPriority(.required, for: .horizontal)

        let textView = UITextView()
        textView.text = text
        textView.font = .systemFont(ofSize: 14, weight: .regular)
        textView.textColor = textWhite
        textView.textAlignment = .right
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.semanticContentAttribute = .forceRightToLeft

        row.addArrangedSubview(checkIcon)
        row.addArrangedSubview(textView)

        NSLayoutConstraint.activate([
            checkIcon.widthAnchor.constraint(equalToConstant: 20),
            checkIcon.heightAnchor.constraint(equalToConstant: 20),
        ])

        return row
    }

    // MARK: - Tune-Up Card

    private func addTuneUpCard(parsed: CarAnalysisResponse) {
        let hasContent = !parsed.trainingAdjustments.isEmpty ||
                         !parsed.recoveryChanges.isEmpty ||
                         !parsed.habitToAdd.isEmpty ||
                         !parsed.habitToRemove.isEmpty

        guard hasContent else { return }

        let header = makeSectionHeader("תוכנית כוונון 30-60 יום", icon: "calendar.badge.clock", color: accentPurple)
        stack.addArrangedSubview(header)

        let card = UIView()
        card.backgroundColor = cardBgColor
        card.layer.cornerRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false

        let innerStack = UIStackView()
        innerStack.axis = .vertical
        innerStack.spacing = 12
        innerStack.alignment = .fill
        innerStack.translatesAutoresizingMaskIntoConstraints = false

        if !parsed.trainingAdjustments.isEmpty {
            let row = makeTuneUpRow(emoji: "🏃", title: "התאמות אימון", content: parsed.trainingAdjustments)
            innerStack.addArrangedSubview(row)
        }

        if !parsed.recoveryChanges.isEmpty {
            let row = makeTuneUpRow(emoji: "😴", title: "התאוששות ושינה", content: parsed.recoveryChanges)
            innerStack.addArrangedSubview(row)
        }

        if !parsed.habitToAdd.isEmpty {
            let row = makeTuneUpRow(emoji: "➕", title: "הרגל להוסיף", content: parsed.habitToAdd)
            innerStack.addArrangedSubview(row)
        }

        if !parsed.habitToRemove.isEmpty {
            let row = makeTuneUpRow(emoji: "➖", title: "הרגל להסיר", content: parsed.habitToRemove)
            innerStack.addArrangedSubview(row)
        }

        card.addSubview(innerStack)
        NSLayoutConstraint.activate([
            innerStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            innerStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            innerStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            innerStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        stack.addArrangedSubview(card)
    }

    private func makeTuneUpRow(emoji: String, title: String, content: String) -> UIView {
        let container = UIView()
        container.backgroundColor = accentPurple.withAlphaComponent(0.1)
        container.layer.cornerRadius = 12
        container.translatesAutoresizingMaskIntoConstraints = false

        let emojiLabel = UILabel()
        emojiLabel.text = emoji
        emojiLabel.font = .systemFont(ofSize: 22)
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = accentPurple
        titleLabel.textAlignment = .right
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let contentTextView = UITextView()
        contentTextView.text = cleanDisplayText(content)
        contentTextView.font = .systemFont(ofSize: 13, weight: .regular)
        contentTextView.textColor = textGray
        contentTextView.textAlignment = .right
        contentTextView.backgroundColor = .clear
        contentTextView.isEditable = false
        contentTextView.isScrollEnabled = false
        contentTextView.textContainerInset = .zero
        contentTextView.textContainer.lineFragmentPadding = 0
        contentTextView.semanticContentAttribute = .forceRightToLeft
        contentTextView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(emojiLabel)
        container.addSubview(titleLabel)
        container.addSubview(contentTextView)

        NSLayoutConstraint.activate([
            emojiLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            emojiLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),

            titleLabel.centerYAnchor.constraint(equalTo: emojiLabel.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: emojiLabel.leadingAnchor, constant: -8),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 12),

            contentTextView.topAnchor.constraint(equalTo: emojiLabel.bottomAnchor, constant: 8),
            contentTextView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            contentTextView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            contentTextView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
        ])

        return container
    }

    // MARK: - Nutrition Button

    private func addNutritionButton(parsed: CarAnalysisResponse) {
        guard !parsed.supplements.isEmpty else { return }

        // שמירת התוספים למעבר למסך
        currentSupplements = parsed.supplements

        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false

        // יצירת container עם עיצוב Premium
        let container = UIView()
        container.backgroundColor = cardBgColor
        container.layer.cornerRadius = 16
        container.layer.borderWidth = 1.5
        container.layer.borderColor = accentGreen.withAlphaComponent(0.4).cgColor
        container.translatesAutoresizingMaskIntoConstraints = false
        container.isUserInteractionEnabled = false

        // אייקון
        let iconLabel = UILabel()
        iconLabel.text = "💊"
        iconLabel.font = .systemFont(ofSize: 32)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false

        // כותרת
        let titleLabel = UILabel()
        titleLabel.text = "המלצות תזונה ותוספים"
        titleLabel.font = .systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = textWhite
        titleLabel.textAlignment = .right
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // תיאור
        let subtitleLabel = UILabel()
        subtitleLabel.text = "תוספים מומלצים מבוססי ניתוח הנתונים שלך"
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = textGray
        subtitleLabel.textAlignment = .right
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Badge עם מספר התוספים
        let countBadge = UIView()
        countBadge.backgroundColor = accentGreen.withAlphaComponent(0.2)
        countBadge.layer.cornerRadius = 10
        countBadge.translatesAutoresizingMaskIntoConstraints = false

        let countLabel = UILabel()
        countLabel.text = "\(parsed.supplements.count) המלצות"
        countLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        countLabel.textColor = accentGreen
        countLabel.translatesAutoresizingMaskIntoConstraints = false

        countBadge.addSubview(countLabel)

        // חץ
        let arrowLabel = UILabel()
        arrowLabel.text = "←"
        arrowLabel.font = .systemFont(ofSize: 20, weight: .medium)
        arrowLabel.textColor = accentGreen
        arrowLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(iconLabel)
        container.addSubview(titleLabel)
        container.addSubview(subtitleLabel)
        container.addSubview(countBadge)
        container.addSubview(arrowLabel)

        NSLayoutConstraint.activate([
            // אייקון בצד ימין
            iconLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            // כותרת
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: iconLabel.leadingAnchor, constant: -12),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: arrowLabel.trailingAnchor, constant: 8),

            // תיאור
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: arrowLabel.trailingAnchor, constant: 8),

            // Badge
            countBadge.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 8),
            countBadge.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            countBadge.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),

            countLabel.topAnchor.constraint(equalTo: countBadge.topAnchor, constant: 4),
            countLabel.leadingAnchor.constraint(equalTo: countBadge.leadingAnchor, constant: 10),
            countLabel.trailingAnchor.constraint(equalTo: countBadge.trailingAnchor, constant: -10),
            countLabel.bottomAnchor.constraint(equalTo: countBadge.bottomAnchor, constant: -4),

            // חץ בצד שמאל
            arrowLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            arrowLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
        ])

        // הוספת ה-container לכפתור
        button.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: button.topAnchor),
            container.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: button.bottomAnchor),
        ])

        button.addTarget(self, action: #selector(openNutritionScreen), for: .touchUpInside)

        stack.addArrangedSubview(button)

        // גובה מינימלי לכפתור
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 90).isActive = true
    }

    @objc private func openNutritionScreen() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let nutritionVC = NutritionViewController()
        nutritionVC.supplements = currentSupplements
        navigationController?.pushViewController(nutritionVC, animated: true)
    }

    // MARK: - Directives Card

    private func addDirectivesCard(parsed: CarAnalysisResponse) {
        guard !parsed.directiveStop.isEmpty || !parsed.directiveStart.isEmpty || !parsed.directiveWatch.isEmpty else { return }

        let header = makeSectionHeader("הנחיות פעולה", icon: "checklist", color: accentCyan)
        stack.addArrangedSubview(header)

        let card = UIView()
        card.backgroundColor = cardBgColor
        card.layer.cornerRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false

        let innerStack = UIStackView()
        innerStack.axis = .vertical
        innerStack.spacing = 16
        innerStack.alignment = .fill
        innerStack.translatesAutoresizingMaskIntoConstraints = false

        if !parsed.directiveStop.isEmpty {
            let row = makeDirectiveRow(label: "STOP", content: parsed.directiveStop, color: accentRed)
            innerStack.addArrangedSubview(row)
        }

        if !parsed.directiveStart.isEmpty {
            let row = makeDirectiveRow(label: "START", content: parsed.directiveStart, color: accentGreen)
            innerStack.addArrangedSubview(row)
        }

        if !parsed.directiveWatch.isEmpty {
            let row = makeDirectiveRow(label: "WATCH", content: parsed.directiveWatch, color: accentOrange)
            innerStack.addArrangedSubview(row)
        }

        card.addSubview(innerStack)
        NSLayoutConstraint.activate([
            innerStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            innerStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            innerStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            innerStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        stack.addArrangedSubview(card)
    }

    private func makeDirectiveRow(label: String, content: String, color: UIColor) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let badge = UILabel()
        badge.text = label
        badge.font = .systemFont(ofSize: 12, weight: .bold)
        badge.textColor = color
        badge.textAlignment = .right
        badge.translatesAutoresizingMaskIntoConstraints = false

        let contentTextView = UITextView()
        contentTextView.text = cleanDisplayText(content)
        contentTextView.font = .systemFont(ofSize: 14, weight: .regular)
        contentTextView.textColor = textWhite
        contentTextView.textAlignment = .right
        contentTextView.backgroundColor = .clear
        contentTextView.isEditable = false
        contentTextView.isScrollEnabled = false
        contentTextView.textContainerInset = .zero
        contentTextView.textContainer.lineFragmentPadding = 0
        contentTextView.semanticContentAttribute = .forceRightToLeft
        contentTextView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(badge)
        container.addSubview(contentTextView)

        NSLayoutConstraint.activate([
            badge.topAnchor.constraint(equalTo: container.topAnchor),
            badge.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            contentTextView.topAnchor.constraint(equalTo: badge.bottomAnchor, constant: 6),
            contentTextView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            contentTextView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            contentTextView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    // MARK: - Summary Card

    private func addSummaryCard(parsed: CarAnalysisResponse) {
        guard !parsed.summary.isEmpty else { return }

        let header = makeSectionHeader("מבט קדימה", icon: "crystal.ball", color: accentCyan)
        stack.addArrangedSubview(header)

        let card = UIView()
        card.backgroundColor = cardBgColor
        card.layer.cornerRadius = 16
        card.layer.borderWidth = 1
        card.layer.borderColor = accentCyan.withAlphaComponent(0.3).cgColor
        card.translatesAutoresizingMaskIntoConstraints = false

        let quoteIcon = UILabel()
        quoteIcon.text = "🔮"
        quoteIcon.font = .systemFont(ofSize: 32)
        quoteIcon.textAlignment = .center
        quoteIcon.translatesAutoresizingMaskIntoConstraints = false

        let summaryLabel = UILabel()
        summaryLabel.text = "\"" + parsed.summary + "\""
        summaryLabel.font = .italicSystemFont(ofSize: 14)
        summaryLabel.textColor = textWhite
        summaryLabel.textAlignment = .center
        summaryLabel.numberOfLines = 0
        summaryLabel.lineBreakMode = .byWordWrapping
        summaryLabel.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(quoteIcon)
        card.addSubview(summaryLabel)

        NSLayoutConstraint.activate([
            quoteIcon.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            quoteIcon.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            summaryLabel.topAnchor.constraint(equalTo: quoteIcon.bottomAnchor, constant: 10),
            summaryLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            summaryLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            summaryLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        stack.addArrangedSubview(card)
    }

    // MARK: - Car Upgrade Reveal Experience (כשהרכב משתנה)

    private func addCarUpgradeRevealExperience() {
        isShowingDiscoveryFlow = true

        let container = UIView()
        container.backgroundColor = .clear
        container.translatesAutoresizingMaskIntoConstraints = false
        self.discoveryContainer = container

        // גרדיאנט רקע זהב-סגול (מייצג upgrade/שינוי)
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 0.85, green: 0.65, blue: 0.13, alpha: 0.3).cgColor, // זהב
            UIColor(red: 0.15, green: 0.1, blue: 0.3, alpha: 1.0).cgColor,
            cardBgColor.cgColor
        ]
        gradientLayer.locations = [0.0, 0.4, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)

        let gradientView = UIView()
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        gradientView.layer.insertSublayer(gradientLayer, at: 0)
        gradientView.layer.cornerRadius = 24
        gradientView.clipsToBounds = true
        container.addSubview(gradientView)

        // תמונת רכב מכוסה עם סרט
        let carImageContainer = UIView()
        carImageContainer.translatesAutoresizingMaskIntoConstraints = false

        // תמונת הרכב המכוסה (ללא רקע)
        let coveredCarImage = UIImageView(image: UIImage(named: "newCarClear"))
        coveredCarImage.contentMode = .scaleAspectFit
        coveredCarImage.translatesAutoresizingMaskIntoConstraints = false
        coveredCarImage.layer.cornerRadius = 16
        coveredCarImage.clipsToBounds = true
        carImageContainer.addSubview(coveredCarImage)

        // ספרקלס מסביב
        let sparkleLeft = UILabel()
        sparkleLeft.text = "✨"
        sparkleLeft.font = .systemFont(ofSize: 28)
        sparkleLeft.translatesAutoresizingMaskIntoConstraints = false
        carImageContainer.addSubview(sparkleLeft)

        let sparkleRight = UILabel()
        sparkleRight.text = "✨"
        sparkleRight.font = .systemFont(ofSize: 28)
        sparkleRight.translatesAutoresizingMaskIntoConstraints = false
        carImageContainer.addSubview(sparkleRight)

        // כותרת
        let titleLabel = UILabel()
        titleLabel.text = "יש לך רכב חדש!"
        titleLabel.font = .systemFont(ofSize: 26, weight: .bold)
        titleLabel.textColor = textWhite
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // תת-כותרת עם הרכב הקודם
        let subtitleLabel = UILabel()
        if let pending = AnalysisCache.getPendingCar(), !pending.previousName.isEmpty {
            subtitleLabel.text = "הנתונים שלך השתנו משמעותית\nהגיע הזמן להחליף את ה-\(pending.previousName)"
        } else {
            subtitleLabel.text = "הנתונים שלך השתנו משמעותית\nהגיע הזמן לגלות את הרכב המעודכן"
        }
        subtitleLabel.font = .systemFont(ofSize: 15, weight: .regular)
        subtitleLabel.textColor = textGray
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        // כפתור CTA
        let ctaButton = UIButton(type: .system)
        ctaButton.translatesAutoresizingMaskIntoConstraints = false

        // גרדיאנט לכפתור (זהב-כתום)
        let buttonGradient = CAGradientLayer()
        buttonGradient.colors = [
            UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0).cgColor, // זהב
            UIColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0).cgColor   // כתום
        ]
        buttonGradient.startPoint = CGPoint(x: 0, y: 0.5)
        buttonGradient.endPoint = CGPoint(x: 1, y: 0.5)
        buttonGradient.cornerRadius = 28

        ctaButton.layer.insertSublayer(buttonGradient, at: 0)
        ctaButton.setTitle("🎁  גלה את הרכב החדש", for: .normal)
        ctaButton.setTitleColor(.black, for: .normal)
        ctaButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        ctaButton.layer.cornerRadius = 28
        ctaButton.clipsToBounds = true
        ctaButton.addTarget(self, action: #selector(revealNewCarTapped), for: .touchUpInside)

        // הוספה לcontainer
        container.addSubview(carImageContainer)
        container.addSubview(titleLabel)
        container.addSubview(subtitleLabel)
        container.addSubview(ctaButton)

        // Constraints
        NSLayoutConstraint.activate([
            gradientView.topAnchor.constraint(equalTo: container.topAnchor),
            gradientView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            gradientView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            carImageContainer.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            carImageContainer.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            carImageContainer.widthAnchor.constraint(equalTo: container.widthAnchor, constant: -24),
            carImageContainer.heightAnchor.constraint(equalToConstant: 220),

            coveredCarImage.topAnchor.constraint(equalTo: carImageContainer.topAnchor),
            coveredCarImage.centerXAnchor.constraint(equalTo: carImageContainer.centerXAnchor),
            coveredCarImage.widthAnchor.constraint(equalTo: carImageContainer.widthAnchor),
            coveredCarImage.heightAnchor.constraint(equalTo: carImageContainer.heightAnchor),

            sparkleLeft.trailingAnchor.constraint(equalTo: coveredCarImage.leadingAnchor, constant: 30),
            sparkleLeft.topAnchor.constraint(equalTo: carImageContainer.topAnchor, constant: 20),

            sparkleRight.leadingAnchor.constraint(equalTo: coveredCarImage.trailingAnchor, constant: -30),
            sparkleRight.topAnchor.constraint(equalTo: carImageContainer.topAnchor, constant: 20),

            titleLabel.topAnchor.constraint(equalTo: carImageContainer.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),

            ctaButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 28),
            ctaButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            ctaButton.widthAnchor.constraint(equalToConstant: 260),
            ctaButton.heightAnchor.constraint(equalToConstant: 56),
            ctaButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -32),
        ])

        stack.addArrangedSubview(container)

        // עדכון גרדיאנט אחרי layout
        DispatchQueue.main.async {
            gradientLayer.frame = gradientView.bounds
            buttonGradient.frame = ctaButton.bounds
        }

        // אנימציות - זוהר על התמונה
        coveredCarImage.layer.shadowColor = UIColor.white.cgColor
        coveredCarImage.layer.shadowRadius = 20
        coveredCarImage.layer.shadowOpacity = 0.3
        coveredCarImage.layer.shadowOffset = .zero

        ctaButton.startPulseAnimation()

        // אנימציית sparkles
        sparkleLeft.layer.add(createSparkleAnimation(delay: 0), forKey: "sparkle")
        sparkleRight.layer.add(createSparkleAnimation(delay: 0.5), forKey: "sparkle")
    }

    private func createSparkleAnimation(delay: Double) -> CAAnimation {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 0.3
        animation.toValue = 1.0
        animation.duration = 0.8
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.beginTime = CACurrentMediaTime() + delay
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        return animation
    }

    @objc private func revealNewCarTapped() {
        // Haptic feedback
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        // אנימציית חשיפה מהירה (הנתונים כבר קיימים)
        showUpgradeRevealAnimation()
    }

    private func showUpgradeRevealAnimation() {
        guard let container = discoveryContainer else { return }

        // ביטול מינימום גובה קודם
        discoveryMinHeightConstraint?.isActive = false
        discoveryMinHeightConstraint = nil

        // ניקוי הcontainer
        container.subviews.forEach { $0.removeFromSuperview() }

        // רקע עם particles
        particleBackground = ParticleBackground(in: container)
        particleBackground?.start()

        // Container מרכזי
        let centerStack = UIStackView()
        centerStack.axis = .vertical
        centerStack.spacing = 20
        centerStack.alignment = .center
        centerStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(centerStack)

        // אייקון מונפש
        let iconLabel = UILabel()
        iconLabel.text = "🔄"
        iconLabel.font = .systemFont(ofSize: 60)
        iconLabel.textAlignment = .center

        // טקסט סטטוס
        let statusLabel = UILabel()
        statusLabel.text = "מכין את הרכב החדש..."
        statusLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        statusLabel.textColor = textWhite
        statusLabel.textAlignment = .center

        // Progress bar
        let progressBar = AnimatedProgressBar()
        progressBar.progressColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // זהב
        progressBar.translatesAutoresizingMaskIntoConstraints = false

        centerStack.addArrangedSubview(iconLabel)
        centerStack.addArrangedSubview(statusLabel)
        centerStack.addArrangedSubview(progressBar)

        let minHeight = container.heightAnchor.constraint(greaterThanOrEqualToConstant: 300)
        minHeight.priority = .defaultHigh
        discoveryMinHeightConstraint = minHeight

        NSLayoutConstraint.activate([
            minHeight,
            centerStack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            centerStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 60),
            centerStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 40),
            centerStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -40),

            progressBar.heightAnchor.constraint(equalToConstant: 8),
            progressBar.widthAnchor.constraint(equalTo: centerStack.widthAnchor),
        ])

        // אנימציית pulse + סיבוב
        iconLabel.startPulseAnimation()
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = CGFloat.pi * 2
        rotation.duration = 1.5
        rotation.repeatCount = .infinity
        iconLabel.layer.add(rotation, forKey: "rotation")

        // שלב 1: מכין (1.5 שניות)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            progressBar.animateProgress(to: 0.5, duration: 1.2)
        }

        // שלב 2: חושף (1 שנייה)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            iconLabel.text = "🎉"
            iconLabel.layer.removeAnimation(forKey: "rotation")
            statusLabel.text = "מוכן!"
            progressBar.animateProgress(to: 1.0, duration: 0.5)
        }

        // חשיפה! (אחרי 2.5 שניות)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.showUpgradeRevealResult()
        }
    }

    private func showUpgradeRevealResult() {
        guard let container = discoveryContainer else { return }

        particleBackground?.stop()

        // טעינת הנתונים מה-pending
        guard let pending = AnalysisCache.getPendingCar() else {
            // אם אין נתונים, פשוט ננקה ונטען מחדש
            AnalysisCache.clearPendingCarReveal()
            refreshContent()
            return
        }

        // Flash effect
        container.flashWhite(duration: 0.3) { [weak self] in
            guard let self = self else { return }

            // ניקוי הcontainer
            container.subviews.forEach { $0.removeFromSuperview() }

            // Confetti!
            self.confettiEmitter = ConfettiEmitter(in: container)
            self.confettiEmitter?.start()

            // Haptic
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            // קריאה ל-parsed data מ-cache
            if let insights = AnalysisCache.loadLatest() {
                let parsed = CarAnalysisParser.parse(insights)
                self.buildRevealedCarCard(in: container, parsed: parsed)
            } else {
                // אם אין insights, נבנה כרטיס פשוט מהנתונים שיש לנו
                self.buildSimpleRevealCard(in: container, pending: pending)
            }

            // ניקוי ה-pending (הרכב החדש נשמר כנוכחי)
            AnalysisCache.clearPendingCarReveal()
        }
    }

    private func buildSimpleRevealCard(in container: UIView, pending: (name: String, wikiName: String, explanation: String, previousName: String)) {
        // כרטיס פשוט אם אין parsed data מלא
        let card = UIView()
        card.backgroundColor = cardBgColor
        card.layer.cornerRadius = 20
        card.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(card)

        let carLabel = UILabel()
        carLabel.text = "🚗"
        carLabel.font = .systemFont(ofSize: 80)
        carLabel.textAlignment = .center
        carLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(carLabel)

        let nameLabel = UILabel()
        nameLabel.text = pending.name
        nameLabel.font = .systemFont(ofSize: 24, weight: .bold)
        nameLabel.textColor = textWhite
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(nameLabel)

        let changeLabel = UILabel()
        if !pending.previousName.isEmpty {
            changeLabel.text = "\(pending.previousName) → \(pending.name)"
        } else {
            changeLabel.text = pending.name
        }
        changeLabel.font = .systemFont(ofSize: 14, weight: .medium)
        changeLabel.textColor = accentCyan
        changeLabel.textAlignment = .center
        changeLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(changeLabel)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: container.topAnchor),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            carLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 40),
            carLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            nameLabel.topAnchor.constraint(equalTo: carLabel.bottomAnchor, constant: 20),
            nameLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            changeLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 12),
            changeLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            changeLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -40),
        ])

        // אנימציות
        card.alpha = 0
        card.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        UIView.animate(withDuration: 0.5, delay: 0.1, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            card.alpha = 1
            card.transform = .identity
        }
    }

    // MARK: - First Time Discovery Experience

    private func addFirstTimeDiscoveryExperience() {
        isShowingDiscoveryFlow = true

        let container = UIView()
        container.backgroundColor = .clear
        container.translatesAutoresizingMaskIntoConstraints = false
        self.discoveryContainer = container

        // גרדיאנט רקע סגול-כחול
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 0.15, green: 0.1, blue: 0.3, alpha: 1.0).cgColor,
            UIColor(red: 0.08, green: 0.08, blue: 0.15, alpha: 1.0).cgColor,
            cardBgColor.cgColor
        ]
        gradientLayer.locations = [0.0, 0.5, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)

        let gradientView = UIView()
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        gradientView.layer.insertSublayer(gradientLayer, at: 0)
        gradientView.layer.cornerRadius = 24
        gradientView.clipsToBounds = true
        container.addSubview(gradientView)

        // סימן שאלה מעל התמונה
        let questionLabel = UILabel()
        questionLabel.text = "❓"
        questionLabel.font = .systemFont(ofSize: 44)
        questionLabel.textAlignment = .center
        questionLabel.translatesAutoresizingMaskIntoConstraints = false

        // תמונת רכב מכוסה עם סרט
        let mysteryCarContainer = UIView()
        mysteryCarContainer.translatesAutoresizingMaskIntoConstraints = false

        // תמונת הרכב המכוסה (ללא רקע)
        let coveredCarImage = UIImageView(image: UIImage(named: "newCarClear"))
        coveredCarImage.contentMode = .scaleAspectFit
        coveredCarImage.translatesAutoresizingMaskIntoConstraints = false
        coveredCarImage.layer.cornerRadius = 16
        coveredCarImage.clipsToBounds = true
        mysteryCarContainer.addSubview(coveredCarImage)

        // כותרת
        let titleLabel = UILabel()
        titleLabel.text = "מוכן לגלות איזה רכב אתה?"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = textWhite
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // תת-כותרת
        let subtitleLabel = UILabel()
        subtitleLabel.text = "על סמך נתוני הבריאות שלך,\nנגלה איזה רכב מייצג אותך הכי טוב"
        subtitleLabel.font = .systemFont(ofSize: 15, weight: .regular)
        subtitleLabel.textColor = textGray
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        // כפתור CTA
        let ctaButton = UIButton(type: .system)
        ctaButton.translatesAutoresizingMaskIntoConstraints = false

        // גרדיאנט לכפתור
        let buttonGradient = CAGradientLayer()
        buttonGradient.colors = [
            accentCyan.cgColor,
            accentPurple.cgColor
        ]
        buttonGradient.startPoint = CGPoint(x: 0, y: 0.5)
        buttonGradient.endPoint = CGPoint(x: 1, y: 0.5)
        buttonGradient.cornerRadius = 28

        ctaButton.layer.insertSublayer(buttonGradient, at: 0)
        ctaButton.setTitle("🔮  גלה את הרכב שלי", for: .normal)
        ctaButton.setTitleColor(.white, for: .normal)
        ctaButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        ctaButton.layer.cornerRadius = 28
        ctaButton.clipsToBounds = true
        ctaButton.addTarget(self, action: #selector(discoverCarTapped), for: .touchUpInside)

        // הוספה לcontainer
        container.addSubview(questionLabel)
        container.addSubview(mysteryCarContainer)
        container.addSubview(titleLabel)
        container.addSubview(subtitleLabel)
        container.addSubview(ctaButton)

        // Constraints
        NSLayoutConstraint.activate([
            gradientView.topAnchor.constraint(equalTo: container.topAnchor),
            gradientView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            gradientView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            // סימן שאלה מעל התמונה
            questionLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            questionLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            // תמונת הרכב מתחת לסימן שאלה - גדולה ומרשימה
            mysteryCarContainer.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: 4),
            mysteryCarContainer.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            mysteryCarContainer.widthAnchor.constraint(equalTo: container.widthAnchor, constant: -24),
            mysteryCarContainer.heightAnchor.constraint(equalToConstant: 220),

            coveredCarImage.topAnchor.constraint(equalTo: mysteryCarContainer.topAnchor),
            coveredCarImage.centerXAnchor.constraint(equalTo: mysteryCarContainer.centerXAnchor),
            coveredCarImage.widthAnchor.constraint(equalTo: mysteryCarContainer.widthAnchor),
            coveredCarImage.heightAnchor.constraint(equalTo: mysteryCarContainer.heightAnchor),

            titleLabel.topAnchor.constraint(equalTo: mysteryCarContainer.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),

            ctaButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 28),
            ctaButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            ctaButton.widthAnchor.constraint(equalToConstant: 260),
            ctaButton.heightAnchor.constraint(equalToConstant: 56),
            ctaButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -32),
        ])

        stack.addArrangedSubview(container)

        // עדכון גרדיאנט אחרי layout
        DispatchQueue.main.async {
            gradientLayer.frame = gradientView.bounds
            buttonGradient.frame = ctaButton.bounds
        }

        // אנימציות - זוהר על התמונה
        coveredCarImage.layer.shadowColor = accentPurple.cgColor
        coveredCarImage.layer.shadowRadius = 25
        coveredCarImage.layer.shadowOpacity = 0.5
        coveredCarImage.layer.shadowOffset = .zero

        ctaButton.startPulseAnimation()
        questionLabel.layer.add(self.createFloatAnimation(), forKey: "float")
    }

    private func createFloatAnimation() -> CAAnimation {
        let animation = CABasicAnimation(keyPath: "transform.translation.y")
        animation.fromValue = 0
        animation.toValue = -8
        animation.duration = 1.5
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        return animation
    }

    @objc private func discoverCarTapped() {
        // Haptic feedback
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        // התחלת אנימציית הטעינה
        showDiscoveryLoadingAnimation()
    }

    // MARK: - Discovery Loading Animation

private func showDiscoveryLoadingAnimation() {
    guard let container = discoveryContainer else { return }

    // ✅ חשוב: לבטל מינימום גובה קודם אם נשאר
    discoveryMinHeightConstraint?.isActive = false
    discoveryMinHeightConstraint = nil

    // ניקוי הcontainer
    container.subviews.forEach { $0.removeFromSuperview() }

    // רקע עם particles
    particleBackground = ParticleBackground(in: container)
    particleBackground?.start()

    // Container מרכזי
    let centerStack = UIStackView()
    centerStack.axis = .vertical
    centerStack.spacing = 20
    centerStack.alignment = .center
    centerStack.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(centerStack)

    // אייקון מונפש
    let iconLabel = UILabel()
    iconLabel.text = "💓"
    iconLabel.font = .systemFont(ofSize: 60)
    iconLabel.textAlignment = .center

    // טקסט סטטוס
    let statusLabel = UILabel()
    statusLabel.text = "סורק נתוני בריאות..."
    statusLabel.font = .systemFont(ofSize: 18, weight: .semibold)
    statusLabel.textColor = textWhite
    statusLabel.textAlignment = .center

    // Progress bar
    let progressBar = AnimatedProgressBar()
    progressBar.progressColor = accentCyan
    progressBar.translatesAutoresizingMaskIntoConstraints = false

    centerStack.addArrangedSubview(iconLabel)
    centerStack.addArrangedSubview(statusLabel)
    centerStack.addArrangedSubview(progressBar)

    // ✅ שומרים את ה-constraint כדי שנוכל לבטל אותו אחרי זה
    let minHeight = container.heightAnchor.constraint(greaterThanOrEqualToConstant: 300)
    minHeight.priority = .defaultHigh
    discoveryMinHeightConstraint = minHeight

    NSLayoutConstraint.activate([
        minHeight,
        centerStack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
        centerStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 60),
        centerStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 40),
        centerStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -40),

        progressBar.heightAnchor.constraint(equalToConstant: 8),
        progressBar.widthAnchor.constraint(equalTo: centerStack.widthAnchor),
    ])

    // אנימציית pulse על האייקון
    iconLabel.startPulseAnimation()

    // שלב 1: סורק (3 שניות)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        progressBar.animateProgress(to: 0.3, duration: 2.5)
    }

    // שלב 2: מנתח (2 שניות)
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
        iconLabel.text = "🧠"
        statusLabel.text = "מנתח ביצועים..."
        progressBar.animateProgress(to: 0.6, duration: 1.8)
    }

    // שלב 3: מוצא התאמה (2 שניות)
    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
        iconLabel.text = "🎯"
        statusLabel.text = "מוצא את הרכב המושלם..."
        progressBar.animateProgress(to: 0.9, duration: 1.5)
    }

    // קריאה ל-Gemini במקביל
    if let dashboard = (tabBarController?.viewControllers?.first as? UINavigationController)?.viewControllers.first as? HealthDashboardViewController {
        dashboard.runAnalysisForInsights()
    }

    // המתנה לתוצאה (מקסימום 7 שניות)
    DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) { [weak self] in
        self?.checkForResultsAndReveal()
    }
}

    private func checkForResultsAndReveal() {
        particleBackground?.stop()

        // בדיקה אם יש תוצאות
        if let insights = AnalysisCache.loadLatest(), !insights.isEmpty {
            let parsed = CarAnalysisParser.parse(insights)
            showRevealAnimation(parsed: parsed)
        } else {
            // אם אין תוצאות - ננסה שוב או נציג הודעה
            showRevealAnimation(parsed: nil)
        }
    }

    // MARK: - Reveal Animation (BOOM!)

    private func showRevealAnimation(parsed: CarAnalysisResponse?) {
        guard let container = discoveryContainer else { return }

        // Flash effect
        container.flashWhite(duration: 0.3) { [weak self] in
            guard let self = self else { return }

            // ניקוי הcontainer
            container.subviews.forEach { $0.removeFromSuperview() }

            // Confetti!
            self.confettiEmitter = ConfettiEmitter(in: container)
            self.confettiEmitter?.start()

            // Haptic
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            // בניית כרטיס הרכב
            self.buildRevealedCarCard(in: container, parsed: parsed)
        }
    }

    private func buildRevealedCarCard(in container: UIView, parsed: CarAnalysisResponse?) {
        // ✅ לבטל מינימום גובה שנשאר מאנימציית הטעינה
        discoveryMinHeightConstraint?.isActive = false
        discoveryMinHeightConstraint = nil

        // Get score (for display only)
        let stats = AnalysisCache.loadWeeklyStats()
        let score: Int
        if let savedScore = AnalysisCache.loadHealthScore() {
            score = savedScore
        } else {
            score = CarTierEngine.computeHealthScore(
                readinessAvg: stats?.readiness,
                sleepHoursAvg: stats?.sleepHours,
                hrvAvg: stats?.hrv,
                strainAvg: stats?.strain
            )
        }

        // Determine car name - priority: Gemini > Saved > Placeholder
        let carName: String
        let wikiName: String
        let explanation: String

        if let parsed = parsed {
            let cleanedName = cleanCarName(parsed.carModel)
            let invalidWords = ["strain", "training", "score", "wiki", "generation"]
            let lowerCar = cleanedName.lowercased()
            let isValid = !cleanedName.isEmpty &&
                          !invalidWords.contains(where: { lowerCar.contains($0) }) &&
                          cleanedName.count > 3 && cleanedName.count < 40

            if isValid {
                carName = cleanedName
                wikiName = parsed.carWikiName
                explanation = parsed.carExplanation
                AnalysisCache.checkAndSetCarChange(newCarName: carName, newWikiName: wikiName, newExplanation: explanation)
            } else if let savedCar = AnalysisCache.loadSelectedCar() {
                carName = savedCar.name
                wikiName = savedCar.wikiName
                explanation = savedCar.explanation
            } else {
                carName = "ממתין לניתוח..."
                wikiName = ""
                explanation = "הרכב שלך ייבחר לאחר ניתוח ראשון של הנתונים"
            }
        } else if let savedCar = AnalysisCache.loadSelectedCar() {
            carName = savedCar.name
            wikiName = savedCar.wikiName
            explanation = savedCar.explanation
        } else {
            carName = "ממתין לניתוח..."
            wikiName = ""
            explanation = "הרכב שלך ייבחר לאחר ניתוח ראשון של הנתונים"
        }

        // Determine status and color based on score
        let status: String
        let tierColor: UIColor
        switch score {
        case 80...100:
            status = "שיא ביצועים"
            tierColor = AIONDesign.accentSuccess
        case 65..<80:
            status = "מצוין"
            tierColor = AIONDesign.accentSecondary
        case 45..<65:
            status = "מצב טוב"
            tierColor = AIONDesign.accentPrimary
        case 25..<45:
            status = "בסדר"
            tierColor = AIONDesign.accentWarning
        default:
            status = "צריך טיפול"
            tierColor = AIONDesign.accentDanger
        }

        // כרטיס רקע
        let card = UIView()
        card.backgroundColor = cardBgColor
        card.layer.cornerRadius = 20
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        card.alpha = 0
        card.transform = CGAffineTransform(scaleX: 0.5, y: 0.5).translatedBy(x: 0, y: -100)
        container.addSubview(card)
        self.carCardView = card

        // תמונת רקע - לא קובעת גובה, רק ממלאת את הכרטיס
        class NoIntrinsicImageView: UIImageView {
            override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric) }
        }
        let bgImageView = NoIntrinsicImageView()
        bgImageView.contentMode = .scaleAspectFill
        bgImageView.clipsToBounds = true
        bgImageView.backgroundColor = UIColor(white: 0.15, alpha: 1)
        bgImageView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(bgImageView)

        // גרדיאנט - קל יותר כדי לראות את התמונה
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.black.withAlphaComponent(0.4).cgColor,
            UIColor.black.withAlphaComponent(0.1).cgColor,
            UIColor.black.withAlphaComponent(0.5).cgColor
        ]
        gradientLayer.locations = [0.0, 0.4, 1.0]
        let gradientView = UIView()
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        gradientView.layer.insertSublayer(gradientLayer, at: 0)
        card.addSubview(gradientView)

        // שם הרכב - בכותרת למעלה בגדול
        let carNameLabel = UILabel()
        carNameLabel.text = carName  // מציג מיד את השם!
        carNameLabel.font = .systemFont(ofSize: 28, weight: .heavy)
        carNameLabel.textColor = .white
        carNameLabel.textAlignment = .center
        carNameLabel.numberOfLines = 1
        carNameLabel.adjustsFontSizeToFitWidth = true
        carNameLabel.minimumScaleFactor = 0.7
        carNameLabel.layer.shadowColor = UIColor.black.cgColor
        carNameLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
        carNameLabel.layer.shadowOpacity = 1
        carNameLabel.layer.shadowRadius = 4
        carNameLabel.translatesAutoresizingMaskIntoConstraints = false
        carNameLabel.alpha = 0  // יופיע עם אנימציה
        card.addSubview(carNameLabel)

        // Badge סטטוס
        let statusBadge = PaddedLabel()
        statusBadge.text = status
        statusBadge.font = .systemFont(ofSize: 14, weight: .bold)
        statusBadge.textColor = .white
        statusBadge.backgroundColor = tierColor
        statusBadge.layer.cornerRadius = 16
        statusBadge.clipsToBounds = true
        statusBadge.alpha = 0
        statusBadge.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(statusBadge)

        // ציון (יספור מ-0)
        let scoreLabel = UILabel()
        scoreLabel.text = "0/100"
        scoreLabel.font = .systemFont(ofSize: 24, weight: .bold)
        scoreLabel.textColor = tierColor
        scoreLabel.layer.shadowColor = UIColor.black.cgColor
        scoreLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        scoreLabel.layer.shadowOpacity = 0.8
        scoreLabel.layer.shadowRadius = 3
        scoreLabel.alpha = 0
        scoreLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(scoreLabel)

        // Progress bar
        let progressBar = AnimatedProgressBar()
        progressBar.progressColor = tierColor
        progressBar.alpha = 0
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(progressBar)

        // הסבר
        let explanationLabel = UILabel()
        let rawExplanation = parsed?.carExplanation ?? "הרכב נבחר על סמך ניתוח נתוני הבריאות שלך."
        explanationLabel.text = cleanExplanationText(rawExplanation, carName: carName)
        explanationLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        explanationLabel.textColor = .white
        explanationLabel.textAlignment = .right
        explanationLabel.numberOfLines = 0
        explanationLabel.alpha = 0
        explanationLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(explanationLabel)

        // כפתורים
        let buttonsStack = UIStackView()
        buttonsStack.axis = .horizontal
        buttonsStack.spacing = 12
        buttonsStack.distribution = .fillEqually
        buttonsStack.alpha = 0
        buttonsStack.translatesAutoresizingMaskIntoConstraints = false

        let refreshButton = createActionButton(title: "🔄 בדוק שוב", action: #selector(rediscoverTapped))
        let detailsButton = createActionButton(title: "📊 פרטים", action: #selector(showDetailsTapped))

        buttonsStack.addArrangedSubview(refreshButton)
        buttonsStack.addArrangedSubview(detailsButton)
        card.addSubview(buttonsStack)

        // Constraints - תמונה בגובה קבוע 200, הכרטיס גדל לפי התוכן
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: container.topAnchor),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor), // חיבור ל-container

            // תמונה - fill לכל הכרטיס
            bgImageView.topAnchor.constraint(equalTo: card.topAnchor),
            bgImageView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            bgImageView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            bgImageView.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            // gradient על כל הכרטיס
            gradientView.topAnchor.constraint(equalTo: card.topAnchor),
            gradientView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            gradientView.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            carNameLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            carNameLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            carNameLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            statusBadge.topAnchor.constraint(equalTo: carNameLabel.bottomAnchor, constant: 12),
            statusBadge.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            scoreLabel.centerYAnchor.constraint(equalTo: statusBadge.centerYAnchor),
            scoreLabel.trailingAnchor.constraint(equalTo: statusBadge.leadingAnchor, constant: -8),

            progressBar.topAnchor.constraint(equalTo: statusBadge.bottomAnchor, constant: 8),
            progressBar.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            progressBar.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            progressBar.heightAnchor.constraint(equalToConstant: 6),

            explanationLabel.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 8),
            explanationLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            explanationLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            buttonsStack.topAnchor.constraint(equalTo: explanationLabel.bottomAnchor, constant: 8),
            buttonsStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            buttonsStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            buttonsStack.heightAnchor.constraint(equalToConstant: 44),
            buttonsStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
        ])

        // טעינת תמונה
        if !wikiName.isEmpty {
            fetchCarImageFromWikipedia(carName: wikiName, into: bgImageView, fallbackEmoji: "🚗")
        }

        // עדכון גרדיאנט
        DispatchQueue.main.async {
            gradientLayer.frame = gradientView.bounds
        }

        // === אנימציות חשיפה ===

        // 1. כרטיס נכנס עם bounce
        UIView.animate(
            withDuration: 0.8,
            delay: 0.2,
            usingSpringWithDamping: 0.65,
            initialSpringVelocity: 0.5,
            options: []
        ) {
            card.alpha = 1
            card.transform = .identity
            container.superview?.layoutIfNeeded() // עדכון layout
        }

        // 2. שם הרכב מופיע עם fade-in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UIView.animate(withDuration: 0.6) {
                carNameLabel.alpha = 1
            }
        }

        // 3. Badge נכנס
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            UIView.animate(withDuration: 0.4) {
                statusBadge.alpha = 1
                statusBadge.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            } completion: { _ in
                UIView.animate(withDuration: 0.2) {
                    statusBadge.transform = .identity
                }
            }
        }

        // 4. ציון סופר
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            scoreLabel.alpha = 1
            let counterAnimator = NumberCounterAnimator(label: scoreLabel)
            counterAnimator.animate(from: 0, to: score, duration: 1.5, suffix: "/100")
        }

        // 5. Progress bar
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            progressBar.alpha = 1
            progressBar.animateProgress(to: CGFloat(score) / 100.0, duration: 1.5)
        }

        // 6. הסבר fade in
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            UIView.animate(withDuration: 0.5) {
                explanationLabel.alpha = 1
            }
        }

        // 7. כפתורים
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            UIView.animate(withDuration: 0.4) {
                buttonsStack.alpha = 1
            }
        }

        // 8. הוספת שאר התוכן אחרי 4 שניות
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
            guard let self = self else { return }
            self.isShowingDiscoveryFlow = false
            self.addRemainingContent(parsed: parsed)
        }

        // סימון שהמשתמש כבר גילה
        UserDefaults.standard.set(true, forKey: "AION.HasDiscoveredCar")

        // עדכון widget עם נתוני פעילות אמיתיים
        let hrvValue = stats?.hrv ?? 0
        let sleepValue = stats?.sleepHours ?? 0
        let dailyActivity = AnalysisCache.loadDailyActivity()
        WidgetDataManager.shared.updateFromInsights(
            score: score,
            status: status,
            carName: carName,
            carEmoji: "🚗",
            steps: dailyActivity?.steps ?? 0,
            activeCalories: dailyActivity?.calories ?? 0,
            exerciseMinutes: dailyActivity?.exerciseMinutes ?? 0,
            standHours: dailyActivity?.standHours ?? 0,
            restingHR: dailyActivity?.restingHR ?? 0 > 0 ? dailyActivity?.restingHR : nil,
            hrv: hrvValue > 0 ? Int(hrvValue) : nil,
            sleepHours: sleepValue > 0 ? sleepValue : nil
        )
    }

    private func createActionButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    // הוספת שאר התוכן אחרי אנימציית החשיפה
    private func addRemainingContent(parsed: CarAnalysisResponse?) {
        guard let parsed = parsed else { return }

        // הוספת כותרת "תובנות AION" מעל הכרטיס
        insertHeaderAboveCard()

        // הוספת כל הקטעים הנוספים
        addWeeklyDataGrid(parsed: parsed)
        addPerformanceSection(parsed: parsed)
        addBottlenecksCard(parsed: parsed)
        addOptimizationCard(parsed: parsed)
        addTuneUpCard(parsed: parsed)
        addNutritionButton(parsed: parsed)
        addDirectivesCard(parsed: parsed)
        addSummaryCard(parsed: parsed)
    }

    // הוספת כותרת מעל כרטיס הרכב
    private func insertHeaderAboveCard() {
        let headerStack = UIStackView()
        headerStack.axis = .vertical
        headerStack.spacing = 4
        headerStack.alignment = .center

        let sparkle = UILabel()
        sparkle.text = "✨"
        sparkle.font = .systemFont(ofSize: 28)

        let title = UILabel()
        title.text = "תובנות AION"
        title.font = .systemFont(ofSize: 22, weight: .bold)
        title.textColor = textWhite

        let subtitle = UILabel()
        subtitle.text = "ניתוח ביומטרי מבוסס נתונים"
        subtitle.font = .systemFont(ofSize: 13, weight: .regular)
        subtitle.textColor = textGray

        let dateLabel = UILabel()
        if let d = AnalysisCache.lastUpdateDate() {
            let f = DateFormatter()
            f.locale = Locale(identifier: "he_IL")
            f.dateFormat = "d בMMMM yyyy"
            dateLabel.text = "עדכון אחרון: \(f.string(from: d))"
        }
        dateLabel.font = .systemFont(ofSize: 12, weight: .regular)
        dateLabel.textColor = textDarkGray

        headerStack.addArrangedSubview(sparkle)
        headerStack.addArrangedSubview(title)
        headerStack.addArrangedSubview(subtitle)
        headerStack.addArrangedSubview(dateLabel)

        // הוספה בתחילת ה-stack (מעל כרטיס הרכב)
        stack.insertArrangedSubview(headerStack, at: 0)
    }

    @objc private func rediscoverTapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // מחיקת cache ו-restart
        AnalysisCache.clear()
        UserDefaults.standard.set(false, forKey: "AION.HasDiscoveredCar")
        isShowingDiscoveryFlow = false
        refreshContent()
    }

    @objc private func showDetailsTapped() {
        // גלילה למטה להציג את שאר התוכן
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // אם אין עדיין תוכן נוסף, נוסיף אותו
        if stack.arrangedSubviews.count <= 2 {
            guard let insights = AnalysisCache.loadLatest(), !insights.isEmpty else { return }
            let parsed = CarAnalysisParser.parse(insights)

            // הוספת שאר הקטעים
            addWeeklyDataGrid(parsed: parsed)
            addPerformanceSection(parsed: parsed)
            addBottlenecksCard(parsed: parsed)
            addOptimizationCard(parsed: parsed)
            addTuneUpCard(parsed: parsed)
            addNutritionButton(parsed: parsed)
            addDirectivesCard(parsed: parsed)
            addSummaryCard(parsed: parsed)
        }

        // גלילה למטה
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            let bottomOffset = CGPoint(x: 0, y: min(300, self.scrollView.contentSize.height - self.scrollView.bounds.height))
            if bottomOffset.y > 0 {
                self.scrollView.setContentOffset(bottomOffset, animated: true)
            }
        }
    }

    // MARK: - Empty State (Legacy - now shows discovery)

    private func addEmptyState() {
        // בדיקה אם זו פעם ראשונה או שהמשתמש כבר גילה
        let hasDiscovered = UserDefaults.standard.bool(forKey: "AION.HasDiscoveredCar")

        if !hasDiscovered {
            addFirstTimeDiscoveryExperience()
        } else {
            // Empty state רגיל (למקרה שה-cache נמחק אבל המשתמש כבר גילה)
            addLegacyEmptyState()
        }
    }

    private func addLegacyEmptyState() {
        let card = UIView()
        card.backgroundColor = cardBgColor
        card.layer.cornerRadius = 20
        card.translatesAutoresizingMaskIntoConstraints = false

        let icon = UILabel()
        icon.text = "🚗"
        icon.font = .systemFont(ofSize: 64)
        icon.textAlignment = .center
        icon.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "אין עדיין ניתוח ביצועים"
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = textWhite
        titleLabel.textAlignment = .center

        let subtitleLabel = UILabel()
        subtitleLabel.text = "לחץ על כפתור הרענון למעלה להתחיל"
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = textGray
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        let stackInner = UIStackView(arrangedSubviews: [icon, titleLabel, subtitleLabel])
        stackInner.axis = .vertical
        stackInner.spacing = 12
        stackInner.alignment = .center
        stackInner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stackInner)

        NSLayoutConstraint.activate([
            stackInner.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            stackInner.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            stackInner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            stackInner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),
            stackInner.topAnchor.constraint(equalTo: card.topAnchor, constant: 48),
            stackInner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -48),
        ])

        stack.addArrangedSubview(card)
    }

    // MARK: - Helpers

    private func makeSectionHeader(_ title: String, icon: String?, color: UIColor) -> UIView {
        let container = UIStackView()
        container.axis = .horizontal
        container.spacing = 8
        container.alignment = .center
        container.semanticContentAttribute = .forceRightToLeft

        if let iconName = icon {
            let iconView = UIImageView(image: UIImage(systemName: iconName))
            iconView.tintColor = color
            iconView.contentMode = .scaleAspectFit
            iconView.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                iconView.widthAnchor.constraint(equalToConstant: 20),
                iconView.heightAnchor.constraint(equalToConstant: 20),
            ])

            container.addArrangedSubview(iconView)
        }

        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 16, weight: .bold)
        label.textColor = color
        label.textAlignment = .right

        container.addArrangedSubview(label)

        return container
    }

    private func makeSubHeader(_ title: String, color: UIColor) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = color
        label.textAlignment = .right
        return label
    }
}
