//
//  ProfileViewController.swift
//  Health Reporter
//
//  2026 Social-First Profile — Instagram-style layout with integrated stats,
//  circular progress score, share/edit buttons, and body metrics card.
//

import UIKit
import FirebaseAuth
import HealthKit
import PhotosUI

final class ProfileViewController: UIViewController {

    // MARK: - UI Components

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // ─── Profile Header (Instagram-style) ───
    private let headerCard = UIView()
    private let ambientGlowLayer = CAGradientLayer()
    private let avatarImageView = UIImageView()
    private let cameraButton = UIButton(type: .system)
    private let nameLabel = UILabel()
    private let editNameButton = UIButton(type: .system)
    private let tierChip = UIView()
    private let tierIcon = UILabel()
    private let tierTextLabel = UILabel()

    // Stats columns (Score | Followers | Following)
    private let statsContainer = UIView()
    private let scoreStatValue = UILabel()
    private let scoreStatLabel = UILabel()
    private let followersStatValue = UILabel()
    private let followersStatLabel = UILabel()
    private let followingStatValue = UILabel()
    private let followingStatLabel = UILabel()

    // Action buttons
    private let editProfileButton = UIButton(type: .system)
    private let shareProfileButton = UIButton(type: .system)

    // ─── Score Showcase ───
    private let scoreCard = UIView()
    private let circularProgress: CircularProgressView = {
        let v = CircularProgressView()
        v.size = 100
        return v
    }()
    private let scoreDescLabel = UILabel()
    private let carSubtitle = UILabel()
    private let progressTrack = UIView()
    private let progressFill = UIView()
    private let progressGradient = CAGradientLayer()

    // ─── Metrics Grid ───
    private let metricsCard = UIView()
    private var heightMetricRow: MetricRowView?
    private var weightMetricRow: MetricRowView?
    private var thirdMetricRow: MetricRowView?

    // Flags
    private var hasAppearedOnce = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "profile.title".localized
        view.backgroundColor = AIONDesign.background
        view.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute

        setupNavigationBar()
        setupScrollView()
        buildHeaderCard()
        buildScoreCard()
        buildMetricsCard()

        updateUserInfo()
        loadProfilePhoto()
        loadHealthScoreData()

        NotificationCenter.default.addObserver(self, selector: #selector(dataSourceDidChange), name: .dataSourceChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(backgroundColorDidChange), name: .backgroundColorChanged, object: nil)

        AnalyticsService.shared.logScreenView(.profile)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadProfileMetrics()
        loadProfilePhoto()
        loadSocialData()
        updateUserInfo()
        loadHealthScoreData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        hasAppearedOnce = true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        ambientGlowLayer.frame = headerCard.bounds
        progressGradient.frame = progressFill.bounds

        let s = avatarImageView.bounds.width
        avatarImageView.layer.cornerRadius = s / 2
    }

    // MARK: - Navigation Bar

    private func setupNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: AIONDesign.textPrimary]
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance

        // Settings (always on the right)
        let gearBtn = UIBarButtonItem(
            image: UIImage(systemName: "gearshape.fill",
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)),
            style: .plain, target: self, action: #selector(settingsTapped)
        )
        gearBtn.tintColor = AIONDesign.textSecondary
        navigationItem.rightBarButtonItem = gearBtn
    }

    @objc private func settingsTapped() {
        let vc = SettingsViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Scroll View

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.contentInsetAdjustmentBehavior = .automatic
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 20
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -40),
        ])
    }

    // MARK: - Header Card (Instagram-Style: Avatar + Name + Tier + Stats + Buttons)

    private func buildHeaderCard() {
        headerCard.translatesAutoresizingMaskIntoConstraints = false
        headerCard.backgroundColor = AIONDesign.surface
        headerCard.layer.cornerRadius = 28
        headerCard.clipsToBounds = true

        // Ambient glow
        ambientGlowLayer.type = .conic
        ambientGlowLayer.colors = [
            AIONDesign.accentPrimary.withAlphaComponent(0.18).cgColor,
            AIONDesign.accentSecondary.withAlphaComponent(0.12).cgColor,
            AIONDesign.accentSuccess.withAlphaComponent(0.08).cgColor,
            AIONDesign.accentPrimary.withAlphaComponent(0.18).cgColor,
        ]
        ambientGlowLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        ambientGlowLayer.endPoint = CGPoint(x: 0.5, y: 0)
        headerCard.layer.insertSublayer(ambientGlowLayer, at: 0)

        // Avatar
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.backgroundColor = AIONDesign.surfaceElevated
        avatarImageView.layer.borderWidth = 3.5
        avatarImageView.layer.borderColor = AIONDesign.accentPrimary.withAlphaComponent(0.4).cgColor
        avatarImageView.isUserInteractionEnabled = true
        let avatarTap = UITapGestureRecognizer(target: self, action: #selector(changePhotoTapped))
        avatarImageView.addGestureRecognizer(avatarTap)
        headerCard.addSubview(avatarImageView)

        // Camera overlay button
        cameraButton.translatesAutoresizingMaskIntoConstraints = false
        cameraButton.setImage(UIImage(systemName: "camera.fill",
                                       withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)), for: .normal)
        cameraButton.tintColor = .white
        cameraButton.backgroundColor = AIONDesign.accentPrimary
        cameraButton.layer.cornerRadius = 15
        cameraButton.layer.borderWidth = 2.5
        cameraButton.layer.borderColor = AIONDesign.surface.cgColor
        cameraButton.addTarget(self, action: #selector(changePhotoTapped), for: .touchUpInside)
        headerCard.addSubview(cameraButton)

        // Name
        nameLabel.text = "profile.user".localized
        nameLabel.font = .systemFont(ofSize: 24, weight: .black)
        nameLabel.textColor = AIONDesign.textPrimary
        nameLabel.textAlignment = .center
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.7
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        headerCard.addSubview(nameLabel)

        // Edit name button
        editNameButton.setImage(UIImage(systemName: "square.and.pencil",
                                         withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)), for: .normal)
        editNameButton.tintColor = AIONDesign.textTertiary
        editNameButton.translatesAutoresizingMaskIntoConstraints = false
        editNameButton.addTarget(self, action: #selector(nameTapped), for: .touchUpInside)
        headerCard.addSubview(editNameButton)

        // Tier chip
        tierChip.translatesAutoresizingMaskIntoConstraints = false
        tierChip.backgroundColor = AIONDesign.surfaceElevated
        tierChip.layer.cornerRadius = 14
        headerCard.addSubview(tierChip)

        tierIcon.font = .systemFont(ofSize: 14)
        tierIcon.translatesAutoresizingMaskIntoConstraints = false
        tierChip.addSubview(tierIcon)

        tierTextLabel.font = .systemFont(ofSize: 12, weight: .bold)
        tierTextLabel.textColor = AIONDesign.textSecondary
        tierTextLabel.translatesAutoresizingMaskIntoConstraints = false
        tierChip.addSubview(tierTextLabel)

        // ── Stats Row (Instagram-style: Score | Followers | Following) ──
        statsContainer.translatesAutoresizingMaskIntoConstraints = false
        headerCard.addSubview(statsContainer)

        let statColumns = buildStatsColumns()
        statsContainer.addSubview(statColumns)
        statColumns.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statColumns.topAnchor.constraint(equalTo: statsContainer.topAnchor),
            statColumns.leadingAnchor.constraint(equalTo: statsContainer.leadingAnchor),
            statColumns.trailingAnchor.constraint(equalTo: statsContainer.trailingAnchor),
            statColumns.bottomAnchor.constraint(equalTo: statsContainer.bottomAnchor),
        ])

        // ── Action Buttons ──
        configureActionButton(editProfileButton, title: "profile.editProfile".localized, filled: true)
        editProfileButton.addTarget(self, action: #selector(nameTapped), for: .touchUpInside)

        configureActionButton(shareProfileButton, title: "profile.shareProfile".localized, filled: false)
        shareProfileButton.addTarget(self, action: #selector(shareProfileTapped), for: .touchUpInside)

        let buttonsStack = UIStackView(arrangedSubviews: [editProfileButton, shareProfileButton])
        buttonsStack.axis = .horizontal
        buttonsStack.spacing = 10
        buttonsStack.distribution = .fillEqually
        buttonsStack.translatesAutoresizingMaskIntoConstraints = false
        headerCard.addSubview(buttonsStack)

        // ── Constraints ──
        NSLayoutConstraint.activate([
            avatarImageView.topAnchor.constraint(equalTo: headerCard.topAnchor, constant: 24),
            avatarImageView.centerXAnchor.constraint(equalTo: headerCard.centerXAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 100),
            avatarImageView.heightAnchor.constraint(equalToConstant: 100),

            cameraButton.trailingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 4),
            cameraButton.bottomAnchor.constraint(equalTo: avatarImageView.bottomAnchor, constant: 4),
            cameraButton.widthAnchor.constraint(equalToConstant: 30),
            cameraButton.heightAnchor.constraint(equalToConstant: 30),

            nameLabel.topAnchor.constraint(equalTo: avatarImageView.bottomAnchor, constant: 14),
            nameLabel.centerXAnchor.constraint(equalTo: headerCard.centerXAnchor),
            nameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: headerCard.leadingAnchor, constant: 44),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: editNameButton.leadingAnchor, constant: -4),

            editNameButton.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            editNameButton.trailingAnchor.constraint(lessThanOrEqualTo: headerCard.trailingAnchor, constant: -20),
            editNameButton.widthAnchor.constraint(equalToConstant: 30),
            editNameButton.heightAnchor.constraint(equalToConstant: 30),

            tierChip.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            tierChip.centerXAnchor.constraint(equalTo: headerCard.centerXAnchor),
            tierChip.heightAnchor.constraint(equalToConstant: 28),

            tierIcon.leadingAnchor.constraint(equalTo: tierChip.leadingAnchor, constant: 10),
            tierIcon.centerYAnchor.constraint(equalTo: tierChip.centerYAnchor),

            tierTextLabel.leadingAnchor.constraint(equalTo: tierIcon.trailingAnchor, constant: 5),
            tierTextLabel.trailingAnchor.constraint(equalTo: tierChip.trailingAnchor, constant: -12),
            tierTextLabel.centerYAnchor.constraint(equalTo: tierChip.centerYAnchor),

            // Stats row
            statsContainer.topAnchor.constraint(equalTo: tierChip.bottomAnchor, constant: 18),
            statsContainer.leadingAnchor.constraint(equalTo: headerCard.leadingAnchor, constant: 16),
            statsContainer.trailingAnchor.constraint(equalTo: headerCard.trailingAnchor, constant: -16),

            // Buttons
            buttonsStack.topAnchor.constraint(equalTo: statsContainer.bottomAnchor, constant: 18),
            buttonsStack.leadingAnchor.constraint(equalTo: headerCard.leadingAnchor, constant: 20),
            buttonsStack.trailingAnchor.constraint(equalTo: headerCard.trailingAnchor, constant: -20),
            buttonsStack.heightAnchor.constraint(equalToConstant: 36),
            buttonsStack.bottomAnchor.constraint(equalTo: headerCard.bottomAnchor, constant: -20),
        ])

        contentStack.addArrangedSubview(headerCard)
        setDefaultAvatar()
    }

    /// Build the 3-column stats row: Score | Followers | Following
    private func buildStatsColumns() -> UIStackView {
        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        func makeColumn(value: UILabel, label: UILabel, labelText: String, action: Selector?) -> UIView {
            let container = UIView()
            container.translatesAutoresizingMaskIntoConstraints = false

            value.text = "—"
            value.font = .monospacedDigitSystemFont(ofSize: 20, weight: .black)
            value.textColor = AIONDesign.textPrimary
            value.textAlignment = .center
            value.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(value)

            label.text = labelText
            label.font = .systemFont(ofSize: 11, weight: .semibold)
            label.textColor = AIONDesign.textTertiary
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(label)

            NSLayoutConstraint.activate([
                value.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
                value.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                label.topAnchor.constraint(equalTo: value.bottomAnchor, constant: 2),
                label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
            ])

            if let action = action {
                container.isUserInteractionEnabled = true
                container.addGestureRecognizer(UITapGestureRecognizer(target: self, action: action))
            }

            return container
        }

        let scoreCol = makeColumn(value: scoreStatValue, label: scoreStatLabel, labelText: "profile.score".localized, action: nil)
        let followersCol = makeColumn(value: followersStatValue, label: followersStatLabel, labelText: "social.followers".localized, action: #selector(followersTapped))
        let followingCol = makeColumn(value: followingStatValue, label: followingStatLabel, labelText: "social.following".localized, action: #selector(followingTapped))

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .center
        stack.spacing = 0
        stack.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute

        stack.addArrangedSubview(scoreCol)
        stack.addArrangedSubview(followersCol)
        stack.addArrangedSubview(followingCol)

        // Thin vertical dividers (non-arranged, positioned between columns)
        let div1 = makeThinVerticalDivider()
        let div2 = makeThinVerticalDivider()
        stack.addSubview(div1)
        stack.addSubview(div2)

        NSLayoutConstraint.activate([
            div1.centerYAnchor.constraint(equalTo: stack.centerYAnchor),
            div1.leadingAnchor.constraint(equalTo: scoreCol.trailingAnchor),
            div2.centerYAnchor.constraint(equalTo: stack.centerYAnchor),
            div2.leadingAnchor.constraint(equalTo: followersCol.trailingAnchor),
        ])

        return stack
    }

    private func makeThinVerticalDivider() -> UIView {
        let div = UIView()
        div.translatesAutoresizingMaskIntoConstraints = false
        div.backgroundColor = AIONDesign.separator.withAlphaComponent(0.2)
        NSLayoutConstraint.activate([
            div.widthAnchor.constraint(equalToConstant: 0.5),
            div.heightAnchor.constraint(equalToConstant: 30),
        ])
        return div
    }

    private func configureActionButton(_ button: UIButton, title: String, filled: Bool) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .bold)
        button.layer.cornerRadius = 10

        if filled {
            button.backgroundColor = AIONDesign.accentPrimary
            button.setTitleColor(.white, for: .normal)
        } else {
            button.backgroundColor = .clear
            button.setTitleColor(AIONDesign.textPrimary, for: .normal)
            button.layer.borderWidth = 1
            button.layer.borderColor = AIONDesign.separator.withAlphaComponent(0.4).cgColor
        }
    }

    // MARK: - Score Card (Circular Progress + Description)

    private func buildScoreCard() {
        scoreCard.translatesAutoresizingMaskIntoConstraints = false
        scoreCard.backgroundColor = AIONDesign.surface
        scoreCard.layer.cornerRadius = 22
        scoreCard.clipsToBounds = true

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        // Circular progress
        circularProgress.translatesAutoresizingMaskIntoConstraints = false
        scoreCard.addSubview(circularProgress)

        // Description
        scoreDescLabel.text = ""
        scoreDescLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        scoreDescLabel.textColor = AIONDesign.accentSecondary
        scoreDescLabel.numberOfLines = 2
        scoreDescLabel.textAlignment = LocalizationManager.shared.textAlignment
        scoreDescLabel.translatesAutoresizingMaskIntoConstraints = false
        scoreCard.addSubview(scoreDescLabel)

        // Car subtitle
        carSubtitle.font = .systemFont(ofSize: 12, weight: .medium)
        carSubtitle.textColor = AIONDesign.textTertiary
        carSubtitle.textAlignment = LocalizationManager.shared.textAlignment
        carSubtitle.translatesAutoresizingMaskIntoConstraints = false
        scoreCard.addSubview(carSubtitle)

        // Title label
        let scoreTitleLabel = UILabel()
        scoreTitleLabel.text = "dashboard.healthScore".localized
        scoreTitleLabel.font = .systemFont(ofSize: 12, weight: .bold)
        scoreTitleLabel.textColor = AIONDesign.textTertiary
        scoreTitleLabel.textAlignment = LocalizationManager.shared.textAlignment
        scoreTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        scoreCard.addSubview(scoreTitleLabel)

        // Progress bar
        progressTrack.translatesAutoresizingMaskIntoConstraints = false
        progressTrack.backgroundColor = AIONDesign.surfaceElevated
        progressTrack.layer.cornerRadius = 5
        scoreCard.addSubview(progressTrack)

        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressFill.layer.cornerRadius = 5
        progressFill.clipsToBounds = true
        progressTrack.addSubview(progressFill)

        progressGradient.colors = [AIONDesign.accentPrimary.cgColor, AIONDesign.accentSuccess.cgColor]
        progressGradient.startPoint = CGPoint(x: 0, y: 0.5)
        progressGradient.endPoint = CGPoint(x: 1, y: 0.5)
        progressGradient.cornerRadius = 5
        progressFill.layer.insertSublayer(progressGradient, at: 0)

        // Common constraints
        NSLayoutConstraint.activate([
            progressTrack.bottomAnchor.constraint(equalTo: scoreCard.bottomAnchor, constant: -18),
            progressTrack.leadingAnchor.constraint(equalTo: scoreCard.leadingAnchor, constant: 20),
            progressTrack.trailingAnchor.constraint(equalTo: scoreCard.trailingAnchor, constant: -20),
            progressTrack.heightAnchor.constraint(equalToConstant: 8),

            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),
            progressFill.widthAnchor.constraint(equalTo: progressTrack.widthAnchor, multiplier: 0.01),
        ])

        if isRTL {
            NSLayoutConstraint.activate([
                circularProgress.topAnchor.constraint(equalTo: scoreCard.topAnchor, constant: 20),
                circularProgress.leftAnchor.constraint(equalTo: scoreCard.leftAnchor, constant: 24),
                circularProgress.widthAnchor.constraint(equalToConstant: 100),
                circularProgress.heightAnchor.constraint(equalToConstant: 100),

                scoreTitleLabel.topAnchor.constraint(equalTo: scoreCard.topAnchor, constant: 24),
                scoreTitleLabel.rightAnchor.constraint(equalTo: scoreCard.rightAnchor, constant: -24),
                scoreTitleLabel.leftAnchor.constraint(greaterThanOrEqualTo: circularProgress.rightAnchor, constant: 16),

                scoreDescLabel.topAnchor.constraint(equalTo: scoreTitleLabel.bottomAnchor, constant: 6),
                scoreDescLabel.rightAnchor.constraint(equalTo: scoreTitleLabel.rightAnchor),
                scoreDescLabel.leftAnchor.constraint(greaterThanOrEqualTo: circularProgress.rightAnchor, constant: 16),

                carSubtitle.topAnchor.constraint(equalTo: scoreDescLabel.bottomAnchor, constant: 4),
                carSubtitle.rightAnchor.constraint(equalTo: scoreTitleLabel.rightAnchor),
            ])
        } else {
            NSLayoutConstraint.activate([
                circularProgress.topAnchor.constraint(equalTo: scoreCard.topAnchor, constant: 20),
                circularProgress.leadingAnchor.constraint(equalTo: scoreCard.leadingAnchor, constant: 24),
                circularProgress.widthAnchor.constraint(equalToConstant: 100),
                circularProgress.heightAnchor.constraint(equalToConstant: 100),

                scoreTitleLabel.topAnchor.constraint(equalTo: scoreCard.topAnchor, constant: 24),
                scoreTitleLabel.leadingAnchor.constraint(equalTo: circularProgress.trailingAnchor, constant: 16),
                scoreTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: scoreCard.trailingAnchor, constant: -24),

                scoreDescLabel.topAnchor.constraint(equalTo: scoreTitleLabel.bottomAnchor, constant: 6),
                scoreDescLabel.leadingAnchor.constraint(equalTo: scoreTitleLabel.leadingAnchor),
                scoreDescLabel.trailingAnchor.constraint(lessThanOrEqualTo: scoreCard.trailingAnchor, constant: -24),

                carSubtitle.topAnchor.constraint(equalTo: scoreDescLabel.bottomAnchor, constant: 4),
                carSubtitle.leadingAnchor.constraint(equalTo: scoreTitleLabel.leadingAnchor),
            ])
        }

        circularProgress.bottomAnchor.constraint(lessThanOrEqualTo: progressTrack.topAnchor, constant: -12).isActive = true
        carSubtitle.bottomAnchor.constraint(lessThanOrEqualTo: progressTrack.topAnchor, constant: -12).isActive = true

        contentStack.addArrangedSubview(scoreCard)
    }

    // MARK: - Metrics Card

    private func buildMetricsCard() {
        metricsCard.translatesAutoresizingMaskIntoConstraints = false
        metricsCard.backgroundColor = AIONDesign.surface
        metricsCard.layer.cornerRadius = 22

        let titleLabel = UILabel()
        titleLabel.text = "profile.bodyMetrics".localized
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = AIONDesign.textPrimary
        titleLabel.textAlignment = LocalizationManager.shared.textAlignment
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        metricsCard.addSubview(titleLabel)

        let hr = MetricRowView(icon: "ruler.fill", title: "profile.height".localized, value: "— cm", explanation: CardExplanations.profileHeight)
        hr.infoButton?.addTarget(self, action: #selector(profileCardInfoTapped(_:)), for: .touchUpInside)
        heightMetricRow = hr

        let wr = MetricRowView(icon: "scalemass.fill", title: "profile.weight".localized, value: "— kg", explanation: CardExplanations.profileWeight)
        wr.infoButton?.addTarget(self, action: #selector(profileCardInfoTapped(_:)), for: .touchUpInside)
        weightMetricRow = wr

        let ar = MetricRowView(icon: "birthday.cake.fill", title: "profile.age".localized, value: "— \("unit.years".localized)", explanation: CardExplanations.profileAge)
        ar.infoButton?.addTarget(self, action: #selector(profileCardInfoTapped(_:)), for: .touchUpInside)
        thirdMetricRow = ar

        let metricStack = UIStackView(arrangedSubviews: [hr, makeThinSeparator(), wr, makeThinSeparator(), ar])
        metricStack.axis = .vertical
        metricStack.spacing = 0
        metricStack.translatesAutoresizingMaskIntoConstraints = false
        metricsCard.addSubview(metricStack)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: metricsCard.topAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: metricsCard.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: metricsCard.trailingAnchor, constant: -20),

            metricStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            metricStack.leadingAnchor.constraint(equalTo: metricsCard.leadingAnchor),
            metricStack.trailingAnchor.constraint(equalTo: metricsCard.trailingAnchor),
            metricStack.bottomAnchor.constraint(equalTo: metricsCard.bottomAnchor, constant: -8),
        ])

        contentStack.addArrangedSubview(metricsCard)
    }

    private func makeThinSeparator() -> UIView {
        let sep = UIView()
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.backgroundColor = AIONDesign.separator.withAlphaComponent(0.15)
        sep.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return sep
    }

    // MARK: - Entrance Animations

    private func playEntranceAnimations() {
        let views = contentStack.arrangedSubviews
        for (i, v) in views.enumerated() {
            v.alpha = 0
            v.transform = i == 0
                ? CGAffineTransform(scaleX: 0.92, y: 0.92)
                : CGAffineTransform(translationX: 0, y: 24)
        }
        for (i, v) in views.enumerated() {
            UIView.animate(withDuration: 0.55, delay: Double(i) * 0.08,
                           usingSpringWithDamping: 0.78, initialSpringVelocity: 0.3, options: .curveEaseOut) {
                v.alpha = 1; v.transform = .identity
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

        let score = AnalysisCache.loadHealthScore() ?? 0
        let text = String(format: "profile.shareText".localized, score)
        let ac = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        ac.popoverPresentationController?.sourceView = shareProfileButton
        present(ac, animated: true)
    }

    // MARK: - Data Loading

    private func loadHealthScoreData() {
        if let score = AnalysisCache.loadHealthScore() {
            scoreStatValue.text = "\(score)"

            // Update circular progress
            circularProgress.score = score

            let fraction = CGFloat(score) / 100.0
            progressFill.superview?.constraints.forEach { c in
                if c.firstItem as? UIView === progressFill && c.firstAttribute == .width { c.isActive = false }
            }
            progressFill.widthAnchor.constraint(equalTo: progressTrack.widthAnchor, multiplier: max(fraction, 0.01)).isActive = true
            UIView.animate(withDuration: 0.7, delay: 0.15, options: .curveEaseOut) { self.scoreCard.layoutIfNeeded() }

            let colors = gradientColorsForScore(score)
            progressGradient.colors = colors.map { $0.cgColor }
            scoreDescLabel.text = descriptionForScore(score)

            let tier = CarTierEngine.tierForScore(score)
            tierIcon.text = tier.emoji
            tierTextLabel.text = tier.tierLabel
            avatarImageView.layer.borderColor = tier.color.withAlphaComponent(0.4).cgColor

            if let car = AnalysisCache.loadSelectedCar() {
                carSubtitle.text = car.name
            } else {
                carSubtitle.text = tier.name
            }
        } else {
            scoreStatValue.text = "0"
            circularProgress.score = 0
            scoreDescLabel.text = "score.no_data".localized
            tierIcon.text = ""
            tierTextLabel.text = ""
            carSubtitle.text = ""
        }
    }

    private func descriptionForScore(_ score: Int) -> String {
        switch score {
        case 82...100: return "score.description.very_high".localized
        case 65...81:  return "score.description.high".localized
        case 45...64:  return "score.description.medium".localized
        case 25...44:  return "score.description.low".localized
        default:       return "score.description.very_low".localized
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
            DispatchQueue.main.async { self?.followingStatValue.text = "\(c)" }
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
        heightMetricRow?.updateValue(heightCm != nil && heightCm! > 0 ? String(format: "%.0f cm", heightCm!) : "— cm")
        weightMetricRow?.updateValue(weightKg != nil && weightKg! > 0 ? String(format: "%.1f kg", weightKg!) : "— kg")

        if let a = ageYears, a > 0 {
            thirdMetricRow?.updateTitle("profile.age".localized)
            thirdMetricRow?.updateValue("\(a) \("unit.years".localized)")
        } else if let h = heightCm, let w = weightKg, h > 0, w > 0 {
            let bmi = w / ((h / 100) * (h / 100))
            thirdMetricRow?.updateTitle("BMI")
            thirdMetricRow?.updateValue(String(format: "%.1f", bmi))
        } else {
            thirdMetricRow?.updateTitle("profile.age".localized)
            thirdMetricRow?.updateValue("— \("unit.years".localized)")
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
                    self?.avatarImageView.image = img
                    self?.avatarImageView.contentMode = .scaleAspectFill
                }
            }.resume()
        } else { tryAuthPhotoOrDefault() }
    }

    private func tryAuthPhotoOrDefault() {
        if let u = Auth.auth().currentUser?.photoURL?.absoluteString, let uu = URL(string: u) {
            URLSession.shared.dataTask(with: uu) { [weak self] data, _, _ in
                guard let d = data, let img = UIImage(data: d) else {
                    DispatchQueue.main.async { self?.setDefaultAvatar() }; return
                }
                DispatchQueue.main.async {
                    self?.avatarImageView.image = img
                    self?.avatarImageView.contentMode = .scaleAspectFill
                }
            }.resume()
        } else { setDefaultAvatar() }
    }

    private func setDefaultAvatar() {
        let cfg = UIImage.SymbolConfiguration(pointSize: 44, weight: .ultraLight)
        avatarImageView.image = UIImage(systemName: "person.circle.fill", withConfiguration: cfg)
        avatarImageView.tintColor = AIONDesign.textTertiary
        avatarImageView.contentMode = .scaleAspectFit
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
                    self?.avatarImageView.contentMode = .scaleAspectFill
                case .failure(let err):
                    let a = UIAlertController(title: "error".localized, message: err.localizedDescription, preferredStyle: .alert)
                    a.addAction(UIAlertAction(title: "ok".localized, style: .default))
                    self?.present(a, animated: true)
                }
            }
        }
    }
}

// MARK: - MetricRowView (reusable metric row)

private final class MetricRowView: UIView {
    private let titleLbl = UILabel()
    private let valueLbl = UILabel()
    var infoButton: CardInfoButton?

    init(icon: String, title: String, value: String, explanation: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        let iconImg = UIImageView(image: UIImage(systemName: icon,
                                                   withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)))
        iconImg.tintColor = AIONDesign.accentPrimary
        iconImg.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconImg)

        titleLbl.text = title
        titleLbl.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLbl.textColor = AIONDesign.textSecondary
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLbl)

        valueLbl.text = value
        valueLbl.font = .monospacedDigitSystemFont(ofSize: 17, weight: .bold)
        valueLbl.textColor = AIONDesign.textPrimary
        valueLbl.translatesAutoresizingMaskIntoConstraints = false
        addSubview(valueLbl)

        let info = CardInfoButton.make(explanation: explanation)
        infoButton = info
        addSubview(info)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 52),
            iconImg.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLbl.centerYAnchor.constraint(equalTo: centerYAnchor),
            valueLbl.centerYAnchor.constraint(equalTo: centerYAnchor),
            info.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        if isRTL {
            NSLayoutConstraint.activate([
                iconImg.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
                titleLbl.trailingAnchor.constraint(equalTo: iconImg.leadingAnchor, constant: -8),
                valueLbl.leadingAnchor.constraint(equalTo: info.trailingAnchor, constant: 8),
                info.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            ])
        } else {
            NSLayoutConstraint.activate([
                iconImg.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
                titleLbl.leadingAnchor.constraint(equalTo: iconImg.trailingAnchor, constant: 8),
                valueLbl.trailingAnchor.constraint(equalTo: info.leadingAnchor, constant: -8),
                info.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            ])
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func updateValue(_ v: String) { valueLbl.text = v }
    func updateTitle(_ t: String) { titleLbl.text = t }
}
