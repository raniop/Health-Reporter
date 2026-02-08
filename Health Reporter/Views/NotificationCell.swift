//
//  NotificationCell.swift
//  Health Reporter
//
//  Table view cell for notification center items.
//

import UIKit

final class NotificationCell: UITableViewCell {

    static let reuseIdentifier = "NotificationCell"

    /// Called when the tappable user name is tapped.
    var onUserNameTapped: (() -> Void)?

    // MARK: - UI Elements

    private let iconContainer: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 20
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .white
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15, weight: .semibold)
        l.textColor = AIONDesign.textPrimary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let bodyTextView: UITextView = {
        let tv = UITextView()
        tv.font = .systemFont(ofSize: 13, weight: .regular)
        tv.textColor = AIONDesign.textSecondary
        tv.backgroundColor = .clear
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.textContainer.maximumNumberOfLines = 2
        tv.textContainer.lineBreakMode = .byTruncatingTail
        tv.linkTextAttributes = [
            .foregroundColor: AIONDesign.accentPrimary,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
        ]
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private let timeLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11, weight: .medium)
        l.textColor = AIONDesign.textTertiary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let unreadDot: UIView = {
        let v = UIView()
        v.backgroundColor = AIONDesign.accentPrimary
        v.layer.cornerRadius = 4
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(iconContainer)
        iconContainer.addSubview(iconImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(bodyTextView)
        contentView.addSubview(timeLabel)
        contentView.addSubview(unreadDot)

        bodyTextView.delegate = self

        let semantic = LocalizationManager.shared.semanticContentAttribute
        contentView.semanticContentAttribute = semantic
        titleLabel.textAlignment = LocalizationManager.shared.textAlignment
        bodyTextView.textAlignment = LocalizationManager.shared.textAlignment

        NSLayoutConstraint.activate([
            iconContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            iconContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconContainer.widthAnchor.constraint(equalToConstant: 40),
            iconContainer.heightAnchor.constraint(equalToConstant: 40),

            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 18),
            iconImageView.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -8),

            bodyTextView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            bodyTextView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            bodyTextView.trailingAnchor.constraint(equalTo: unreadDot.leadingAnchor, constant: -8),
            bodyTextView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12),

            timeLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            unreadDot.widthAnchor.constraint(equalToConstant: 8),
            unreadDot.heightAnchor.constraint(equalToConstant: 8),
            unreadDot.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            unreadDot.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
        ])
    }

    // MARK: - Configure

    func configure(with notification: NotificationItem, userName: String?, hasUserProfile: Bool) {
        titleLabel.text = notification.title
        timeLabel.text = notification.timeAgo
        unreadDot.isHidden = notification.read

        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        iconImageView.image = UIImage(systemName: notification.type.icon, withConfiguration: config)

        let (bgColor, tintColor) = iconColors(for: notification.type)
        iconContainer.backgroundColor = bgColor
        iconImageView.tintColor = tintColor

        // Build body text — add tappable link on user name if present
        let body = notification.body
        let attr = NSMutableAttributedString(string: body, attributes: [
            .font: UIFont.systemFont(ofSize: 13, weight: .regular),
            .foregroundColor: AIONDesign.textSecondary,
        ])

        if let name = userName, hasUserProfile, let range = body.range(of: name) {
            let nsRange = NSRange(range, in: body)
            attr.addAttributes([
                .link: "username-tap://profile",
            ], range: nsRange)
        }

        bodyTextView.attributedText = attr

        // Dim read notifications slightly
        contentView.alpha = notification.read ? 0.7 : 1.0
    }

    private func iconColors(for type: NotificationType) -> (UIColor, UIColor) {
        switch type {
        case .followRequest:
            return (AIONDesign.accentPrimary.withAlphaComponent(0.15), AIONDesign.accentPrimary)
        case .followAccepted:
            return (AIONDesign.accentSuccess.withAlphaComponent(0.15), AIONDesign.accentSuccess)
        case .newFollower:
            return (AIONDesign.accentSecondary.withAlphaComponent(0.15), AIONDesign.accentSecondary)
        case .morningSummary:
            return (AIONDesign.accentWarning.withAlphaComponent(0.15), AIONDesign.accentWarning)
        case .bedtimeRecommendation:
            return (UIColor.systemIndigo.withAlphaComponent(0.15), UIColor.systemIndigo)
        case .healthMilestone:
            return (UIColor(hex: "#FFD700")!.withAlphaComponent(0.15), UIColor(hex: "#FFD700")!)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        bodyTextView.attributedText = nil
        timeLabel.text = nil
        unreadDot.isHidden = true
        contentView.alpha = 1.0
        onUserNameTapped = nil
    }
}

// MARK: - UITextViewDelegate

extension NotificationCell: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        if URL.scheme == "username-tap" {
            onUserNameTapped?()
            return false
        }
        return true
    }
}
