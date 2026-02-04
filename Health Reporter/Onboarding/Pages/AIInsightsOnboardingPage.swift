//
//  AIInsightsOnboardingPage.swift
//  Health Reporter
//
//  מסך הסבר על תובנות AI ומגמות
//

import UIKit

final class AIInsightsOnboardingPage: UIViewController {

    private weak var delegate: OnboardingPageDelegate?

    // MARK: - UI

    private let iconContainer: UIView = {
        let view = UIView()
        view.backgroundColor = AIONDesign.accentSuccess.withAlphaComponent(0.15)
        view.layer.cornerRadius = 50
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "brain.head.profile")
        iv.tintColor = AIONDesign.accentSuccess
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "onboarding.ai.title".localized
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = AIONDesign.textPrimary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "onboarding.ai.description".localized
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = AIONDesign.textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let featuresStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let continueButton = OnboardingPrimaryButton()

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
        animateIn()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = AIONDesign.background

        // Icon
        iconContainer.addSubview(iconImageView)
        view.addSubview(iconContainer)

        // Title & Description
        view.addSubview(titleLabel)
        view.addSubview(descriptionLabel)

        // Features
        let features = [
            ("lightbulb.fill", "onboarding.ai.feature1".localized, AIONDesign.accentPrimary),
            ("chart.line.uptrend.xyaxis", "onboarding.ai.feature2".localized, AIONDesign.accentSecondary),
            ("arrow.triangle.2.circlepath", "onboarding.ai.feature3".localized, AIONDesign.accentSuccess)
        ]

        for (icon, text, color) in features {
            let featureView = createFeatureView(icon: icon, text: text, color: color)
            featuresStack.addArrangedSubview(featureView)
        }
        view.addSubview(featuresStack)

        // Button
        continueButton.setTitle("onboarding.continue".localized, for: .normal)
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        view.addSubview(continueButton)

        NSLayoutConstraint.activate([
            iconContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            iconContainer.widthAnchor.constraint(equalToConstant: 100),
            iconContainer.heightAnchor.constraint(equalToConstant: 100),

            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 50),
            iconImageView.heightAnchor.constraint(equalToConstant: 50),

            titleLabel.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 32),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            featuresStack.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 32),
            featuresStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            featuresStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -80)
        ])
    }

    private func createFeatureView(icon: String, text: String, color: UIColor) -> UIView {
        let container = UIView()
        container.backgroundColor = AIONDesign.surface
        container.layer.cornerRadius = AIONDesign.cornerRadius
        container.translatesAutoresizingMaskIntoConstraints = false

        let iconContainer = UIView()
        iconContainer.backgroundColor = color.withAlphaComponent(0.15)
        iconContainer.layer.cornerRadius = 20
        iconContainer.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView()
        iconView.image = UIImage(systemName: icon)
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = AIONDesign.textPrimary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        iconContainer.addSubview(iconView)
        container.addSubview(iconContainer)
        container.addSubview(label)

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),

            iconContainer.widthAnchor.constraint(equalToConstant: 40),
            iconContainer.heightAnchor.constraint(equalToConstant: 40),
            iconContainer.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            isRTL ?
                iconContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16) :
                iconContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),

            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.topAnchor.constraint(greaterThanOrEqualTo: container.topAnchor, constant: 12),
            label.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -12),
            isRTL ?
                label.trailingAnchor.constraint(equalTo: iconContainer.leadingAnchor, constant: -16) :
                label.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 16),
            isRTL ?
                label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16) :
                label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16)
        ])

        return container
    }

    // MARK: - Animation

    private func animateIn() {
        // Pulse brain icon
        UIView.animate(withDuration: 0.8, delay: 0.3, options: [.repeat, .autoreverse], animations: {
            self.iconImageView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }, completion: nil)

        // Animate features
        for (index, subview) in featuresStack.arrangedSubviews.enumerated() {
            subview.alpha = 0
            subview.transform = CGAffineTransform(translationX: 50, y: 0)

            UIView.animate(withDuration: 0.5, delay: 0.2 + Double(index) * 0.15, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [], animations: {
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
