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

    private let bodyLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13, weight: .regular)
        l.textColor = AIONDesign.textSecondary
        l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    /// Transparent button placed exactly over the user name text.
    /// Because it's a real UIControl it intercepts the touch and prevents
    /// the tableView from receiving `didSelectRowAt`.
    private let nameButton: UIButton = {
        let b = UIButton(type: .system)
        b.backgroundColor = .clear
        b.translatesAutoresizingMaskIntoConstraints = false
        b.isHidden = true
        return b
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

    /// Constraints for positioning the name button dynamically.
    private var nameButtonLeading: NSLayoutConstraint?
    private var nameButtonWidth: NSLayoutConstraint?
    private var nameButtonTop: NSLayoutConstraint?
    private var nameButtonHeight: NSLayoutConstraint?

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
        contentView.addSubview(bodyLabel)
        contentView.addSubview(timeLabel)
        contentView.addSubview(unreadDot)

        // Name button sits on top of the body label
        contentView.addSubview(nameButton)
        nameButton.addTarget(self, action: #selector(nameButtonTapped), for: .touchUpInside)

        let semantic = LocalizationManager.shared.semanticContentAttribute
        contentView.semanticContentAttribute = semantic
        titleLabel.textAlignment = LocalizationManager.shared.textAlignment
        bodyLabel.textAlignment = LocalizationManager.shared.textAlignment

        // Prepare dynamic constraints for the name button (inactive until positioned)
        nameButtonLeading = nameButton.leadingAnchor.constraint(equalTo: bodyLabel.leadingAnchor)
        nameButtonWidth = nameButton.widthAnchor.constraint(equalToConstant: 0)
        nameButtonTop = nameButton.topAnchor.constraint(equalTo: bodyLabel.topAnchor)
        nameButtonHeight = nameButton.heightAnchor.constraint(equalToConstant: 0)
        nameButtonLeading?.isActive = true
        nameButtonWidth?.isActive = true
        nameButtonTop?.isActive = true
        nameButtonHeight?.isActive = true

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

            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            bodyLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            bodyLabel.trailingAnchor.constraint(equalTo: unreadDot.leadingAnchor, constant: -8),
            bodyLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12),

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

        // Build body text — style the user name as a tappable link
        let body = notification.body
        if let name = userName, hasUserProfile, let range = body.range(of: name) {
            let nsRange = NSRange(range, in: body)

            let attr = NSMutableAttributedString(string: body, attributes: [
                .font: UIFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: AIONDesign.textSecondary,
            ])
            attr.addAttributes([
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: AIONDesign.accentPrimary,
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            ], range: nsRange)
            bodyLabel.attributedText = attr
            nameButton.isHidden = false

            // Position the invisible button over the name text after layout
            DispatchQueue.main.async { [weak self] in
                self?.positionNameButton(over: nsRange)
            }
        } else {
            bodyLabel.attributedText = nil
            bodyLabel.text = body
            nameButton.isHidden = true
        }

        // Dim read notifications slightly
        contentView.alpha = notification.read ? 0.7 : 1.0
    }

    /// Uses NSLayoutManager to compute the pixel rect of the name range
    /// inside bodyLabel, then positions nameButton exactly on top of it.
    private func positionNameButton(over range: NSRange) {
        guard let attrText = bodyLabel.attributedText else { return }

        let textStorage = NSTextStorage(attributedString: attrText)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: bodyLabel.bounds.size)
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = bodyLabel.numberOfLines
        textContainer.lineBreakMode = bodyLabel.lineBreakMode
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        // Force layout so glyph positions are computed
        layoutManager.ensureLayout(for: textContainer)

        var glyphRange = NSRange()
        layoutManager.characterRange(forGlyphRange: range, actualGlyphRange: &glyphRange)
        let nameRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

        // Add small padding around the tap target for easier tapping
        let padding: CGFloat = 4
        nameButtonLeading?.constant = nameRect.origin.x - padding
        nameButtonWidth?.constant = nameRect.width + padding * 2
        nameButtonTop?.constant = nameRect.origin.y - padding
        nameButtonHeight?.constant = nameRect.height + padding * 2
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
        bodyLabel.attributedText = nil
        bodyLabel.text = nil
        timeLabel.text = nil
        unreadDot.isHidden = true
        contentView.alpha = 1.0
        onUserNameTapped = nil
        nameButton.isHidden = true
    }
}
