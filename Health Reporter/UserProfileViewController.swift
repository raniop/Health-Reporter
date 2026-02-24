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

    // MARK: - UI -- Car Showcase Card

    private let carShowcaseCard = UIView()
    private let carImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    private let carGlowLayer = CAGradientLayer()
    private let carShowcaseNameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 17, weight: .bold)
        l.textColor = AIONDesign.textPrimary
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let carShowcaseTierLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13, weight: .medium)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let tierLadderStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.distribution = .equalSpacing
        s.alignment = .center
        s.spacing = 12
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    // MARK: - UI -- Comparison Card

    private let comparisonCard = UIView()
    private let comparisonTitleLabel: UILabel = {
        let l = UILabel()
        l.text = "social.comparison".localized.uppercased()
        l.font = .systemFont(ofSize: 11, weight: .heavy)
        l.textColor = AIONDesign.textTertiary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let yourAvatarRing: AvatarRingView = {
        let v = AvatarRingView(size: 32)
        v.ringWidth = 2
        v.isAnimated = false
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let yourCompLabel: UILabel = {
        let l = UILabel()
        l.text = "social.you".localized
        l.font = .systemFont(ofSize: 11, weight: .semibold)
        l.textColor = AIONDesign.textTertiary
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let yourScoreLabel: UILabel = {
        let l = UILabel()
        l.font = .monospacedDigitSystemFont(ofSize: 22, weight: .black)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let theirCompLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11, weight: .semibold)
        l.textColor = AIONDesign.textTertiary
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let theirAvatarRing: AvatarRingView = {
        let v = AvatarRingView(size: 32)
        v.ringWidth = 2
        v.isAnimated = false
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let theirScoreLabel: UILabel = {
        let l = UILabel()
        l.font = .monospacedDigitSystemFont(ofSize: 22, weight: .black)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let comparisonBarContainer = UIView()
    private let comparisonBarYou = UIView()
    private let comparisonBarThem = UIView()
    private var compBarYouWidth: NSLayoutConstraint?
    private let comparisonStatusLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13, weight: .semibold)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - UI -- Badges Card

    private let badgesCard = UIView()
    private let badgesTitleLabel: UILabel = {
        let l = UILabel()
        l.text = "social.badges".localized.uppercased()
        l.font = .systemFont(ofSize: 11, weight: .heavy)
        l.textColor = AIONDesign.textTertiary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let memberValueLabel = UILabel()
    private let streakValueLabel = UILabel()
    private let peakScoreValueLabel = UILabel()

    // MARK: - UI -- Mutual Friends

    private let mutualCard = UIView()
    private let mutualTitleLabel: UILabel = {
        let l = UILabel()
        l.text = "social.mutualConnections".localized.uppercased()
        l.font = .systemFont(ofSize: 11, weight: .heavy)
        l.textColor = AIONDesign.textTertiary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let mutualScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    private let mutualStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = 14
        s.alignment = .center
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    // Extra data for new cards
    private var memberSinceDate: Date?
    private var streakDays: Int = 0
    private var peakScore: Int = 0

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
        if let glowSuper = carGlowLayer.superlayer?.bounds {
            carGlowLayer.frame = glowSuper
        }
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
        // Push stats card below the blurred background photo (380px)
        contentStack.setCustomSpacing(96, after: headerSection)
        buildStatsCard()
        buildScoreCard()
        buildCarShowcaseCard()
        buildComparisonCard()
        buildBadgesCard()
        buildMutualFriendsSection()

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
                                       labelText: "social.healthScore".localized, action: nil)
        let followersCol = makeStatColumn(value: followersStatValue, label: followersStatLabel,
                                           labelText: "social.followers".localized, action: #selector(followersTapped))
        let followingCol = makeStatColumn(value: followingStatValue, label: followingStatLabel,
                                           labelText: "social.following".localized, action: #selector(followingTapped))

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
        scoreTitleLabel.text = "social.healthScore".localized
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
            progressTrack.topAnchor.constraint(greaterThanOrEqualTo: circularProgress.bottomAnchor, constant: 16),
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
                carSubtitle.bottomAnchor.constraint(lessThanOrEqualTo: progressTrack.topAnchor, constant: -12),
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
                carSubtitle.bottomAnchor.constraint(lessThanOrEqualTo: progressTrack.topAnchor, constant: -12),
            ])
        }

        contentStack.addArrangedSubview(scoreCard)
    }

    // MARK: - Car Showcase Card

    private func buildCarShowcaseCard() {
        carShowcaseCard.translatesAutoresizingMaskIntoConstraints = false
        carShowcaseCard.backgroundColor = AIONDesign.glassCardBackground
        carShowcaseCard.layer.cornerRadius = 22
        carShowcaseCard.layer.borderWidth = 1
        carShowcaseCard.layer.borderColor = AIONDesign.glassCardBorder.cgColor
        carShowcaseCard.clipsToBounds = true
        carShowcaseCard.isHidden = true

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: AIONDesign.glassBlurStyle))
        blur.alpha = AIONDesign.glassBlurAlpha
        blur.translatesAutoresizingMaskIntoConstraints = false
        carShowcaseCard.addSubview(blur)
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: carShowcaseCard.topAnchor),
            blur.leadingAnchor.constraint(equalTo: carShowcaseCard.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: carShowcaseCard.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: carShowcaseCard.bottomAnchor),
        ])

        // Glow layer behind car image
        let glowContainer = UIView()
        glowContainer.translatesAutoresizingMaskIntoConstraints = false
        carShowcaseCard.addSubview(glowContainer)

        carGlowLayer.type = .radial
        carGlowLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        carGlowLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        carGlowLayer.colors = [
            AIONDesign.accentPrimary.withAlphaComponent(0.25).cgColor,
            UIColor.clear.cgColor
        ]
        glowContainer.layer.insertSublayer(carGlowLayer, at: 0)

        // Car image
        carShowcaseCard.addSubview(carImageView)

        // Section label
        let sectionLabel = UILabel()
        sectionLabel.text = "social.garage".localized.uppercased()
        sectionLabel.font = .systemFont(ofSize: 11, weight: .heavy)
        sectionLabel.textColor = AIONDesign.textTertiary
        sectionLabel.translatesAutoresizingMaskIntoConstraints = false
        carShowcaseCard.addSubview(sectionLabel)

        // Car name + tier label
        carShowcaseCard.addSubview(carShowcaseNameLabel)
        carShowcaseCard.addSubview(carShowcaseTierLabel)

        // Tier ladder (5 dots)
        carShowcaseCard.addSubview(tierLadderStack)
        tierLadderStack.semanticContentAttribute = .forceLeftToRight // Always LTR for ladder

        for i in 0..<5 {
            let dot = UIView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.layer.cornerRadius = 6
            dot.backgroundColor = AIONDesign.surfaceElevated
            dot.tag = 500 + i

            let emoji = UILabel()
            emoji.font = .systemFont(ofSize: 10)
            emoji.textAlignment = .center
            emoji.translatesAutoresizingMaskIntoConstraints = false
            emoji.tag = 600 + i
            emoji.text = HealthTier.forIndex(i)?.emoji ?? ""

            let col = UIStackView(arrangedSubviews: [dot, emoji])
            col.axis = .vertical
            col.alignment = .center
            col.spacing = 4
            col.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 12),
                dot.heightAnchor.constraint(equalToConstant: 12),
            ])

            tierLadderStack.addArrangedSubview(col)
        }

        NSLayoutConstraint.activate([
            sectionLabel.topAnchor.constraint(equalTo: carShowcaseCard.topAnchor, constant: 16),
            sectionLabel.centerXAnchor.constraint(equalTo: carShowcaseCard.centerXAnchor),

            glowContainer.centerXAnchor.constraint(equalTo: carShowcaseCard.centerXAnchor),
            glowContainer.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: 8),
            glowContainer.widthAnchor.constraint(equalToConstant: 200),
            glowContainer.heightAnchor.constraint(equalToConstant: 120),

            carImageView.centerXAnchor.constraint(equalTo: glowContainer.centerXAnchor),
            carImageView.centerYAnchor.constraint(equalTo: glowContainer.centerYAnchor),
            carImageView.widthAnchor.constraint(equalToConstant: 180),
            carImageView.heightAnchor.constraint(equalToConstant: 110),

            carShowcaseNameLabel.topAnchor.constraint(equalTo: glowContainer.bottomAnchor, constant: 8),
            carShowcaseNameLabel.leadingAnchor.constraint(equalTo: carShowcaseCard.leadingAnchor, constant: 20),
            carShowcaseNameLabel.trailingAnchor.constraint(equalTo: carShowcaseCard.trailingAnchor, constant: -20),

            carShowcaseTierLabel.topAnchor.constraint(equalTo: carShowcaseNameLabel.bottomAnchor, constant: 4),
            carShowcaseTierLabel.centerXAnchor.constraint(equalTo: carShowcaseCard.centerXAnchor),

            tierLadderStack.topAnchor.constraint(equalTo: carShowcaseTierLabel.bottomAnchor, constant: 16),
            tierLadderStack.centerXAnchor.constraint(equalTo: carShowcaseCard.centerXAnchor),
            tierLadderStack.bottomAnchor.constraint(equalTo: carShowcaseCard.bottomAnchor, constant: -18),
        ])

        contentStack.addArrangedSubview(carShowcaseCard)
    }

    // MARK: - Comparison Card

    private func buildComparisonCard() {
        comparisonCard.translatesAutoresizingMaskIntoConstraints = false
        comparisonCard.backgroundColor = AIONDesign.glassCardBackground
        comparisonCard.layer.cornerRadius = 22
        comparisonCard.layer.borderWidth = 1
        comparisonCard.layer.borderColor = AIONDesign.glassCardBorder.cgColor
        comparisonCard.clipsToBounds = true
        comparisonCard.isHidden = true

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: AIONDesign.glassBlurStyle))
        blur.alpha = AIONDesign.glassBlurAlpha
        blur.translatesAutoresizingMaskIntoConstraints = false
        comparisonCard.addSubview(blur)
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: comparisonCard.topAnchor),
            blur.leadingAnchor.constraint(equalTo: comparisonCard.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: comparisonCard.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: comparisonCard.bottomAnchor),
        ])

        // Title
        comparisonCard.addSubview(comparisonTitleLabel)

        // Your side
        let yourCol = UIStackView(arrangedSubviews: [yourAvatarRing, yourCompLabel, yourScoreLabel])
        yourCol.axis = .vertical
        yourCol.alignment = .center
        yourCol.spacing = 4
        yourCol.translatesAutoresizingMaskIntoConstraints = false
        comparisonCard.addSubview(yourCol)

        // Their side
        let theirCol = UIStackView(arrangedSubviews: [theirAvatarRing, theirCompLabel, theirScoreLabel])
        theirCol.axis = .vertical
        theirCol.alignment = .center
        theirCol.spacing = 4
        theirCol.translatesAutoresizingMaskIntoConstraints = false
        comparisonCard.addSubview(theirCol)

        // VS label
        let vsLabel = UILabel()
        vsLabel.text = "VS"
        vsLabel.font = .systemFont(ofSize: 13, weight: .heavy)
        vsLabel.textColor = AIONDesign.textTertiary.withAlphaComponent(0.5)
        vsLabel.textAlignment = .center
        vsLabel.translatesAutoresizingMaskIntoConstraints = false
        comparisonCard.addSubview(vsLabel)

        // Comparison bar
        comparisonBarContainer.translatesAutoresizingMaskIntoConstraints = false
        comparisonBarContainer.backgroundColor = AIONDesign.surfaceElevated
        comparisonBarContainer.layer.cornerRadius = 5
        comparisonBarContainer.clipsToBounds = true
        comparisonCard.addSubview(comparisonBarContainer)

        comparisonBarYou.translatesAutoresizingMaskIntoConstraints = false
        comparisonBarYou.layer.cornerRadius = 5
        comparisonBarContainer.addSubview(comparisonBarYou)

        comparisonBarThem.translatesAutoresizingMaskIntoConstraints = false
        comparisonBarThem.layer.cornerRadius = 5
        comparisonBarContainer.addSubview(comparisonBarThem)

        let youWidth = comparisonBarYou.widthAnchor.constraint(equalTo: comparisonBarContainer.widthAnchor, multiplier: 0.5)
        compBarYouWidth = youWidth

        NSLayoutConstraint.activate([
            comparisonBarYou.topAnchor.constraint(equalTo: comparisonBarContainer.topAnchor),
            comparisonBarYou.leadingAnchor.constraint(equalTo: comparisonBarContainer.leadingAnchor),
            comparisonBarYou.bottomAnchor.constraint(equalTo: comparisonBarContainer.bottomAnchor),
            youWidth,

            comparisonBarThem.topAnchor.constraint(equalTo: comparisonBarContainer.topAnchor),
            comparisonBarThem.trailingAnchor.constraint(equalTo: comparisonBarContainer.trailingAnchor),
            comparisonBarThem.bottomAnchor.constraint(equalTo: comparisonBarContainer.bottomAnchor),
            comparisonBarThem.leadingAnchor.constraint(equalTo: comparisonBarYou.trailingAnchor, constant: 2),
        ])

        // Status label
        comparisonCard.addSubview(comparisonStatusLabel)

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        NSLayoutConstraint.activate([
            comparisonTitleLabel.topAnchor.constraint(equalTo: comparisonCard.topAnchor, constant: 16),
            comparisonTitleLabel.centerXAnchor.constraint(equalTo: comparisonCard.centerXAnchor),

            yourCol.topAnchor.constraint(equalTo: comparisonTitleLabel.bottomAnchor, constant: 14),
            yourCol.leadingAnchor.constraint(equalTo: comparisonCard.leadingAnchor, constant: 28),
            yourCol.widthAnchor.constraint(equalToConstant: 70),

            theirCol.topAnchor.constraint(equalTo: yourCol.topAnchor),
            theirCol.trailingAnchor.constraint(equalTo: comparisonCard.trailingAnchor, constant: -28),
            theirCol.widthAnchor.constraint(equalToConstant: 70),

            vsLabel.centerYAnchor.constraint(equalTo: yourCol.centerYAnchor),
            vsLabel.centerXAnchor.constraint(equalTo: comparisonCard.centerXAnchor),

            comparisonBarContainer.topAnchor.constraint(equalTo: yourCol.bottomAnchor, constant: 14),
            comparisonBarContainer.leadingAnchor.constraint(equalTo: comparisonCard.leadingAnchor, constant: 20),
            comparisonBarContainer.trailingAnchor.constraint(equalTo: comparisonCard.trailingAnchor, constant: -20),
            comparisonBarContainer.heightAnchor.constraint(equalToConstant: 10),

            comparisonStatusLabel.topAnchor.constraint(equalTo: comparisonBarContainer.bottomAnchor, constant: 10),
            comparisonStatusLabel.centerXAnchor.constraint(equalTo: comparisonCard.centerXAnchor),
            comparisonStatusLabel.bottomAnchor.constraint(equalTo: comparisonCard.bottomAnchor, constant: -16),
        ])

        contentStack.addArrangedSubview(comparisonCard)
    }

    // MARK: - Badges Card

    private func buildBadgesCard() {
        badgesCard.translatesAutoresizingMaskIntoConstraints = false
        badgesCard.backgroundColor = AIONDesign.glassCardBackground
        badgesCard.layer.cornerRadius = 22
        badgesCard.layer.borderWidth = 1
        badgesCard.layer.borderColor = AIONDesign.glassCardBorder.cgColor
        badgesCard.clipsToBounds = true
        badgesCard.isHidden = true

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: AIONDesign.glassBlurStyle))
        blur.alpha = AIONDesign.glassBlurAlpha
        blur.translatesAutoresizingMaskIntoConstraints = false
        badgesCard.addSubview(blur)
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: badgesCard.topAnchor),
            blur.leadingAnchor.constraint(equalTo: badgesCard.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: badgesCard.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: badgesCard.bottomAnchor),
        ])

        badgesCard.addSubview(badgesTitleLabel)

        // Three badge columns
        let memberCol = makeBadgeColumn(
            iconName: "calendar", iconColor: AIONDesign.accentPrimary,
            valueLabel: memberValueLabel, caption: "social.memberBadge".localized
        )
        let streakCol = makeBadgeColumn(
            iconName: "flame.fill", iconColor: .systemOrange,
            valueLabel: streakValueLabel, caption: "social.streakBadge".localized
        )
        let peakCol = makeBadgeColumn(
            iconName: "star.fill", iconColor: .systemYellow,
            valueLabel: peakScoreValueLabel, caption: "social.bestBadge".localized
        )

        let badgesStack = UIStackView(arrangedSubviews: [memberCol, streakCol, peakCol])
        badgesStack.axis = .horizontal
        badgesStack.distribution = .fillEqually
        badgesStack.alignment = .center
        badgesStack.spacing = 0
        badgesStack.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        badgesStack.translatesAutoresizingMaskIntoConstraints = false
        badgesCard.addSubview(badgesStack)

        // Dividers
        let div1 = makeThinVerticalDivider()
        let div2 = makeThinVerticalDivider()
        badgesStack.addSubview(div1)
        badgesStack.addSubview(div2)

        NSLayoutConstraint.activate([
            badgesTitleLabel.topAnchor.constraint(equalTo: badgesCard.topAnchor, constant: 16),
            badgesTitleLabel.centerXAnchor.constraint(equalTo: badgesCard.centerXAnchor),

            badgesStack.topAnchor.constraint(equalTo: badgesTitleLabel.bottomAnchor, constant: 12),
            badgesStack.leadingAnchor.constraint(equalTo: badgesCard.leadingAnchor, constant: 8),
            badgesStack.trailingAnchor.constraint(equalTo: badgesCard.trailingAnchor, constant: -8),
            badgesStack.bottomAnchor.constraint(equalTo: badgesCard.bottomAnchor, constant: -16),

            div1.centerYAnchor.constraint(equalTo: badgesStack.centerYAnchor),
            div1.leadingAnchor.constraint(equalTo: memberCol.trailingAnchor),
            div2.centerYAnchor.constraint(equalTo: badgesStack.centerYAnchor),
            div2.leadingAnchor.constraint(equalTo: streakCol.trailingAnchor),
        ])

        contentStack.addArrangedSubview(badgesCard)
    }

    private func makeBadgeColumn(iconName: String, iconColor: UIColor, valueLabel: UILabel, caption: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: iconName))
        icon.tintColor = iconColor
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(icon)

        valueLabel.text = "—"
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 18, weight: .bold)
        valueLabel.textColor = AIONDesign.textPrimary
        valueLabel.textAlignment = .center
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(valueLabel)

        let captionLabel = UILabel()
        captionLabel.text = caption.uppercased()
        captionLabel.font = .systemFont(ofSize: 9, weight: .heavy)
        captionLabel.textColor = AIONDesign.textTertiary
        captionLabel.textAlignment = .center
        captionLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(captionLabel)

        NSLayoutConstraint.activate([
            icon.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            icon.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),

            valueLabel.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 6),
            valueLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            captionLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 2),
            captionLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            captionLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
        ])

        return container
    }

    // MARK: - Mutual Friends Section

    private func buildMutualFriendsSection() {
        mutualCard.translatesAutoresizingMaskIntoConstraints = false
        mutualCard.backgroundColor = AIONDesign.glassCardBackground
        mutualCard.layer.cornerRadius = 22
        mutualCard.layer.borderWidth = 1
        mutualCard.layer.borderColor = AIONDesign.glassCardBorder.cgColor
        mutualCard.clipsToBounds = true
        mutualCard.isHidden = true

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: AIONDesign.glassBlurStyle))
        blur.alpha = AIONDesign.glassBlurAlpha
        blur.translatesAutoresizingMaskIntoConstraints = false
        mutualCard.addSubview(blur)
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: mutualCard.topAnchor),
            blur.leadingAnchor.constraint(equalTo: mutualCard.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: mutualCard.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: mutualCard.bottomAnchor),
        ])

        mutualCard.addSubview(mutualTitleLabel)
        mutualCard.addSubview(mutualScrollView)
        mutualScrollView.addSubview(mutualStack)
        mutualScrollView.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        mutualStack.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute

        NSLayoutConstraint.activate([
            mutualTitleLabel.topAnchor.constraint(equalTo: mutualCard.topAnchor, constant: 16),
            mutualTitleLabel.leadingAnchor.constraint(equalTo: mutualCard.leadingAnchor, constant: 20),

            mutualScrollView.topAnchor.constraint(equalTo: mutualTitleLabel.bottomAnchor, constant: 12),
            mutualScrollView.leadingAnchor.constraint(equalTo: mutualCard.leadingAnchor, constant: 16),
            mutualScrollView.trailingAnchor.constraint(equalTo: mutualCard.trailingAnchor, constant: -16),
            mutualScrollView.bottomAnchor.constraint(equalTo: mutualCard.bottomAnchor, constant: -16),
            mutualScrollView.heightAnchor.constraint(equalToConstant: 64),

            mutualStack.topAnchor.constraint(equalTo: mutualScrollView.topAnchor),
            mutualStack.leadingAnchor.constraint(equalTo: mutualScrollView.leadingAnchor),
            mutualStack.trailingAnchor.constraint(equalTo: mutualScrollView.trailingAnchor),
            mutualStack.bottomAnchor.constraint(equalTo: mutualScrollView.bottomAnchor),
            mutualStack.heightAnchor.constraint(equalTo: mutualScrollView.heightAnchor),
        ])

        contentStack.addArrangedSubview(mutualCard)
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

                // Read new gamification fields
                self.memberSinceDate = (data["memberSince"] as? Timestamp)?.dateValue()
                self.streakDays = data["streakDays"] as? Int ?? 0
                self.peakScore = data["peakScore"] as? Int ?? healthScore

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

        // 5. Load mutual connections
        loadMutualFriends()
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

    // MARK: - Mutual Friends Loading

    private func loadMutualFriends() {
        guard let currentUid = Auth.auth().currentUser?.uid, currentUid != userUid else { return }

        let group = DispatchGroup()
        var myFollowing: [FollowRelation] = []
        var theirFollowers: [FollowRelation] = []

        group.enter()
        FollowFirestoreSync.fetchFollowing(for: currentUid) { relations in
            myFollowing = relations
            group.leave()
        }

        group.enter()
        FollowFirestoreSync.fetchFollowers(for: userUid) { relations in
            theirFollowers = relations
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }

            let myFollowingUids = Set(myFollowing.map { $0.uid })
            let theirFollowerUids = Set(theirFollowers.map { $0.uid })
            let mutualUids = myFollowingUids.intersection(theirFollowerUids)

            guard !mutualUids.isEmpty else { return }

            // Get FollowRelation objects for mutual users (from my following list for display names/photos)
            let mutuals = myFollowing.filter { mutualUids.contains($0.uid) }

            // Clear existing
            self.mutualStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

            let maxShow = 5
            let displayMutuals = Array(mutuals.prefix(maxShow))

            for mutual in displayMutuals {
                let col = self.makeMutualAvatarColumn(relation: mutual)
                self.mutualStack.addArrangedSubview(col)
            }

            // "+N" indicator if more
            if mutuals.count > maxShow {
                let extra = mutuals.count - maxShow
                let moreLabel = UILabel()
                moreLabel.text = String(format: "social.moreMutuals".localized, extra)
                moreLabel.font = .systemFont(ofSize: 13, weight: .bold)
                moreLabel.textColor = AIONDesign.accentPrimary
                moreLabel.textAlignment = .center
                moreLabel.translatesAutoresizingMaskIntoConstraints = false

                let moreContainer = UIView()
                moreContainer.translatesAutoresizingMaskIntoConstraints = false
                moreContainer.backgroundColor = AIONDesign.surfaceElevated
                moreContainer.layer.cornerRadius = 18
                moreContainer.addSubview(moreLabel)

                NSLayoutConstraint.activate([
                    moreContainer.widthAnchor.constraint(equalToConstant: 36),
                    moreContainer.heightAnchor.constraint(equalToConstant: 36),
                    moreLabel.centerXAnchor.constraint(equalTo: moreContainer.centerXAnchor),
                    moreLabel.centerYAnchor.constraint(equalTo: moreContainer.centerYAnchor),
                ])

                let moreCol = UIStackView(arrangedSubviews: [moreContainer, UIView()])
                moreCol.axis = .vertical
                moreCol.alignment = .center
                moreCol.spacing = 4
                moreCol.translatesAutoresizingMaskIntoConstraints = false
                self.mutualStack.addArrangedSubview(moreCol)
            }

            self.mutualCard.isHidden = false
        }
    }

    private func makeMutualAvatarColumn(relation: FollowRelation) -> UIView {
        let avatar = AvatarRingView(size: 36)
        avatar.ringWidth = 1.5
        avatar.isAnimated = false
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.loadImage(from: relation.photoURL)

        let nameLabel = UILabel()
        nameLabel.text = relation.displayName.components(separatedBy: " ").first ?? relation.displayName
        nameLabel.font = .systemFont(ofSize: 9, weight: .medium)
        nameLabel.textColor = AIONDesign.textTertiary
        nameLabel.textAlignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let col = UIStackView(arrangedSubviews: [avatar, nameLabel])
        col.axis = .vertical
        col.alignment = .center
        col.spacing = 4
        col.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            avatar.widthAnchor.constraint(equalToConstant: 36),
            avatar.heightAnchor.constraint(equalToConstant: 36),
            nameLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 50),
        ])

        // Tap to navigate
        col.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(mutualAvatarTapped(_:)))
        col.addGestureRecognizer(tap)
        col.tag = relation.uid.hashValue // Store UID hash for identification
        col.accessibilityIdentifier = relation.uid

        return col
    }

    @objc private func mutualAvatarTapped(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view, let uid = view.accessibilityIdentifier else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let vc = UserProfileViewController(userUid: uid)
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Apply Data to UI

    private func applyData() {
        guard let data = userData else {
            nameLabel.text = "social.unknownUser".localized
            scoreCard.isHidden = true
            carShowcaseCard.isHidden = true
            comparisonCard.isHidden = true
            badgesCard.isHidden = true
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
            carSubtitle.isHidden = true

            // Animate progress bar
            let fraction = CGFloat(data.healthScore) / 100.0
            progressFillWidthConstraint?.isActive = false
            progressFillWidthConstraint = progressFill.widthAnchor.constraint(
                equalTo: progressTrack.widthAnchor, multiplier: max(fraction, 0.01)
            )
            progressFillWidthConstraint?.isActive = true

            // --- Car Showcase Card ---
            applyCarShowcase(tierIndex: data.carTierIndex, carName: data.carTierName, tierColor: tierColor)

            // --- Comparison Card ---
            applyComparison(theirScore: data.healthScore, theirName: data.displayName,
                            theirPhotoURL: data.photoURL, theirTierColor: tierColor)

            // --- Badges Card ---
            applyBadges(tierColor: tierColor)

        } else {
            tierChip.isHidden = true
            scoreCard.isHidden = true
            carShowcaseCard.isHidden = true
            comparisonCard.isHidden = true
            badgesCard.isHidden = true
            scoreStatValue.text = "—"
        }

        // Buttons
        applyButtonStates()
    }

    // MARK: - Apply New Cards Data

    private func applyCarShowcase(tierIndex: Int, carName: String, tierColor: UIColor) {
        guard let tier = HealthTier.forIndex(tierIndex) else {
            carShowcaseCard.isHidden = true
            return
        }

        carShowcaseCard.isHidden = false

        // Car image from asset catalog
        carImageView.image = UIImage(named: tier.imageName)

        // Glow color
        carGlowLayer.colors = [
            tierColor.withAlphaComponent(0.3).cgColor,
            UIColor.clear.cgColor
        ]

        // Labels
        carShowcaseNameLabel.text = carName
        carShowcaseTierLabel.text = String(format: "social.tierLevel".localized, tierIndex + 1)
        carShowcaseTierLabel.textColor = tierColor

        // Update tier ladder dots
        for i in 0..<5 {
            guard let col = tierLadderStack.arrangedSubviews[safe: i] as? UIStackView,
                  let dot = col.arrangedSubviews.first else { continue }

            let dotTier = HealthTier.forIndex(i)
            let isCurrent = (i == tierIndex)

            if isCurrent {
                dot.backgroundColor = tierColor
                dot.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
                dot.layer.shadowColor = tierColor.cgColor
                dot.layer.shadowOpacity = 0.6
                dot.layer.shadowRadius = 6
                dot.layer.shadowOffset = .zero
            } else {
                dot.backgroundColor = (dotTier?.color ?? AIONDesign.surfaceElevated).withAlphaComponent(0.3)
                dot.transform = .identity
                dot.layer.shadowOpacity = 0
            }
        }

        // Gradient accent border
        carShowcaseCard.layer.borderColor = tierColor.withAlphaComponent(0.3).cgColor
    }

    private func applyComparison(theirScore: Int, theirName: String, theirPhotoURL: String?, theirTierColor: UIColor) {
        guard let myScore = GeminiResultStore.loadHealthScore(), myScore > 0 else {
            comparisonCard.isHidden = true
            return
        }

        comparisonCard.isHidden = false

        let myTier = HealthTier.forScore(myScore)
        let myColor = myTier.color

        // Your side
        if let currentUser = Auth.auth().currentUser {
            yourAvatarRing.loadImage(from: currentUser.photoURL?.absoluteString)
            yourAvatarRing.ringColors = [myColor, myColor.withAlphaComponent(0.5)]
        }
        yourScoreLabel.text = "\(myScore)"
        yourScoreLabel.textColor = myColor

        // Their side
        let firstName = theirName.components(separatedBy: " ").first ?? theirName
        theirCompLabel.text = firstName
        theirAvatarRing.loadImage(from: theirPhotoURL)
        theirAvatarRing.ringColors = [theirTierColor, theirTierColor.withAlphaComponent(0.5)]
        theirScoreLabel.text = "\(theirScore)"
        theirScoreLabel.textColor = theirTierColor

        // Comparison bar
        let total = max(myScore + theirScore, 1)
        let myFraction = CGFloat(myScore) / CGFloat(total)

        compBarYouWidth?.isActive = false
        compBarYouWidth = comparisonBarYou.widthAnchor.constraint(
            equalTo: comparisonBarContainer.widthAnchor,
            multiplier: max(min(myFraction, 0.95), 0.05)
        )
        compBarYouWidth?.isActive = true

        comparisonBarYou.backgroundColor = myColor
        comparisonBarThem.backgroundColor = theirTierColor

        // Status text
        let diff = myScore - theirScore
        if diff > 0 {
            comparisonStatusLabel.text = String(format: "social.youLeadByPoints".localized, diff)
            comparisonStatusLabel.textColor = AIONDesign.accentSuccess
        } else if diff < 0 {
            comparisonStatusLabel.text = String(format: "social.behindByPoints".localized, abs(diff))
            comparisonStatusLabel.textColor = AIONDesign.accentWarning
        } else {
            comparisonStatusLabel.text = "social.tiedScore".localized
            comparisonStatusLabel.textColor = AIONDesign.accentPrimary
        }
    }

    private func applyBadges(tierColor: UIColor) {
        // Show badges card if we have any data
        let hasMemberSince = memberSinceDate != nil
        let hasStreak = streakDays > 0
        let hasPeak = peakScore > 0
        guard hasMemberSince || hasStreak || hasPeak else {
            badgesCard.isHidden = true
            return
        }

        badgesCard.isHidden = false

        // Member since
        if let joinDate = memberSinceDate {
            let months = Calendar.current.dateComponents([.month], from: joinDate, to: Date()).month ?? 0
            if months >= 12 {
                let years = months / 12
                memberValueLabel.text = String(format: "social.yearsCount".localized, years)
            } else if months > 0 {
                memberValueLabel.text = String(format: "social.monthsCount".localized, months)
            } else {
                memberValueLabel.text = String(format: "social.daysCount".localized,
                    max(1, Calendar.current.dateComponents([.day], from: joinDate, to: Date()).day ?? 1))
            }
        } else {
            memberValueLabel.text = "—"
        }

        // Streak
        if hasStreak {
            streakValueLabel.text = "\(streakDays)"
            streakValueLabel.textColor = streakDays >= 7 ? .systemOrange : AIONDesign.textPrimary
        } else {
            streakValueLabel.text = "—"
        }

        // Peak score
        if hasPeak {
            peakScoreValueLabel.text = "\(peakScore)"
            peakScoreValueLabel.textColor = tierColor
        } else {
            peakScoreValueLabel.text = "—"
        }
    }

    private func applyScoreDescription(healthScore: Int) {
        switch healthScore {
        case 80...:
            scoreDescLabel.text = "social.aboutExcellent".localized
            scoreDescLabel.textColor = AIONDesign.accentSuccess
        case 60..<80:
            scoreDescLabel.text = "social.aboutGood".localized
            scoreDescLabel.textColor = AIONDesign.accentSecondary
        case 40..<60:
            scoreDescLabel.text = "social.aboutProgress".localized
            scoreDescLabel.textColor = AIONDesign.accentPrimary
        default:
            scoreDescLabel.text = "social.aboutStarting".localized
            scoreDescLabel.textColor = AIONDesign.accentWarning
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
            primaryButton.setTitle("social.follow".localized, for: .normal)
            primaryButton.backgroundColor = AIONDesign.accentPrimary
            primaryButton.setTitleColor(.white, for: .normal)
            showMessageButton()

        case .following:
            primaryButton.isHidden = false
            primaryButton.isEnabled = true
            primaryButton.setTitle("social.unfollow".localized, for: .normal)
            primaryButton.backgroundColor = .clear
            primaryButton.setTitleColor(AIONDesign.textPrimary, for: .normal)
            primaryButton.layer.borderWidth = 1
            primaryButton.layer.borderColor = AIONDesign.separator.withAlphaComponent(0.4).cgColor
            showMessageButton()

        case .followRequestSent:
            primaryButton.isHidden = false
            primaryButton.isEnabled = true
            primaryButton.setTitle("social.cancelRequest".localized, for: .normal)
            primaryButton.backgroundColor = .clear
            primaryButton.setTitleColor(AIONDesign.accentDanger, for: .normal)
            primaryButton.layer.borderWidth = 1
            primaryButton.layer.borderColor = AIONDesign.accentDanger.withAlphaComponent(0.4).cgColor
            showMessageButton()

        case .followRequestReceived:
            primaryButton.isHidden = false
            primaryButton.isEnabled = true
            primaryButton.setTitle("social.accept".localized, for: .normal)
            primaryButton.backgroundColor = AIONDesign.accentSuccess
            primaryButton.setTitleColor(.white, for: .normal)
            primaryButton.layer.borderWidth = 0

            secondaryButton.isHidden = false
            secondaryButton.setTitle("social.decline".localized, for: .normal)
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
            headerSection, statsCard, scoreCard,
            carShowcaseCard, comparisonCard, badgesCard, mutualCard
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
            title: "social.unfollow".localized,
            message: String(format: "social.unfollowConfirmMessage".localized, userData?.displayName ?? ""),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "cancel".localized, style: .cancel))
        alert.addAction(UIAlertAction(title: "social.unfollow".localized, style: .destructive) { [weak self] _ in
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
            title: "error".localized,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "ok".localized, style: .default))
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
