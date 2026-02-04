//
//  HealthScoreOnboardingPage.swift
//  Health Reporter
//
//  מסך הסבר על ה-Health Score
//

import UIKit

final class HealthScoreOnboardingPage: UIViewController {

    private weak var delegate: OnboardingPageDelegate?

    // MARK: - UI

    private let gaugeContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let scoreLabel: UILabel = {
        let label = UILabel()
        label.text = "85"
        label.font = .systemFont(ofSize: 48, weight: .bold)
        label.textColor = AIONDesign.accentPrimary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "onboarding.score.title".localized
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = AIONDesign.textPrimary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "onboarding.score.description".localized
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = AIONDesign.textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let componentsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let continueButton = OnboardingPrimaryButton()

    private var progressLayer: CAShapeLayer?
    private var animatedScore = 0

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
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateGauge()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        setupGaugeRing()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = AIONDesign.background

        // Gauge container
        view.addSubview(gaugeContainer)
        gaugeContainer.addSubview(scoreLabel)

        // Title & Description
        view.addSubview(titleLabel)
        view.addSubview(descriptionLabel)

        // Score components
        let components = [
            ("bed.double.fill", "onboarding.score.sleep".localized, AIONDesign.chartSleep),
            ("figure.run", "onboarding.score.activity".localized, AIONDesign.accentSecondary),
            ("heart.fill", "onboarding.score.heart".localized, AIONDesign.chartRecovery)
        ]

        for (icon, name, color) in components {
            let componentView = createComponentView(icon: icon, name: name, color: color)
            componentsStack.addArrangedSubview(componentView)
        }
        view.addSubview(componentsStack)

        // Button
        continueButton.setTitle("onboarding.continue".localized, for: .normal)
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        view.addSubview(continueButton)

        NSLayoutConstraint.activate([
            gaugeContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            gaugeContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            gaugeContainer.widthAnchor.constraint(equalToConstant: 150),
            gaugeContainer.heightAnchor.constraint(equalToConstant: 150),

            scoreLabel.centerXAnchor.constraint(equalTo: gaugeContainer.centerXAnchor),
            scoreLabel.centerYAnchor.constraint(equalTo: gaugeContainer.centerYAnchor),

            titleLabel.topAnchor.constraint(equalTo: gaugeContainer.bottomAnchor, constant: 32),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            componentsStack.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 32),
            componentsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            componentsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            componentsStack.heightAnchor.constraint(equalToConstant: 80),

            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -80)
        ])
    }

    private func setupGaugeRing() {
        // Remove existing layers
        gaugeContainer.layer.sublayers?.removeAll { $0 is CAShapeLayer }

        let center = CGPoint(x: gaugeContainer.bounds.midX, y: gaugeContainer.bounds.midY)
        let radius: CGFloat = 65
        let lineWidth: CGFloat = 12

        // Background ring
        let backgroundPath = UIBezierPath(arcCenter: center, radius: radius, startAngle: -.pi * 0.75, endAngle: .pi * 0.75, clockwise: true)
        let backgroundLayer = CAShapeLayer()
        backgroundLayer.path = backgroundPath.cgPath
        backgroundLayer.strokeColor = AIONDesign.surfaceElevated.cgColor
        backgroundLayer.fillColor = UIColor.clear.cgColor
        backgroundLayer.lineWidth = lineWidth
        backgroundLayer.lineCap = .round
        gaugeContainer.layer.addSublayer(backgroundLayer)

        // Progress ring
        let progressPath = UIBezierPath(arcCenter: center, radius: radius, startAngle: -.pi * 0.75, endAngle: .pi * 0.75, clockwise: true)
        let progressLayerNew = CAShapeLayer()
        progressLayerNew.path = progressPath.cgPath
        progressLayerNew.strokeColor = AIONDesign.accentPrimary.cgColor
        progressLayerNew.fillColor = UIColor.clear.cgColor
        progressLayerNew.lineWidth = lineWidth
        progressLayerNew.lineCap = .round
        progressLayerNew.strokeEnd = 0
        gaugeContainer.layer.addSublayer(progressLayerNew)
        self.progressLayer = progressLayerNew
    }

    private func createComponentView(icon: String, name: String, color: UIColor) -> UIView {
        let container = UIView()
        container.backgroundColor = AIONDesign.surface
        container.layer.cornerRadius = AIONDesign.cornerRadiusSmall
        container.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView()
        iconView.image = UIImage(systemName: icon)
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = .systemFont(ofSize: 11, weight: .medium)
        nameLabel.textColor = AIONDesign.textSecondary
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(iconView)
        container.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            iconView.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            nameLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            nameLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4)
        ])

        return container
    }

    // MARK: - Animation

    private func animateGauge() {
        // Animate score number
        scoreLabel.text = "0"
        animatedScore = 0

        let timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }

            self.animatedScore += 1
            self.scoreLabel.text = "\(self.animatedScore)"

            if self.animatedScore >= 85 {
                timer.invalidate()
            }
        }
        RunLoop.current.add(timer, forMode: .common)

        // Animate ring
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = 0
        animation.toValue = 0.85
        animation.duration = 1.5
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        progressLayer?.add(animation, forKey: "progress")

        // Animate components
        for (index, subview) in componentsStack.arrangedSubviews.enumerated() {
            subview.alpha = 0
            subview.transform = CGAffineTransform(translationX: 0, y: 20)

            UIView.animate(withDuration: 0.5, delay: 0.8 + Double(index) * 0.15, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [], animations: {
                subview.alpha = 1
                subview.transform = .identity
            }, completion: nil)
        }
    }

    // MARK: - Actions

    @objc private func continueTapped() {
        continueButton.springAnimation {
            self.delegate?.onboardingDidRequestNext()
        }
    }
}
