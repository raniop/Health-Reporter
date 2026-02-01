//
//  LeaderboardViewController.swift
//  Health Reporter
//
//  מסך לידרבורד מעוצב - עם פודיום לשלושת הראשונים, אנימציות ו-Glass Morphism.
//

import UIKit
import FirebaseAuth

final class LeaderboardViewController: UIViewController {

    // MARK: - Properties

    private var currentSegment: Int = 0
    private var globalEntries: [LeaderboardEntry] = []
    private var friendsEntries: [LeaderboardEntry] = []
    private var isOptedIn: Bool = false
    private var currentUserRank: Int?
    private var currentUserScore: Int?

    // MARK: - UI Elements

    private lazy var tabBarControl: AnimatedTabBarControl = {
        let control = AnimatedTabBarControl(items: [
            .init(title: "social.global".localized, icon: "globe"),
            .init(title: "social.friendsOnly".localized, icon: "person.2")
        ])
        control.translatesAutoresizingMaskIntoConstraints = false
        control.onSelectionChanged = { [weak self] index in
            self?.tabChanged(to: index)
        }
        return control
    }()

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
        s.spacing = AIONDesign.spacing
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    // Podium for top 3
    private let podiumView: PodiumView = {
        let v = PodiumView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()

    // Privacy card with glass effect
    private let privacyCard: GlassMorphismView = {
        let v = GlassMorphismView()
        v.cornerRadius = AIONDesign.cornerRadius
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let privacyLabel: UILabel = {
        let l = UILabel()
        l.text = "social.privacyToggle".localized
        l.font = .systemFont(ofSize: 15, weight: .medium)
        l.textColor = AIONDesign.textPrimary
        l.textAlignment = LocalizationManager.shared.textAlignment
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let privacySwitch: UISwitch = {
        let s = UISwitch()
        s.onTintColor = AIONDesign.accentPrimary
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    // Current user rank card with glow
    private let myRankCard: GlassMorphismView = {
        let v = GlassMorphismView()
        v.cornerRadius = AIONDesign.cornerRadius
        v.borderColors = [AIONDesign.accentPrimary, AIONDesign.accentSecondary]
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()

    private let myRankBadge: RankBadgeView = {
        let v = RankBadgeView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let myRankTitleLabel: UILabel = {
        let l = UILabel()
        l.text = "social.yourRank".localized
        l.font = .systemFont(ofSize: 13, weight: .medium)
        l.textColor = AIONDesign.textSecondary
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let myScoreLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 28, weight: .bold)
        l.textColor = AIONDesign.accentPrimary
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let progressView: ProgressToNextRankView = {
        let v = ProgressToNextRankView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()

    // Empty state
    private let emptyStateView: UIView = {
        let v = UIView()
        v.isHidden = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let emptyStateIcon: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = AIONDesign.textTertiary
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let emptyStateLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .medium)
        l.textColor = AIONDesign.textSecondary
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .large)
        ai.hidesWhenStopped = true
        ai.color = AIONDesign.accentPrimary
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    private let refreshControl = UIRefreshControl()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "social.leaderboard".localized
        view.backgroundColor = AIONDesign.background
        view.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        setupUI()
        setupRefreshControl()
        loadPrivacySetting()

        // Analytics: Log screen view
        AnalyticsService.shared.logScreenView(.leaderboard)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
    }

    // MARK: - Setup

    private func setupUI() {
        // Privacy card setup
        privacyCard.addSubview(privacyLabel)
        privacyCard.addSubview(privacySwitch)

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        // Common constraints
        NSLayoutConstraint.activate([
            privacyLabel.centerYAnchor.constraint(equalTo: privacyCard.centerYAnchor),
            privacySwitch.centerYAnchor.constraint(equalTo: privacyCard.centerYAnchor),
            privacyCard.heightAnchor.constraint(equalToConstant: 56),
        ])

        // RTL/LTR specific constraints for privacy card
        if isRTL {
            // Hebrew: Switch on left, label on right
            NSLayoutConstraint.activate([
                privacySwitch.leadingAnchor.constraint(equalTo: privacyCard.leadingAnchor, constant: 16),
                privacyLabel.trailingAnchor.constraint(equalTo: privacyCard.trailingAnchor, constant: -16),
                privacyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: privacySwitch.trailingAnchor, constant: 12),
            ])
        } else {
            // English: Label on left, switch on right
            NSLayoutConstraint.activate([
                privacyLabel.leadingAnchor.constraint(equalTo: privacyCard.leadingAnchor, constant: 16),
                privacySwitch.trailingAnchor.constraint(equalTo: privacyCard.trailingAnchor, constant: -16),
                privacySwitch.leadingAnchor.constraint(greaterThanOrEqualTo: privacyLabel.trailingAnchor, constant: 12),
            ])
        }

        privacySwitch.addTarget(self, action: #selector(privacySwitchChanged), for: .valueChanged)

        // My rank card setup
        myRankCard.addSubview(myRankBadge)
        myRankCard.addSubview(myRankTitleLabel)
        myRankCard.addSubview(myScoreLabel)

        NSLayoutConstraint.activate([
            myRankBadge.centerYAnchor.constraint(equalTo: myRankCard.centerYAnchor),
            myRankBadge.widthAnchor.constraint(equalToConstant: 44),
            myRankBadge.heightAnchor.constraint(equalToConstant: 44),
            myRankTitleLabel.topAnchor.constraint(equalTo: myRankCard.topAnchor, constant: 14),
            myScoreLabel.topAnchor.constraint(equalTo: myRankTitleLabel.bottomAnchor, constant: 2),
        ])

        // RTL/LTR specific constraints for myRankCard
        if isRTL {
            // Hebrew: Badge on left, text on right
            NSLayoutConstraint.activate([
                myRankBadge.leadingAnchor.constraint(equalTo: myRankCard.leadingAnchor, constant: 16),
                myRankTitleLabel.trailingAnchor.constraint(equalTo: myRankCard.trailingAnchor, constant: -16),
                myScoreLabel.trailingAnchor.constraint(equalTo: myRankTitleLabel.trailingAnchor),
            ])
        } else {
            // English: Badge on right, text on left
            NSLayoutConstraint.activate([
                myRankBadge.trailingAnchor.constraint(equalTo: myRankCard.trailingAnchor, constant: -16),
                myRankTitleLabel.leadingAnchor.constraint(equalTo: myRankCard.leadingAnchor, constant: 16),
                myScoreLabel.leadingAnchor.constraint(equalTo: myRankTitleLabel.leadingAnchor),
            ])
        }

        // Empty state setup
        emptyStateView.addSubview(emptyStateIcon)
        emptyStateView.addSubview(emptyStateLabel)

        NSLayoutConstraint.activate([
            emptyStateIcon.topAnchor.constraint(equalTo: emptyStateView.topAnchor),
            emptyStateIcon.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            emptyStateIcon.widthAnchor.constraint(equalToConstant: 60),
            emptyStateIcon.heightAnchor.constraint(equalToConstant: 60),

            emptyStateLabel.topAnchor.constraint(equalTo: emptyStateIcon.bottomAnchor, constant: AIONDesign.spacing),
            emptyStateLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor),
            emptyStateLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor),
            emptyStateLabel.bottomAnchor.constraint(equalTo: emptyStateView.bottomAnchor),
        ])

        view.addSubview(tabBarControl)
        view.addSubview(privacyCard)
        view.addSubview(podiumView)
        view.addSubview(myRankCard)
        view.addSubview(progressView)
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        view.addSubview(emptyStateView)
        view.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            tabBarControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AIONDesign.spacing),
            tabBarControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AIONDesign.spacing),
            tabBarControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AIONDesign.spacing),
            tabBarControl.heightAnchor.constraint(equalToConstant: 44),

            privacyCard.topAnchor.constraint(equalTo: tabBarControl.bottomAnchor, constant: AIONDesign.spacing),
            privacyCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AIONDesign.spacing),
            privacyCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AIONDesign.spacing),

            podiumView.topAnchor.constraint(equalTo: privacyCard.bottomAnchor, constant: AIONDesign.spacingLarge),
            podiumView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AIONDesign.spacing),
            podiumView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AIONDesign.spacing),
            podiumView.heightAnchor.constraint(equalToConstant: 155),

            myRankCard.topAnchor.constraint(equalTo: podiumView.bottomAnchor, constant: AIONDesign.spacing),
            myRankCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AIONDesign.spacing),
            myRankCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AIONDesign.spacing),
            myRankCard.heightAnchor.constraint(equalToConstant: 80),

            progressView.topAnchor.constraint(equalTo: myRankCard.bottomAnchor, constant: AIONDesign.spacing),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AIONDesign.spacing),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AIONDesign.spacing),

            scrollView.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: AIONDesign.spacing),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: AIONDesign.spacing),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -AIONDesign.spacing),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -AIONDesign.spacingLarge),

            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 50),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        updatePrivacyCardVisibility()
        addGlowToMyRankCard()

        // Handle taps on podium users
        podiumView.onUserTapped = { [weak self] uid in
            self?.showUserProfile(uid: uid)
        }
    }

    private func setupRefreshControl() {
        refreshControl.tintColor = AIONDesign.accentPrimary
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        scrollView.refreshControl = refreshControl
    }

    private func addGlowToMyRankCard() {
        myRankCard.applyGlowEffect(color: AIONDesign.accentPrimary, radius: 15, opacity: 0.3)
    }

    @objc private func handleRefresh() {
        loadData()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refreshControl.endRefreshing()
        }
    }

    // MARK: - Data Loading

    private func loadPrivacySetting() {
        LeaderboardFirestoreSync.getLeaderboardOptIn { [weak self] optIn in
            self?.isOptedIn = optIn
            self?.privacySwitch.isOn = optIn
        }
    }

    private func loadData() {
        switch currentSegment {
        case 0:
            loadGlobalLeaderboard()
        case 1:
            loadFriendsLeaderboard()
        default:
            break
        }
    }

    private func loadGlobalLeaderboard() {
        showLoading(true)
        LeaderboardFirestoreSync.fetchGlobalLeaderboard { [weak self] entries in
            self?.globalEntries = entries
            self?.showLoading(false)
            self?.updateUI()
            self?.animateEntrance()

            LeaderboardFirestoreSync.fetchUserRank { rank in
                self?.currentUserRank = rank
                self?.updateMyRankCard()
            }
        }
    }

    private func loadFriendsLeaderboard() {
        showLoading(true)
        LeaderboardFirestoreSync.fetchFriendsLeaderboard { [weak self] entries in
            self?.friendsEntries = entries
            self?.showLoading(false)
            self?.updateUI()
            self?.animateEntrance()
        }
    }

    // MARK: - UI Updates

    private func updatePrivacyCardVisibility() {
        privacyCard.isHidden = currentSegment != 0
    }

    private func updatePodium(entries: [LeaderboardEntry]) {
        guard entries.count >= 1 else {
            podiumView.isHidden = true
            return
        }

        podiumView.isHidden = false

        let first = entries.count > 0 ? entries[0] : nil
        let second = entries.count > 1 ? entries[1] : nil
        let third = entries.count > 2 ? entries[2] : nil

        podiumView.configure(
            first: first.map { PodiumView.Entry(
                uid: $0.uid,
                rank: 1,
                name: $0.displayName,
                photoURL: $0.photoURL,
                score: $0.healthScore,
                isCurrentUser: $0.isCurrentUser
            )},
            second: second.map { PodiumView.Entry(
                uid: $0.uid,
                rank: 2,
                name: $0.displayName,
                photoURL: $0.photoURL,
                score: $0.healthScore,
                isCurrentUser: $0.isCurrentUser
            )},
            third: third.map { PodiumView.Entry(
                uid: $0.uid,
                rank: 3,
                name: $0.displayName,
                photoURL: $0.photoURL,
                score: $0.healthScore,
                isCurrentUser: $0.isCurrentUser
            )}
        )
    }

    private func updateMyRankCard() {
        let entries = currentSegment == 0 ? globalEntries : friendsEntries

        if currentSegment == 0 {
            // Global leaderboard - use myEntry.rank from the entries list
            if let myEntry = entries.first(where: { $0.isCurrentUser }), let rank = myEntry.rank, isOptedIn {
                myRankCard.isHidden = false
                myRankBadge.configure(rank: rank)
                myScoreLabel.text = "\(myEntry.healthScore) " + "social.points".localized
                currentUserScore = myEntry.healthScore
                currentUserRank = rank
                updateProgressView(myEntry: myEntry, entries: entries)
            } else {
                myRankCard.isHidden = true
                progressView.isHidden = true
            }
        } else {
            // Friends leaderboard
            if let myEntry = entries.first(where: { $0.isCurrentUser }), let rank = myEntry.rank {
                myRankCard.isHidden = false
                myRankBadge.configure(rank: rank)
                myScoreLabel.text = "\(myEntry.healthScore) " + "social.points".localized
                currentUserScore = myEntry.healthScore
                updateProgressView(myEntry: myEntry, entries: entries)
            } else {
                myRankCard.isHidden = true
                progressView.isHidden = true
            }
        }
    }

    private func updateProgressView(myEntry: LeaderboardEntry, entries: [LeaderboardEntry]) {
        guard let myRank = myEntry.rank, myRank > 1 else {
            progressView.isHidden = true
            return
        }

        // Find the entry above us
        let entryAbove = entries.first { ($0.rank ?? 0) == myRank - 1 }
        if let above = entryAbove {
            progressView.isHidden = false
            let pointsNeeded = above.healthScore - myEntry.healthScore
            progressView.configure(current: myEntry.healthScore, nextRank: above.healthScore, pointsNeeded: pointsNeeded)
        } else {
            progressView.isHidden = true
        }
    }

    private func clearContent() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        emptyStateView.isHidden = true
    }

    private func showLoading(_ show: Bool) {
        if show {
            loadingIndicator.startAnimating()
            scrollView.alpha = 0.5
            emptyStateView.isHidden = true
        } else {
            loadingIndicator.stopAnimating()
            UIView.animate(withDuration: AIONDesign.animationFast) {
                self.scrollView.alpha = 1
            }
        }
    }

    private func showEmptyState(_ message: String, icon: String) {
        emptyStateLabel.text = message
        let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .light)
        emptyStateIcon.image = UIImage(systemName: icon, withConfiguration: config)
        emptyStateView.isHidden = false
        podiumView.isHidden = true
        myRankCard.isHidden = true
        progressView.isHidden = true
    }

    private func updateUI() {
        clearContent()
        updatePrivacyCardVisibility()

        let entries = currentSegment == 0 ? globalEntries : friendsEntries
        let emptyMessage = currentSegment == 0 ? "social.emptyGlobalLeaderboard".localized : "social.emptyFriendsLeaderboard".localized
        let emptyIcon = currentSegment == 0 ? "globe" : "person.2.slash"

        if entries.isEmpty {
            showEmptyState(emptyMessage, icon: emptyIcon)
            return
        }

        // Update podium with top 3
        updatePodium(entries: entries)
        updateMyRankCard()

        // Add remaining entries (skip top 3 since they're in podium)
        let remainingEntries = entries.dropFirst(3)
        for entry in remainingEntries {
            let view = LeaderboardEntryView()
            view.configure(with: entry)
            contentStack.addArrangedSubview(view)
        }
    }

    private func animateEntrance() {
        // Animate podium
        podiumView.animateEntrance()

        // Animate content cards
        for (index, view) in contentStack.arrangedSubviews.enumerated() {
            view.alpha = 0
            view.transform = CGAffineTransform(translationX: 0, y: 20)

            UIView.animate(
                withDuration: AIONDesign.animationMedium,
                delay: Double(index) * 0.06 + 0.3,
                usingSpringWithDamping: AIONDesign.springDamping,
                initialSpringVelocity: AIONDesign.springVelocity
            ) {
                view.alpha = 1
                view.transform = .identity
            }
        }
    }

    // MARK: - Actions

    private func tabChanged(to index: Int) {
        currentSegment = index
        loadData()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @objc private func privacySwitchChanged() {
        let newValue = privacySwitch.isOn

        if !newValue && isOptedIn {
            let alert = UIAlertController(
                title: "social.privacyTitle".localized,
                message: "social.privacyOffMessage".localized,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "cancel".localized, style: .cancel) { [weak self] _ in
                self?.privacySwitch.isOn = true
            })
            alert.addAction(UIAlertAction(title: "ok".localized, style: .default) { [weak self] _ in
                self?.updatePrivacySetting(false)
            })
            present(alert, animated: true)
        } else {
            updatePrivacySetting(newValue)
        }
    }

    private func updatePrivacySetting(_ optIn: Bool) {
        LeaderboardFirestoreSync.setLeaderboardOptIn(optIn) { [weak self] error in
            if let error = error {
                self?.showError(error.localizedDescription)
                self?.privacySwitch.isOn = self?.isOptedIn ?? false
            } else {
                self?.isOptedIn = optIn
                if self?.currentSegment == 0 {
                    self?.loadGlobalLeaderboard()
                }
            }
        }
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "error".localized, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "ok".localized, style: .default))
        present(alert, animated: true)
    }

    private func showUserProfile(uid: String) {
        // If tapping on self, navigate to Profile tab instead
        if uid == Auth.auth().currentUser?.uid {
            // Navigate to profile tab
            if let tabBarController = tabBarController {
                // Profile is the last tab (index 4)
                tabBarController.selectedIndex = 4
            }
            return
        }

        let vc = UserProfileViewController(userUid: uid)
        navigationController?.pushViewController(vc, animated: true)
    }
}
