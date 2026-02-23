//
//  LanguageSelectionViewController.swift
//  Health Reporter
//
//  Full-screen language selection shown once on first launch.
//  After the user picks a language, the app restarts with that locale.
//

import UIKit

final class LanguageSelectionViewController: UIViewController {

    // MARK: - Key

    /// Once set to true the picker is never shown again.
    static let hasChosenLanguageKey = "AION.HasChosenLanguage"

    /// Returns true when the user still needs to pick a language.
    static var needsLanguageSelection: Bool {
        return !UserDefaults.standard.bool(forKey: hasChosenLanguageKey)
    }

    // MARK: - UI

    private let logoImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "LaunchLogoNew"))
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "AION"
        label.font = .boldSystemFont(ofSize: 34)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let promptLabel: UILabel = {
        let label = UILabel()
        label.text = "Choose your language\nבחר שפה"
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var englishButton: UIButton = {
        let btn = makeLanguageButton(
            flag: "🇺🇸",
            title: "English",
            tag: 0
        )
        return btn
    }()

    private lazy var hebrewButton: UIButton = {
        let btn = makeLanguageButton(
            flag: "🇮🇱",
            title: "עברית",
            tag: 1
        )
        return btn
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateIn()
    }

    // MARK: - Setup

    private func setupUI() {
        applyAIONGradientBackground()

        view.addSubview(logoImageView)
        view.addSubview(titleLabel)
        view.addSubview(promptLabel)
        view.addSubview(englishButton)
        view.addSubview(hebrewButton)

        NSLayoutConstraint.activate([
            // Logo
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            logoImageView.widthAnchor.constraint(equalToConstant: 140),
            logoImageView.heightAnchor.constraint(equalToConstant: 140),

            // Title
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 16),

            // Prompt
            promptLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            promptLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 40),
            promptLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            promptLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            // English button
            englishButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            englishButton.topAnchor.constraint(equalTo: promptLabel.bottomAnchor, constant: 40),
            englishButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            englishButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            englishButton.heightAnchor.constraint(equalToConstant: 56),

            // Hebrew button
            hebrewButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hebrewButton.topAnchor.constraint(equalTo: englishButton.bottomAnchor, constant: 16),
            hebrewButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            hebrewButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            hebrewButton.heightAnchor.constraint(equalToConstant: 56),
        ])

        // Initial state for animation
        logoImageView.alpha = 0
        logoImageView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        titleLabel.alpha = 0
        promptLabel.alpha = 0
        englishButton.alpha = 0
        englishButton.transform = CGAffineTransform(translationX: 0, y: 20)
        hebrewButton.alpha = 0
        hebrewButton.transform = CGAffineTransform(translationX: 0, y: 20)
    }

    // MARK: - Button Factory

    private func makeLanguageButton(flag: String, title: String, tag: Int) -> UIButton {
        let btn = UIButton(type: .system)
        btn.tag = tag
        btn.translatesAutoresizingMaskIntoConstraints = false

        // Style: rounded, semi-transparent border
        btn.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        btn.layer.cornerRadius = 14
        btn.layer.borderWidth = 1
        btn.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor

        // Content
        let text = "\(flag)   \(title)"
        let attr = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: 20, weight: .semibold),
            .foregroundColor: UIColor.white
        ])
        btn.setAttributedTitle(attr, for: .normal)

        btn.addTarget(self, action: #selector(languageTapped(_:)), for: .touchUpInside)
        return btn
    }

    // MARK: - Animation

    private func animateIn() {
        UIView.animate(withDuration: 0.6, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.logoImageView.alpha = 1
            self.logoImageView.transform = .identity
        }

        UIView.animate(withDuration: 0.5, delay: 0.3) {
            self.titleLabel.alpha = 1
        }

        UIView.animate(withDuration: 0.5, delay: 0.4) {
            self.promptLabel.alpha = 1
        }

        UIView.animate(withDuration: 0.5, delay: 0.5, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.englishButton.alpha = 1
            self.englishButton.transform = .identity
        }

        UIView.animate(withDuration: 0.5, delay: 0.6, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.hebrewButton.alpha = 1
            self.hebrewButton.transform = .identity
        }
    }

    // MARK: - Actions

    @objc private func languageTapped(_ sender: UIButton) {
        let language: AppLanguage = sender.tag == 0 ? .english : .hebrew

        // Highlight selected button
        let selectedButton = sender
        let otherButton = sender.tag == 0 ? hebrewButton : englishButton

        UIView.animate(withDuration: 0.2) {
            selectedButton.backgroundColor = AIONDesign.accentPrimary.withAlphaComponent(0.3)
            selectedButton.layer.borderColor = AIONDesign.accentPrimary.cgColor
            otherButton.alpha = 0.4
        }

        // Save language choice
        UserDefaults.standard.set(true, forKey: Self.hasChosenLanguageKey)
        LocalizationManager.shared.setLanguage(language)

        // Brief delay for visual feedback, then restart
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Restart the app flow with the selected language
            guard let window = self.view.window else { return }
            let sceneDelegate = window.windowScene?.delegate as? SceneDelegate
            UIView.transition(with: window, duration: 0.4, options: .transitionCrossDissolve) {
                sceneDelegate?.setRootByAuth()
            }
        }
    }
}
