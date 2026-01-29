//
//  CarDiscoveryAnimator.swift
//  Health Reporter
//
//  אנימציות לחווית גילוי הרכב - confetti, typing, counting ועוד
//

import UIKit

// MARK: - Confetti Emitter

final class ConfettiEmitter {

    private weak var containerView: UIView?
    private var emitterLayer: CAEmitterLayer?

    init(in view: UIView) {
        self.containerView = view
    }

    func start() {
        guard let containerView = containerView else { return }

        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: containerView.bounds.midX, y: -20)
        emitter.emitterSize = CGSize(width: containerView.bounds.width, height: 1)
        emitter.emitterShape = .line

        // יצירת חלקיקים בצבעים שונים
        let colors: [UIColor] = [
            UIColor(red: 0.0, green: 0.85, blue: 0.95, alpha: 1.0),  // Cyan
            UIColor(red: 0.6, green: 0.4, blue: 1.0, alpha: 1.0),   // Purple
            UIColor(red: 0.2, green: 0.9, blue: 0.5, alpha: 1.0),   // Green
            UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0),   // Orange
            UIColor.white
        ]

        var cells: [CAEmitterCell] = []

        for color in colors {
            let cell = CAEmitterCell()
            cell.birthRate = 8
            cell.lifetime = 4.0
            cell.velocity = 200
            cell.velocityRange = 50
            cell.emissionLongitude = .pi
            cell.emissionRange = .pi / 4
            cell.spin = 3
            cell.spinRange = 6
            cell.scale = 0.08
            cell.scaleRange = 0.04
            cell.color = color.cgColor
            cell.alphaSpeed = -0.3

            // יצירת תמונת חלקיק עגול
            cell.contents = createConfettiImage(size: CGSize(width: 12, height: 12))?.cgImage

            cells.append(cell)
        }

        emitter.emitterCells = cells
        containerView.layer.addSublayer(emitter)
        self.emitterLayer = emitter

        // עצירה אחרי 3 שניות
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.stop()
        }
    }

    func stop() {
        emitterLayer?.birthRate = 0

        // הסרה מלאה אחרי שכל החלקיקים נעלמו
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
            self?.emitterLayer?.removeFromSuperlayer()
            self?.emitterLayer = nil
        }
    }

    private func createConfettiImage(size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }

        let rect = CGRect(origin: .zero, size: size)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: size.width * 0.3)
        UIColor.white.setFill()
        path.fill()

        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

// MARK: - Particle Background Effect

final class ParticleBackground {

    private weak var containerView: UIView?
    private var emitterLayer: CAEmitterLayer?

    init(in view: UIView) {
        self.containerView = view
    }

    func start() {
        guard let containerView = containerView else { return }

        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: containerView.bounds.midX, y: containerView.bounds.maxY + 20)
        emitter.emitterSize = CGSize(width: containerView.bounds.width, height: 1)
        emitter.emitterShape = .line

        let cell = CAEmitterCell()
        cell.birthRate = 3
        cell.lifetime = 8.0
        cell.velocity = 50
        cell.velocityRange = 20
        cell.emissionLongitude = -.pi / 2  // כלפי מעלה
        cell.emissionRange = .pi / 8
        cell.scale = 0.03
        cell.scaleRange = 0.02
        cell.alphaSpeed = -0.1
        cell.color = UIColor(red: 0.0, green: 0.85, blue: 0.95, alpha: 0.4).cgColor
        cell.contents = createDotImage(size: CGSize(width: 8, height: 8))?.cgImage

        emitter.emitterCells = [cell]
        containerView.layer.insertSublayer(emitter, at: 0)
        self.emitterLayer = emitter
    }

    func stop() {
        emitterLayer?.birthRate = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { [weak self] in
            self?.emitterLayer?.removeFromSuperlayer()
            self?.emitterLayer = nil
        }
    }

    private func createDotImage(size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }

        let rect = CGRect(origin: .zero, size: size)
        let path = UIBezierPath(ovalIn: rect)
        UIColor.white.setFill()
        path.fill()

        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

// MARK: - Typing Animation

final class TypingAnimator {

    private weak var label: UILabel?
    private var fullText: String = ""
    private var currentIndex: Int = 0
    private var timer: Timer?
    private var completion: (() -> Void)?

    init(label: UILabel) {
        self.label = label
    }

    func animate(text: String, duration: TimeInterval = 1.5, completion: (() -> Void)? = nil) {
        self.fullText = text
        self.currentIndex = 0
        self.completion = completion
        label?.text = ""

        let interval = duration / Double(text.count)

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.typeNextCharacter()
        }
    }

    private func typeNextCharacter() {
        guard currentIndex < fullText.count else {
            timer?.invalidate()
            timer = nil
            completion?()
            return
        }

        let index = fullText.index(fullText.startIndex, offsetBy: currentIndex)
        label?.text = String(fullText[...index])
        currentIndex += 1

        // אפקט קול קליק (haptic feedback)
        if currentIndex % 3 == 0 {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        label?.text = fullText
    }
}

// MARK: - Number Counter Animation

final class NumberCounterAnimator {

    private weak var label: UILabel?
    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private var duration: TimeInterval = 0
    private var startValue: Int = 0
    private var endValue: Int = 0
    private var suffix: String = ""
    private var completion: (() -> Void)?

    init(label: UILabel) {
        self.label = label
    }

    func animate(from start: Int, to end: Int, duration: TimeInterval = 2.0, suffix: String = "", completion: (() -> Void)? = nil) {
        self.startValue = start
        self.endValue = end
        self.duration = duration
        self.suffix = suffix
        self.completion = completion
        self.startTime = CACurrentMediaTime()

        displayLink = CADisplayLink(target: self, selector: #selector(updateValue))
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func updateValue() {
        let elapsed = CACurrentMediaTime() - startTime
        let progress = min(elapsed / duration, 1.0)

        // Ease-out curve
        let easedProgress = 1 - pow(1 - progress, 3)

        let currentValue = Int(Double(startValue) + Double(endValue - startValue) * easedProgress)
        label?.text = "\(currentValue)\(suffix)"

        if progress >= 1.0 {
            displayLink?.invalidate()
            displayLink = nil
            label?.text = "\(endValue)\(suffix)"
            completion?()
        }
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        label?.text = "\(endValue)\(suffix)"
    }
}

// MARK: - Pulse Animation

extension UIView {

    func startPulseAnimation() {
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 1.05
        pulse.duration = 1.0
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(pulse, forKey: "pulse")
    }

    func stopPulseAnimation() {
        layer.removeAnimation(forKey: "pulse")
    }
}

// MARK: - Glow Animation

extension UIView {

    func addGlowEffect(color: UIColor = UIColor(red: 0.0, green: 0.85, blue: 0.95, alpha: 1.0), radius: CGFloat = 20) {
        layer.shadowColor = color.cgColor
        layer.shadowRadius = radius
        layer.shadowOpacity = 0.8
        layer.shadowOffset = .zero

        let animation = CABasicAnimation(keyPath: "shadowOpacity")
        animation.fromValue = 0.4
        animation.toValue = 1.0
        animation.duration = 1.5
        animation.autoreverses = true
        animation.repeatCount = .infinity
        layer.add(animation, forKey: "glow")
    }

    func removeGlowEffect() {
        layer.removeAnimation(forKey: "glow")
        layer.shadowOpacity = 0
    }
}

// MARK: - Shimmer Animation

extension UIView {

    func addShimmerEffect() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = bounds
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)

        gradientLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.white.withAlphaComponent(0.2).cgColor,
            UIColor.clear.cgColor
        ]
        gradientLayer.locations = [0.0, 0.5, 1.0]
        gradientLayer.name = "shimmer"

        layer.addSublayer(gradientLayer)

        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [-1.0, -0.5, 0.0]
        animation.toValue = [1.0, 1.5, 2.0]
        animation.duration = 2.0
        animation.repeatCount = .infinity

        gradientLayer.add(animation, forKey: "shimmer")
    }

    func removeShimmerEffect() {
        layer.sublayers?.first { $0.name == "shimmer" }?.removeFromSuperlayer()
    }
}

// MARK: - Flash Animation

extension UIView {

    func flashWhite(duration: TimeInterval = 0.3, completion: (() -> Void)? = nil) {
        let flashView = UIView(frame: bounds)
        flashView.backgroundColor = .white
        flashView.alpha = 0
        addSubview(flashView)

        UIView.animateKeyframes(withDuration: duration, delay: 0, options: []) {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.5) {
                flashView.alpha = 1.0
            }
            UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5) {
                flashView.alpha = 0
            }
        } completion: { _ in
            flashView.removeFromSuperview()
            completion?()
        }
    }
}

// MARK: - Spring Bounce Animation

extension UIView {

    func bounceIn(from direction: BounceDirection = .top, delay: TimeInterval = 0, completion: (() -> Void)? = nil) {
        let offset: CGFloat = 100

        switch direction {
        case .top:
            transform = CGAffineTransform(translationX: 0, y: -offset).scaledBy(x: 0.7, y: 0.7)
        case .bottom:
            transform = CGAffineTransform(translationX: 0, y: offset).scaledBy(x: 0.7, y: 0.7)
        case .left:
            transform = CGAffineTransform(translationX: -offset, y: 0).scaledBy(x: 0.7, y: 0.7)
        case .right:
            transform = CGAffineTransform(translationX: offset, y: 0).scaledBy(x: 0.7, y: 0.7)
        }

        alpha = 0

        UIView.animate(
            withDuration: 0.8,
            delay: delay,
            usingSpringWithDamping: 0.6,
            initialSpringVelocity: 0.5,
            options: [.curveEaseOut]
        ) {
            self.transform = .identity
            self.alpha = 1
        } completion: { _ in
            completion?()
        }
    }

    enum BounceDirection {
        case top, bottom, left, right
    }
}

// MARK: - Progress Bar Animation

final class AnimatedProgressBar: UIView {

    private let backgroundBar = UIView()
    private let fillBar = UIView()
    private var fillWidthConstraint: NSLayoutConstraint?

    var progressColor: UIColor = UIColor(red: 0.0, green: 0.85, blue: 0.95, alpha: 1.0) {
        didSet { fillBar.backgroundColor = progressColor }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        backgroundBar.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        backgroundBar.layer.cornerRadius = 4
        backgroundBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backgroundBar)

        fillBar.backgroundColor = progressColor
        fillBar.layer.cornerRadius = 4
        fillBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(fillBar)

        fillWidthConstraint = fillBar.widthAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            backgroundBar.topAnchor.constraint(equalTo: topAnchor),
            backgroundBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundBar.bottomAnchor.constraint(equalTo: bottomAnchor),

            fillBar.topAnchor.constraint(equalTo: topAnchor),
            fillBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            fillBar.bottomAnchor.constraint(equalTo: bottomAnchor),
            fillWidthConstraint!
        ])
    }

    func animateProgress(to percentage: CGFloat, duration: TimeInterval = 2.0, completion: (() -> Void)? = nil) {
        layoutIfNeeded()
        let targetWidth = bounds.width * percentage
        fillWidthConstraint?.constant = targetWidth

        UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseOut]) {
            self.layoutIfNeeded()
        } completion: { _ in
            completion?()
        }
    }

    func setProgress(_ percentage: CGFloat) {
        layoutIfNeeded()
        fillWidthConstraint?.constant = bounds.width * percentage
    }
}
