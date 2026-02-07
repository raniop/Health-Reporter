//
//  SocialComponents.swift
//  Health Reporter
//
//  Styled components for Social Hub and Leaderboard screens
//

import UIKit

// MARK: - GlassMorphismView

/// Component with frosted glass effect (Glass Morphism)
class GlassMorphismView: UIView {

    private let blurView: UIVisualEffectView = {
        let blur = UIBlurEffect(style: AIONDesign.glassBlurStyle)
        let view = UIVisualEffectView(effect: blur)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let tintOverlay: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    var glassTintColor: UIColor = AIONDesign.accentPrimary {
        didSet { updateTint() }
    }

    var cornerRadius: CGFloat = AIONDesign.cornerRadius {
        didSet { updateCornerRadius() }
    }

    var borderColors: [UIColor]? {
        didSet { updateBorder() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        clipsToBounds = true

        addSubview(blurView)
        blurView.contentView.addSubview(tintOverlay)

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            tintOverlay.topAnchor.constraint(equalTo: blurView.contentView.topAnchor),
            tintOverlay.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor),
            tintOverlay.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor),
            tintOverlay.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor),
        ])

        updateTint()
        updateCornerRadius()
        applyShadow(.medium)
    }

    private func updateTint() {
        tintOverlay.backgroundColor = glassTintColor.withAlphaComponent(AIONDesign.glassTintAlpha)
    }

    private func updateCornerRadius() {
        layer.cornerRadius = cornerRadius
    }

    private func updateBorder() {
        if let colors = borderColors {
            addGradientBorder(colors: colors, width: 1.5, cornerRadius: cornerRadius)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if borderColors != nil {
            updateBorder()
        }
    }
}

// MARK: - GradientButton

/// Button with gradient and press effects
final class GradientButton: UIButton {

    private let gradientLayer = CAGradientLayer()

    var gradientColors: [UIColor] = [AIONDesign.accentPrimary, AIONDesign.accentSuccess] {
        didSet { updateGradient() }
    }

    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                UIView.animate(withDuration: 0.1) {
                    self.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
                    self.alpha = 0.9
                }
            } else {
                UIView.animate(
                    withDuration: 0.3,
                    delay: 0,
                    usingSpringWithDamping: AIONDesign.springDampingBouncy,
                    initialSpringVelocity: AIONDesign.springVelocity
                ) {
                    self.transform = .identity
                    self.alpha = 1.0
                }
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }

    private func setupButton() {
        layer.insertSublayer(gradientLayer, at: 0)
        clipsToBounds = true

        setTitleColor(.white, for: .normal)
        titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)

        updateGradient()
        applyShadow(.small)
    }

    private func updateGradient() {
        gradientLayer.colors = gradientColors.map { $0.cgColor }
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        // Use cornerRadius that fits button height - max cornerRadiusLarge, min cornerRadiusSmall
        let radius = min(AIONDesign.cornerRadius, bounds.height / 2)
        layer.cornerRadius = radius
        gradientLayer.cornerRadius = radius
    }
}

// MARK: - AvatarRingView

/// Profile image with a glowing ring around it
final class AvatarRingView: UIView {

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = AIONDesign.surfaceElevated
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let ringLayer = CAGradientLayer()
    private let ringMask = CAShapeLayer()

    var image: UIImage? {
        didSet { imageView.image = image }
    }

    var ringColors: [UIColor] = [AIONDesign.accentPrimary, AIONDesign.accentSecondary, AIONDesign.accentSuccess] {
        didSet { updateRing() }
    }

    var ringWidth: CGFloat = 3 {
        didSet { setNeedsLayout() }
    }

    var isAnimated: Bool = false {
        didSet { updateAnimation() }
    }

    var placeholderIcon: String = "person.fill" {
        didSet { updatePlaceholder() }
    }

    private var avatarSize: CGFloat = 48

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    convenience init(size: CGFloat) {
        self.init(frame: CGRect(x: 0, y: 0, width: size, height: size))
        self.avatarSize = size
    }

    private func setupView() {
        layer.addSublayer(ringLayer)
        addSubview(imageView)

        ringLayer.colors = ringColors.map { $0.cgColor }
        ringLayer.startPoint = CGPoint(x: 0, y: 0)
        ringLayer.endPoint = CGPoint(x: 1, y: 1)
        ringLayer.mask = ringMask
        ringMask.fillColor = UIColor.clear.cgColor
        ringMask.strokeColor = UIColor.white.cgColor
        ringMask.lineWidth = ringWidth

        updatePlaceholder()
    }

    private func updatePlaceholder() {
        if imageView.image == nil {
            let config = UIImage.SymbolConfiguration(pointSize: avatarSize * 0.4, weight: .medium)
            imageView.image = UIImage(systemName: placeholderIcon, withConfiguration: config)
            imageView.tintColor = AIONDesign.textTertiary
        }
    }

    private func updateRing() {
        ringLayer.colors = ringColors.map { $0.cgColor }
    }

    private func updateAnimation() {
        ringLayer.removeAllAnimations()
        if isAnimated {
            let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
            rotation.fromValue = 0
            rotation.toValue = Double.pi * 2
            rotation.duration = 3.0
            rotation.repeatCount = .infinity
            ringLayer.add(rotation, forKey: "rotation")
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let size = min(bounds.width, bounds.height)
        avatarSize = size

        ringLayer.frame = bounds
        let ringPath = UIBezierPath(ovalIn: bounds.insetBy(dx: ringWidth / 2, dy: ringWidth / 2))
        ringMask.path = ringPath.cgPath
        ringMask.lineWidth = ringWidth

        let imageInset = ringWidth + 2
        imageView.frame = bounds.insetBy(dx: imageInset, dy: imageInset)
        imageView.layer.cornerRadius = imageView.bounds.width / 2
    }

    func loadImage(from urlString: String?) {
        guard let urlString = urlString, let url = URL(string: urlString) else {
            updatePlaceholder()
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.image = image
            }
        }.resume()
    }
}

// MARK: - PulsingStatusIndicator

/// Status indicator with pulse animation
final class PulsingStatusIndicator: UIView {

    var isOnline: Bool = true {
        didSet { updateStatus() }
    }

    var statusColor: UIColor = AIONDesign.accentSuccess {
        didSet { updateStatus() }
    }

    private let dotView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let pulseLayer = CALayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    convenience init(size: CGFloat = 12) {
        self.init(frame: CGRect(x: 0, y: 0, width: size, height: size))
    }

    private func setupView() {
        addSubview(dotView)

        NSLayoutConstraint.activate([
            dotView.centerXAnchor.constraint(equalTo: centerXAnchor),
            dotView.centerYAnchor.constraint(equalTo: centerYAnchor),
            dotView.widthAnchor.constraint(equalTo: widthAnchor),
            dotView.heightAnchor.constraint(equalTo: heightAnchor),
        ])

        updateStatus()
    }

    private func updateStatus() {
        let color = isOnline ? statusColor : AIONDesign.textTertiary
        dotView.backgroundColor = color

        pulseLayer.removeAllAnimations()
        if isOnline {
            startPulse()
        }
    }

    private func startPulse() {
        pulseLayer.backgroundColor = statusColor.cgColor
        pulseLayer.opacity = 0
        layer.insertSublayer(pulseLayer, below: dotView.layer)

        let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
        scaleAnim.fromValue = 1.0
        scaleAnim.toValue = 2.0

        let opacityAnim = CABasicAnimation(keyPath: "opacity")
        opacityAnim.fromValue = 0.6
        opacityAnim.toValue = 0.0

        let group = CAAnimationGroup()
        group.animations = [scaleAnim, opacityAnim]
        group.duration = 1.5
        group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)

        pulseLayer.add(group, forKey: "pulse")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        dotView.layer.cornerRadius = bounds.width / 2
        pulseLayer.frame = bounds
        pulseLayer.cornerRadius = bounds.width / 2
    }
}

// MARK: - AnimatedTabBarControl

/// Custom tab bar with animations
final class AnimatedTabBarControl: UIView {

    struct TabItem {
        let title: String
        let icon: String?
    }

    private var items: [TabItem] = []
    private var buttons: [UIButton] = []
    private let indicatorView = UIView()
    private let stackView = UIStackView()

    var selectedIndex: Int = 0 {
        didSet {
            updateSelection(animated: true)
            onSelectionChanged?(selectedIndex)
        }
    }

    var onSelectionChanged: ((Int) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    convenience init(items: [TabItem]) {
        self.init(frame: .zero)
        self.items = items
        setupButtons()
    }

    convenience init(titles: [String]) {
        let tabItems = titles.map { TabItem(title: $0, icon: nil) }
        self.init(items: tabItems)
    }

    private var hasLayoutOnce = false

    private func setupView() {
        backgroundColor = AIONDesign.surfaceElevated.withAlphaComponent(0.5)
        layer.cornerRadius = AIONDesign.cornerRadius

        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        // Indicator with gradient
        indicatorView.layer.cornerRadius = AIONDesign.cornerRadius - 4
        indicatorView.clipsToBounds = true
        let gradient = CAGradientLayer()
        gradient.colors = AIONDesign.primaryGradient
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        indicatorView.layer.insertSublayer(gradient, at: 0)
        indicatorView.alpha = 0.9
        insertSubview(indicatorView, at: 0)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
    }

    private func setupButtons() {
        buttons.forEach { $0.removeFromSuperview() }
        buttons.removeAll()

        for (index, item) in items.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(item.title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
            button.setTitleColor(AIONDesign.textSecondary, for: .normal)
            button.tag = index
            button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)

            if let iconName = item.icon {
                let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
                button.setImage(UIImage(systemName: iconName, withConfiguration: config), for: .normal)
                button.tintColor = AIONDesign.textSecondary
            }

            buttons.append(button)
            stackView.addArrangedSubview(button)
        }

        updateSelection(animated: false)
    }

    @objc private func buttonTapped(_ sender: UIButton) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        selectedIndex = sender.tag
    }

    private func updateSelection(animated: Bool) {
        guard !buttons.isEmpty else { return }

        let duration = animated ? AIONDesign.animationMedium : 0

        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: AIONDesign.springDamping,
            initialSpringVelocity: AIONDesign.springVelocity
        ) {
            for (index, button) in self.buttons.enumerated() {
                let isSelected = index == self.selectedIndex
                button.setTitleColor(isSelected ? .white : AIONDesign.textSecondary, for: .normal)
                button.tintColor = isSelected ? .white : AIONDesign.textSecondary
                button.transform = isSelected ? CGAffineTransform(scaleX: 1.02, y: 1.02) : .identity
            }
        }

        layoutIndicator(animated: animated)
    }

    private func layoutIndicator(animated: Bool) {
        guard !buttons.isEmpty, selectedIndex < buttons.count else { return }

        let selectedButton = buttons[selectedIndex]
        // Convert button frame to self's coordinate system
        let buttonFrameInSelf = stackView.convert(selectedButton.frame, to: self)
        // Inset slightly for better appearance
        let indicatorFrame = CGRect(
            x: buttonFrameInSelf.origin.x,
            y: buttonFrameInSelf.origin.y,
            width: buttonFrameInSelf.width,
            height: buttonFrameInSelf.height
        )

        let duration = animated ? AIONDesign.animationMedium : 0

        if animated {
            UIView.animate(
                withDuration: duration,
                delay: 0,
                usingSpringWithDamping: AIONDesign.springDamping,
                initialSpringVelocity: AIONDesign.springVelocity
            ) {
                self.indicatorView.frame = indicatorFrame
                self.updateIndicatorGradient()
            }
        } else {
            indicatorView.frame = indicatorFrame
            updateIndicatorGradient()
        }
    }

    private func updateIndicatorGradient() {
        // Update gradient frame to match indicator
        if let gradient = indicatorView.layer.sublayers?.first as? CAGradientLayer {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            gradient.frame = indicatorView.bounds
            CATransaction.commit()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Force layout indicator on first layout pass
        if !hasLayoutOnce && !buttons.isEmpty {
            hasLayoutOnce = true
            // Delay slightly to ensure stackView has laid out its subviews
            DispatchQueue.main.async { [weak self] in
                self?.layoutIndicator(animated: false)
            }
        } else {
            layoutIndicator(animated: false)
        }
    }

    func setItems(_ newItems: [TabItem]) {
        items = newItems
        hasLayoutOnce = false
        setupButtons()
    }
}

// MARK: - RankBadgeView

/// Rank badge with medal design for top three
final class RankBadgeView: UIView {

    enum Style {
        case gold, silver, bronze, standard

        var gradient: [CGColor] {
            switch self {
            case .gold: return AIONDesign.goldGradient
            case .silver: return AIONDesign.silverGradient
            case .bronze: return AIONDesign.bronzeGradient
            case .standard: return [AIONDesign.surfaceElevated.cgColor, AIONDesign.surfaceElevated.cgColor]
            }
        }

        var emoji: String? {
            switch self {
            case .gold: return "🥇"
            case .silver: return "🥈"
            case .bronze: return "🥉"
            case .standard: return nil
            }
        }
    }

    private let gradientLayer = CAGradientLayer()
    private let shineLayer = CAGradientLayer()
    private let rankLabel = UILabel()

    var rank: Int = 1 {
        didSet { updateRank() }
    }

    var style: Style = .standard {
        didSet { updateStyle() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        layer.insertSublayer(gradientLayer, at: 0)
        layer.addSublayer(shineLayer)

        rankLabel.font = .systemFont(ofSize: 16, weight: .bold)
        rankLabel.textAlignment = .center
        rankLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rankLabel)

        NSLayoutConstraint.activate([
            rankLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            rankLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        layer.cornerRadius = AIONDesign.cornerRadiusSmall
        clipsToBounds = true

        // Shine layer setup
        shineLayer.colors = [
            UIColor.white.withAlphaComponent(0).cgColor,
            UIColor.white.withAlphaComponent(0.4).cgColor,
            UIColor.white.withAlphaComponent(0).cgColor
        ]
        shineLayer.startPoint = CGPoint(x: 0, y: 0.5)
        shineLayer.endPoint = CGPoint(x: 1, y: 0.5)
        shineLayer.locations = [0, 0.5, 1]
        shineLayer.opacity = 0

        updateStyle()
        updateRank()
    }

    private func updateRank() {
        if let emoji = style.emoji {
            rankLabel.text = emoji
        } else {
            rankLabel.text = "#\(rank)"
            rankLabel.textColor = AIONDesign.textPrimary
        }
    }

    private func updateStyle() {
        gradientLayer.colors = style.gradient
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)

        if style != .standard {
            startShineAnimation()
        } else {
            shineLayer.removeAllAnimations()
            shineLayer.opacity = 0
        }

        updateRank()
    }

    private func startShineAnimation() {
        shineLayer.opacity = 1

        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [-0.5, 0, 0.5]
        animation.toValue = [0.5, 1, 1.5]
        animation.duration = 2.0
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        shineLayer.add(animation, forKey: "shine")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        shineLayer.frame = bounds
    }

    func configure(rank: Int) {
        self.rank = rank
        switch rank {
        case 1: style = .gold
        case 2: style = .silver
        case 3: style = .bronze
        default: style = .standard
        }
    }
}

// MARK: - ProgressToNextRankView

/// Progress bar to next rank
final class ProgressToNextRankView: UIView {

    private let progressTrack: UIView = {
        let view = UIView()
        view.backgroundColor = AIONDesign.surfaceElevated
        view.layer.cornerRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let progressFill: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 4
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let gradientLayer = CAGradientLayer()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = AIONDesign.textSecondary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private var fillWidthConstraint: NSLayoutConstraint?

    var currentScore: Int = 0
    var nextRankScore: Int = 100
    var pointsToNext: Int = 10 {
        didSet { updateProgress() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        addSubview(messageLabel)
        addSubview(progressTrack)
        progressTrack.addSubview(progressFill)

        // Gradient for progress fill
        gradientLayer.colors = AIONDesign.successGradient
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        progressFill.layer.insertSublayer(gradientLayer, at: 0)

        fillWidthConstraint = progressFill.widthAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            messageLabel.topAnchor.constraint(equalTo: topAnchor),
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor),

            progressTrack.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 8),
            progressTrack.leadingAnchor.constraint(equalTo: leadingAnchor),
            progressTrack.trailingAnchor.constraint(equalTo: trailingAnchor),
            progressTrack.heightAnchor.constraint(equalToConstant: 8),
            progressTrack.bottomAnchor.constraint(equalTo: bottomAnchor),

            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),
            fillWidthConstraint!,
        ])

        updateProgress()
    }

    private func updateProgress() {
        let progress = CGFloat(currentScore) / CGFloat(nextRankScore)
        messageLabel.text = String(format: "social.pointsToNextRank".localized, pointsToNext)

        layoutIfNeeded()
        let targetWidth = progressTrack.bounds.width * min(progress, 1.0)

        UIView.animate(withDuration: AIONDesign.animationSlow, delay: 0, options: .curveEaseOut) {
            self.fillWidthConstraint?.constant = targetWidth
            self.layoutIfNeeded()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = progressFill.bounds
    }

    func configure(current: Int, nextRank: Int, pointsNeeded: Int) {
        currentScore = current
        nextRankScore = nextRank
        pointsToNext = pointsNeeded
    }
}

// MARK: - PodiumView

/// Podium for top three in Leaderboard
final class PodiumView: UIView {

    struct Entry {
        let uid: String
        let rank: Int
        let name: String
        let photoURL: String?
        let score: Int
        let isCurrentUser: Bool
    }

    var onUserTapped: ((String) -> Void)?

    private let secondPlaceView = PodiumPlaceView(rank: 2)
    private let firstPlaceView = PodiumPlaceView(rank: 1)
    private let thirdPlaceView = PodiumPlaceView(rank: 3)

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .bottom
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        addSubview(stackView)

        // Order: 2nd, 1st, 3rd (first place in center and tallest)
        stackView.addArrangedSubview(secondPlaceView)
        stackView.addArrangedSubview(firstPlaceView)
        stackView.addArrangedSubview(thirdPlaceView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),

            firstPlaceView.heightAnchor.constraint(equalToConstant: 185),
            secondPlaceView.heightAnchor.constraint(equalToConstant: 145),
            thirdPlaceView.heightAnchor.constraint(equalToConstant: 105),
        ])

        // Setup tap handlers
        firstPlaceView.onTapped = { [weak self] uid in self?.onUserTapped?(uid) }
        secondPlaceView.onTapped = { [weak self] uid in self?.onUserTapped?(uid) }
        thirdPlaceView.onTapped = { [weak self] uid in self?.onUserTapped?(uid) }
    }

    func configure(first: Entry?, second: Entry?, third: Entry?) {
        if let first = first {
            firstPlaceView.configure(with: first)
        }
        if let second = second {
            secondPlaceView.configure(with: second)
        }
        if let third = third {
            thirdPlaceView.configure(with: third)
        }
    }

    func animateEntrance() {
        // Reset positions
        [secondPlaceView, firstPlaceView, thirdPlaceView].forEach {
            $0.alpha = 0
            $0.transform = CGAffineTransform(translationX: 0, y: 50)
        }

        // Animate with stagger
        let views = [firstPlaceView, secondPlaceView, thirdPlaceView]
        for (index, view) in views.enumerated() {
            UIView.animate(
                withDuration: 0.6,
                delay: Double(index) * 0.15,
                usingSpringWithDamping: 0.7,
                initialSpringVelocity: 0.5
            ) {
                view.alpha = 1
                view.transform = .identity
            }
        }
    }
}

// MARK: - PodiumPlaceView

/// Single podium place view
private final class PodiumPlaceView: UIView {

    private let rank: Int
    private var uid: String?
    var onTapped: ((String) -> Void)?

    private let pedestalView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = AIONDesign.cornerRadius
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let avatarRing: AvatarRingView = {
        let view = AvatarRingView(size: 56)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let badgeView: RankBadgeView = {
        let view = RankBadgeView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = AIONDesign.textPrimary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let scoreLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textColor = AIONDesign.accentPrimary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    init(rank: Int) {
        self.rank = rank
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) {
        self.rank = 1
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        addSubview(pedestalView)
        addSubview(avatarRing)
        addSubview(badgeView)
        addSubview(nameLabel)
        addSubview(scoreLabel)

        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
        isUserInteractionEnabled = true

        // Configure based on rank
        let style: RankBadgeView.Style
        let pedestalColor: UIColor
        let ringColors: [UIColor]

        switch rank {
        case 1:
            style = .gold
            pedestalColor = UIColor(hex: "#FFD700")!.withAlphaComponent(0.3)
            ringColors = [UIColor(hex: "#FFD700")!, UIColor(hex: "#FFA500")!]
            avatarRing.isAnimated = true
        case 2:
            style = .silver
            pedestalColor = UIColor(hex: "#C0C0C0")!.withAlphaComponent(0.3)
            ringColors = [UIColor(hex: "#C0C0C0")!, UIColor(hex: "#A8A8A8")!]
            avatarRing.isAnimated = false
        case 3:
            style = .bronze
            pedestalColor = UIColor(hex: "#CD7F32")!.withAlphaComponent(0.3)
            ringColors = [UIColor(hex: "#CD7F32")!, UIColor(hex: "#8B4513")!]
            avatarRing.isAnimated = false
        default:
            style = .standard
            pedestalColor = AIONDesign.surfaceElevated
            ringColors = [AIONDesign.accentPrimary, AIONDesign.accentSecondary]
            avatarRing.isAnimated = false
        }

        badgeView.style = style
        badgeView.rank = rank
        pedestalView.backgroundColor = pedestalColor
        avatarRing.ringColors = ringColors

        // Pedestal height: name (16) + gap (4) + score (22) + padding (8+8) = 58
        let pedestalHeight: CGFloat = rank == 1 ? 100 : (rank == 2 ? 80 : 60)

        NSLayoutConstraint.activate([
            pedestalView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pedestalView.trailingAnchor.constraint(equalTo: trailingAnchor),
            pedestalView.bottomAnchor.constraint(equalTo: bottomAnchor),
            pedestalView.heightAnchor.constraint(equalToConstant: pedestalHeight),

            // Avatar positioned above pedestal
            avatarRing.centerXAnchor.constraint(equalTo: centerXAnchor),
            avatarRing.bottomAnchor.constraint(equalTo: pedestalView.topAnchor, constant: 0),
            avatarRing.widthAnchor.constraint(equalToConstant: 56),
            avatarRing.heightAnchor.constraint(equalToConstant: 56),

            // Badge at bottom-right of avatar
            badgeView.trailingAnchor.constraint(equalTo: avatarRing.trailingAnchor, constant: 4),
            badgeView.bottomAnchor.constraint(equalTo: avatarRing.bottomAnchor, constant: 4),
            badgeView.widthAnchor.constraint(equalToConstant: 24),
            badgeView.heightAnchor.constraint(equalToConstant: 24),

            // Name inside pedestal - with fixed height
            nameLabel.topAnchor.constraint(equalTo: pedestalView.topAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            nameLabel.heightAnchor.constraint(equalToConstant: 16),

            // Score below name - with fixed height
            scoreLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            scoreLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            scoreLabel.heightAnchor.constraint(equalToConstant: 22),
        ])
    }

    func configure(with entry: PodiumView.Entry) {
        uid = entry.uid
        avatarRing.loadImage(from: entry.photoURL)
        nameLabel.text = entry.name
        scoreLabel.text = "\(entry.score)"

        if entry.isCurrentUser {
            applyGlowEffect(color: AIONDesign.accentPrimary, radius: 10, opacity: 0.5)
        }
    }

    @objc private func handleTap() {
        guard let uid = uid else { return }
        onTapped?(uid)
    }
}

// MARK: - Confetti Burst

/// Confetti animation for celebrations
final class ConfettiBurstView: UIView {

    private let emitterLayer = CAEmitterLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isUserInteractionEnabled = false
    }

    func burst(duration: TimeInterval = 1.5) {
        emitterLayer.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
        emitterLayer.emitterShape = .point

        let colors: [UIColor] = [
            AIONDesign.accentPrimary,
            AIONDesign.accentSecondary,
            AIONDesign.accentSuccess,
            .systemYellow,
            .systemPink
        ]

        var cells: [CAEmitterCell] = []
        for color in colors {
            let cell = CAEmitterCell()
            cell.birthRate = 20
            cell.lifetime = 2.0
            cell.velocity = 200
            cell.velocityRange = 100
            cell.emissionLongitude = .pi
            cell.emissionRange = .pi * 2
            cell.spin = 3.0
            cell.spinRange = 6.0
            cell.scale = 0.1
            cell.scaleRange = 0.05
            cell.color = color.cgColor
            cell.contents = createConfettiImage().cgImage
            cells.append(cell)
        }

        emitterLayer.emitterCells = cells
        layer.addSublayer(emitterLayer)

        // Stop emitting after a short burst
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.emitterLayer.birthRate = 0
        }

        // Remove layer after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            self.emitterLayer.removeFromSuperlayer()
        }
    }

    private func createConfettiImage() -> UIImage {
        let size = CGSize(width: 12, height: 12)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        let path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 2)
        UIColor.white.setFill()
        path.fill()
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
}

// MARK: - RivalComparisonCard

/// Comparison card between user and rival (friend with similar score)
final class RivalComparisonCard: UIView {

    var onTapped: (() -> Void)?

    private let glassBackground: GlassMorphismView = {
        let view = GlassMorphismView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let avatarRing: AvatarRingView = {
        let view = AvatarRingView(size: 44)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = AIONDesign.textPrimary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let comparisonBarContainer: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 4
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let userBarView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let rivalBarView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private var userBarWidthConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(glassBackground)
        addSubview(avatarRing)
        addSubview(nameLabel)
        addSubview(comparisonBarContainer)
        comparisonBarContainer.addSubview(userBarView)
        comparisonBarContainer.addSubview(rivalBarView)
        addSubview(statusLabel)

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL
        semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        nameLabel.textAlignment = LocalizationManager.shared.textAlignment

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)

        let userBarWidth = userBarView.widthAnchor.constraint(equalToConstant: 0)
        userBarWidthConstraint = userBarWidth

        NSLayoutConstraint.activate([
            glassBackground.topAnchor.constraint(equalTo: topAnchor),
            glassBackground.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassBackground.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassBackground.bottomAnchor.constraint(equalTo: bottomAnchor),

            avatarRing.topAnchor.constraint(equalTo: topAnchor, constant: AIONDesign.spacing),
            avatarRing.centerXAnchor.constraint(equalTo: centerXAnchor),
            avatarRing.widthAnchor.constraint(equalToConstant: 44),
            avatarRing.heightAnchor.constraint(equalToConstant: 44),

            nameLabel.topAnchor.constraint(equalTo: avatarRing.bottomAnchor, constant: AIONDesign.spacingSmall),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: AIONDesign.spacingSmall),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -AIONDesign.spacingSmall),

            comparisonBarContainer.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: AIONDesign.spacingSmall),
            comparisonBarContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: AIONDesign.spacing),
            comparisonBarContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -AIONDesign.spacing),
            comparisonBarContainer.heightAnchor.constraint(equalToConstant: 8),

            userBarView.topAnchor.constraint(equalTo: comparisonBarContainer.topAnchor),
            userBarView.leadingAnchor.constraint(equalTo: isRTL ? comparisonBarContainer.trailingAnchor : comparisonBarContainer.leadingAnchor),
            userBarView.bottomAnchor.constraint(equalTo: comparisonBarContainer.bottomAnchor),
            userBarWidth,

            rivalBarView.topAnchor.constraint(equalTo: comparisonBarContainer.topAnchor),
            rivalBarView.trailingAnchor.constraint(equalTo: isRTL ? comparisonBarContainer.leadingAnchor : comparisonBarContainer.trailingAnchor),
            rivalBarView.bottomAnchor.constraint(equalTo: comparisonBarContainer.bottomAnchor),
            rivalBarView.leadingAnchor.constraint(equalTo: isRTL ? comparisonBarContainer.leadingAnchor : userBarView.trailingAnchor),

            statusLabel.topAnchor.constraint(equalTo: comparisonBarContainer.bottomAnchor, constant: AIONDesign.spacingSmall),
            statusLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: AIONDesign.spacingSmall),
            statusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -AIONDesign.spacingSmall),
            statusLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -AIONDesign.spacing),

            widthAnchor.constraint(equalToConstant: 160),
        ])
    }

    @objc private func handleTap() {
        UIView.animate(
            withDuration: AIONDesign.animationFast,
            delay: 0,
            usingSpringWithDamping: AIONDesign.springDamping,
            initialSpringVelocity: AIONDesign.springVelocity
        ) {
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        } completion: { _ in
            UIView.animate(
                withDuration: AIONDesign.animationFast,
                delay: 0,
                usingSpringWithDamping: AIONDesign.springDamping,
                initialSpringVelocity: AIONDesign.springVelocity
            ) {
                self.transform = .identity
            }
        }
        onTapped?()
    }

    func configure(rivalName: String, rivalPhotoURL: String?, rivalScore: Int, userScore: Int, rivalCarTierIndex: Int?) {
        nameLabel.text = rivalName
        avatarRing.loadImage(from: rivalPhotoURL)

        let totalScore = max(userScore + rivalScore, 1)
        let userProportion = CGFloat(userScore) / CGFloat(totalScore)

        if userScore > rivalScore {
            userBarView.backgroundColor = AIONDesign.accentSuccess
            rivalBarView.backgroundColor = AIONDesign.accentSecondary
            let diff = userScore - rivalScore
            statusLabel.text = String(format: "social.rival.youLead".localized, diff)
            statusLabel.textColor = AIONDesign.accentSuccess
        } else if rivalScore > userScore {
            userBarView.backgroundColor = AIONDesign.accentPrimary
            rivalBarView.backgroundColor = AIONDesign.accentWarning
            let diff = rivalScore - userScore
            statusLabel.text = String(format: "social.rival.ahead".localized, diff)
            statusLabel.textColor = AIONDesign.accentWarning
        } else {
            userBarView.backgroundColor = AIONDesign.accentPrimary
            rivalBarView.backgroundColor = AIONDesign.accentPrimary
            statusLabel.text = "social.rival.tied".localized
            statusLabel.textColor = AIONDesign.accentPrimary
        }

        layoutIfNeeded()
        let barWidth = comparisonBarContainer.bounds.width
        let userWidth = barWidth * userProportion

        UIView.animate(withDuration: AIONDesign.animationMedium, delay: 0, options: .curveEaseOut) {
            self.userBarWidthConstraint?.constant = userWidth
            self.layoutIfNeeded()
        }
    }
}

// MARK: - WeeklyBarChart

/// Weekly bar chart - 7 bars for each day of the week
final class WeeklyBarChart: UIView {

    var barHeight: CGFloat = 60

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .bottom
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let labelsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .center
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private var barViews: [UIView] = []
    private var barHeightConstraints: [NSLayoutConstraint] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute

        addSubview(stackView)
        addSubview(labelsStack)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.heightAnchor.constraint(equalToConstant: barHeight),

            labelsStack.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 4),
            labelsStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            labelsStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            labelsStack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        setupBars()
        setupLabels()
    }

    private func setupBars() {
        for _ in 0..<7 {
            let bar = UIView()
            bar.translatesAutoresizingMaskIntoConstraints = false
            bar.backgroundColor = AIONDesign.surface
            bar.layer.cornerRadius = AIONDesign.cornerRadiusSmall / 2
            bar.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            bar.clipsToBounds = true

            let heightConstraint = bar.heightAnchor.constraint(equalToConstant: 4)
            heightConstraint.isActive = true

            stackView.addArrangedSubview(bar)
            barViews.append(bar)
            barHeightConstraints.append(heightConstraint)
        }
    }

    private func setupLabels() {
        let isRTL = LocalizationManager.shared.currentLanguage.isRTL
        let englishDays = ["S", "M", "T", "W", "T", "F", "S"]
        let hebrewDays = ["א", "ב", "ג", "ד", "ה", "ו", "ש"]
        let dayLabels = isRTL ? hebrewDays : englishDays

        for day in dayLabels {
            let label = UILabel()
            label.text = day
            label.font = .systemFont(ofSize: 11, weight: .medium)
            label.textColor = AIONDesign.textTertiary
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            labelsStack.addArrangedSubview(label)
        }
    }

    func configure(scores: [Int]) {
        guard scores.count == 7 else { return }

        layoutIfNeeded()

        for (index, score) in scores.enumerated() {
            guard index < barViews.count else { break }
            let clampedScore = max(0, min(score, 100))
            let height = max(4, barHeight * CGFloat(clampedScore) / 100.0)

            barViews[index].backgroundColor = colorForScore(clampedScore)

            UIView.animate(
                withDuration: AIONDesign.animationMedium,
                delay: Double(index) * 0.05,
                usingSpringWithDamping: AIONDesign.springDamping,
                initialSpringVelocity: AIONDesign.springVelocity
            ) {
                self.barHeightConstraints[index].constant = height
                self.layoutIfNeeded()
            }
        }
    }

    private func colorForScore(_ score: Int) -> UIColor {
        switch score {
        case 82...100: return AIONDesign.accentSuccess
        case 65...81: return AIONDesign.accentSecondary
        case 45...64: return AIONDesign.accentPrimary
        case 25...44: return AIONDesign.accentWarning
        default: return AIONDesign.accentDanger
        }
    }
}

// MARK: - CircularProgressView

/// Circular progress ring with score 0-100
final class CircularProgressView: UIView {

    var score: Int = 0 {
        didSet { updateProgress() }
    }

    var ringWidth: CGFloat = 8 {
        didSet { setNeedsLayout() }
    }

    var size: CGFloat = 100 {
        didSet { invalidateIntrinsicContentSize(); setNeedsLayout() }
    }

    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let gradientLayer = CAGradientLayer()

    private let scoreLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = AIONDesign.textPrimary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let denominatorLabel: UILabel = {
        let label = UILabel()
        label.text = "/100"
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = AIONDesign.textTertiary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override var intrinsicContentSize: CGSize {
        return CGSize(width: size, height: size)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false

        // Track layer (background ring)
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.strokeColor = AIONDesign.surface.cgColor
        trackLayer.lineWidth = ringWidth
        trackLayer.lineCap = .round
        layer.addSublayer(trackLayer)

        // Gradient layer masked by progress shape
        gradientLayer.colors = [AIONDesign.accentPrimary.cgColor, AIONDesign.accentSecondary.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)

        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = UIColor.white.cgColor
        progressLayer.lineWidth = ringWidth
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0

        gradientLayer.mask = progressLayer
        layer.addSublayer(gradientLayer)

        addSubview(scoreLabel)
        addSubview(denominatorLabel)

        NSLayoutConstraint.activate([
            scoreLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            scoreLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -6),

            denominatorLabel.topAnchor.constraint(equalTo: scoreLabel.bottomAnchor, constant: 0),
            denominatorLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size),
        ])

        scoreLabel.text = "0"
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = (min(bounds.width, bounds.height) - ringWidth) / 2

        let startAngle = -CGFloat.pi / 2
        let endAngle = startAngle + CGFloat.pi * 2

        let circularPath = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: true
        )

        trackLayer.path = circularPath.cgPath
        trackLayer.lineWidth = ringWidth

        progressLayer.path = circularPath.cgPath
        progressLayer.lineWidth = ringWidth

        gradientLayer.frame = bounds
    }

    private func updateProgress() {
        let clampedScore = max(0, min(score, 100))
        scoreLabel.text = "\(clampedScore)"

        // Update gradient colors based on score tier
        let tierColors = gradientColorsForScore(clampedScore)
        gradientLayer.colors = tierColors.map { $0.cgColor }

        // Animate stroke
        let targetStrokeEnd = CGFloat(clampedScore) / 100.0
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = progressLayer.strokeEnd
        animation.toValue = targetStrokeEnd
        animation.duration = AIONDesign.animationMedium
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false

        progressLayer.strokeEnd = targetStrokeEnd
        progressLayer.add(animation, forKey: "progressAnimation")
    }

    private func gradientColorsForScore(_ score: Int) -> [UIColor] {
        switch score {
        case 82...100: return [AIONDesign.accentSuccess, AIONDesign.accentSecondary]
        case 65...81: return [AIONDesign.accentSecondary, AIONDesign.accentPrimary]
        case 45...64: return [AIONDesign.accentPrimary, AIONDesign.accentSecondary]
        case 25...44: return [AIONDesign.accentWarning, AIONDesign.accentPrimary]
        default: return [AIONDesign.accentDanger, AIONDesign.accentWarning]
        }
    }
}
