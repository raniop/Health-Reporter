//
//  BedtimeNotificationSettingsViewController.swift
//  Health Reporter
//
//  Bedtime recommendation notification settings screen.
//  Simpler than morning notification settings (no content toggles - Gemini generates everything).
//

import UIKit

final class BedtimeNotificationSettingsViewController: UIViewController {

    // MARK: - UI Elements

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // Enable toggle
    private let enableCard = UIView()
    private let enableSwitch = UISwitch()

    // Time picker
    private let timeCard = UIView()
    private let timePicker = UIDatePicker()

    // Sleep goal
    private let sleepGoalCard = UIView()
    private let sleepGoalValueLabel = UILabel()
    private let sleepGoalStepper = UIStepper()

    // Test button
    private let testButton = UIButton(type: .system)

    private let manager = BedtimeNotificationManager.shared

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "settings.bedtimeNotification.title".localized
        view.backgroundColor = AIONDesign.background
        view.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute

        setupUI()
        loadCurrentSettings()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        FriendsFirestoreSync.refreshAndSaveFCMToken()
        manager.syncSettingsToFirestore()
    }

    // MARK: - Setup UI

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

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

        setupEnableCard()
        setupTimeCard()
        setupSleepGoalCard()
        setupTestButton()
    }

    // MARK: - Enable Card

    private func setupEnableCard() {
        enableCard.backgroundColor = AIONDesign.surface
        enableCard.layer.cornerRadius = AIONDesign.cornerRadius
        enableCard.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: UIImage(systemName: "moon.stars.fill"))
        iconView.tintColor = AIONDesign.accentPrimary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "settings.bedtimeNotification.enable".localized
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = AIONDesign.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = UILabel()
        subtitleLabel.text = "settings.bedtimeNotification.enableDescription".localized
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
        titleLabel.text = "settings.bedtimeNotification.time".localized
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

    // MARK: - Sleep Goal Card

    private func setupSleepGoalCard() {
        sleepGoalCard.backgroundColor = AIONDesign.surface
        sleepGoalCard.layer.cornerRadius = AIONDesign.cornerRadius
        sleepGoalCard.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: UIImage(systemName: "bed.double.fill"))
        iconView.tintColor = AIONDesign.accentPrimary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "settings.bedtimeNotification.sleepGoal".localized
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = AIONDesign.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        sleepGoalValueLabel.font = .monospacedDigitSystemFont(ofSize: 16, weight: .bold)
        sleepGoalValueLabel.textColor = AIONDesign.accentPrimary
        sleepGoalValueLabel.translatesAutoresizingMaskIntoConstraints = false

        sleepGoalStepper.minimumValue = 6.0
        sleepGoalStepper.maximumValue = 10.0
        sleepGoalStepper.stepValue = 0.25
        sleepGoalStepper.tintColor = AIONDesign.accentPrimary
        sleepGoalStepper.translatesAutoresizingMaskIntoConstraints = false
        sleepGoalStepper.addTarget(self, action: #selector(sleepGoalStepperChanged), for: .valueChanged)

        let valueStack = UIStackView(arrangedSubviews: [sleepGoalValueLabel, sleepGoalStepper])
        valueStack.axis = .horizontal
        valueStack.spacing = 10
        valueStack.alignment = .center
        valueStack.translatesAutoresizingMaskIntoConstraints = false

        sleepGoalCard.addSubview(iconView)
        sleepGoalCard.addSubview(titleLabel)
        sleepGoalCard.addSubview(valueStack)

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        NSLayoutConstraint.activate([
            sleepGoalCard.heightAnchor.constraint(equalToConstant: 64),

            iconView.centerYAnchor.constraint(equalTo: sleepGoalCard.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            titleLabel.centerYAnchor.constraint(equalTo: sleepGoalCard.centerYAnchor),

            valueStack.centerYAnchor.constraint(equalTo: sleepGoalCard.centerYAnchor),
        ])

        if isRTL {
            NSLayoutConstraint.activate([
                iconView.trailingAnchor.constraint(equalTo: sleepGoalCard.trailingAnchor, constant: -AIONDesign.spacing),
                titleLabel.trailingAnchor.constraint(equalTo: iconView.leadingAnchor, constant: -12),
                valueStack.leadingAnchor.constraint(equalTo: sleepGoalCard.leadingAnchor, constant: AIONDesign.spacing),
            ])
        } else {
            NSLayoutConstraint.activate([
                iconView.leadingAnchor.constraint(equalTo: sleepGoalCard.leadingAnchor, constant: AIONDesign.spacing),
                titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
                valueStack.trailingAnchor.constraint(equalTo: sleepGoalCard.trailingAnchor, constant: -AIONDesign.spacing),
            ])
        }

        contentStack.addArrangedSubview(sleepGoalCard)
    }

    // MARK: - Test Button

    private func setupTestButton() {
        testButton.setTitle("settings.bedtimeNotification.test".localized, for: .normal)
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

        var components = DateComponents()
        components.hour = manager.notificationHour
        components.minute = manager.notificationMinute
        if let date = Calendar.current.date(from: components) {
            timePicker.date = date
        }

        sleepGoalStepper.value = manager.sleepGoalHours
        updateSleepGoalLabel()

        updateUIState()
    }

    private func updateUIState() {
        let enabled = enableSwitch.isOn
        timeCard.alpha = enabled ? 1.0 : 0.5
        sleepGoalCard.alpha = enabled ? 1.0 : 0.5
        testButton.alpha = enabled ? 1.0 : 0.5

        timePicker.isEnabled = enabled
        sleepGoalStepper.isEnabled = enabled
        testButton.isEnabled = enabled
    }

    private func updateSleepGoalLabel() {
        let hours = sleepGoalStepper.value
        let h = Int(hours)
        let m = Int(round((hours - Double(h)) * 60))
        sleepGoalValueLabel.text = String(format: "%dh %02dm", h, m)
    }

    // MARK: - Actions

    @objc private func enableSwitchChanged() {
        manager.isEnabled = enableSwitch.isOn
        updateUIState()

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @objc private func timePickerChanged() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: timePicker.date)
        manager.notificationHour = components.hour ?? 19
        manager.notificationMinute = components.minute ?? 0
    }

    @objc private func sleepGoalStepperChanged() {
        manager.sleepGoalHours = sleepGoalStepper.value
        updateSleepGoalLabel()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @objc private func testButtonTapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        manager.sendTestNotification()

        let alert = UIAlertController(
            title: "settings.bedtimeNotification.testSent".localized,
            message: "settings.bedtimeNotification.testSentMessage".localized,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "ok".localized, style: .default))
        present(alert, animated: true)
    }
}
