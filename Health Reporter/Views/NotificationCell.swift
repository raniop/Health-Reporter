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

    /// Range of the tappable name inside the body label (used for overlay positioning).
    private var nameRange: NSRange?

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

    /// Transparent overlay button positioned exactly over the user name.
    /// Added to the cell itself (not contentView) so it intercepts touches
    /// before UITableView's internal touch handling.
    private let nameOverlayButton: UIButton = {
        let b = UIButton(type: .custom)
        b.backgroundColor = .clear
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

        // IMPORTANT: Add to self (the cell), NOT contentView.
        // This way hitTest can return this button INSTEAD of contentView,
        // preventing UITableView from firing didSelectRowAt.
        addSubview(nameOverlayButton)
        nameOverlayButton.addTarget(self, action: #selector(nameButtonTapped), for: .touchUpInside)

        let semantic = LocalizationManager.shared.semanticContentAttribute
        contentView.semanticContentAttribute = semantic
        titleLabel.textAlignment = LocalizationManager.shared.textAlignment
        bodyLabel.textAlignment = LocalizationManager.shared.textAlignment

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

    // MARK: - Hit Testing

    /// Override hitTest so that taps landing on the name overlay button
    /// are routed to the button (not to contentView → tableView selection).
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !nameOverlayButton.isHidden {
            let buttonPoint = nameOverlayButton.convert(point, from: self)
            print("🔍 [NotifCell] hitTest — button.frame=\(nameOverlayButton.frame), point=\(point), buttonPoint=\(buttonPoint), contains=\(nameOverlayButton.bounds.contains(buttonPoint))")
            if nameOverlayButton.bounds.contains(buttonPoint) {
                print("🔍 [NotifCell] hitTest → returning nameOverlayButton!")
                return nameOverlayButton
            }
        }
        return super.hitTest(point, with: event)
    }

    // MARK: - Layout — position the name overlay button

    override func layoutSubviews() {
        super.layoutSubviews()
        positionNameOverlay()
    }

    /// Calculates the bounding rect of the name range inside bodyLabel
    /// and places the overlay button exactly on top (in cell coordinates).
    private func positionNameOverlay() {
        guard let range = nameRange,
              let attrText = bodyLabel.attributedText,
              bodyLabel.bounds.size != .zero else {
            nameOverlayButton.isHidden = true
            return
        }

        let textStorage = NSTextStorage(attributedString: attrText)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: bodyLabel.bounds.size)
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = bodyLabel.numberOfLines
        textContainer.lineBreakMode = bodyLabel.lineBreakMode
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        layoutManager.ensureLayout(for: textContainer)

        var glyphRange = NSRange()
        layoutManager.characterRange(forGlyphRange: range, actualGlyphRange: &glyphRange)
        let nameRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

        // Convert from bodyLabel coordinates to cell coordinates (not contentView)
        let padding: CGFloat = 4
        let frameInCell = bodyLabel.convert(nameRect, to: self)

        nameOverlayButton.frame = frameInCell.insetBy(dx: -padding, dy: -padding)
        nameOverlayButton.isHidden = false
        print("🔍 [NotifCell] positionNameOverlay — nameRect=\(nameRect), frameInCell=\(frameInCell), finalFrame=\(nameOverlayButton.frame)")
    }

    // MARK: - Name Button Action

    @objc private func nameButtonTapped() {
        print("🔍 [NotifCell] nameButtonTapped called! onUserNameTapped=\(onUserNameTapped != nil)")
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

        // Build body text — style the user name as a tappable link (white + underline)
        let body = notification.body
        if let name = userName, hasUserProfile, let range = body.range(of: name) {
            let nsRange = NSRange(range, in: body)
            self.nameRange = nsRange

            let attr = NSMutableAttributedString(string: body, attributes: [
                .font: UIFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: AIONDesign.textSecondary,
            ])
            attr.addAttributes([
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            ], range: nsRange)
            bodyLabel.attributedText = attr
            nameOverlayButton.isHidden = false
        } else {
            self.nameRange = nil
            bodyLabel.attributedText = nil
            bodyLabel.text = body
            nameOverlayButton.isHidden = true
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
        bodyLabel.attributedText = nil
        bodyLabel.text = nil
        timeLabel.text = nil
        unreadDot.isHidden = true
        contentView.alpha = 1.0
        onUserNameTapped = nil
        nameRange = nil
        nameOverlayButton.isHidden = true
    }
}
