//
//  ChatViewController.swift
//  Health Reporter
//
//  WhatsApp-style 1-on-1 chat screen with real-time messages, inverted table view,
//  message input bar, keyboard handling, and read receipts.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

final class ChatViewController: UIViewController {

    // MARK: - Properties

    private let conversation: ChatConversation
    private let currentUid: String
    private let otherUid: String
    private let otherProfile: ChatUserProfile?
    private let chatId: String

    private var messages: [ChatMessage] = []
    private var messagesListener: ListenerRegistration?
    private var isLoadingEarlier = false

    /// Messages grouped by date section for date headers
    private var sections: [(date: Date, messages: [ChatMessage])] = []

    // MARK: - UI Elements

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.separatorStyle = .none
        tv.backgroundColor = .clear
        tv.keyboardDismissMode = .interactive
        tv.allowsSelection = false
        tv.showsVerticalScrollIndicator = false
        tv.translatesAutoresizingMaskIntoConstraints = false
        // Inverted for bottom-anchored messages
        tv.transform = CGAffineTransform(scaleX: 1, y: -1)
        return tv
    }()

    private let inputBar = MessageInputBar()
    private var inputBarBottomConstraint: NSLayoutConstraint!

    private let emptyStateLabel: UILabel = {
        let l = UILabel()
        l.text = "chat.startConversation".localized
        l.font = AIONDesign.bodyFont()
        l.textColor = AIONDesign.textTertiary
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Init

    init(conversation: ChatConversation) {
        self.conversation = conversation
        self.chatId = conversation.id
        self.currentUid = Auth.auth().currentUser?.uid ?? ""
        self.otherUid = conversation.otherParticipantUid(currentUid: Auth.auth().currentUser?.uid ?? "") ?? ""
        self.otherProfile = conversation.otherParticipantProfile(currentUid: Auth.auth().currentUser?.uid ?? "")
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        messagesListener?.remove()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AIONDesign.background
        view.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute

        setupNavigationBar()
        setupLayout()
        setupKeyboardObservers()
        listenToMessages()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Set initial bottom padding to account for safe area (home indicator)
        let safeBottom = view.safeAreaInsets.bottom
        if inputBar.bottomPadding.constant != -(8 + safeBottom) && inputBarBottomConstraint.constant == 0 {
            inputBar.bottomPadding.constant = -(8 + safeBottom)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ChatFirestoreSync.markConversationAsSeen(chatId: chatId, otherUid: otherUid)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        ChatFirestoreSync.markConversationAsSeen(chatId: chatId, otherUid: otherUid)
    }

    // MARK: - Navigation Bar

    private func setupNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [
            .foregroundColor: AIONDesign.textPrimary,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance

        // Custom title view with avatar + name
        let titleView = UIView()
        titleView.translatesAutoresizingMaskIntoConstraints = false

        let avatar = AvatarRingView(size: 32)
        avatar.ringWidth = 1.5
        avatar.isAnimated = false
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.loadImage(from: otherProfile?.photoURL)

        let nameLabel = UILabel()
        nameLabel.text = otherProfile?.displayName ?? "chat.unknownUser".localized
        nameLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        nameLabel.textColor = AIONDesign.textPrimary
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        titleView.addSubview(avatar)
        titleView.addSubview(nameLabel)

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        if isRTL {
            NSLayoutConstraint.activate([
                avatar.trailingAnchor.constraint(equalTo: titleView.trailingAnchor),
                avatar.centerYAnchor.constraint(equalTo: titleView.centerYAnchor),
                avatar.widthAnchor.constraint(equalToConstant: 32),
                avatar.heightAnchor.constraint(equalToConstant: 32),

                nameLabel.trailingAnchor.constraint(equalTo: avatar.leadingAnchor, constant: -8),
                nameLabel.centerYAnchor.constraint(equalTo: titleView.centerYAnchor),
                nameLabel.leadingAnchor.constraint(equalTo: titleView.leadingAnchor),
            ])
        } else {
            NSLayoutConstraint.activate([
                avatar.leadingAnchor.constraint(equalTo: titleView.leadingAnchor),
                avatar.centerYAnchor.constraint(equalTo: titleView.centerYAnchor),
                avatar.widthAnchor.constraint(equalToConstant: 32),
                avatar.heightAnchor.constraint(equalToConstant: 32),

                nameLabel.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 8),
                nameLabel.centerYAnchor.constraint(equalTo: titleView.centerYAnchor),
                nameLabel.trailingAnchor.constraint(equalTo: titleView.trailingAnchor),
            ])
        }

        NSLayoutConstraint.activate([
            titleView.heightAnchor.constraint(equalToConstant: 36),
        ])

        navigationItem.titleView = titleView

        // Tap on title view to push profile
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapTitleView))
        titleView.addGestureRecognizer(tap)
        titleView.isUserInteractionEnabled = true
    }

    @objc private func didTapTitleView() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let vc = UserProfileViewController(userUid: otherUid)
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Layout

    private func setupLayout() {
        inputBar.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(tableView)
        view.addSubview(inputBar)
        view.addSubview(emptyStateLabel)

        // Pin to view.bottomAnchor so the input bar background extends to the screen edge
        inputBarBottomConstraint = inputBar.bottomAnchor.constraint(equalTo: view.bottomAnchor)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: inputBar.topAnchor),

            inputBar.leftAnchor.constraint(equalTo: view.leftAnchor),
            inputBar.rightAnchor.constraint(equalTo: view.rightAnchor),
            inputBarBottomConstraint,

            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            emptyStateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyStateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
        ])

        tableView.register(MessageBubbleCell.self, forCellReuseIdentifier: MessageBubbleCell.reuseIdentifier)
        tableView.dataSource = self
        tableView.delegate = self

        inputBar.onSendTapped = { [weak self] text in
            self?.sendMessage(text)
        }
    }

    // MARK: - Keyboard

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)),
                                               name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)),
                                               name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }

        // Input bar is pinned to view.bottomAnchor, so use full keyboard height
        inputBarBottomConstraint.constant = -keyboardFrame.height
        // Keyboard is up — minimal bottom padding (no safe area gap)
        inputBar.bottomPadding.constant = -8

        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }

        inputBarBottomConstraint.constant = 0
        // Keyboard hidden — add safe area bottom inset so content sits above home indicator
        let safeBottom = view.safeAreaInsets.bottom
        inputBar.bottomPadding.constant = -(8 + safeBottom)

        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - Messages

    private func listenToMessages() {
        // Verify chat document exists before attaching listener to avoid Firestore permission errors
        // (security rules use get() on parent doc which fails if it doesn't exist yet)
        print("💬 [ChatVC] listenToMessages — chatId=\(chatId)")
        let db = Firestore.firestore()
        db.collection("chats").document(chatId).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("💬 [ChatVC] listenToMessages — getDocument error: \(error.localizedDescription)")
            }
            guard snapshot?.exists == true else {
                print("💬 [ChatVC] listenToMessages — chat doc not yet available, retrying in 1s...")
                // Chat doc not yet available — retry after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.listenToMessages()
                }
                return
            }
            print("💬 [ChatVC] listenToMessages — chat doc exists, attaching messages listener")
            self.messagesListener = ChatFirestoreSync.listenToMessages(chatId: self.chatId, limit: 50) { [weak self] messages in
                guard let self = self else { return }
                print("💬 [ChatVC] Messages snapshot — \(messages.count) messages")
                self.messages = messages
                self.buildSections()
                self.emptyStateLabel.isHidden = !messages.isEmpty
                self.tableView.reloadData()
            }
        }
    }

    private func buildSections() {
        let calendar = Calendar.current
        var grouped: [Date: [ChatMessage]] = [:]

        for message in messages {
            let day = calendar.startOfDay(for: message.timestamp)
            grouped[day, default: []].append(message)
        }

        // Sort sections by date ascending, but since table is inverted we reverse
        sections = grouped.map { (date: $0.key, messages: $0.value) }
            .sorted { $0.date > $1.date }

        // Reverse messages within each section for inverted display
        for i in sections.indices {
            sections[i].messages.reverse()
        }
    }

    private func sendMessage(_ text: String) {
        print("💬 [ChatVC] sendMessage — chatId=\(chatId), otherUid=\(otherUid), text=\(text.prefix(30))...")
        ChatFirestoreSync.sendMessage(chatId: chatId, text: text, otherUid: otherUid) { error in
            if let error = error {
                print("💬 [ChatVC] sendMessage FAILED — \(error.localizedDescription)")
            } else {
                print("💬 [ChatVC] sendMessage OK ✅")
            }
        }
    }

    // MARK: - Load Earlier

    private func loadEarlierMessages() {
        guard !isLoadingEarlier, let earliest = messages.first else { return }
        isLoadingEarlier = true

        ChatFirestoreSync.loadEarlierMessages(chatId: chatId, before: earliest.timestamp) { [weak self] olderMessages in
            guard let self = self else { return }
            self.isLoadingEarlier = false

            guard !olderMessages.isEmpty else { return }
            self.messages.insert(contentsOf: olderMessages, at: 0)
            self.buildSections()
            self.tableView.reloadData()
        }
    }
}

// MARK: - UITableViewDataSource

extension ChatViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: MessageBubbleCell.reuseIdentifier, for: indexPath) as? MessageBubbleCell else {
            return UITableViewCell()
        }

        let message = sections[indexPath.section].messages[indexPath.row]
        let isFromMe = message.senderUid == currentUid

        // Invert the cell since the table is inverted
        cell.contentView.transform = CGAffineTransform(scaleX: 1, y: -1)
        cell.configure(with: message, isFromCurrentUser: isFromMe)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension ChatViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        // In inverted table, "headers" appear at the bottom of each section
        // We use footers for date headers (they appear at the top visually)
        return nil
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        // Footer in inverted table = visual header (date separator)
        let header = ChatDateHeaderView(reuseIdentifier: ChatDateHeaderView.reuseIdentifier)
        header.configure(with: sections[section].date)
        // Invert the header since the table is inverted
        header.contentView.transform = CGAffineTransform(scaleX: 1, y: -1)
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0.01
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 32
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // In inverted table, "top" (scrolling up) is actually the oldest messages
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let frameHeight = scrollView.frame.height

        if offsetY > contentHeight - frameHeight - 100 {
            loadEarlierMessages()
        }
    }
}
