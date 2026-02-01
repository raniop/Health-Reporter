//
//  SocialHubViewController.swift
//  Health Reporter
//
//  מסך ראשי לחברים - טאבים: חברים, בקשות, חיפוש. עיצוב מודרני עם Glass Morphism.
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

    // Dynamic constraint for scrollView top
    private var scrollViewTopConstraint: NSLayoutConstraint?

    // MARK: - Recently Viewed Users
    private let recentlyViewedKey = "recentlyViewedUsers"
    private let maxRecentlyViewed = 5

    private var recentlyViewedUsers: [[String: String]] {
        get { UserDefaults.standard.array(forKey: recentlyViewedKey) as? [[String: String]] ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: recentlyViewedKey) }
    }

    // MARK: - UI Elements

    private lazy var tabBarControl: AnimatedTabBarControl = {
        let control = AnimatedTabBarControl(items: [
            .init(title: "social.friends".localized, icon: "person.2.fill"),
            .init(title: "social.requests".localized, icon: "person.badge.plus"),
            .init(title: "social.search".localized, icon: "magnifyingglass")
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

    private let searchBar: UISearchBar = {
        let sb = UISearchBar()
        sb.placeholder = "social.searchPlaceholder".localized
        sb.searchBarStyle = .minimal
        sb.backgroundImage = UIImage()
        sb.translatesAutoresizingMaskIntoConstraints = false
        sb.isHidden = true
        return sb
    }()

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

    private let recentSearchesContainer: GlassMorphismView = {
        let v = GlassMorphismView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        v.cornerRadius = AIONDesign.cornerRadius
        return v
    }()

    private let recentSearchesTitleLabel: UILabel = {
        let l = UILabel()
        l.text = "social.recentlyViewed".localized
        l.font = .systemFont(ofSize: 14, weight: .semibold)
        l.textColor = AIONDesign.textSecondary
        l.textAlignment = LocalizationManager.shared.textAlignment
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let recentSearchesStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 4
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let refreshControl = UIRefreshControl()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "social.title".localized
        view.backgroundColor = AIONDesign.background
        view.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        setupUI()
        setupNavigationBar()
        setupRefreshControl()

        // Analytics: Log screen view
        AnalyticsService.shared.logScreenView(.socialHub)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
    }

    // MARK: - Setup

    private func setupUI() {
        view.addSubview(tabBarControl)
        view.addSubview(searchBar)
        view.addSubview(recentSearchesContainer)
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        view.addSubview(emptyStateView)
        view.addSubview(loadingIndicator)

        // Setup empty state view
        emptyStateView.addSubview(emptyStateIcon)
        emptyStateView.addSubview(emptyStateLabel)

        // Setup recent searches container
        recentSearchesContainer.addSubview(recentSearchesTitleLabel)
        recentSearchesContainer.addSubview(recentSearchesStack)

        searchBar.delegate = self

        NSLayoutConstraint.activate([
            tabBarControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AIONDesign.spacing),
            tabBarControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AIONDesign.spacing),
            tabBarControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AIONDesign.spacing),
            tabBarControl.heightAnchor.constraint(equalToConstant: 48),

            searchBar.topAnchor.constraint(equalTo: tabBarControl.bottomAnchor, constant: AIONDesign.spacing),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AIONDesign.spacingSmall),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AIONDesign.spacingSmall),

            recentSearchesContainer.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: AIONDesign.spacing),
            recentSearchesContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AIONDesign.spacing),
            recentSearchesContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AIONDesign.spacing),

            recentSearchesTitleLabel.topAnchor.constraint(equalTo: recentSearchesContainer.topAnchor, constant: AIONDesign.spacing),
            recentSearchesTitleLabel.leadingAnchor.constraint(equalTo: recentSearchesContainer.leadingAnchor, constant: AIONDesign.spacing),
            recentSearchesTitleLabel.trailingAnchor.constraint(equalTo: recentSearchesContainer.trailingAnchor, constant: -AIONDesign.spacing),

            recentSearchesStack.topAnchor.constraint(equalTo: recentSearchesTitleLabel.bottomAnchor, constant: AIONDesign.spacingSmall),
            recentSearchesStack.leadingAnchor.constraint(equalTo: recentSearchesContainer.leadingAnchor, constant: AIONDesign.spacing),
            recentSearchesStack.trailingAnchor.constraint(equalTo: recentSearchesContainer.trailingAnchor, constant: -AIONDesign.spacing),
            recentSearchesStack.bottomAnchor.constraint(equalTo: recentSearchesContainer.bottomAnchor, constant: -AIONDesign.spacing),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: AIONDesign.spacing),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: AIONDesign.spacing),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -AIONDesign.spacing),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -AIONDesign.spacingLarge),

            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 40),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            emptyStateIcon.topAnchor.constraint(equalTo: emptyStateView.topAnchor),
            emptyStateIcon.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            emptyStateIcon.widthAnchor.constraint(equalToConstant: 60),
            emptyStateIcon.heightAnchor.constraint(equalToConstant: 60),

            emptyStateLabel.topAnchor.constraint(equalTo: emptyStateIcon.bottomAnchor, constant: AIONDesign.spacing),
            emptyStateLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor),
            emptyStateLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor),
            emptyStateLabel.bottomAnchor.constraint(equalTo: emptyStateView.bottomAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        // Set initial scrollView top constraint (will be updated based on search visibility)
        scrollViewTopConstraint = scrollView.topAnchor.constraint(equalTo: tabBarControl.bottomAnchor, constant: AIONDesign.spacing)
        scrollViewTopConstraint?.isActive = true

        // Tap gesture to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)

        updateSearchBarVisibility()
    }

    private func setupNavigationBar() {
        let leaderboardButton = UIBarButtonItem(
            image: UIImage(systemName: "trophy.fill"),
            style: .plain,
            target: self,
            action: #selector(leaderboardTapped)
        )
        leaderboardButton.tintColor = AIONDesign.accentPrimary
        navigationItem.leftBarButtonItem = leaderboardButton
    }

    private func setupRefreshControl() {
        refreshControl.tintColor = AIONDesign.accentPrimary
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        scrollView.refreshControl = refreshControl
    }

    @objc private func handleRefresh() {
        loadData()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refreshControl.endRefreshing()
        }
    }

    @objc private func dismissKeyboard() {
        searchBar.resignFirstResponder()
    }

    // MARK: - Data Loading

    private func loadData() {
        switch currentSegment {
        case 0:
            loadFriends()
        case 1:
            loadRequests()
        case 2:
            updateSearchUI()
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
            self?.animateCardsEntrance()
        }
    }

    private func loadRequests() {
        showLoading(true)
        FriendsFirestoreSync.fetchPendingRequests { [weak self] requests in
            self?.pendingRequests = requests
            self?.showLoading(false)
            self?.updateRequestsUI()
            self?.updateRequestsBadge()
            self?.animateCardsEntrance()
        }
    }

    // MARK: - UI Updates

    private func updateSearchBarVisibility() {
        let isSearch = currentSegment == 2

        // Update scrollView top constraint based on search visibility
        scrollViewTopConstraint?.isActive = false
        if isSearch {
            scrollViewTopConstraint = scrollView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: AIONDesign.spacing)
        } else {
            scrollViewTopConstraint = scrollView.topAnchor.constraint(equalTo: tabBarControl.bottomAnchor, constant: AIONDesign.spacing)
        }
        scrollViewTopConstraint?.isActive = true

        UIView.animate(withDuration: AIONDesign.animationMedium) {
            self.searchBar.isHidden = !isSearch
            self.searchBar.alpha = isSearch ? 1 : 0

            // Hide recent searches when not in search tab
            if !isSearch {
                self.recentSearchesContainer.isHidden = true
                self.recentSearchesContainer.alpha = 0
                // Make sure scrollView is visible when leaving search tab
                self.scrollView.isHidden = false
            }

            self.view.layoutIfNeeded()
        }

        if isSearch {
            searchBar.becomeFirstResponder()
        } else {
            searchBar.resignFirstResponder()
            searchBar.text = ""
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

        // Animate entrance
        emptyStateView.alpha = 0
        emptyStateView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        UIView.animate(
            withDuration: AIONDesign.animationMedium,
            delay: 0,
            usingSpringWithDamping: AIONDesign.springDamping,
            initialSpringVelocity: AIONDesign.springVelocity
        ) {
            self.emptyStateView.alpha = 1
            self.emptyStateView.transform = .identity
        }
    }

    private func updateFriendsUI() {
        clearContent()

        if friends.isEmpty {
            showEmptyState("social.noFriends".localized, icon: "person.2.slash")
            return
        }

        for friend in friends {
            let card = UserCardView()
            card.configure(with: friend)
            card.onActionTapped = { [weak self] in
                self?.confirmRemoveFriend(friend)
            }
            card.onCardTapped = { [weak self] in
                self?.showUserProfile(uid: friend.uid)
            }
            contentStack.addArrangedSubview(card)
        }
    }

    private func updateRequestsUI() {
        clearContent()

        if pendingRequests.isEmpty {
            showEmptyState("social.noRequests".localized, icon: "person.badge.clock")
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

        let searchText = searchBar.text?.trimmingCharacters(in: .whitespaces) ?? ""
        if searchText.isEmpty && !isSearching {
            updateRecentSearchesUI()
            let hasRecentlyViewed = !recentlyViewedUsers.isEmpty
            recentSearchesContainer.isHidden = !hasRecentlyViewed
            recentSearchesContainer.alpha = hasRecentlyViewed ? 1 : 0
            scrollView.isHidden = true
            emptyStateView.isHidden = hasRecentlyViewed
            if !hasRecentlyViewed {
                showEmptyState("social.searchHint".localized, icon: "magnifyingglass")
            }
            return
        }

        recentSearchesContainer.isHidden = true
        recentSearchesContainer.alpha = 0
        scrollView.isHidden = false

        if searchResults.isEmpty && isSearching {
            showEmptyState("social.noResults".localized, icon: "person.slash")
            return
        }

        if searchResults.isEmpty && !isSearching {
            showEmptyState("social.searchHint".localized, icon: "magnifyingglass")
            return
        }

        for (index, result) in searchResults.enumerated() {
            let card = UserCardView()
            card.configure(with: result)
            card.onActionTapped = { [weak self, index] in
                self?.sendFriendRequest(to: result, cardIndex: index)
            }
            card.onCardTapped = { [weak self] in
                self?.saveRecentlyViewedUser(uid: result.uid, displayName: result.displayName, photoURL: result.photoURL)
                self?.showUserProfile(uid: result.uid)
            }
            contentStack.addArrangedSubview(card)
        }

        animateCardsEntrance()
    }

    private func animateCardsEntrance() {
        for (index, view) in contentStack.arrangedSubviews.enumerated() {
            view.alpha = 0
            view.transform = CGAffineTransform(translationX: 0, y: 20)

            UIView.animate(
                withDuration: AIONDesign.animationMedium,
                delay: Double(index) * 0.06,
                usingSpringWithDamping: AIONDesign.springDamping,
                initialSpringVelocity: AIONDesign.springVelocity
            ) {
                view.alpha = 1
                view.transform = .identity
            }
        }
    }

    private func updateRequestsBadge() {
        FriendsFirestoreSync.fetchPendingRequestsCount { [weak self] count in
            if count > 0 {
                self?.tabBarItem.badgeValue = "\(count)"
            } else {
                self?.tabBarItem.badgeValue = nil
            }
        }
    }

    // MARK: - Recently Viewed Users

    private func saveRecentlyViewedUser(uid: String, displayName: String, photoURL: String?) {
        var users = recentlyViewedUsers
        users.removeAll { $0["uid"] == uid }
        var userData: [String: String] = ["uid": uid, "displayName": displayName]
        if let photoURL = photoURL {
            userData["photoURL"] = photoURL
        }
        users.insert(userData, at: 0)
        if users.count > maxRecentlyViewed {
            users = Array(users.prefix(maxRecentlyViewed))
        }
        recentlyViewedUsers = users
    }

    private func updateRecentSearchesUI() {
        recentSearchesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for user in recentlyViewedUsers {
            guard let uid = user["uid"], let displayName = user["displayName"] else { continue }
            let photoURL = user["photoURL"]
            let button = createRecentUserButton(uid: uid, displayName: displayName, photoURL: photoURL)
            recentSearchesStack.addArrangedSubview(button)
        }
    }

    private func createRecentUserButton(uid: String, displayName: String, photoURL: String?) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let avatarSize: CGFloat = 36
        let avatarImageView = UIImageView()
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.layer.cornerRadius = avatarSize / 2
        avatarImageView.backgroundColor = AIONDesign.surfaceElevated

        if let photoURL = photoURL, let url = URL(string: photoURL) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        avatarImageView.image = image
                    }
                }
            }.resume()
        } else {
            avatarImageView.image = UIImage(systemName: "person.circle.fill")
            avatarImageView.tintColor = AIONDesign.textTertiary
        }

        let nameLabel = UILabel()
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.text = displayName
        nameLabel.font = .systemFont(ofSize: 16, weight: .medium)
        nameLabel.textColor = AIONDesign.textPrimary
        nameLabel.textAlignment = LocalizationManager.shared.currentLanguage.isRTL ? .right : .left

        container.addSubview(avatarImageView)
        container.addSubview(nameLabel)

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 48),

            avatarImageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: avatarSize),
            avatarImageView.heightAnchor.constraint(equalToConstant: avatarSize),

            nameLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        // RTL/LTR specific constraints
        if isRTL {
            NSLayoutConstraint.activate([
                avatarImageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                nameLabel.trailingAnchor.constraint(equalTo: avatarImageView.leadingAnchor, constant: -12),
                nameLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            ])
        } else {
            NSLayoutConstraint.activate([
                avatarImageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                nameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
                nameLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            ])
        }

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(recentUserTapped(_:)))
        container.addGestureRecognizer(tapGesture)
        container.tag = uid.hashValue
        container.accessibilityIdentifier = uid
        container.isUserInteractionEnabled = true

        return container
    }

    @objc private func recentUserTapped(_ gesture: UITapGestureRecognizer) {
        guard let container = gesture.view, let uid = container.accessibilityIdentifier else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showUserProfile(uid: uid)
    }

    // MARK: - Public Methods

    func switchToRequestsSegment() {
        tabBarControl.selectedIndex = 1
    }

    // MARK: - Actions

    private func tabChanged(to index: Int) {
        currentSegment = index
        updateSearchBarVisibility()
        searchResults = []
        isSearching = false
        loadData()

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @objc private func leaderboardTapped() {
        let vc = LeaderboardViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    private func showUserProfile(uid: String) {
        let vc = UserProfileViewController(userUid: uid)
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
                if cardIndex < (self?.searchResults.count ?? 0) {
                    self?.searchResults[cardIndex].hasPendingRequest = true
                    self?.searchResults[cardIndex].requestSentByMe = true
                    card.configure(with: self?.searchResults[cardIndex] ?? user)
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)

                // Analytics: Log friend request sent
                AnalyticsService.shared.logFriendRequestSent(toUserId: user.uid)
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
        }
    }
}

// MARK: - FriendRequestViewDelegate

extension SocialHubViewController: FriendRequestViewDelegate {

    func friendRequestView(_ view: FriendRequestView, didAcceptRequest request: FriendRequest) {
        // Optimistic update
        if let index = pendingRequests.firstIndex(where: { $0.id == request.id }) {
            pendingRequests.remove(at: index)

            // Animate removal
            UIView.animate(withDuration: AIONDesign.animationMedium, animations: {
                view.alpha = 0
                view.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            }) { _ in
                self.updateRequestsUI()
                self.updateRequestsBadge()
                self.notifyTabBarToUpdateBadge()
            }
        }

        FriendsFirestoreSync.acceptFriendRequest(requestId: request.id) { [weak self] error in
            if let error = error {
                self?.showError(error.localizedDescription)
                self?.loadRequests()
            }
        }
    }

    func friendRequestView(_ view: FriendRequestView, didDeclineRequest request: FriendRequest) {
        // Optimistic update
        if let index = pendingRequests.firstIndex(where: { $0.id == request.id }) {
            pendingRequests.remove(at: index)

            UIView.animate(withDuration: AIONDesign.animationMedium, animations: {
                view.alpha = 0
                view.transform = CGAffineTransform(translationX: -100, y: 0)
            }) { _ in
                self.updateRequestsUI()
                self.updateRequestsBadge()
                self.notifyTabBarToUpdateBadge()
            }
        }

        FriendsFirestoreSync.declineFriendRequest(requestId: request.id) { [weak self] error in
            if let error = error {
                self?.showError(error.localizedDescription)
                self?.loadRequests()
            }
        }
    }

    private func notifyTabBarToUpdateBadge() {
        if let tabBarController = self.tabBarController as? MainTabBarController {
            tabBarController.updateSocialTabBadge()
        }
    }
}

// MARK: - Array Safe Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
