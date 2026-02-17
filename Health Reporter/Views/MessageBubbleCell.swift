//
//  MessageBubbleCell.swift
//  Health Reporter
//
//  WhatsApp-style message bubble cell for the chat screen.
//

import UIKit

final class MessageBubbleCell: UITableViewCell {

    static let reuseIdentifier = "MessageBubbleCell"

    // MARK: - UI Elements

    private let bubbleContainer: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 18
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let messageLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .regular)
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let metaStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = 4
        s.alignment = .center
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let timestampLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11, weight: .medium)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let statusIcon: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    // Constraints that change based on sent/received
    private var bubbleLeading: NSLayoutConstraint!
    private var bubbleTrailing: NSLayoutConstraint!

    private let maxBubbleWidthMultiplier: CGFloat = 0.75
    private let isRTL = LocalizationManager.shared.currentLanguage.isRTL

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

        // NOTE: Cell is used in an inverted table view (transform scaleY: -1),
        // so the cell itself is also inverted. No additional transform needed here.

        contentView.addSubview(bubbleContainer)
        bubbleContainer.addSubview(messageLabel)
        bubbleContainer.addSubview(metaStack)

        metaStack.addArrangedSubview(timestampLabel)
        metaStack.addArrangedSubview(statusIcon)

        // Status icon size
        NSLayoutConstraint.activate([
            statusIcon.widthAnchor.constraint(equalToConstant: 16),
            statusIcon.heightAnchor.constraint(equalToConstant: 12),
        ])

        // Bubble container
        bubbleLeading = bubbleContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12)
        bubbleTrailing = bubbleContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12)

        NSLayoutConstraint.activate([
            bubbleContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            bubbleContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2),
            bubbleContainer.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: maxBubbleWidthMultiplier),
            // Minimum width so timestamp + status icon always fit
            bubbleContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 90),

            // Message label inside bubble
            messageLabel.topAnchor.constraint(equalTo: bubbleContainer.topAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleContainer.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleContainer.trailingAnchor, constant: -12),

            // Meta stack below message
            metaStack.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 4),
            metaStack.trailingAnchor.constraint(equalTo: bubbleContainer.trailingAnchor, constant: -10),
            metaStack.bottomAnchor.constraint(equalTo: bubbleContainer.bottomAnchor, constant: -6),
        ])
    }

    // MARK: - Configure

    func configure(with message: ChatMessage, isFromCurrentUser: Bool) {
        messageLabel.text = message.text

        // Timestamp
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = LocalizationManager.shared.currentLocale
        timestampLabel.text = formatter.string(from: message.timestamp)

        // Deactivate old position constraints
        bubbleLeading.isActive = false
        bubbleTrailing.isActive = false

        if isFromCurrentUser {
            // Sent bubble: trailing side (right in LTR, left in RTL)
            bubbleContainer.backgroundColor = AIONDesign.accentPrimary
            messageLabel.textColor = .white
            timestampLabel.textColor = UIColor.white.withAlphaComponent(0.7)

            if isRTL {
                bubbleLeading.isActive = true
            } else {
                bubbleTrailing.isActive = true
            }

            // Round corners: all except bottom-trailing
            bubbleContainer.layer.maskedCorners = isRTL
                ? [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMaxXMaxYCorner]
                : [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner]

            // Status icon: single check = sent, double check = seen (blue tint)
            statusIcon.isHidden = false
            switch message.status {
            case .sent:
                statusIcon.image = UIImage(systemName: "checkmark")
                statusIcon.tintColor = UIColor.white.withAlphaComponent(0.7)
            case .delivered:
                statusIcon.image = Self.doubleCheckImage()
                statusIcon.tintColor = UIColor.white.withAlphaComponent(0.7)
            case .seen:
                statusIcon.image = Self.doubleCheckImage()
                statusIcon.tintColor = UIColor(red: 0.33, green: 0.85, blue: 1.0, alpha: 1.0)
            }
        } else {
            // Received bubble: leading side (left in LTR, right in RTL)
            bubbleContainer.backgroundColor = AIONDesign.surface
            messageLabel.textColor = AIONDesign.textPrimary
            timestampLabel.textColor = AIONDesign.textTertiary

            if isRTL {
                bubbleTrailing.isActive = true
            } else {
                bubbleLeading.isActive = true
            }

            // Round corners: all except bottom-leading
            bubbleContainer.layer.maskedCorners = isRTL
                ? [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner]
                : [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMaxXMaxYCorner]

            statusIcon.isHidden = true
        }
    }

    /// Draws a WhatsApp-style double checkmark image (two overlapping ✓✓)
    private static func doubleCheckImage() -> UIImage {
        let size = CGSize(width: 18, height: 12)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let path1 = UIBezierPath()
            path1.move(to: CGPoint(x: 1, y: 6))
            path1.addLine(to: CGPoint(x: 5, y: 10.5))
            path1.addLine(to: CGPoint(x: 13, y: 1.5))

            let path2 = UIBezierPath()
            path2.move(to: CGPoint(x: 5, y: 6))
            path2.addLine(to: CGPoint(x: 9, y: 10.5))
            path2.addLine(to: CGPoint(x: 17, y: 1.5))

            UIColor.white.setStroke()
            path1.lineWidth = 1.5
            path1.lineCapStyle = .round
            path1.lineJoinStyle = .round
            path1.stroke()

            path2.lineWidth = 1.5
            path2.lineCapStyle = .round
            path2.lineJoinStyle = .round
            path2.stroke()
        }.withRenderingMode(.alwaysTemplate)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        messageLabel.text = nil
        timestampLabel.text = nil
        statusIcon.isHidden = true
        bubbleLeading.isActive = false
        bubbleTrailing.isActive = false
    }
}
