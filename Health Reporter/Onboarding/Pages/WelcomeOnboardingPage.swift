//
//  WelcomeOnboardingPage.swift
//  Health Reporter
//
//  מסך פתיחה - ברוכים הבאים ל-AION
//

import UIKit

final class WelcomeOnboardingPage: UIViewController {

    private weak var delegate: OnboardingPageDelegate?

    // MARK: - UI

    private let logoImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "AIONLogoClear"))
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "onboarding.welcome.title".localized
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.textColor = AIONDesign.textPrimary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "onboarding.welcome.subtitle".localized
        label.font = .systemFont(ofSize: 17, weight: .regular)
        label.textColor = AIONDesign.textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let bulletStack: UIStackView = {
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

        // Logo
        view.addSubview(logoImageView)

        // Title & Subtitle
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)

        // Bullets
        let bullets = [
            ("car.fill", "onboarding.welcome.bullet1".localized),
            ("chart.line.uptrend.xyaxis", "onboarding.welcome.bullet2".localized),
            ("heart.text.square.fill", "onboarding.welcome.bullet3".localized)
        ]

        for (icon, text) in bullets {
            let bulletView = createBulletView(icon: icon, text: text)
            bulletStack.addArrangedSubview(bulletView)
        }
        view.addSubview(bulletStack)

        // Button
        continueButton.setTitle("onboarding.welcome.getStarted".localized, for: .normal)
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        view.addSubview(continueButton)

        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            logoImageView.widthAnchor.constraint(equalToConstant: 120),
            logoImageView.heightAnchor.constraint(equalToConstant: 120),

            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            bulletStack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),
            bulletStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            bulletStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -80)
        ])

        // Initial state for animation
        logoImageView.alpha = 0
        logoImageView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        titleLabel.alpha = 0
        subtitleLabel.alpha = 0
        bulletStack.alpha = 0
        bulletStack.transform = CGAffineTransform(translationX: 0, y: 20)
        continueButton.alpha = 0
    }

    private func createBulletView(icon: String, text: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView()
        iconView.image = UIImage(systemName: icon)
        iconView.tintColor = AIONDesign.accentPrimary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = AIONDesign.textPrimary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(iconView)
        container.addSubview(label)

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),
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

    private func animateIn() {
        UIView.animate(withDuration: 0.6, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [], animations: {
            self.logoImageView.alpha = 1
            self.logoImageView.transform = .identity
        }, completion: nil)

        UIView.animate(withDuration: 0.5, delay: 0.3, animations: {
            self.titleLabel.alpha = 1
        })

        UIView.animate(withDuration: 0.5, delay: 0.4, animations: {
            self.subtitleLabel.alpha = 1
        })

        UIView.animate(withDuration: 0.6, delay: 0.5, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [], animations: {
            self.bulletStack.alpha = 1
            self.bulletStack.transform = .identity
        }, completion: nil)

        UIView.animate(withDuration: 0.5, delay: 0.7, animations: {
            self.continueButton.alpha = 1
        })
    }

    // MARK: - Actions

    @objc private func continueTapped() {
        continueButton.springAnimation {
            self.delegate?.onboardingDidRequestNext()
        }
    }
}
