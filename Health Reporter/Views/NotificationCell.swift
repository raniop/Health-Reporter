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

    /// Container that holds body text parts: prefix label, name button, suffix label.
    /// When there's no user name, only bodyPlainLabel is shown instead.
    private let bodyStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.alignment = .firstBaseline
        s.spacing = 0
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    /// Used when there is NO tappable user name — plain body text.
    private let bodyPlainLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13, weight: .regular)
        l.textColor = AIONDesign.textSecondary
        l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    /// Text before the user name.
    private let prefixLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13, weight: .regular)
        l.textColor = AIONDesign.textSecondary
        l.setContentHuggingPriority(.required, for: .horizontal)
        l.setContentCompressionResistancePriority(.required, for: .horizontal)
        return l
    }()

    /// The tappable user name button.
    private let nameButton: UIButton = {
        let b = UIButton(type: .system)
        b.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        b.setTitleColor(AIONDesign.accentPrimary, for: .normal)
        b.contentEdgeInsets = .zero
        b.setContentHuggingPriority(.required, for: .horizontal)
        b.setContentCompressionResistancePriority(.required, for: .horizontal)
        return b
    }()

    /// Text after the user name.
    private let suffixLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13, weight: .regular)
        l.textColor = AIONDesign.textSecondary
        l.lineBreakMode = .byTruncatingTail
        return l
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
        contentView.addSubview(bodyPlainLabel)
        contentView.addSubview(bodyStack)
        contentView.addSubview(timeLabel)
        contentView.addSubview(unreadDot)

        // Build the body stack: prefix + name button + suffix
        bodyStack.addArrangedSubview(prefixLabel)
        bodyStack.addArrangedSubview(nameButton)
        bodyStack.addArrangedSubview(suffixLabel)
        nameButton.addTarget(self, action: #selector(nameButtonTapped), for: .touchUpInside)

        let semantic = LocalizationManager.shared.semanticContentAttribute
        contentView.semanticContentAttribute = semantic
        titleLabel.textAlignment = LocalizationManager.shared.textAlignment
        bodyPlainLabel.textAlignment = LocalizationManager.shared.textAlignment
        bodyStack.semanticContentAttribute = semantic

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

            // Plain body label (no name)
            bodyPlainLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            bodyPlainLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            bodyPlainLabel.trailingAnchor.constraint(equalTo: unreadDot.leadingAnchor, constant: -8),
            bodyPlainLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12),

            // Body stack (with name)
            bodyStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            bodyStack.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            bodyStack.trailingAnchor.constraint(lessThanOrEqualTo: unreadDot.leadingAnchor, constant: -8),
            bodyStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12),

            timeLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            unreadDot.widthAnchor.constraint(equalToConstant: 8),
            unreadDot.heightAnchor.constraint(equalToConstant: 8),
            unreadDot.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            unreadDot.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
        ])
    }

    // MARK: - Name Button Action

    @objc private func nameButtonTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onUserNameTapped?()
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

        let body = notification.body

        if let name = userName, hasUserProfile, let range = body.range(of: name) {
            // Split body into prefix / name / suffix
            let prefix = String(body[body.startIndex..<range.lowerBound])
            let suffix = String(body[range.upperBound..<body.endIndex])

            prefixLabel.text = prefix
            nameButton.setTitle(name, for: .normal)

            // Add underline to the button title
            let underlined = NSAttributedString(string: name, attributes: [
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: AIONDesign.accentPrimary,
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            ])
            nameButton.setAttributedTitle(underlined, for: .normal)

            suffixLabel.text = suffix

            bodyStack.isHidden = false
            bodyPlainLabel.isHidden = true
        } else {
            bodyPlainLabel.text = body
            bodyStack.isHidden = true
            bodyPlainLabel.isHidden = false
        }

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
        bodyPlainLabel.text = nil
        prefixLabel.text = nil
        suffixLabel.text = nil
        nameButton.setTitle(nil, for: .normal)
        nameButton.setAttributedTitle(nil, for: .normal)
        timeLabel.text = nil
        unreadDot.isHidden = true
        contentView.alpha = 1.0
        onUserNameTapped = nil
        bodyStack.isHidden = true
        bodyPlainLabel.isHidden = false
    }
}
