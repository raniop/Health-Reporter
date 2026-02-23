//
//  ChatListViewController.swift
//  Health Reporter
//
//  WhatsApp-style conversation list showing all active chats ordered by last message.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

final class ChatListViewController: UIViewController {

    // MARK: - Properties

    private var conversations: [ChatConversation] = []
    private var filteredConversations: [ChatConversation] = []
    private var conversationsListener: ListenerRegistration?
    private var isSearchActive = false
    private let currentUid = Auth.auth().currentUser?.uid ?? ""

    // MARK: - UI Elements

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

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.separatorStyle = .none
        tv.backgroundColor = .clear
        tv.showsVerticalScrollIndicator = false
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private let emptyStateStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 12
        s.alignment = .center
        s.translatesAutoresizingMaskIntoConstraints = false
        s.isHidden = true
        return s
    }()

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
        title = "chat.title".localized
        applyAIONGradientBackground()
        view.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute

        setupNavigationBar()
        setupLayout()
        setupEmptyState()

        loadingIndicator.startAnimating()
        listenToConversations()
    }

    deinit {
        conversationsListener?.remove()
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

        let composeButton = UIBarButtonItem(
            image: UIImage(systemName: "square.and.pencil"),
            style: .plain,
            target: self,
            action: #selector(composeTapped)
        )
        composeButton.tintColor = AIONDesign.accentPrimary
        navigationItem.rightBarButtonItem = composeButton
    }

    @objc private func composeTapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let vc = NewMessageViewController()
        vc.delegate = self
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true)
    }

    // MARK: - Layout

    private func setupLayout() {
        searchBar.delegate = self

        view.addSubview(searchBar)
        view.addSubview(tableView)
        view.addSubview(emptyStateStack)
        view.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),

            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            emptyStateStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateStack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            emptyStateStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyStateStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        tableView.register(ChatListCell.self, forCellReuseIdentifier: ChatListCell.reuseIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
    }

    private func setupEmptyState() {
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 48, weight: .thin)
        let iconView = UIImageView(image: UIImage(systemName: "bubble.left.and.bubble.right", withConfiguration: iconConfig))
        iconView.tintColor = AIONDesign.textTertiary
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 56),
            iconView.heightAnchor.constraint(equalToConstant: 56),
        ])

        let titleLabel = UILabel()
        titleLabel.text = "chat.noConversations".localized
        titleLabel.font = AIONDesign.headlineFont()
        titleLabel.textColor = AIONDesign.textPrimary
        titleLabel.textAlignment = .center

        let subtitleLabel = UILabel()
        subtitleLabel.text = "chat.noConversationsSubtitle".localized
        subtitleLabel.font = AIONDesign.bodyFont()
        subtitleLabel.textColor = AIONDesign.textSecondary
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        emptyStateStack.addArrangedSubview(iconView)
        emptyStateStack.addArrangedSubview(titleLabel)
        emptyStateStack.addArrangedSubview(subtitleLabel)
    }

    // MARK: - Data

    private func listenToConversations() {
        conversationsListener = ChatFirestoreSync.listenToConversations { [weak self] conversations in
            guard let self = self else { return }
            self.loadingIndicator.stopAnimating()
            self.conversations = conversations
            self.updateUI()
        }
    }

    private func updateUI() {
        let source = isSearchActive ? filteredConversations : conversations
        emptyStateStack.isHidden = !source.isEmpty
        tableView.isHidden = source.isEmpty
        tableView.reloadData()
    }

    // MARK: - Navigation

    private func openChat(_ conversation: ChatConversation) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let vc = ChatViewController(conversation: conversation)
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension ChatListViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearchActive ? filteredConversations.count : conversations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ChatListCell.reuseIdentifier, for: indexPath) as? ChatListCell else {
            return UITableViewCell()
        }

        let source = isSearchActive ? filteredConversations : conversations
        let conversation = source[indexPath.row]
        cell.configure(with: conversation, currentUid: currentUid)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension ChatListViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let source = isSearchActive ? filteredConversations : conversations
        openChat(source[indexPath.row])
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 72
    }
}

// MARK: - UISearchBarDelegate

extension ChatListViewController: UISearchBarDelegate {

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if query.isEmpty {
            isSearchActive = false
        } else {
            isSearchActive = true
            filteredConversations = conversations.filter { conv in
                let otherProfile = conv.otherParticipantProfile(currentUid: currentUid)
                let name = otherProfile?.displayName.lowercased() ?? ""
                return name.contains(query)
            }
        }
        updateUI()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        isSearchActive = false
        searchBar.resignFirstResponder()
        updateUI()
    }
}

// MARK: - NewMessageViewControllerDelegate

extension ChatListViewController: NewMessageViewControllerDelegate {

    func newMessageViewController(_ vc: NewMessageViewController, didSelectUser user: UserSearchResult) {
        vc.dismiss(animated: true) { [weak self] in
            ChatFirestoreSync.getOrCreateConversation(with: user.uid) { conversation, error in
                guard let self = self, let conversation = conversation else { return }
                self.openChat(conversation)
            }
        }
    }
}
