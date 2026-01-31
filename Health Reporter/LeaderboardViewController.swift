//
//  LeaderboardViewController.swift
//  Health Reporter
//
//  מסך לידרבורד - גלובלי וחברים.
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

    // MARK: - UI Elements

    private let segmentedControl: UISegmentedControl = {
        let items = [
            "social.global".localized,
            "social.friendsOnly".localized
        ]
        let sc = UISegmentedControl(items: items)
        sc.selectedSegmentIndex = 0
        sc.translatesAutoresizingMaskIntoConstraints = false
        return sc
    }()

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = true
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

    private let privacyCard: UIView = {
        let v = UIView()
        v.backgroundColor = AIONDesign.surface
        v.layer.cornerRadius = AIONDesign.cornerRadius
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let privacyLabel: UILabel = {
        let l = UILabel()
        l.text = "social.privacyToggle".localized
        l.font = .systemFont(ofSize: 15, weight: .medium)
        l.textColor = AIONDesign.textPrimary
        l.textAlignment = .right
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let privacySwitch: UISwitch = {
        let s = UISwitch()
        s.onTintColor = AIONDesign.accentPrimary
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let rankCard: UIView = {
        let v = UIView()
        v.backgroundColor = AIONDesign.accentPrimary.withAlphaComponent(0.1)
        v.layer.cornerRadius = AIONDesign.cornerRadius
        v.layer.borderWidth = 2
        v.layer.borderColor = AIONDesign.accentPrimary.cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()

    private let rankTitleLabel: UILabel = {
        let l = UILabel()
        l.text = "social.yourRank".localized
        l.font = .systemFont(ofSize: 14, weight: .medium)
        l.textColor = AIONDesign.textSecondary
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let rankValueLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 32, weight: .bold)
        l.textColor = AIONDesign.accentPrimary
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let emptyStateLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .medium)
        l.textColor = AIONDesign.textSecondary
        l.textAlignment = .center
        l.numberOfLines = 0
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .large)
        ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "social.leaderboard".localized
        view.backgroundColor = AIONDesign.background
        view.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        setupUI()
        loadPrivacySetting()
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

        NSLayoutConstraint.activate([
            privacyLabel.trailingAnchor.constraint(equalTo: privacyCard.trailingAnchor, constant: -16),
            privacyLabel.centerYAnchor.constraint(equalTo: privacyCard.centerYAnchor),

            privacySwitch.leadingAnchor.constraint(equalTo: privacyCard.leadingAnchor, constant: 16),
            privacySwitch.centerYAnchor.constraint(equalTo: privacyCard.centerYAnchor),

            privacyCard.heightAnchor.constraint(equalToConstant: 50),
        ])

        privacySwitch.addTarget(self, action: #selector(privacySwitchChanged), for: .valueChanged)

        // Rank card setup
        rankCard.addSubview(rankTitleLabel)
        rankCard.addSubview(rankValueLabel)

        NSLayoutConstraint.activate([
            rankTitleLabel.topAnchor.constraint(equalTo: rankCard.topAnchor, constant: 12),
            rankTitleLabel.centerXAnchor.constraint(equalTo: rankCard.centerXAnchor),

            rankValueLabel.topAnchor.constraint(equalTo: rankTitleLabel.bottomAnchor, constant: 4),
            rankValueLabel.centerXAnchor.constraint(equalTo: rankCard.centerXAnchor),
            rankValueLabel.bottomAnchor.constraint(equalTo: rankCard.bottomAnchor, constant: -12),
        ])

        view.addSubview(segmentedControl)
        view.addSubview(privacyCard)
        view.addSubview(rankCard)
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        view.addSubview(emptyStateLabel)
        view.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AIONDesign.spacing),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AIONDesign.spacing),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AIONDesign.spacing),

            privacyCard.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: AIONDesign.spacing),
            privacyCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AIONDesign.spacing),
            privacyCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AIONDesign.spacing),

            rankCard.topAnchor.constraint(equalTo: privacyCard.bottomAnchor, constant: AIONDesign.spacing),
            rankCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AIONDesign.spacing),
            rankCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AIONDesign.spacing),

            scrollView.topAnchor.constraint(equalTo: rankCard.bottomAnchor, constant: AIONDesign.spacing),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: AIONDesign.spacing),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -AIONDesign.spacing),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -AIONDesign.spacingLarge),

            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 50),
            emptyStateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyStateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)

        updatePrivacyCardVisibility()
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

            // Also load user's rank
            LeaderboardFirestoreSync.fetchUserRank { rank in
                self?.currentUserRank = rank
                self?.updateRankCard()
            }
        }
    }

    private func loadFriendsLeaderboard() {
        showLoading(true)
        LeaderboardFirestoreSync.fetchFriendsLeaderboard { [weak self] entries in
            self?.friendsEntries = entries
            self?.showLoading(false)
            self?.updateUI()
        }
    }

    // MARK: - UI Updates

    private func updatePrivacyCardVisibility() {
        // Show privacy card only for global leaderboard
        privacyCard.isHidden = currentSegment != 0
    }

    private func updateRankCard() {
        if currentSegment == 0, let rank = currentUserRank, isOptedIn {
            rankCard.isHidden = false
            rankValueLabel.text = "#\(rank)"
        } else if currentSegment == 1 {
            // For friends, find current user's rank in the list
            if let myEntry = friendsEntries.first(where: { $0.isCurrentUser }), let rank = myEntry.rank {
                rankCard.isHidden = false
                rankValueLabel.text = "#\(rank)"
            } else {
                rankCard.isHidden = true
            }
        } else {
            rankCard.isHidden = true
        }
    }

    private func clearContent() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        emptyStateLabel.isHidden = true
    }

    private func showLoading(_ show: Bool) {
        if show {
            loadingIndicator.startAnimating()
            scrollView.isHidden = true
            emptyStateLabel.isHidden = true
        } else {
            loadingIndicator.stopAnimating()
            scrollView.isHidden = false
        }
    }

    private func showEmptyState(_ message: String) {
        emptyStateLabel.text = message
        emptyStateLabel.isHidden = false
    }

    private func updateUI() {
        clearContent()
        updatePrivacyCardVisibility()
        updateRankCard()

        let entries = currentSegment == 0 ? globalEntries : friendsEntries
        let emptyMessage = currentSegment == 0 ? "social.emptyGlobalLeaderboard".localized : "social.emptyFriendsLeaderboard".localized

        if entries.isEmpty {
            showEmptyState(emptyMessage)
            return
        }

        for entry in entries {
            let view = LeaderboardEntryView()
            view.configure(with: entry)
            contentStack.addArrangedSubview(view)
        }
    }

    // MARK: - Actions

    @objc private func segmentChanged() {
        currentSegment = segmentedControl.selectedSegmentIndex
        loadData()
    }

    @objc private func privacySwitchChanged() {
        let newValue = privacySwitch.isOn

        // Show confirmation if turning off
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
}
