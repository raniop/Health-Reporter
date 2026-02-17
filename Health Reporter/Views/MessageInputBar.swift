//
//  MessageInputBar.swift
//  Health Reporter
//
//  WhatsApp-style message input bar with auto-growing text view and send button.
//

import UIKit

final class MessageInputBar: UIView {

    var onSendTapped: ((String) -> Void)?

    // MARK: - UI Elements

    private let topSeparator: UIView = {
        let v = UIView()
        v.backgroundColor = AIONDesign.separator.withAlphaComponent(0.3)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let textView: UITextView = {
        let tv = UITextView()
        tv.font = .systemFont(ofSize: 16, weight: .regular)
        tv.textColor = AIONDesign.textPrimary
        tv.backgroundColor = AIONDesign.surfaceElevated
        tv.layer.cornerRadius = 20
        tv.textContainerInset = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        tv.isScrollEnabled = false
        tv.showsVerticalScrollIndicator = false
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.semanticContentAttribute = .forceLeftToRight
        tv.textAlignment = .natural
        return tv
    }()

    private let placeholderLabel: UILabel = {
        let l = UILabel()
        l.text = "chat.typeMessage".localized
        l.font = .systemFont(ofSize: 16, weight: .regular)
        l.textColor = AIONDesign.textTertiary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let sendButton: UIButton = {
        let b = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold)
        b.setImage(UIImage(systemName: "arrow.up.circle.fill", withConfiguration: config), for: .normal)
        b.tintColor = AIONDesign.accentPrimary
        b.isEnabled = false
        b.alpha = 0.4
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private var textViewHeightConstraint: NSLayoutConstraint!
    private let maxLines: Int = 5
    private let minHeight: CGFloat = 40
    private let lineHeight: CGFloat = 22

    /// Bottom padding constraint — adjusted when keyboard shows/hides
    var bottomPadding: NSLayoutConstraint!

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = AIONDesign.background
        semanticContentAttribute = .forceLeftToRight

        addSubview(topSeparator)
        addSubview(textView)
        addSubview(sendButton)
        textView.addSubview(placeholderLabel)

        textView.delegate = self
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)

        textViewHeightConstraint = textView.heightAnchor.constraint(equalToConstant: minHeight)
        bottomPadding = sendButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)

        // Use leftAnchor/rightAnchor (absolute, never flipped by RTL parent)
        // Send button is ALWAYS on the right side
        NSLayoutConstraint.activate([
            topSeparator.topAnchor.constraint(equalTo: topAnchor),
            topSeparator.leftAnchor.constraint(equalTo: leftAnchor),
            topSeparator.rightAnchor.constraint(equalTo: rightAnchor),
            topSeparator.heightAnchor.constraint(equalToConstant: 0.5),

            textViewHeightConstraint,

            sendButton.rightAnchor.constraint(equalTo: rightAnchor, constant: -8),
            bottomPadding,
            sendButton.widthAnchor.constraint(equalToConstant: 36),
            sendButton.heightAnchor.constraint(equalToConstant: 36),

            textView.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            textView.leftAnchor.constraint(equalTo: leftAnchor, constant: 12),
            textView.rightAnchor.constraint(equalTo: sendButton.leftAnchor, constant: -8),
            textView.bottomAnchor.constraint(equalTo: sendButton.bottomAnchor),

            placeholderLabel.leftAnchor.constraint(equalTo: textView.leftAnchor, constant: 16),
            placeholderLabel.centerYAnchor.constraint(equalTo: textView.centerYAnchor),
        ])
    }

    // MARK: - Actions

    @objc private func sendTapped() {
        let text = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onSendTapped?(text)
        textView.text = ""
        placeholderLabel.isHidden = false
        updateSendButton()
        updateTextViewHeight()
    }

    private func updateSendButton() {
        let hasText = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        UIView.animate(withDuration: AIONDesign.animationFast) {
            self.sendButton.isEnabled = hasText
            self.sendButton.alpha = hasText ? 1.0 : 0.4
        }
    }

    private func updateTextViewHeight() {
        let maxHeight = minHeight + lineHeight * CGFloat(maxLines - 1)
        let size = textView.sizeThatFits(CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude))
        let newHeight = min(max(size.height, minHeight), maxHeight)
        textView.isScrollEnabled = size.height > maxHeight
        textViewHeightConstraint.constant = newHeight

        UIView.animate(withDuration: 0.1) {
            self.layoutIfNeeded()
        }
    }
}

// MARK: - UITextViewDelegate

extension MessageInputBar: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        updateSendButton()
        updateTextViewHeight()
    }
}
