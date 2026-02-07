//
//  CarRevealOnboardingPage.swift
//  Health Reporter
//
//  Car reveal screen - shown only if Gemini data is available
//

import UIKit

final class CarRevealOnboardingPage: UIViewController {

    private weak var delegate: OnboardingPageDelegate?

    // MARK: - Data

    private var carName: String = ""
    private var carEmoji: String = ""
    private var healthScore: Int = 0
    private var wikiName: String = ""

    // MARK: - UI

    private let confettiLayer = CAEmitterLayer()

    private let coverView: UIView = {
        let view = UIView()
        view.backgroundColor = AIONDesign.surfaceElevated
        view.layer.cornerRadius = 24
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let carImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.alpha = 0
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let questionMarkLabel: UILabel = {
        let label = UILabel()
        label.text = "?"
        label.font = .systemFont(ofSize: 80, weight: .bold)
        label.textColor = AIONDesign.textTertiary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let carEmojiLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 80)
        label.textAlignment = .center
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "onboarding.reveal.title".localized
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = AIONDesign.textPrimary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let carNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 26, weight: .bold)
        label.textColor = AIONDesign.accentPrimary
        label.textAlignment = .center
        label.alpha = 0
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let scoreContainer: UIView = {
        let view = UIView()
        view.backgroundColor = AIONDesign.surface
        view.layer.cornerRadius = AIONDesign.cornerRadius
        view.alpha = 0
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let scoreLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = AIONDesign.accentPrimary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let scoreDescLabel: UILabel = {
        let label = UILabel()
        label.text = "onboarding.reveal.healthScore".localized
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = AIONDesign.textSecondary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "onboarding.reveal.description".localized
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = AIONDesign.textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let startButton = OnboardingPrimaryButton()

    // MARK: - Init

    init(delegate: OnboardingPageDelegate, carName: String, carEmoji: String, healthScore: Int, wikiName: String = "") {
        self.delegate = delegate
        self.carName = carName
        self.carEmoji = carEmoji
        self.healthScore = healthScore
        self.wikiName = wikiName
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startRevealAnimation()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = AIONDesign.background

        // Cover with question mark
        view.addSubview(coverView)
        coverView.addSubview(carImageView)
        coverView.addSubview(questionMarkLabel)
        coverView.addSubview(carEmojiLabel)

        // Title
        view.addSubview(titleLabel)

        // Car name
        view.addSubview(carNameLabel)

        // Score container
        scoreContainer.addSubview(scoreLabel)
        scoreContainer.addSubview(scoreDescLabel)
        view.addSubview(scoreContainer)

        // Description
        view.addSubview(descriptionLabel)

        // Button
        startButton.setTitle("onboarding.reveal.start".localized, for: .normal)
        startButton.addTarget(self, action: #selector(startTapped), for: .touchUpInside)
        startButton.alpha = 0
        view.addSubview(startButton)

        // New order: Title -> Car Name -> Image -> Score -> Description -> Button
        NSLayoutConstraint.activate([
            // 1. Title at top
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            // 2. Car name below title
            carNameLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            carNameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            carNameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            // 3. Image below car name
            coverView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            coverView.topAnchor.constraint(equalTo: carNameLabel.bottomAnchor, constant: 24),
            coverView.widthAnchor.constraint(equalToConstant: 280),
            coverView.heightAnchor.constraint(equalToConstant: 280),

            carImageView.topAnchor.constraint(equalTo: coverView.topAnchor),
            carImageView.leadingAnchor.constraint(equalTo: coverView.leadingAnchor),
            carImageView.trailingAnchor.constraint(equalTo: coverView.trailingAnchor),
            carImageView.bottomAnchor.constraint(equalTo: coverView.bottomAnchor),

            questionMarkLabel.centerXAnchor.constraint(equalTo: coverView.centerXAnchor),
            questionMarkLabel.centerYAnchor.constraint(equalTo: coverView.centerYAnchor),

            carEmojiLabel.centerXAnchor.constraint(equalTo: coverView.centerXAnchor),
            carEmojiLabel.centerYAnchor.constraint(equalTo: coverView.centerYAnchor),

            // 4. Score below image
            scoreContainer.topAnchor.constraint(equalTo: coverView.bottomAnchor, constant: 24),
            scoreContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scoreContainer.widthAnchor.constraint(equalToConstant: 120),
            scoreContainer.heightAnchor.constraint(equalToConstant: 70),

            scoreLabel.topAnchor.constraint(equalTo: scoreContainer.topAnchor, constant: 12),
            scoreLabel.centerXAnchor.constraint(equalTo: scoreContainer.centerXAnchor),

            scoreDescLabel.topAnchor.constraint(equalTo: scoreLabel.bottomAnchor, constant: 4),
            scoreDescLabel.centerXAnchor.constraint(equalTo: scoreContainer.centerXAnchor),

            // 5. Description below score
            descriptionLabel.topAnchor.constraint(equalTo: scoreContainer.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            // 6. Button at bottom
            startButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            startButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            startButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40)
        ])
    }

    private func configureData() {
        carEmojiLabel.text = carEmoji
        carNameLabel.text = carName
        scoreLabel.text = "\(healthScore)"

        // Load car image from cache or fetch from Wikipedia
        if !wikiName.isEmpty {
            if let cachedImage = WidgetDataManager.shared.loadCachedCarImage(forWikiName: wikiName) {
                carImageView.image = cachedImage
            } else {
                // Fetch and cache
                WidgetDataManager.shared.prefetchCarImage(wikiName: wikiName) { [weak self] success in
                    if success, let image = WidgetDataManager.shared.loadCachedCarImage(forWikiName: self?.wikiName ?? "") {
                        DispatchQueue.main.async {
                            self?.carImageView.image = image
                        }
                    }
                }
            }
        }
    }

    // MARK: - Animation

    private func startRevealAnimation() {
        // Shake the cover
        let shake = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        shake.values = [0, 0.05, -0.05, 0.05, -0.05, 0]
        shake.duration = 0.6
        shake.beginTime = CACurrentMediaTime() + 0.5
        coverView.layer.add(shake, forKey: "shake")

        // Reveal sequence
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.revealCar()
        }
    }

    private func revealCar() {
        // Flash effect
        let flash = UIView(frame: view.bounds)
        flash.backgroundColor = .white
        flash.alpha = 0
        view.addSubview(flash)

        UIView.animate(withDuration: 0.1) {
            flash.alpha = 0.8
        } completion: { _ in
            UIView.animate(withDuration: 0.3) {
                flash.alpha = 0
            } completion: { _ in
                flash.removeFromSuperview()
            }
        }

        // Hide question mark, show image or emoji
        UIView.animate(withDuration: 0.3) {
            self.questionMarkLabel.alpha = 0
            self.questionMarkLabel.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        }

        // Show image if available, otherwise emoji
        if self.carImageView.image != nil {
            UIView.animate(withDuration: 0.5, delay: 0.2, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: [], animations: {
                self.carImageView.alpha = 1
                self.carImageView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            }, completion: { _ in
                UIView.animate(withDuration: 0.2) {
                    self.carImageView.transform = .identity
                }
            })
        } else {
            UIView.animate(withDuration: 0.5, delay: 0.2, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: [], animations: {
                self.carEmojiLabel.alpha = 1
                self.carEmojiLabel.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            }, completion: { _ in
                UIView.animate(withDuration: 0.2) {
                    self.carEmojiLabel.transform = .identity
                }
            })
        }

        // Add glow to cover
        coverView.layer.shadowColor = AIONDesign.accentPrimary.cgColor
        coverView.layer.shadowOffset = .zero
        coverView.layer.shadowRadius = 20
        UIView.animate(withDuration: 0.5) {
            self.coverView.layer.shadowOpacity = 0.6
        }

        // Show car name
        carNameLabel.transform = CGAffineTransform(translationX: 0, y: 20)
        UIView.animate(withDuration: 0.5, delay: 0.4, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [], animations: {
            self.carNameLabel.alpha = 1
            self.carNameLabel.transform = .identity
        }, completion: nil)

        // Show score
        UIView.animate(withDuration: 0.5, delay: 0.6, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [], animations: {
            self.scoreContainer.alpha = 1
        }, completion: nil)

        // Show description
        UIView.animate(withDuration: 0.5, delay: 0.8, animations: {
            self.descriptionLabel.alpha = 1
        })

        // Show button
        UIView.animate(withDuration: 0.5, delay: 1.0, animations: {
            self.startButton.alpha = 1
        })

        // Start confetti
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.startConfetti()
        }

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func startConfetti() {
        confettiLayer.emitterPosition = CGPoint(x: view.bounds.midX, y: -10)
        confettiLayer.emitterShape = .line
        confettiLayer.emitterSize = CGSize(width: view.bounds.width, height: 1)

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
            cell.birthRate = 8
            cell.lifetime = 4
            cell.velocity = 150
            cell.velocityRange = 50
            cell.emissionLongitude = .pi
            cell.emissionRange = .pi / 4
            cell.spin = 2
            cell.spinRange = 3
            cell.scale = 0.08
            cell.scaleRange = 0.04
            cell.contents = createConfettiImage(color: color).cgImage
            cells.append(cell)
        }

        confettiLayer.emitterCells = cells
        view.layer.addSublayer(confettiLayer)

        // Stop after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.confettiLayer.birthRate = 0
        }
    }

    private func createConfettiImage(color: UIColor) -> UIImage {
        let size = CGSize(width: 12, height: 12)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        color.setFill()
        UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 2).fill()
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }

    // MARK: - Actions

    @objc private func startTapped() {
        // Mark that user has discovered their car (so Insights tab won't show discovery again)
        UserDefaults.standard.set(true, forKey: "AION.HasDiscoveredCar")

        startButton.springAnimation { [weak self] in
            self?.delegate?.onboardingDidComplete()
        }
    }
}
