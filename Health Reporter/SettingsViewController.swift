//
//  SettingsViewController.swift
//  Health Reporter
//
//  Settings screen extracted from ProfileViewController.
//  Data source, background color, language, notifications, follow privacy, logout.
//

import UIKit
import FirebaseAuth

final class SettingsViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let logoutButton = UIButton(type: .system)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "settings.title".localized
        view.backgroundColor = AIONDesign.background
        view.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        setupUI()

        NotificationCenter.default.addObserver(self, selector: #selector(dataSourceDidChange), name: .dataSourceChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(backgroundColorDidChange), name: .backgroundColorChanged, object: nil)

        AnalyticsService.shared.logScreenView(.settings)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateNotificationCardSubtitle()
        updateBedtimeCardSubtitle()
    }

    // MARK: - UI Setup

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        view.addSubview(scrollView)

        stack.axis = .vertical
        stack.spacing = 0
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        // 1. Data Source Card
        let dataSourceCard = makeSettingsCard(
            icon: "antenna.radiowaves.left.and.right",
            title: "profile.dataSource".localized,
            subtitle: DataSourceManager.shared.effectiveSource().displayName
        )
        dataSourceCard.tag = 999
        let dataSourceTap = UITapGestureRecognizer(target: self, action: #selector(dataSourceTapped))
        dataSourceCard.addGestureRecognizer(dataSourceTap)
        stack.addArrangedSubview(dataSourceCard)

        NSLayoutConstraint.activate([
            dataSourceCard.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            dataSourceCard.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
        ])

        stack.setCustomSpacing(AIONDesign.spacingLarge, after: dataSourceCard)

        // 2. Background Color Card
        let bgColorCard = makeBackgroundColorCard()
        stack.addArrangedSubview(bgColorCard)

        NSLayoutConstraint.activate([
            bgColorCard.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            bgColorCard.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
        ])

        stack.setCustomSpacing(AIONDesign.spacingLarge, after: bgColorCard)

        // 3. Language Card
        let languageCard = makeLanguageCard()
        stack.addArrangedSubview(languageCard)

        NSLayoutConstraint.activate([
            languageCard.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            languageCard.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
        ])

        stack.setCustomSpacing(AIONDesign.spacingLarge, after: languageCard)

        // 4. Morning Notification Card
        let notificationCard = makeSettingsCard(
            icon: "bell.badge.fill",
            title: "profile.morningNotification".localized,
            subtitle: MorningNotificationManager.shared.isEnabled
                ? String(format: "profile.notificationTime".localized, MorningNotificationManager.shared.formattedTime)
                : "profile.notificationOff".localized
        )
        notificationCard.tag = 994
        let notificationTap = UITapGestureRecognizer(target: self, action: #selector(notificationSettingsTapped))
        notificationCard.addGestureRecognizer(notificationTap)
        stack.addArrangedSubview(notificationCard)

        NSLayoutConstraint.activate([
            notificationCard.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            notificationCard.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
        ])

        stack.setCustomSpacing(AIONDesign.spacingLarge, after: notificationCard)

        // 4b. Bedtime Notification Card
        let bedtimeCard = makeSettingsCard(
            icon: "moon.stars.fill",
            title: "profile.bedtimeNotification".localized,
            subtitle: BedtimeNotificationManager.shared.isEnabled
                ? String(format: "profile.notificationTime".localized, BedtimeNotificationManager.shared.formattedTime)
                : "profile.notificationOff".localized
        )
        bedtimeCard.tag = 993
        let bedtimeTap = UITapGestureRecognizer(target: self, action: #selector(bedtimeSettingsTapped))
        bedtimeCard.addGestureRecognizer(bedtimeTap)
        stack.addArrangedSubview(bedtimeCard)

        NSLayoutConstraint.activate([
            bedtimeCard.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            bedtimeCard.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
        ])

        stack.setCustomSpacing(AIONDesign.spacingLarge, after: bedtimeCard)

        // 5. Follow Privacy Card
        let followPrivacyCard = makeFollowPrivacyCard()
        stack.addArrangedSubview(followPrivacyCard)

        NSLayoutConstraint.activate([
            followPrivacyCard.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            followPrivacyCard.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
        ])

        stack.setCustomSpacing(AIONDesign.spacingLarge, after: followPrivacyCard)

        // 6. Logout Button
        logoutButton.setTitle("profile.logout".localized, for: .normal)
        logoutButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        logoutButton.setTitleColor(AIONDesign.textTertiary, for: .normal)
        logoutButton.backgroundColor = .clear
        logoutButton.layer.cornerRadius = AIONDesign.cornerRadius
        logoutButton.layer.borderWidth = 0.5
        logoutButton.layer.borderColor = AIONDesign.separator.cgColor
        logoutButton.translatesAutoresizingMaskIntoConstraints = false
        logoutButton.addTarget(self, action: #selector(logoutTapped), for: .touchUpInside)

        let logoutContainer = UIView()
        logoutContainer.translatesAutoresizingMaskIntoConstraints = false
        logoutContainer.addSubview(logoutButton)
        view.addSubview(logoutContainer)

        NSLayoutConstraint.activate([
            logoutButton.heightAnchor.constraint(equalToConstant: 34),
            logoutButton.widthAnchor.constraint(equalToConstant: 90),
            logoutButton.centerXAnchor.constraint(equalTo: logoutContainer.centerXAnchor),
            logoutButton.topAnchor.constraint(equalTo: logoutContainer.topAnchor, constant: 10),
            logoutButton.bottomAnchor.constraint(equalTo: logoutContainer.bottomAnchor, constant: -10),
        ])

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: logoutContainer.topAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: AIONDesign.spacingLarge * 1.5),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: AIONDesign.spacing),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -AIONDesign.spacing),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -AIONDesign.spacingLarge * 1.5),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -AIONDesign.spacing * 2),

            logoutContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            logoutContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            logoutContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    // MARK: - Settings Card Builder

    private func makeSettingsCard(icon: String, title: String, subtitle: String) -> UIView {
        let card = UIView()
        card.backgroundColor = AIONDesign.surface
        card.layer.cornerRadius = AIONDesign.cornerRadius
        card.translatesAutoresizingMaskIntoConstraints = false
        card.isUserInteractionEnabled = true

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = AIONDesign.accentPrimary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = AIONDesign.textPrimary
        titleLabel.textAlignment = LocalizationManager.shared.textAlignment
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = AIONDesign.textSecondary
        subtitleLabel.textAlignment = LocalizationManager.shared.textAlignment
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL
        let chevron = UIImageView(image: UIImage(systemName: isRTL ? "chevron.left" : "chevron.right"))
        chevron.tintColor = AIONDesign.textTertiary
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(iconView)
        card.addSubview(titleLabel)
        card.addSubview(subtitleLabel)
        card.addSubview(chevron)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 64),

            iconView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),

            chevron.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 16),
            chevron.heightAnchor.constraint(equalToConstant: 16),
        ])

        if isRTL {
            NSLayoutConstraint.activate([
                iconView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -AIONDesign.spacing),
                titleLabel.trailingAnchor.constraint(equalTo: iconView.leadingAnchor, constant: -12),
                subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
                chevron.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: AIONDesign.spacing),
            ])
        } else {
            NSLayoutConstraint.activate([
                iconView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: AIONDesign.spacing),
                titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
                subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
                chevron.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -AIONDesign.spacing),
            ])
        }

        return card
    }

    // MARK: - Data Source

    @objc private func dataSourceTapped() {
        let vc = DataSourceSettingsViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func dataSourceDidChange() {
        if let card = stack.viewWithTag(999) {
            for subview in card.subviews {
                if let label = subview as? UILabel,
                   label.font == .systemFont(ofSize: 13, weight: .regular) {
                    label.text = DataSourceManager.shared.effectiveSource().displayName
                    break
                }
            }
        }
    }

    // MARK: - Background Color

    private func makeBackgroundColorCard() -> UIView {
        let card = UIView()
        card.backgroundColor = AIONDesign.surface
        card.layer.cornerRadius = AIONDesign.cornerRadius
        card.translatesAutoresizingMaskIntoConstraints = false
        card.tag = 998

        let titleLabel = UILabel()
        titleLabel.text = "profile.backgroundColor".localized
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = AIONDesign.textPrimary
        titleLabel.textAlignment = LocalizationManager.shared.textAlignment
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: UIImage(systemName: "paintpalette.fill"))
        iconView.tintColor = AIONDesign.accentPrimary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let colorsStack = UIStackView()
        colorsStack.axis = .horizontal
        colorsStack.spacing = 8
        colorsStack.distribution = .fillEqually
        colorsStack.translatesAutoresizingMaskIntoConstraints = false
        colorsStack.tag = 997

        for (index, bgColor) in BackgroundColor.allCases.enumerated() {
            let colorView = makeColorOption(bgColor, index: index)
            colorsStack.addArrangedSubview(colorView)
        }

        card.addSubview(titleLabel)
        card.addSubview(iconView)
        card.addSubview(colorsStack)

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),

            colorsStack.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 14),
            colorsStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: AIONDesign.spacing),
            colorsStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -AIONDesign.spacing),
            colorsStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -AIONDesign.spacing),
            colorsStack.heightAnchor.constraint(equalToConstant: 44),
        ])

        if isRTL {
            NSLayoutConstraint.activate([
                iconView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -AIONDesign.spacing),
                titleLabel.trailingAnchor.constraint(equalTo: iconView.leadingAnchor, constant: -10),
            ])
        } else {
            NSLayoutConstraint.activate([
                iconView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: AIONDesign.spacing),
                titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            ])
        }

        return card
    }

    private func makeColorOption(_ bgColor: BackgroundColor, index: Int) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.tag = index

        let colorCircle = UIView()
        colorCircle.backgroundColor = bgColor.color
        colorCircle.layer.cornerRadius = 18
        colorCircle.layer.borderWidth = bgColor == BackgroundColor.current ? 3 : 2
        colorCircle.layer.borderColor = bgColor == BackgroundColor.current
            ? AIONDesign.accentPrimary.cgColor
            : AIONDesign.textTertiary.cgColor
        colorCircle.translatesAutoresizingMaskIntoConstraints = false
        colorCircle.tag = 100 + index

        container.addSubview(colorCircle)

        NSLayoutConstraint.activate([
            colorCircle.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            colorCircle.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            colorCircle.widthAnchor.constraint(equalToConstant: 36),
            colorCircle.heightAnchor.constraint(equalToConstant: 36),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(backgroundColorTapped(_:)))
        container.addGestureRecognizer(tap)
        container.isUserInteractionEnabled = true

        return container
    }

    @objc private func backgroundColorTapped(_ sender: UITapGestureRecognizer) {
        guard let tappedView = sender.view,
              tappedView.tag < BackgroundColor.allCases.count else { return }

        let selectedColor = BackgroundColor.allCases[tappedView.tag]

        guard selectedColor != BackgroundColor.current else { return }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        let alert = UIAlertController(
            title: "profile.backgroundColorChange".localized,
            message: "profile.backgroundColorMessage".localized,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "cancel".localized, style: .cancel))

        alert.addAction(UIAlertAction(title: "profile.confirmAndClose".localized, style: .default) { [weak self] _ in
            BackgroundColor.current = selectedColor
            self?.updateBackgroundColorSelection()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                exit(0)
            }
        })

        present(alert, animated: true)
    }

    private func updateBackgroundColorSelection() {
        guard let card = stack.viewWithTag(998),
              let colorsStack = card.viewWithTag(997) as? UIStackView else { return }

        for (index, container) in colorsStack.arrangedSubviews.enumerated() {
            guard let colorCircle = container.viewWithTag(100 + index) else { continue }
            let bgColor = BackgroundColor.allCases[index]
            colorCircle.layer.borderWidth = bgColor == BackgroundColor.current ? 3 : 2
            colorCircle.layer.borderColor = bgColor == BackgroundColor.current
                ? AIONDesign.accentPrimary.cgColor
                : AIONDesign.textTertiary.cgColor
        }
    }

    // MARK: - Language Selection

    private func makeLanguageCard() -> UIView {
        let card = UIView()
        card.backgroundColor = AIONDesign.surface
        card.layer.cornerRadius = AIONDesign.cornerRadius
        card.translatesAutoresizingMaskIntoConstraints = false
        card.tag = 996

        let titleLabel = UILabel()
        titleLabel.text = "profile.language".localized
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = AIONDesign.textPrimary
        titleLabel.textAlignment = LocalizationManager.shared.textAlignment
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: UIImage(systemName: "globe"))
        iconView.tintColor = AIONDesign.accentPrimary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let languagesStack = UIStackView()
        languagesStack.axis = .horizontal
        languagesStack.spacing = 12
        languagesStack.distribution = .fillEqually
        languagesStack.translatesAutoresizingMaskIntoConstraints = false
        languagesStack.tag = 995

        for lang in AppLanguage.allCases {
            let btn = makeLanguageButton(lang)
            languagesStack.addArrangedSubview(btn)
        }

        card.addSubview(titleLabel)
        card.addSubview(iconView)
        card.addSubview(languagesStack)

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        var iconConstraints: [NSLayoutConstraint] = [
            iconView.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
        ]

        if isRTL {
            iconConstraints.append(iconView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -AIONDesign.spacing))
        } else {
            iconConstraints.append(iconView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: AIONDesign.spacing))
        }

        NSLayoutConstraint.activate(iconConstraints)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: isRTL ? card.leadingAnchor : iconView.trailingAnchor, constant: isRTL ? AIONDesign.spacing : 10),
            titleLabel.trailingAnchor.constraint(equalTo: isRTL ? iconView.leadingAnchor : card.trailingAnchor, constant: isRTL ? -10 : -AIONDesign.spacing),
            titleLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),

            languagesStack.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 14),
            languagesStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: AIONDesign.spacing),
            languagesStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -AIONDesign.spacing),
            languagesStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -AIONDesign.spacing),
            languagesStack.heightAnchor.constraint(equalToConstant: 44),
        ])

        return card
    }

    private func makeLanguageButton(_ language: AppLanguage) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(language.displayName, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        btn.layer.cornerRadius = 8
        btn.translatesAutoresizingMaskIntoConstraints = false

        let isSelected = language == LocalizationManager.shared.currentLanguage
        btn.backgroundColor = isSelected ? AIONDesign.accentPrimary : AIONDesign.background
        btn.setTitleColor(isSelected ? .white : AIONDesign.textPrimary, for: .normal)
        btn.layer.borderWidth = isSelected ? 0 : 1
        btn.layer.borderColor = AIONDesign.separator.cgColor

        btn.tag = language == .hebrew ? 0 : 1
        btn.addTarget(self, action: #selector(languageButtonTapped(_:)), for: .touchUpInside)

        return btn
    }

    @objc private func languageButtonTapped(_ sender: UIButton) {
        let selectedLanguage: AppLanguage = sender.tag == 0 ? .hebrew : .english

        guard selectedLanguage != LocalizationManager.shared.currentLanguage else { return }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        let alert = UIAlertController(
            title: "profile.changeLanguage".localized,
            message: "profile.languageChangeMessage".localized,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "cancel".localized, style: .cancel))

        alert.addAction(UIAlertAction(title: "ok".localized, style: .default) { _ in
            LocalizationManager.shared.setLanguage(selectedLanguage)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                exit(0)
            }
        })

        present(alert, animated: true)
    }

    // MARK: - Morning Notification

    @objc private func notificationSettingsTapped() {
        let vc = MorningNotificationSettingsViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    private func updateNotificationCardSubtitle() {
        if let card = stack.viewWithTag(994) {
            for subview in card.subviews {
                if let label = subview as? UILabel,
                   label.font == .systemFont(ofSize: 13, weight: .regular) {
                    label.text = MorningNotificationManager.shared.isEnabled
                        ? String(format: "profile.notificationTime".localized, MorningNotificationManager.shared.formattedTime)
                        : "profile.notificationOff".localized
                    break
                }
            }
        }
    }

    // MARK: - Bedtime Notification

    @objc private func bedtimeSettingsTapped() {
        let vc = BedtimeNotificationSettingsViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    private func updateBedtimeCardSubtitle() {
        if let card = stack.viewWithTag(993) {
            for subview in card.subviews {
                if let label = subview as? UILabel,
                   label.font == .systemFont(ofSize: 13, weight: .regular) {
                    label.text = BedtimeNotificationManager.shared.isEnabled
                        ? String(format: "profile.notificationTime".localized, BedtimeNotificationManager.shared.formattedTime)
                        : "profile.notificationOff".localized
                    break
                }
            }
        }
    }

    // MARK: - Follow Privacy

    private func makeFollowPrivacyCard() -> UIView {
        let card = UIView()
        card.backgroundColor = AIONDesign.surface
        card.layer.cornerRadius = AIONDesign.cornerRadius
        card.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: UIImage(systemName: "lock.shield"))
        iconView.tintColor = AIONDesign.accentPrimary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "profile.followPrivacy".localized
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = AIONDesign.textPrimary
        titleLabel.textAlignment = LocalizationManager.shared.textAlignment
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = UILabel()
        subtitleLabel.text = "profile.followPrivacyDescription".localized
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = AIONDesign.textSecondary
        subtitleLabel.textAlignment = LocalizationManager.shared.textAlignment
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let segmentedControl = UISegmentedControl(items: [
            "profile.followPrivacyOpen".localized,
            "profile.followPrivacyApproval".localized
        ])
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.addTarget(self, action: #selector(followPrivacyChanged(_:)), for: .valueChanged)

        // Load current privacy setting
        FollowFirestoreSync.getFollowPrivacy { privacy in
            DispatchQueue.main.async {
                switch privacy {
                case .open:
                    segmentedControl.selectedSegmentIndex = 0
                case .approval:
                    segmentedControl.selectedSegmentIndex = 1
                }
            }
        }

        card.addSubview(iconView)
        card.addSubview(titleLabel)
        card.addSubview(subtitleLabel)
        card.addSubview(segmentedControl)

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: AIONDesign.spacing),
            subtitleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -AIONDesign.spacing),

            segmentedControl.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 12),
            segmentedControl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: AIONDesign.spacing),
            segmentedControl.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -AIONDesign.spacing),
            segmentedControl.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -AIONDesign.spacing),
        ])

        if isRTL {
            NSLayoutConstraint.activate([
                iconView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -AIONDesign.spacing),
                titleLabel.trailingAnchor.constraint(equalTo: iconView.leadingAnchor, constant: -10),
            ])
        } else {
            NSLayoutConstraint.activate([
                iconView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: AIONDesign.spacing),
                titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            ])
        }

        return card
    }

    @objc private func followPrivacyChanged(_ sender: UISegmentedControl) {
        let privacy: FollowPrivacy = sender.selectedSegmentIndex == 0 ? .open : .approval
        FollowFirestoreSync.setFollowPrivacy(privacy)
    }

    // MARK: - Background Color Change Notification

    @objc private func backgroundColorDidChange() {
        view.backgroundColor = AIONDesign.background
        navigationController?.navigationBar.barStyle = AIONDesign.navBarStyle
        navigationController?.navigationBar.barTintColor = AIONDesign.background
        navigationController?.navigationBar.backgroundColor = AIONDesign.background
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: AIONDesign.textPrimary]
    }

    // MARK: - Logout

    @objc private func logoutTapped() {
        do {
            AnalyticsService.shared.logLogout()
            AnalyticsService.shared.resetAnalyticsData()
            FriendsFirestoreSync.removeFCMToken()
            AIONMemoryManager.clear()

            try Auth.auth().signOut()
            (view.window?.windowScene?.delegate as? SceneDelegate)?.showLogin()
        } catch {
            let alert = UIAlertController(title: "error".localized, message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "ok".localized, style: .default))
            present(alert, animated: true)
        }
    }
}
