//
//  AnalysisLoadingPage.swift
//  Health Reporter
//
//  Final loading screen - waits for Gemini analysis to complete
//

import UIKit

private struct AssociatedKeys {
    static var animationStartValue = "animationStartValue"
    static var animationEndValue = "animationEndValue"
    static var animationStartTime = "animationStartTime"
    static var animationDuration = "animationDuration"
    static var displayLink = "displayLink"
}

final class AnalysisLoadingPage: UIViewController {

    private weak var delegate: OnboardingPageDelegate?

    // MARK: - UI

    private let carImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "car.fill")
        iv.tintColor = AIONDesign.accentPrimary
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let progressContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let progressLabel: UILabel = {
        let label = UILabel()
        label.text = "0%"
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = AIONDesign.textPrimary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "onboarding.progress.syncing".localized
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = AIONDesign.textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "onboarding.loading.subtitle".localized
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = AIONDesign.textTertiary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private var progressLayer: CAShapeLayer?
    private var currentProgress: Double = 0
    private var simulatedProgressTimer: Timer?
    private var simulatedProgress: Double = 0

    // MARK: - Init

    init(delegate: OnboardingPageDelegate) {
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNotifications()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startAnimations()
        startSimulatedProgress()
        checkIfAlreadyComplete()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        setupProgressRing()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        simulatedProgressTimer?.invalidate()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = AIONDesign.background

        // Car icon
        view.addSubview(carImageView)

        // Progress ring container
        view.addSubview(progressContainer)
        progressContainer.addSubview(progressLabel)

        // Status labels
        view.addSubview(statusLabel)
        view.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            carImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            carImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            carImageView.widthAnchor.constraint(equalToConstant: 80),
            carImageView.heightAnchor.constraint(equalToConstant: 80),

            progressContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressContainer.topAnchor.constraint(equalTo: carImageView.bottomAnchor, constant: 40),
            progressContainer.widthAnchor.constraint(equalToConstant: 160),
            progressContainer.heightAnchor.constraint(equalToConstant: 160),

            progressLabel.centerXAnchor.constraint(equalTo: progressContainer.centerXAnchor),
            progressLabel.centerYAnchor.constraint(equalTo: progressContainer.centerYAnchor),

            statusLabel.topAnchor.constraint(equalTo: progressContainer.bottomAnchor, constant: 32),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            subtitleLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func setupProgressRing() {
        progressContainer.layer.sublayers?.removeAll { $0 is CAShapeLayer }

        let center = CGPoint(x: progressContainer.bounds.midX, y: progressContainer.bounds.midY)
        let radius: CGFloat = 70
        let lineWidth: CGFloat = 8

        // Background ring
        let backgroundPath = UIBezierPath(arcCenter: center, radius: radius, startAngle: -.pi / 2, endAngle: .pi * 1.5, clockwise: true)
        let backgroundLayer = CAShapeLayer()
        backgroundLayer.path = backgroundPath.cgPath
        backgroundLayer.strokeColor = AIONDesign.surfaceElevated.cgColor
        backgroundLayer.fillColor = UIColor.clear.cgColor
        backgroundLayer.lineWidth = lineWidth
        backgroundLayer.lineCap = .round
        progressContainer.layer.addSublayer(backgroundLayer)

        // Progress ring with gradient
        let progressPath = UIBezierPath(arcCenter: center, radius: radius, startAngle: -.pi / 2, endAngle: .pi * 1.5, clockwise: true)
        let progressLayerNew = CAShapeLayer()
        progressLayerNew.path = progressPath.cgPath
        progressLayerNew.strokeColor = AIONDesign.accentPrimary.cgColor
        progressLayerNew.fillColor = UIColor.clear.cgColor
        progressLayerNew.lineWidth = lineWidth
        progressLayerNew.lineCap = .round
        progressLayerNew.strokeEnd = CGFloat(currentProgress)
        progressContainer.layer.addSublayer(progressLayerNew)
        self.progressLayer = progressLayerNew
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAnalysisProgress),
            name: OnboardingCoordinator.analysisProgressNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAnalysisComplete),
            name: OnboardingCoordinator.analysisDidCompleteNotification,
            object: nil
        )
    }

    // MARK: - Animation

    private func startAnimations() {
        // Car floating animation
        UIView.animate(withDuration: 1.5, delay: 0, options: [.repeat, .autoreverse, .curveEaseInOut], animations: {
            self.carImageView.transform = CGAffineTransform(translationX: 0, y: -10)
        }, completion: nil)

        // Glow effect on progress ring
        progressContainer.layer.shadowColor = AIONDesign.accentPrimary.cgColor
        progressContainer.layer.shadowOffset = .zero
        progressContainer.layer.shadowRadius = 20
        progressContainer.layer.shadowOpacity = 0

        UIView.animate(withDuration: 1.5, delay: 0, options: [.repeat, .autoreverse, .curveEaseInOut], animations: {
            self.progressContainer.layer.shadowOpacity = 0.6
        }, completion: nil)
    }

    /// Simulated progress that moves slowly to show activity while waiting for real progress
    private func startSimulatedProgress() {
        simulatedProgress = 0
        simulatedProgressTimer?.invalidate()

        // Update every 0.3 seconds with small increments
        simulatedProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // Stop if real progress has taken over
            guard self.currentProgress == 0 else {
                self.simulatedProgressTimer?.invalidate()
                return
            }

            // Asymptotic progress that slows down but never fully stops
            // Goes faster to 30%, then slower to 90% (never reaches 100%)
            let maxSimulated = 0.90
            let remaining = maxSimulated - self.simulatedProgress

            // Speed depends on current progress - faster at start, slower as we go
            let speedFactor: Double
            if self.simulatedProgress < 0.30 {
                speedFactor = 0.08  // Fast phase: ~8% of remaining
            } else if self.simulatedProgress < 0.60 {
                speedFactor = 0.03  // Medium phase: ~3% of remaining
            } else {
                speedFactor = 0.015 // Slow phase: ~1.5% of remaining
            }

            let increment = remaining * speedFactor
            self.simulatedProgress = min(maxSimulated, self.simulatedProgress + max(0.002, increment))

            // Update UI
            let percentage = Int(self.simulatedProgress * 100)
            self.progressLabel.text = "\(percentage)%"

            // Animate progress ring
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.progressLayer?.strokeEnd = CGFloat(self.simulatedProgress)
            CATransaction.commit()
        }
    }

    private func updateProgress(to value: Double, step: String) {
        // Stop simulated progress when real progress arrives
        simulatedProgressTimer?.invalidate()
        simulatedProgressTimer = nil

        // Ensure we animate from current visual position (including simulated)
        let fromValue = max(simulatedProgress, currentProgress)
        currentProgress = value

        // Calculate animation duration based on distance (longer for bigger jumps)
        let distance = abs(value - fromValue)
        let duration = max(0.5, min(1.5, distance * 2.0)) // 0.5-1.5 seconds based on distance

        // Animate progress ring
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = fromValue
        animation.toValue = value
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        progressLayer?.add(animation, forKey: "progress")

        // Animate percentage label smoothly
        animatePercentageLabel(from: Int(fromValue * 100), to: Int(value * 100), duration: duration)

        // Update status label
        UIView.transition(with: statusLabel, duration: 0.3, options: .transitionCrossDissolve) {
            self.statusLabel.text = step
        }
    }

    private func animatePercentageLabel(from startValue: Int, to endValue: Int, duration: Double) {
        let startTime = CACurrentMediaTime()
        let displayLink = CADisplayLink(target: self, selector: #selector(updatePercentageAnimation))
        displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60)

        // Store animation parameters
        objc_setAssociatedObject(self, &AssociatedKeys.animationStartValue, startValue, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &AssociatedKeys.animationEndValue, endValue, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &AssociatedKeys.animationStartTime, startTime, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &AssociatedKeys.animationDuration, duration, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &AssociatedKeys.displayLink, displayLink, .OBJC_ASSOCIATION_RETAIN)

        displayLink.add(to: .main, forMode: .common)
    }

    @objc private func updatePercentageAnimation() {
        guard let startValue = objc_getAssociatedObject(self, &AssociatedKeys.animationStartValue) as? Int,
              let endValue = objc_getAssociatedObject(self, &AssociatedKeys.animationEndValue) as? Int,
              let startTime = objc_getAssociatedObject(self, &AssociatedKeys.animationStartTime) as? Double,
              let duration = objc_getAssociatedObject(self, &AssociatedKeys.animationDuration) as? Double,
              let displayLink = objc_getAssociatedObject(self, &AssociatedKeys.displayLink) as? CADisplayLink else {
            return
        }

        let elapsed = CACurrentMediaTime() - startTime
        let progress = min(1.0, elapsed / duration)

        // Ease in-out curve
        let easedProgress = progress < 0.5
            ? 2 * progress * progress
            : 1 - pow(-2 * progress + 2, 2) / 2

        let currentValue = startValue + Int(Double(endValue - startValue) * easedProgress)
        progressLabel.text = "\(currentValue)%"

        if progress >= 1.0 {
            displayLink.invalidate()
            progressLabel.text = "\(endValue)%"
        }
    }

    private func checkIfAlreadyComplete() {
        print("🎬 [AnalysisLoadingPage] checkIfAlreadyComplete - state=\(OnboardingCoordinator.shared.analysisState), isComplete=\(OnboardingCoordinator.shared.isAnalysisComplete)")
        // If analysis already completed (user went through screens quickly)
        if OnboardingCoordinator.shared.isAnalysisComplete {
            print("🎬 [AnalysisLoadingPage] Analysis already complete - calling handleAnalysisComplete")
            handleAnalysisComplete()
        } else if OnboardingCoordinator.shared.analysisState == .idle {
            print("🎬 [AnalysisLoadingPage] Analysis idle - completing quickly")
            // If not started (e.g. skipped HealthKit) - finish immediately
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.updateProgress(to: 1.0, step: "onboarding.progress.ready".localized)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.completeOnboarding()
                }
            }
        } else {
            print("🎬 [AnalysisLoadingPage] Analysis in progress - waiting for completion notification")
        }
    }

    // MARK: - Notification Handlers

    @objc private func handleAnalysisProgress(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let step = userInfo["step"] as? String,
              let progress = userInfo["progress"] as? Double else { return }

        DispatchQueue.main.async { [weak self] in
            self?.updateProgress(to: progress, step: step)
        }
    }

    @objc private func handleAnalysisComplete() {
        DispatchQueue.main.async { [weak self] in
            self?.updateProgress(to: 1.0, step: "onboarding.progress.ready".localized)

            // Wait a moment to show the completed state
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self?.completeOnboarding()
            }
        }
    }

    private func completeOnboarding() {
        // Stop animations
        carImageView.layer.removeAllAnimations()
        progressContainer.layer.removeAllAnimations()

        // Check if we have Gemini data for car reveal
        let healthScore = AnalysisCache.loadHealthScore() ?? 0
        let hasGeminiData = healthScore > 0
        let geminiCar = AnalysisCache.loadSelectedCar()

        // Debug: check raw UserDefaults value
        let rawScore = UserDefaults.standard.integer(forKey: "AION.WeeklyStats.HealthScore")
        let healthScoreResult = AnalysisCache.loadHealthScoreResult()
        print("🎬 [AnalysisLoadingPage] completeOnboarding called")
        print("🎬 [AnalysisLoadingPage] healthScore=\(healthScore), rawScore=\(rawScore), hasGeminiData=\(hasGeminiData)")
        print("🎬 [AnalysisLoadingPage] healthScoreResult?.healthScoreInt=\(healthScoreResult?.healthScoreInt ?? -1)")
        print("🎬 [AnalysisLoadingPage] geminiCar=\(geminiCar?.name ?? "nil")")

        // Celebration animation
        UIView.animate(withDuration: 0.3, animations: {
            self.carImageView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }, completion: { _ in
            UIView.animate(withDuration: 0.2, animations: {
                self.carImageView.transform = .identity
            }, completion: { _ in
                if hasGeminiData {
                    // Get actual Gemini car name - NEVER use generic tier names!
                    let geminiCar = AnalysisCache.loadSelectedCar()
                    let tier = CarTierEngine.tierForScore(healthScore)

                    // Only proceed with car reveal if we have actual Gemini car name
                    guard let carName = geminiCar?.name, !carName.isEmpty else {
                        // No Gemini car name - go directly to main screen
                        self.delegate?.onboardingDidComplete()
                        return
                    }

                    let wikiName = geminiCar?.wikiName ?? ""

                    // Clear any pending reveal since we're showing it now in onboarding
                    AnalysisCache.clearPendingCarReveal()

                    self.delegate?.onboardingDidRequestCarReveal(
                        carName: carName,
                        carEmoji: tier.emoji,
                        healthScore: healthScore,
                        wikiName: wikiName
                    )
                } else {
                    // No data - go directly to main screen
                    self.delegate?.onboardingDidComplete()
                }
            })
        })
    }
}
