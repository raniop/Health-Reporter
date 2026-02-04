//
//  NotificationsOnboardingPage.swift
//  Health Reporter
//
//  מסך בקשת הרשאה לנוטיפיקציות
//

import UIKit

final class NotificationsOnboardingPage: UIViewController {

    private weak var delegate: OnboardingPageDelegate?

    // MARK: - UI

    private let iconContainer: UIView = {
        let view = UIView()
        view.backgroundColor = AIONDesign.accentPrimary.withAlphaComponent(0.15)
        view.layer.cornerRadius = 50
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "bell.badge.fill")
        iv.tintColor = AIONDesign.accentPrimary
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "onboarding.notifications.title".localized
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = AIONDesign.textPrimary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "onboarding.notifications.subtitle".localized
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = AIONDesign.textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let bulletStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let enableButton = OnboardingPrimaryButton()
    private let skipButton = OnboardingSecondaryButton()

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
        animateIcon()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = AIONDesign.background

        // Icon
        iconContainer.addSubview(iconImageView)
        view.addSubview(iconContainer)

        // Title & Subtitle
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)

        // Bullets
        let bullets = [
            ("chart.bar.fill", "onboarding.notifications.bullet1".localized),
            ("figure.run", "onboarding.notifications.bullet2".localized),
            ("person.2.fill", "onboarding.notifications.bullet3".localized)
        ]

        for (icon, text) in bullets {
            let bulletView = createBulletView(icon: icon, text: text)
            bulletStack.addArrangedSubview(bulletView)
        }
        view.addSubview(bulletStack)

        // Buttons
        enableButton.setTitle("onboarding.notifications.enable".localized, for: .normal)
        enableButton.addTarget(self, action: #selector(enableTapped), for: .touchUpInside)
        view.addSubview(enableButton)

        skipButton.setTitle("onboarding.notifications.skip".localized, for: .normal)
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        view.addSubview(skipButton)

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

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            bulletStack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),
            bulletStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            bulletStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            enableButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            enableButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            enableButton.bottomAnchor.constraint(equalTo: skipButton.topAnchor, constant: -12),

            skipButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            skipButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            skipButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -80)
        ])
    }

    private func createBulletView(icon: String, text: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView()
        iconView.image = UIImage(systemName: icon)
        iconView.tintColor = AIONDesign.accentSecondary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = AIONDesign.textPrimary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(iconView)
        container.addSubview(label)

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            iconView.topAnchor.constraint(equalTo: container.topAnchor),
            isRTL ?
                iconView.trailingAnchor.constraint(equalTo: container.trailingAnchor) :
                iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor),

            label.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            isRTL ?
                label.trailingAnchor.constraint(equalTo: iconView.leadingAnchor, constant: -12) :
                label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            isRTL ?
                label.leadingAnchor.constraint(equalTo: container.leadingAnchor) :
                label.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            container.bottomAnchor.constraint(greaterThanOrEqualTo: label.bottomAnchor),
            container.bottomAnchor.constraint(greaterThanOrEqualTo: iconView.bottomAnchor)
        ])

        return container
    }

    // MARK: - Animation

    private func animateIcon() {
        // Bell ring animation
        UIView.animateKeyframes(withDuration: 0.6, delay: 0.3, options: [], animations: {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.2) {
                self.iconImageView.transform = CGAffineTransform(rotationAngle: .pi / 12)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.2, relativeDuration: 0.2) {
                self.iconImageView.transform = CGAffineTransform(rotationAngle: -.pi / 12)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.4, relativeDuration: 0.2) {
                self.iconImageView.transform = CGAffineTransform(rotationAngle: .pi / 16)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.6, relativeDuration: 0.2) {
                self.iconImageView.transform = CGAffineTransform(rotationAngle: -.pi / 16)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.8, relativeDuration: 0.2) {
                self.iconImageView.transform = .identity
            }
        }, completion: nil)
    }

    // MARK: - Actions

    @objc private func enableTapped() {
        enableButton.isLoading = true
        delegate?.onboardingDidRequestNotifications()
    }

    @objc private func skipTapped() {
        delegate?.onboardingDidRequestNext()
    }
}
