//
//  InsightsTabViewController.swift
//  Health Reporter
//
//  Insights screen – Premium design with Hero Card like in the dashboard
//

import UIKit
import FirebaseAuth

// MARK: - Padded Label for badges

private final class PaddedLabel: UILabel {
    var padding = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
    var useFullyRoundedCorners = true  // Makes corners fully rounded (pill shape)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: padding))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + padding.left + padding.right,
                      height: size.height + padding.top + padding.bottom)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if useFullyRoundedCorners {
            layer.cornerRadius = bounds.height / 2
        }
    }
}

// MARK: - Gradient Overlay for Car Image Text Readability

private final class GradientOverlayView: UIView {
    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGradient()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupGradient() {
        // Gradient from transparent at top to semi-dark at bottom
        // This ensures white text is readable even on white car images
        gradientLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.3).cgColor,
            UIColor.black.withAlphaComponent(0.7).cgColor
        ]
        gradientLayer.locations = [0.0, 0.3, 0.7, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        layer.insertSublayer(gradientLayer, at: 0)
        isUserInteractionEnabled = false  // Allow touches to pass through
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
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
        v.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        return v
    }()

    private let stack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 16
        s.alignment = .fill
        s.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
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
        l.text = "insights.analyzingData".localized
        l.font = .systemFont(ofSize: 16, weight: .medium)
        l.textColor = AIONDesign.textSecondary
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Colors (dynamic based on light/dark background)

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
    private var isAnimatingContent = false  // Prevent conflicting animations
    private var hasLoadedInitialContent = false  // Prevent double loading
    private var currentSupplements: [SupplementRecommendation] = []

    // Discovery UI elements (for animation access)
    private var discoveryContainer: UIView?
    private var discoveryMinHeightConstraint: NSLayoutConstraint?
    private var carCardView: UIView?

    // Animators - must be kept as properties to prevent deallocation
    private var typingAnimator: TypingAnimator?
    private var counterAnimator: NumberCounterAnimator?

    // Personal notes
    private var notesTextView: UITextView?
    private var notesPlaceholderLabel: UILabel?

    // Language tracking – triggers auto-refresh when system language changes
    private var lastContentLanguage: AppLanguage?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "insights.title".localized
        view.backgroundColor = bgColor
        view.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute

        setupUI()
        setupRefreshButton()
        setupAnalysisObserver()
        // Note: refreshContent is called in viewWillAppear, not here, to prevent double calling

        // Listen for background color changes
        NotificationCenter.default.addObserver(self, selector: #selector(backgroundColorDidChange), name: .backgroundColorChanged, object: nil)

        // Listen for language changes — auto-refresh when user switches language
        NotificationCenter.default.addObserver(self, selector: #selector(languageDidChange), name: .languageDidChange, object: nil)

        // Analytics: Log screen view
        AnalyticsService.shared.logScreenView(.insights)

        // Keyboard notifications — scroll to text view when keyboard appears
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func backgroundColorDidChange() {
        view.backgroundColor = AIONDesign.background
        navigationController?.navigationBar.barStyle = AIONDesign.navBarStyle
        navigationController?.navigationBar.barTintColor = AIONDesign.background
        navigationController?.navigationBar.backgroundColor = AIONDesign.background
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: textWhite]
    }

    @objc private func languageDidChange() {
        // Language switched — force a fresh Gemini analysis in the new language
        guard lastContentLanguage != nil,
              lastContentLanguage != LocalizationManager.shared.currentLanguage else { return }
        lastContentLanguage = LocalizationManager.shared.currentLanguage

        // Update UI direction & title
        view.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        title = "insights.title".localized

        // Trigger full re-analysis from Gemini via orchestrator
        showLoading()
        AIONAnalysisOrchestrator.shared.refresh { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.refreshContent()
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Initial load only - prevent duplicate calls
        if !hasLoadedInitialContent {
            hasLoadedInitialContent = true
            refreshContent()
        }
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

        // Dismiss keyboard on tap outside text view
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(tapGesture)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
              let curve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else { return }

        let keyboardHeight = keyboardFrame.height - (tabBarController?.tabBar.frame.height ?? 0)
        let contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardHeight, right: 0)

        // Calculate target offset before animating
        var targetOffset: CGPoint?
        if let textView = self.notesTextView {
            let textViewRect = textView.convert(textView.bounds, to: self.scrollView)
            let visibleHeight = self.scrollView.bounds.height - keyboardHeight
            // Position the text view in the upper portion of visible area with padding
            let desiredY = textViewRect.maxY - visibleHeight + 120
            let maxOffset = max(0, self.scrollView.contentSize.height + keyboardHeight - self.scrollView.bounds.height)
            targetOffset = CGPoint(x: 0, y: min(max(0, desiredY), maxOffset))
        }

        UIView.animate(withDuration: duration, delay: 0, options: UIView.AnimationOptions(rawValue: curve << 16)) {
            self.scrollView.contentInset = contentInset
            self.scrollView.scrollIndicatorInsets = contentInset
            if let offset = targetOffset {
                self.scrollView.contentOffset = offset
            }
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
              let curve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else { return }

        UIView.animate(withDuration: duration, delay: 0, options: UIView.AnimationOptions(rawValue: curve << 16)) {
            self.scrollView.contentInset = .zero
            self.scrollView.scrollIndicatorInsets = .zero
        }
    }

    private func setupRefreshButton() {
        // Refresh button on the left side
        let refreshBtn = UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"), style: .plain, target: self, action: #selector(refreshTapped))
        refreshBtn.tintColor = accentCyan
        navigationItem.leftBarButtonItem = refreshBtn

        // Debug button on the right side
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

    /// The dashboard is now embedded in the "Performance" tab (Unified), not in the first tab
    private func unifiedPerformanceVC() -> UnifiedTrendsActivityViewController? {
        guard let tabs = tabBarController?.viewControllers, tabs.count > 1,
              let nav = tabs[1] as? UINavigationController,
              let unified = nav.viewControllers.first as? UnifiedTrendsActivityViewController else { return nil }
        return unified
    }

    private func embeddedHealthDashboard() -> HealthDashboardViewController? {
        unifiedPerformanceVC()?.healthDashboardViewController
    }

    // MARK: - Actions

    @objc private func insightsCardInfoTapped(_ sender: CardInfoButton) {
        let alert = UIAlertController(title: "dashboard.explanation".localized, message: sender.explanation, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "understand".localized, style: .default))
        present(alert, animated: true)
    }

    @objc private func refreshTapped() {
        // Always allow refresh — triggers fresh Gemini call via orchestrator
        showLoading()
        AIONAnalysisOrchestrator.shared.refresh { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.refreshContent()
            }
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

        // Track current language so we can detect changes later
        lastContentLanguage = LocalizationManager.shared.currentLanguage

        // Prevent conflicting animations - if an animation is already running, defer the refresh
        guard !isAnimatingContent else { return }

        // If we're in the middle of a discovery flow - don't delete
        if isShowingDiscoveryFlow {
            // Check if analysis has completed
            if let insights = GeminiResultStore.loadRawAnalysis(), !insights.isEmpty {
                // Results found! If still loading - transition to reveal
                // (this is handled in checkForResultsAndReveal)
            }
            return
        }

        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        discoveryContainer = nil
        carCardView = nil

        // Check: if the user hasn't discovered yet - show Discovery Flow (even if there's cache)
        let hasDiscovered = UserDefaults.standard.bool(forKey: "AION.HasDiscoveredCar")
        if !hasDiscovered {
            addFirstTimeDiscoveryExperience()
            return
        }

        // Early check: if there's new data - check if the car changed before displaying UI
        if let rawAnalysis = GeminiResultStore.loadRawAnalysis(), !rawAnalysis.isEmpty {
            let parsed = CarAnalysisParser.parse(rawAnalysis)
            let cleanedGeminiCar = cleanCarName(parsed.carModel)
            let invalidWords = [
                "strain", "training", "score", "wiki", "generation", "first", "second", "third",
                "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth",
                "model year", "version", "series"
            ]
            let lowerCar = cleanedGeminiCar.lowercased()
            let containsInvalidWord = invalidWords.contains { lowerCar.contains($0) }
            let isValidGeminiCar = !cleanedGeminiCar.isEmpty && !containsInvalidWord && cleanedGeminiCar.count > 3 && cleanedGeminiCar.count < 40

            if isValidGeminiCar {
                // Check if the car changed - this will determine hasPendingCarReveal
                AnalysisCache.checkAndSetCarChange(
                    newCarName: cleanedGeminiCar,
                    newWikiName: parsed.carWikiName,
                    newExplanation: parsed.carExplanation
                )
            }
        }

        // Check: if there's a new car pending reveal - show Car Upgrade Reveal
        if AnalysisCache.hasPendingCarReveal() {
            addCarUpgradeRevealExperience()
            return
        }

        guard let rawAnalysis = GeminiResultStore.loadRawAnalysis(), !rawAnalysis.isEmpty else {
            addEmptyState()
            addPersonalNotesCard()
            return
        }

        let parsed = CarAnalysisParser.parse(rawAnalysis)

        // Build Premium UI
        addHeader()
        addHeroCarCard(parsed: parsed)
        addPersonalNotesCard()
        addPerformanceSection(parsed: parsed)
        addBottlenecksCard(parsed: parsed)
        addOptimizationCard(parsed: parsed)
        addTuneUpCard(parsed: parsed)
        addNutritionButton(parsed: parsed)
        addDirectivesCard(parsed: parsed)
        addSummaryCard(parsed: parsed)
    }

    // MARK: - Personal Notes Card (Apple-style)

    private var notesSaveButton: UIButton?
    private var notesTextContainerView: UIView?

    private func addPersonalNotesCard() {
        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        let card = UIView()
        card.backgroundColor = cardBgColor
        card.layer.cornerRadius = 16
        card.layer.cornerCurve = .continuous
        // Subtle shadow for depth
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.18
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 8
        card.translatesAutoresizingMaskIntoConstraints = false

        let innerStack = UIStackView()
        innerStack.axis = .vertical
        innerStack.spacing = 14
        innerStack.alignment = .fill
        innerStack.translatesAutoresizingMaskIntoConstraints = false
        innerStack.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        card.addSubview(innerStack)

        // ── Header row: icon circle + title + save button ──
        let headerRow = UIStackView()
        headerRow.axis = .horizontal
        headerRow.spacing = 10
        headerRow.alignment = .center
        headerRow.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute

        // Icon with tinted circle background
        let iconCircle = UIView()
        iconCircle.backgroundColor = AIONDesign.accentPrimary.withAlphaComponent(0.12)
        iconCircle.layer.cornerRadius = 15
        iconCircle.layer.cornerCurve = .continuous
        iconCircle.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconCircle.widthAnchor.constraint(equalToConstant: 30),
            iconCircle.heightAnchor.constraint(equalToConstant: 30),
        ])

        let iconView = UIImageView()
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        iconView.image = UIImage(systemName: "square.and.pencil", withConfiguration: iconConfig)
        iconView.tintColor = AIONDesign.accentPrimary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconCircle.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 15),
            iconView.heightAnchor.constraint(equalToConstant: 15),
        ])

        let titleLabel = UILabel()
        titleLabel.text = "insights.personalNotes".localized
        if let descriptor = UIFont.systemFont(ofSize: 15, weight: .semibold).fontDescriptor.withDesign(.rounded) {
            titleLabel.font = UIFont(descriptor: descriptor, size: 15)
        } else {
            titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        }
        titleLabel.textColor = textWhite
        titleLabel.textAlignment = LocalizationManager.shared.textAlignment

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // Save button — pill style, appears when user types
        let saveBtn = UIButton(type: .system)
        saveBtn.setTitle("insights.notesSave".localized, for: .normal)
        if let descriptor = UIFont.systemFont(ofSize: 13, weight: .semibold).fontDescriptor.withDesign(.rounded) {
            saveBtn.titleLabel?.font = UIFont(descriptor: descriptor, size: 13)
        } else {
            saveBtn.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        }
        saveBtn.setTitleColor(.white, for: .normal)
        saveBtn.backgroundColor = AIONDesign.accentPrimary
        saveBtn.layer.cornerRadius = 13
        saveBtn.layer.cornerCurve = .continuous
        saveBtn.contentEdgeInsets = UIEdgeInsets(top: 5, left: 14, bottom: 5, right: 14)
        saveBtn.setContentHuggingPriority(.required, for: .horizontal)
        saveBtn.addTarget(self, action: #selector(saveNotesTapped), for: .touchUpInside)
        saveBtn.alpha = 0
        saveBtn.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        self.notesSaveButton = saveBtn

        headerRow.addArrangedSubview(iconCircle)
        headerRow.addArrangedSubview(titleLabel)
        headerRow.addArrangedSubview(spacer)
        headerRow.addArrangedSubview(saveBtn)
        innerStack.addArrangedSubview(headerRow)

        // ── Text input area with elevated background ──
        let textContainer = UIView()
        textContainer.backgroundColor = AIONDesign.surfaceElevated
        textContainer.layer.cornerRadius = 12
        textContainer.layer.cornerCurve = .continuous
        textContainer.layer.borderWidth = 1
        textContainer.layer.borderColor = AIONDesign.textTertiary.withAlphaComponent(0.08).cgColor
        textContainer.translatesAutoresizingMaskIntoConstraints = false
        self.notesTextContainerView = textContainer

        let textView = UITextView()
        textView.backgroundColor = .clear
        if let descriptor = UIFont.systemFont(ofSize: 14.5, weight: .regular).fontDescriptor.withDesign(.rounded) {
            textView.font = UIFont(descriptor: descriptor, size: 14.5)
        } else {
            textView.font = .systemFont(ofSize: 14.5, weight: .regular)
        }
        textView.textColor = textWhite
        textView.textAlignment = LocalizationManager.shared.textAlignment
        textView.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.delegate = self
        textView.keyboardDismissMode = .interactive
        self.notesTextView = textView

        // Placeholder
        let placeholder = UILabel()
        placeholder.text = "insights.notesPlaceholder".localized
        if let descriptor = UIFont.systemFont(ofSize: 14.5, weight: .regular).fontDescriptor.withDesign(.rounded) {
            placeholder.font = UIFont(descriptor: descriptor, size: 14.5)
        } else {
            placeholder.font = .systemFont(ofSize: 14.5, weight: .regular)
        }
        placeholder.textColor = AIONDesign.textTertiary
        placeholder.textAlignment = LocalizationManager.shared.textAlignment
        placeholder.numberOfLines = 0
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        self.notesPlaceholderLabel = placeholder

        textContainer.addSubview(textView)
        textContainer.addSubview(placeholder)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: textContainer.topAnchor),
            textView.leadingAnchor.constraint(equalTo: textContainer.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: textContainer.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: textContainer.bottomAnchor),
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),

            placeholder.topAnchor.constraint(equalTo: textContainer.topAnchor, constant: 12),
            placeholder.leadingAnchor.constraint(equalTo: textContainer.leadingAnchor, constant: 15),
            placeholder.trailingAnchor.constraint(equalTo: textContainer.trailingAnchor, constant: -15),
        ])

        innerStack.addArrangedSubview(textContainer)

        // Load existing notes
        if let notes = AnalysisCache.loadUserNotes(), !notes.isEmpty {
            textView.text = notes
            placeholder.isHidden = true
            // Show save button if there's existing text
            saveBtn.alpha = 1
            saveBtn.transform = .identity
        }

        NSLayoutConstraint.activate([
            innerStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            innerStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            innerStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            innerStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        stack.addArrangedSubview(card)
    }

    @objc private func saveNotesTapped() {
        let text = notesTextView?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        AnalysisCache.saveUserNotes(text)

        // Dismiss keyboard
        notesTextView?.resignFirstResponder()

        // Haptic
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        guard let btn = notesSaveButton else { return }
        let originalTitle = btn.title(for: .normal)
        let originalBg = btn.backgroundColor

        // Animate to success state
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            btn.backgroundColor = AIONDesign.accentSuccess
            btn.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
        }

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        let checkImage = UIImage(systemName: "checkmark", withConfiguration: iconConfig)
        btn.setTitle(nil, for: .normal)
        btn.setImage(checkImage, for: .normal)
        btn.tintColor = .white

        // Bounce back after a moment
        UIView.animate(withDuration: 0.3, delay: 1.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3) {
            btn.transform = .identity
            btn.backgroundColor = originalBg
        } completion: { _ in
            btn.setImage(nil, for: .normal)
            btn.setTitle(originalTitle, for: .normal)
            btn.tintColor = .white
        }
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
        title.text = "insights.aionInsights".localized
        title.font = .systemFont(ofSize: 22, weight: .bold)
        title.textColor = textWhite

        let subtitle = UILabel()
        subtitle.text = "insights.biometricAnalysis".localized
        subtitle.font = .systemFont(ofSize: 13, weight: .regular)
        subtitle.textColor = textGray

        let dateLabel = UILabel()
        if let d = GeminiResultStore.load()?.date {
            let f = DateFormatter()
            f.locale = Locale(identifier: LocalizationManager.shared.currentLanguage == .hebrew ? "he_IL" : "en_US")
            f.dateFormat = LocalizationManager.shared.currentLanguage == .hebrew ? "d בMMMM yyyy" : "MMMM d, yyyy"
            dateLabel.text = "\("insights.lastUpdate".localized): \(f.string(from: d))"
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
    // Get score from Gemini (single source of truth)
    let score: Int = GeminiResultStore.loadCarScore() ?? GeminiResultStore.loadHealthScore() ?? 0

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
        // Gemini returned a valid car - save it (change detection already done in refreshContent)
        carName = cleanedGeminiCar
        wikiName = parsed.carWikiName
        explanation = parsed.carExplanation
        // Note: checkAndSetCarChange is now called in refreshContent() before we get here
        // Here we just save the car (if no pending reveal was triggered)
        if !AnalysisCache.hasPendingCarReveal() {
            AnalysisCache.saveSelectedCar(name: carName, wikiName: wikiName, explanation: explanation)
        }

        // Update car name from Gemini to Firestore (leaderboard and friends)
        let tier = CarTierEngine.tierForScore(score)
        LeaderboardFirestoreSync.syncScore(score: score, tier: tier, geminiCarName: carName)
    } else if let savedCar = AnalysisCache.loadSelectedCar() {
        // Gemini didn't return valid car - use saved car
        carName = savedCar.name
        wikiName = savedCar.wikiName
        explanation = savedCar.explanation
    } else {
        // No car at all - show placeholder
        carName = "insights.waitingForAnalysis".localized
        wikiName = ""
        explanation = "insights.carSelectedAfter".localized
    }

    // Determine status based on score - use score.description for consistency with Watch
    let scoreLevel = RangeLevel.from(score: Double(score))
    let status = "score.description.\(scoreLevel.rawValue)".localized

    // NOTE: Do NOT save to mainScore here! This score is the Gemini 90-day average.
    // mainScore should only be saved from InsightsDashboardViewController (daily score).
    // AnalysisCache.saveMainScore is intentionally NOT called here.

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
    let dailyActivity = AnalysisCache.loadDailyActivity()
    let userName = Auth.auth().currentUser?.displayName ?? ""
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
        hrv: nil,
        sleepHours: nil,
        userName: userName
    )

    // ═══ Glass Card with floating car image ═══
    let isRTL = LocalizationManager.shared.currentLanguage.isRTL

    // Wrapper - doesn't clip so car image can overflow
    let wrapper = UIView()
    wrapper.clipsToBounds = false
    wrapper.translatesAutoresizingMaskIntoConstraints = false

    // Glass card
    let card = UIView()
    card.layer.cornerRadius = 20
    card.clipsToBounds = true
    card.translatesAutoresizingMaskIntoConstraints = false

    self.discoveryContainer = wrapper
    self.carCardView = card

    // Blur background
    let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
    let blurView = UIVisualEffectView(effect: blurEffect)
    blurView.translatesAutoresizingMaskIntoConstraints = false
    card.addSubview(blurView)

    // Subtle border
    card.layer.borderWidth = 1
    card.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor

    // ── Car name ──
    let carNameLabel = UILabel()
    carNameLabel.text = carName
    carNameLabel.font = .systemFont(ofSize: 22, weight: .heavy)
    carNameLabel.textColor = .white
    carNameLabel.textAlignment = .center
    carNameLabel.numberOfLines = 1
    carNameLabel.adjustsFontSizeToFitWidth = true
    carNameLabel.minimumScaleFactor = 0.7
    carNameLabel.translatesAutoresizingMaskIntoConstraints = false

    // ── Score + badge row (centered) ──
    let scoreLabel = UILabel()
    scoreLabel.text = "\(score)"
    scoreLabel.font = .monospacedDigitSystemFont(ofSize: 44, weight: .black)
    scoreLabel.textColor = tierColor
    scoreLabel.translatesAutoresizingMaskIntoConstraints = false

    let maxScoreLabel = UILabel()
    maxScoreLabel.text = "/100"
    maxScoreLabel.font = .systemFont(ofSize: 18, weight: .medium)
    maxScoreLabel.textColor = UIColor.white.withAlphaComponent(0.4)
    maxScoreLabel.translatesAutoresizingMaskIntoConstraints = false

    let statusBadge = PaddedLabel()
    statusBadge.text = status
    statusBadge.font = .systemFont(ofSize: 12, weight: .bold)
    statusBadge.textColor = .white
    statusBadge.backgroundColor = tierColor
    statusBadge.clipsToBounds = true
    statusBadge.translatesAutoresizingMaskIntoConstraints = false

    let scoreRow = UIStackView()
    scoreRow.axis = .horizontal
    scoreRow.alignment = .firstBaseline
    scoreRow.spacing = 2
    scoreRow.translatesAutoresizingMaskIntoConstraints = false
    scoreRow.addArrangedSubview(scoreLabel)
    scoreRow.addArrangedSubview(maxScoreLabel)
    scoreRow.setCustomSpacing(10, after: maxScoreLabel)
    scoreRow.addArrangedSubview(statusBadge)

    // Center the score row
    let scoreCenterStack = UIStackView()
    scoreCenterStack.axis = .horizontal
    scoreCenterStack.alignment = .center
    scoreCenterStack.distribution = .equalCentering
    scoreCenterStack.translatesAutoresizingMaskIntoConstraints = false
    let leftSpacer = UIView(); leftSpacer.translatesAutoresizingMaskIntoConstraints = false
    let rightSpacer = UIView(); rightSpacer.translatesAutoresizingMaskIntoConstraints = false
    scoreCenterStack.addArrangedSubview(leftSpacer)
    scoreCenterStack.addArrangedSubview(scoreRow)
    scoreCenterStack.addArrangedSubview(rightSpacer)
    leftSpacer.widthAnchor.constraint(equalTo: rightSpacer.widthAnchor).isActive = true

    // ── Progress bar ──
    let progressBar = AnimatedProgressBar()
    progressBar.progressColor = tierColor
    progressBar.translatesAutoresizingMaskIntoConstraints = false

    // ── Explanation ──
    let rawExplanation = explanation.isEmpty ? "insights.carSelectedBased".localized : explanation
    let explanationText = cleanExplanationText(rawExplanation, carName: carName)

    let explanationLabel = UILabel()
    explanationLabel.text = explanationText
    explanationLabel.font = .systemFont(ofSize: 15, weight: .regular)
    explanationLabel.textColor = UIColor.white.withAlphaComponent(0.85)
    explanationLabel.textAlignment = .center
    explanationLabel.numberOfLines = 0
    explanationLabel.lineBreakMode = .byWordWrapping
    explanationLabel.translatesAutoresizingMaskIntoConstraints = false

    // ── Action button ──
    let refreshButton = createActionButton(title: "🔄 " + "insights.checkAgain".localized, action: #selector(rediscoverTapped))
    refreshButton.translatesAutoresizingMaskIntoConstraints = false

    // ── Content stack (inside glass card) ──
    let contentStack = UIStackView()
    contentStack.axis = .vertical
    contentStack.spacing = 6
    contentStack.alignment = .fill
    contentStack.translatesAutoresizingMaskIntoConstraints = false

    contentStack.addArrangedSubview(carNameLabel)
    contentStack.addArrangedSubview(scoreCenterStack)
    contentStack.addArrangedSubview(progressBar)
    contentStack.setCustomSpacing(10, after: progressBar)
    contentStack.addArrangedSubview(explanationLabel)
    contentStack.setCustomSpacing(12, after: explanationLabel)
    contentStack.addArrangedSubview(refreshButton)

    card.addSubview(contentStack)

    // ── Car image (floating, overlaps card top) ──
    let carImageView = UIImageView()
    carImageView.contentMode = .scaleAspectFit
    carImageView.clipsToBounds = false
    carImageView.backgroundColor = .clear
    carImageView.translatesAutoresizingMaskIntoConstraints = false

    // Add subtle drop shadow to the car image
    carImageView.layer.shadowColor = UIColor.black.cgColor
    carImageView.layer.shadowOffset = CGSize(width: 0, height: 8)
    carImageView.layer.shadowOpacity = 0.5
    carImageView.layer.shadowRadius = 16

    print("🚗 [CarImage] wikiName = '\(wikiName)', carName = '\(carName)'")
    if !wikiName.isEmpty {
        fetchCarImageFromWikipedia(carName: wikiName, into: carImageView, fallbackEmoji: "")
    } else if !carName.isEmpty && carName != "insights.waitingForAnalysis".localized {
        fetchCarImageFromWikipedia(carName: carName, into: carImageView, fallbackEmoji: "")
    }

    // ── Assemble ──
    wrapper.addSubview(card)
    wrapper.addSubview(carImageView)  // On top of card, can overflow

    NSLayoutConstraint.activate([
        // Card inside wrapper - leave space at top for floating car
        card.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 50),
        card.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
        card.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
        card.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),

        // Blur fills card
        blurView.topAnchor.constraint(equalTo: card.topAnchor),
        blurView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
        blurView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
        blurView.bottomAnchor.constraint(equalTo: card.bottomAnchor),

        // Content inside card
        contentStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
        contentStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
        contentStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
        contentStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),

        progressBar.heightAnchor.constraint(equalToConstant: 5),
        refreshButton.heightAnchor.constraint(equalToConstant: 38),

        // Floating car image - centered at top, overlapping the card
        carImageView.centerXAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -90),
        carImageView.bottomAnchor.constraint(equalTo: card.topAnchor, constant: 30),
        carImageView.widthAnchor.constraint(equalToConstant: 160),
        carImageView.heightAnchor.constraint(equalToConstant: 100),
    ])

    // Update progress bar
    DispatchQueue.main.async {
        progressBar.setProgress(CGFloat(score) / 100.0)
    }

    stack.addArrangedSubview(wrapper)
}


    // MARK: - Car Name Cleaning

    private func cleanCarName(_ raw: String) -> String {
        var name = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // If Gemini returned a sentence ("You are currently like ...")
        if let range = name.range(of: "כמו") {
            name = String(name[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }

        // Remove tags and remnants
        name = name
            .replacingOccurrences(of: "[CAR_WIKI:", with: "")
            .replacingOccurrences(of: "[CAR_WIKI]", with: "")
            .replacingOccurrences(of: "CAR_WIKI:", with: "")
            .replacingOccurrences(of: "CAR_WIKI", with: "")
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove parentheses and their content
        if let parenIndex = name.firstIndex(of: "(") {
            name = String(name[..<parenIndex]).trimmingCharacters(in: .whitespaces)
        }

        // Remove trailing period / colon
        while name.hasSuffix(".") || name.hasSuffix(":") {
            name = String(name.dropLast()).trimmingCharacters(in: .whitespaces)
        }

        return name
    }

    // MARK: - Explanation Cleaning

    private func cleanExplanationText(_ raw: String, carName: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1) Remove everything in parentheses (Mk7 etc.) - supports multiple pairs
        while let open = s.firstIndex(of: "("),
              let close = s[open...].firstIndex(of: ")") {
            s.removeSubrange(open...close)
        }

        // 2) Clean up spaces/punctuation after removing parentheses
        while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }
        s = s.replacingOccurrences(of: " .", with: ".")
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)

        // Helper: case-insensitive replace
        func replaceCI(_ text: String, _ pattern: String, with replacement: String) -> String {
            return text.replacingOccurrences(of: pattern, with: replacement, options: [.caseInsensitive], range: nil)
        }

        // 3) If the explanation starts with the car name - remove it (since there's already a title)
        // (case-insensitive)
        let prefixTrimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if prefixTrimmed.lowercased().hasPrefix(carName.lowercased()) {
            s = String(prefixTrimmed.dropFirst(carName.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            if let first = s.first, [".", ":", "–", "-"].contains(first) {
                s = String(s.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // 4) Remove consecutive duplicates of car name in text (including "X. X", "X X", and line breaks)
        for _ in 0..<5 {
            s = replaceCI(s, "\(carName). \(carName)", with: "\(carName).")
            s = replaceCI(s, "\(carName) \(carName)", with: "\(carName)")
            s = replaceCI(s, "\(carName).\n\(carName)", with: "\(carName).")
            s = replaceCI(s, "\(carName)\n\(carName)", with: "\(carName)")
        }

        // 5) Filter unwanted lines (line that is only a car name / sub-model like "Golf Mk7")
        let lines = s
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let carLower = carName.lowercased()

        let filtered = lines.filter { line in
            let l = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let low = l.lowercased()

            // Line that is only the car name (with/without punctuation)
            let normalized = low
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ":", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if normalized == carLower { return false }
            if normalized.hasPrefix(carLower) && normalized.count <= carLower.count + 2 { return false }

            // Remove "sub-model" lines like Golf Mk7 / Golf MK8 / GTI Mk7 etc.
            // (if there's mk + number/letter)
            if low.contains("mk") {
                // Short line containing mk is considered a "model tag" -> discard
                if l.count <= 18 { return false }
            }

            return true
        }

        // 6) Remove duplicate lines (case-insensitive)
        var seen = Set<String>()
        let unique = filtered.filter { line in
            let key = line.lowercased()
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }

        // 7) Final cleanup: if duplicate "X. X" remains within a line (case-insensitive)
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
            score = 0 // No data = score 0 (will show "--")
        }

        return max(0, min(100, Int(score)))
    }

    private func getStatusInfo(score: Int) -> (text: String, color: UIColor, emoji: String) {
        switch score {
        case 80...100:
            return ("insights.greatCondition".localized, accentGreen, "🏎️")
        case 65..<80:
            return ("insights.goodCondition".localized, accentCyan, "🚙")
        case 50..<65:
            return ("insights.mediumCondition".localized, accentOrange, "🚗")
        case 35..<50:
            return ("insights.needsCare".localized, accentOrange, "🚕")
        default:
            return ("insights.requiresAttention".localized, accentRed, "🛻")
        }
    }

    // MARK: - Car Image Loading via Wikipedia API

    private func fetchCarImageFromWikipedia(carName: String, into imageView: UIImageView, fallbackEmoji: String) {
        print("🚗 [CarImage] Starting fetch for: '\(carName)'")

        // First, check if we have a cached image for this car
        if let cachedImage = WidgetDataManager.shared.loadCachedCarImage(forWikiName: carName) {
            print("🚗 [CarImage] ⚡ Using cached image for '\(carName)'")
            DispatchQueue.main.async {
                imageView.image = cachedImage
                imageView.contentMode = .scaleAspectFill
                imageView.backgroundColor = .clear
            }
            return
        }

        // No cache - fetch from Wikipedia
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

        print("🚗 [CarImage] Candidates: \(candidates)")
        tryWikipediaCandidates(candidates: candidates, index: 0, into: imageView, fallbackEmoji: fallbackEmoji, originalWikiName: carName)
    }

    private func tryWikipediaCandidates(candidates: [String], index: Int, into imageView: UIImageView, fallbackEmoji: String, originalWikiName: String) {
        guard index < candidates.count else {
            print("🚗 [CarImage] ❌ All candidates exhausted, showing fallback")
            DispatchQueue.main.async { [weak self] in
                self?.showFallbackEmoji(in: imageView, emoji: fallbackEmoji)
            }
            return
        }

        let carName = candidates[index]
        let wikiTitle = carName.replacingOccurrences(of: " ", with: "_")
        let apiURL = "https://en.wikipedia.org/api/rest_v1/page/summary/\(wikiTitle)"

        print("🚗 [CarImage] Trying candidate \(index + 1)/\(candidates.count): '\(carName)' -> \(apiURL)")

        guard let url = URL(string: apiURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? apiURL) else {
            print("🚗 [CarImage] ❌ Invalid URL for '\(carName)'")
            tryWikipediaCandidates(candidates: candidates, index: index + 1, into: imageView, fallbackEmoji: fallbackEmoji, originalWikiName: originalWikiName)
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self, weak imageView] data, response, error in
            guard let self = self, let imageView = imageView else { return }

            if let error = error {
                print("🚗 [CarImage] ❌ Network error for '\(carName)': \(error.localizedDescription)")
                self.tryWikipediaCandidates(candidates: candidates, index: index + 1, into: imageView, fallbackEmoji: fallbackEmoji, originalWikiName: originalWikiName)
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("🚗 [CarImage] ❌ Invalid JSON for '\(carName)'")
                self.tryWikipediaCandidates(candidates: candidates, index: index + 1, into: imageView, fallbackEmoji: fallbackEmoji, originalWikiName: originalWikiName)
                return
            }

            // Extract thumbnail URL from response
            if let thumbnail = json["thumbnail"] as? [String: Any],
               let source = thumbnail["source"] as? String {
                // Change thumbnail size to 640px for better quality
                let thumbURL = source.replacingOccurrences(of: "/320px-", with: "/640px-")
                    .replacingOccurrences(of: "/330px-", with: "/640px-")

                print("🚗 [CarImage] ✅ Found thumbnail for '\(carName)': \(thumbURL)")

                guard let imageURL = URL(string: thumbURL) else {
                    print("🚗 [CarImage] ❌ Invalid image URL")
                    self.tryWikipediaCandidates(candidates: candidates, index: index + 1, into: imageView, fallbackEmoji: fallbackEmoji, originalWikiName: originalWikiName)
                    return
                }

                // Download the actual image with proper request configuration
                var imageRequest = URLRequest(url: imageURL)
                imageRequest.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
                imageRequest.setValue("image/webp,image/apng,image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
                imageRequest.setValue("en-US,en;q=0.9,he;q=0.8", forHTTPHeaderField: "Accept-Language")
                imageRequest.cachePolicy = .reloadIgnoringLocalCacheData

                URLSession.shared.dataTask(with: imageRequest) { [weak self, weak imageView] imgData, response, imgError in
                    // Log response details for debugging
                    if let httpResponse = response as? HTTPURLResponse {
                        print("🚗 [CarImage] HTTP Status: \(httpResponse.statusCode), Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "none")")
                        if httpResponse.statusCode != 200 {
                            print("🚗 [CarImage] ⚠️ Non-200 status code, headers: \(httpResponse.allHeaderFields)")
                        }
                    }

                    if let imgError = imgError {
                        print("🚗 [CarImage] ⚠️ Image download error: \(imgError.localizedDescription), code: \((imgError as NSError).code)")
                    }

                    if let imgData = imgData, !imgData.isEmpty, let image = UIImage(data: imgData) {
                        print("🚗 [CarImage] ✅ Image loaded successfully for '\(carName)' (size: \(imgData.count) bytes), removing background...")
                        WidgetDataManager.shared.removeBackground(from: image) { [weak self, weak imageView] processedImage in
                            DispatchQueue.main.async {
                                guard let imageView = imageView else { return }
                                imageView.image = processedImage
                                imageView.contentMode = .scaleAspectFill
                                imageView.backgroundColor = .clear
                            }
                            WidgetDataManager.shared.saveCarImage(processedImage)
                            WidgetDataManager.shared.cacheCarImage(processedImage, forWikiName: originalWikiName)
                        }
                    } else {
                        print("🚗 [CarImage] ❌ Failed to load image data: \(imgError?.localizedDescription ?? "no error"), data size: \(imgData?.count ?? 0)")
                        // Try original thumbnail URL as fallback (without size modification)
                        if let originalURL = URL(string: source) {
                            print("🚗 [CarImage] 🔄 Retrying with original URL: \(source)")
                            var retryRequest = URLRequest(url: originalURL)
                            retryRequest.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
                            retryRequest.setValue("image/webp,image/apng,image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
                            retryRequest.cachePolicy = .reloadIgnoringLocalCacheData

                            URLSession.shared.dataTask(with: retryRequest) { [weak self, weak imageView] retryData, _, _ in
                                if let retryData = retryData, !retryData.isEmpty, let image = UIImage(data: retryData) {
                                    print("🚗 [CarImage] ✅ Image loaded with original URL for '\(carName)', removing background...")
                                    WidgetDataManager.shared.removeBackground(from: image) { [weak self, weak imageView] processedImage in
                                        DispatchQueue.main.async {
                                            guard let imageView = imageView else { return }
                                            imageView.image = processedImage
                                            imageView.contentMode = .scaleAspectFill
                                            imageView.backgroundColor = .clear
                                        }
                                        WidgetDataManager.shared.saveCarImage(processedImage)
                                        WidgetDataManager.shared.cacheCarImage(processedImage, forWikiName: originalWikiName)
                                    }
                                } else {
                                    DispatchQueue.main.async {
                                        guard let self = self, let imageView = imageView else { return }
                                        print("🚗 [CarImage] ❌ Retry also failed")
                                        self.showFallbackEmoji(in: imageView, emoji: fallbackEmoji)
                                    }
                                }
                            }.resume()
                        } else {
                            DispatchQueue.main.async { [weak self, weak imageView] in
                                guard let self = self, let imageView = imageView else { return }
                                self.showFallbackEmoji(in: imageView, emoji: fallbackEmoji)
                            }
                        }
                    }
                }.resume()
            } else {
                print("🚗 [CarImage] ❌ No thumbnail in response for '\(carName)'")
                self.tryWikipediaCandidates(candidates: candidates, index: index + 1, into: imageView, fallbackEmoji: fallbackEmoji, originalWikiName: originalWikiName)
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
        let header = makeSectionHeader("insights.weeklyData".localized, icon: nil, color: accentCyan)
        stack.addArrangedSubview(header)

        // Grid container
        let gridStack = UIStackView()
        gridStack.axis = .vertical
        gridStack.spacing = 12
        gridStack.translatesAutoresizingMaskIntoConstraints = false

        // Load scores from Gemini result (single source of truth)
        let geminiScores = GeminiResultStore.load()?.scores

        // Format sleep value
        let sleepValue: String
        if let s = geminiScores?.sleepScore {
            sleepValue = "\(s)"
        } else {
            sleepValue = "--"
        }

        // Format readiness value
        let readinessValue: String
        if let r = geminiScores?.readinessScore {
            readinessValue = "\(r)"
        } else {
            readinessValue = "--"
        }

        // Format strain value
        let strainValue: String
        if let st = geminiScores?.trainingStrain {
            strainValue = String(format: "%.1f", st)
        } else {
            strainValue = "--"
        }

        // Format HRV value (now nervousSystemBalance from Gemini)
        let hrvValue: String
        if let h = geminiScores?.nervousSystemBalance {
            hrvValue = "\(h)"
        } else {
            hrvValue = "--"
        }

        // Row 1
        let row1 = UIStackView()
        row1.axis = .horizontal
        row1.spacing = 12
        row1.distribution = .fillEqually

        let sleepBox = makeDataBox(
            icon: "bed.double.fill",
            title: "insights.sleep".localized,
            value: sleepValue,
            color: accentCyan,
            explanation: "insights.sleepExplanation".localized
        )
        let readinessBox = makeDataBox(
            icon: "bolt.fill",
            title: "insights.readiness".localized,
            value: readinessValue,
            color: accentCyan,
            explanation: "insights.readinessExplanation".localized
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
            title: "insights.strain".localized,
            value: strainValue,
            color: accentOrange,
            explanation: "insights.strainExplanation".localized
        )
        let hrvBox = makeDataBox(
            icon: "waveform.path.ecg",
            title: "HRV",
            value: hrvValue,
            color: accentCyan,
            explanation: "insights.hrvExplanation".localized
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
        let stepsValue = "insights.loadingValue".localized
        let exerciseValue = "insights.loadingValue".localized

        let stepsBox = makeDataBox(
            icon: "figure.walk",
            title: "insights.steps".localized,
            value: stepsValue,
            color: accentOrange,
            explanation: "insights.stepsExplanation".localized
        )

        let exerciseBox = makeDataBox(
            icon: "flame.fill",
            title: "insights.exerciseMinutes".localized,
            value: exerciseValue,
            color: accentGreen,
            explanation: "insights.exerciseExplanation".localized
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
                    valueLabel.text = String(format: "%.0f min", totalExercise)
                } else {
                    valueLabel.text = "-- min"
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
        infoBtn.addTarget(self, action: #selector(insightsCardInfoTapped(_:)), for: .touchUpInside)

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

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        // Common constraints
        NSLayoutConstraint.activate([
            box.heightAnchor.constraint(equalToConstant: 100),

            infoBtn.topAnchor.constraint(equalTo: box.topAnchor, constant: 12),
            iconView.topAnchor.constraint(equalTo: box.topAnchor, constant: 12),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
            titleLabel.centerXAnchor.constraint(equalTo: box.centerXAnchor),

            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            valueLabel.centerXAnchor.constraint(equalTo: box.centerXAnchor),
        ])

        // RTL/LTR specific constraints for info button and icon
        // RTL (Hebrew): info on LEFT, icon on RIGHT. LTR (English): info on RIGHT, icon on LEFT
        if isRTL {
            NSLayoutConstraint.activate([
                infoBtn.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
                iconView.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
            ])
        } else {
            NSLayoutConstraint.activate([
                infoBtn.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
                iconView.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
            ])
        }

        return box
    }

    // MARK: - Performance Section (Expandable Cards)

    private func addPerformanceSection(parsed: CarAnalysisResponse) {
        let hasContent = !parsed.engine.isEmpty || !parsed.transmission.isEmpty ||
                         !parsed.suspension.isEmpty || !parsed.fuelEfficiency.isEmpty ||
                         !parsed.electronics.isEmpty

        guard hasContent else { return }

        let header = makeSectionHeader("insights.aiInsights".localized, icon: nil, color: accentCyan)
        stack.addArrangedSubview(header)

        let items: [(emoji: String, title: String, content: String, color: UIColor)] = [
            ("🔥", "insights.engine".localized, parsed.engine, accentOrange),
            ("⚙️", "insights.transmission".localized, parsed.transmission, accentPurple),
            ("🛞", "insights.suspension".localized, parsed.suspension, accentGreen),
            ("⛽", "insights.fuelEfficiency".localized, parsed.fuelEfficiency, accentCyan),
            ("🧠", "insights.electronics".localized, parsed.electronics, accentBlue),
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
        titleLabel.textAlignment = LocalizationManager.shared.textAlignment
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Content - using UITextView for proper RTL text wrapping
        let contentTextView = UITextView()
        contentTextView.text = cleanDisplayText(content)
        contentTextView.font = .systemFont(ofSize: 14, weight: .regular)
        contentTextView.textColor = textWhite
        contentTextView.textAlignment = LocalizationManager.shared.textAlignment
        contentTextView.backgroundColor = .clear
        contentTextView.isEditable = false
        contentTextView.isScrollEnabled = false
        contentTextView.textContainerInset = .zero
        contentTextView.textContainer.lineFragmentPadding = 0
        contentTextView.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        contentTextView.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(emojiLabel)
        card.addSubview(titleLabel)
        card.addSubview(contentTextView)

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        NSLayoutConstraint.activate([
            emojiLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),

            titleLabel.centerYAnchor.constraint(equalTo: emojiLabel.centerYAnchor),

            contentTextView.topAnchor.constraint(equalTo: emojiLabel.bottomAnchor, constant: 12),
            contentTextView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            contentTextView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            contentTextView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        // Position emoji and title based on language direction
        if isRTL {
            emojiLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16).isActive = true
            titleLabel.trailingAnchor.constraint(equalTo: emojiLabel.leadingAnchor, constant: -8).isActive = true
        } else {
            emojiLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16).isActive = true
            titleLabel.leadingAnchor.constraint(equalTo: emojiLabel.trailingAnchor, constant: 8).isActive = true
        }

        return card
    }

    /// Cleans text from unnecessary characters (colon at start, asterisks at end, etc.)
    private func cleanDisplayText(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove ":" or ": " from the start of text
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

        // Remove "*" from the end of text
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
        title.text = "insights.whatLimitsPerformance".localized
        title.font = .systemFont(ofSize: 16, weight: .bold)
        title.textColor = accentOrange
        title.textAlignment = LocalizationManager.shared.textAlignment
        title.translatesAutoresizingMaskIntoConstraints = false

        titleContainer.addSubview(icon)
        titleContainer.addSubview(title)

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        NSLayoutConstraint.activate([
            icon.centerYAnchor.constraint(equalTo: titleContainer.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),
            title.centerYAnchor.constraint(equalTo: titleContainer.centerYAnchor),
            titleContainer.heightAnchor.constraint(equalToConstant: 24),
        ])

        // Position icon and title based on language direction
        if isRTL {
            icon.trailingAnchor.constraint(equalTo: titleContainer.trailingAnchor).isActive = true
            title.trailingAnchor.constraint(equalTo: icon.leadingAnchor, constant: -8).isActive = true
            title.leadingAnchor.constraint(greaterThanOrEqualTo: titleContainer.leadingAnchor).isActive = true
        } else {
            icon.leadingAnchor.constraint(equalTo: titleContainer.leadingAnchor).isActive = true
            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8).isActive = true
            title.trailingAnchor.constraint(lessThanOrEqualTo: titleContainer.trailingAnchor).isActive = true
        }

        innerStack.addArrangedSubview(titleContainer)

        for item in parsed.bottlenecks {
            // Skip items that are just the question repeated
            if item.contains("What limits performance") { continue }
            let row = makeWarningRow(text: item, color: accentOrange, iconName: "exclamationmark.triangle.fill")
            innerStack.addArrangedSubview(row)
        }

        for item in parsed.warningSignals {
            // Skip items that are just the question repeated
            if item.contains("What limits performance") { continue }
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
        row.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute

        let bullet = UILabel()
        bullet.text = "•"
        bullet.font = .systemFont(ofSize: 18, weight: .bold)
        bullet.textColor = color
        bullet.setContentHuggingPriority(.required, for: .horizontal)

        let textView = UITextView()
        textView.text = cleanDisplayText(text)
        textView.font = .systemFont(ofSize: 14, weight: .regular)
        textView.textColor = textWhite
        textView.textAlignment = LocalizationManager.shared.textAlignment
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute

        row.addArrangedSubview(bullet)
        row.addArrangedSubview(textView)

        return row
    }

    // MARK: - Optimization Card

    private func addOptimizationCard(parsed: CarAnalysisResponse) {
        guard !parsed.upgrades.isEmpty || !parsed.skippedMaintenance.isEmpty || !parsed.stopImmediately.isEmpty else { return }

        let header = makeSectionHeader("insights.optimizationPlan".localized, icon: "wrench.and.screwdriver.fill", color: accentGreen)
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
            let subHeader = makeSubHeader("insights.recommendedUpgrades".localized, color: accentGreen)
            innerStack.addArrangedSubview(subHeader)
            for item in parsed.upgrades {
                let row = makeCheckRow(text: item, color: accentGreen)
                innerStack.addArrangedSubview(row)
            }
        }

        if !parsed.skippedMaintenance.isEmpty {
            let subHeader = makeSubHeader("insights.skippedMaintenance".localized, color: accentOrange)
            innerStack.addArrangedSubview(subHeader)
            for item in parsed.skippedMaintenance {
                let row = makeCheckRow(text: item, color: accentOrange)
                innerStack.addArrangedSubview(row)
            }
        }

        if !parsed.stopImmediately.isEmpty {
            let subHeader = makeSubHeader("insights.stopImmediately".localized, color: accentRed)
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
        row.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute

        let checkIcon = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        checkIcon.tintColor = color
        checkIcon.translatesAutoresizingMaskIntoConstraints = false
        checkIcon.setContentHuggingPriority(.required, for: .horizontal)

        let textView = UITextView()
        textView.text = text
        textView.font = .systemFont(ofSize: 14, weight: .regular)
        textView.textColor = textWhite
        textView.textAlignment = LocalizationManager.shared.textAlignment
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute

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

        let header = makeSectionHeader("insights.tuningPlan".localized, icon: "calendar.badge.clock", color: accentPurple)
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
            let row = makeTuneUpRow(emoji: "🏃", title: "insights.trainingAdjustments".localized, content: parsed.trainingAdjustments)
            innerStack.addArrangedSubview(row)
        }

        if !parsed.recoveryChanges.isEmpty {
            let row = makeTuneUpRow(emoji: "😴", title: "insights.recoveryAndSleep".localized, content: parsed.recoveryChanges)
            innerStack.addArrangedSubview(row)
        }

        if !parsed.habitToAdd.isEmpty {
            let row = makeTuneUpRow(emoji: "➕", title: "insights.habitToAdd".localized, content: parsed.habitToAdd)
            innerStack.addArrangedSubview(row)
        }

        if !parsed.habitToRemove.isEmpty {
            let row = makeTuneUpRow(emoji: "➖", title: "insights.habitToRemove".localized, content: parsed.habitToRemove)
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
        titleLabel.textAlignment = LocalizationManager.shared.textAlignment
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let contentTextView = UITextView()
        contentTextView.text = cleanDisplayText(content)
        contentTextView.font = .systemFont(ofSize: 13, weight: .regular)
        contentTextView.textColor = textGray
        contentTextView.textAlignment = LocalizationManager.shared.textAlignment
        contentTextView.backgroundColor = .clear
        contentTextView.isEditable = false
        contentTextView.isScrollEnabled = false
        contentTextView.textContainerInset = .zero
        contentTextView.textContainer.lineFragmentPadding = 0
        contentTextView.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        contentTextView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(emojiLabel)
        container.addSubview(titleLabel)
        container.addSubview(contentTextView)

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        NSLayoutConstraint.activate([
            emojiLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),

            titleLabel.centerYAnchor.constraint(equalTo: emojiLabel.centerYAnchor),

            contentTextView.topAnchor.constraint(equalTo: emojiLabel.bottomAnchor, constant: 8),
            contentTextView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            contentTextView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            contentTextView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
        ])

        // Position emoji and title based on language direction
        if isRTL {
            emojiLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12).isActive = true
            titleLabel.trailingAnchor.constraint(equalTo: emojiLabel.leadingAnchor, constant: -8).isActive = true
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 12).isActive = true
        } else {
            emojiLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12).isActive = true
            titleLabel.leadingAnchor.constraint(equalTo: emojiLabel.trailingAnchor, constant: 8).isActive = true
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -12).isActive = true
        }

        return container
    }

    // MARK: - Nutrition Button

    private func addNutritionButton(parsed: CarAnalysisResponse) {
        guard !parsed.supplements.isEmpty else { return }

        // Save supplements for screen transition
        currentSupplements = parsed.supplements

        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false

        // Create container with Premium design
        let container = UIView()
        container.backgroundColor = cardBgColor
        container.layer.cornerRadius = 16
        container.layer.borderWidth = 1.5
        container.layer.borderColor = accentGreen.withAlphaComponent(0.4).cgColor
        container.translatesAutoresizingMaskIntoConstraints = false
        container.isUserInteractionEnabled = false

        // Icon
        let iconLabel = UILabel()
        iconLabel.text = "💊"
        iconLabel.font = .systemFont(ofSize: 32)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false

        // Title
        let titleLabel = UILabel()
        titleLabel.text = "insights.nutritionRecommendations".localized
        titleLabel.font = .systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = textWhite
        titleLabel.textAlignment = LocalizationManager.shared.textAlignment
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Description
        let subtitleLabel = UILabel()
        subtitleLabel.text = "insights.recommendedSupplements".localized
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = textGray
        subtitleLabel.textAlignment = LocalizationManager.shared.textAlignment
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Badge with supplement count
        let countBadge = UIView()
        countBadge.backgroundColor = accentGreen.withAlphaComponent(0.2)
        countBadge.layer.cornerRadius = 10
        countBadge.translatesAutoresizingMaskIntoConstraints = false

        let countLabel = UILabel()
        countLabel.text = "\(parsed.supplements.count) \("insights.recommendations".localized)"
        countLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        countLabel.textColor = accentGreen
        countLabel.translatesAutoresizingMaskIntoConstraints = false

        countBadge.addSubview(countLabel)

        // Arrow
        let arrowLabel = UILabel()
        let isRTL = LocalizationManager.shared.currentLanguage.isRTL
        arrowLabel.text = isRTL ? "←" : "→"
        arrowLabel.font = .systemFont(ofSize: 20, weight: .medium)
        arrowLabel.textColor = accentGreen
        arrowLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(iconLabel)
        container.addSubview(titleLabel)
        container.addSubview(subtitleLabel)
        container.addSubview(countBadge)
        container.addSubview(arrowLabel)

        // Common constraints
        NSLayoutConstraint.activate([
            iconLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            countBadge.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 8),
            countBadge.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            countLabel.topAnchor.constraint(equalTo: countBadge.topAnchor, constant: 4),
            countLabel.leadingAnchor.constraint(equalTo: countBadge.leadingAnchor, constant: 10),
            countLabel.trailingAnchor.constraint(equalTo: countBadge.trailingAnchor, constant: -10),
            countLabel.bottomAnchor.constraint(equalTo: countBadge.bottomAnchor, constant: -4),
            arrowLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        // Position based on language direction
        if isRTL {
            NSLayoutConstraint.activate([
                iconLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
                titleLabel.trailingAnchor.constraint(equalTo: iconLabel.leadingAnchor, constant: -12),
                titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: arrowLabel.trailingAnchor, constant: 8),
                subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
                subtitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: arrowLabel.trailingAnchor, constant: 8),
                countBadge.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
                arrowLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            ])
        } else {
            NSLayoutConstraint.activate([
                iconLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
                titleLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 12),
                titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: arrowLabel.leadingAnchor, constant: -8),
                subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
                subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: arrowLabel.leadingAnchor, constant: -8),
                countBadge.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
                arrowLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            ])
        }

        // Add the container to the button
        button.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: button.topAnchor),
            container.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: button.bottomAnchor),
        ])

        button.addTarget(self, action: #selector(openNutritionScreen), for: .touchUpInside)

        stack.addArrangedSubview(button)

        // Minimum height for button
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

        let header = makeSectionHeader("insights.actionDirectives".localized, icon: "checklist", color: accentCyan)
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
        badge.textAlignment = LocalizationManager.shared.textAlignment
        badge.translatesAutoresizingMaskIntoConstraints = false

        let contentTextView = UITextView()
        contentTextView.text = cleanDisplayText(content)
        contentTextView.font = .systemFont(ofSize: 14, weight: .regular)
        contentTextView.textColor = textWhite
        contentTextView.textAlignment = LocalizationManager.shared.textAlignment
        contentTextView.backgroundColor = .clear
        contentTextView.isEditable = false
        contentTextView.isScrollEnabled = false
        contentTextView.textContainerInset = .zero
        contentTextView.textContainer.lineFragmentPadding = 0
        contentTextView.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        contentTextView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(badge)
        container.addSubview(contentTextView)

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        NSLayoutConstraint.activate([
            badge.topAnchor.constraint(equalTo: container.topAnchor),

            contentTextView.topAnchor.constraint(equalTo: badge.bottomAnchor, constant: 6),
            contentTextView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            contentTextView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            contentTextView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        // Position badge based on language direction
        if isRTL {
            badge.trailingAnchor.constraint(equalTo: container.trailingAnchor).isActive = true
        } else {
            badge.leadingAnchor.constraint(equalTo: container.leadingAnchor).isActive = true
        }

        return container
    }

    // MARK: - Summary Card

    private func addSummaryCard(parsed: CarAnalysisResponse) {
        guard !parsed.summary.isEmpty else { return }

        let header = makeSectionHeader("insights.lookingAhead".localized, icon: "crystal.ball", color: accentCyan)
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

    // MARK: - Car Upgrade Reveal Experience (when the car changes)

    private func addCarUpgradeRevealExperience() {
        isShowingDiscoveryFlow = true

        let container = UIView()
        container.backgroundColor = .clear
        container.translatesAutoresizingMaskIntoConstraints = false
        self.discoveryContainer = container

        // Gold-purple background gradient (represents upgrade/change)
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 0.85, green: 0.65, blue: 0.13, alpha: 0.3).cgColor, // gold
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

        // Covered car image with ribbon
        let carImageContainer = UIView()
        carImageContainer.translatesAutoresizingMaskIntoConstraints = false

        // The covered car image (no background)
        let coveredCarImage = UIImageView(image: UIImage(named: "newCarClear"))
        coveredCarImage.contentMode = .scaleAspectFit
        coveredCarImage.translatesAutoresizingMaskIntoConstraints = false
        coveredCarImage.layer.cornerRadius = 16
        coveredCarImage.clipsToBounds = true
        carImageContainer.addSubview(coveredCarImage)

        // Sparkles around
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

        // Title
        let titleLabel = UILabel()
        titleLabel.text = "insights.newCarTitle".localized
        titleLabel.font = .systemFont(ofSize: 26, weight: .bold)
        titleLabel.textColor = textWhite
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Subtitle with previous car
        let subtitleLabel = UILabel()
        if let pending = AnalysisCache.getPendingCar(), !pending.previousName.isEmpty {
            subtitleLabel.text = "\("insights.dataChangedSignificantly".localized)\n\(String(format: "insights.timeToReplace".localized, pending.previousName))"
        } else {
            subtitleLabel.text = "\("insights.dataChangedSignificantly".localized)\n\("insights.timeToDiscover".localized)"
        }
        subtitleLabel.font = .systemFont(ofSize: 15, weight: .regular)
        subtitleLabel.textColor = textGray
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        // CTA button
        let ctaButton = UIButton(type: .system)
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        ctaButton.backgroundColor = UIColor(red: 1.0, green: 0.76, blue: 0.0, alpha: 1.0) // Bright amber/gold
        ctaButton.setTitle("🎁  " + "insights.discoverNewCar".localized, for: .normal)
        ctaButton.setTitleColor(.black, for: .normal)
        ctaButton.titleLabel?.font = .systemFont(ofSize: 20, weight: .heavy)
        ctaButton.layer.cornerRadius = 28
        ctaButton.addTarget(self, action: #selector(revealNewCarTapped), for: .touchUpInside)

        // Glow shadow
        ctaButton.layer.shadowColor = UIColor(red: 1.0, green: 0.76, blue: 0.0, alpha: 1.0).cgColor
        ctaButton.layer.shadowOffset = .zero
        ctaButton.layer.shadowRadius = 16
        ctaButton.layer.shadowOpacity = 0.6

        // Add to container
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
            ctaButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
            ctaButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32),
            ctaButton.heightAnchor.constraint(equalToConstant: 56),
            ctaButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -32),
        ])

        stack.addArrangedSubview(container)

        // Update gradient after layout
        DispatchQueue.main.async {
            gradientLayer.frame = gradientView.bounds
        }

        // Animations - glow on the image
        coveredCarImage.layer.shadowColor = UIColor.white.cgColor
        coveredCarImage.layer.shadowRadius = 20
        coveredCarImage.layer.shadowOpacity = 0.3
        coveredCarImage.layer.shadowOffset = .zero

        ctaButton.startPulseAnimation()

        // Sparkle animation
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

        // Quick reveal animation (data already exists)
        showUpgradeRevealAnimation()
    }

    private func showUpgradeRevealAnimation() {
        guard let container = discoveryContainer else { return }

        // Cancel previous minimum height
        discoveryMinHeightConstraint?.isActive = false
        discoveryMinHeightConstraint = nil

        // Clear the container
        container.subviews.forEach { $0.removeFromSuperview() }

        // Background with particles
        particleBackground = ParticleBackground(in: container)
        particleBackground?.start()

        // Central container
        let centerStack = UIStackView()
        centerStack.axis = .vertical
        centerStack.spacing = 20
        centerStack.alignment = .center
        centerStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(centerStack)

        // Animated icon
        let iconLabel = UILabel()
        iconLabel.text = "🔄"
        iconLabel.font = .systemFont(ofSize: 60)
        iconLabel.textAlignment = .center

        // Status text
        let statusLabel = UILabel()
        statusLabel.text = "insights.preparingNewCar".localized
        statusLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        statusLabel.textColor = textWhite
        statusLabel.textAlignment = .center

        // Progress bar
        let progressBar = AnimatedProgressBar()
        progressBar.progressColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // gold
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

        // Pulse + rotation animation
        iconLabel.startPulseAnimation()
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = CGFloat.pi * 2
        rotation.duration = 1.5
        rotation.repeatCount = .infinity
        iconLabel.layer.add(rotation, forKey: "rotation")

        // Phase 1: Preparing (1.5 seconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            progressBar.animateProgress(to: 0.5, duration: 1.2)
        }

        // Phase 2: Revealing (1 second)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            iconLabel.text = "🎉"
            iconLabel.layer.removeAnimation(forKey: "rotation")
            statusLabel.text = "insights.ready".localized
            progressBar.animateProgress(to: 1.0, duration: 0.5)
        }

        // Reveal! (after 2.5 seconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.showUpgradeRevealResult()
        }
    }

    private func showUpgradeRevealResult() {
        guard let container = discoveryContainer else { return }

        particleBackground?.stop()

        // Load data from pending
        guard let pending = AnalysisCache.getPendingCar() else {
            // If there's no data, just clean up and reload
            AnalysisCache.clearPendingCarReveal()
            refreshContent()
            return
        }

        // Flash effect
        container.flashWhite(duration: 0.3) { [weak self] in
            guard let self = self else { return }

            // Clear the container
            container.subviews.forEach { $0.removeFromSuperview() }

            // Confetti!
            self.confettiEmitter = ConfettiEmitter(in: container)
            self.confettiEmitter?.start()

            // Haptic
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            // Read parsed data from cache
            if let insights = GeminiResultStore.loadRawAnalysis() {
                let parsed = CarAnalysisParser.parse(insights)
                self.buildRevealedCarCard(in: container, parsed: parsed)
            } else {
                // If there are no insights, build a simple card from the available data
                self.buildSimpleRevealCard(in: container, pending: pending)
            }

            // Clear the pending (new car is saved as current)
            AnalysisCache.clearPendingCarReveal()
        }
    }

    private func buildSimpleRevealCard(in container: UIView, pending: (name: String, wikiName: String, explanation: String, previousName: String)) {
        // Simple card if there's no full parsed data
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

        // Animations
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

        // Purple-blue background gradient
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

        // Question mark above the image
        let questionLabel = UILabel()
        questionLabel.text = "❓"
        questionLabel.font = .systemFont(ofSize: 44)
        questionLabel.textAlignment = .center
        questionLabel.translatesAutoresizingMaskIntoConstraints = false

        // Covered car image with ribbon
        let mysteryCarContainer = UIView()
        mysteryCarContainer.translatesAutoresizingMaskIntoConstraints = false

        // The covered car image (no background)
        let coveredCarImage = UIImageView(image: UIImage(named: "newCarClear"))
        coveredCarImage.contentMode = .scaleAspectFit
        coveredCarImage.translatesAutoresizingMaskIntoConstraints = false
        coveredCarImage.layer.cornerRadius = 16
        coveredCarImage.clipsToBounds = true
        mysteryCarContainer.addSubview(coveredCarImage)

        // Title
        let titleLabel = UILabel()
        titleLabel.text = "insights.readyToDiscover".localized
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = textWhite
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Subtitle
        let subtitleLabel = UILabel()
        subtitleLabel.text = "insights.basedOnYourData".localized
        subtitleLabel.font = .systemFont(ofSize: 15, weight: .regular)
        subtitleLabel.textColor = textGray
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        // CTA button
        let ctaButton = UIButton(type: .system)
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        ctaButton.backgroundColor = accentCyan
        ctaButton.setTitle("🔮  " + "insights.discoverCar".localized, for: .normal)
        ctaButton.setTitleColor(.white, for: .normal)
        ctaButton.titleLabel?.font = .systemFont(ofSize: 20, weight: .heavy)
        ctaButton.layer.cornerRadius = 28
        ctaButton.addTarget(self, action: #selector(discoverCarTapped), for: .touchUpInside)

        // Glow shadow
        ctaButton.layer.shadowColor = accentCyan.cgColor
        ctaButton.layer.shadowOffset = .zero
        ctaButton.layer.shadowRadius = 16
        ctaButton.layer.shadowOpacity = 0.6

        // Add to container
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

            // Question mark above the image
            questionLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            questionLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            // Car image below the question mark - large and impressive
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
            ctaButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
            ctaButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32),
            ctaButton.heightAnchor.constraint(equalToConstant: 56),
            ctaButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -32),
        ])

        stack.addArrangedSubview(container)

        // Update gradient after layout
        DispatchQueue.main.async {
            gradientLayer.frame = gradientView.bounds
        }

        // Animations - glow on the image
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

        // Start the loading animation
        showDiscoveryLoadingAnimation()
    }

    // MARK: - Discovery Loading Animation

private func showDiscoveryLoadingAnimation() {
    guard let container = discoveryContainer else { return }

    // Important: cancel previous minimum height if it remains
    discoveryMinHeightConstraint?.isActive = false
    discoveryMinHeightConstraint = nil

    // Clear the container
    container.subviews.forEach { $0.removeFromSuperview() }

    // Background with particles
    particleBackground = ParticleBackground(in: container)
    particleBackground?.start()

    // Central container
    let centerStack = UIStackView()
    centerStack.axis = .vertical
    centerStack.spacing = 20
    centerStack.alignment = .center
    centerStack.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(centerStack)

    // Animated icon
    let iconLabel = UILabel()
    iconLabel.text = "💓"
    iconLabel.font = .systemFont(ofSize: 60)
    iconLabel.textAlignment = .center

    // Status text
    let statusLabel = UILabel()
    statusLabel.text = "insights.scanningHealthData".localized
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

    // Save the constraint so we can deactivate it later
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

    // Pulse animation on the icon
    iconLabel.startPulseAnimation()

    // Phase 1: Scanning (3 seconds)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        progressBar.animateProgress(to: 0.3, duration: 2.5)
    }

    // Phase 2: Analyzing (2 seconds)
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
        iconLabel.text = "🧠"
        statusLabel.text = "insights.analyzingPerformance".localized
        progressBar.animateProgress(to: 0.6, duration: 1.8)
    }

    // Phase 3: Finding match (2 seconds)
    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
        iconLabel.text = "🎯"
        statusLabel.text = "insights.findingPerfectCar".localized
        progressBar.animateProgress(to: 0.9, duration: 1.5)
    }

    // Call Gemini in parallel (dashboard is now in the Performance tab)
    unifiedPerformanceVC()?.runAnalysisForInsights()

    // Wait for result (maximum 7 seconds)
    DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) { [weak self] in
        self?.checkForResultsAndReveal()
    }
}

    private func checkForResultsAndReveal() {
        particleBackground?.stop()

        // Check if there are results
        if let insights = GeminiResultStore.loadRawAnalysis(), !insights.isEmpty {
            let parsed = CarAnalysisParser.parse(insights)
            showRevealAnimation(parsed: parsed)
        } else {
            // If no results - try again or show message
            showRevealAnimation(parsed: nil)
        }
    }

    // MARK: - Reveal Animation (BOOM!)

    private func showRevealAnimation(parsed: CarAnalysisResponse?) {
        guard let container = discoveryContainer else { return }
        guard !isAnimatingContent else { return }  // Prevent conflicting animations
        isAnimatingContent = true

        // Flash effect
        container.flashWhite(duration: 0.3) { [weak self] in
            guard let self = self else { return }

            // Clear the container
            container.subviews.forEach { $0.removeFromSuperview() }

            // Confetti!
            self.confettiEmitter = ConfettiEmitter(in: container)
            self.confettiEmitter?.start()

            // Haptic
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            // Build the car card
            self.buildRevealedCarCard(in: container, parsed: parsed)
        }
    }

    private func buildRevealedCarCard(in container: UIView, parsed: CarAnalysisResponse?) {
        // Cancel minimum height left over from the loading animation
        discoveryMinHeightConstraint?.isActive = false
        discoveryMinHeightConstraint = nil

        // Get score from Gemini (single source of truth)
        let score: Int = GeminiResultStore.loadCarScore() ?? GeminiResultStore.loadHealthScore() ?? 0

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
                carName = "insights.waitingForAnalysis".localized
                wikiName = ""
                explanation = "insights.carSelectedAfter".localized
            }
        } else if let savedCar = AnalysisCache.loadSelectedCar() {
            carName = savedCar.name
            wikiName = savedCar.wikiName
            explanation = savedCar.explanation
        } else {
            carName = "insights.waitingForAnalysis".localized
            wikiName = ""
            explanation = "insights.carSelectedAfter".localized
        }

        // Determine status and color based on score - use score.description for consistency with Watch
        let scoreLevel = RangeLevel.from(score: Double(score))
        let status = "score.description.\(scoreLevel.rawValue)".localized

        // NOTE: Do NOT save to mainScore here! This score is the Gemini 90-day average.
        // mainScore should only be saved from InsightsDashboardViewController (daily score).
        // AnalysisCache.saveMainScore is intentionally NOT called here.

        let tierColor: UIColor
        switch score {
        case 80...100: tierColor = AIONDesign.accentSuccess
        case 65..<80: tierColor = AIONDesign.accentSecondary
        case 45..<65: tierColor = AIONDesign.accentPrimary
        case 25..<45: tierColor = AIONDesign.accentWarning
        default: tierColor = AIONDesign.accentDanger
        }

        // ═══ Glass Card reveal with floating car image ═══
        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        // Glass card
        let card = UIView()
        card.layer.cornerRadius = 20
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        card.alpha = 0
        card.transform = CGAffineTransform(scaleX: 0.5, y: 0.5).translatedBy(x: 0, y: -100)
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        container.addSubview(card)
        self.carCardView = card

        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blurView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(blurView)

        // ── Car name ──
        let carNameLabel = UILabel()
        carNameLabel.text = carName
        carNameLabel.font = .systemFont(ofSize: 22, weight: .heavy)
        carNameLabel.textColor = .white
        carNameLabel.textAlignment = .center
        carNameLabel.numberOfLines = 1
        carNameLabel.adjustsFontSizeToFitWidth = true
        carNameLabel.minimumScaleFactor = 0.7
        carNameLabel.alpha = 0
        carNameLabel.translatesAutoresizingMaskIntoConstraints = false

        // ── Score row (centered) ──
        let scoreLabel = UILabel()
        scoreLabel.text = "0"
        scoreLabel.font = .monospacedDigitSystemFont(ofSize: 44, weight: .black)
        scoreLabel.textColor = tierColor
        scoreLabel.alpha = 0
        scoreLabel.translatesAutoresizingMaskIntoConstraints = false

        let maxScoreLabel = UILabel()
        maxScoreLabel.text = "/100"
        maxScoreLabel.font = .systemFont(ofSize: 18, weight: .medium)
        maxScoreLabel.textColor = UIColor.white.withAlphaComponent(0.4)
        maxScoreLabel.alpha = 0
        maxScoreLabel.translatesAutoresizingMaskIntoConstraints = false

        let statusBadge = PaddedLabel()
        statusBadge.text = status
        statusBadge.font = .systemFont(ofSize: 12, weight: .bold)
        statusBadge.textColor = .white
        statusBadge.backgroundColor = tierColor
        statusBadge.clipsToBounds = true
        statusBadge.alpha = 0
        statusBadge.translatesAutoresizingMaskIntoConstraints = false

        let scoreRow = UIStackView()
        scoreRow.axis = .horizontal
        scoreRow.alignment = .firstBaseline
        scoreRow.spacing = 2
        scoreRow.alpha = 0
        scoreRow.translatesAutoresizingMaskIntoConstraints = false
        scoreRow.addArrangedSubview(scoreLabel)
        scoreRow.addArrangedSubview(maxScoreLabel)
        scoreRow.setCustomSpacing(10, after: maxScoreLabel)
        scoreRow.addArrangedSubview(statusBadge)

        let scoreCenterStack = UIStackView()
        scoreCenterStack.axis = .horizontal
        scoreCenterStack.alignment = .center
        scoreCenterStack.distribution = .equalCentering
        scoreCenterStack.translatesAutoresizingMaskIntoConstraints = false
        let leftSpacer = UIView(); leftSpacer.translatesAutoresizingMaskIntoConstraints = false
        let rightSpacer = UIView(); rightSpacer.translatesAutoresizingMaskIntoConstraints = false
        scoreCenterStack.addArrangedSubview(leftSpacer)
        scoreCenterStack.addArrangedSubview(scoreRow)
        scoreCenterStack.addArrangedSubview(rightSpacer)
        leftSpacer.widthAnchor.constraint(equalTo: rightSpacer.widthAnchor).isActive = true

        // ── Progress bar ──
        let progressBar = AnimatedProgressBar()
        progressBar.progressColor = tierColor
        progressBar.alpha = 0
        progressBar.translatesAutoresizingMaskIntoConstraints = false

        // ── Explanation ──
        let explanationLabel = UILabel()
        let rawExplanation = parsed?.carExplanation ?? "insights.carSelectedBased".localized
        explanationLabel.text = cleanExplanationText(rawExplanation, carName: carName)
        explanationLabel.font = .systemFont(ofSize: 15, weight: .regular)
        explanationLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        explanationLabel.textAlignment = .center
        explanationLabel.numberOfLines = 0
        explanationLabel.lineBreakMode = .byWordWrapping
        explanationLabel.alpha = 0
        explanationLabel.translatesAutoresizingMaskIntoConstraints = false

        // ── Button ──
        let refreshButton = createActionButton(title: "🔄 " + "insights.checkAgain".localized, action: #selector(rediscoverTapped))
        refreshButton.alpha = 0
        refreshButton.translatesAutoresizingMaskIntoConstraints = false

        // ── Content stack ──
        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 6
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        contentStack.addArrangedSubview(carNameLabel)
        contentStack.addArrangedSubview(scoreCenterStack)
        contentStack.addArrangedSubview(progressBar)
        contentStack.setCustomSpacing(10, after: progressBar)
        contentStack.addArrangedSubview(explanationLabel)
        contentStack.setCustomSpacing(12, after: explanationLabel)
        contentStack.addArrangedSubview(refreshButton)
        card.addSubview(contentStack)

        // ── Floating car image ──
        let carImageView = UIImageView()
        carImageView.contentMode = .scaleAspectFit
        carImageView.clipsToBounds = false
        carImageView.backgroundColor = .clear
        carImageView.alpha = 0
        carImageView.translatesAutoresizingMaskIntoConstraints = false
        carImageView.layer.shadowColor = UIColor.black.cgColor
        carImageView.layer.shadowOffset = CGSize(width: 0, height: 8)
        carImageView.layer.shadowOpacity = 0.5
        carImageView.layer.shadowRadius = 16
        container.addSubview(carImageView)  // Add to container, not card

        if !wikiName.isEmpty {
            fetchCarImageFromWikipedia(carName: wikiName, into: carImageView, fallbackEmoji: "🚗")
        }

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: container.topAnchor, constant: 50),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            blurView.topAnchor.constraint(equalTo: card.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),

            progressBar.heightAnchor.constraint(equalToConstant: 5),
            refreshButton.heightAnchor.constraint(equalToConstant: 38),

            carImageView.centerXAnchor.constraint(equalTo: container.trailingAnchor, constant: -90),
            carImageView.bottomAnchor.constraint(equalTo: card.topAnchor, constant: 30),
            carImageView.widthAnchor.constraint(equalToConstant: 160),
            carImageView.heightAnchor.constraint(equalToConstant: 100),
        ])

        // === Reveal animations ===

        // 1. Card enters with bounce
        UIView.animate(
            withDuration: 0.8,
            delay: 0.2,
            usingSpringWithDamping: 0.65,
            initialSpringVelocity: 0.5,
            options: []
        ) {
            card.alpha = 1
            card.transform = .identity
            container.superview?.layoutIfNeeded()
        }

        // 2. Car image drops in
        carImageView.transform = CGAffineTransform(translationX: 40, y: -30)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UIView.animate(withDuration: 0.7, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.3, options: []) {
                carImageView.alpha = 1
                carImageView.transform = .identity
            }
        }

        // 3. Car name
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            UIView.animate(withDuration: 0.5) {
                carNameLabel.alpha = 1
            }
        }

        // 4. Score counter + badge
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            scoreCenterStack.alpha = 1
            scoreRow.alpha = 1
            scoreLabel.alpha = 1
            maxScoreLabel.alpha = 1
            let counterAnimator = NumberCounterAnimator(label: scoreLabel)
            counterAnimator.animate(from: 0, to: score, duration: 1.2)
            UIView.animate(withDuration: 0.3) {
                statusBadge.alpha = 1
            }
        }

        // 5. Progress bar
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            progressBar.alpha = 1
            progressBar.animateProgress(to: CGFloat(score) / 100.0, duration: 1.2)
        }

        // 6. Explanation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            UIView.animate(withDuration: 0.4) {
                explanationLabel.alpha = 1
            }
        }

        // 7. Button
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            UIView.animate(withDuration: 0.4) {
                refreshButton.alpha = 1
            }
        }

        // 8. Add remaining content after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
            guard let self = self else { return }
            self.isShowingDiscoveryFlow = false
            self.isAnimatingContent = false  // Animations complete
            self.addRemainingContent(parsed: parsed)
        }

        // Mark that the user has already discovered
        UserDefaults.standard.set(true, forKey: "AION.HasDiscoveredCar")

        // Update widget with real activity data
        let dailyActivity = AnalysisCache.loadDailyActivity()
        let userName = Auth.auth().currentUser?.displayName ?? ""
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
            hrv: nil,
            sleepHours: nil,
            userName: userName
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

    // Add remaining content after the reveal animation
    private func addRemainingContent(parsed: CarAnalysisResponse?) {
        guard let parsed = parsed else { return }

        // Add "AION Insights" title above the card
        insertHeaderAboveCard()

        // Add all additional sections
        addPerformanceSection(parsed: parsed)
        addBottlenecksCard(parsed: parsed)
        addOptimizationCard(parsed: parsed)
        addTuneUpCard(parsed: parsed)
        addNutritionButton(parsed: parsed)
        addDirectivesCard(parsed: parsed)
        addSummaryCard(parsed: parsed)
    }

    // Add title above the car card
    private func insertHeaderAboveCard() {
        let headerStack = UIStackView()
        headerStack.axis = .vertical
        headerStack.spacing = 4
        headerStack.alignment = .center

        let sparkle = UILabel()
        sparkle.text = "✨"
        sparkle.font = .systemFont(ofSize: 28)

        let title = UILabel()
        title.text = "insights.aionInsights".localized
        title.font = .systemFont(ofSize: 22, weight: .bold)
        title.textColor = textWhite

        let subtitle = UILabel()
        subtitle.text = "insights.biometricAnalysis".localized
        subtitle.font = .systemFont(ofSize: 13, weight: .regular)
        subtitle.textColor = textGray

        let dateLabel = UILabel()
        if let d = GeminiResultStore.load()?.date {
            let f = DateFormatter()
            f.locale = Locale(identifier: LocalizationManager.shared.currentLanguage == .hebrew ? "he_IL" : "en_US")
            f.dateFormat = LocalizationManager.shared.currentLanguage == .hebrew ? "d בMMMM yyyy" : "MMMM d, yyyy"
            dateLabel.text = "\("insights.lastUpdate".localized): \(f.string(from: d))"
        }
        dateLabel.font = .systemFont(ofSize: 12, weight: .regular)
        dateLabel.textColor = textDarkGray

        headerStack.addArrangedSubview(sparkle)
        headerStack.addArrangedSubview(title)
        headerStack.addArrangedSubview(subtitle)
        headerStack.addArrangedSubview(dateLabel)

        // Add at the beginning of the stack (above the car card)
        stack.insertArrangedSubview(headerStack, at: 0)
    }

    @objc private func rediscoverTapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Delete cache and restart
        GeminiResultStore.clear()
        AnalysisCache.clear()
        UserDefaults.standard.set(false, forKey: "AION.HasDiscoveredCar")
        isShowingDiscoveryFlow = false
        refreshContent()
    }

    @objc private func showDetailsTapped() {
        // Scroll down to show the rest of the content
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // If there's no additional content yet, add it
        if stack.arrangedSubviews.count <= 2 {
            guard let insights = GeminiResultStore.loadRawAnalysis(), !insights.isEmpty else { return }
            let parsed = CarAnalysisParser.parse(insights)

            // Add remaining sections
            addPerformanceSection(parsed: parsed)
            addBottlenecksCard(parsed: parsed)
            addOptimizationCard(parsed: parsed)
            addTuneUpCard(parsed: parsed)
            addNutritionButton(parsed: parsed)
            addDirectivesCard(parsed: parsed)
            addSummaryCard(parsed: parsed)
        }

        // Scroll down
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
        // Check if this is the first time or the user has already discovered
        let hasDiscovered = UserDefaults.standard.bool(forKey: "AION.HasDiscoveredCar")

        if !hasDiscovered {
            addFirstTimeDiscoveryExperience()
        } else {
            // Regular empty state (in case the cache was deleted but the user already discovered)
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
        titleLabel.text = "insights.noAnalysisYet".localized
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = textWhite
        titleLabel.textAlignment = .center

        let subtitleLabel = UILabel()
        subtitleLabel.text = "insights.pressRefreshToStart".localized
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
        container.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute

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
        label.textAlignment = LocalizationManager.shared.textAlignment

        container.addArrangedSubview(label)

        return container
    }

    private func makeSubHeader(_ title: String, color: UIColor) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = color
        label.textAlignment = LocalizationManager.shared.textAlignment
        return label
    }
}

// MARK: - UITextViewDelegate (Personal Notes)

extension InsightsTabViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        let hasText = !textView.text.isEmpty
        notesPlaceholderLabel?.isHidden = hasText

        // Show/hide save button with spring animation
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.5) {
            self.notesSaveButton?.alpha = hasText ? 1 : 0
            self.notesSaveButton?.transform = hasText ? .identity : CGAffineTransform(scaleX: 0.85, y: 0.85)
        }
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        notesPlaceholderLabel?.isHidden = !textView.text.isEmpty
        // Subtle highlight on the text container border
        UIView.animate(withDuration: 0.2) {
            self.notesTextContainerView?.layer.borderColor = AIONDesign.accentPrimary.withAlphaComponent(0.25).cgColor
        }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        notesPlaceholderLabel?.isHidden = !textView.text.isEmpty
        // Restore border
        UIView.animate(withDuration: 0.2) {
            self.notesTextContainerView?.layer.borderColor = AIONDesign.textTertiary.withAlphaComponent(0.08).cgColor
        }
        // Hide save button if empty
        if textView.text.isEmpty {
            UIView.animate(withDuration: 0.25) {
                self.notesSaveButton?.alpha = 0
                self.notesSaveButton?.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
            }
        }
    }
}
