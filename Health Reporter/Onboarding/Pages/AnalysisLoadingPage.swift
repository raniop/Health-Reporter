//
//  AnalysisLoadingPage.swift
//  Health Reporter
//
//  מסך טעינה אחרון - ממתין לסיום הניתוח של Gemini
//

import UIKit

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
        checkIfAlreadyComplete()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        setupProgressRing()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
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

    private func updateProgress(to value: Double, step: String) {
        currentProgress = value

        // Animate progress ring
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = progressLayer?.strokeEnd ?? 0
        animation.toValue = value
        animation.duration = 0.5
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        progressLayer?.add(animation, forKey: "progress")

        // Update percentage label
        let percentage = Int(value * 100)
        UIView.transition(with: progressLabel, duration: 0.3, options: .transitionCrossDissolve) {
            self.progressLabel.text = "\(percentage)%"
        }

        // Update status label
        UIView.transition(with: statusLabel, duration: 0.3, options: .transitionCrossDissolve) {
            self.statusLabel.text = step
        }
    }

    private func checkIfAlreadyComplete() {
        // אם הניתוח כבר הסתיים (המשתמש עבר מהר על המסכים)
        if OnboardingCoordinator.shared.isAnalysisComplete {
            handleAnalysisComplete()
        } else if OnboardingCoordinator.shared.analysisState == .idle {
            // אם לא התחיל (למשל דילג על HealthKit) - סיים מיד
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.updateProgress(to: 1.0, step: "onboarding.progress.ready".localized)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.completeOnboarding()
                }
            }
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

        // Celebration animation
        UIView.animate(withDuration: 0.3, animations: {
            self.carImageView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }, completion: { _ in
            UIView.animate(withDuration: 0.2, animations: {
                self.carImageView.transform = .identity
            }, completion: { _ in
                if hasGeminiData {
                    // Get car tier data for reveal
                    let tier = CarTierEngine.tierForScore(healthScore)
                    self.delegate?.onboardingDidRequestCarReveal(
                        carName: tier.name,
                        carEmoji: tier.emoji,
                        healthScore: healthScore
                    )
                } else {
                    // No data - go directly to main screen
                    self.delegate?.onboardingDidComplete()
                }
            })
        })
    }
}
