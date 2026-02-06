//
//  FollowRequestsViewController.swift
//  Health Reporter
//
//  Follow requests modal screen with 2026 aesthetic.
//  Clean modal card layout, staggered animations, confetti on accept.
//

import UIKit

protocol FollowRequestsViewControllerDelegate: AnyObject {
    func followRequestsViewControllerDidUpdateRequests(_ controller: FollowRequestsViewController)
}

final class FollowRequestsViewController: UIViewController, FriendRequestViewDelegate {

    // MARK: - Properties

    weak var delegate: FollowRequestsViewControllerDelegate?
    private var pendingRequests: [FollowRequest] = []
    private var cardViews: [FriendRequestView] = []

    // MARK: - UI Elements

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

    private let emptyStateView: UIView = {
        let v = UIView()
        v.isHidden = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let emptyStateIcon: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 48, weight: .light)
        let iv = UIImageView(image: UIImage(systemName: "bell.slash", withConfiguration: config))
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
        l.text = "social.noRequests".localized
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .large)
        ai.color = AIONDesign.accentPrimary
        ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        setupUI()
        applyRTL()
        fetchRequests()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        delegate?.followRequestsViewControllerDidUpdateRequests(self)
    }

    // MARK: - Setup Navigation

    private func setupNavigation() {
        title = "social.followRequests".localized
        modalPresentationStyle = .formSheet

        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = AIONDesign.surface
        appearance.titleTextAttributes = [.foregroundColor: AIONDesign.textPrimary]
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance

        let closeButton = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeTapped)
        )
        closeButton.tintColor = AIONDesign.textPrimary
        navigationItem.rightBarButtonItem = closeButton
    }

    // MARK: - Setup UI

    private func setupUI() {
        view.backgroundColor = AIONDesign.surface

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        view.addSubview(emptyStateView)
        view.addSubview(loadingIndicator)

        emptyStateView.addSubview(emptyStateIcon)
        emptyStateView.addSubview(emptyStateLabel)

        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Content stack
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: AIONDesign.spacingLarge),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: AIONDesign.spacingLarge),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -AIONDesign.spacingLarge),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -AIONDesign.spacingLarge),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -(AIONDesign.spacingLarge * 2)),

            // Empty state view
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            emptyStateIcon.topAnchor.constraint(equalTo: emptyStateView.topAnchor),
            emptyStateIcon.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            emptyStateIcon.widthAnchor.constraint(equalToConstant: 56),
            emptyStateIcon.heightAnchor.constraint(equalToConstant: 56),

            emptyStateLabel.topAnchor.constraint(equalTo: emptyStateIcon.bottomAnchor, constant: AIONDesign.spacing),
            emptyStateLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor),
            emptyStateLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor),
            emptyStateLabel.bottomAnchor.constraint(equalTo: emptyStateView.bottomAnchor),

            // Loading indicator
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    // MARK: - RTL Support

    private func applyRTL() {
        let semanticAttr = LocalizationManager.shared.semanticContentAttribute
        view.semanticContentAttribute = semanticAttr
        scrollView.semanticContentAttribute = semanticAttr
        contentStack.semanticContentAttribute = semanticAttr
        emptyStateLabel.textAlignment = .center
    }

    // MARK: - Fetch Requests

    private func fetchRequests() {
        loadingIndicator.startAnimating()
        scrollView.isHidden = true
        emptyStateView.isHidden = true

        FollowFirestoreSync.fetchPendingFollowRequests { [weak self] requests in
            guard let self = self else { return }
            self.loadingIndicator.stopAnimating()
            self.pendingRequests = requests
            self.rebuildCards()
        }
    }

    // MARK: - Rebuild Cards

    private func rebuildCards() {
        // Remove existing cards
        for card in cardViews {
            contentStack.removeArrangedSubview(card)
            card.removeFromSuperview()
        }
        cardViews.removeAll()

        if pendingRequests.isEmpty {
            scrollView.isHidden = true
            emptyStateView.isHidden = false

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
            return
        }

        scrollView.isHidden = false
        emptyStateView.isHidden = true

        // Create and add cards with staggered entrance
        for (index, request) in pendingRequests.enumerated() {
            let card = FriendRequestView()
            card.configure(with: request)
            card.delegate = self
            card.alpha = 0
            card.transform = CGAffineTransform(translationX: 0, y: 24)
            contentStack.addArrangedSubview(card)
            cardViews.append(card)

            // Staggered entrance animation
            let delay = TimeInterval(index) * 0.08
            UIView.animate(
                withDuration: AIONDesign.animationMedium,
                delay: delay,
                usingSpringWithDamping: AIONDesign.springDamping,
                initialSpringVelocity: AIONDesign.springVelocity,
                options: [],
                animations: {
                    card.alpha = 1
                    card.transform = .identity
                },
                completion: nil
            )
        }
    }

    // MARK: - Remove Card With Animation

    private func removeCard(for request: FollowRequest, withConfetti: Bool) {
        guard let index = pendingRequests.firstIndex(where: { $0.id == request.id }),
              index < cardViews.count else { return }

        let card = cardViews[index]

        // Optimistically remove from data
        pendingRequests.remove(at: index)
        cardViews.remove(at: index)

        if withConfetti {
            let confetti = ConfettiBurstView(frame: card.bounds)
            card.addSubview(confetti)
            confetti.burst()
        }

        UIView.animate(
            withDuration: AIONDesign.animationMedium,
            delay: withConfetti ? 0.15 : 0,
            usingSpringWithDamping: AIONDesign.springDamping,
            initialSpringVelocity: AIONDesign.springVelocity,
            options: [],
            animations: {
                card.alpha = 0
                card.transform = CGAffineTransform(translationX: withConfetti ? 0 : -card.bounds.width, y: 0)
                    .scaledBy(x: 0.8, y: 0.8)
            },
            completion: { [weak self] _ in
                self?.contentStack.removeArrangedSubview(card)
                card.removeFromSuperview()
                self?.updateEmptyState()
            }
        )

        // Notify delegate
        delegate?.followRequestsViewControllerDidUpdateRequests(self)
    }

    private func updateEmptyState() {
        if pendingRequests.isEmpty {
            scrollView.isHidden = true
            emptyStateView.isHidden = false
            emptyStateView.alpha = 0
            emptyStateView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)

            UIView.animate(
                withDuration: AIONDesign.animationMedium,
                delay: 0.1,
                usingSpringWithDamping: AIONDesign.springDamping,
                initialSpringVelocity: AIONDesign.springVelocity
            ) {
                self.emptyStateView.alpha = 1
                self.emptyStateView.transform = .identity
            }
        }
    }

    // MARK: - Error Handling

    private func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "error".localized,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "ok".localized, style: .default))
        present(alert, animated: true)
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    // MARK: - FriendRequestViewDelegate

    func friendRequestView(_ view: FriendRequestView, didAcceptRequest request: FriendRequest) {
        removeCard(for: request, withConfetti: true)

        FollowFirestoreSync.acceptFollowRequest(requestId: request.id) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.showErrorAlert(message: error.localizedDescription)
                self.fetchRequests()
            }
        }
    }

    func friendRequestView(_ view: FriendRequestView, didDeclineRequest request: FriendRequest) {
        removeCard(for: request, withConfetti: false)

        FollowFirestoreSync.declineFollowRequest(requestId: request.id) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.showErrorAlert(message: error.localizedDescription)
                self.fetchRequests()
            }
        }
    }
}
