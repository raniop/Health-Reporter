//
//  SocialHubViewController.swift
//  Health Reporter
//
//  מסך ראשי לחברים - טאבים: חברים, בקשות, חיפוש.
//

import UIKit
import FirebaseAuth

final class SocialHubViewController: UIViewController {

    // MARK: - Properties

    private var currentSegment: Int = 0
    private var friends: [Friend] = []
    private var pendingRequests: [FriendRequest] = []
    private var searchResults: [UserSearchResult] = []
    private var isSearching = false

    // MARK: - Recent Searches
    private let recentSearchesKey = "recentUserSearches"
    private let maxRecentSearches = 5

    private var recentSearches: [String] {
        get { UserDefaults.standard.stringArray(forKey: recentSearchesKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: recentSearchesKey) }
    }

    // MARK: - UI Elements

    private let segmentedControl: UISegmentedControl = {
        let items = [
            "social.friends".localized,
            "social.requests".localized,
            "social.search".localized
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

    private let searchBar: UISearchBar = {
        let sb = UISearchBar()
        sb.placeholder = "social.searchPlaceholder".localized
        sb.searchBarStyle = .minimal
        sb.translatesAutoresizingMaskIntoConstraints = false
        sb.isHidden = true
        return sb
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

    private var requestsBadgeLabel: UILabel?

    private let recentSearchesContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()

    private let recentSearchesTitleLabel: UILabel = {
        let l = UILabel()
        l.text = "social.recentSearches".localized
        l.font = .systemFont(ofSize: 14, weight: .medium)
        l.textColor = AIONDesign.textSecondary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let recentSearchesStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 8
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "social.title".localized
        view.backgroundColor = AIONDesign.background
        view.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        setupUI()
        setupNavigationBar()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
    }

    // MARK: - Setup

    private func setupUI() {
        view.addSubview(segmentedControl)
        view.addSubview(searchBar)
        view.addSubview(recentSearchesContainer)
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        view.addSubview(emptyStateLabel)
        view.addSubview(loadingIndicator)

        // Setup recent searches container
        recentSearchesContainer.addSubview(recentSearchesTitleLabel)
        recentSearchesContainer.addSubview(recentSearchesStack)

        searchBar.delegate = self

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AIONDesign.spacing),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AIONDesign.spacing),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AIONDesign.spacing),

            searchBar.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: AIONDesign.spacing),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AIONDesign.spacing),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AIONDesign.spacing),

            recentSearchesContainer.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: AIONDesign.spacing),
            recentSearchesContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AIONDesign.spacing),
            recentSearchesContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AIONDesign.spacing),

            recentSearchesTitleLabel.topAnchor.constraint(equalTo: recentSearchesContainer.topAnchor),
            recentSearchesTitleLabel.leadingAnchor.constraint(equalTo: recentSearchesContainer.leadingAnchor),
            recentSearchesTitleLabel.trailingAnchor.constraint(equalTo: recentSearchesContainer.trailingAnchor),

            recentSearchesStack.topAnchor.constraint(equalTo: recentSearchesTitleLabel.bottomAnchor, constant: 8),
            recentSearchesStack.leadingAnchor.constraint(equalTo: recentSearchesContainer.leadingAnchor),
            recentSearchesStack.trailingAnchor.constraint(equalTo: recentSearchesContainer.trailingAnchor),
            recentSearchesStack.bottomAnchor.constraint(equalTo: recentSearchesContainer.bottomAnchor),

            scrollView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: AIONDesign.spacing),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: AIONDesign.spacing),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -AIONDesign.spacing),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -AIONDesign.spacingLarge),

            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyStateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)

        // Tap gesture to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)

        // Adjust search bar visibility based on segment
        updateSearchBarVisibility()
    }

    @objc private func dismissKeyboard() {
        searchBar.resignFirstResponder()
    }

    private func setupNavigationBar() {
        let leaderboardButton = UIBarButtonItem(
            image: UIImage(systemName: "trophy"),
            style: .plain,
            target: self,
            action: #selector(leaderboardTapped)
        )
        leaderboardButton.tintColor = AIONDesign.accentPrimary
        navigationItem.leftBarButtonItem = leaderboardButton
    }

    // MARK: - Data Loading

    private func loadData() {
        switch currentSegment {
        case 0:
            loadFriends()
        case 1:
            loadRequests()
        case 2:
            // Search mode - don't auto-load
            break
        default:
            break
        }
    }

    private func loadFriends() {
        showLoading(true)
        FriendsFirestoreSync.fetchFriends { [weak self] friends in
            self?.friends = friends
            self?.showLoading(false)
            self?.updateFriendsUI()
        }
    }

    private func loadRequests() {
        showLoading(true)
        FriendsFirestoreSync.fetchPendingRequests { [weak self] requests in
            self?.pendingRequests = requests
            self?.showLoading(false)
            self?.updateRequestsUI()
            self?.updateRequestsBadge()
        }
    }

    // MARK: - UI Updates

    private func updateSearchBarVisibility() {
        searchBar.isHidden = currentSegment != 2
        if currentSegment == 2 {
            searchBar.becomeFirstResponder()
        } else {
            searchBar.resignFirstResponder()
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

    private func updateFriendsUI() {
        clearContent()

        if friends.isEmpty {
            showEmptyState("social.noFriends".localized)
            return
        }

        for friend in friends {
            let card = UserCardView()
            card.configure(with: friend)
            card.onActionTapped = { [weak self] in
                self?.confirmRemoveFriend(friend)
            }
            contentStack.addArrangedSubview(card)
        }
    }

    private func updateRequestsUI() {
        clearContent()

        if pendingRequests.isEmpty {
            showEmptyState("social.noRequests".localized)
            return
        }

        for request in pendingRequests {
            let card = FriendRequestView()
            card.configure(with: request)
            card.delegate = self
            contentStack.addArrangedSubview(card)
        }
    }

    private func updateSearchUI() {
        clearContent()

        // Show recent searches if no search text and not searching
        let searchText = searchBar.text?.trimmingCharacters(in: .whitespaces) ?? ""
        if searchText.isEmpty && !isSearching {
            updateRecentSearchesUI()
            recentSearchesContainer.isHidden = recentSearches.isEmpty
            scrollView.isHidden = true
            emptyStateLabel.isHidden = !recentSearches.isEmpty
            if recentSearches.isEmpty {
                showEmptyState("social.searchHint".localized)
            }
            return
        }

        recentSearchesContainer.isHidden = true
        scrollView.isHidden = false

        if searchResults.isEmpty && isSearching {
            showEmptyState("social.noResults".localized)
            return
        }

        if searchResults.isEmpty && !isSearching {
            showEmptyState("social.searchHint".localized)
            return
        }

        for (index, result) in searchResults.enumerated() {
            let card = UserCardView()
            card.configure(with: result)
            card.onActionTapped = { [weak self, index] in
                self?.sendFriendRequest(to: result, cardIndex: index)
            }
            contentStack.addArrangedSubview(card)
        }
    }

    private func updateRequestsBadge() {
        // Update tab bar badge
        FriendsFirestoreSync.fetchPendingRequestsCount { [weak self] count in
            if count > 0 {
                self?.tabBarItem.badgeValue = "\(count)"
            } else {
                self?.tabBarItem.badgeValue = nil
            }
        }
    }

    // MARK: - Recent Searches

    private func saveRecentSearch(_ query: String) {
        guard !query.isEmpty else { return }
        var searches = recentSearches
        searches.removeAll { $0.lowercased() == query.lowercased() }
        searches.insert(query, at: 0)
        if searches.count > maxRecentSearches {
            searches = Array(searches.prefix(maxRecentSearches))
        }
        recentSearches = searches
    }

    private func updateRecentSearchesUI() {
        // Clear existing items
        recentSearchesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for query in recentSearches {
            let button = createRecentSearchButton(query: query)
            recentSearchesStack.addArrangedSubview(button)
        }
    }

    private func createRecentSearchButton(query: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("🕐 \(query)", for: .normal)
        button.setTitleColor(AIONDesign.textPrimary, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16)
        button.contentHorizontalAlignment = LocalizationManager.shared.currentLanguage.isRTL ? .right : .left
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true

        button.addAction(UIAction { [weak self] _ in
            self?.searchBar.text = query
            self?.performSearch()
        }, for: .touchUpInside)

        return button
    }

    // MARK: - Actions

    @objc private func segmentChanged() {
        currentSegment = segmentedControl.selectedSegmentIndex
        updateSearchBarVisibility()
        searchResults = []
        isSearching = false
        loadData()
    }

    @objc private func leaderboardTapped() {
        let vc = LeaderboardViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    private func confirmRemoveFriend(_ friend: Friend) {
        let message = String(format: "social.confirmRemove".localized, friend.displayName)
        let alert = UIAlertController(title: "social.removeFriend".localized, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "cancel".localized, style: .cancel))
        alert.addAction(UIAlertAction(title: "social.remove".localized, style: .destructive) { [weak self] _ in
            self?.removeFriend(friend)
        })
        present(alert, animated: true)
    }

    private func removeFriend(_ friend: Friend) {
        FriendsFirestoreSync.removeFriend(friendUid: friend.uid) { [weak self] error in
            if let error = error {
                self?.showError(error.localizedDescription)
            } else {
                self?.loadFriends()
            }
        }
    }

    private func sendFriendRequest(to user: UserSearchResult, cardIndex: Int) {
        guard let card = contentStack.arrangedSubviews[safe: cardIndex] as? UserCardView else { return }
        card.setLoading(true)

        FriendsFirestoreSync.sendFriendRequest(toUid: user.uid) { [weak self] error in
            card.setLoading(false)
            if let error = error {
                self?.showError(error.localizedDescription)
            } else {
                // Update the result to show pending
                if cardIndex < (self?.searchResults.count ?? 0) {
                    self?.searchResults[cardIndex].hasPendingRequest = true
                    self?.searchResults[cardIndex].requestSentByMe = true
                    card.configure(with: self?.searchResults[cardIndex] ?? user)
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

// MARK: - UISearchBarDelegate

extension SocialHubViewController: UISearchBarDelegate {

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        performSearch()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // Debounce search
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(performSearch), object: nil)
        perform(#selector(performSearch), with: nil, afterDelay: 0.5)
    }

    @objc private func performSearch() {
        guard let query = searchBar.text?.trimmingCharacters(in: .whitespaces),
              query.count >= 2 else {
            searchResults = []
            isSearching = false
            updateSearchUI()
            return
        }

        isSearching = true
        showLoading(true)

        FriendsFirestoreSync.searchUsers(query: query) { [weak self] results in
            self?.searchResults = results
            self?.showLoading(false)
            self?.updateSearchUI()
            // Save to recent searches if we got results
            if !results.isEmpty {
                self?.saveRecentSearch(query)
            }
        }
    }
}

// MARK: - FriendRequestViewDelegate

extension SocialHubViewController: FriendRequestViewDelegate {

    func friendRequestView(_ view: FriendRequestView, didAcceptRequest request: FriendRequest) {
        FriendsFirestoreSync.acceptFriendRequest(requestId: request.id) { [weak self] error in
            if let error = error {
                self?.showError(error.localizedDescription)
            } else {
                self?.loadRequests()
            }
        }
    }

    func friendRequestView(_ view: FriendRequestView, didDeclineRequest request: FriendRequest) {
        FriendsFirestoreSync.declineFriendRequest(requestId: request.id) { [weak self] error in
            if let error = error {
                self?.showError(error.localizedDescription)
            } else {
                self?.loadRequests()
            }
        }
    }
}

// MARK: - Array Safe Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
