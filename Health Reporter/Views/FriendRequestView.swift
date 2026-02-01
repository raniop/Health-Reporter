//
//  FriendRequestView.swift
//  Health Reporter
//
//  תצוגת בקשת חברות - עיצוב מודרני עם Glass Morphism ואנימציות.
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
    private var confettiView: ConfettiBurstView?

    // MARK: - UI Elements

    private let glassBackground: GlassMorphismView = {
        let view = GlassMorphismView()
        view.cornerRadius = AIONDesign.cornerRadius
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let avatarRing: AvatarRingView = {
        let view = AvatarRingView(size: 56)
        view.ringColors = [AIONDesign.accentPrimary, AIONDesign.accentSecondary, AIONDesign.accentSuccess]
        view.isAnimated = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 17, weight: .bold)
        l.textColor = AIONDesign.textPrimary
        l.textAlignment = LocalizationManager.shared.textAlignment
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13, weight: .regular)
        l.textColor = AIONDesign.textSecondary
        l.textAlignment = LocalizationManager.shared.textAlignment
        l.text = "social.wantsToBeYourFriend".localized
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let acceptButton: GradientButton = {
        let b = GradientButton()
        b.setTitle("social.accept".localized, for: .normal)
        b.gradientColors = [AIONDesign.accentSecondary, AIONDesign.accentSuccess]
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let declineButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("social.decline".localized, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        b.setTitleColor(AIONDesign.textSecondary, for: .normal)
        b.backgroundColor = AIONDesign.surfaceElevated.withAlphaComponent(0.5)
        b.layer.cornerRadius = AIONDesign.cornerRadiusSmall
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let buttonsStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = 10
        s.distribution = .fillEqually
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let swipeHintLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11, weight: .medium)
        l.textColor = AIONDesign.textTertiary
        l.textAlignment = .center
        l.text = "החלק לאישור או דחייה"
        l.alpha = 0.6
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupSwipeGestures()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupSwipeGestures()
    }

    // MARK: - Setup

    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(glassBackground)
        glassBackground.addSubview(avatarRing)
        glassBackground.addSubview(nameLabel)
        glassBackground.addSubview(subtitleLabel)
        glassBackground.addSubview(buttonsStack)
        glassBackground.addSubview(swipeHintLabel)

        buttonsStack.addArrangedSubview(declineButton)
        buttonsStack.addArrangedSubview(acceptButton)

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 110),

            glassBackground.topAnchor.constraint(equalTo: topAnchor),
            glassBackground.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassBackground.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassBackground.bottomAnchor.constraint(equalTo: bottomAnchor),

            avatarRing.topAnchor.constraint(equalTo: glassBackground.topAnchor, constant: 16),
            avatarRing.widthAnchor.constraint(equalToConstant: 56),
            avatarRing.heightAnchor.constraint(equalToConstant: 56),

            nameLabel.topAnchor.constraint(equalTo: glassBackground.topAnchor, constant: 16),

            subtitleLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),

            buttonsStack.bottomAnchor.constraint(equalTo: glassBackground.bottomAnchor, constant: -16),
            buttonsStack.heightAnchor.constraint(equalToConstant: 38),

            swipeHintLabel.centerXAnchor.constraint(equalTo: glassBackground.centerXAnchor),
            swipeHintLabel.bottomAnchor.constraint(equalTo: glassBackground.bottomAnchor, constant: -4),
        ])

        // RTL/LTR specific constraints
        if isRTL {
            // RTL: Avatar on right, text on left
            NSLayoutConstraint.activate([
                avatarRing.trailingAnchor.constraint(equalTo: glassBackground.trailingAnchor, constant: -16),
                nameLabel.trailingAnchor.constraint(equalTo: avatarRing.leadingAnchor, constant: -12),
                nameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: glassBackground.leadingAnchor, constant: 16),
                subtitleLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
                subtitleLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
                buttonsStack.leadingAnchor.constraint(equalTo: glassBackground.leadingAnchor, constant: 16),
                buttonsStack.trailingAnchor.constraint(equalTo: avatarRing.leadingAnchor, constant: -12),
            ])
        } else {
            // LTR: Avatar on left, text on right
            NSLayoutConstraint.activate([
                avatarRing.leadingAnchor.constraint(equalTo: glassBackground.leadingAnchor, constant: 16),
                nameLabel.leadingAnchor.constraint(equalTo: avatarRing.trailingAnchor, constant: 12),
                nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: glassBackground.trailingAnchor, constant: -16),
                subtitleLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
                subtitleLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
                buttonsStack.leadingAnchor.constraint(equalTo: avatarRing.trailingAnchor, constant: 12),
                buttonsStack.trailingAnchor.constraint(equalTo: glassBackground.trailingAnchor, constant: -16),
            ])
        }

        acceptButton.addTarget(self, action: #selector(acceptTapped), for: .touchUpInside)
        declineButton.addTarget(self, action: #selector(declineTapped), for: .touchUpInside)

        // Hide swipe hint after first view
        swipeHintLabel.isHidden = true
    }

    private func setupSwipeGestures() {
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeAccept))
        swipeRight.direction = LocalizationManager.shared.currentLanguage.isRTL ? .left : .right
        addGestureRecognizer(swipeRight)

        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeDecline))
        swipeLeft.direction = LocalizationManager.shared.currentLanguage.isRTL ? .right : .left
        addGestureRecognizer(swipeLeft)
    }

    // MARK: - Configure

    func configure(with request: FriendRequest) {
        self.request = request
        nameLabel.text = request.fromDisplayName
        avatarRing.loadImage(from: request.fromPhotoURL)
    }

    // MARK: - Actions

    @objc private func acceptTapped() {
        guard let request = request else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        playCelebration()
        delegate?.friendRequestView(self, didAcceptRequest: request)
    }

    @objc private func declineTapped() {
        guard let request = request else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        delegate?.friendRequestView(self, didDeclineRequest: request)
    }

    @objc private func handleSwipeAccept() {
        guard let request = request else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // Animate swipe
        UIView.animate(withDuration: 0.3, animations: {
            self.transform = CGAffineTransform(translationX: self.bounds.width, y: 0)
            self.alpha = 0
        }) { _ in
            self.playCelebration()
            self.delegate?.friendRequestView(self, didAcceptRequest: request)
        }
    }

    @objc private func handleSwipeDecline() {
        guard let request = request else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Animate swipe
        UIView.animate(withDuration: 0.3, animations: {
            self.transform = CGAffineTransform(translationX: -self.bounds.width, y: 0)
            self.alpha = 0
        }) { _ in
            self.delegate?.friendRequestView(self, didDeclineRequest: request)
        }
    }

    private func playCelebration() {
        let confetti = ConfettiBurstView(frame: bounds)
        addSubview(confetti)
        confetti.burst()
    }
}

// MARK: - User Card View (for search results and friend list)

final class UserCardView: UIView {

    // MARK: - Properties

    var onActionTapped: (() -> Void)?
    var onCardTapped: (() -> Void)?
    private var isLoading = false

    // MARK: - UI Elements

    private let glassBackground: GlassMorphismView = {
        let view = GlassMorphismView()
        view.cornerRadius = AIONDesign.cornerRadius
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let avatarRing: AvatarRingView = {
        let view = AvatarRingView(size: 48)
        view.ringWidth = 2
        view.isAnimated = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let statusIndicator: PulsingStatusIndicator = {
        let view = PulsingStatusIndicator(size: 12)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .semibold)
        l.textColor = AIONDesign.textPrimary
        l.textAlignment = LocalizationManager.shared.textAlignment
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let statusLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13, weight: .medium)
        l.textColor = AIONDesign.textSecondary
        l.textAlignment = LocalizationManager.shared.textAlignment
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let actionButton: UIButton = {
        let b = UIButton(type: .system)
        b.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        b.layer.cornerRadius = AIONDesign.cornerRadiusSmall
        b.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.hidesWhenStopped = true
        ai.color = AIONDesign.accentPrimary
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
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(glassBackground)
        glassBackground.addSubview(avatarRing)
        glassBackground.addSubview(statusIndicator)
        glassBackground.addSubview(nameLabel)
        glassBackground.addSubview(statusLabel)
        glassBackground.addSubview(actionButton)
        glassBackground.addSubview(activityIndicator)

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 76),

            glassBackground.topAnchor.constraint(equalTo: topAnchor),
            glassBackground.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassBackground.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassBackground.bottomAnchor.constraint(equalTo: bottomAnchor),

            avatarRing.centerYAnchor.constraint(equalTo: glassBackground.centerYAnchor),
            avatarRing.widthAnchor.constraint(equalToConstant: 48),
            avatarRing.heightAnchor.constraint(equalToConstant: 48),

            statusIndicator.bottomAnchor.constraint(equalTo: avatarRing.bottomAnchor, constant: 2),
            statusIndicator.widthAnchor.constraint(equalToConstant: 12),
            statusIndicator.heightAnchor.constraint(equalToConstant: 12),

            nameLabel.topAnchor.constraint(equalTo: glassBackground.topAnchor, constant: 18),

            statusLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),

            actionButton.centerYAnchor.constraint(equalTo: glassBackground.centerYAnchor),
            actionButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 90),
            actionButton.heightAnchor.constraint(equalToConstant: 34),

            activityIndicator.centerXAnchor.constraint(equalTo: actionButton.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: actionButton.centerYAnchor),
        ])

        // RTL/LTR specific constraints
        if isRTL {
            // RTL: Avatar on right, button on left
            NSLayoutConstraint.activate([
                avatarRing.trailingAnchor.constraint(equalTo: glassBackground.trailingAnchor, constant: -16),
                statusIndicator.trailingAnchor.constraint(equalTo: avatarRing.trailingAnchor, constant: 2),
                nameLabel.trailingAnchor.constraint(equalTo: avatarRing.leadingAnchor, constant: -12),
                nameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: actionButton.trailingAnchor, constant: 12),
                statusLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
                actionButton.leadingAnchor.constraint(equalTo: glassBackground.leadingAnchor, constant: 16),
            ])
        } else {
            // LTR: Avatar on left, button on right
            NSLayoutConstraint.activate([
                avatarRing.leadingAnchor.constraint(equalTo: glassBackground.leadingAnchor, constant: 16),
                statusIndicator.leadingAnchor.constraint(equalTo: avatarRing.trailingAnchor, constant: -14),
                nameLabel.leadingAnchor.constraint(equalTo: avatarRing.trailingAnchor, constant: 12),
                nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: actionButton.leadingAnchor, constant: -12),
                statusLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
                actionButton.trailingAnchor.constraint(equalTo: glassBackground.trailingAnchor, constant: -16),
            ])
        }

        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)

        // Tap gesture for entire card
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(cardTapped))
        addGestureRecognizer(tapGesture)
    }

    // MARK: - Configure for Search Result

    func configure(with result: UserSearchResult) {
        nameLabel.text = result.displayName
        avatarRing.loadImage(from: result.photoURL)
        statusIndicator.isHidden = true

        if result.isFriend {
            statusLabel.text = "social.alreadyFriends".localized
            statusLabel.textColor = AIONDesign.accentSuccess
            actionButton.isHidden = true
            avatarRing.ringColors = [AIONDesign.accentSuccess, AIONDesign.accentSecondary]
        } else if result.hasPendingRequest {
            if result.requestSentByMe {
                statusLabel.text = "social.requestPending".localized
                statusLabel.textColor = AIONDesign.accentWarning
                actionButton.isHidden = true
                avatarRing.ringColors = [AIONDesign.accentWarning, AIONDesign.accentPrimary]
            } else {
                statusLabel.text = "social.sentYouRequest".localized
                statusLabel.textColor = AIONDesign.accentPrimary
                configureActionButton(title: "social.accept".localized, style: .primary)
                avatarRing.ringColors = [AIONDesign.accentPrimary, AIONDesign.accentSecondary]
                avatarRing.isAnimated = true
            }
        } else {
            if let tierName = result.carTierName, !tierName.isEmpty {
                let tier = result.carTierIndex.flatMap { CarTierEngine.tiers[safe: $0] }
                let emoji = tier?.emoji ?? "🚗"
                let color = tier?.color ?? AIONDesign.textSecondary
                statusLabel.text = "\(emoji) \(tierName)"
                statusLabel.textColor = color
                avatarRing.ringColors = [color, AIONDesign.accentSecondary]
            } else {
                statusLabel.text = ""
                avatarRing.ringColors = [AIONDesign.accentPrimary, AIONDesign.accentSecondary]
            }
            configureActionButton(title: "social.sendRequest".localized, style: .secondary)
        }
    }

    // MARK: - Configure for Friend

    func configure(with friend: Friend) {
        nameLabel.text = friend.displayName
        avatarRing.loadImage(from: friend.photoURL)
        statusIndicator.isHidden = false
        statusIndicator.isOnline = true // Could be dynamic based on actual status

        if let tierName = friend.carTierName, !tierName.isEmpty {
            let tier = friend.carTierIndex.flatMap { CarTierEngine.tiers[safe: $0] }
            let emoji = tier?.emoji ?? "🚗"
            let color = tier?.color ?? AIONDesign.textSecondary
            statusLabel.text = "\(emoji) \(tierName)"
            statusLabel.textColor = color
            avatarRing.ringColors = [color, AIONDesign.accentSecondary]
        } else {
            statusLabel.text = ""
            avatarRing.ringColors = [AIONDesign.accentSuccess, AIONDesign.accentSecondary]
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
            actionButton.backgroundColor = AIONDesign.surfaceElevated.withAlphaComponent(0.5)
            actionButton.setTitleColor(AIONDesign.accentPrimary, for: .normal)
            actionButton.layer.borderWidth = 1.5
            actionButton.layer.borderColor = AIONDesign.accentPrimary.cgColor
        case .destructive:
            actionButton.backgroundColor = AIONDesign.surfaceElevated.withAlphaComponent(0.5)
            actionButton.setTitleColor(AIONDesign.accentDanger, for: .normal)
            actionButton.layer.borderWidth = 1.5
            actionButton.layer.borderColor = AIONDesign.accentDanger.cgColor
        }
    }

    // MARK: - Loading State

    func setLoading(_ loading: Bool) {
        isLoading = loading
        actionButton.isEnabled = !loading

        UIView.animate(withDuration: AIONDesign.animationFast) {
            self.actionButton.alpha = loading ? 0 : 1
        }

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
        springAnimation { [weak self] in
            self?.onActionTapped?()
        }
    }

    @objc private func cardTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        springAnimation { [weak self] in
            self?.onCardTapped?()
        }
    }

    // MARK: - Touch Feedback

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        UIView.animate(withDuration: 0.1) {
            self.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            usingSpringWithDamping: AIONDesign.springDampingBouncy,
            initialSpringVelocity: AIONDesign.springVelocity
        ) {
            self.transform = .identity
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        UIView.animate(withDuration: 0.2) {
            self.transform = .identity
        }
    }
}

// MARK: - Array Safe Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
