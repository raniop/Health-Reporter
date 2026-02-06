//
//  UserSearchViewController.swift
//  Health Reporter
//
//  Search screen for finding and following users.
//  Pushed from the Social tab's navigation bar search button.
//

import UIKit

final class UserSearchViewController: UIViewController {

    // MARK: - Properties

    private var searchResults: [UserSearchResult] = []
    private var isSearching = false

    // MARK: - Recently Viewed

    private let recentlyViewedKey = "recentlyViewedUsers"
    private let maxRecentlyViewed = 5

    private var recentlyViewedUsers: [[String: String]] {
        get { UserDefaults.standard.array(forKey: recentlyViewedKey) as? [[String: String]] ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: recentlyViewedKey) }
    }

    // MARK: - UI Elements

    private let searchBar: UISearchBar = {
        let sb = UISearchBar()
        sb.placeholder = "social.searchPlaceholder".localized
        sb.searchBarStyle = .minimal
        sb.backgroundImage = UIImage()
        sb.translatesAutoresizingMaskIntoConstraints = false
        if let textField = sb.value(forKey: "searchField") as? UITextField {
            textField.textColor = AIONDesign.textPrimary
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

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.alwaysBounceVertical = true
        sv.keyboardDismissMode = .interactive
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

    // MARK: - Recently Viewed UI

    private let recentlyViewedContainer: GlassMorphismView = {
        let v = GlassMorphismView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        v.cornerRadius = AIONDesign.cornerRadius
        return v
    }()

    private let recentlyViewedTitleLabel: UILabel = {
        let l = UILabel()
        l.text = "social.recentlyViewed".localized
        l.font = .systemFont(ofSize: 14, weight: .semibold)
        l.textColor = AIONDesign.textSecondary
        l.textAlignment = LocalizationManager.shared.textAlignment
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let recentlyViewedStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 4
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    // MARK: - Empty State

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

    // MARK: - Loading

    private let loadingIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .large)
        ai.hidesWhenStopped = true
        ai.color = AIONDesign.accentPrimary
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "social.searchUsers".localized
        view.backgroundColor = AIONDesign.background
        view.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute

        setupUI()
        logAnalytics()
        updateRecentlyViewedUI()
        showInitialState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh recently viewed to update follow status after returning from profile
        let searchText = searchBar.text?.trimmingCharacters(in: .whitespaces) ?? ""
        if searchText.isEmpty {
            updateRecentlyViewedUI()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        searchBar.becomeFirstResponder()
    }

    // MARK: - Analytics

    private func logAnalytics() {
        // Use .userSearch if the enum case exists, otherwise fall back to a raw string
        if let screen = AnalyticsScreen(rawValue: "User_Search") {
            AnalyticsService.shared.logScreenView(screen)
        } else {
            AnalyticsService.shared.logScreenView(.socialHub, additionalParams: ["sub_screen": "user_search"])
        }
    }

    // MARK: - Setup

    private func setupUI() {
        searchBar.delegate = self

        view.addSubview(searchBar)
        view.addSubview(recentlyViewedContainer)
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        view.addSubview(emptyStateView)
        view.addSubview(loadingIndicator)

        emptyStateView.addSubview(emptyStateIcon)
        emptyStateView.addSubview(emptyStateLabel)

        recentlyViewedContainer.addSubview(recentlyViewedTitleLabel)
        recentlyViewedContainer.addSubview(recentlyViewedStack)

        NSLayoutConstraint.activate([
            // Search bar
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AIONDesign.spacingSmall),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AIONDesign.spacingSmall),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AIONDesign.spacingSmall),

            // Recently viewed container
            recentlyViewedContainer.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: AIONDesign.spacing),
            recentlyViewedContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AIONDesign.spacing),
            recentlyViewedContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AIONDesign.spacing),

            recentlyViewedTitleLabel.topAnchor.constraint(equalTo: recentlyViewedContainer.topAnchor, constant: AIONDesign.spacing),
            recentlyViewedTitleLabel.leadingAnchor.constraint(equalTo: recentlyViewedContainer.leadingAnchor, constant: AIONDesign.spacing),
            recentlyViewedTitleLabel.trailingAnchor.constraint(equalTo: recentlyViewedContainer.trailingAnchor, constant: -AIONDesign.spacing),

            recentlyViewedStack.topAnchor.constraint(equalTo: recentlyViewedTitleLabel.bottomAnchor, constant: AIONDesign.spacingSmall),
            recentlyViewedStack.leadingAnchor.constraint(equalTo: recentlyViewedContainer.leadingAnchor, constant: AIONDesign.spacing),
            recentlyViewedStack.trailingAnchor.constraint(equalTo: recentlyViewedContainer.trailingAnchor, constant: -AIONDesign.spacing),
            recentlyViewedStack.bottomAnchor.constraint(equalTo: recentlyViewedContainer.bottomAnchor, constant: -AIONDesign.spacing),

            // Scroll view (for search results)
            scrollView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: AIONDesign.spacing),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: AIONDesign.spacing),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: AIONDesign.spacing),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -AIONDesign.spacing),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -AIONDesign.spacingLarge),

            // Empty state
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

            // Loading
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        // Tap gesture to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }

    @objc private func dismissKeyboard() {
        searchBar.resignFirstResponder()
    }

    // MARK: - State Management

    private func showInitialState() {
        let hasRecent = !recentlyViewedUsers.isEmpty
        recentlyViewedContainer.isHidden = !hasRecent
        recentlyViewedContainer.alpha = hasRecent ? 1 : 0
        scrollView.isHidden = true
        emptyStateView.isHidden = hasRecent

        if !hasRecent {
            showEmptyState("social.searchHint".localized, icon: "magnifyingglass")
        }
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

        // Spring entrance animation
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

    private func clearContent() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        emptyStateView.isHidden = true
    }

    // MARK: - Search Results UI

    private func updateSearchResultsUI() {
        clearContent()

        let searchText = searchBar.text?.trimmingCharacters(in: .whitespaces) ?? ""

        // Empty search field: show recently viewed
        if searchText.isEmpty && !isSearching {
            updateRecentlyViewedUI()
            showInitialState()
            return
        }

        // Hide recently viewed, show scroll view
        recentlyViewedContainer.isHidden = true
        recentlyViewedContainer.alpha = 0
        scrollView.isHidden = false

        // No results after a search
        if searchResults.isEmpty && isSearching {
            showEmptyState("social.noResults".localized, icon: "person.slash")
            return
        }

        // No results yet (not searched)
        if searchResults.isEmpty && !isSearching {
            showEmptyState("social.searchHint".localized, icon: "magnifyingglass")
            return
        }

        // Display result cards
        for (index, result) in searchResults.enumerated() {
            let card = UserCardView()
            card.configure(with: result)

            card.onActionTapped = { [weak self] in
                self?.followUser(result, cardIndex: index)
            }

            card.onCardTapped = { [weak self] in
                self?.saveRecentlyViewedUser(
                    uid: result.uid,
                    displayName: result.displayName,
                    photoURL: result.photoURL
                )
                self?.showUserProfile(uid: result.uid)
            }

            contentStack.addArrangedSubview(card)
        }

        animateCardsEntrance()
    }

    // MARK: - Card Entrance Animation

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

    // MARK: - Follow User

    private func followUser(_ user: UserSearchResult, cardIndex: Int) {
        guard let card = contentStack.arrangedSubviews[safe: cardIndex] as? UserCardView else { return }
        card.setLoading(true)

        FollowFirestoreSync.followUser(targetUid: user.uid) { [weak self] error in
            guard let self = self else { return }
            card.setLoading(false)

            if let error = error {
                self.showError(error.localizedDescription)
            } else {
                // Update local state
                if cardIndex < self.searchResults.count {
                    self.searchResults[cardIndex].hasPendingRequest = true
                    self.searchResults[cardIndex].requestSentByMe = true
                    card.configure(with: self.searchResults[cardIndex])
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    // MARK: - Recently Viewed

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

    private func updateRecentlyViewedUI() {
        recentlyViewedStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let users = recentlyViewedUsers
        guard !users.isEmpty else { return }

        // Build rows first, then update follow status asynchronously
        var rows: [(UIView, String)] = []
        for user in users {
            guard let uid = user["uid"], let displayName = user["displayName"] else { continue }
            let photoURL = user["photoURL"]
            let row = createRecentUserRow(uid: uid, displayName: displayName, photoURL: photoURL)
            recentlyViewedStack.addArrangedSubview(row)
            rows.append((row, uid))
        }

        // Fetch following list and update status labels
        FollowFirestoreSync.fetchFollowing { [weak self] following in
            guard let self = self else { return }
            let followingUids = Set(following.map { $0.uid })
            for (row, uid) in rows {
                if let statusLabel = row.viewWithTag(1001) as? UILabel {
                    if followingUids.contains(uid) {
                        statusLabel.text = "social.following".localized
                        statusLabel.textColor = AIONDesign.accentSuccess
                    }
                }
            }
        }
    }

    private func createRecentUserRow(uid: String, displayName: String, photoURL: String?) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL
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
        nameLabel.textAlignment = isRTL ? .right : .left

        let statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = AIONDesign.textTertiary
        statusLabel.textAlignment = isRTL ? .right : .left
        statusLabel.tag = 1001

        container.addSubview(avatarImageView)
        container.addSubview(nameLabel)
        container.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 48),

            avatarImageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: avatarSize),
            avatarImageView.heightAnchor.constraint(equalToConstant: avatarSize),

            nameLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            statusLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
        ])

        if isRTL {
            NSLayoutConstraint.activate([
                avatarImageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                nameLabel.trailingAnchor.constraint(equalTo: avatarImageView.leadingAnchor, constant: -12),
                nameLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                statusLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
                statusLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            ])
        } else {
            NSLayoutConstraint.activate([
                avatarImageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                nameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
                nameLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                statusLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
                statusLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            ])
        }

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(recentUserTapped(_:)))
        container.addGestureRecognizer(tapGesture)
        container.accessibilityIdentifier = uid
        container.isUserInteractionEnabled = true

        return container
    }

    @objc private func recentUserTapped(_ gesture: UITapGestureRecognizer) {
        guard let container = gesture.view, let uid = container.accessibilityIdentifier else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showUserProfile(uid: uid)
    }

    // MARK: - Navigation

    private func showUserProfile(uid: String) {
        let vc = UserProfileViewController(userUid: uid)
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Error Handling

    private func showError(_ message: String) {
        let alert = UIAlertController(
            title: "error".localized,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "ok".localized, style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UISearchBarDelegate

extension UserSearchViewController: UISearchBarDelegate {

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
            updateSearchResultsUI()
            return
        }

        isSearching = true
        showLoading(true)

        FollowFirestoreSync.searchUsers(query: query) { [weak self] results in
            guard let self = self else { return }
            self.searchResults = results
            self.showLoading(false)
            self.updateSearchResultsUI()
        }
    }
}

// MARK: - Array Safe Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
