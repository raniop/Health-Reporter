//
//  FriendRequestView.swift
//  Health Reporter
//
//  תצוגת בקשת חברות - מציגה שם, תמונה וכפתורי אישור/דחייה.
//

import UIKit

protocol FriendRequestViewDelegate: AnyObject {
    func friendRequestView(_ view: FriendRequestView, didAcceptRequest request: FriendRequest)
    func friendRequestView(_ view: FriendRequestView, didDeclineRequest request: FriendRequest)
}

final class FriendRequestView: UIView {

    // MARK: - Properties

    weak var delegate: FriendRequestViewDelegate?
    private var request: FriendRequest?

    // MARK: - UI Elements

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 24
        iv.backgroundColor = AIONDesign.surface
        iv.image = UIImage(systemName: "person.circle.fill")
        iv.tintColor = AIONDesign.textTertiary
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .semibold)
        l.textColor = AIONDesign.textPrimary
        l.textAlignment = .right
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13, weight: .regular)
        l.textColor = AIONDesign.textSecondary
        l.textAlignment = .right
        l.text = "social.wantsToBeYourFriend".localized
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let acceptButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("social.accept".localized, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        b.setTitleColor(.white, for: .normal)
        b.backgroundColor = AIONDesign.accentSuccess
        b.layer.cornerRadius = 8
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let declineButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("social.decline".localized, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        b.setTitleColor(AIONDesign.textSecondary, for: .normal)
        b.backgroundColor = AIONDesign.background
        b.layer.cornerRadius = 8
        b.layer.borderWidth = 1
        b.layer.borderColor = AIONDesign.separator.cgColor
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let buttonsStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = 8
        s.distribution = .fillEqually
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = AIONDesign.surface
        layer.cornerRadius = AIONDesign.cornerRadius
        translatesAutoresizingMaskIntoConstraints = false

        buttonsStack.addArrangedSubview(declineButton)
        buttonsStack.addArrangedSubview(acceptButton)

        addSubview(avatarImageView)
        addSubview(nameLabel)
        addSubview(subtitleLabel)
        addSubview(buttonsStack)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 80),

            avatarImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            avatarImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 48),
            avatarImageView.heightAnchor.constraint(equalToConstant: 48),

            nameLabel.trailingAnchor.constraint(equalTo: avatarImageView.leadingAnchor, constant: -12),
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),

            subtitleLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),

            buttonsStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            buttonsStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            buttonsStack.widthAnchor.constraint(equalToConstant: 140),
            buttonsStack.heightAnchor.constraint(equalToConstant: 36),
        ])

        acceptButton.addTarget(self, action: #selector(acceptTapped), for: .touchUpInside)
        declineButton.addTarget(self, action: #selector(declineTapped), for: .touchUpInside)
    }

    // MARK: - Configure

    func configure(with request: FriendRequest) {
        self.request = request
        nameLabel.text = request.fromDisplayName
        loadAvatar(from: request.fromPhotoURL)
    }

    // MARK: - Actions

    @objc private func acceptTapped() {
        guard let request = request else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        delegate?.friendRequestView(self, didAcceptRequest: request)
    }

    @objc private func declineTapped() {
        guard let request = request else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        delegate?.friendRequestView(self, didDeclineRequest: request)
    }

    // MARK: - Helpers

    private func loadAvatar(from urlString: String?) {
        guard let urlString = urlString, let url = URL(string: urlString) else {
            avatarImageView.image = UIImage(systemName: "person.circle.fill")
            avatarImageView.tintColor = AIONDesign.textTertiary
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.avatarImageView.image = image
                self?.avatarImageView.tintColor = nil
            }
        }.resume()
    }
}

// MARK: - User Card View (for search results and friend list)

final class UserCardView: UIView {

    // MARK: - Properties

    var onActionTapped: (() -> Void)?
    private var isLoading = false

    // MARK: - UI Elements

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 22
        iv.backgroundColor = AIONDesign.surface
        iv.image = UIImage(systemName: "person.circle.fill")
        iv.tintColor = AIONDesign.textTertiary
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .semibold)
        l.textColor = AIONDesign.textPrimary
        l.textAlignment = .right
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let statusLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13, weight: .regular)
        l.textColor = AIONDesign.textSecondary
        l.textAlignment = .right
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let actionButton: UIButton = {
        let b = UIButton(type: .system)
        b.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        b.layer.cornerRadius = 8
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = AIONDesign.surface
        layer.cornerRadius = AIONDesign.cornerRadius
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(avatarImageView)
        addSubview(nameLabel)
        addSubview(statusLabel)
        addSubview(actionButton)
        addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 68),

            avatarImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            avatarImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 44),
            avatarImageView.heightAnchor.constraint(equalToConstant: 44),

            nameLabel.trailingAnchor.constraint(equalTo: avatarImageView.leadingAnchor, constant: -12),
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            nameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: actionButton.trailingAnchor, constant: 12),

            statusLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            statusLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),

            actionButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            actionButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            actionButton.widthAnchor.constraint(equalToConstant: 90),
            actionButton.heightAnchor.constraint(equalToConstant: 32),

            activityIndicator.centerXAnchor.constraint(equalTo: actionButton.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: actionButton.centerYAnchor),
        ])

        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
    }

    // MARK: - Configure for Search Result

    func configure(with result: UserSearchResult) {
        nameLabel.text = result.displayName
        loadAvatar(from: result.photoURL)

        if result.isFriend {
            statusLabel.text = "social.alreadyFriends".localized
            statusLabel.textColor = AIONDesign.accentSuccess
            actionButton.isHidden = true
        } else if result.hasPendingRequest {
            if result.requestSentByMe {
                statusLabel.text = "social.requestPending".localized
                statusLabel.textColor = AIONDesign.accentWarning
                actionButton.isHidden = true
            } else {
                statusLabel.text = "social.sentYouRequest".localized
                statusLabel.textColor = AIONDesign.accentPrimary
                configureActionButton(title: "social.accept".localized, style: .primary)
            }
        } else {
            // הצגת Car Tier אם יש - שם הרכב במקום ציון
            if let tierIndex = result.carTierIndex {
                let tier = CarTierEngine.tiers[safe: tierIndex]
                statusLabel.text = "\(tier?.emoji ?? "") \(tier?.name ?? "")"
                statusLabel.textColor = tier?.color ?? AIONDesign.textSecondary
            } else {
                statusLabel.text = ""
            }
            configureActionButton(title: "social.sendRequest".localized, style: .secondary)
        }
    }

    // MARK: - Configure for Friend

    func configure(with friend: Friend) {
        nameLabel.text = friend.displayName
        loadAvatar(from: friend.photoURL)

        // הצגת שם הרכב במקום ציון
        if let tierIndex = friend.carTierIndex {
            let tier = CarTierEngine.tiers[safe: tierIndex]
            statusLabel.text = "\(tier?.emoji ?? "") \(tier?.name ?? "")"
            statusLabel.textColor = tier?.color ?? AIONDesign.textSecondary
        } else {
            statusLabel.text = ""
        }

        configureActionButton(title: "social.remove".localized, style: .destructive)
    }

    // MARK: - Button Styles

    private enum ButtonStyle {
        case primary
        case secondary
        case destructive
    }

    private func configureActionButton(title: String, style: ButtonStyle) {
        actionButton.isHidden = false
        actionButton.setTitle(title, for: .normal)

        switch style {
        case .primary:
            actionButton.backgroundColor = AIONDesign.accentPrimary
            actionButton.setTitleColor(.white, for: .normal)
            actionButton.layer.borderWidth = 0
        case .secondary:
            actionButton.backgroundColor = AIONDesign.background
            actionButton.setTitleColor(AIONDesign.accentPrimary, for: .normal)
            actionButton.layer.borderWidth = 1
            actionButton.layer.borderColor = AIONDesign.accentPrimary.cgColor
        case .destructive:
            actionButton.backgroundColor = AIONDesign.background
            actionButton.setTitleColor(AIONDesign.accentDanger, for: .normal)
            actionButton.layer.borderWidth = 1
            actionButton.layer.borderColor = AIONDesign.accentDanger.cgColor
        }
    }

    // MARK: - Loading State

    func setLoading(_ loading: Bool) {
        isLoading = loading
        actionButton.isEnabled = !loading
        actionButton.alpha = loading ? 0 : 1

        if loading {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }

    // MARK: - Actions

    @objc private func actionTapped() {
        guard !isLoading else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onActionTapped?()
    }

    // MARK: - Helpers

    private func loadAvatar(from urlString: String?) {
        guard let urlString = urlString, let url = URL(string: urlString) else {
            avatarImageView.image = UIImage(systemName: "person.circle.fill")
            avatarImageView.tintColor = AIONDesign.textTertiary
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.avatarImageView.image = image
                self?.avatarImageView.tintColor = nil
            }
        }.resume()
    }
}

// MARK: - Array Safe Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
