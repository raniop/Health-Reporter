//
//  NotificationsCenterViewController.swift
//  Health Reporter
//
//  Full notification center: pending follow requests + notification history.
//  Replaces FollowRequestsViewController as the bell icon destination.
//

import UIKit
import UserNotifications

protocol NotificationsCenterViewControllerDelegate: AnyObject {
    func notificationsCenterDidUpdate(_ controller: NotificationsCenterViewController)
}

final class NotificationsCenterViewController: UIViewController {

    // MARK: - Properties

    weak var delegate: NotificationsCenterViewControllerDelegate?
    private var pendingRequests: [FollowRequest] = []
    private var notifications: [NotificationItem] = []
    private var isLoading = true

    // MARK: - UI Elements

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .grouped)
        tv.backgroundColor = .clear
        tv.separatorStyle = .none
        tv.showsVerticalScrollIndicator = false
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
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
        iv.tintColor = .tertiaryLabel
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let emptyStateLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .medium)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.numberOfLines = 0
        l.text = "notifications.empty".localized
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

    private let refreshControl = UIRefreshControl()

    // MARK: - Sections

    private enum Section: Int, CaseIterable {
        case requests = 0
        case notifications = 1
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        setupUI()
        applyRTL()
        fetchData()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Always clear the app icon badge when leaving notifications
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
        delegate?.notificationsCenterDidUpdate(self)
        // Mark all as read, then ping observers — posting the broadcast before
        // Firestore commits returns the stale unread count, leaving the bell
        // badge stuck until the user opens-and-closes the sheet a second time.
        markAllReadQuietly { [weak self] in
            _ = self
            NotificationCenter.default.post(name: NSNotification.Name("NotificationItemSaved"), object: nil)
        }
    }

    // MARK: - Setup Navigation

    private func setupNavigation() {
        title = "notifications.title".localized
        modalPresentationStyle = .formSheet

        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = .systemGroupedBackground
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance

        let closeButton = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeTapped)
        )
        closeButton.tintColor = .label
        navigationItem.rightBarButtonItem = closeButton

        let clearAllButton = UIBarButtonItem(
            image: UIImage(systemName: "trash"),
            style: .plain,
            target: self,
            action: #selector(clearAllTapped)
        )
        clearAllButton.tintColor = .label
        navigationItem.leftBarButtonItem = clearAllButton
    }

    // MARK: - Setup UI

    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(NotificationCell.self, forCellReuseIdentifier: NotificationCell.reuseIdentifier)

        refreshControl.tintColor = AIONDesign.accentPrimary
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl

        view.addSubview(tableView)
        view.addSubview(emptyStateView)
        view.addSubview(loadingIndicator)

        emptyStateView.addSubview(emptyStateIcon)
        emptyStateView.addSubview(emptyStateLabel)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

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

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    // MARK: - RTL Support

    private func applyRTL() {
        let semanticAttr = LocalizationManager.shared.semanticContentAttribute
        view.semanticContentAttribute = semanticAttr
        tableView.semanticContentAttribute = semanticAttr
        emptyStateLabel.textAlignment = .center
    }

    // MARK: - Data Loading

    private func fetchData() {
        if isLoading {
            loadingIndicator.startAnimating()
            tableView.isHidden = true
            emptyStateView.isHidden = true
        }

        // Purge generic bedtime placeholders first, then fetch so the list comes back clean.
        FriendsFirestoreSync.deleteGenericBedtimeNotifications(
            placeholders: AppDelegate.bedtimePlaceholderStrings
        ) { [weak self] _ in
            self?.performFetch()
        }
    }

    private func performFetch() {
        let group = DispatchGroup()

        // Fetch pending follow requests
        group.enter()
        FollowFirestoreSync.fetchPendingFollowRequests { [weak self] requests in
            self?.pendingRequests = requests
            group.leave()
        }

        // Fetch notification history
        group.enter()
        FriendsFirestoreSync.fetchNotifications(limit: 50) { [weak self] items in
            self?.notifications = items
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.isLoading = false
            self.loadingIndicator.stopAnimating()
            self.refreshControl.endRefreshing()
            self.updateUI()
        }
    }

    private func updateUI() {
        let hasContent = !pendingRequests.isEmpty || !notifications.isEmpty

        tableView.isHidden = !hasContent
        emptyStateView.isHidden = hasContent

        if hasContent {
            tableView.reloadData()
        } else {
            // Animate empty state
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
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func handleRefresh() {
        fetchData()
    }

    @objc private func clearAllTapped() {
        guard !notifications.isEmpty || !pendingRequests.isEmpty else { return }

        let alert = UIAlertController(
            title: "notifications.clearAll.title".localized,
            message: "notifications.clearAll.message".localized,
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "notifications.clearAll.confirm".localized, style: .destructive) { [weak self] _ in
            self?.performClearAll()
        })
        alert.addAction(UIAlertAction(title: "cancel".localized, style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.leftBarButtonItem
        }
        present(alert, animated: true)
    }

    private func performClearAll() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        notifications.removeAll()
        tableView.reloadData()
        updateUI()
        FriendsFirestoreSync.deleteAllNotifications { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.showErrorAlert(message: error.localizedDescription)
                self.fetchData()
            } else {
                UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
                self.delegate?.notificationsCenterDidUpdate(self)
            }
        }
    }

    private func markAllReadQuietly(completion: (() -> Void)? = nil) {
        let hasUnread = notifications.contains { !$0.read }
        guard hasUnread else {
            completion?()
            return
        }
        for i in notifications.indices {
            notifications[i].read = true
        }
        // Clear app icon badge immediately (don't wait for Firestore round-trip)
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
        FriendsFirestoreSync.markAllNotificationsAsRead {
            completion?()
        }
    }

    // MARK: - Follow Request Actions

    private func acceptRequest(_ request: FollowRequest) {
        guard let index = pendingRequests.firstIndex(where: { $0.id == request.id }) else { return }
        pendingRequests.remove(at: index)
        tableView.reloadSections(IndexSet(integer: Section.requests.rawValue), with: .automatic)

        FollowFirestoreSync.acceptFollowRequest(requestId: request.id) { [weak self] error in
            if let error = error {
                self?.showErrorAlert(message: error.localizedDescription)
                self?.fetchData()
            }
        }
        delegate?.notificationsCenterDidUpdate(self)
    }

    private func declineRequest(_ request: FollowRequest) {
        guard let index = pendingRequests.firstIndex(where: { $0.id == request.id }) else { return }
        pendingRequests.remove(at: index)
        tableView.reloadSections(IndexSet(integer: Section.requests.rawValue), with: .automatic)

        FollowFirestoreSync.declineFollowRequest(requestId: request.id) { [weak self] error in
            if let error = error {
                self?.showErrorAlert(message: error.localizedDescription)
                self?.fetchData()
            }
        }
        delegate?.notificationsCenterDidUpdate(self)
    }

    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension NotificationsCenterViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .requests: return pendingRequests.count
        case .notifications: return notifications.count
        case .none: return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .requests:
            return makeRequestCell(for: indexPath)
        case .notifications:
            let cell = tableView.dequeueReusableCell(withIdentifier: NotificationCell.reuseIdentifier, for: indexPath) as! NotificationCell
            let notification = notifications[indexPath.row]
            let name = displayName(from: notification)
            let uid = userUid(from: notification)
            cell.configure(with: notification, userName: name, hasUserProfile: uid != nil)
            cell.onUserNameTapped = { [weak self] in
                guard let self = self, let uid = uid else { return }
                let vc = UserProfileViewController(userUid: uid)
                self.navigationController?.pushViewController(vc, animated: true)
            }
            return cell
        case .none:
            return UITableViewCell()
        }
    }

    private func makeRequestCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "RequestCell")
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        cell.selectionStyle = .none

        let request = pendingRequests[indexPath.row]
        let card = FriendRequestView()
        card.configure(with: request)
        card.delegate = self
        card.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(card)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 4),
            card.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -4),
        ])

        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch Section(rawValue: section) {
        case .requests:
            guard !pendingRequests.isEmpty else { return nil }
            return makeSectionHeader(title: "Follow Requests", icon: "person.badge.plus")
        case .notifications:
            guard !notifications.isEmpty else { return nil }
            return makeSectionHeader(title: "notifications.section.recent".localized, icon: "clock.fill")
        case .none:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch Section(rawValue: section) {
        case .requests: return pendingRequests.isEmpty ? 0 : 40
        case .notifications: return notifications.isEmpty ? 0 : 40
        case .none: return 0
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        0
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }

    private func makeSectionHeader(title: String, icon: String) -> UIView {
        let container = UIView()
        container.backgroundColor = .systemGroupedBackground

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .heavy)
        label.textColor = .secondaryLabel

        let iconAttachment = NSTextAttachment()
        iconAttachment.image = UIImage(
            systemName: icon,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        )?.withTintColor(AIONDesign.accentPrimary, renderingMode: .alwaysOriginal)

        let attrText = NSMutableAttributedString(attachment: iconAttachment)
        attrText.append(NSAttributedString(string: "  " + title.uppercased(), attributes: [
            .font: UIFont.systemFont(ofSize: 13, weight: .heavy),
            .foregroundColor: UIColor.secondaryLabel,
            .kern: 0.8 as NSNumber,
        ]))
        label.attributedText = attrText
        label.textAlignment = LocalizationManager.shared.textAlignment

        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
        ])

        return container
    }
}

// MARK: - UITableViewDelegate

extension NotificationsCenterViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard Section(rawValue: indexPath.section) == .notifications else { return }

        let notification = notifications[indexPath.row]

        // Mark as read
        if !notification.read {
            notifications[indexPath.row].read = true
            FriendsFirestoreSync.markNotificationAsRead(notification.id)
            tableView.reloadRows(at: [indexPath], with: .fade)
            delegate?.notificationsCenterDidUpdate(self)
        }

        // If user tapped on a username link, skip detail — profile navigation already fired
        if let cell = tableView.cellForRow(at: indexPath) as? NotificationCell, cell.didTapName {
            cell.didTapName = false
            return
        }

        // Show detail for any notification
        showNotificationDetail(notification)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard Section(rawValue: indexPath.section) == .notifications,
              indexPath.row < notifications.count else {
            return nil
        }

        let deleteAction = UIContextualAction(style: .destructive, title: "delete".localized) { [weak self] _, _, complete in
            self?.deleteNotification(at: indexPath)
            complete(true)
        }
        deleteAction.image = UIImage(systemName: "trash")
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }

    private func deleteNotification(at indexPath: IndexPath) {
        guard indexPath.row < notifications.count else { return }
        let item = notifications.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)

        FriendsFirestoreSync.deleteNotification(item.id) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.showErrorAlert(message: error.localizedDescription)
                self.fetchData()
            } else {
                self.delegate?.notificationsCenterDidUpdate(self)
                if self.notifications.isEmpty && self.pendingRequests.isEmpty {
                    self.updateUI()
                }
            }
        }
    }

    private func showNotificationDetail(_ notification: NotificationItem) {
        let detailVC = NotificationDetailViewController(notification: notification)
        detailVC.modalPresentationStyle = .pageSheet
        if let sheet = detailVC.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = AIONDesign.cornerRadiusLarge
        }
        present(detailVC, animated: true)
    }

    /// Extracts the relevant user UID from the notification data dictionary.
    private func userUid(from notification: NotificationItem) -> String? {
        switch notification.type {
        case .followRequest:
            return notification.data["fromUid"] as? String
        case .followAccepted:
            return notification.data["acceptedByUid"] as? String
        case .newFollower:
            return notification.data["followerUid"] as? String
        case .morningSummary, .bedtimeRecommendation, .healthMilestone:
            return nil
        }
    }

    /// Extracts the display name from the notification data dictionary.
    private func displayName(from notification: NotificationItem) -> String? {
        switch notification.type {
        case .followRequest:
            return notification.data["fromDisplayName"] as? String
        case .followAccepted:
            return notification.data["acceptedByDisplayName"] as? String
        case .newFollower:
            return notification.data["followerDisplayName"] as? String
        case .morningSummary, .bedtimeRecommendation, .healthMilestone:
            return nil
        }
    }
}

// MARK: - FriendRequestViewDelegate

extension NotificationsCenterViewController: FriendRequestViewDelegate {
    func friendRequestView(_ view: FriendRequestView, didAcceptRequest request: FriendRequest) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        acceptRequest(request)
    }

    func friendRequestView(_ view: FriendRequestView, didDeclineRequest request: FriendRequest) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        declineRequest(request)
    }
}
