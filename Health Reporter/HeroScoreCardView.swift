//
//  HeroScoreCardView.swift
//  Health Reporter
//
//  כרטיס Hero ראשי – טבעת ציון אנימטיבית, תמונת רכב, 3 mini-KPIs.
//

import UIKit

final class HeroScoreCardView: UIView {

    // MARK: - Subviews

    private let ringContainer = UIView()
    private let scoreLabel = UILabel()
    private let tierLabel = UILabel()
    private let carImageView = UIImageView()
    private let carNameLabel = UILabel()
    private let separatorLine = UIView()
    private let miniKPIStack = UIStackView()

    // Mini-KPI value labels (exposed for updates)
    private let sleepIcon = UIImageView()
    private let hrvIcon = UIImageView()
    private let strainIcon = UIImageView()
    let sleepValueLabel = UILabel()
    let hrvValueLabel = UILabel()
    let strainValueLabel = UILabel()

    // Ring layers
    private let backgroundRingLayer = CAShapeLayer()
    private let progressRingLayer = CAShapeLayer()
    private let gradientMaskLayer = CALayer()

    // Car glow
    private let carGlowLayer = CAGradientLayer()

    // Animation state
    private var displayLink: CADisplayLink?
    private var animStartTime: CFTimeInterval = 0
    private var targetScore: Int = 0
    private var currentAnimScore: Int = 0
    private let animDuration: CFTimeInterval = 0.8

    // Ring dimensions
    private let ringDiameter: CGFloat = 160
    private let ringLineWidth: CGFloat = 10

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: - Setup

    private func setup() {
        backgroundColor = AIONDesign.surface
        layer.cornerRadius = AIONDesign.cornerRadiusLarge
        clipsToBounds = true
        semanticContentAttribute = .forceRightToLeft

        setupRing()
        setupScoreLabels()
        setupCarImage()
        setupSeparator()
        setupMiniKPIs()
        setupConstraints()
    }

    private func setupRing() {
        ringContainer.translatesAutoresizingMaskIntoConstraints = false
        ringContainer.backgroundColor = .clear
        addSubview(ringContainer)
    }

    private func setupScoreLabels() {
        scoreLabel.text = "—"
        scoreLabel.font = .systemFont(ofSize: 56, weight: .bold)
        scoreLabel.textColor = AIONDesign.textPrimary
        scoreLabel.textAlignment = .center
        scoreLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scoreLabel)

        tierLabel.text = ""
        tierLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        tierLabel.textColor = AIONDesign.accentPrimary
        tierLabel.textAlignment = .center
        tierLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tierLabel)
    }

    private func setupCarImage() {
        // Car image and name removed - not relevant for this page
        carImageView.isHidden = true
        carNameLabel.isHidden = true
    }

    private func setupSeparator() {
        separatorLine.backgroundColor = AIONDesign.textTertiary.withAlphaComponent(0.2)
        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separatorLine)
    }

    private func setupMiniKPIs() {
        miniKPIStack.axis = .horizontal
        miniKPIStack.distribution = .equalCentering
        miniKPIStack.alignment = .center
        miniKPIStack.semanticContentAttribute = .forceRightToLeft
        miniKPIStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(miniKPIStack)

        let sleepKPI = makeMiniKPI(
            icon: "bed.double.fill",
            iconView: sleepIcon,
            valueLabel: sleepValueLabel,
            label: "שינה",
            tint: AIONDesign.accentPrimary
        )
        let hrvKPI = makeMiniKPI(
            icon: "waveform.path.ecg",
            iconView: hrvIcon,
            valueLabel: hrvValueLabel,
            label: "HRV",
            tint: AIONDesign.accentSecondary
        )
        let strainKPI = makeMiniKPI(
            icon: "flame.fill",
            iconView: strainIcon,
            valueLabel: strainValueLabel,
            label: "עומס",
            tint: AIONDesign.accentWarning
        )

        miniKPIStack.addArrangedSubview(sleepKPI)
        miniKPIStack.addArrangedSubview(hrvKPI)
        miniKPIStack.addArrangedSubview(strainKPI)
    }

    private func makeMiniKPI(icon: String, iconView: UIImageView, valueLabel: UILabel, label: String, tint: UIColor) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        stack.semanticContentAttribute = .forceRightToLeft

        let cfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        iconView.image = UIImage(systemName: icon, withConfiguration: cfg)
        iconView.tintColor = tint
        iconView.translatesAutoresizingMaskIntoConstraints = false

        valueLabel.text = "—"
        valueLabel.font = .systemFont(ofSize: 16, weight: .bold)
        valueLabel.textColor = AIONDesign.textPrimary
        valueLabel.textAlignment = .center
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = label
        titleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = AIONDesign.textSecondary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(valueLabel)
        stack.addArrangedSubview(titleLabel)

        return stack
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Ring container
            ringContainer.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            ringContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            ringContainer.widthAnchor.constraint(equalToConstant: ringDiameter),
            ringContainer.heightAnchor.constraint(equalToConstant: ringDiameter),

            // Score label centered in ring
            scoreLabel.centerXAnchor.constraint(equalTo: ringContainer.centerXAnchor),
            scoreLabel.centerYAnchor.constraint(equalTo: ringContainer.centerYAnchor, constant: -8),

            // Tier label below score
            tierLabel.topAnchor.constraint(equalTo: scoreLabel.bottomAnchor, constant: -2),
            tierLabel.centerXAnchor.constraint(equalTo: ringContainer.centerXAnchor),

            // Separator below tier label (car removed)
            separatorLine.topAnchor.constraint(equalTo: ringContainer.bottomAnchor, constant: 16),
            separatorLine.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            separatorLine.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            separatorLine.heightAnchor.constraint(equalToConstant: 1),

            // Mini KPI stack
            miniKPIStack.topAnchor.constraint(equalTo: separatorLine.bottomAnchor, constant: 16),
            miniKPIStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            miniKPIStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            miniKPIStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
        ])
    }

    // MARK: - Layout (Ring drawing)

    override func layoutSubviews() {
        super.layoutSubviews()
        drawRingIfNeeded()
    }

    private var ringDrawn = false

    private func drawRingIfNeeded() {
        guard !ringDrawn, ringContainer.bounds.width > 0 else { return }
        ringDrawn = true

        let center = CGPoint(x: ringContainer.bounds.midX, y: ringContainer.bounds.midY)
        let radius = (ringDiameter - ringLineWidth) / 2
        let startAngle: CGFloat = -.pi / 2
        let endAngle: CGFloat = .pi * 1.5
        let path = UIBezierPath(arcCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)

        // Background ring
        backgroundRingLayer.path = path.cgPath
        backgroundRingLayer.fillColor = UIColor.clear.cgColor
        backgroundRingLayer.strokeColor = AIONDesign.textTertiary.withAlphaComponent(0.15).cgColor
        backgroundRingLayer.lineWidth = ringLineWidth
        backgroundRingLayer.lineCap = .round
        backgroundRingLayer.frame = ringContainer.bounds
        ringContainer.layer.addSublayer(backgroundRingLayer)

        // Progress ring (will be masked by gradient)
        progressRingLayer.path = path.cgPath
        progressRingLayer.fillColor = UIColor.clear.cgColor
        progressRingLayer.strokeColor = UIColor.white.cgColor
        progressRingLayer.lineWidth = ringLineWidth
        progressRingLayer.lineCap = .round
        progressRingLayer.strokeEnd = 0
        progressRingLayer.frame = ringContainer.bounds

        // Gradient layer
        let gradient = CAGradientLayer()
        gradient.frame = ringContainer.bounds
        gradient.colors = [
            AIONDesign.accentPrimary.cgColor,
            AIONDesign.accentSecondary.cgColor,
            AIONDesign.accentSuccess.cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.mask = progressRingLayer
        ringContainer.layer.addSublayer(gradient)
    }

    // MARK: - Configure

    func configure(
        score: Int,
        tier: CarTier,
        sleepText: String,
        hrvText: String,
        strainText: String,
        animated: Bool = true
    ) {
        tierLabel.text = tier.tierLabel
        tierLabel.textColor = tier.color
        // Car removed - not relevant for this page

        // Mini KPIs
        sleepValueLabel.text = sleepText
        hrvValueLabel.text = hrvText
        strainValueLabel.text = strainText

        // Score + Ring animation
        if animated {
            animateScoreCounter(to: score)
            animateRing(to: CGFloat(score) / 100.0)
        } else {
            scoreLabel.text = "\(score)"
            progressRingLayer.strokeEnd = CGFloat(score) / 100.0
        }
    }

    /// Configure with placeholder (no data)
    func configurePlaceholder() {
        scoreLabel.text = "—"
        tierLabel.text = "טוען..."
        tierLabel.textColor = AIONDesign.textTertiary
        sleepValueLabel.text = "—"
        hrvValueLabel.text = "—"
        strainValueLabel.text = "—"
        progressRingLayer.strokeEnd = 0
    }

    // MARK: - Animations

    func animateRing(to progress: CGFloat) {
        // Ensure ring is drawn
        layoutIfNeeded()
        drawRingIfNeeded()

        let clamped = min(1, max(0, progress))
        let anim = CABasicAnimation(keyPath: "strokeEnd")
        anim.fromValue = 0
        anim.toValue = clamped
        anim.duration = 1.2
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        anim.fillMode = .forwards
        anim.isRemovedOnCompletion = false
        progressRingLayer.add(anim, forKey: "ringProgress")
        progressRingLayer.strokeEnd = clamped
    }

    func animateScoreCounter(to target: Int) {
        targetScore = target
        currentAnimScore = 0
        scoreLabel.text = "0"
        animStartTime = CACurrentMediaTime()

        displayLink?.invalidate()
        displayLink = CADisplayLink(target: self, selector: #selector(updateCounter))
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func updateCounter() {
        let elapsed = CACurrentMediaTime() - animStartTime
        let progress = min(1.0, elapsed / animDuration)

        // Ease out
        let eased = 1 - pow(1 - progress, 3)
        let current = Int(round(Double(targetScore) * eased))
        scoreLabel.text = "\(current)"

        if progress >= 1.0 {
            displayLink?.invalidate()
            displayLink = nil
            scoreLabel.text = "\(targetScore)"

            // Haptic feedback
            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.prepare()
            gen.impactOccurred()

            // Subtle bounce
            UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseOut) {
                self.scoreLabel.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            } completion: { _ in
                UIView.animate(withDuration: 0.1) {
                    self.scoreLabel.transform = .identity
                }
            }
        }
    }

    // MARK: - Cleanup

    deinit {
        displayLink?.invalidate()
    }
}
