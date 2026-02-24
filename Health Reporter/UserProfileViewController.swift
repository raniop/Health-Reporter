//
//  UserProfileViewController.swift
//  Health Reporter
//
//  2026 Instagram-style profile for viewing another user.
//  Header card with avatar ring, stats row (Score | Followers | Following),
//  health score card with circular progress, car tier card, about card.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

// MARK: - UserProfileViewController

final class UserProfileViewController: UIViewController {

    // MARK: - Types

    private enum FriendshipStatus: Equatable {
        case unknown
        case notFollowing
        case following
        case followRequestSent(requestId: String)
        case followRequestReceived(requestId: String)
    }

    // MARK: - Properties

    private let userUid: String
    private let db = Firestore.firestore()

    private var userData: (
        displayName: String,
        photoURL: String?,
        healthScore: Int,
        carTierIndex: Int,
        carTierName: String
    )?

    private var followersCount: Int = 0
    private var followingCount: Int = 0
    private var friendshipStatus: FriendshipStatus = .unknown
    private let feedbackGenerator = UINotificationFeedbackGenerator()

    // MARK: - UI -- Chrome

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let loadingSpinner = UIActivityIndicatorView(style: .large)

    // Blurred background photo (WHOOP-style)
    private let backgroundImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.backgroundColor = AIONDesign.background
        return iv
    }()
    private let bgBlurEffectView: UIVisualEffectView = {
        let v = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        v.alpha = 0.7
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let bgGradientOverlay: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let bgGradientLayer = CAGradientLayer()

    // MARK: - UI -- Header Section (transparent, over blur)

    private let headerSection = UIView()

    private let avatarRing: AvatarRingView = {
        let v = AvatarRingView(size: 110)
        v.ringWidth = 3
        v.isAnimated = false
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 26, weight: .black)
        l.textColor = .white
        l.textAlignment = .center
        l.numberOfLines = 2
        l.adjustsFontSizeToFitWidth = true
        l.minimumScaleFactor = 0.7
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

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

    // Action buttons inside header
    private let primaryButton: UIButton = {
        let b = UIButton(type: .system)
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        b.layer.cornerRadius = 10
        b.clipsToBounds = true
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let secondaryButton: UIButton = {
        let b = UIButton(type: .system)
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        b.layer.cornerRadius = 10
        b.layer.borderWidth = 1
        b.clipsToBounds = true
        b.isHidden = true
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    // MARK: - UI -- Score Card

    private let scoreCard = UIView()
    private let circularProgress: CircularProgressView = {
        let v = CircularProgressView()
        v.size = 80
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let scoreDescLabel = UILabel()
    private let carSubtitle = UILabel()
    private let scoreTitleLabel = UILabel()
    private let progressTrack = UIView()
    private let progressFill = UIView()
    private let progressGradient = CAGradientLayer()
    private var progressFillWidthConstraint: NSLayoutConstraint?

    // MARK: - UI -- Car Tier Card

    private let carTierCard = UIView()

    // MARK: - UI -- About Card

    private let aboutCard = UIView()
    private let aboutTitleLabel: UILabel = {
        let l = UILabel()
        l.text = "About"
        l.font = .systemFont(ofSize: 14, weight: .bold)
        l.textColor = AIONDesign.textPrimary
        l.textAlignment = LocalizationManager.shared.textAlignment
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let aboutBodyLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13, weight: .regular)
        l.textColor = AIONDesign.textSecondary
        l.textAlignment = LocalizationManager.shared.textAlignment
        l.numberOfLines = 0
        l.text = "Active user on Health Reporter"
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Init

    init(userUid: String) {
        self.userUid = userUid
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        applyAIONGradientBackground()
        view.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        feedbackGenerator.prepare()

        buildNavigationBar()
        buildLayout()
        loadUserData()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        bgGradientLayer.frame = bgGradientOverlay.bounds
        progressGradient.frame = progressFill.bounds
    }

    // MARK: - Navigation Bar

    private func buildNavigationBar() {
        title = ""
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance

        // Use system back button with custom tint
        navigationController?.navigationBar.tintColor = AIONDesign.textPrimary
        navigationItem.backButtonDisplayMode = .minimal
    }

    // MARK: - Layout

    private func buildLayout() {
        // --- Blurred background photo ---
        view.addSubview(backgroundImageView)
        backgroundImageView.addSubview(bgBlurEffectView)
        backgroundImageView.addSubview(bgGradientOverlay)

        bgGradientLayer.colors = [
            UIColor.clear.cgColor,
            AIONDesign.background.withAlphaComponent(0.3).cgColor,
            AIONDesign.background.withAlphaComponent(0.85).cgColor,
            AIONDesign.background.cgColor,
        ]
        bgGradientLayer.locations = [0, 0.4, 0.75, 1.0]
        bgGradientOverlay.layer.insertSublayer(bgGradientLayer, at: 0)

        // --- Loading spinner ---
        loadingSpinner.translatesAutoresizingMaskIntoConstraints = false
        loadingSpinner.color = AIONDesign.accentPrimary
        view.addSubview(loadingSpinner)

        // --- Scroll view ---
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.backgroundColor = .clear
        scrollView.delegate = self
        view.addSubview(scrollView)

        // --- Content stack (vertical) ---
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        // Build sections
        buildHeaderSection()
        buildStatsCard()
        buildScoreCard()
        buildCarTierCard()
        buildAboutCard()

        // Bottom spacing
        let bottomSpacer = UIView()
        bottomSpacer.translatesAutoresizingMaskIntoConstraints = false
        bottomSpacer.heightAnchor.constraint(equalToConstant: 48).isActive = true
        contentStack.addArrangedSubview(bottomSpacer)

        let hPad: CGFloat = 16

        // --- Constraints ---
        NSLayoutConstraint.activate([
            // Blurred background
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.heightAnchor.constraint(equalToConstant: 380),

            bgBlurEffectView.topAnchor.constraint(equalTo: backgroundImageView.topAnchor),
            bgBlurEffectView.leadingAnchor.constraint(equalTo: backgroundImageView.leadingAnchor),
            bgBlurEffectView.trailingAnchor.constraint(equalTo: backgroundImageView.trailingAnchor),
            bgBlurEffectView.bottomAnchor.constraint(equalTo: backgroundImageView.bottomAnchor),

            bgGradientOverlay.topAnchor.constraint(equalTo: backgroundImageView.topAnchor),
            bgGradientOverlay.leadingAnchor.constraint(equalTo: backgroundImageView.leadingAnchor),
            bgGradientOverlay.trailingAnchor.constraint(equalTo: backgroundImageView.trailingAnchor),
            bgGradientOverlay.bottomAnchor.constraint(equalTo: backgroundImageView.bottomAnchor),

            // Spinner
            loadingSpinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            // Scroll
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Content stack
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 90),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: hPad),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -hPad),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -hPad * 2),
        ])
    }

    // MARK: - Header Section (transparent, over blur)

    private func buildHeaderSection() {
        headerSection.translatesAutoresizingMaskIntoConstraints = false
        headerSection.backgroundColor = .clear

        // Avatar ring
        headerSection.addSubview(avatarRing)

        // Name
        headerSection.addSubview(nameLabel)

        // Tier chip
        tierChip.translatesAutoresizingMaskIntoConstraints = false
        tierChip.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        tierChip.layer.cornerRadius = 14
        tierChip.layer.borderWidth = 0.5
        tierChip.layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
        tierChip.isHidden = true
        headerSection.addSubview(tierChip)

        tierIcon.font = .systemFont(ofSize: 14)
        tierIcon.translatesAutoresizingMaskIntoConstraints = false
        tierChip.addSubview(tierIcon)

        tierTextLabel.font = .systemFont(ofSize: 12, weight: .bold)
        tierTextLabel.textColor = .white
        tierTextLabel.translatesAutoresizingMaskIntoConstraints = false
        tierChip.addSubview(tierTextLabel)

        NSLayoutConstraint.activate([
            avatarRing.topAnchor.constraint(equalTo: headerSection.topAnchor, constant: 8),
            avatarRing.centerXAnchor.constraint(equalTo: headerSection.centerXAnchor),
            avatarRing.widthAnchor.constraint(equalToConstant: 110),
            avatarRing.heightAnchor.constraint(equalToConstant: 110),

            nameLabel.topAnchor.constraint(equalTo: avatarRing.bottomAnchor, constant: 12),
            nameLabel.centerXAnchor.constraint(equalTo: headerSection.centerXAnchor),
            nameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: headerSection.leadingAnchor, constant: 24),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: headerSection.trailingAnchor, constant: -24),

            tierChip.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            tierChip.centerXAnchor.constraint(equalTo: headerSection.centerXAnchor),
            tierChip.heightAnchor.constraint(equalToConstant: 28),
            tierChip.bottomAnchor.constraint(equalTo: headerSection.bottomAnchor, constant: -8),

            tierIcon.leadingAnchor.constraint(equalTo: tierChip.leadingAnchor, constant: 10),
            tierIcon.centerYAnchor.constraint(equalTo: tierChip.centerYAnchor),

            tierTextLabel.leadingAnchor.constraint(equalTo: tierIcon.trailingAnchor, constant: 5),
            tierTextLabel.trailingAnchor.constraint(equalTo: tierChip.trailingAnchor, constant: -12),
            tierTextLabel.centerYAnchor.constraint(equalTo: tierChip.centerYAnchor),
        ])

        contentStack.addArrangedSubview(headerSection)
    }

    // MARK: - Stats + Buttons Card (glass)

    private let statsCard = UIView()

    private func buildStatsCard() {
        statsCard.translatesAutoresizingMaskIntoConstraints = false
        statsCard.backgroundColor = AIONDesign.glassCardBackground
        statsCard.layer.cornerRadius = AIONDesign.cornerRadiusLarge
        statsCard.layer.borderWidth = 1
        statsCard.layer.borderColor = AIONDesign.glassCardBorder.cgColor
        statsCard.clipsToBounds = true

        // Glass blur
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: AIONDesign.glassBlurStyle))
        blur.alpha = AIONDesign.glassBlurAlpha
        blur.translatesAutoresizingMaskIntoConstraints = false
        statsCard.addSubview(blur)

        // Stats row
        statsContainer.translatesAutoresizingMaskIntoConstraints = false
        statsCard.addSubview(statsContainer)

        let statColumns = buildStatsColumns()
        statsContainer.addSubview(statColumns)
        statColumns.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statColumns.topAnchor.constraint(equalTo: statsContainer.topAnchor),
            statColumns.leadingAnchor.constraint(equalTo: statsContainer.leadingAnchor),
            statColumns.trailingAnchor.constraint(equalTo: statsContainer.trailingAnchor),
            statColumns.bottomAnchor.constraint(equalTo: statsContainer.bottomAnchor),
        ])

        // Action buttons
        let buttonsStack = UIStackView(arrangedSubviews: [primaryButton, secondaryButton])
        buttonsStack.axis = .horizontal
        buttonsStack.spacing = 10
        buttonsStack.distribution = .fillEqually
        buttonsStack.translatesAutoresizingMaskIntoConstraints = false
        statsCard.addSubview(buttonsStack)

        primaryButton.addTarget(self, action: #selector(didTapPrimary), for: .touchUpInside)
        secondaryButton.addTarget(self, action: #selector(didTapSecondary), for: .touchUpInside)

        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: statsCard.topAnchor),
            blur.leadingAnchor.constraint(equalTo: statsCard.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: statsCard.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: statsCard.bottomAnchor),

            statsContainer.topAnchor.constraint(equalTo: statsCard.topAnchor, constant: 16),
            statsContainer.leadingAnchor.constraint(equalTo: statsCard.leadingAnchor, constant: 16),
            statsContainer.trailingAnchor.constraint(equalTo: statsCard.trailingAnchor, constant: -16),

            buttonsStack.topAnchor.constraint(equalTo: statsContainer.bottomAnchor, constant: 16),
            buttonsStack.leadingAnchor.constraint(equalTo: statsCard.leadingAnchor, constant: 20),
            buttonsStack.trailingAnchor.constraint(equalTo: statsCard.trailingAnchor, constant: -20),
            buttonsStack.heightAnchor.constraint(equalToConstant: 36),
            buttonsStack.bottomAnchor.constraint(equalTo: statsCard.bottomAnchor, constant: -16),
        ])

        contentStack.addArrangedSubview(statsCard)
    }

    /// Build the 3-column stats row: Score | Followers | Following
    private func buildStatsColumns() -> UIStackView {
        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        let scoreCol = makeStatColumn(value: scoreStatValue, label: scoreStatLabel,
                                       labelText: "Health Score", action: nil)
        let followersCol = makeStatColumn(value: followersStatValue, label: followersStatLabel,
                                           labelText: "Followers", action: #selector(followersTapped))
        let followingCol = makeStatColumn(value: followingStatValue, label: followingStatLabel,
                                           labelText: "Following", action: #selector(followingTapped))

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .center
        stack.spacing = 0
        stack.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute

        stack.addArrangedSubview(scoreCol)
        stack.addArrangedSubview(followersCol)
        stack.addArrangedSubview(followingCol)

        // Thin vertical dividers
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

    private func makeStatColumn(value: UILabel, label: UILabel, labelText: String, action: Selector?) -> UIView {
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

    @objc private func followersTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let vc = FollowersListViewController(mode: .followers, targetUid: userUid)
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func followingTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let vc = FollowersListViewController(mode: .following, targetUid: userUid)
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Score Card

    private func buildScoreCard() {
        scoreCard.translatesAutoresizingMaskIntoConstraints = false
        scoreCard.backgroundColor = AIONDesign.glassCardBackground
        scoreCard.layer.cornerRadius = 22
        scoreCard.layer.borderWidth = 1
        scoreCard.layer.borderColor = AIONDesign.glassCardBorder.cgColor
        scoreCard.clipsToBounds = true
        scoreCard.isHidden = true

        let scoreBlur = UIVisualEffectView(effect: UIBlurEffect(style: AIONDesign.glassBlurStyle))
        scoreBlur.alpha = AIONDesign.glassBlurAlpha
        scoreBlur.translatesAutoresizingMaskIntoConstraints = false
        scoreCard.addSubview(scoreBlur)
        NSLayoutConstraint.activate([
            scoreBlur.topAnchor.constraint(equalTo: scoreCard.topAnchor),
            scoreBlur.leadingAnchor.constraint(equalTo: scoreCard.leadingAnchor),
            scoreBlur.trailingAnchor.constraint(equalTo: scoreCard.trailingAnchor),
            scoreBlur.bottomAnchor.constraint(equalTo: scoreCard.bottomAnchor),
        ])

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        // Circular progress
        scoreCard.addSubview(circularProgress)

        // Score title
        scoreTitleLabel.text = "Health Score"
        scoreTitleLabel.font = .systemFont(ofSize: 12, weight: .bold)
        scoreTitleLabel.textColor = AIONDesign.textTertiary
        scoreTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        scoreCard.addSubview(scoreTitleLabel)

        // Description
        scoreDescLabel.text = ""
        scoreDescLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        scoreDescLabel.textColor = AIONDesign.accentSecondary
        scoreDescLabel.numberOfLines = 2
        scoreDescLabel.translatesAutoresizingMaskIntoConstraints = false
        scoreCard.addSubview(scoreDescLabel)

        // Car subtitle
        carSubtitle.font = .systemFont(ofSize: 12, weight: .medium)
        carSubtitle.textColor = AIONDesign.textTertiary
        carSubtitle.translatesAutoresizingMaskIntoConstraints = false
        scoreCard.addSubview(carSubtitle)

        // Progress bar
        progressTrack.translatesAutoresizingMaskIntoConstraints = false
        progressTrack.backgroundColor = AIONDesign.surfaceElevated
        progressTrack.layer.cornerRadius = 4
        scoreCard.addSubview(progressTrack)

        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressFill.layer.cornerRadius = 4
        progressFill.clipsToBounds = true
        progressTrack.addSubview(progressFill)

        progressGradient.colors = [AIONDesign.accentPrimary.cgColor, AIONDesign.accentSuccess.cgColor]
        progressGradient.startPoint = CGPoint(x: 0, y: 0.5)
        progressGradient.endPoint = CGPoint(x: 1, y: 0.5)
        progressGradient.cornerRadius = 4
        progressFill.layer.insertSublayer(progressGradient, at: 0)

        let fillWidth = progressFill.widthAnchor.constraint(equalTo: progressTrack.widthAnchor, multiplier: 0.01)
        progressFillWidthConstraint = fillWidth

        NSLayoutConstraint.activate([
            progressTrack.bottomAnchor.constraint(equalTo: scoreCard.bottomAnchor, constant: -18),
            progressTrack.leadingAnchor.constraint(equalTo: scoreCard.leadingAnchor, constant: 20),
            progressTrack.trailingAnchor.constraint(equalTo: scoreCard.trailingAnchor, constant: -20),
            progressTrack.heightAnchor.constraint(equalToConstant: 6),

            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),
            fillWidth,
        ])

        if isRTL {
            NSLayoutConstraint.activate([
                circularProgress.topAnchor.constraint(equalTo: scoreCard.topAnchor, constant: 20),
                circularProgress.trailingAnchor.constraint(equalTo: scoreCard.trailingAnchor, constant: -24),
                circularProgress.widthAnchor.constraint(equalToConstant: 80),
                circularProgress.heightAnchor.constraint(equalToConstant: 80),

                scoreTitleLabel.topAnchor.constraint(equalTo: scoreCard.topAnchor, constant: 24),
                scoreTitleLabel.leadingAnchor.constraint(equalTo: scoreCard.leadingAnchor, constant: 24),
                scoreTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: circularProgress.leadingAnchor, constant: -16),

                scoreDescLabel.topAnchor.constraint(equalTo: scoreTitleLabel.bottomAnchor, constant: 6),
                scoreDescLabel.leadingAnchor.constraint(equalTo: scoreTitleLabel.leadingAnchor),
                scoreDescLabel.trailingAnchor.constraint(lessThanOrEqualTo: circularProgress.leadingAnchor, constant: -16),

                carSubtitle.topAnchor.constraint(equalTo: scoreDescLabel.bottomAnchor, constant: 4),
                carSubtitle.leadingAnchor.constraint(equalTo: scoreTitleLabel.leadingAnchor),
            ])
        } else {
            NSLayoutConstraint.activate([
                circularProgress.topAnchor.constraint(equalTo: scoreCard.topAnchor, constant: 20),
                circularProgress.leadingAnchor.constraint(equalTo: scoreCard.leadingAnchor, constant: 24),
                circularProgress.widthAnchor.constraint(equalToConstant: 80),
                circularProgress.heightAnchor.constraint(equalToConstant: 80),

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

        contentStack.addArrangedSubview(scoreCard)
    }

    // MARK: - Car Tier Card

    private func buildCarTierCard() {
        carTierCard.translatesAutoresizingMaskIntoConstraints = false
        carTierCard.backgroundColor = AIONDesign.glassCardBackground
        carTierCard.layer.cornerRadius = 22
        carTierCard.layer.borderWidth = 1
        carTierCard.layer.borderColor = AIONDesign.glassCardBorder.cgColor
        carTierCard.clipsToBounds = true
        carTierCard.isHidden = true

        contentStack.addArrangedSubview(carTierCard)
    }

    private func populateCarTierCard(tierIndex: Int, carName: String) {
        // Clear previous content
        carTierCard.subviews.forEach { $0.removeFromSuperview() }

        // Re-add glass blur
        let tierBlur = UIVisualEffectView(effect: UIBlurEffect(style: AIONDesign.glassBlurStyle))
        tierBlur.alpha = AIONDesign.glassBlurAlpha
        tierBlur.translatesAutoresizingMaskIntoConstraints = false
        carTierCard.addSubview(tierBlur)
        NSLayoutConstraint.activate([
            tierBlur.topAnchor.constraint(equalTo: carTierCard.topAnchor),
            tierBlur.leadingAnchor.constraint(equalTo: carTierCard.leadingAnchor),
            tierBlur.trailingAnchor.constraint(equalTo: carTierCard.trailingAnchor),
            tierBlur.bottomAnchor.constraint(equalTo: carTierCard.bottomAnchor),
        ])

        let tier = HealthTier.forIndex(tierIndex)
        let emoji = tier?.emoji ?? "\u{1F697}"
        let tierLabel = tier?.tierLabel ?? ""
        let tierColor = tier?.color ?? AIONDesign.accentPrimary

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        // Colored accent bar on leading edge
        let accentBar = UIView()
        accentBar.translatesAutoresizingMaskIntoConstraints = false
        accentBar.backgroundColor = tierColor
        accentBar.layer.cornerRadius = 2
        carTierCard.addSubview(accentBar)

        // Emoji
        let emojiLabel = UILabel()
        emojiLabel.text = emoji
        emojiLabel.font = .systemFont(ofSize: 36)
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false
        carTierCard.addSubview(emojiLabel)

        // Car name
        let carNameLabel = UILabel()
        carNameLabel.text = carName
        carNameLabel.font = .systemFont(ofSize: 17, weight: .bold)
        carNameLabel.textColor = AIONDesign.textPrimary
        carNameLabel.translatesAutoresizingMaskIntoConstraints = false
        carTierCard.addSubview(carNameLabel)

        // Tier label
        let tierDescLabel = UILabel()
        tierDescLabel.text = tierLabel
        tierDescLabel.font = .systemFont(ofSize: 13, weight: .medium)
        tierDescLabel.textColor = tierColor
        tierDescLabel.translatesAutoresizingMaskIntoConstraints = false
        carTierCard.addSubview(tierDescLabel)

        if isRTL {
            NSLayoutConstraint.activate([
                accentBar.trailingAnchor.constraint(equalTo: carTierCard.trailingAnchor),
                accentBar.topAnchor.constraint(equalTo: carTierCard.topAnchor, constant: 12),
                accentBar.bottomAnchor.constraint(equalTo: carTierCard.bottomAnchor, constant: -12),
                accentBar.widthAnchor.constraint(equalToConstant: 4),

                emojiLabel.trailingAnchor.constraint(equalTo: accentBar.leadingAnchor, constant: -16),
                emojiLabel.centerYAnchor.constraint(equalTo: carTierCard.centerYAnchor),

                carNameLabel.trailingAnchor.constraint(equalTo: emojiLabel.leadingAnchor, constant: -14),
                carNameLabel.topAnchor.constraint(equalTo: carTierCard.topAnchor, constant: 16),
                carNameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: carTierCard.leadingAnchor, constant: 16),

                tierDescLabel.trailingAnchor.constraint(equalTo: carNameLabel.trailingAnchor),
                tierDescLabel.topAnchor.constraint(equalTo: carNameLabel.bottomAnchor, constant: 4),
                tierDescLabel.bottomAnchor.constraint(equalTo: carTierCard.bottomAnchor, constant: -16),
            ])
        } else {
            NSLayoutConstraint.activate([
                accentBar.leadingAnchor.constraint(equalTo: carTierCard.leadingAnchor),
                accentBar.topAnchor.constraint(equalTo: carTierCard.topAnchor, constant: 12),
                accentBar.bottomAnchor.constraint(equalTo: carTierCard.bottomAnchor, constant: -12),
                accentBar.widthAnchor.constraint(equalToConstant: 4),

                emojiLabel.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 16),
                emojiLabel.centerYAnchor.constraint(equalTo: carTierCard.centerYAnchor),

                carNameLabel.leadingAnchor.constraint(equalTo: emojiLabel.trailingAnchor, constant: 14),
                carNameLabel.topAnchor.constraint(equalTo: carTierCard.topAnchor, constant: 16),
                carNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: carTierCard.trailingAnchor, constant: -16),

                tierDescLabel.leadingAnchor.constraint(equalTo: carNameLabel.leadingAnchor),
                tierDescLabel.topAnchor.constraint(equalTo: carNameLabel.bottomAnchor, constant: 4),
                tierDescLabel.bottomAnchor.constraint(equalTo: carTierCard.bottomAnchor, constant: -16),
            ])
        }
    }

    // MARK: - About Card

    private func buildAboutCard() {
        aboutCard.translatesAutoresizingMaskIntoConstraints = false
        aboutCard.backgroundColor = AIONDesign.glassCardBackground
        aboutCard.layer.cornerRadius = 16
        aboutCard.layer.borderWidth = 1
        aboutCard.layer.borderColor = AIONDesign.glassCardBorder.cgColor
        aboutCard.clipsToBounds = true

        let aboutBlur = UIVisualEffectView(effect: UIBlurEffect(style: AIONDesign.glassBlurStyle))
        aboutBlur.alpha = AIONDesign.glassBlurAlpha
        aboutBlur.translatesAutoresizingMaskIntoConstraints = false
        aboutCard.addSubview(aboutBlur)
        NSLayoutConstraint.activate([
            aboutBlur.topAnchor.constraint(equalTo: aboutCard.topAnchor),
            aboutBlur.leadingAnchor.constraint(equalTo: aboutCard.leadingAnchor),
            aboutBlur.trailingAnchor.constraint(equalTo: aboutCard.trailingAnchor),
            aboutBlur.bottomAnchor.constraint(equalTo: aboutCard.bottomAnchor),
        ])

        aboutCard.addSubview(aboutTitleLabel)
        aboutCard.addSubview(aboutBodyLabel)

        NSLayoutConstraint.activate([
            aboutTitleLabel.topAnchor.constraint(equalTo: aboutCard.topAnchor, constant: 16),
            aboutTitleLabel.leadingAnchor.constraint(equalTo: aboutCard.leadingAnchor, constant: 16),
            aboutTitleLabel.trailingAnchor.constraint(equalTo: aboutCard.trailingAnchor, constant: -16),

            aboutBodyLabel.topAnchor.constraint(equalTo: aboutTitleLabel.bottomAnchor, constant: 6),
            aboutBodyLabel.leadingAnchor.constraint(equalTo: aboutCard.leadingAnchor, constant: 16),
            aboutBodyLabel.trailingAnchor.constraint(equalTo: aboutCard.trailingAnchor, constant: -16),
            aboutBodyLabel.bottomAnchor.constraint(equalTo: aboutCard.bottomAnchor, constant: -16),
        ])

        contentStack.addArrangedSubview(aboutCard)
    }

    // MARK: - Data Loading

    private func loadUserData() {
        // Show layout immediately with placeholders
        scrollView.isHidden = false
        nameLabel.text = "..."
        scoreStatValue.text = "—"
        followersStatValue.text = "—"
        followingStatValue.text = "—"
        loadingSpinner.startAnimating()

        // 1. Load score data from publicScores — update UI as soon as it arrives
        db.collection("publicScores").document(userUid).getDocument { [weak self] snapshot, _ in
            guard let self = self else { return }

            if let data = snapshot?.data(),
               let healthScore = data["healthScore"] as? Int,
               let carTierIndex = data["carTierIndex"] as? Int {

                let displayName = data["displayName"] as? String ?? "Unknown User"
                let carTierName = data["carTierName"] as? String
                    ?? HealthTier.forIndex(carTierIndex)?.tierLabel
                    ?? ""

                self.userData = (
                    displayName: displayName,
                    photoURL: data["photoURL"] as? String,
                    healthScore: healthScore,
                    carTierIndex: carTierIndex,
                    carTierName: carTierName
                )
                DispatchQueue.main.async {
                    self.loadingSpinner.stopAnimating()
                    self.applyData()
                    self.playEntranceAnimations()
                }
            } else {
                // Fallback: load basic info from users collection
                self.db.collection("users").document(self.userUid).getDocument { [weak self] snapshot, _ in
                    guard let self = self else { return }

                    if let data = snapshot?.data(),
                       let displayName = data["displayName"] as? String, !displayName.isEmpty {
                        let healthScore = data["healthScore"] as? Int ?? 0
                        let carTierIndex = data["carTierIndex"] as? Int ?? 0
                        let carTierName = HealthTier.forIndex(carTierIndex)?.tierLabel ?? ""
                        self.userData = (
                            displayName: displayName,
                            photoURL: data["photoURL"] as? String,
                            healthScore: healthScore,
                            carTierIndex: carTierIndex,
                            carTierName: carTierName
                        )
                    }
                    DispatchQueue.main.async {
                        self.loadingSpinner.stopAnimating()
                        self.applyData()
                        self.playEntranceAnimations()
                    }
                }
            }
        }

        // 2. Load followers count — update immediately when ready
        FollowFirestoreSync.fetchFollowersCount(for: userUid) { [weak self] count in
            self?.followersCount = count
            DispatchQueue.main.async {
                self?.followersStatValue.text = "\(count)"
            }
        }

        // 3. Load following count — update immediately when ready
        FollowFirestoreSync.fetchFollowingCount(for: userUid) { [weak self] count in
            self?.followingCount = count
            DispatchQueue.main.async {
                self?.followingStatValue.text = "\(count)"
            }
        }

        // 4. Check friendship status — update button when ready
        checkFriendshipStatus { [weak self] in
            DispatchQueue.main.async {
                self?.applyButtonStates()
            }
        }
    }

    // MARK: - Friendship Status

    private func checkFriendshipStatus(completion: @escaping () -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            friendshipStatus = .unknown
            completion()
            return
        }

        // 1. Am I already following this user?
        db.collection("users").document(currentUid)
            .collection("following").document(userUid)
            .getDocument { [weak self] snapshot, _ in
                guard let self = self else { return }

                if snapshot?.exists == true {
                    self.friendshipStatus = .following
                    completion()
                    return
                }

                // 2. Did I send them a request?
                self.checkPendingRequests(currentUid: currentUid, completion: completion)
            }
    }

    private func checkPendingRequests(currentUid: String, completion: @escaping () -> Void) {
        db.collection("followRequests")
            .whereField("fromUid", isEqualTo: currentUid)
            .whereField("toUid", isEqualTo: userUid)
            .whereField("status", isEqualTo: "pending")
            .getDocuments { [weak self] snapshot, _ in
                guard let self = self else { return }

                if let doc = snapshot?.documents.first {
                    self.friendshipStatus = .followRequestSent(requestId: doc.documentID)
                    completion()
                    return
                }

                self.db.collection("followRequests")
                    .whereField("fromUid", isEqualTo: self.userUid)
                    .whereField("toUid", isEqualTo: currentUid)
                    .whereField("status", isEqualTo: "pending")
                    .getDocuments { [weak self] snapshot, _ in
                        guard let self = self else { return }

                        if let doc = snapshot?.documents.first {
                            self.friendshipStatus = .followRequestReceived(requestId: doc.documentID)
                        } else {
                            self.friendshipStatus = .notFollowing
                        }
                        completion()
                    }
            }
    }

    // MARK: - Apply Data to UI

    private func applyData() {
        guard let data = userData else {
            nameLabel.text = "Unknown User"
            scoreCard.isHidden = true
            carTierCard.isHidden = true
            aboutCard.isHidden = true
            tierChip.isHidden = true
            scoreStatValue.text = "—"
            followersStatValue.text = "\(followersCount)"
            followingStatValue.text = "\(followingCount)"
            applyButtonStates()
            return
        }

        let hasScoreData = data.healthScore > 0 || !data.carTierName.isEmpty

        nameLabel.text = data.displayName
        title = data.displayName

        // Avatar + blurred background
        avatarRing.loadImage(from: data.photoURL)
        if let photoURL = data.photoURL, let url = URL(string: photoURL) {
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let d = data, let img = UIImage(data: d) else { return }
                DispatchQueue.main.async { self?.backgroundImageView.image = img }
            }.resume()
        }

        // Stats row - always show
        followersStatValue.text = "\(followersCount)"
        followingStatValue.text = "\(followingCount)"

        if hasScoreData {
            let tier = HealthTier.forIndex(data.carTierIndex)
            let tierColor = tier?.color ?? AIONDesign.accentPrimary

            // Tier chip
            tierIcon.text = tier?.emoji ?? "\u{1F697}"
            tierTextLabel.text = data.carTierName
            tierChip.isHidden = false

            // Avatar ring colors
            avatarRing.ringColors = [tierColor, tierColor.withAlphaComponent(0.5)]

            // Tint blur overlay
            bgGradientLayer.colors = [
                tierColor.withAlphaComponent(0.15).cgColor,
                AIONDesign.background.withAlphaComponent(0.5).cgColor,
                AIONDesign.background.cgColor,
            ]

            // Score stat
            scoreStatValue.text = "\(data.healthScore)"
            scoreStatValue.textColor = tierColor

            // --- Score Card ---
            scoreCard.isHidden = false
            circularProgress.score = data.healthScore

            applyScoreDescription(healthScore: data.healthScore)
            carSubtitle.text = "\(tier?.emoji ?? "") \(data.carTierName)"

            // Animate progress bar
            let fraction = CGFloat(data.healthScore) / 100.0
            progressFillWidthConstraint?.isActive = false
            progressFillWidthConstraint = progressFill.widthAnchor.constraint(
                equalTo: progressTrack.widthAnchor, multiplier: max(fraction, 0.01)
            )
            progressFillWidthConstraint?.isActive = true

            // --- Car Tier Card ---
            carTierCard.isHidden = false
            populateCarTierCard(tierIndex: data.carTierIndex, carName: data.carTierName)

            // --- About ---
            aboutCard.isHidden = false
            applyAboutText(healthScore: data.healthScore)

        } else {
            tierChip.isHidden = true
            scoreCard.isHidden = true
            carTierCard.isHidden = true
            scoreStatValue.text = "—"

            // About - show generic text
            aboutCard.isHidden = false
            aboutBodyLabel.text = "Active user on Health Reporter"
        }

        // Buttons
        applyButtonStates()
    }

    private func applyScoreDescription(healthScore: Int) {
        switch healthScore {
        case 80...:
            scoreDescLabel.text = "Excellent health habits!"
            scoreDescLabel.textColor = AIONDesign.accentSuccess
        case 60..<80:
            scoreDescLabel.text = "Good health progress"
            scoreDescLabel.textColor = AIONDesign.accentSecondary
        case 40..<60:
            scoreDescLabel.text = "Making progress"
            scoreDescLabel.textColor = AIONDesign.accentPrimary
        default:
            scoreDescLabel.text = "Just getting started"
            scoreDescLabel.textColor = AIONDesign.accentWarning
        }
    }

    private func applyAboutText(healthScore: Int) {
        switch healthScore {
        case 80...:
            aboutBodyLabel.text = "Excellent health habits!"
        case 60..<80:
            aboutBodyLabel.text = "Good health progress"
        case 40..<60:
            aboutBodyLabel.text = "Making progress"
        default:
            aboutBodyLabel.text = "Just getting started"
        }
    }

    // MARK: - Button States

    private func applyButtonStates() {
        switch friendshipStatus {
        case .unknown:
            primaryButton.isHidden = true
            secondaryButton.isHidden = true

        case .notFollowing:
            primaryButton.isHidden = false
            primaryButton.isEnabled = true
            primaryButton.setTitle("Follow", for: .normal)
            primaryButton.backgroundColor = AIONDesign.accentPrimary
            primaryButton.setTitleColor(.white, for: .normal)
            showMessageButton()

        case .following:
            primaryButton.isHidden = false
            primaryButton.isEnabled = true
            primaryButton.setTitle("Unfollow", for: .normal)
            primaryButton.backgroundColor = .clear
            primaryButton.setTitleColor(AIONDesign.textPrimary, for: .normal)
            primaryButton.layer.borderWidth = 1
            primaryButton.layer.borderColor = AIONDesign.separator.withAlphaComponent(0.4).cgColor
            showMessageButton()

        case .followRequestSent:
            primaryButton.isHidden = false
            primaryButton.isEnabled = true
            primaryButton.setTitle("Cancel Request", for: .normal)
            primaryButton.backgroundColor = .clear
            primaryButton.setTitleColor(AIONDesign.accentDanger, for: .normal)
            primaryButton.layer.borderWidth = 1
            primaryButton.layer.borderColor = AIONDesign.accentDanger.withAlphaComponent(0.4).cgColor
            showMessageButton()

        case .followRequestReceived:
            primaryButton.isHidden = false
            primaryButton.isEnabled = true
            primaryButton.setTitle("Accept", for: .normal)
            primaryButton.backgroundColor = AIONDesign.accentSuccess
            primaryButton.setTitleColor(.white, for: .normal)
            primaryButton.layer.borderWidth = 0

            secondaryButton.isHidden = false
            secondaryButton.setTitle("Decline", for: .normal)
            secondaryButton.setTitleColor(AIONDesign.accentDanger, for: .normal)
            secondaryButton.backgroundColor = .clear
            secondaryButton.layer.borderColor = AIONDesign.accentDanger.withAlphaComponent(0.4).cgColor
        }
    }

    private func showMessageButton() {
        secondaryButton.isHidden = false
        secondaryButton.setTitle("chat.message".localized, for: .normal)
        secondaryButton.setTitleColor(AIONDesign.accentPrimary, for: .normal)
        secondaryButton.backgroundColor = .clear
        secondaryButton.layer.borderWidth = 1
        secondaryButton.layer.borderColor = AIONDesign.accentPrimary.withAlphaComponent(0.4).cgColor
    }

    // MARK: - Entrance Animations

    private var didPlayEntrance = false
    private func playEntranceAnimations() {
        guard !didPlayEntrance else { return }
        didPlayEntrance = true
        let animatables: [UIView] = [
            headerSection, statsCard, scoreCard, carTierCard, aboutCard
        ].filter { !$0.isHidden }

        for v in animatables {
            v.alpha = 0
            v.transform = CGAffineTransform(translationX: 0, y: 24)
        }

        for (i, v) in animatables.enumerated() {
            UIView.animate(
                withDuration: 0.55,
                delay: Double(i) * 0.08,
                usingSpringWithDamping: 0.72,
                initialSpringVelocity: 0.4,
                options: []
            ) {
                v.alpha = 1
                v.transform = .identity
            }
        }
    }

    // MARK: - Button Actions

    @objc private func didTapPrimary() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        primaryButton.springAnimation { [weak self] in
            self?.routePrimaryAction()
        }
    }

    @objc private func didTapSecondary() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        secondaryButton.springAnimation { [weak self] in
            guard let self = self else { return }
            if case .followRequestReceived(let rid) = self.friendshipStatus {
                self.performDecline(requestId: rid)
            } else {
                // Message button — open chat (available from any follow state)
                self.openChat()
            }
        }
    }

    private func openChat() {
        setButtonsLoading(true)
        ChatFirestoreSync.getOrCreateConversation(with: userUid) { [weak self] conversation, error in
            guard let self = self else { return }
            self.setButtonsLoading(false)

            if let error = error {
                self.presentError(error.localizedDescription)
                return
            }

            guard let conversation = conversation else { return }
            let chatVC = ChatViewController(conversation: conversation)
            self.navigationController?.pushViewController(chatVC, animated: true)
        }
    }

    private func routePrimaryAction() {
        switch friendshipStatus {
        case .notFollowing:
            performFollow()
        case .following:
            confirmUnfollow()
        case .followRequestSent(let rid):
            performCancelRequest(requestId: rid)
        case .followRequestReceived(let rid):
            performAccept(requestId: rid)
        default:
            break
        }
    }

    // MARK: - Follow

    private func performFollow() {
        setButtonsLoading(true)

        FollowFirestoreSync.followUser(targetUid: userUid) { [weak self] error in
            guard let self = self else { return }
            self.setButtonsLoading(false)

            if let error = error {
                self.presentError(error.localizedDescription)
                return
            }

            self.checkFriendshipStatus {
                DispatchQueue.main.async {
                    self.applyButtonStates()
                    self.showSuccessFeedback()
                }
            }
        }
    }

    // MARK: - Cancel Follow Request

    private func performCancelRequest(requestId: String) {
        setButtonsLoading(true)

        FollowFirestoreSync.cancelFollowRequest(requestId: requestId) { [weak self] error in
            guard let self = self else { return }
            self.setButtonsLoading(false)

            if let error = error {
                self.presentError(error.localizedDescription)
                return
            }

            self.friendshipStatus = .notFollowing
            DispatchQueue.main.async {
                self.applyButtonStates()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    // MARK: - Unfollow

    private func confirmUnfollow() {
        let alert = UIAlertController(
            title: "Unfollow",
            message: "Are you sure you want to unfollow \(userData?.displayName ?? "")?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Unfollow", style: .destructive) { [weak self] _ in
            self?.performUnfollow()
        })
        present(alert, animated: true)
    }

    private func performUnfollow() {
        setButtonsLoading(true)

        FollowFirestoreSync.unfollowUser(targetUid: userUid) { [weak self] error in
            guard let self = self else { return }
            self.setButtonsLoading(false)

            if let error = error {
                self.presentError(error.localizedDescription)
                return
            }

            self.friendshipStatus = .notFollowing
            self.applyButtonStates()
        }
    }

    // MARK: - Accept / Decline

    private func performAccept(requestId: String) {
        setButtonsLoading(true)

        FollowFirestoreSync.acceptFollowRequest(requestId: requestId) { [weak self] error in
            guard let self = self else { return }
            self.setButtonsLoading(false)

            if let error = error {
                self.presentError(error.localizedDescription)
                return
            }

            self.friendshipStatus = .following
            self.applyButtonStates()
            self.showSuccessFeedback()
            self.notifyTabBarBadge()
        }
    }

    private func performDecline(requestId: String) {
        setButtonsLoading(true)

        FollowFirestoreSync.declineFollowRequest(requestId: requestId) { [weak self] error in
            guard let self = self else { return }
            self.setButtonsLoading(false)

            if let error = error {
                self.presentError(error.localizedDescription)
                return
            }

            self.friendshipStatus = .notFollowing
            self.applyButtonStates()
            self.notifyTabBarBadge()
        }
    }

    // MARK: - Helpers

    private func setButtonsLoading(_ loading: Bool) {
        primaryButton.isEnabled = !loading
        secondaryButton.isEnabled = !loading
        primaryButton.alpha = loading ? 0.55 : 1
        secondaryButton.alpha = loading ? 0.55 : 1
    }

    private func presentError(_ message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showSuccessFeedback() {
        feedbackGenerator.notificationOccurred(.success)

        UIView.animate(withDuration: 0.15, animations: {
            self.avatarRing.transform = CGAffineTransform(scaleX: 1.12, y: 1.12)
        }) { _ in
            UIView.animate(
                withDuration: 0.35,
                delay: 0,
                usingSpringWithDamping: 0.45,
                initialSpringVelocity: 0.5,
                options: []
            ) {
                self.avatarRing.transform = .identity
            }
        }
    }

    private func notifyTabBarBadge() {
        (tabBarController as? MainTabBarController)?.updateFollowRequestBadge()
    }
}

// MARK: - UIScrollViewDelegate (Parallax)

extension UserProfileViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offset = scrollView.contentOffset.y
        backgroundImageView.transform = CGAffineTransform(translationX: 0, y: min(0, offset * 0.3))
    }
}

// MARK: - Array Safe Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
