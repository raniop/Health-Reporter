//
//  NewMessageViewController.swift
//  Health Reporter
//
//  Search-based user picker for starting a new chat conversation.
//

import UIKit

protocol NewMessageViewControllerDelegate: AnyObject {
    func newMessageViewController(_ vc: NewMessageViewController, didSelectUser user: UserSearchResult)
}

final class NewMessageViewController: UIViewController {

    // MARK: - Properties

    weak var delegate: NewMessageViewControllerDelegate?
    private var searchResults: [UserSearchResult] = []
    private var searchTimer: Timer?

    // MARK: - UI Elements

    private let searchBar: UISearchBar = {
        let sb = UISearchBar()
        sb.placeholder = "chat.searchUsers".localized
        sb.searchBarStyle = .minimal
        sb.backgroundImage = UIImage()
        sb.translatesAutoresizingMaskIntoConstraints = false
        if let textField = sb.value(forKey: "searchField") as? UITextField {
            textField.textColor = AIONDesign.textPrimary
            textField.backgroundColor = AIONDesign.surface
            textField.attributedPlaceholder = NSAttributedString(
                string: "chat.searchUsers".localized,
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
        tv.keyboardDismissMode = .onDrag
        return tv
    }()

    private let emptyStateStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 12
        s.alignment = .center
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.hidesWhenStopped = true
        ai.color = AIONDesign.accentPrimary
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "chat.newMessage".localized
        view.backgroundColor = AIONDesign.background
        view.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute

        setupNavigation()
        setupLayout()
        setupEmptyState()

        // Focus the search bar immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.searchBar.becomeFirstResponder()
        }
    }

    // MARK: - Setup

    private func setupNavigation() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = AIONDesign.background
        appearance.titleTextAttributes = [
            .foregroundColor: AIONDesign.textPrimary,
            .font: UIFont.systemFont(ofSize: 18, weight: .bold)
        ]
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance

        let cancelButton = UIBarButtonItem(
            title: "cancel".localized,
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
        cancelButton.tintColor = AIONDesign.textSecondary
        navigationItem.leftBarButtonItem = cancelButton
    }

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
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyStateStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateStack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            emptyStateStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyStateStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 24),
        ])

        tableView.register(NewMessageUserCell.self, forCellReuseIdentifier: NewMessageUserCell.reuseIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
    }

    private func setupEmptyState() {
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 48, weight: .thin)
        let iconView = UIImageView(image: UIImage(systemName: "magnifyingglass", withConfiguration: iconConfig))
        iconView.tintColor = AIONDesign.textTertiary
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 56),
            iconView.heightAnchor.constraint(equalToConstant: 56),
        ])

        let titleLabel = UILabel()
        titleLabel.text = "chat.searchToStart".localized
        titleLabel.font = AIONDesign.bodyFont()
        titleLabel.textColor = AIONDesign.textSecondary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        emptyStateStack.addArrangedSubview(iconView)
        emptyStateStack.addArrangedSubview(titleLabel)
    }

    // MARK: - Actions

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    // MARK: - Search

    private func performSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            searchResults = []
            updateUI()
            return
        }

        loadingIndicator.startAnimating()

        FollowFirestoreSync.searchUsers(query: trimmed, limit: 20) { [weak self] results in
            guard let self = self else { return }
            self.loadingIndicator.stopAnimating()
            self.searchResults = results
            self.updateUI()
        }
    }

    private func updateUI() {
        let hasResults = !searchResults.isEmpty
        emptyStateStack.isHidden = hasResults || loadingIndicator.isAnimating
        tableView.isHidden = !hasResults
        tableView.reloadData()
    }
}

// MARK: - UISearchBarDelegate

extension NewMessageViewController: UISearchBarDelegate {

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchTimer?.invalidate()
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.performSearch(query: searchText)
        }
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        if let text = searchBar.text {
            performSearch(query: text)
        }
    }
}

// MARK: - UITableViewDataSource

extension NewMessageViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        searchResults.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: NewMessageUserCell.reuseIdentifier, for: indexPath) as? NewMessageUserCell else {
            return UITableViewCell()
        }
        cell.configure(with: searchResults[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate

extension NewMessageViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        delegate?.newMessageViewController(self, didSelectUser: searchResults[indexPath.row])
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        64
    }
}

// MARK: - NewMessageUserCell

final class NewMessageUserCell: UITableViewCell {

    static let reuseIdentifier = "NewMessageUserCell"

    private let avatarRing: AvatarRingView = {
        let v = AvatarRingView(size: 44)
        v.ringWidth = 2
        v.isAnimated = false
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .semibold)
        l.textColor = AIONDesign.textPrimary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        let semantic = LocalizationManager.shared.semanticContentAttribute
        contentView.semanticContentAttribute = semantic

        contentView.addSubview(avatarRing)
        contentView.addSubview(nameLabel)

        nameLabel.textAlignment = LocalizationManager.shared.textAlignment

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        if isRTL {
            NSLayoutConstraint.activate([
                avatarRing.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
                avatarRing.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
                avatarRing.widthAnchor.constraint(equalToConstant: 44),
                avatarRing.heightAnchor.constraint(equalToConstant: 44),

                nameLabel.trailingAnchor.constraint(equalTo: avatarRing.leadingAnchor, constant: -12),
                nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
                nameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 16),
            ])
        } else {
            NSLayoutConstraint.activate([
                avatarRing.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                avatarRing.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
                avatarRing.widthAnchor.constraint(equalToConstant: 44),
                avatarRing.heightAnchor.constraint(equalToConstant: 44),

                nameLabel.leadingAnchor.constraint(equalTo: avatarRing.trailingAnchor, constant: 12),
                nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
                nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16),
            ])
        }
    }

    func configure(with user: UserSearchResult) {
        nameLabel.text = user.displayName
        avatarRing.loadImage(from: user.photoURL)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.text = nil
    }
}
