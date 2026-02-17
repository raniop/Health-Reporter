//
//  ChatListCell.swift
//  Health Reporter
//
//  Table view cell for the conversation list (WhatsApp-style).
//

import UIKit
import FirebaseAuth

final class ChatListCell: UITableViewCell {

    static let reuseIdentifier = "ChatListCell"

    // MARK: - UI Elements

    private let avatarRing: AvatarRingView = {
        let v = AvatarRingView(size: 52)
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

    private let messagePreviewLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 14, weight: .regular)
        l.textColor = AIONDesign.textSecondary
        l.numberOfLines = 1
        l.lineBreakMode = .byTruncatingTail
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let timeLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12, weight: .medium)
        l.textColor = AIONDesign.textTertiary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let unreadBadge: UIView = {
        let v = UIView()
        v.backgroundColor = AIONDesign.accentPrimary
        v.layer.cornerRadius = 11
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()

    private let unreadCountLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12, weight: .bold)
        l.textColor = .white
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let statusIcon: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        let semantic = LocalizationManager.shared.semanticContentAttribute
        contentView.semanticContentAttribute = semantic

        contentView.addSubview(avatarRing)
        contentView.addSubview(nameLabel)
        contentView.addSubview(messagePreviewLabel)
        contentView.addSubview(timeLabel)
        contentView.addSubview(unreadBadge)
        contentView.addSubview(statusIcon)
        unreadBadge.addSubview(unreadCountLabel)

        nameLabel.textAlignment = LocalizationManager.shared.textAlignment
        messagePreviewLabel.textAlignment = LocalizationManager.shared.textAlignment

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        if isRTL {
            NSLayoutConstraint.activate([
                avatarRing.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
                avatarRing.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
                avatarRing.widthAnchor.constraint(equalToConstant: 52),
                avatarRing.heightAnchor.constraint(equalToConstant: 52),

                timeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                timeLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),

                nameLabel.trailingAnchor.constraint(equalTo: avatarRing.leadingAnchor, constant: -12),
                nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
                nameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: timeLabel.trailingAnchor, constant: 8),

                statusIcon.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
                statusIcon.centerYAnchor.constraint(equalTo: messagePreviewLabel.centerYAnchor),
                statusIcon.widthAnchor.constraint(equalToConstant: 16),
                statusIcon.heightAnchor.constraint(equalToConstant: 12),

                messagePreviewLabel.trailingAnchor.constraint(equalTo: statusIcon.leadingAnchor, constant: -4),
                messagePreviewLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 3),
                messagePreviewLabel.leadingAnchor.constraint(greaterThanOrEqualTo: unreadBadge.trailingAnchor, constant: 8),

                unreadBadge.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                unreadBadge.centerYAnchor.constraint(equalTo: messagePreviewLabel.centerYAnchor),
                unreadBadge.heightAnchor.constraint(equalToConstant: 22),
                unreadBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 22),
            ])
        } else {
            NSLayoutConstraint.activate([
                avatarRing.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                avatarRing.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
                avatarRing.widthAnchor.constraint(equalToConstant: 52),
                avatarRing.heightAnchor.constraint(equalToConstant: 52),

                timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
                timeLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),

                nameLabel.leadingAnchor.constraint(equalTo: avatarRing.trailingAnchor, constant: 12),
                nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
                nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -8),

                statusIcon.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
                statusIcon.centerYAnchor.constraint(equalTo: messagePreviewLabel.centerYAnchor),
                statusIcon.widthAnchor.constraint(equalToConstant: 16),
                statusIcon.heightAnchor.constraint(equalToConstant: 12),

                messagePreviewLabel.leadingAnchor.constraint(equalTo: statusIcon.trailingAnchor, constant: 4),
                messagePreviewLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 3),
                messagePreviewLabel.trailingAnchor.constraint(lessThanOrEqualTo: unreadBadge.leadingAnchor, constant: -8),

                unreadBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
                unreadBadge.centerYAnchor.constraint(equalTo: messagePreviewLabel.centerYAnchor),
                unreadBadge.heightAnchor.constraint(equalToConstant: 22),
                unreadBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 22),
            ])
        }

        NSLayoutConstraint.activate([
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 72),

            unreadCountLabel.centerXAnchor.constraint(equalTo: unreadBadge.centerXAnchor),
            unreadCountLabel.centerYAnchor.constraint(equalTo: unreadBadge.centerYAnchor),
            unreadCountLabel.leadingAnchor.constraint(greaterThanOrEqualTo: unreadBadge.leadingAnchor, constant: 5),
            unreadCountLabel.trailingAnchor.constraint(lessThanOrEqualTo: unreadBadge.trailingAnchor, constant: -5),
        ])
    }

    // MARK: - Configure

    func configure(with conversation: ChatConversation, currentUid: String) {
        let otherProfile = conversation.otherParticipantProfile(currentUid: currentUid)
        nameLabel.text = otherProfile?.displayName ?? "chat.unknownUser".localized

        // Avatar
        avatarRing.loadImage(from: otherProfile?.photoURL)

        // Last message preview
        if let lastMsg = conversation.lastMessage {
            let isMyMessage = lastMsg.senderUid == currentUid
            if isMyMessage {
                messagePreviewLabel.text = lastMsg.text
                statusIcon.isHidden = false
                // Status icon: single check = sent, double check = delivered/seen
                statusIcon.image = UIImage(systemName: "checkmark")
                statusIcon.tintColor = AIONDesign.textTertiary
            } else {
                messagePreviewLabel.text = lastMsg.text
                statusIcon.isHidden = true
            }
        } else {
            messagePreviewLabel.text = "chat.noMessages".localized
            statusIcon.isHidden = true
        }

        // Time label
        if let timestamp = conversation.lastMessage?.timestamp ?? conversation.lastMessageTimestamp {
            timeLabel.text = formatTimeAgo(timestamp)
        } else {
            timeLabel.text = ""
        }

        // Unread badge
        if conversation.unreadCount > 0 {
            unreadBadge.isHidden = false
            unreadCountLabel.text = conversation.unreadCount > 99 ? "99+" : "\(conversation.unreadCount)"
            nameLabel.font = .systemFont(ofSize: 16, weight: .bold)
            messagePreviewLabel.font = .systemFont(ofSize: 14, weight: .semibold)
            messagePreviewLabel.textColor = AIONDesign.textPrimary
            timeLabel.textColor = AIONDesign.accentPrimary
        } else {
            unreadBadge.isHidden = true
            nameLabel.font = .systemFont(ofSize: 16, weight: .semibold)
            messagePreviewLabel.font = .systemFont(ofSize: 14, weight: .regular)
            messagePreviewLabel.textColor = AIONDesign.textSecondary
            timeLabel.textColor = AIONDesign.textTertiary
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.text = nil
        messagePreviewLabel.text = nil
        timeLabel.text = nil
        unreadBadge.isHidden = true
        statusIcon.isHidden = true
        nameLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        messagePreviewLabel.font = .systemFont(ofSize: 14, weight: .regular)
        messagePreviewLabel.textColor = AIONDesign.textSecondary
        timeLabel.textColor = AIONDesign.textTertiary
    }

    // MARK: - Time Formatting

    private func formatTimeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        if minutes < 1 { return "social.timeAgo.now".localized }
        if minutes < 60 { return "social.timeAgo.minutes".localized(minutes) }
        if hours < 24 { return "social.timeAgo.hours".localized(hours) }
        if days == 1 { return "social.timeAgo.yesterday".localized }
        if days < 7 { return "social.timeAgo.days".localized(days) }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        formatter.locale = LocalizationManager.shared.currentLocale
        return formatter.string(from: date)
    }
}
