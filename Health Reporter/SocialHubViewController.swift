//
//  SocialHubViewController.swift
//  Health Reporter
//
//  2026 Social-First redesign — Instagram-style stories row, activity feed cards,
//  horizontal rivals carousel, compact top performers, weekly stats, invite banner.
//

import UIKit
import FirebaseAuth

final class SocialHubViewController: UIViewController {

    // MARK: - Data

    private var leaderboardEntries: [LeaderboardEntry] = []
    private var currentUserEntry: LeaderboardEntry?
    private var rankChange: RankChange?
    private var rivals: [LeaderboardEntry] = []
    private var followingRelations: [FollowRelation] = []

    private let lastRankKey = "arenaLastRank"

    // MARK: - UI Chrome

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.alwaysBounceVertical = true
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let contentStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 20
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let refreshControl = UIRefreshControl()

    private let loadingIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .large)
        ai.hidesWhenStopped = true
        ai.color = AIONDesign.accentPrimary
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    // Inline search UI
    private let searchBar: UISearchBar = {
        let sb = UISearchBar()
        sb.placeholder = "social.searchPlaceholder".localized
        sb.searchBarStyle = .minimal
        sb.backgroundImage = UIImage()
        sb.translatesAutoresizingMaskIntoConstraints = false
        if let textField = sb.value(forKey: "searchField") as? UITextField {
            textField.textColor = AIONDesign.textPrimary
            textField.backgroundColor = AIONDesign.surface
            textField.attributedPlaceholder = NSAttributedString(
                string: "social.searchPlaceholder".localized,
                attributes: [.foregroundColor: AIONDesign.textTertiary]
            )
            textField.textAlignment = LocalizationManager.shared.textAlignment
        }
        sb.tintColor = AIONDesign.accentPrimary
        sb.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        return sb
    }()

    private let searchResultsStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 10
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let searchResultsScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.alwaysBounceVertical = true
        sv.keyboardDismissMode = .interactive
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.isHidden = true
        return sv
    }()

    private var hasLoadedOnce = false
    private var hasAnimatedPodium = false
    private var lastLoadTime: Date?

    // Inline search
    private var searchResults: [UserSearchResult] = []
    private var isSearchActive = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "social.title".localized
        view.backgroundColor = AIONDesign.background
        view.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute

        setupNavigationBar()
        setupLayout()
        setupRefreshControl()

        AnalyticsService.shared.logScreenView(.socialHub)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Skip full reload if data was loaded recently (< 30 seconds ago)
        if let last = lastLoadTime, Date().timeIntervalSince(last) < 30, hasLoadedOnce {
            return
        }
        loadArenaData()
    }

    // MARK: - Public (backward compat)

    func switchToRequestsSegment() {
        // No-op: maintained for backward compatibility with tab bar routing.
    }

    // MARK: - Navigation Bar

    private func setupNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [
            .foregroundColor: AIONDesign.textPrimary,
            .font: UIFont.systemFont(ofSize: 18, weight: .bold)
        ]
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
    }

    // MARK: - Layout

    private func setupLayout() {
        searchBar.delegate = self

        view.addSubview(searchBar)
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        view.addSubview(searchResultsScrollView)
        searchResultsScrollView.addSubview(searchResultsStack)
        view.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            // Search bar pinned at top
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),

            // Social content below search bar
            scrollView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -40),

            // Search results overlay (same position as scroll view)
            searchResultsScrollView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            searchResultsScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchResultsScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchResultsScrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            searchResultsStack.topAnchor.constraint(equalTo: searchResultsScrollView.contentLayoutGuide.topAnchor, constant: 12),
            searchResultsStack.leadingAnchor.constraint(equalTo: searchResultsScrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            searchResultsStack.trailingAnchor.constraint(equalTo: searchResultsScrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            searchResultsStack.bottomAnchor.constraint(equalTo: searchResultsScrollView.contentLayoutGuide.bottomAnchor, constant: -40),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func setupRefreshControl() {
        refreshControl.tintColor = AIONDesign.accentPrimary
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        scrollView.refreshControl = refreshControl
    }

    // MARK: - Actions

    @objc private func handleRefresh() {
        loadArenaData()
    }

    @objc private func leaderboardTapped() {
        let vc = LeaderboardViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Data Loading

    private func loadArenaData() {
        let isFirstLoad = !hasLoadedOnce

        if isFirstLoad {
            loadingIndicator.startAnimating()
            scrollView.alpha = 0.5
        }

        let group = DispatchGroup()

        // Fetch 1: Leaderboard (friends/following)
        group.enter()
        LeaderboardFirestoreSync.fetchFriendsLeaderboard { [weak self] entries in
            guard let self = self else { group.leave(); return }
            self.leaderboardEntries = entries
            self.currentUserEntry = entries.first(where: { $0.isCurrentUser })

            if let userEntry = self.currentUserEntry, let currentRank = userEntry.rank {
                let previousRank = UserDefaults.standard.object(forKey: self.lastRankKey) as? Int
                self.rankChange = RankChange(previousRank: previousRank, currentRank: currentRank)
                UserDefaults.standard.set(currentRank, forKey: self.lastRankKey)
            } else {
                self.rankChange = nil
            }

            if let userScore = self.currentUserEntry?.healthScore {
                self.rivals = entries.filter {
                    !$0.isCurrentUser && abs($0.healthScore - userScore) <= 10
                }
            } else {
                self.rivals = []
            }
            group.leave()
        }

        // Fetch 2: Following list (for stories row)
        group.enter()
        FollowFirestoreSync.fetchFollowing { [weak self] relations in
            self?.followingRelations = relations
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.loadingIndicator.stopAnimating()
            self.refreshControl.endRefreshing()
            self.lastLoadTime = Date()

            if isFirstLoad {
                self.hasLoadedOnce = true
                UIView.animate(withDuration: 0.25) { self.scrollView.alpha = 1 }
                self.rebuildSections()
            } else {
                self.rebuildSectionsQuietly()
            }
        }
    }

    // MARK: - Rebuild

    private func rebuildSections() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        buildStoriesRow()
        buildActivityFeed()
        buildRivalsBattle()
        buildTopPerformersStrip()
        buildWeeklyMomentum()
        buildInviteBanner()

        animateSectionEntrance()
    }

    private func rebuildSectionsQuietly() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        buildStoriesRow()
        buildActivityFeed()
        buildRivalsBattle()
        buildTopPerformersStrip()
        buildWeeklyMomentum()
        buildInviteBanner()
    }

    // =========================================================================
    // MARK: - Section 1 : Stories Row (Instagram-style)
    // =========================================================================

    private func buildStoriesRow() {
        // Don't show stories row if there's nothing to display
        guard !followingRelations.isEmpty else { return }

        let carousel = UIScrollView()
        carousel.translatesAutoresizingMaskIntoConstraints = false
        carousel.showsHorizontalScrollIndicator = false
        carousel.alwaysBounceHorizontal = true
        carousel.clipsToBounds = false
        carousel.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        carousel.addSubview(stack)

        // Following users — sorted by most recently active first
        let sortedRelations = followingRelations.sorted {
            ($0.lastUpdated ?? $0.followedAt) > ($1.lastUpdated ?? $1.followedAt)
        }
        for relation in sortedRelations {
            let firstName = relation.displayName.components(separatedBy: " ").first ?? relation.displayName
            let story = makeStoryCircle(
                name: firstName,
                photoURL: relation.photoURL,
                tierIndex: relation.carTierIndex ?? 0,
                uid: relation.uid,
                isCurrentUser: false
            )
            stack.addArrangedSubview(story)
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: carousel.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: carousel.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: carousel.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: carousel.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: carousel.frameLayoutGuide.heightAnchor),
            carousel.heightAnchor.constraint(equalToConstant: 104),
        ])

        contentStack.addArrangedSubview(carousel)
    }

    private func makeStoryCircle(name: String, photoURL: String?, tierIndex: Int, uid: String?, isCurrentUser: Bool) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.isUserInteractionEnabled = true

        let avatarSize: CGFloat = 68
        let avatar = AvatarRingView(size: avatarSize)
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.ringWidth = 3

        // Ring colors from tier
        let tier = CarTierEngine.tiers[safe: tierIndex]
        if isCurrentUser {
            avatar.ringColors = [AIONDesign.accentPrimary, AIONDesign.accentSecondary]
            avatar.isAnimated = true
        } else {
            let tierColor = tier?.color ?? AIONDesign.accentPrimary
            avatar.ringColors = [tierColor, tierColor.withAlphaComponent(0.6)]
            avatar.isAnimated = false
        }
        avatar.loadImage(from: photoURL)
        container.addSubview(avatar)

        let nameLabel = UILabel()
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.text = name
        nameLabel.font = .systemFont(ofSize: 11, weight: .medium)
        nameLabel.textColor = AIONDesign.textSecondary
        nameLabel.textAlignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail
        container.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 80),

            avatar.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            avatar.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            avatar.widthAnchor.constraint(equalToConstant: avatarSize),
            avatar.heightAnchor.constraint(equalToConstant: avatarSize),

            nameLabel.topAnchor.constraint(equalTo: avatar.bottomAnchor, constant: 4),
            nameLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            nameLabel.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])

        if let uid = uid {
            container.accessibilityIdentifier = uid
            let tap = UITapGestureRecognizer(target: self, action: #selector(storyAvatarTapped(_:)))
            container.addGestureRecognizer(tap)
        }

        return container
    }

    @objc private func storyAvatarTapped(_ gesture: UITapGestureRecognizer) {
        guard let uid = gesture.view?.accessibilityIdentifier else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        AnalyticsService.shared.logEvent(.storyAvatarTapped, parameters: ["user_uid": uid])
        pushUserProfile(uid: uid)
    }

    // =========================================================================
    // MARK: - Section 2 : Activity Feed (replaces leaderboard table)
    // =========================================================================

    private func buildActivityFeed() {
        let otherEntries = leaderboardEntries.filter { !$0.isCurrentUser }

        if otherEntries.isEmpty {
            buildEmptyState()
            return
        }

        let header = makeSectionHeader(text: "social.activity".localized, icon: "bolt.heart.fill")
        contentStack.addArrangedSubview(header)

        // Sort by lastUpdated (most recent first)
        let sorted = otherEntries.sorted { ($0.lastUpdated ?? .distantPast) > ($1.lastUpdated ?? .distantPast) }

        for entry in sorted {
            let card = makeActivityCard(entry: entry)
            contentStack.addArrangedSubview(card)
        }
    }

    private func makeActivityCard(entry: LeaderboardEntry) -> UIView {
        let card = makeFloatingCard()
        card.isUserInteractionEnabled = true

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        // Avatar
        let avatar = AvatarRingView(size: 44)
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.ringWidth = 2
        let tier = CarTierEngine.tiers[safe: entry.carTierIndex]
        let tierColor = tier?.color ?? AIONDesign.accentPrimary
        avatar.ringColors = [tierColor, tierColor.withAlphaComponent(0.6)]
        avatar.loadImage(from: entry.photoURL)
        card.addSubview(avatar)

        // Name + tier emoji
        let nameLabel = UILabel()
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 15, weight: .bold)
        nameLabel.textColor = AIONDesign.textPrimary
        nameLabel.text = entry.displayName
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.textAlignment = LocalizationManager.shared.textAlignment
        card.addSubview(nameLabel)

        // Tier label + time
        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        subtitleLabel.textColor = AIONDesign.textTertiary
        let tierEmoji = tier?.emoji ?? ""
        let timeAgo = relativeTimeString(from: entry.lastUpdated)
        subtitleLabel.text = "\(tierEmoji) \(entry.carTierLabel)  ·  \(timeAgo)"
        subtitleLabel.textAlignment = LocalizationManager.shared.textAlignment
        card.addSubview(subtitleLabel)

        // Score (large)
        let scoreLabel = UILabel()
        scoreLabel.translatesAutoresizingMaskIntoConstraints = false
        scoreLabel.text = "\(entry.healthScore)"
        scoreLabel.font = .monospacedDigitSystemFont(ofSize: 28, weight: .black)
        scoreLabel.textColor = tierColor
        card.addSubview(scoreLabel)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 80),

            avatar.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            avatar.widthAnchor.constraint(equalToConstant: 44),
            avatar.heightAnchor.constraint(equalToConstant: 44),

            nameLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            subtitleLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 3),

            scoreLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor),
        ])

        if isRTL {
            NSLayoutConstraint.activate([
                avatar.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
                nameLabel.trailingAnchor.constraint(equalTo: avatar.leadingAnchor, constant: -12),
                nameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: scoreLabel.trailingAnchor, constant: 12),
                subtitleLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
                subtitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: scoreLabel.trailingAnchor, constant: 12),
                scoreLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            ])
        } else {
            NSLayoutConstraint.activate([
                avatar.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
                nameLabel.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 12),
                nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: scoreLabel.leadingAnchor, constant: -12),
                subtitleLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
                subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: scoreLabel.leadingAnchor, constant: -12),
                scoreLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            ])
        }

        // Tap
        let tap = UITapGestureRecognizer(target: self, action: #selector(activityCardTapped(_:)))
        card.addGestureRecognizer(tap)
        card.accessibilityIdentifier = entry.uid

        return card
    }

    @objc private func activityCardTapped(_ gesture: UITapGestureRecognizer) {
        guard let uid = gesture.view?.accessibilityIdentifier else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        AnalyticsService.shared.logEvent(.activityFeedCardTapped, parameters: ["user_uid": uid])
        pushUserProfile(uid: uid)
    }

    private func buildEmptyState() {
        let card = makeFloatingCard()

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 38, weight: .ultraLight)
        let icon = UIImageView(image: UIImage(systemName: "person.badge.plus", withConfiguration: iconConfig))
        icon.tintColor = AIONDesign.accentPrimary.withAlphaComponent(0.6)
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = "social.noDataYet".localized
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = AIONDesign.textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .vertical
        stack.spacing = 10
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 140),
            stack.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: card.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -24),
            icon.heightAnchor.constraint(equalToConstant: 44),
        ])

        // Tap to focus search bar
        let tap = UITapGestureRecognizer(target: self, action: #selector(focusSearchBar))
        card.addGestureRecognizer(tap)
        card.isUserInteractionEnabled = true

        contentStack.addArrangedSubview(card)
    }

    // =========================================================================
    // MARK: - Section 3 : Rivals Battle (kept, minor restyle)
    // =========================================================================

    private func buildRivalsBattle() {
        guard !rivals.isEmpty else { return }

        let header = makeSectionHeader(text: "social.challengeFriends".localized, icon: "bolt.fill")
        contentStack.addArrangedSubview(header)

        // Horizontal scroll
        let carousel = UIScrollView()
        carousel.translatesAutoresizingMaskIntoConstraints = false
        carousel.showsHorizontalScrollIndicator = false
        carousel.alwaysBounceHorizontal = true
        carousel.clipsToBounds = false
        carousel.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute

        let carouselStack = UIStackView()
        carouselStack.axis = .horizontal
        carouselStack.spacing = 12
        carouselStack.translatesAutoresizingMaskIntoConstraints = false
        carouselStack.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        carousel.addSubview(carouselStack)

        let userScore = currentUserEntry?.healthScore ?? 0

        for rival in rivals {
            let card = makeRivalCard(rival: rival, userScore: userScore)
            carouselStack.addArrangedSubview(card)
        }

        NSLayoutConstraint.activate([
            carouselStack.topAnchor.constraint(equalTo: carousel.contentLayoutGuide.topAnchor),
            carouselStack.leadingAnchor.constraint(equalTo: carousel.contentLayoutGuide.leadingAnchor),
            carouselStack.trailingAnchor.constraint(equalTo: carousel.contentLayoutGuide.trailingAnchor),
            carouselStack.bottomAnchor.constraint(equalTo: carousel.contentLayoutGuide.bottomAnchor),
            carouselStack.heightAnchor.constraint(equalTo: carousel.frameLayoutGuide.heightAnchor),
            carousel.heightAnchor.constraint(equalToConstant: 100),
        ])

        contentStack.addArrangedSubview(carousel)
    }

    private func makeRivalCard(rival: LeaderboardEntry, userScore: Int) -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = AIONDesign.surface
        card.layer.cornerRadius = 18
        card.isUserInteractionEnabled = true

        let avatar = AvatarRingView(size: 36)
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.ringWidth = 2
        avatar.loadImage(from: rival.photoURL)
        card.addSubview(avatar)

        let nameLabel = UILabel()
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.text = rival.displayName
        nameLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        nameLabel.textColor = AIONDesign.textPrimary
        nameLabel.lineBreakMode = .byTruncatingTail
        card.addSubview(nameLabel)

        let scoreLabel = UILabel()
        scoreLabel.translatesAutoresizingMaskIntoConstraints = false
        scoreLabel.text = "\(rival.healthScore)"
        scoreLabel.font = .systemFont(ofSize: 11, weight: .medium)
        scoreLabel.textColor = AIONDesign.textTertiary
        card.addSubview(scoreLabel)

        // VS badge
        let diff = userScore - rival.healthScore
        let diffBadge = UIView()
        diffBadge.translatesAutoresizingMaskIntoConstraints = false
        diffBadge.layer.cornerRadius = 10

        let diffLabel = UILabel()
        diffLabel.translatesAutoresizingMaskIntoConstraints = false
        diffLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .bold)

        if diff > 0 {
            diffLabel.text = "+\(diff)"
            diffLabel.textColor = AIONDesign.accentSuccess
            diffBadge.backgroundColor = AIONDesign.accentSuccess.withAlphaComponent(0.12)
        } else if diff < 0 {
            diffLabel.text = "\(diff)"
            diffLabel.textColor = AIONDesign.accentDanger
            diffBadge.backgroundColor = AIONDesign.accentDanger.withAlphaComponent(0.12)
        } else {
            diffLabel.text = "="
            diffLabel.textColor = AIONDesign.textTertiary
            diffBadge.backgroundColor = AIONDesign.separator.withAlphaComponent(0.15)
        }

        diffBadge.addSubview(diffLabel)
        card.addSubview(diffBadge)

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(equalToConstant: 175),
            avatar.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            diffLabel.topAnchor.constraint(equalTo: diffBadge.topAnchor, constant: 3),
            diffLabel.bottomAnchor.constraint(equalTo: diffBadge.bottomAnchor, constant: -3),
            diffLabel.leadingAnchor.constraint(equalTo: diffBadge.leadingAnchor, constant: 8),
            diffLabel.trailingAnchor.constraint(equalTo: diffBadge.trailingAnchor, constant: -8),
        ])

        if isRTL {
            NSLayoutConstraint.activate([
                avatar.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
                nameLabel.trailingAnchor.constraint(equalTo: avatar.leadingAnchor, constant: -10),
                nameLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
                nameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: diffBadge.trailingAnchor, constant: 6),
                scoreLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
                scoreLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
                diffBadge.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
                diffBadge.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            ])
        } else {
            NSLayoutConstraint.activate([
                avatar.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
                nameLabel.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 10),
                nameLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
                nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: diffBadge.leadingAnchor, constant: -6),
                scoreLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
                scoreLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
                diffBadge.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
                diffBadge.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            ])
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(rivalCardTapped(_:)))
        card.addGestureRecognizer(tap)
        card.accessibilityIdentifier = rival.uid

        return card
    }

    @objc private func rivalCardTapped(_ gesture: UITapGestureRecognizer) {
        guard let uid = gesture.view?.accessibilityIdentifier else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        pushUserProfile(uid: uid)
    }

    // =========================================================================
    // MARK: - Section 4 : Top Performers Strip (compact)
    // =========================================================================

    private func buildTopPerformersStrip() {
        let top3 = leaderboardEntries.prefix(3)
        guard !top3.isEmpty else { return }

        // Header with "See All" link
        let headerContainer = UIView()
        headerContainer.translatesAutoresizingMaskIntoConstraints = false

        let headerLabel = UILabel()
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.font = .systemFont(ofSize: 13, weight: .heavy)
        headerLabel.textColor = AIONDesign.textSecondary

        let iconAttachment = NSTextAttachment()
        iconAttachment.image = UIImage(
            systemName: "crown.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        )?.withTintColor(AIONDesign.accentPrimary, renderingMode: .alwaysOriginal)
        let attrText = NSMutableAttributedString(attachment: iconAttachment)
        attrText.append(NSAttributedString(string: "  " + "social.topPerformers".localized.uppercased(), attributes: [
            .font: UIFont.systemFont(ofSize: 13, weight: .heavy),
            .foregroundColor: AIONDesign.textSecondary,
            .kern: 0.8 as NSNumber,
        ]))
        headerLabel.attributedText = attrText
        headerLabel.textAlignment = LocalizationManager.shared.textAlignment

        let seeAllBtn = UIButton(type: .system)
        seeAllBtn.translatesAutoresizingMaskIntoConstraints = false
        seeAllBtn.setTitle("social.seeAll".localized, for: .normal)
        seeAllBtn.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        seeAllBtn.setTitleColor(AIONDesign.accentPrimary, for: .normal)
        seeAllBtn.addTarget(self, action: #selector(leaderboardTapped), for: .touchUpInside)

        headerContainer.addSubview(headerLabel)
        headerContainer.addSubview(seeAllBtn)

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 4),
            headerLabel.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor),
            seeAllBtn.centerYAnchor.constraint(equalTo: headerLabel.centerYAnchor),
            headerContainer.heightAnchor.constraint(equalToConstant: 26),
        ])
        if isRTL {
            NSLayoutConstraint.activate([
                headerLabel.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -4),
                seeAllBtn.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor),
            ])
        } else {
            NSLayoutConstraint.activate([
                headerLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 4),
                seeAllBtn.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor),
            ])
        }

        contentStack.addArrangedSubview(headerContainer)

        // Podium view for top 3
        let podium = PodiumView()
        podium.translatesAutoresizingMaskIntoConstraints = false

        let entries = Array(top3)
        let currentUid = Auth.auth().currentUser?.uid ?? ""

        let first: PodiumView.Entry? = entries.count > 0 ? PodiumView.Entry(
            uid: entries[0].uid,
            rank: 1,
            name: entries[0].displayName.components(separatedBy: " ").first ?? entries[0].displayName,
            photoURL: entries[0].photoURL,
            score: entries[0].healthScore,
            isCurrentUser: entries[0].uid == currentUid
        ) : nil

        let second: PodiumView.Entry? = entries.count > 1 ? PodiumView.Entry(
            uid: entries[1].uid,
            rank: 2,
            name: entries[1].displayName.components(separatedBy: " ").first ?? entries[1].displayName,
            photoURL: entries[1].photoURL,
            score: entries[1].healthScore,
            isCurrentUser: entries[1].uid == currentUid
        ) : nil

        let third: PodiumView.Entry? = entries.count > 2 ? PodiumView.Entry(
            uid: entries[2].uid,
            rank: 3,
            name: entries[2].displayName.components(separatedBy: " ").first ?? entries[2].displayName,
            photoURL: entries[2].photoURL,
            score: entries[2].healthScore,
            isCurrentUser: entries[2].uid == currentUid
        ) : nil

        podium.configure(first: first, second: second, third: third)
        podium.onUserTapped = { [weak self] uid in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            self?.pushUserProfile(uid: uid)
        }

        podium.heightAnchor.constraint(equalToConstant: 185).isActive = true
        contentStack.addArrangedSubview(podium)
        if !hasAnimatedPodium {
            podium.animateEntrance()
            hasAnimatedPodium = true
        }

        // Compact strip below podium
        let strip = UIStackView()
        strip.axis = .horizontal
        strip.spacing = 10
        strip.distribution = .fillEqually
        strip.translatesAutoresizingMaskIntoConstraints = false
        strip.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute

        let medals = ["", "\u{1F947}", "\u{1F948}", "\u{1F949}"]

        for (index, entry) in top3.enumerated() {
            let cell = makeCompactTop3Cell(entry: entry, medal: medals[safe: index + 1] ?? "")
            strip.addArrangedSubview(cell)
        }

        strip.heightAnchor.constraint(equalToConstant: 80).isActive = true
        contentStack.addArrangedSubview(strip)
    }

    private func makeCompactTop3Cell(entry: LeaderboardEntry, medal: String) -> UIView {
        let cell = UIView()
        cell.translatesAutoresizingMaskIntoConstraints = false
        cell.backgroundColor = AIONDesign.surface
        cell.layer.cornerRadius = 16
        cell.clipsToBounds = true
        cell.isUserInteractionEnabled = true

        let hStack = UIStackView()
        hStack.axis = .horizontal
        hStack.spacing = 6
        hStack.alignment = .center
        hStack.translatesAutoresizingMaskIntoConstraints = false
        hStack.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute

        let medalLabel = UILabel()
        medalLabel.text = medal
        medalLabel.font = .systemFont(ofSize: 18)

        let avatar = AvatarRingView(size: 32)
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.ringWidth = 1.5
        avatar.isAnimated = false
        avatar.loadImage(from: entry.photoURL)

        let vStack = UIStackView()
        vStack.axis = .vertical
        vStack.spacing = 1

        let nameLabel = UILabel()
        nameLabel.text = entry.displayName.components(separatedBy: " ").first ?? entry.displayName
        nameLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        nameLabel.textColor = AIONDesign.textPrimary
        nameLabel.lineBreakMode = .byTruncatingTail

        let scoreLabel = UILabel()
        scoreLabel.text = "\(entry.healthScore)"
        scoreLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .bold)
        scoreLabel.textColor = AIONDesign.accentPrimary

        vStack.addArrangedSubview(nameLabel)
        vStack.addArrangedSubview(scoreLabel)

        hStack.addArrangedSubview(medalLabel)
        hStack.addArrangedSubview(avatar)
        hStack.addArrangedSubview(vStack)

        cell.addSubview(hStack)

        NSLayoutConstraint.activate([
            avatar.widthAnchor.constraint(equalToConstant: 32),
            avatar.heightAnchor.constraint(equalToConstant: 32),
            hStack.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            hStack.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            hStack.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -8),
        ])

        if entry.isCurrentUser {
            cell.layer.borderWidth = 1.5
            cell.layer.borderColor = AIONDesign.accentPrimary.withAlphaComponent(0.35).cgColor
        }

        cell.accessibilityIdentifier = entry.uid
        let tap = UITapGestureRecognizer(target: self, action: #selector(top3CellTapped(_:)))
        cell.addGestureRecognizer(tap)

        return cell
    }

    @objc private func top3CellTapped(_ gesture: UITapGestureRecognizer) {
        guard let uid = gesture.view?.accessibilityIdentifier else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        pushUserProfile(uid: uid)
    }

    // =========================================================================
    // MARK: - Section 5 : Weekly Momentum (kept)
    // =========================================================================

    private func buildWeeklyMomentum() {
        let header = makeSectionHeader(text: "social.weeklyStats".localized, icon: "chart.bar.fill")
        contentStack.addArrangedSubview(header)

        let card = makeFloatingCard()

        let currentScore = currentUserEntry?.healthScore ?? 50
        let mockScores = (0..<7).map { _ in max(0, min(100, currentScore + Int.random(in: -15...15))) }

        let chart = WeeklyBarChart()
        chart.translatesAutoresizingMaskIntoConstraints = false

        let bestScore = mockScores.max() ?? 0
        let avgScore = mockScores.isEmpty ? 0 : mockScores.reduce(0, +) / mockScores.count
        let daysAbove80 = mockScores.filter { $0 >= 80 }.count

        let statsRow = UIStackView()
        statsRow.axis = .horizontal
        statsRow.distribution = .fillEqually
        statsRow.spacing = 8
        statsRow.translatesAutoresizingMaskIntoConstraints = false
        statsRow.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute

        statsRow.addArrangedSubview(makeStatPill(value: "\(bestScore)", label: "social.statBest".localized))
        statsRow.addArrangedSubview(makeStatPill(value: "\(avgScore)", label: "social.statAvg".localized))
        statsRow.addArrangedSubview(makeStatPill(value: "\(daysAbove80)/7", label: "social.statDays80".localized))

        let innerStack = UIStackView(arrangedSubviews: [chart, statsRow])
        innerStack.axis = .vertical
        innerStack.spacing = 14
        innerStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(innerStack)

        NSLayoutConstraint.activate([
            innerStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            innerStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            innerStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            innerStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        contentStack.addArrangedSubview(card)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak chart] in
            chart?.configure(scores: mockScores)
        }
    }

    private func makeStatPill(value: String, label: String) -> UIView {
        let pill = UIView()
        pill.backgroundColor = AIONDesign.surfaceElevated.withAlphaComponent(0.5)
        pill.layer.cornerRadius = 12
        pill.translatesAutoresizingMaskIntoConstraints = false

        let valLabel = UILabel()
        valLabel.text = value
        valLabel.font = .monospacedDigitSystemFont(ofSize: 16, weight: .bold)
        valLabel.textColor = AIONDesign.textPrimary
        valLabel.textAlignment = .center
        valLabel.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = label
        titleLabel.font = .systemFont(ofSize: 10, weight: .medium)
        titleLabel.textColor = AIONDesign.textTertiary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [valLabel, titleLabel])
        stack.axis = .vertical
        stack.spacing = 1
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(stack)

        NSLayoutConstraint.activate([
            pill.heightAnchor.constraint(equalToConstant: 46),
            stack.centerXAnchor.constraint(equalTo: pill.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
        ])

        return pill
    }

    // =========================================================================
    // MARK: - Section 6 : Invite Banner (kept)
    // =========================================================================

    private func buildInviteBanner() {
        let banner = UIView()
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.layer.cornerRadius = 22
        banner.clipsToBounds = true

        let gradientBg = CAGradientLayer()
        gradientBg.colors = [
            AIONDesign.accentPrimary.withAlphaComponent(0.14).cgColor,
            AIONDesign.accentSecondary.withAlphaComponent(0.07).cgColor,
        ]
        gradientBg.startPoint = CGPoint(x: 0, y: 0.5)
        gradientBg.endPoint = CGPoint(x: 1, y: 0.5)
        gradientBg.cornerRadius = 22
        banner.layer.insertSublayer(gradientBg, at: 0)

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        let iconView = UIImageView(image: UIImage(
            systemName: "person.badge.plus",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        ))
        iconView.tintColor = AIONDesign.accentPrimary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "social.inviteFriends".localized
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = AIONDesign.textPrimary
        titleLabel.textAlignment = LocalizationManager.shared.textAlignment

        let subtitleLabel = UILabel()
        subtitleLabel.text = "social.moreFriendsMoreCompetition".localized
        subtitleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        subtitleLabel.textColor = AIONDesign.textSecondary
        subtitleLabel.textAlignment = LocalizationManager.shared.textAlignment

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)

        let chevronName = isRTL ? "chevron.left" : "chevron.right"
        let arrowIcon = UIImageView(image: UIImage(
            systemName: chevronName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        ))
        arrowIcon.tintColor = AIONDesign.accentPrimary
        arrowIcon.translatesAutoresizingMaskIntoConstraints = false

        banner.addSubview(iconView)
        banner.addSubview(textStack)
        banner.addSubview(arrowIcon)

        NSLayoutConstraint.activate([
            banner.heightAnchor.constraint(equalToConstant: 72),
            iconView.centerYAnchor.constraint(equalTo: banner.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),
            textStack.centerYAnchor.constraint(equalTo: banner.centerYAnchor),
            arrowIcon.centerYAnchor.constraint(equalTo: banner.centerYAnchor),
        ])

        if isRTL {
            NSLayoutConstraint.activate([
                iconView.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -20),
                textStack.trailingAnchor.constraint(equalTo: iconView.leadingAnchor, constant: -14),
                textStack.leadingAnchor.constraint(greaterThanOrEqualTo: arrowIcon.trailingAnchor, constant: 12),
                arrowIcon.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 20),
            ])
        } else {
            NSLayoutConstraint.activate([
                iconView.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 20),
                textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 14),
                textStack.trailingAnchor.constraint(lessThanOrEqualTo: arrowIcon.leadingAnchor, constant: -12),
                arrowIcon.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -20),
            ])
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(inviteTapped))
        banner.addGestureRecognizer(tap)
        banner.isUserInteractionEnabled = true

        contentStack.addArrangedSubview(banner)

        DispatchQueue.main.async {
            gradientBg.frame = banner.bounds
        }
    }

    @objc private func inviteTapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let shareText = "social.shareText".localized
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = view
        present(activityVC, animated: true)
    }

    // =========================================================================
    // MARK: - Shared Helpers
    // =========================================================================

    private func makeFloatingCard() -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = AIONDesign.surface
        card.layer.cornerRadius = 22
        card.clipsToBounds = true
        return card
    }

    private func makeSectionHeader(text: String, icon: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .heavy)
        label.textColor = AIONDesign.textSecondary

        let iconAttachment = NSTextAttachment()
        iconAttachment.image = UIImage(
            systemName: icon,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        )?.withTintColor(AIONDesign.accentPrimary, renderingMode: .alwaysOriginal)

        let attrText = NSMutableAttributedString(attachment: iconAttachment)
        attrText.append(NSAttributedString(string: "  " + text.uppercased(), attributes: [
            .font: UIFont.systemFont(ofSize: 13, weight: .heavy),
            .foregroundColor: AIONDesign.textSecondary,
            .kern: 0.8 as NSNumber,
        ]))
        label.attributedText = attrText
        label.textAlignment = LocalizationManager.shared.textAlignment

        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            container.heightAnchor.constraint(equalToConstant: 26),
        ])

        return container
    }

    private func pushUserProfile(uid: String) {
        let vc = UserProfileViewController(userUid: uid)
        navigationController?.pushViewController(vc, animated: true)
    }

    /// Converts a date to a relative time string like "2h ago", "yesterday", etc.
    private func relativeTimeString(from date: Date?) -> String {
        guard let date = date else { return "" }
        let seconds = Int(Date().timeIntervalSince(date))

        if seconds < 60 {
            return "social.timeAgo.now".localized
        } else if seconds < 3600 {
            return String(format: "social.timeAgo.minutes".localized, seconds / 60)
        } else if seconds < 86400 {
            return String(format: "social.timeAgo.hours".localized, seconds / 3600)
        } else if seconds < 172800 {
            return "social.timeAgo.yesterday".localized
        } else {
            return String(format: "social.timeAgo.days".localized, seconds / 86400)
        }
    }

    @objc private func focusSearchBar() {
        searchBar.becomeFirstResponder()
    }

    // MARK: - Inline Search

    private func showSearchResults() {
        searchResultsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if searchResults.isEmpty {
            let emptyLabel = UILabel()
            emptyLabel.text = "social.noResults".localized
            emptyLabel.font = .systemFont(ofSize: 15, weight: .medium)
            emptyLabel.textColor = AIONDesign.textSecondary
            emptyLabel.textAlignment = .center
            emptyLabel.translatesAutoresizingMaskIntoConstraints = false
            let wrapper = UIView()
            wrapper.translatesAutoresizingMaskIntoConstraints = false
            wrapper.addSubview(emptyLabel)
            NSLayoutConstraint.activate([
                wrapper.heightAnchor.constraint(equalToConstant: 80),
                emptyLabel.centerXAnchor.constraint(equalTo: wrapper.centerXAnchor),
                emptyLabel.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor),
            ])
            searchResultsStack.addArrangedSubview(wrapper)
            return
        }

        for (index, result) in searchResults.enumerated() {
            let card = UserCardView()
            card.configure(with: result)

            card.onActionTapped = { [weak self] in
                self?.followUserFromSearch(result, cardIndex: index)
            }

            card.onCardTapped = { [weak self] in
                self?.saveRecentlyViewedUser(result)
                self?.pushUserProfile(uid: result.uid)
            }

            searchResultsStack.addArrangedSubview(card)
        }

        // Animate cards in
        for (index, view) in searchResultsStack.arrangedSubviews.enumerated() {
            view.alpha = 0
            view.transform = CGAffineTransform(translationX: 0, y: 20)
            UIView.animate(
                withDuration: 0.35,
                delay: Double(index) * 0.05,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.3
            ) {
                view.alpha = 1
                view.transform = .identity
            }
        }
    }

    private func followUserFromSearch(_ user: UserSearchResult, cardIndex: Int) {
        guard let card = searchResultsStack.arrangedSubviews[safe: cardIndex] as? UserCardView else { return }
        card.setLoading(true)

        if user.isFollowing {
            // Unfollow
            FollowFirestoreSync.unfollowUser(targetUid: user.uid) { [weak self] error in
                guard let self = self else { return }
                card.setLoading(false)

                if error != nil {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                } else {
                    if cardIndex < self.searchResults.count {
                        self.searchResults[cardIndex].isFollowing = false
                        card.configure(with: self.searchResults[cardIndex])
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    self.loadArenaData()
                }
            }
        } else {
            // Follow
            FollowFirestoreSync.followUser(targetUid: user.uid) { [weak self] error in
                guard let self = self else { return }
                card.setLoading(false)

                if error != nil {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                } else {
                    // Re-check actual state: if now in following list, it was a direct follow;
                    // otherwise it was a pending request
                    FollowFirestoreSync.fetchFollowing { [weak self] following in
                        guard let self = self, cardIndex < self.searchResults.count else { return }
                        let isNowFollowing = following.contains { $0.uid == user.uid }
                        if isNowFollowing {
                            self.searchResults[cardIndex].isFollowing = true
                            self.searchResults[cardIndex].hasPendingRequest = false
                        } else {
                            self.searchResults[cardIndex].hasPendingRequest = true
                            self.searchResults[cardIndex].requestSentByMe = true
                        }
                        card.configure(with: self.searchResults[cardIndex])
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    self.loadArenaData()
                }
            }
        }
    }

    private func enterSearchMode() {
        isSearchActive = true
        scrollView.isHidden = true
        searchResultsScrollView.isHidden = false
        searchBar.setShowsCancelButton(true, animated: true)
    }

    private func exitSearchMode() {
        isSearchActive = false
        searchBar.text = nil
        searchBar.setShowsCancelButton(false, animated: true)
        searchBar.resignFirstResponder()
        searchResults = []
        searchResultsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        searchResultsScrollView.isHidden = true
        scrollView.isHidden = false
    }

    // Recently viewed (shared with UserSearchViewController via UserDefaults)
    private func saveRecentlyViewedUser(_ result: UserSearchResult) {
        let key = "recentlyViewedUsers"
        var users = UserDefaults.standard.array(forKey: key) as? [[String: String]] ?? []
        users.removeAll { $0["uid"] == result.uid }
        var userData: [String: String] = ["uid": result.uid, "displayName": result.displayName]
        if let photoURL = result.photoURL {
            userData["photoURL"] = photoURL
        }
        users.insert(userData, at: 0)
        if users.count > 5 { users = Array(users.prefix(5)) }
        UserDefaults.standard.set(users, forKey: key)
    }

    // MARK: - Staggered Spring Entrance

    private func animateSectionEntrance() {
        for (index, section) in contentStack.arrangedSubviews.enumerated() {
            section.alpha = 0
            section.transform = CGAffineTransform(translationX: 0, y: 24)

            let delay = Double(index) * 0.07
            let damping: CGFloat = 0.78 + CGFloat(index) * 0.015
            UIView.animate(
                withDuration: 0.55,
                delay: delay,
                usingSpringWithDamping: min(damping, 0.92),
                initialSpringVelocity: 0.4
            ) {
                section.alpha = 1
                section.transform = .identity
            }
        }
    }
}

// MARK: - UISearchBarDelegate

extension SocialHubViewController: UISearchBarDelegate {

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        enterSearchMode()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        exitSearchMode()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(performInlineSearch), object: nil)

        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        if trimmed.count < 2 {
            searchResults = []
            searchResultsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            return
        }

        perform(#selector(performInlineSearch), with: nil, afterDelay: 0.4)
    }

    @objc private func performInlineSearch() {
        guard let query = searchBar.text?.trimmingCharacters(in: .whitespaces),
              query.count >= 2 else { return }

        FollowFirestoreSync.searchUsers(query: query) { [weak self] results in
            guard let self = self, self.isSearchActive else { return }
            self.searchResults = results
            self.showSearchResults()
        }
    }
}

// MARK: - Array Safe Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
