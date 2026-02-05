//
//  CarMetaphorOnboardingPage.swift
//  Health Reporter
//
//  מסך הסבר על מטאפורת המכונית
//

import UIKit

final class CarMetaphorOnboardingPage: UIViewController {

    private weak var delegate: OnboardingPageDelegate?

    // MARK: - UI

    private let carImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "car.fill")
        iv.tintColor = AIONDesign.accentPrimary
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let gradientView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "onboarding.car.title".localized
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = AIONDesign.textPrimary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "onboarding.car.description".localized
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = AIONDesign.textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let carsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let continueButton = OnboardingPrimaryButton()

    // MARK: - Init

    init(delegate: OnboardingPageDelegate) {
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateCar()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        setupGradient()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = AIONDesign.background

        // Gradient background at top
        view.addSubview(gradientView)

        // Car icon
        view.addSubview(carImageView)

        // Title & Description
        view.addSubview(titleLabel)
        view.addSubview(descriptionLabel)

        // Car examples
        let carExamples = [
            ("🚗", "Mini Cooper"),
            ("🏎️", "Tesla Model S"),
            ("🚀", "Ferrari")
        ]

        for (emoji, name) in carExamples {
            let carView = createCarExampleView(emoji: emoji, name: name)
            carsStack.addArrangedSubview(carView)
        }
        view.addSubview(carsStack)

        // Button
        continueButton.setTitle("onboarding.continue".localized, for: .normal)
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        view.addSubview(continueButton)

        NSLayoutConstraint.activate([
            gradientView.topAnchor.constraint(equalTo: view.topAnchor),
            gradientView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gradientView.heightAnchor.constraint(equalToConstant: 250),

            carImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            carImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            carImageView.widthAnchor.constraint(equalToConstant: 100),
            carImageView.heightAnchor.constraint(equalToConstant: 100),

            titleLabel.topAnchor.constraint(equalTo: carImageView.bottomAnchor, constant: 32),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            carsStack.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 40),
            carsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            carsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            carsStack.heightAnchor.constraint(equalToConstant: 100),

            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -80)
        ])
    }

    private func setupGradient() {
        gradientView.layer.sublayers?.removeAll { $0 is CAGradientLayer }

        let gradient = CAGradientLayer()
        gradient.frame = gradientView.bounds
        gradient.colors = [
            AIONDesign.accentPrimary.withAlphaComponent(0.2).cgColor,
            AIONDesign.background.cgColor
        ]
        gradient.locations = [0, 1]
        gradientView.layer.insertSublayer(gradient, at: 0)
    }

    private func createCarExampleView(emoji: String, name: String) -> UIView {
        let container = UIView()
        container.backgroundColor = AIONDesign.surface
        container.layer.cornerRadius = AIONDesign.cornerRadius
        container.translatesAutoresizingMaskIntoConstraints = false

        let emojiLabel = UILabel()
        emojiLabel.text = emoji
        emojiLabel.font = .systemFont(ofSize: 32)
        emojiLabel.textAlignment = .center
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = .systemFont(ofSize: 11, weight: .medium)
        nameLabel.textColor = AIONDesign.textSecondary
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(emojiLabel)
        container.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            emojiLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            emojiLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),

            nameLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            nameLabel.topAnchor.constraint(equalTo: emojiLabel.bottomAnchor, constant: 8),
            nameLabel.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -12)
        ])

        return container
    }

    // MARK: - Animation

    private func animateCar() {
        // Car driving animation
        let originalCenter = carImageView.center.x

        carImageView.center.x = -50
        carImageView.alpha = 0

        UIView.animate(withDuration: 0.8, delay: 0.2, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [], animations: {
            self.carImageView.center.x = originalCenter
            self.carImageView.alpha = 1
        }, completion: nil)

        // Animate car examples
        for (index, subview) in carsStack.arrangedSubviews.enumerated() {
            subview.alpha = 0
            subview.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)

            UIView.animate(withDuration: 0.5, delay: 0.4 + Double(index) * 0.15, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [], animations: {
                subview.alpha = 1
                subview.transform = .identity
            }, completion: nil)
        }
    }

    // MARK: - Actions

    @objc private func continueTapped() {
        continueButton.springAnimation {
            self.delegate?.onboardingDidRequestNext()
        }
    }
}
