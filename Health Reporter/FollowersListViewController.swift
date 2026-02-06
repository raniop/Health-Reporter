//
//  FollowersListViewController.swift
//  Health Reporter
//
//  Followers / Following list screen with 2026 aesthetic.
//  Clean rounded search, card shadows, spring animations, RTL support.
//

import UIKit

final class FollowersListViewController: UIViewController {

    // MARK: - Mode

    enum Mode {
        case followers
        case following
    }

    // MARK: - Properties

    private let mode: Mode
    private let targetUid: String?
    private var allRelations: [FollowRelation] = []
    private var filteredRelations: [FollowRelation] = []
    private var cardViews: [UserCardView] = []

    // MARK: - UI Elements

    private let searchContainerView: UIView = {
        let v = UIView()
        v.backgroundColor = AIONDesign.surface
        v.layer.cornerRadius = AIONDesign.cornerRadius
        v.translatesAutoresizingMaskIntoConstraints = false
        v.applyShadow(.small)
        return v
    }()

    private let searchBar: UISearchBar = {
        let sb = UISearchBar()
        sb.searchBarStyle = .minimal
        sb.placeholder = "social.searchPlaceholder".localized
        sb.translatesAutoresizingMaskIntoConstraints = false
        return sb
    }()

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.alwaysBounceVertical = true
        sv.showsVerticalScrollIndicator = false
        sv.keyboardDismissMode = .onDrag
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = AIONDesign.spacing
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let emptyStateContainer: UIView = {
        let v = UIView()
        v.isHidden = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let emptyIconView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 48, weight: .light)
        let iv = UIImageView(image: UIImage(systemName: "person.2.slash", withConfiguration: config))
        iv.tintColor = AIONDesign.textTertiary
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let emptyLabel: UILabel = {
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

    // MARK: - Init

    init(mode: Mode, targetUid: String? = nil) {
        self.mode = mode
        self.targetUid = targetUid
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        setupUI()
        setupRTL()
        fetchData()
    }

    // MARK: - Navigation

    private func setupNavigation() {
        switch mode {
        case .followers:
            title = "social.followers".localized
        case .following:
            title = "social.following".localized
        }

        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = AIONDesign.background
        appearance.titleTextAttributes = [.foregroundColor: AIONDesign.textPrimary]
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
    }

    // MARK: - Setup UI

    private func setupUI() {
        view.backgroundColor = AIONDesign.background

        searchBar.delegate = self

        // Search container
        view.addSubview(searchContainerView)
        searchContainerView.addSubview(searchBar)

        view.addSubview(scrollView)
        view.addSubview(emptyStateContainer)
        view.addSubview(loadingIndicator)

        scrollView.addSubview(stackView)

        // Empty state
        emptyStateContainer.addSubview(emptyIconView)
        emptyStateContainer.addSubview(emptyLabel)

        emptyLabel.text = mode == .followers
            ? "social.noFollowers".localized
            : "social.noFollowing".localized

        NSLayoutConstraint.activate([
            // Search container
            searchContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AIONDesign.spacing),
            searchContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AIONDesign.spacingLarge),
            searchContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AIONDesign.spacingLarge),

            // Search bar inside container
            searchBar.topAnchor.constraint(equalTo: searchContainerView.topAnchor, constant: 2),
            searchBar.leadingAnchor.constraint(equalTo: searchContainerView.leadingAnchor, constant: 4),
            searchBar.trailingAnchor.constraint(equalTo: searchContainerView.trailingAnchor, constant: -4),
            searchBar.bottomAnchor.constraint(equalTo: searchContainerView.bottomAnchor, constant: -2),

            // Scroll view
            scrollView.topAnchor.constraint(equalTo: searchContainerView.bottomAnchor, constant: AIONDesign.spacing),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Stack view
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: AIONDesign.spacingSmall),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: AIONDesign.spacingLarge),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -AIONDesign.spacingLarge),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -AIONDesign.spacingLarge),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -(AIONDesign.spacingLarge * 2)),

            // Empty state
            emptyStateContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateContainer.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: AIONDesign.spacingLarge),
            emptyStateContainer.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -AIONDesign.spacingLarge),

            emptyIconView.topAnchor.constraint(equalTo: emptyStateContainer.topAnchor),
            emptyIconView.centerXAnchor.constraint(equalTo: emptyStateContainer.centerXAnchor),
            emptyIconView.widthAnchor.constraint(equalToConstant: 56),
            emptyIconView.heightAnchor.constraint(equalToConstant: 56),

            emptyLabel.topAnchor.constraint(equalTo: emptyIconView.bottomAnchor, constant: AIONDesign.spacing),
            emptyLabel.leadingAnchor.constraint(equalTo: emptyStateContainer.leadingAnchor),
            emptyLabel.trailingAnchor.constraint(equalTo: emptyStateContainer.trailingAnchor),
            emptyLabel.bottomAnchor.constraint(equalTo: emptyStateContainer.bottomAnchor),

            // Loading indicator
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    // MARK: - RTL

    private func setupRTL() {
        let semanticAttr = LocalizationManager.shared.semanticContentAttribute
        view.semanticContentAttribute = semanticAttr
        scrollView.semanticContentAttribute = semanticAttr
        stackView.semanticContentAttribute = semanticAttr
        searchBar.semanticContentAttribute = semanticAttr
        searchContainerView.semanticContentAttribute = semanticAttr
        emptyLabel.textAlignment = .center
    }

    // MARK: - Fetch Data

    private func fetchData() {
        loadingIndicator.startAnimating()
        scrollView.isHidden = true
        emptyStateContainer.isHidden = true

        let completion: ([FollowRelation]) -> Void = { [weak self] relations in
            guard let self = self else { return }
            self.loadingIndicator.stopAnimating()
            self.allRelations = relations
            self.filteredRelations = relations
            self.rebuildCards(animated: true)
        }

        switch mode {
        case .followers:
            FollowFirestoreSync.fetchFollowers(for: targetUid, completion: completion)
        case .following:
            FollowFirestoreSync.fetchFollowing(for: targetUid, completion: completion)
        }
    }

    // MARK: - Build Cards

    private func rebuildCards(animated: Bool) {
        // Remove existing cards
        for card in cardViews {
            stackView.removeArrangedSubview(card)
            card.removeFromSuperview()
        }
        cardViews.removeAll()

        guard !filteredRelations.isEmpty else {
            scrollView.isHidden = true
            emptyStateContainer.isHidden = false

            if animated {
                emptyStateContainer.alpha = 0
                emptyStateContainer.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
                UIView.animate(
                    withDuration: AIONDesign.animationMedium,
                    delay: 0,
                    usingSpringWithDamping: AIONDesign.springDamping,
                    initialSpringVelocity: AIONDesign.springVelocity
                ) {
                    self.emptyStateContainer.alpha = 1
                    self.emptyStateContainer.transform = .identity
                }
            }
            return
        }

        scrollView.isHidden = false
        emptyStateContainer.isHidden = true

        for (index, relation) in filteredRelations.enumerated() {
            let card = makeCard(for: relation)

            if animated {
                card.alpha = 0
                card.transform = CGAffineTransform(translationX: 0, y: 24)
            }

            stackView.addArrangedSubview(card)
            cardViews.append(card)

            if animated {
                let delay = Double(index) * 0.06
                UIView.animate(
                    withDuration: AIONDesign.animationMedium,
                    delay: delay,
                    usingSpringWithDamping: AIONDesign.springDamping,
                    initialSpringVelocity: AIONDesign.springVelocity,
                    options: [],
                    animations: {
                        card.alpha = 1
                        card.transform = .identity
                    }
                )
            }
        }
    }

    private func makeCard(for relation: FollowRelation) -> UserCardView {
        let card = UserCardView()
        card.configure(with: relation)

        // Override action button based on mode
        switch mode {
        case .followers:
            card.configureExternalAction(title: "social.removeFollower".localized, isDestructive: true)
            card.onActionTapped = { [weak self] in
                self?.handleRemoveFollower(relation)
            }
        case .following:
            card.configureExternalAction(title: "social.unfollow".localized, isDestructive: true)
            card.onActionTapped = { [weak self] in
                self?.confirmUnfollow(relation)
            }
        }

        card.onCardTapped = { [weak self] in
            let profileVC = UserProfileViewController(userUid: relation.uid)
            self?.navigationController?.pushViewController(profileVC, animated: true)
        }

        return card
    }

    // MARK: - Actions

    private func handleRemoveFollower(_ relation: FollowRelation) {
        performRemoval(relation: relation) {
            FollowFirestoreSync.removeFollower(followerUid: relation.uid, completion: $0)
        }
    }

    private func confirmUnfollow(_ relation: FollowRelation) {
        let alert = UIAlertController(
            title: "social.unfollowConfirmTitle".localized,
            message: String(format: "social.unfollowConfirmMessage".localized, relation.displayName),
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "social.unfollow".localized, style: .destructive) { [weak self] _ in
            self?.performRemoval(relation: relation) {
                FollowFirestoreSync.unfollowUser(targetUid: relation.uid, completion: $0)
            }
        })

        alert.addAction(UIAlertAction(title: "cancel".localized, style: .cancel))
        present(alert, animated: true)
    }

    private func performRemoval(relation: FollowRelation, action: @escaping (@escaping (Error?) -> Void) -> Void) {
        // Find the card view for loading state
        guard let cardIndex = filteredRelations.firstIndex(where: { $0.uid == relation.uid }),
              cardIndex < cardViews.count else { return }

        let card = cardViews[cardIndex]
        card.setLoading(true)

        action { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                card.setLoading(false)
                self.showErrorAlert(error)
                return
            }

            // Remove from data sources
            self.allRelations.removeAll { $0.uid == relation.uid }
            self.filteredRelations.removeAll { $0.uid == relation.uid }

            // Remove from tracked card views
            if let idx = self.cardViews.firstIndex(where: { $0 === card }) {
                self.cardViews.remove(at: idx)
            }

            // Animate card removal with scale + translate
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            UIView.animate(
                withDuration: AIONDesign.animationMedium,
                delay: 0,
                usingSpringWithDamping: AIONDesign.springDamping,
                initialSpringVelocity: AIONDesign.springVelocity,
                options: [],
                animations: {
                    card.alpha = 0
                    card.transform = CGAffineTransform(translationX: 0, y: -20)
                        .concatenating(CGAffineTransform(scaleX: 0.92, y: 0.92))
                },
                completion: { _ in
                    self.stackView.removeArrangedSubview(card)
                    card.removeFromSuperview()

                    // Show empty state if needed
                    if self.filteredRelations.isEmpty {
                        self.emptyStateContainer.alpha = 0
                        self.emptyStateContainer.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)

                        UIView.animate(
                            withDuration: AIONDesign.animationMedium,
                            delay: 0.05,
                            usingSpringWithDamping: AIONDesign.springDamping,
                            initialSpringVelocity: AIONDesign.springVelocity
                        ) {
                            self.scrollView.isHidden = true
                            self.emptyStateContainer.isHidden = false
                            self.emptyStateContainer.alpha = 1
                            self.emptyStateContainer.transform = .identity
                        }
                    }
                }
            )
        }
    }

    // MARK: - Error Handling

    private func showErrorAlert(_ error: Error) {
        let alert = UIAlertController(
            title: "error".localized,
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "ok".localized, style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UISearchBarDelegate

extension FollowersListViewController: UISearchBarDelegate {

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filterRelations(with: searchText)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    private func filterRelations(with query: String) {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            filteredRelations = allRelations
        } else {
            let lowercased = query.lowercased()
            filteredRelations = allRelations.filter {
                $0.displayName.lowercased().contains(lowercased)
            }
        }
        rebuildCards(animated: false)
    }
}
