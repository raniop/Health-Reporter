//
//  MorningNotificationSettingsViewController.swift
//  Health Reporter
//
//  Daily morning notification settings screen.
//

import UIKit

final class MorningNotificationSettingsViewController: UIViewController {

    // MARK: - UI Elements

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // Enable toggle
    private let enableCard = UIView()
    private let enableSwitch = UISwitch()

    // Time picker
    private let timeCard = UIView()
    private let timePicker = UIDatePicker()

    // Content preferences
    private let contentCard = UIView()
    private var recoverySwitch: UISwitch!
    private var sleepSwitch: UISwitch!
    private var scoreSwitch: UISwitch!
    private var motivationSwitch: UISwitch!
    private var achievementsSwitch: UISwitch!

    // Test button
    private let testButton = UIButton(type: .system)

    private let manager = MorningNotificationManager.shared

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "settings.morningNotification.title".localized
        view.backgroundColor = AIONDesign.background
        view.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute

        setupUI()
        loadCurrentSettings()
    }

    // MARK: - Setup UI

    private func setupUI() {
        // Scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        // Content stack
        contentStack.axis = .vertical
        contentStack.spacing = AIONDesign.spacingLarge
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: AIONDesign.spacingLarge),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: AIONDesign.spacing),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -AIONDesign.spacing),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -AIONDesign.spacingLarge),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -AIONDesign.spacing * 2),
        ])

        // Setup cards
        setupEnableCard()
        setupTimeCard()
        setupContentCard()
        setupTestButton()
    }

    // MARK: - Enable Card

    private func setupEnableCard() {
        enableCard.backgroundColor = AIONDesign.surface
        enableCard.layer.cornerRadius = AIONDesign.cornerRadius
        enableCard.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: UIImage(systemName: "bell.badge.fill"))
        iconView.tintColor = AIONDesign.accentPrimary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "settings.morningNotification.enable".localized
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = AIONDesign.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = UILabel()
        subtitleLabel.text = "settings.morningNotification.enableDescription".localized
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = AIONDesign.textSecondary
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        enableSwitch.onTintColor = AIONDesign.accentPrimary
        enableSwitch.translatesAutoresizingMaskIntoConstraints = false
        enableSwitch.addTarget(self, action: #selector(enableSwitchChanged), for: .valueChanged)

        enableCard.addSubview(iconView)
        enableCard.addSubview(titleLabel)
        enableCard.addSubview(subtitleLabel)
        enableCard.addSubview(enableSwitch)

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        NSLayoutConstraint.activate([
            enableCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),

            iconView.centerYAnchor.constraint(equalTo: enableCard.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            enableSwitch.centerYAnchor.constraint(equalTo: enableCard.centerYAnchor),

            titleLabel.topAnchor.constraint(equalTo: enableCard.topAnchor, constant: 16),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: enableCard.bottomAnchor, constant: -16),
        ])

        if isRTL {
            NSLayoutConstraint.activate([
                iconView.trailingAnchor.constraint(equalTo: enableCard.trailingAnchor, constant: -AIONDesign.spacing),
                titleLabel.trailingAnchor.constraint(equalTo: iconView.leadingAnchor, constant: -12),
                titleLabel.leadingAnchor.constraint(equalTo: enableSwitch.trailingAnchor, constant: 12),
                subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
                subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
                enableSwitch.leadingAnchor.constraint(equalTo: enableCard.leadingAnchor, constant: AIONDesign.spacing),
            ])
        } else {
            NSLayoutConstraint.activate([
                iconView.leadingAnchor.constraint(equalTo: enableCard.leadingAnchor, constant: AIONDesign.spacing),
                titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
                titleLabel.trailingAnchor.constraint(equalTo: enableSwitch.leadingAnchor, constant: -12),
                subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
                subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
                enableSwitch.trailingAnchor.constraint(equalTo: enableCard.trailingAnchor, constant: -AIONDesign.spacing),
            ])
        }

        contentStack.addArrangedSubview(enableCard)
    }

    // MARK: - Time Card

    private func setupTimeCard() {
        timeCard.backgroundColor = AIONDesign.surface
        timeCard.layer.cornerRadius = AIONDesign.cornerRadius
        timeCard.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: UIImage(systemName: "clock.fill"))
        iconView.tintColor = AIONDesign.accentPrimary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "settings.morningNotification.time".localized
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = AIONDesign.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        timePicker.datePickerMode = .time
        timePicker.preferredDatePickerStyle = .compact
        timePicker.tintColor = AIONDesign.accentPrimary
        timePicker.translatesAutoresizingMaskIntoConstraints = false
        timePicker.addTarget(self, action: #selector(timePickerChanged), for: .valueChanged)

        timeCard.addSubview(iconView)
        timeCard.addSubview(titleLabel)
        timeCard.addSubview(timePicker)

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        NSLayoutConstraint.activate([
            timeCard.heightAnchor.constraint(equalToConstant: 64),

            iconView.centerYAnchor.constraint(equalTo: timeCard.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            titleLabel.centerYAnchor.constraint(equalTo: timeCard.centerYAnchor),

            timePicker.centerYAnchor.constraint(equalTo: timeCard.centerYAnchor),
        ])

        if isRTL {
            NSLayoutConstraint.activate([
                iconView.trailingAnchor.constraint(equalTo: timeCard.trailingAnchor, constant: -AIONDesign.spacing),
                titleLabel.trailingAnchor.constraint(equalTo: iconView.leadingAnchor, constant: -12),
                timePicker.leadingAnchor.constraint(equalTo: timeCard.leadingAnchor, constant: AIONDesign.spacing),
            ])
        } else {
            NSLayoutConstraint.activate([
                iconView.leadingAnchor.constraint(equalTo: timeCard.leadingAnchor, constant: AIONDesign.spacing),
                titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
                timePicker.trailingAnchor.constraint(equalTo: timeCard.trailingAnchor, constant: -AIONDesign.spacing),
            ])
        }

        contentStack.addArrangedSubview(timeCard)
    }

    // MARK: - Content Card

    private func setupContentCard() {
        contentCard.backgroundColor = AIONDesign.surface
        contentCard.layer.cornerRadius = AIONDesign.cornerRadius
        contentCard.translatesAutoresizingMaskIntoConstraints = false

        let headerLabel = UILabel()
        headerLabel.text = "settings.morningNotification.content".localized
        headerLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        headerLabel.textColor = AIONDesign.textPrimary
        headerLabel.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: UIImage(systemName: "text.badge.checkmark"))
        iconView.tintColor = AIONDesign.accentPrimary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let optionsStack = UIStackView()
        optionsStack.axis = .vertical
        optionsStack.spacing = 12
        optionsStack.translatesAutoresizingMaskIntoConstraints = false

        // Create toggle rows
        recoverySwitch = UISwitch()
        sleepSwitch = UISwitch()
        scoreSwitch = UISwitch()
        motivationSwitch = UISwitch()
        achievementsSwitch = UISwitch()

        let options: [(String, UISwitch, Selector)] = [
            ("settings.morningNotification.includeRecovery".localized, recoverySwitch, #selector(recoverySwitchChanged)),
            ("settings.morningNotification.includeSleep".localized, sleepSwitch, #selector(sleepSwitchChanged)),
            ("settings.morningNotification.includeScore".localized, scoreSwitch, #selector(scoreSwitchChanged)),
            ("settings.morningNotification.includeMotivation".localized, motivationSwitch, #selector(motivationSwitchChanged)),
            ("settings.morningNotification.includeAchievements".localized, achievementsSwitch, #selector(achievementsSwitchChanged)),
        ]

        for (title, toggle, action) in options {
            let row = createToggleRow(title: title, toggle: toggle, action: action)
            optionsStack.addArrangedSubview(row)
        }

        contentCard.addSubview(iconView)
        contentCard.addSubview(headerLabel)
        contentCard.addSubview(optionsStack)

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: contentCard.topAnchor, constant: 16),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            headerLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),

            optionsStack.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 16),
            optionsStack.leadingAnchor.constraint(equalTo: contentCard.leadingAnchor, constant: AIONDesign.spacing),
            optionsStack.trailingAnchor.constraint(equalTo: contentCard.trailingAnchor, constant: -AIONDesign.spacing),
            optionsStack.bottomAnchor.constraint(equalTo: contentCard.bottomAnchor, constant: -16),
        ])

        if isRTL {
            NSLayoutConstraint.activate([
                iconView.trailingAnchor.constraint(equalTo: contentCard.trailingAnchor, constant: -AIONDesign.spacing),
                headerLabel.trailingAnchor.constraint(equalTo: iconView.leadingAnchor, constant: -10),
            ])
        } else {
            NSLayoutConstraint.activate([
                iconView.leadingAnchor.constraint(equalTo: contentCard.leadingAnchor, constant: AIONDesign.spacing),
                headerLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            ])
        }

        contentStack.addArrangedSubview(contentCard)
    }

    private func createToggleRow(title: String, toggle: UISwitch, action: Selector) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = AIONDesign.textPrimary
        label.translatesAutoresizingMaskIntoConstraints = false

        toggle.onTintColor = AIONDesign.accentPrimary
        toggle.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.addTarget(self, action: action, for: .valueChanged)

        row.addSubview(label)
        row.addSubview(toggle)

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 36),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            toggle.centerYAnchor.constraint(equalTo: row.centerYAnchor),
        ])

        if isRTL {
            NSLayoutConstraint.activate([
                label.trailingAnchor.constraint(equalTo: row.trailingAnchor),
                toggle.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            ])
        } else {
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: row.leadingAnchor),
                toggle.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            ])
        }

        return row
    }

    // MARK: - Test Button

    private func setupTestButton() {
        testButton.setTitle("settings.morningNotification.test".localized, for: .normal)
        testButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        testButton.setTitleColor(.white, for: .normal)
        testButton.backgroundColor = AIONDesign.accentPrimary
        testButton.layer.cornerRadius = AIONDesign.cornerRadius
        testButton.translatesAutoresizingMaskIntoConstraints = false
        testButton.addTarget(self, action: #selector(testButtonTapped), for: .touchUpInside)

        contentStack.addArrangedSubview(testButton)

        NSLayoutConstraint.activate([
            testButton.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    // MARK: - Load Settings

    private func loadCurrentSettings() {
        enableSwitch.isOn = manager.isEnabled

        // Set time picker
        var components = DateComponents()
        components.hour = manager.notificationHour
        components.minute = manager.notificationMinute
        if let date = Calendar.current.date(from: components) {
            timePicker.date = date
        }

        // Set content toggles
        recoverySwitch.isOn = manager.includeRecovery
        sleepSwitch.isOn = manager.includeSleep
        scoreSwitch.isOn = manager.includeScore
        motivationSwitch.isOn = manager.includeMotivation
        achievementsSwitch.isOn = manager.includeAchievements

        updateUIState()
    }

    private func updateUIState() {
        let enabled = enableSwitch.isOn
        timeCard.alpha = enabled ? 1.0 : 0.5
        contentCard.alpha = enabled ? 1.0 : 0.5
        testButton.alpha = enabled ? 1.0 : 0.5

        timePicker.isEnabled = enabled
        recoverySwitch.isEnabled = enabled
        sleepSwitch.isEnabled = enabled
        scoreSwitch.isEnabled = enabled
        motivationSwitch.isEnabled = enabled
        achievementsSwitch.isEnabled = enabled
        testButton.isEnabled = enabled
    }

    // MARK: - Actions

    @objc private func enableSwitchChanged() {
        manager.isEnabled = enableSwitch.isOn
        updateUIState()

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @objc private func timePickerChanged() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: timePicker.date)
        manager.notificationHour = components.hour ?? 8
        manager.notificationMinute = components.minute ?? 0
    }

    @objc private func recoverySwitchChanged() {
        manager.includeRecovery = recoverySwitch.isOn
    }

    @objc private func sleepSwitchChanged() {
        manager.includeSleep = sleepSwitch.isOn
    }

    @objc private func scoreSwitchChanged() {
        manager.includeScore = scoreSwitch.isOn
    }

    @objc private func motivationSwitchChanged() {
        manager.includeMotivation = motivationSwitch.isOn
    }

    @objc private func achievementsSwitchChanged() {
        manager.includeAchievements = achievementsSwitch.isOn
    }

    @objc private func testButtonTapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        manager.sendTestNotification()

        let alert = UIAlertController(
            title: "settings.morningNotification.testSent".localized,
            message: "settings.morningNotification.testSentMessage".localized,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "ok".localized, style: .default))
        present(alert, animated: true)
    }
}
