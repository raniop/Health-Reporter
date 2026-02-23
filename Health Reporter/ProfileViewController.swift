//
//  ProfileViewController.swift
//  Health Reporter
//
//  WHOOP-inspired profile page — blurred background photo, avatar,
//  stats badges, tab selector, key stats, health breakdown,
//  body metrics, rank card.
//

import UIKit
import FirebaseAuth
import HealthKit
import PhotosUI

// MARK: - ProfileViewController

final class ProfileViewController: UIViewController {

    // MARK: - State

    private var hasAppearedOnce = false
    private var currentScore: Int = 0
    private var selectedPeriodIndex: Int = 0  // 0 = Last 30 Days, 1 = All Time

    // MARK: - UI — Chrome

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // Blurred background photo (replaces old gradient header)
    private let backgroundImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.backgroundColor = AIONDesign.surface
        return iv
    }()

    private let blurEffectView: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemThinMaterialDark)
        let v = UIVisualEffectView(effect: blur)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let gradientOverlayView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let gradientOverlayLayer = CAGradientLayer()

    // MARK: - UI — Section 1: Header (transparent, over blur)

    private let headerSection = UIView()

    private let avatarRing: AvatarRingView = {
        let v = AvatarRingView(size: 110)
        v.ringWidth = 3
        v.isAnimated = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let cameraButton: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: "camera.fill",
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)), for: .normal)
        b.tintColor = .white
        b.backgroundColor = AIONDesign.accentPrimary
        b.layer.cornerRadius = 14
        b.layer.borderWidth = 2.5
        b.layer.borderColor = AIONDesign.surface.cgColor
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 26, weight: .black)
        l.textColor = .white
        l.textAlignment = .center
        l.numberOfLines = 2
        l.adjustsFontSizeToFitWidth = true
        l.minimumScaleFactor = 0.7
        l.isUserInteractionEnabled = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let tierChip = UIView()
    private let tierDot = UIView()
    private let tierTextLabel = UILabel()

    // MARK: - UI — Section 2: Stats Badge Row

    private let statsBadgeCard = UIView()
    private let rankStatValue = UILabel()
    private let rankStatLabel = UILabel()
    private let scoreStatValue = UILabel()
    private let scoreStatLabel = UILabel()
    private let followersStatValue = UILabel()
    private let followersStatLabel = UILabel()
    private let streakStatValue = UILabel()
    private let streakStatLabel = UILabel()

    // MARK: - UI — Section 3: Tab Selector

    private lazy var periodTabControl: AnimatedTabBarControl = {
        let tabs = AnimatedTabBarControl(titles: [
            "profile.last30Days".localized,
            "profile.allTime".localized,
        ])
        tabs.translatesAutoresizingMaskIntoConstraints = false
        return tabs
    }()

    // MARK: - UI — Section 4: Key Stats Row

    private let keyStatsRow = UIStackView()
    private let activityCountLabel = UILabel()
    private let avgScoreLabel = UILabel()
    private let bestDayLabel = UILabel()

    // MARK: - UI — Section 5: Health Breakdown Grid

    private let breakdownSectionLabel = UILabel()
    private let breakdownContainer = UIView()
    private let sleepCard = BioTrendCardView()
    private let recoveryCard = BioTrendCardView()
    private let energyCard = BioTrendCardView()
    private let activityCard = BioTrendCardView()
    private let nervousCard = BioTrendCardView()
    private let balanceCard = BioTrendCardView()

    // MARK: - UI — Section 6: Body Metrics

    private let metricsCard = UIView()
    private let heightValueLabel = UILabel()
    private let weightValueLabel = UILabel()
    private let thirdValueLabel = UILabel()
    private let thirdTitleLabel = UILabel()
    private var heightInfoBtn: CardInfoButton?
    private var weightInfoBtn: CardInfoButton?
    private var thirdInfoBtn: CardInfoButton?

    // MARK: - UI — Section 7: Rank & Progress

    private let rankCard = UIView()
    private let rankBadge = RankBadgeView()
    private let rankLabel = UILabel()
    private let rankProgress = ProgressToNextRankView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AIONDesign.background
        view.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute

        buildNavigationBar()
        buildLayout()

        updateUserInfo()
        loadProfilePhoto()
        loadHealthScoreData()

        NotificationCenter.default.addObserver(self, selector: #selector(dataSourceDidChange), name: .dataSourceChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(backgroundColorDidChange), name: .backgroundColorChanged, object: nil)

        AnalyticsService.shared.logScreenView(.profile)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never

        updateUserInfo()
        loadProfilePhoto()
        loadSocialData()
        loadHealthScoreData()
        loadProfileMetrics()
        loadScoreBreakdown()
        loadRankData()
        loadKeyStats()
        loadStreakData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !hasAppearedOnce {
            hasAppearedOnce = true
            playEntranceAnimations()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientOverlayLayer.frame = gradientOverlayView.bounds
    }

    // MARK: - Navigation Bar

    private func buildNavigationBar() {
        title = ""
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance

        let shareBtn = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up",
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)),
            style: .plain, target: self, action: #selector(shareProfileTapped)
        )
        shareBtn.tintColor = AIONDesign.textTertiary

        let gearBtn = UIBarButtonItem(
            image: UIImage(systemName: "gearshape",
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)),
            style: .plain, target: self, action: #selector(settingsTapped)
        )
        gearBtn.tintColor = AIONDesign.textTertiary

        navigationItem.rightBarButtonItems = [gearBtn, shareBtn]
    }

    @objc private func settingsTapped() {
        navigationController?.pushViewController(SettingsViewController(), animated: true)
    }

    // MARK: - Master Layout

    private func buildLayout() {
        // --- Blurred background photo (pinned behind scroll) ---
        view.addSubview(backgroundImageView)
        backgroundImageView.addSubview(blurEffectView)
        backgroundImageView.addSubview(gradientOverlayView)

        gradientOverlayLayer.colors = [
            UIColor.clear.cgColor,
            AIONDesign.background.withAlphaComponent(0.5).cgColor,
            AIONDesign.background.cgColor,
        ]
        gradientOverlayLayer.locations = [0, 0.55, 1.0]
        gradientOverlayView.layer.insertSublayer(gradientOverlayLayer, at: 0)

        // --- Scroll view ---
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.backgroundColor = .clear
        scrollView.alwaysBounceVertical = true
        scrollView.delegate = self
        view.addSubview(scrollView)

        // --- Content stack ---
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        // Build all sections
        buildHeaderSection()         // Section 1: Avatar + Name + Tier
        buildStatsBadgeRow()         // Section 2: 4-column stats
        buildTabSelector()           // Section 3: Period tab
        buildKeyStatsRow()           // Section 4: 3 key stats
        buildBreakdownGrid()         // Section 5: 6 health cards
        buildMetricsCard()           // Section 6: Body metrics
        buildRankCard()              // Section 7: Rank

        // Bottom spacer
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 48).isActive = true
        contentStack.addArrangedSubview(spacer)

        let hPad: CGFloat = 16

        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.heightAnchor.constraint(equalToConstant: 380),

            blurEffectView.topAnchor.constraint(equalTo: backgroundImageView.topAnchor),
            blurEffectView.leadingAnchor.constraint(equalTo: backgroundImageView.leadingAnchor),
            blurEffectView.trailingAnchor.constraint(equalTo: backgroundImageView.trailingAnchor),
            blurEffectView.bottomAnchor.constraint(equalTo: backgroundImageView.bottomAnchor),

            gradientOverlayView.topAnchor.constraint(equalTo: backgroundImageView.topAnchor),
            gradientOverlayView.leadingAnchor.constraint(equalTo: backgroundImageView.leadingAnchor),
            gradientOverlayView.trailingAnchor.constraint(equalTo: backgroundImageView.trailingAnchor),
            gradientOverlayView.bottomAnchor.constraint(equalTo: backgroundImageView.bottomAnchor),

            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 90),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: hPad),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -hPad),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -hPad * 2),
        ])
    }

    // MARK: - Section 1: Header (Avatar + Name + Tier)

    private func buildHeaderSection() {
        headerSection.translatesAutoresizingMaskIntoConstraints = false
        headerSection.backgroundColor = .clear

        // Avatar
        avatarRing.isUserInteractionEnabled = true
        avatarRing.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(changePhotoTapped)))
        headerSection.addSubview(avatarRing)

        // Camera button
        cameraButton.addTarget(self, action: #selector(changePhotoTapped), for: .touchUpInside)
        headerSection.addSubview(cameraButton)

        // Name
        nameLabel.text = "profile.user".localized
        nameLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(nameTapped)))
        headerSection.addSubview(nameLabel)

        // Tier chip
        tierChip.translatesAutoresizingMaskIntoConstraints = false
        tierChip.backgroundColor = AIONDesign.surfaceElevated.withAlphaComponent(0.6)
        tierChip.layer.cornerRadius = 14
        tierChip.isHidden = true
        headerSection.addSubview(tierChip)

        tierDot.translatesAutoresizingMaskIntoConstraints = false
        tierDot.layer.cornerRadius = 3
        tierDot.backgroundColor = AIONDesign.accentPrimary
        tierChip.addSubview(tierDot)

        tierTextLabel.font = .systemFont(ofSize: 12, weight: .bold)
        tierTextLabel.textColor = .white
        tierTextLabel.translatesAutoresizingMaskIntoConstraints = false
        tierChip.addSubview(tierTextLabel)

        NSLayoutConstraint.activate([
            avatarRing.topAnchor.constraint(equalTo: headerSection.topAnchor, constant: 8),
            avatarRing.centerXAnchor.constraint(equalTo: headerSection.centerXAnchor),
            avatarRing.widthAnchor.constraint(equalToConstant: 110),
            avatarRing.heightAnchor.constraint(equalToConstant: 110),

            cameraButton.trailingAnchor.constraint(equalTo: avatarRing.trailingAnchor, constant: 2),
            cameraButton.bottomAnchor.constraint(equalTo: avatarRing.bottomAnchor, constant: 2),
            cameraButton.widthAnchor.constraint(equalToConstant: 28),
            cameraButton.heightAnchor.constraint(equalToConstant: 28),

            nameLabel.topAnchor.constraint(equalTo: avatarRing.bottomAnchor, constant: 12),
            nameLabel.centerXAnchor.constraint(equalTo: headerSection.centerXAnchor),
            nameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: headerSection.leadingAnchor, constant: 24),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: headerSection.trailingAnchor, constant: -24),

            tierChip.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            tierChip.centerXAnchor.constraint(equalTo: headerSection.centerXAnchor),
            tierChip.heightAnchor.constraint(equalToConstant: 28),
            tierChip.bottomAnchor.constraint(equalTo: headerSection.bottomAnchor, constant: -8),

            tierDot.leadingAnchor.constraint(equalTo: tierChip.leadingAnchor, constant: 12),
            tierDot.centerYAnchor.constraint(equalTo: tierChip.centerYAnchor),
            tierDot.widthAnchor.constraint(equalToConstant: 6),
            tierDot.heightAnchor.constraint(equalToConstant: 6),

            tierTextLabel.leadingAnchor.constraint(equalTo: tierDot.trailingAnchor, constant: 6),
            tierTextLabel.trailingAnchor.constraint(equalTo: tierChip.trailingAnchor, constant: -12),
            tierTextLabel.centerYAnchor.constraint(equalTo: tierChip.centerYAnchor),
        ])

        contentStack.addArrangedSubview(headerSection)
    }

    // MARK: - Section 2: Stats Badge Row

    private func buildStatsBadgeRow() {
        statsBadgeCard.translatesAutoresizingMaskIntoConstraints = false
        statsBadgeCard.backgroundColor = AIONDesign.surface.withAlphaComponent(0.6)
        statsBadgeCard.layer.cornerRadius = AIONDesign.cornerRadiusLarge
        statsBadgeCard.clipsToBounds = true

        // Add blur for glass effect
        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: AIONDesign.glassBlurStyle))
        blurView.translatesAutoresizingMaskIntoConstraints = false
        statsBadgeCard.addSubview(blurView)

        let rankCol = makeStatBadgeColumn(value: rankStatValue, label: rankStatLabel,
                                           labelText: "profile.rank".localized,
                                           icon: "medal.fill", iconColor: AIONDesign.accentWarning,
                                           action: nil)
        let scoreCol = makeStatBadgeColumn(value: scoreStatValue, label: scoreStatLabel,
                                            labelText: "profile.score".localized,
                                            icon: "heart.fill", iconColor: AIONDesign.accentSuccess,
                                            action: nil)
        let followersCol = makeStatBadgeColumn(value: followersStatValue, label: followersStatLabel,
                                                labelText: "social.followers".localized,
                                                icon: "person.2.fill", iconColor: AIONDesign.accentPrimary,
                                                action: #selector(followersTapped))
        let streakCol = makeStatBadgeColumn(value: streakStatValue, label: streakStatLabel,
                                             labelText: "profile.streak".localized,
                                             icon: "flame.fill", iconColor: AIONDesign.accentDanger,
                                             action: nil)

        let stack = UIStackView(arrangedSubviews: [rankCol, scoreCol, followersCol, streakCol])
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .center
        stack.spacing = 0
        stack.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        stack.translatesAutoresizingMaskIntoConstraints = false
        statsBadgeCard.addSubview(stack)

        // Add dividers
        for i in 0..<3 {
            let div = makeThinVerticalDivider()
            stack.addSubview(div)
            NSLayoutConstraint.activate([
                div.centerYAnchor.constraint(equalTo: stack.centerYAnchor),
                div.leadingAnchor.constraint(equalTo: stack.arrangedSubviews[i].trailingAnchor),
            ])
        }

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: statsBadgeCard.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: statsBadgeCard.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: statsBadgeCard.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: statsBadgeCard.bottomAnchor),

            stack.topAnchor.constraint(equalTo: statsBadgeCard.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: statsBadgeCard.leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: statsBadgeCard.trailingAnchor, constant: -4),
            stack.bottomAnchor.constraint(equalTo: statsBadgeCard.bottomAnchor, constant: -12),
        ])

        contentStack.addArrangedSubview(statsBadgeCard)
    }

    private func makeStatBadgeColumn(value: UILabel, label: UILabel, labelText: String,
                                      icon: String, iconColor: UIColor,
                                      action: Selector?) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: UIImage(systemName: icon,
                                                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)))
        iconView.tintColor = iconColor
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        container.addSubview(iconView)

        value.text = "—"
        value.font = .monospacedDigitSystemFont(ofSize: 20, weight: .black)
        value.textColor = AIONDesign.textPrimary
        value.textAlignment = .center
        value.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(value)

        label.text = labelText.uppercased()
        label.font = .systemFont(ofSize: 9, weight: .heavy)
        label.textColor = AIONDesign.textTertiary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
            iconView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 14),
            iconView.heightAnchor.constraint(equalToConstant: 14),

            value.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 4),
            value.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            label.topAnchor.constraint(equalTo: value.bottomAnchor, constant: 2),
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2),
        ])

        if let action = action {
            container.isUserInteractionEnabled = true
            container.addGestureRecognizer(UITapGestureRecognizer(target: self, action: action))
        }
        return container
    }

    private func makeThinVerticalDivider() -> UIView {
        let div = UIView()
        div.translatesAutoresizingMaskIntoConstraints = false
        div.backgroundColor = AIONDesign.separator.withAlphaComponent(0.2)
        NSLayoutConstraint.activate([
            div.widthAnchor.constraint(equalToConstant: 0.5),
            div.heightAnchor.constraint(equalToConstant: 36),
        ])
        return div
    }

    // MARK: - Section 3: Tab Selector

    private func buildTabSelector() {
        periodTabControl.onSelectionChanged = { [weak self] index in
            self?.selectedPeriodIndex = index
            self?.loadKeyStats()
        }
        periodTabControl.heightAnchor.constraint(equalToConstant: 44).isActive = true
        contentStack.addArrangedSubview(periodTabControl)
    }

    // MARK: - Section 4: Key Stats Row

    private func buildKeyStatsRow() {
        keyStatsRow.axis = .horizontal
        keyStatsRow.distribution = .fillEqually
        keyStatsRow.spacing = 8
        keyStatsRow.translatesAutoresizingMaskIntoConstraints = false

        let activityStat = makeKeyStatCard(
            icon: "figure.run", iconColor: AIONDesign.accentSecondary,
            valueLabel: activityCountLabel, caption: "profile.activities".localized
        )
        let avgScoreStat = makeKeyStatCard(
            icon: "chart.line.uptrend.xyaxis", iconColor: AIONDesign.accentPrimary,
            valueLabel: avgScoreLabel, caption: "profile.avgScore".localized
        )
        let bestDayStat = makeKeyStatCard(
            icon: "star.fill", iconColor: AIONDesign.accentSuccess,
            valueLabel: bestDayLabel, caption: "profile.bestDay".localized
        )

        keyStatsRow.addArrangedSubview(activityStat)
        keyStatsRow.addArrangedSubview(avgScoreStat)
        keyStatsRow.addArrangedSubview(bestDayStat)

        contentStack.addArrangedSubview(keyStatsRow)
    }

    private func makeKeyStatCard(icon: String, iconColor: UIColor,
                                   valueLabel: UILabel, caption: String) -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = AIONDesign.surface
        card.layer.cornerRadius = AIONDesign.cornerRadius
        card.clipsToBounds = true

        let iconView = UIImageView(image: UIImage(systemName: icon,
                                                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)))
        iconView.tintColor = iconColor
        iconView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(iconView)

        valueLabel.text = "—"
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 22, weight: .black)
        valueLabel.textColor = AIONDesign.textPrimary
        valueLabel.textAlignment = .center
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(valueLabel)

        let captionLabel = UILabel()
        captionLabel.text = caption.uppercased()
        captionLabel.font = .systemFont(ofSize: 9, weight: .heavy)
        captionLabel.textColor = AIONDesign.textTertiary
        captionLabel.textAlignment = .center
        captionLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(captionLabel)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 90),

            iconView.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            iconView.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            valueLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 6),
            valueLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: card.leadingAnchor, constant: 4),
            valueLabel.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -4),

            captionLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 4),
            captionLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            captionLabel.leadingAnchor.constraint(greaterThanOrEqualTo: card.leadingAnchor, constant: 4),
            captionLabel.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -4),
        ])

        return card
    }

    // MARK: - Section 5: Health Breakdown Grid

    private func buildBreakdownGrid() {
        breakdownSectionLabel.text = "profile.healthBreakdown".localized.uppercased()
        configureSectionLabel(breakdownSectionLabel)
        contentStack.addArrangedSubview(breakdownSectionLabel)

        breakdownContainer.translatesAutoresizingMaskIntoConstraints = false
        breakdownContainer.isHidden = true

        let row1 = UIStackView(arrangedSubviews: [sleepCard, recoveryCard, energyCard])
        row1.axis = .horizontal
        row1.distribution = .fillEqually
        row1.spacing = 8
        row1.translatesAutoresizingMaskIntoConstraints = false

        let row2 = UIStackView(arrangedSubviews: [activityCard, nervousCard, balanceCard])
        row2.axis = .horizontal
        row2.distribution = .fillEqually
        row2.spacing = 8
        row2.translatesAutoresizingMaskIntoConstraints = false

        let gridStack = UIStackView(arrangedSubviews: [row1, row2])
        gridStack.axis = .vertical
        gridStack.spacing = 8
        gridStack.translatesAutoresizingMaskIntoConstraints = false

        breakdownContainer.addSubview(gridStack)
        NSLayoutConstraint.activate([
            gridStack.topAnchor.constraint(equalTo: breakdownContainer.topAnchor),
            gridStack.leadingAnchor.constraint(equalTo: breakdownContainer.leadingAnchor),
            gridStack.trailingAnchor.constraint(equalTo: breakdownContainer.trailingAnchor),
            gridStack.bottomAnchor.constraint(equalTo: breakdownContainer.bottomAnchor),
        ])

        [sleepCard, recoveryCard, energyCard, activityCard, nervousCard, balanceCard].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.heightAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
        }

        contentStack.addArrangedSubview(breakdownContainer)
    }

    // MARK: - Section 6: Body Metrics Card

    private func buildMetricsCard() {
        metricsCard.translatesAutoresizingMaskIntoConstraints = false
        metricsCard.backgroundColor = AIONDesign.surface
        metricsCard.layer.cornerRadius = 22
        metricsCard.clipsToBounds = true

        let sectionTitle = UILabel()
        sectionTitle.text = "profile.bodyMetrics".localized.uppercased()
        sectionTitle.font = .systemFont(ofSize: 11, weight: .heavy)
        sectionTitle.textColor = AIONDesign.textTertiary
        sectionTitle.textAlignment = LocalizationManager.shared.textAlignment
        sectionTitle.translatesAutoresizingMaskIntoConstraints = false
        metricsCard.addSubview(sectionTitle)

        let heightRow = buildMetricRow(icon: "ruler.fill", title: "profile.height".localized,
                                        valueLabel: heightValueLabel, accentColor: AIONDesign.accentPrimary,
                                        explanation: CardExplanations.profileHeight, infoBtnRef: &heightInfoBtn)
        let sep1 = makeRowSeparator()
        let weightRow = buildMetricRow(icon: "scalemass.fill", title: "profile.weight".localized,
                                        valueLabel: weightValueLabel, accentColor: AIONDesign.accentSecondary,
                                        explanation: CardExplanations.profileWeight, infoBtnRef: &weightInfoBtn)
        let sep2 = makeRowSeparator()
        let ageRow = buildMetricRow(icon: "birthday.cake.fill", titleLabel: thirdTitleLabel,
                                     title: "profile.age".localized, valueLabel: thirdValueLabel,
                                     accentColor: AIONDesign.accentSuccess,
                                     explanation: CardExplanations.profileAge, infoBtnRef: &thirdInfoBtn)

        heightValueLabel.text = "\u{2014} cm"
        weightValueLabel.text = "\u{2014} kg"
        thirdValueLabel.text = "\u{2014} \("unit.years".localized)"

        let rowStack = UIStackView(arrangedSubviews: [heightRow, sep1, weightRow, sep2, ageRow])
        rowStack.axis = .vertical
        rowStack.spacing = 0
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        metricsCard.addSubview(rowStack)

        NSLayoutConstraint.activate([
            sectionTitle.topAnchor.constraint(equalTo: metricsCard.topAnchor, constant: 16),
            sectionTitle.leadingAnchor.constraint(equalTo: metricsCard.leadingAnchor, constant: 20),
            sectionTitle.trailingAnchor.constraint(equalTo: metricsCard.trailingAnchor, constant: -20),
            rowStack.topAnchor.constraint(equalTo: sectionTitle.bottomAnchor, constant: 8),
            rowStack.leadingAnchor.constraint(equalTo: metricsCard.leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: metricsCard.trailingAnchor),
            rowStack.bottomAnchor.constraint(equalTo: metricsCard.bottomAnchor, constant: -8),
        ])

        contentStack.addArrangedSubview(metricsCard)
    }

    private func buildMetricRow(icon: String, titleLabel: UILabel? = nil, title: String,
                                  valueLabel: UILabel, accentColor: UIColor,
                                  explanation: String, infoBtnRef: inout CardInfoButton?) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let iconBg = UIView()
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        iconBg.backgroundColor = accentColor.withAlphaComponent(0.10)
        iconBg.layer.cornerRadius = 14
        row.addSubview(iconBg)

        let iconView = UIImageView(image: UIImage(systemName: icon,
                                                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)))
        iconView.tintColor = accentColor
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconBg.addSubview(iconView)

        let tLabel = titleLabel ?? UILabel()
        tLabel.text = title
        tLabel.font = .systemFont(ofSize: 15, weight: .medium)
        tLabel.textColor = AIONDesign.textPrimary
        tLabel.textAlignment = LocalizationManager.shared.textAlignment
        tLabel.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(tLabel)

        valueLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        valueLabel.textColor = AIONDesign.textSecondary
        valueLabel.textAlignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(valueLabel)

        let info = CardInfoButton.make(explanation: explanation)
        info.addTarget(self, action: #selector(profileCardInfoTapped(_:)), for: .touchUpInside)
        infoBtnRef = info
        row.addSubview(info)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 52),
            iconBg.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            iconBg.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            iconBg.widthAnchor.constraint(equalToConstant: 28),
            iconBg.heightAnchor.constraint(equalToConstant: 28),
            iconView.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            tLabel.leadingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 12),
            tLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            info.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
            info.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: info.leadingAnchor, constant: -4),
            valueLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: tLabel.trailingAnchor, constant: 8),
        ])
        return row
    }

    private func makeRowSeparator() -> UIView {
        let sep = UIView()
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.backgroundColor = AIONDesign.separator.withAlphaComponent(0.10)
        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(sep)
        NSLayoutConstraint.activate([
            wrapper.heightAnchor.constraint(equalToConstant: 0.5),
            sep.heightAnchor.constraint(equalToConstant: 0.5),
            sep.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 56),
            sep.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            sep.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor),
        ])
        return wrapper
    }

    // MARK: - Section 7: Rank & Progress

    private func buildRankCard() {
        rankCard.translatesAutoresizingMaskIntoConstraints = false
        rankCard.backgroundColor = AIONDesign.surface
        rankCard.layer.cornerRadius = AIONDesign.cornerRadiusLarge
        rankCard.clipsToBounds = true
        rankCard.isHidden = true

        rankBadge.translatesAutoresizingMaskIntoConstraints = false
        rankCard.addSubview(rankBadge)

        rankLabel.font = .systemFont(ofSize: 16, weight: .bold)
        rankLabel.textColor = AIONDesign.textPrimary
        rankLabel.textAlignment = LocalizationManager.shared.textAlignment
        rankLabel.translatesAutoresizingMaskIntoConstraints = false
        rankCard.addSubview(rankLabel)

        rankProgress.translatesAutoresizingMaskIntoConstraints = false
        rankCard.addSubview(rankProgress)

        NSLayoutConstraint.activate([
            rankBadge.leadingAnchor.constraint(equalTo: rankCard.leadingAnchor, constant: 20),
            rankBadge.topAnchor.constraint(equalTo: rankCard.topAnchor, constant: 16),
            rankBadge.widthAnchor.constraint(equalToConstant: 40),
            rankBadge.heightAnchor.constraint(equalToConstant: 40),

            rankLabel.leadingAnchor.constraint(equalTo: rankBadge.trailingAnchor, constant: 12),
            rankLabel.centerYAnchor.constraint(equalTo: rankBadge.centerYAnchor),
            rankLabel.trailingAnchor.constraint(equalTo: rankCard.trailingAnchor, constant: -20),

            rankProgress.topAnchor.constraint(equalTo: rankBadge.bottomAnchor, constant: 12),
            rankProgress.leadingAnchor.constraint(equalTo: rankCard.leadingAnchor, constant: 20),
            rankProgress.trailingAnchor.constraint(equalTo: rankCard.trailingAnchor, constant: -20),
            rankProgress.bottomAnchor.constraint(equalTo: rankCard.bottomAnchor, constant: -16),
        ])

        contentStack.addArrangedSubview(rankCard)
    }

    // MARK: - Section Label Helper

    private func configureSectionLabel(_ label: UILabel) {
        label.font = .systemFont(ofSize: 11, weight: .heavy)
        label.textColor = AIONDesign.textTertiary
        label.textAlignment = LocalizationManager.shared.textAlignment
        label.translatesAutoresizingMaskIntoConstraints = false
    }

    // MARK: - Entrance Animations

    private func playEntranceAnimations() {
        let animatables: [UIView] = [
            headerSection, statsBadgeCard, periodTabControl,
            keyStatsRow,
            breakdownSectionLabel, breakdownContainer,
            metricsCard, rankCard,
        ].filter { !$0.isHidden }

        for v in animatables {
            v.alpha = 0
            v.transform = CGAffineTransform(translationX: 0, y: 24)
        }

        for (i, v) in animatables.enumerated() {
            UIView.animate(
                withDuration: 0.55,
                delay: Double(i) * 0.06,
                usingSpringWithDamping: 0.72,
                initialSpringVelocity: 0.4,
                options: []
            ) {
                v.alpha = 1
                v.transform = .identity
            }
        }
    }

    // MARK: - Social Taps

    @objc private func followersTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        AnalyticsService.shared.logEvent(.profileStatTapped, parameters: ["stat_type": "followers"])
        navigationController?.pushViewController(FollowersListViewController(mode: .followers), animated: true)
    }

    @objc private func followingTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        AnalyticsService.shared.logEvent(.profileStatTapped, parameters: ["stat_type": "following"])
        navigationController?.pushViewController(FollowersListViewController(mode: .following), animated: true)
    }

    @objc private func shareProfileTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        AnalyticsService.shared.logEvent(.profileShareTapped)

        guard let uid = Auth.auth().currentUser?.uid else { return }

        let name = Auth.auth().currentUser?.displayName ?? "AION User"
        let score = GeminiResultStore.loadHealthScore() ?? 0
        let tier = HealthTier.forScore(score)
        let carName = AnalysisCache.loadSelectedCar()?.name ?? GeminiResultStore.loadCarName() ?? ""

        let profileLink = "https://aionapp.co/profile/\(uid)"
        let appStoreLink = "https://apps.apple.com/us/app/aion-app/id6758244788"
        let shareText = String(format: "profile.shareText".localized, name, score, tier.emoji, carName, profileLink, appStoreLink)

        let cardImage = ShareCardRenderer.render(
            name: name, score: score, carName: carName, carEmoji: tier.emoji, tierColor: tier.color
        )

        let items: [Any] = [shareText, cardImage]
        let ac = UIActivityViewController(activityItems: items, applicationActivities: nil)
        ac.popoverPresentationController?.sourceView = view
        present(ac, animated: true)
    }

    // MARK: - Data Loading

    private func loadHealthScoreData() {
        if let score = GeminiResultStore.loadHealthScore(), score > 0 {
            currentScore = score
            let tier = HealthTier.forScore(score)
            let tierColor = tier.color

            // Tier chip
            tierDot.backgroundColor = tierColor
            tierTextLabel.text = tier.tierLabel
            tierChip.isHidden = false

            // Avatar ring
            avatarRing.ringColors = gradientColorsForScore(score)

            // Tint the blur overlay with tier color
            gradientOverlayLayer.colors = [
                tierColor.withAlphaComponent(0.15).cgColor,
                AIONDesign.background.withAlphaComponent(0.5).cgColor,
                AIONDesign.background.cgColor,
            ]

            // Update score in stats badge
            scoreStatValue.text = "\(score)"
        } else {
            currentScore = 0
            tierChip.isHidden = true
            scoreStatValue.text = "—"
        }
    }

    private func loadScoreBreakdown() {
        let bd = AnalysisCache.loadScoreBreakdown()
        let hasAny = [bd.sleep, bd.recovery, bd.energy, bd.activity, bd.nervousSystem, bd.loadBalance].contains(where: { $0 != nil })

        if hasAny {
            breakdownContainer.isHidden = false
            breakdownSectionLabel.isHidden = false

            sleepCard.configure(icon: "bed.double.fill", title: "metric.sleep".localized,
                                value: bd.sleep.map { "\($0)" } ?? "—", subtitle: nil,
                                dataPoints: [], color: AIONDesign.accentPrimary)
            recoveryCard.configure(icon: "heart.fill", title: "metric.recovery".localized,
                                   value: bd.recovery.map { "\($0)" } ?? "—", subtitle: nil,
                                   dataPoints: [], color: AIONDesign.accentSuccess)
            energyCard.configure(icon: "bolt.fill", title: "metric.energy".localized,
                                 value: bd.energy.map { "\($0)" } ?? "—", subtitle: nil,
                                 dataPoints: [], color: AIONDesign.accentWarning)
            activityCard.configure(icon: "figure.run", title: "metric.activity".localized,
                                   value: bd.activity.map { "\($0)" } ?? "—", subtitle: nil,
                                   dataPoints: [], color: AIONDesign.accentSecondary)
            nervousCard.configure(icon: "waveform.path.ecg", title: "HRV",
                                  value: bd.nervousSystem.map { "\($0)" } ?? "—", subtitle: nil,
                                  dataPoints: [], color: AIONDesign.accentPrimary)
            balanceCard.configure(icon: "scale.3d", title: "metric.balance".localized,
                                  value: bd.loadBalance.map { "\($0)" } ?? "—", subtitle: nil,
                                  dataPoints: [], color: AIONDesign.accentSecondary)
        } else {
            breakdownContainer.isHidden = true
            breakdownSectionLabel.isHidden = true
        }
    }

    private func loadKeyStats() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        HealthKitManager.shared.requestAuthorization { [weak self] ok, _ in
            guard ok, let self = self else { return }

            let endDate = Date()
            let startDate: Date
            if self.selectedPeriodIndex == 0 {
                startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
            } else {
                startDate = Calendar.current.date(byAdding: .year, value: -10, to: endDate) ?? endDate
            }

            HealthKitManager.shared.fetchWorkouts(startDate: startDate, endDate: endDate) { [weak self] workouts in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.activityCountLabel.text = "\(workouts.count)"

                    // Average score: use current score for now
                    if self.currentScore > 0 {
                        self.avgScoreLabel.text = "\(self.currentScore)"
                    }

                    // Best day: highest score from breakdown
                    let bd = AnalysisCache.loadScoreBreakdown()
                    let scores = [bd.sleep, bd.recovery, bd.energy, bd.activity, bd.nervousSystem, bd.loadBalance].compactMap { $0 }
                    if let best = scores.max() {
                        self.bestDayLabel.text = "\(best)"
                    }
                }
            }
        }
    }

    private func loadStreakData() {
        let streak = UserDefaults.standard.integer(forKey: "morningNotification.stepStreak")
        streakStatValue.text = "\(streak)"
    }

    private func loadRankData() {
        LeaderboardFirestoreSync.fetchUserRank { [weak self] rank in
            DispatchQueue.main.async {
                guard let self = self, let rank = rank, rank > 0 else {
                    self?.rankCard.isHidden = true
                    self?.rankStatValue.text = "—"
                    return
                }
                self.rankCard.isHidden = false
                self.rankBadge.configure(rank: rank)
                self.rankLabel.text = "#\(rank) " + "profile.globalRank".localized
                self.rankStatValue.text = "#\(rank)"

                let score = self.currentScore
                let nextThreshold: Int
                switch score {
                case 0..<25:  nextThreshold = 25
                case 25..<45: nextThreshold = 45
                case 45..<65: nextThreshold = 65
                case 65..<82: nextThreshold = 82
                default:      nextThreshold = 100
                }
                let needed = max(0, nextThreshold - score)
                self.rankProgress.configure(current: score, nextRank: nextThreshold, pointsNeeded: needed)
            }
        }
    }

    private func gradientColorsForScore(_ score: Int) -> [UIColor] {
        switch score {
        case 82...100: return [AIONDesign.accentSuccess, AIONDesign.accentSecondary]
        case 65...81:  return [AIONDesign.accentSecondary, AIONDesign.accentPrimary]
        case 45...64:  return [AIONDesign.accentPrimary, AIONDesign.accentSecondary]
        case 25...44:  return [AIONDesign.accentWarning, AIONDesign.accentPrimary]
        default:       return [AIONDesign.accentDanger, AIONDesign.accentWarning]
        }
    }

    private func loadSocialData() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        FollowFirestoreSync.fetchFollowersCount(for: uid) { [weak self] c in
            DispatchQueue.main.async { self?.followersStatValue.text = "\(c)" }
        }
        FollowFirestoreSync.fetchFollowingCount(for: uid) { [weak self] c in
            DispatchQueue.main.async {
                // followingStatValue not displayed in badge row, but keep data loaded
            }
        }
    }

    private func loadProfileMetrics() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        HealthKitManager.shared.requestAuthorization { [weak self] ok, _ in
            guard ok else { return }
            HealthKitManager.shared.fetchProfileMetrics { h, w in
                HealthKitManager.shared.fetchDateOfBirth { a in
                    self?.updateMetricLabels(heightCm: h, weightKg: w, ageYears: a)
                }
            }
        }
    }

    private func updateMetricLabels(heightCm: Double?, weightKg: Double?, ageYears: Int?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.heightValueLabel.text = heightCm != nil && heightCm! > 0
                ? String(format: "%.0f cm", heightCm!) : "\u{2014} cm"
            self.weightValueLabel.text = weightKg != nil && weightKg! > 0
                ? String(format: "%.1f kg", weightKg!) : "\u{2014} kg"
            if let a = ageYears, a > 0 {
                self.thirdTitleLabel.text = "profile.age".localized
                self.thirdValueLabel.text = "\(a) \("unit.years".localized)"
            } else if let h = heightCm, let w = weightKg, h > 0, w > 0 {
                let bmi = w / ((h / 100) * (h / 100))
                self.thirdTitleLabel.text = "BMI"
                self.thirdValueLabel.text = String(format: "%.1f", bmi)
            } else {
                self.thirdTitleLabel.text = "profile.age".localized
                self.thirdValueLabel.text = "\u{2014} \("unit.years".localized)"
            }
        }
    }

    // MARK: - User Info

    private func updateUserInfo() {
        guard Auth.auth().currentUser != nil else { return }
        ProfileFirestoreSync.fetchDisplayName { [weak self] name in
            guard let self = self else { return }
            if let n = name, !n.isEmpty { self.nameLabel.text = n; return }
            guard let u = Auth.auth().currentUser else { return }
            self.nameLabel.text = u.displayName ?? u.email ?? "profile.user".localized
        }
    }

    // MARK: - Profile Photo

    private func loadProfilePhoto() {
        ProfileFirestoreSync.fetchPhotoURL { [weak self] url in self?.applyProfilePhoto(url: url) }
    }

    private func applyProfilePhoto(url: String?) {
        if let u = url, let uu = URL(string: u) {
            URLSession.shared.dataTask(with: uu) { [weak self] data, resp, _ in
                if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
                    DispatchQueue.main.async { self?.tryAuthPhotoOrDefault() }; return
                }
                guard let d = data, let img = UIImage(data: d) else {
                    DispatchQueue.main.async { self?.tryAuthPhotoOrDefault() }; return
                }
                DispatchQueue.main.async {
                    self?.avatarRing.image = img
                    self?.backgroundImageView.image = img
                }
            }.resume()
        } else { tryAuthPhotoOrDefault() }
    }

    private func tryAuthPhotoOrDefault() {
        if let u = Auth.auth().currentUser?.photoURL?.absoluteString, let uu = URL(string: u) {
            URLSession.shared.dataTask(with: uu) { [weak self] data, _, _ in
                guard let d = data, let img = UIImage(data: d) else {
                    DispatchQueue.main.async {
                        self?.avatarRing.image = nil
                        self?.backgroundImageView.image = nil
                    }; return
                }
                DispatchQueue.main.async {
                    self?.avatarRing.image = img
                    self?.backgroundImageView.image = img
                }
            }.resume()
        } else {
            avatarRing.image = nil
            backgroundImageView.image = nil
        }
    }

    // MARK: - Photo Change

    @objc private func changePhotoTapped() {
        if #available(iOS 14, *) {
            var config = PHPickerConfiguration()
            config.filter = .images; config.selectionLimit = 1
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = self; present(picker, animated: true)
        } else {
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary; picker.delegate = self
            picker.mediaTypes = ["public.image"]; present(picker, animated: true)
        }
    }

    // MARK: - Name Editing

    @objc private func nameTapped() {
        AnalyticsService.shared.logEvent(.profileEditTapped)
        let alert = UIAlertController(title: "profile.editName".localized, message: "profile.enterName".localized, preferredStyle: .alert)
        alert.addTextField { [weak self] tf in
            tf.text = self?.nameLabel.text
            tf.placeholder = "profile.name".localized
            tf.textAlignment = LocalizationManager.shared.textAlignment
        }
        alert.addAction(UIAlertAction(title: "cancel".localized, style: .cancel))
        alert.addAction(UIAlertAction(title: "save".localized, style: .default) { [weak self] _ in
            guard let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return }
            self?.saveDisplayName(name)
        })
        present(alert, animated: true)
    }

    private func saveDisplayName(_ name: String) {
        let req = Auth.auth().currentUser?.createProfileChangeRequest()
        req?.displayName = name
        req?.commitChanges { [weak self] err in
            DispatchQueue.main.async {
                if let e = err {
                    let a = UIAlertController(title: "error".localized, message: e.localizedDescription, preferredStyle: .alert)
                    a.addAction(UIAlertAction(title: "ok".localized, style: .default))
                    self?.present(a, animated: true); return
                }
                self?.nameLabel.text = name
                ProfileFirestoreSync.saveDisplayName(name)
            }
        }
    }

    @objc private func profileCardInfoTapped(_ sender: CardInfoButton) {
        let alert = UIAlertController(title: "dashboard.explanation".localized, message: sender.explanation, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "understand".localized, style: .default))
        present(alert, animated: true)
    }

    // MARK: - Observers

    @objc private func dataSourceDidChange() {}

    @objc private func backgroundColorDidChange() {
        view.backgroundColor = AIONDesign.background
        navigationController?.navigationBar.barStyle = AIONDesign.navBarStyle
        navigationController?.navigationBar.barTintColor = AIONDesign.background
        navigationController?.navigationBar.backgroundColor = AIONDesign.background
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: AIONDesign.textPrimary]
    }
}

// MARK: - UIScrollViewDelegate (Parallax)

extension ProfileViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offset = scrollView.contentOffset.y
        let parallaxFactor: CGFloat = 0.3
        backgroundImageView.transform = CGAffineTransform(translationX: 0, y: min(0, offset * parallaxFactor))
    }
}

// MARK: - PHPickerViewControllerDelegate

extension ProfileViewController: PHPickerViewControllerDelegate {
    @available(iOS 14, *)
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let r = results.first else { return }
        r.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
            guard let img = obj as? UIImage else { return }
            DispatchQueue.main.async { self?.uploadAndSaveProfilePhoto(img) }
        }
    }
}

// MARK: - UIImagePickerControllerDelegate

extension ProfileViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let img = info[.originalImage] as? UIImage else { return }
        uploadAndSaveProfilePhoto(img)
    }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { picker.dismiss(animated: true) }
}

// MARK: - Photo Upload

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
        overlay.addSubview(sp); sp.startAnimating()

        ProfileFirestoreSync.uploadProfileImage(image) { [weak self] result in
            DispatchQueue.main.async {
                overlay.removeFromSuperview()
                switch result {
                case .success(let url):
                    ProfileFirestoreSync.savePhotoURL(url) { _ in }
                    self?.applyProfilePhoto(url: url)
                case .failure(let err):
                    let a = UIAlertController(title: "error".localized, message: err.localizedDescription, preferredStyle: .alert)
                    a.addAction(UIAlertAction(title: "ok".localized, style: .default))
                    self?.present(a, animated: true)
                }
            }
        }
    }
}
