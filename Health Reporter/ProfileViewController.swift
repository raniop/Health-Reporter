//
//  ProfileViewController.swift
//  Health Reporter
//
//  מסך פרופיל / Account – מדדים, מכשירים, הגדרות, התנתקות.
//

import UIKit
import FirebaseAuth
import HealthKit
import PhotosUI

private let kProfileBadge = "ProfileBadge"
private var profileBadgeOptions: [(title: String, value: String)] {
    [
        ("profile.athlete".localized, "athlete"),
        ("profile.beginner".localized, "beginner"),
        ("profile.amateur".localized, "amateur"),
        ("profile.professional".localized, "professional"),
    ]
}

final class ProfileViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let avatarView = UIView()
    private let avatarImageView = UIImageView()
    private let nameLabel = UILabel()
    private let badgeContainer = UIView()
    private let badgeLabel = UILabel()
    private let tierLabel = UILabel()
    private let metricsStack = UIStackView()
    private let logoutButton = UIButton(type: .system)
    private var heightValueLabel: UILabel?
    private var weightValueLabel: UILabel?
    private var ageValueLabel: UILabel?
    private var thirdMetricTitleLabel: UILabel?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "profile.title".localized
        view.backgroundColor = AIONDesign.background
        view.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        setupUI()
        updateUserInfo()
        loadProfilePhoto()

        // Listen for data source changes
        NotificationCenter.default.addObserver(self, selector: #selector(dataSourceDidChange), name: .dataSourceChanged, object: nil)

        // Listen for background color changes
        NotificationCenter.default.addObserver(self, selector: #selector(backgroundColorDidChange), name: .backgroundColorChanged, object: nil)

        // Analytics: Log screen view
        AnalyticsService.shared.logScreenView(.profile)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadProfileMetrics()
        loadProfilePhoto()
    }

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        view.addSubview(scrollView)
        stack.axis = .vertical
        stack.spacing = 0
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        avatarView.backgroundColor = AIONDesign.surface
        avatarView.layer.cornerRadius = 52
        avatarView.layer.borderWidth = 2
        avatarView.layer.borderColor = AIONDesign.accentPrimary.cgColor
        avatarView.clipsToBounds = true
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.isUserInteractionEnabled = true
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.layer.cornerRadius = 50
        avatarImageView.image = UIImage(systemName: "person.circle.fill")
        avatarImageView.tintColor = AIONDesign.textTertiary
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.addSubview(avatarImageView)
        let tap = UITapGestureRecognizer(target: self, action: #selector(changePhotoTapped))
        avatarView.addGestureRecognizer(tap)
        NSLayoutConstraint.activate([
            avatarImageView.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarImageView.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 100),
            avatarImageView.heightAnchor.constraint(equalToConstant: 100),
            avatarView.widthAnchor.constraint(equalToConstant: 104),
            avatarView.heightAnchor.constraint(equalToConstant: 104),
        ])

        nameLabel.text = "profile.user".localized
        nameLabel.font = .systemFont(ofSize: 24, weight: .bold)
        nameLabel.textColor = AIONDesign.textPrimary
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.isUserInteractionEnabled = true
        let nameTap = UITapGestureRecognizer(target: self, action: #selector(nameTapped))
        nameLabel.addGestureRecognizer(nameTap)

        let pencilBtn = UIButton(type: .system)
        pencilBtn.setImage(UIImage(systemName: "pencil"), for: .normal)
        pencilBtn.tintColor = AIONDesign.textTertiary
        pencilBtn.translatesAutoresizingMaskIntoConstraints = false
        pencilBtn.addTarget(self, action: #selector(nameTapped), for: .touchUpInside)

        let nameRowContainer = UIView()
        nameRowContainer.translatesAutoresizingMaskIntoConstraints = false
        nameRowContainer.addSubview(nameLabel)
        nameRowContainer.addSubview(pencilBtn)

        badgeContainer.backgroundColor = AIONDesign.surface
        badgeContainer.layer.cornerRadius = 14
        badgeContainer.layer.borderWidth = 2
        badgeContainer.layer.borderColor = AIONDesign.accentPrimary.cgColor
        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.isUserInteractionEnabled = true
        let badgeTap = UITapGestureRecognizer(target: self, action: #selector(badgeTapped))
        badgeContainer.addGestureRecognizer(badgeTap)
        badgeLabel.font = .systemFont(ofSize: 14, weight: .bold)
        badgeLabel.textColor = AIONDesign.accentPrimary
        badgeLabel.textAlignment = .center
        badgeLabel.adjustsFontSizeToFitWidth = true
        badgeLabel.minimumScaleFactor = 0.7
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.addSubview(badgeLabel)
        NSLayoutConstraint.activate([
            badgeLabel.topAnchor.constraint(equalTo: badgeContainer.topAnchor, constant: 10),
            badgeLabel.bottomAnchor.constraint(equalTo: badgeContainer.bottomAnchor, constant: -10),
            badgeLabel.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 20),
            badgeLabel.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -20),
        ])
        applySavedBadge()

        tierLabel.text = "Performance Tier: Pro Lab"
        tierLabel.font = .systemFont(ofSize: 12, weight: .medium)
        tierLabel.textColor = AIONDesign.textTertiary
        tierLabel.textAlignment = .center
        tierLabel.translatesAutoresizingMaskIntoConstraints = false

        metricsStack.axis = .horizontal
        metricsStack.spacing = AIONDesign.spacing
        metricsStack.distribution = .fillEqually
        metricsStack.translatesAutoresizingMaskIntoConstraints = false
        let (hCard, hLabel) = makeMetricCard("profile.height".localized, value: "—", unit: "unit.cm".localized, explanation: CardExplanations.profileHeight)
        let (wCard, wLabel) = makeMetricCard("profile.weight".localized, value: "—", unit: "unit.kg".localized, explanation: CardExplanations.profileWeight)
        let (ageCard, ageLabel) = makeMetricCard("profile.age".localized, value: "—", unit: "unit.years".localized, explanation: CardExplanations.profileAge)
        heightValueLabel = hLabel
        weightValueLabel = wLabel
        ageValueLabel = ageLabel
        thirdMetricTitleLabel = ageCard.subviews.compactMap { $0 as? UILabel }.first
        [hCard, wCard, ageCard].forEach { metricsStack.addArrangedSubview($0) }

        logoutButton.setTitle("profile.logout".localized, for: .normal)
        logoutButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        logoutButton.setTitleColor(AIONDesign.textTertiary, for: .normal)
        logoutButton.backgroundColor = .clear
        logoutButton.layer.cornerRadius = AIONDesign.cornerRadius
        logoutButton.layer.borderWidth = 0.5
        logoutButton.layer.borderColor = AIONDesign.separator.cgColor
        logoutButton.translatesAutoresizingMaskIntoConstraints = false
        logoutButton.addTarget(self, action: #selector(logoutTapped), for: .touchUpInside)

        stack.addArrangedSubview(avatarView)
        stack.addArrangedSubview(nameRowContainer)
        stack.addArrangedSubview(badgeContainer)
        stack.addArrangedSubview(tierLabel)
        stack.addArrangedSubview(metricsStack)

        NSLayoutConstraint.activate([
            nameRowContainer.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            nameRowContainer.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
            nameRowContainer.heightAnchor.constraint(equalToConstant: 40),
            nameLabel.centerXAnchor.constraint(equalTo: nameRowContainer.centerXAnchor),
            nameLabel.centerYAnchor.constraint(equalTo: nameRowContainer.centerYAnchor),
            pencilBtn.centerYAnchor.constraint(equalTo: nameRowContainer.centerYAnchor),
            pencilBtn.trailingAnchor.constraint(equalTo: nameRowContainer.trailingAnchor, constant: -16),
            pencilBtn.widthAnchor.constraint(equalToConstant: 28),
            pencilBtn.heightAnchor.constraint(equalToConstant: 28),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: pencilBtn.leadingAnchor, constant: -8),
            nameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: nameRowContainer.leadingAnchor, constant: 16),
            badgeContainer.widthAnchor.constraint(equalTo: nameLabel.widthAnchor, constant: 8 + 28),
        ])

        // Data Source Settings Card
        let dataSourceCard = makeSettingsCard(
            icon: "antenna.radiowaves.left.and.right",
            title: "profile.dataSource".localized,
            subtitle: DataSourceManager.shared.effectiveSource().displayName
        )
        dataSourceCard.tag = 999 // For updating later
        let dataSourceTap = UITapGestureRecognizer(target: self, action: #selector(dataSourceTapped))
        dataSourceCard.addGestureRecognizer(dataSourceTap)
        stack.addArrangedSubview(dataSourceCard)

        // Constraint for data source card width
        NSLayoutConstraint.activate([
            dataSourceCard.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            dataSourceCard.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
        ])

        // Background Color Card
        let bgColorCard = makeBackgroundColorCard()
        stack.addArrangedSubview(bgColorCard)

        NSLayoutConstraint.activate([
            bgColorCard.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            bgColorCard.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
        ])

        // Language Selection Card
        let languageCard = makeLanguageCard()
        stack.addArrangedSubview(languageCard)

        NSLayoutConstraint.activate([
            languageCard.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            languageCard.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
        ])

        stack.setCustomSpacing(6, after: avatarView)
        stack.setCustomSpacing(12, after: nameRowContainer)
        stack.setCustomSpacing(6, after: badgeContainer)
        stack.setCustomSpacing(AIONDesign.spacingLarge * 2, after: tierLabel)
        stack.setCustomSpacing(AIONDesign.spacingLarge, after: metricsStack)
        stack.setCustomSpacing(AIONDesign.spacingLarge, after: dataSourceCard)
        stack.setCustomSpacing(AIONDesign.spacingLarge, after: bgColorCard)
        stack.setCustomSpacing(AIONDesign.spacingLarge, after: languageCard)

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
            metricsStack.heightAnchor.constraint(equalToConstant: 124),
            metricsStack.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            metricsStack.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
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

    private func makeMetricCard(_ title: String, value: String, unit: String, explanation: String) -> (UIView, UILabel) {
        let c = UIView()
        c.backgroundColor = AIONDesign.surface
        c.layer.cornerRadius = AIONDesign.cornerRadius
        c.translatesAutoresizingMaskIntoConstraints = false

        let info = CardInfoButton.make(explanation: explanation)
        info.addTarget(self, action: #selector(profileCardInfoTapped(_:)), for: .touchUpInside)
        c.addSubview(info)

        let t = UILabel()
        t.text = title
        t.font = .systemFont(ofSize: 12, weight: .semibold)
        t.textColor = AIONDesign.textSecondary
        t.textAlignment = .center
        t.translatesAutoresizingMaskIntoConstraints = false
        c.addSubview(t)

        let v = UILabel()
        v.text = (value.isEmpty || value == "—") ? "— \(unit)" : "\(value) \(unit)"
        v.font = .systemFont(ofSize: 18, weight: .bold)
        v.textColor = AIONDesign.textPrimary
        v.textAlignment = .center
        v.adjustsFontSizeToFitWidth = true
        v.minimumScaleFactor = 0.7
        v.translatesAutoresizingMaskIntoConstraints = false
        c.addSubview(v)

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        // Common constraints
        NSLayoutConstraint.activate([
            info.topAnchor.constraint(equalTo: c.topAnchor, constant: 10),
            t.centerYAnchor.constraint(equalTo: info.centerYAnchor),
            v.topAnchor.constraint(equalTo: t.bottomAnchor, constant: 14),
            v.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 10),
            v.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -10),
            v.bottomAnchor.constraint(equalTo: c.bottomAnchor, constant: -14),
        ])

        // RTL/LTR specific constraints
        // RTL (Hebrew): info on LEFT, title on right. LTR (English): info on RIGHT, title on left
        if isRTL {
            NSLayoutConstraint.activate([
                info.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 10),
                t.leadingAnchor.constraint(equalTo: info.trailingAnchor, constant: 6),
                t.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -10),
            ])
        } else {
            NSLayoutConstraint.activate([
                info.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -10),
                t.trailingAnchor.constraint(equalTo: info.leadingAnchor, constant: -6),
                t.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 10),
            ])
        }
        return (c, v)
    }

    /// יוצר כרטיס הגדרות עם אייקון, כותרת וsubtitle
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

        // Common constraints
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

        // RTL/LTR specific constraints
        if isRTL {
            // RTL: icon on right, chevron on left
            NSLayoutConstraint.activate([
                iconView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -AIONDesign.spacing),
                titleLabel.trailingAnchor.constraint(equalTo: iconView.leadingAnchor, constant: -12),
                subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
                chevron.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: AIONDesign.spacing),
            ])
        } else {
            // LTR: icon on left, chevron on right
            NSLayoutConstraint.activate([
                iconView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: AIONDesign.spacing),
                titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
                subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
                chevron.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -AIONDesign.spacing),
            ])
        }

        return card
    }

    @objc private func dataSourceTapped() {
        let vc = DataSourceSettingsViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func dataSourceDidChange() {
        // Update the subtitle in the data source card
        if let card = stack.viewWithTag(999) {
            for subview in card.subviews {
                if let label = subview as? UILabel,
                   label.font == .systemFont(ofSize: 13, weight: .regular) {
                    label.text = DataSourceManager.shared.effectiveSource().displayNameHebrew
                    break
                }
            }
        }
    }

    // MARK: - Background Color Selection

    private func makeBackgroundColorCard() -> UIView {
        let card = UIView()
        card.backgroundColor = AIONDesign.surface
        card.layer.cornerRadius = AIONDesign.cornerRadius
        card.translatesAutoresizingMaskIntoConstraints = false
        card.tag = 998 // For updating later

        // Title
        let titleLabel = UILabel()
        titleLabel.text = "profile.backgroundColor".localized
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = AIONDesign.textPrimary
        titleLabel.textAlignment = LocalizationManager.shared.textAlignment
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // אייקון
        let iconView = UIImageView(image: UIImage(systemName: "paintpalette.fill"))
        iconView.tintColor = AIONDesign.accentPrimary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        // שורת צבעים
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

        // Common constraints
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

        // RTL/LTR specific constraints
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
        colorCircle.tag = 100 + index // For finding later

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

        // אם זה כבר הצבע הנוכחי, לא לעשות כלום
        guard selectedColor != BackgroundColor.current else { return }

        // Haptic
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Show confirmation to user
        let alert = UIAlertController(
            title: "profile.backgroundColorChange".localized,
            message: "profile.backgroundColorMessage".localized,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "cancel".localized, style: .cancel))

        alert.addAction(UIAlertAction(title: "profile.confirmAndClose".localized, style: .default) { [weak self] _ in
            // שמירת הצבע החדש
            BackgroundColor.current = selectedColor

            // עדכון ויזואלי של הבחירה
            self?.updateBackgroundColorSelection()

            // סגירת האפליקציה אחרי השהייה קצרה
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

        // Icon constraints based on language direction
        var iconConstraints: [NSLayoutConstraint] = [
            iconView.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
        ]

        if isRTL {
            // RTL: icon on right
            iconConstraints.append(iconView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -AIONDesign.spacing))
        } else {
            // LTR: icon on left
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

    @objc private func backgroundColorDidChange() {
        view.backgroundColor = AIONDesign.background
        navigationController?.navigationBar.barStyle = AIONDesign.navBarStyle
        navigationController?.navigationBar.barTintColor = AIONDesign.background
        navigationController?.navigationBar.backgroundColor = AIONDesign.background
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: AIONDesign.textPrimary]
    }

    @objc private func profileCardInfoTapped(_ sender: CardInfoButton) {
        let alert = UIAlertController(title: "dashboard.explanation".localized, message: sender.explanation, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "understand".localized, style: .default))
        present(alert, animated: true)
    }

    private func applySavedBadge() {
        let savedValue = UserDefaults.standard.string(forKey: kProfileBadge) ?? "athlete"
        // Map saved key to localized display text
        let displayText: String
        switch savedValue {
        case "athlete", "אתלט", "ATHLETE": displayText = "profile.athlete".localized
        case "beginner", "מתחיל": displayText = "profile.beginner".localized
        case "amateur", "חובב": displayText = "profile.amateur".localized
        case "professional", "מקצוען": displayText = "profile.professional".localized
        default: displayText = "profile.athlete".localized
        }
        badgeLabel.text = displayText
    }

    @objc private func nameTapped() {
        let alert = UIAlertController(title: "profile.editName".localized, message: "profile.enterName".localized, preferredStyle: .alert)
        alert.addTextField { [weak self] tf in
            tf.text = self?.nameLabel.text
            tf.placeholder = "profile.name".localized
            tf.textAlignment = LocalizationManager.shared.textAlignment
        }
        alert.addAction(UIAlertAction(title: "cancel".localized, style: .cancel))
        alert.addAction(UIAlertAction(title: "save".localized, style: .default) { [weak self] _ in
            guard let self = self, let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return }
            self.saveDisplayName(name)
        })
        present(alert, animated: true)
    }

    private func saveDisplayName(_ name: String) {
        let request = Auth.auth().currentUser?.createProfileChangeRequest()
        request?.displayName = name
        request?.commitChanges { [weak self] err in
            DispatchQueue.main.async {
                if let e = err {
                    let a = UIAlertController(title: "error".localized, message: e.localizedDescription, preferredStyle: .alert)
                    a.addAction(UIAlertAction(title: "ok".localized, style: .default))
                    self?.present(a, animated: true)
                    return
                }
                self?.nameLabel.text = name
                ProfileFirestoreSync.saveDisplayName(name)
            }
        }
    }

    @objc private func badgeTapped() {
        let sheet = UIAlertController(title: "profile.selectUserType".localized, message: nil, preferredStyle: .actionSheet)
        for opt in profileBadgeOptions {
            sheet.addAction(UIAlertAction(title: opt.title, style: .default) { [weak self] _ in
                UserDefaults.standard.set(opt.value, forKey: kProfileBadge)
                self?.badgeLabel.text = opt.value
            })
        }
        sheet.addAction(UIAlertAction(title: "cancel".localized, style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
            pop.permittedArrowDirections = []
        }
        present(sheet, animated: true)
    }

    private func updateUserInfo() {
        guard Auth.auth().currentUser != nil else { return }
        ProfileFirestoreSync.fetchDisplayName { [weak self] name in
            guard let self = self else { return }
            if let n = name, !n.isEmpty {
                self.nameLabel.text = n
                return
            }
            guard let u = Auth.auth().currentUser else { return }
            self.nameLabel.text = u.displayName ?? u.email ?? "profile.user".localized
        }
    }

    private func loadProfilePhoto() {
        ProfileFirestoreSync.fetchPhotoURL { [weak self] url in
            self?.applyProfilePhoto(url: url)
        }
    }

    private func applyProfilePhoto(url: String?) {
        if let u = url, let uu = URL(string: u) {
            URLSession.shared.dataTask(with: uu) { [weak self] data, response, error in
                guard let self = self else { return }

                // Check for HTTP errors (like 404 - file not found)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    // Image doesn't exist, fall back to Auth photo or default
                    DispatchQueue.main.async {
                        self.tryAuthPhotoOrDefault()
                    }
                    return
                }

                guard let d = data, let img = UIImage(data: d) else {
                    DispatchQueue.main.async {
                        self.tryAuthPhotoOrDefault()
                    }
                    return
                }

                DispatchQueue.main.async {
                    self.avatarImageView.image = img
                    self.avatarImageView.tintColor = nil
                }
            }.resume()
        } else {
            tryAuthPhotoOrDefault()
        }
    }

    private func tryAuthPhotoOrDefault() {
        if let u = Auth.auth().currentUser?.photoURL?.absoluteString, let uu = URL(string: u) {
            URLSession.shared.dataTask(with: uu) { [weak self] data, _, _ in
                guard let self = self, let d = data, let img = UIImage(data: d) else {
                    DispatchQueue.main.async {
                        self?.setDefaultAvatar()
                    }
                    return
                }
                DispatchQueue.main.async {
                    self.avatarImageView.image = img
                    self.avatarImageView.tintColor = nil
                }
            }.resume()
        } else {
            setDefaultAvatar()
        }
    }

    private func setDefaultAvatar() {
        avatarImageView.image = UIImage(systemName: "person.circle.fill")
        avatarImageView.tintColor = AIONDesign.textTertiary
    }

    @objc private func changePhotoTapped() {
        if #available(iOS 14, *) {
            var config = PHPickerConfiguration()
            config.filter = .images
            config.selectionLimit = 1
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = self
            present(picker, animated: true)
        } else {
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.mediaTypes = ["public.image"]
            present(picker, animated: true)
        }
    }

    private func loadProfileMetrics() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        HealthKitManager.shared.requestAuthorization { [weak self] success, _ in
            guard success else { return }
            HealthKitManager.shared.fetchProfileMetrics { heightCm, weightKg in
                HealthKitManager.shared.fetchDateOfBirth { ageYears in
                    self?.updateMetricLabels(heightCm: heightCm, weightKg: weightKg, ageYears: ageYears)
                }
            }
        }
    }

    private func updateMetricLabels(heightCm: Double?, weightKg: Double?, ageYears: Int?) {
        if let h = heightCm, h > 0 {
            heightValueLabel?.text = String(format: "%.0f cm", h)
        } else {
            heightValueLabel?.text = "— cm"
        }
        if let w = weightKg, w > 0 {
            weightValueLabel?.text = String(format: "%.1f kg", w)
        } else {
            weightValueLabel?.text = "— kg"
        }
        if let a = ageYears, a > 0 {
            thirdMetricTitleLabel?.text = "profile.age".localized
            ageValueLabel?.text = "\(a) \("unit.years".localized)"
        } else if let h = heightCm, let w = weightKg, h > 0, w > 0 {
            let bmi = w / ((h / 100) * (h / 100))
            thirdMetricTitleLabel?.text = "BMI"
            ageValueLabel?.text = String(format: "%.1f", bmi)
        } else {
            thirdMetricTitleLabel?.text = "profile.age".localized
            ageValueLabel?.text = "— \("unit.years".localized)"
        }
    }

    @objc private func logoutTapped() {
        do {
            // Analytics: Log logout and reset analytics data
            AnalyticsService.shared.logLogout()
            AnalyticsService.shared.resetAnalyticsData()

            try Auth.auth().signOut()
            (view.window?.windowScene?.delegate as? SceneDelegate)?.showLogin()
        } catch {
            let alert = UIAlertController(title: "error".localized, message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "ok".localized, style: .default))
            present(alert, animated: true)
        }
    }
}

extension ProfileViewController: PHPickerViewControllerDelegate {
    @available(iOS 14, *)
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let r = results.first else { return }
        r.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
            guard let self = self, let img = obj as? UIImage else { return }
            DispatchQueue.main.async {
                self.uploadAndSaveProfilePhoto(img)
            }
        }
    }
}

extension ProfileViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let img = info[.originalImage] as? UIImage else { return }
        uploadAndSaveProfilePhoto(img)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

private extension ProfileViewController {
    func uploadAndSaveProfilePhoto(_ image: UIImage) {
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        overlay.frame = view.bounds
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(overlay)
        let sp = UIActivityIndicatorView(style: .large)
        sp.color = AIONDesign.textPrimary
        sp.center = CGPoint(x: overlay.bounds.midX, y: overlay.bounds.midY)
        sp.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
        overlay.addSubview(sp)
        sp.startAnimating()

        ProfileFirestoreSync.uploadProfileImage(image) { [weak self] result in
            DispatchQueue.main.async {
                overlay.removeFromSuperview()
                switch result {
                case .success(let url):
                    ProfileFirestoreSync.savePhotoURL(url) { _ in }
                    self?.applyProfilePhoto(url: url)
                case .failure(let err):
                    let alert = UIAlertController(title: "error".localized, message: err.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "ok".localized, style: .default))
                    self?.present(alert, animated: true)
                }
            }
        }
    }
}
