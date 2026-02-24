//
//  DataPrivacyOnboardingPage.swift
//  Health Reporter
//
//  Onboarding page that discloses data usage and obtains explicit user consent:
//  1. AI Analysis: Health data is sent to Google Gemini AI for personalized analysis.
//  2. Leaderboard: Health scores can optionally appear on a global leaderboard.
//
//  Apple App Store Guidelines: 5.1.2 (Data Use and Sharing), 2.1 (Third-party AI)
//

import UIKit

final class DataPrivacyOnboardingPage: UIViewController {

    private weak var delegate: OnboardingPageDelegate?

    // MARK: - State

    private var aiConsentEnabled = true      // Default ON (required for core functionality)
    private var leaderboardEnabled = false   // Default OFF (opt-in)

    // MARK: - UI

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let iconContainer: UIView = {
        let view = UIView()
        view.backgroundColor = AIONDesign.accentPrimary.withAlphaComponent(0.15)
        view.layer.cornerRadius = 50
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "hand.raised.fill")
        iv.tintColor = AIONDesign.accentPrimary
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "onboarding.privacy.title".localized
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = AIONDesign.textPrimary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "onboarding.privacy.description".localized
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = AIONDesign.textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var aiToggle: UISwitch = {
        let toggle = UISwitch()
        toggle.isOn = true
        toggle.onTintColor = AIONDesign.accentPrimary
        toggle.addTarget(self, action: #selector(aiToggleChanged), for: .valueChanged)
        return toggle
    }()

    private lazy var leaderboardToggle: UISwitch = {
        let toggle = UISwitch()
        toggle.isOn = false
        toggle.onTintColor = AIONDesign.accentPrimary
        toggle.addTarget(self, action: #selector(leaderboardToggleChanged), for: .valueChanged)
        return toggle
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

    // MARK: - Setup

    private func setupUI() {
        applyAIONGradientBackground()

        // Scroll view (for smaller screens)
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        // Icon
        let iconWrapper = UIView()
        iconWrapper.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconImageView)
        iconWrapper.addSubview(iconContainer)

        NSLayoutConstraint.activate([
            iconContainer.centerXAnchor.constraint(equalTo: iconWrapper.centerXAnchor),
            iconContainer.topAnchor.constraint(equalTo: iconWrapper.topAnchor),
            iconContainer.bottomAnchor.constraint(equalTo: iconWrapper.bottomAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 100),
            iconContainer.heightAnchor.constraint(equalToConstant: 100),

            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 50),
            iconImageView.heightAnchor.constraint(equalToConstant: 50),
        ])

        // Title & description
        let titleWrapper = UIView()
        titleWrapper.translatesAutoresizingMaskIntoConstraints = false
        titleWrapper.addSubview(titleLabel)
        titleWrapper.addSubview(descriptionLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: titleWrapper.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: titleWrapper.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: titleWrapper.trailingAnchor),
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            descriptionLabel.leadingAnchor.constraint(equalTo: titleWrapper.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: titleWrapper.trailingAnchor),
            descriptionLabel.bottomAnchor.constraint(equalTo: titleWrapper.bottomAnchor),
        ])

        // AI consent card
        let aiCard = createConsentCard(
            icon: "brain.head.profile",
            iconColor: AIONDesign.accentSuccess,
            title: "onboarding.privacy.ai.title".localized,
            detail: "onboarding.privacy.ai.detail".localized,
            toggle: aiToggle
        )

        // Leaderboard consent card
        let leaderboardCard = createConsentCard(
            icon: "trophy.fill",
            iconColor: AIONDesign.accentSecondary,
            title: "onboarding.privacy.leaderboard.title".localized,
            detail: "onboarding.privacy.leaderboard.detail".localized,
            toggle: leaderboardToggle
        )

        // Add to stack
        contentStack.addArrangedSubview(iconWrapper)
        contentStack.addArrangedSubview(titleWrapper)
        contentStack.addArrangedSubview(aiCard)
        contentStack.addArrangedSubview(leaderboardCard)

        // Button (outside scroll view)
        continueButton.setTitle("onboarding.privacy.agree".localized, for: .normal)
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        view.addSubview(continueButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            scrollView.bottomAnchor.constraint(equalTo: continueButton.topAnchor, constant: -20),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -80)
        ])
    }

    private func createConsentCard(icon: String, iconColor: UIColor, title: String, detail: String, toggle: UISwitch) -> UIView {
        let card = UIView()
        card.backgroundColor = AIONDesign.surface
        card.layer.cornerRadius = AIONDesign.cornerRadius
        card.translatesAutoresizingMaskIntoConstraints = false

        let iconBg = UIView()
        iconBg.backgroundColor = iconColor.withAlphaComponent(0.15)
        iconBg.layer.cornerRadius = 20
        iconBg.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView()
        iconView.image = UIImage(systemName: icon)
        iconView.tintColor = iconColor
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = AIONDesign.textPrimary
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let detailLabel = UILabel()
        detailLabel.text = detail
        detailLabel.font = .systemFont(ofSize: 13, weight: .regular)
        detailLabel.textColor = AIONDesign.textSecondary
        detailLabel.numberOfLines = 0
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        toggle.translatesAutoresizingMaskIntoConstraints = false

        iconBg.addSubview(iconView)
        card.addSubview(iconBg)
        card.addSubview(titleLabel)
        card.addSubview(detailLabel)
        card.addSubview(toggle)

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),

            iconBg.widthAnchor.constraint(equalToConstant: 40),
            iconBg.heightAnchor.constraint(equalToConstant: 40),
            iconBg.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            isRTL ?
                iconBg.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16) :
                iconBg.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            iconView.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),

            toggle.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            isRTL ?
                toggle.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16) :
                toggle.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            isRTL ?
                titleLabel.trailingAnchor.constraint(equalTo: iconBg.leadingAnchor, constant: -12) :
                titleLabel.leadingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 12),
            isRTL ?
                titleLabel.leadingAnchor.constraint(equalTo: toggle.trailingAnchor, constant: 12) :
                titleLabel.trailingAnchor.constraint(equalTo: toggle.leadingAnchor, constant: -12),

            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            isRTL ?
                detailLabel.trailingAnchor.constraint(equalTo: iconBg.leadingAnchor, constant: -12) :
                detailLabel.leadingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 12),
            isRTL ?
                detailLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16) :
                detailLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            detailLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        return card
    }

    // MARK: - Actions

    @objc private func aiToggleChanged() {
        aiConsentEnabled = aiToggle.isOn
    }

    @objc private func leaderboardToggleChanged() {
        leaderboardEnabled = leaderboardToggle.isOn
    }

    @objc private func continueTapped() {
        // Save consent choices
        ConsentManager.hasAIConsent = aiConsentEnabled
        ConsentManager.hasLeaderboardConsent = leaderboardEnabled

        print("[Consent] AI=\(aiConsentEnabled), Leaderboard=\(leaderboardEnabled)")

        continueButton.springAnimation {
            self.delegate?.onboardingDidRequestNext()
        }
    }
}
