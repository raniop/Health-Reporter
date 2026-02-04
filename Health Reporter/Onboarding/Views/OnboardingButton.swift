//
//  OnboardingButton.swift
//  Health Reporter
//
//  כפתורים מעוצבים ל-Onboarding
//

import UIKit

final class OnboardingPrimaryButton: UIButton {

    private let gradientLayer = CAGradientLayer()
    private let spinner = UIActivityIndicatorView(style: .medium)

    var isLoading: Bool = false {
        didSet {
            updateLoadingState()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        // Gradient background
        gradientLayer.colors = AIONDesign.primaryGradient
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.cornerRadius = AIONDesign.cornerRadius
        layer.insertSublayer(gradientLayer, at: 0)

        // Text style
        titleLabel?.font = AIONDesign.headlineFont()
        setTitleColor(.white, for: .normal)
        setTitleColor(.white.withAlphaComponent(0.5), for: .disabled)

        // Layout
        layer.cornerRadius = AIONDesign.cornerRadius
        clipsToBounds = true
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 56).isActive = true

        // Shadow
        layer.shadowColor = AIONDesign.accentPrimary.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 12
        layer.shadowOpacity = 0.3
        layer.masksToBounds = false

        // Spinner
        spinner.color = .white
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    private func updateLoadingState() {
        if isLoading {
            spinner.startAnimating()
            titleLabel?.alpha = 0
            isUserInteractionEnabled = false
        } else {
            spinner.stopAnimating()
            titleLabel?.alpha = 1
            isUserInteractionEnabled = true
        }
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
                self.alpha = self.isHighlighted ? 0.9 : 1.0
            }
        }
    }

    override var isEnabled: Bool {
        didSet {
            gradientLayer.opacity = isEnabled ? 1.0 : 0.5
        }
    }
}

// MARK: - Secondary Button (Skip/Later)

final class OnboardingSecondaryButton: UIButton {

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        setTitleColor(AIONDesign.textSecondary, for: .normal)
        setTitleColor(AIONDesign.textTertiary, for: .highlighted)
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 44).isActive = true
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.alpha = self.isHighlighted ? 0.6 : 1.0
            }
        }
    }
}
