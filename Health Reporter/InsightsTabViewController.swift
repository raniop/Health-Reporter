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
            UIColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1.0).cgColor
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
        v.backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1.0)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()

    private let loadingSpinner: UIActivityIndicatorView = {
        let s = UIActivityIndicatorView(style: .large)
        s.color = UIColor(red: 0.0, green: 0.8, blue: 0.9, alpha: 1.0)
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let loadingLabel: UILabel = {
        let l = UILabel()
        l.text = "מנתח נתונים..."
        l.font = .systemFont(ofSize: 16, weight: .medium)
        l.textColor = UIColor(white: 0.6, alpha: 1.0)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Colors

    private let bgColor = UIColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1.0)
    private let cardBgColor = UIColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1.0)
    private let accentCyan = UIColor(red: 0.0, green: 0.85, blue: 0.95, alpha: 1.0)
    private let accentGreen = UIColor(red: 0.2, green: 0.9, blue: 0.5, alpha: 1.0)
    private let accentOrange = UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0)
    private let accentRed = UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
    private let accentPurple = UIColor(red: 0.6, green: 0.4, blue: 1.0, alpha: 1.0)
    private let accentBlue = UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0)
    private let textWhite = UIColor.white
    private let textGray = UIColor(white: 0.65, alpha: 1.0)
    private let textDarkGray = UIColor(white: 0.45, alpha: 1.0)

    // MARK: - Properties

    private var analysisObserver: NSObjectProtocol?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "תובנות"
        view.backgroundColor = bgColor
        view.semanticContentAttribute = .forceRightToLeft
        navigationController?.navigationBar.barStyle = .black
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: textWhite]

        setupUI()
        setupRefreshButton()
        setupAnalysisObserver()
        refreshContent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshContent()
    }

    deinit {
        if let o = analysisObserver { NotificationCenter.default.removeObserver(o) }
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
        let btn = UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"), style: .plain, target: self, action: #selector(refreshTapped))
        btn.tintColor = accentCyan
        navigationItem.leftBarButtonItem = btn
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
        // לא מוחקים את המטמון - נותנים ל-dashboard להחליט אם צריך לקרוא ל-Gemini
        // על סמך hash של נתוני הבריאות
        showLoading()

        if let dashboard = (tabBarController?.viewControllers?.first as? UINavigationController)?.viewControllers.first as? HealthDashboardViewController {
            dashboard.runAnalysisForInsights()
        }
    }

    /// מאלץ ניתוח חדש גם אם יש cache (למשל כשהמשתמש רוצה ניתוח מחודש)
    @objc private func forceRefreshTapped() {
        showLoading()
        AnalysisCache.clear()
        AnalysisFirestoreSync.clear()

        if let dashboard = (tabBarController?.viewControllers?.first as? UINavigationController)?.viewControllers.first as? HealthDashboardViewController {
            dashboard.runAnalysisForInsights()
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
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

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

    private func addHeroCarCard(parsed: CarAnalysisResponse) {
        let card = UIView()
        card.backgroundColor = cardBgColor
        card.layer.cornerRadius = 20
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false

        // Calculate score from weekly stats
        let stats = AnalysisCache.loadWeeklyStats()
        let score = calculateHealthScore(stats: stats)
        let statusInfo = getStatusInfo(score: score)

        // === Background car image (fills entire card) ===
        let bgImageView = UIImageView()
        bgImageView.contentMode = .scaleAspectFill
        bgImageView.clipsToBounds = true
        bgImageView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(bgImageView)

        // Dark overlay so text is readable on top of image
        let darkOverlay = UIView()
        darkOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        darkOverlay.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(darkOverlay)

        // Bottom gradient overlay for extra readability on text area
        let bottomGradient = CAGradientLayer()
        bottomGradient.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.85).cgColor
        ]
        bottomGradient.locations = [0.0, 1.0]
        let bottomGradientView = UIView()
        bottomGradientView.translatesAutoresizingMaskIntoConstraints = false
        bottomGradientView.layer.insertSublayer(bottomGradient, at: 0)
        card.addSubview(bottomGradientView)

        NSLayoutConstraint.activate([
            bgImageView.topAnchor.constraint(equalTo: card.topAnchor),
            bgImageView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            bgImageView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            bgImageView.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            darkOverlay.topAnchor.constraint(equalTo: card.topAnchor),
            darkOverlay.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            darkOverlay.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            darkOverlay.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            bottomGradientView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            bottomGradientView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            bottomGradientView.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            bottomGradientView.heightAnchor.constraint(equalTo: card.heightAnchor, multiplier: 0.5),
        ])

        // Layout callback for bottom gradient
        bottomGradientView.layoutIfNeeded()
        DispatchQueue.main.async {
            bottomGradient.frame = bottomGradientView.bounds
        }

        // Load car image into background
        let wikiName = parsed.carWikiName
        print("=== CAR WIKI NAME: '\(wikiName)' ===")
        if !wikiName.isEmpty {
            bgImageView.backgroundColor = cardBgColor
            fetchCarImageFromWikipedia(carName: wikiName, into: bgImageView, fallbackEmoji: "")
        } else {
            bgImageView.backgroundColor = cardBgColor
        }

        // === Car Name - big and centered at top ===
        let carNameLabel = UILabel()
        carNameLabel.text = parsed.carModel.isEmpty ? "לא זוהה" : parsed.carModel
        carNameLabel.font = .systemFont(ofSize: 26, weight: .heavy)
        carNameLabel.textColor = textWhite
        carNameLabel.textAlignment = .center
        carNameLabel.numberOfLines = 2
        carNameLabel.adjustsFontSizeToFitWidth = true
        carNameLabel.minimumScaleFactor = 0.6
        carNameLabel.layer.shadowColor = UIColor.black.cgColor
        carNameLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
        carNameLabel.layer.shadowOpacity = 0.8
        carNameLabel.layer.shadowRadius = 4
        carNameLabel.translatesAutoresizingMaskIntoConstraints = false

        // Score + badge row
        let scoreRow = UIStackView()
        scoreRow.axis = .horizontal
        scoreRow.spacing = 10
        scoreRow.alignment = .center
        scoreRow.distribution = .fill
        scoreRow.translatesAutoresizingMaskIntoConstraints = false

        let scoreLabel = UILabel()
        scoreLabel.text = "\(score)/100"
        scoreLabel.font = .systemFont(ofSize: 20, weight: .bold)
        scoreLabel.textColor = statusInfo.color
        scoreLabel.layer.shadowColor = UIColor.black.cgColor
        scoreLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        scoreLabel.layer.shadowOpacity = 0.6
        scoreLabel.layer.shadowRadius = 3

        let statusBadge = PaddedLabel()
        statusBadge.text = statusInfo.text
        statusBadge.font = .systemFont(ofSize: 11, weight: .semibold)
        statusBadge.textColor = .white
        statusBadge.backgroundColor = statusInfo.color
        statusBadge.layer.cornerRadius = 12
        statusBadge.clipsToBounds = true
        statusBadge.textAlignment = .center

        let spacer = UIView()
        scoreRow.addArrangedSubview(spacer)
        scoreRow.addArrangedSubview(scoreLabel)
        scoreRow.addArrangedSubview(statusBadge)

        // Progress bar
        let progressBg = UIView()
        progressBg.backgroundColor = UIColor(white: 1.0, alpha: 0.2)
        progressBg.layer.cornerRadius = 4
        progressBg.translatesAutoresizingMaskIntoConstraints = false

        let progressFill = UIView()
        progressFill.backgroundColor = statusInfo.color
        progressFill.layer.cornerRadius = 4
        progressFill.translatesAutoresizingMaskIntoConstraints = false

        // Explanation title
        let explanationTitle = UILabel()
        explanationTitle.text = "למה בחרתי עבורך את הרכב הזה:"
        explanationTitle.font = .systemFont(ofSize: 13, weight: .bold)
        explanationTitle.textColor = statusInfo.color
        explanationTitle.textAlignment = .right
        explanationTitle.layer.shadowColor = UIColor.black.cgColor
        explanationTitle.layer.shadowOffset = CGSize(width: 0, height: 1)
        explanationTitle.layer.shadowOpacity = 0.5
        explanationTitle.layer.shadowRadius = 2
        explanationTitle.translatesAutoresizingMaskIntoConstraints = false

        // Scrollable explanation text
        let explanationTextView = UITextView()
        explanationTextView.text = parsed.carExplanation.isEmpty ? "הרכב נבחר על סמך ניתוח נתוני הבריאות שלך." : parsed.carExplanation
        explanationTextView.font = .systemFont(ofSize: 13, weight: .regular)
        explanationTextView.textColor = UIColor(white: 0.95, alpha: 1.0)
        explanationTextView.textAlignment = .right
        explanationTextView.backgroundColor = .clear
        explanationTextView.isEditable = false
        explanationTextView.isScrollEnabled = true
        explanationTextView.showsVerticalScrollIndicator = true
        explanationTextView.textContainerInset = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        explanationTextView.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(carNameLabel)
        card.addSubview(scoreRow)
        card.addSubview(progressBg)
        progressBg.addSubview(progressFill)
        card.addSubview(explanationTitle)
        card.addSubview(explanationTextView)

        let progressMultiplier = max(0.01, CGFloat(score) / 100.0)

        NSLayoutConstraint.activate([
            // Car name at top center - minimal top padding
            carNameLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            carNameLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            carNameLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            // Score row - tight spacing
            scoreRow.topAnchor.constraint(equalTo: carNameLabel.bottomAnchor, constant: 2),
            scoreRow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            scoreRow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            // Progress bar - tight spacing
            progressBg.topAnchor.constraint(equalTo: scoreRow.bottomAnchor, constant: 6),
            progressBg.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            progressBg.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            progressBg.heightAnchor.constraint(equalToConstant: 5),

            progressFill.topAnchor.constraint(equalTo: progressBg.topAnchor),
            progressFill.leadingAnchor.constraint(equalTo: progressBg.leadingAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressBg.bottomAnchor),
            progressFill.widthAnchor.constraint(equalTo: progressBg.widthAnchor, multiplier: progressMultiplier),

            // Explanation title - tight spacing
            explanationTitle.topAnchor.constraint(equalTo: progressBg.bottomAnchor, constant: 8),
            explanationTitle.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            explanationTitle.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            // Explanation text - larger area
            explanationTextView.topAnchor.constraint(equalTo: explanationTitle.bottomAnchor, constant: 2),
            explanationTextView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            explanationTextView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            explanationTextView.heightAnchor.constraint(equalToConstant: 160),
            explanationTextView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
        ])

        stack.addArrangedSubview(card)
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

        gridStack.addArrangedSubview(row1)
        gridStack.addArrangedSubview(row2)

        stack.addArrangedSubview(gridStack)
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

        // Content - cleaned
        let contentLabel = UILabel()
        contentLabel.text = cleanDisplayText(content)
        contentLabel.font = .systemFont(ofSize: 14, weight: .regular)
        contentLabel.textColor = textWhite
        contentLabel.textAlignment = .right
        contentLabel.numberOfLines = 0
        contentLabel.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(emojiLabel)
        card.addSubview(titleLabel)
        card.addSubview(contentLabel)

        NSLayoutConstraint.activate([
            emojiLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            emojiLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            titleLabel.centerYAnchor.constraint(equalTo: emojiLabel.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: emojiLabel.leadingAnchor, constant: -8),

            contentLabel.topAnchor.constraint(equalTo: emojiLabel.bottomAnchor, constant: 12),
            contentLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            contentLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            contentLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
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

        let titleRow = UIStackView()
        titleRow.axis = .horizontal
        titleRow.spacing = 8
        titleRow.alignment = .center
        titleRow.semanticContentAttribute = .forceRightToLeft

        let icon = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill"))
        icon.tintColor = accentOrange
        icon.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = "מה מגביל את הביצועים?"
        title.font = .systemFont(ofSize: 16, weight: .bold)
        title.textColor = accentOrange

        titleRow.addArrangedSubview(icon)
        titleRow.addArrangedSubview(title)

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),
        ])

        innerStack.addArrangedSubview(titleRow)

        for item in parsed.bottlenecks {
            let row = makeWarningRow(text: item, color: accentOrange, iconName: "exclamationmark.triangle.fill")
            innerStack.addArrangedSubview(row)
        }

        for item in parsed.warningSignals {
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

        let label = UILabel()
        label.text = cleanDisplayText(text)
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = textWhite
        label.textAlignment = .right
        label.numberOfLines = 0

        row.addArrangedSubview(bullet)
        row.addArrangedSubview(label)

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

        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = textWhite
        label.textAlignment = .right
        label.numberOfLines = 0

        row.addArrangedSubview(checkIcon)
        row.addArrangedSubview(label)

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

        let contentLabel = UILabel()
        contentLabel.text = cleanDisplayText(content)
        contentLabel.font = .systemFont(ofSize: 13, weight: .regular)
        contentLabel.textColor = textGray
        contentLabel.textAlignment = .right
        contentLabel.numberOfLines = 0
        contentLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(emojiLabel)
        container.addSubview(titleLabel)
        container.addSubview(contentLabel)

        NSLayoutConstraint.activate([
            emojiLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            emojiLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),

            titleLabel.centerYAnchor.constraint(equalTo: emojiLabel.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: emojiLabel.leadingAnchor, constant: -8),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 12),

            contentLabel.topAnchor.constraint(equalTo: emojiLabel.bottomAnchor, constant: 8),
            contentLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            contentLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            contentLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
        ])

        return container
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

        let contentLabel = UILabel()
        contentLabel.text = cleanDisplayText(content)
        contentLabel.font = .systemFont(ofSize: 14, weight: .regular)
        contentLabel.textColor = textWhite
        contentLabel.textAlignment = .right
        contentLabel.numberOfLines = 0
        contentLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(badge)
        container.addSubview(contentLabel)

        NSLayoutConstraint.activate([
            badge.topAnchor.constraint(equalTo: container.topAnchor),
            badge.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            contentLabel.topAnchor.constraint(equalTo: badge.bottomAnchor, constant: 6),
            contentLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            contentLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            contentLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
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

    // MARK: - Empty State

    private func addEmptyState() {
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
