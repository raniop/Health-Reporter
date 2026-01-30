//
//  NutritionViewController.swift
//  Health Reporter
//
//  מסך המלצות תזונה ותוספים - מבוסס על ניתוח נתוני בריאות
//

import UIKit

final class NutritionViewController: UIViewController {

    // MARK: - Properties

    var supplements: [SupplementRecommendation] = []

    // MARK: - UI Colors (דינמי לפי רקע בהיר/כהה)

    private var bgColor: UIColor { AIONDesign.background }
    private var cardBgColor: UIColor { AIONDesign.surface }
    private var textWhite: UIColor { AIONDesign.textPrimary }
    private var textGray: UIColor { AIONDesign.textSecondary }
    private let accentGreen = UIColor(red: 0.2, green: 0.85, blue: 0.5, alpha: 1.0)
    private let accentCyan = UIColor(red: 0.0, green: 0.85, blue: 0.95, alpha: 1.0)

    // MARK: - UI Components

    private let scrollView: UIScrollView = {
        let v = UIScrollView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.showsVerticalScrollIndicator = false
        v.alwaysBounceVertical = true
        return v
    }()

    private let stack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 16
        s.alignment = .fill
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        buildContent()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = bgColor
        title = "nutrition.title".localized

        // Navigation bar styling
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.tintColor = accentCyan

        // ScrollView setup
        view.addSubview(scrollView)
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -32),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),
        ])
    }

    // MARK: - Build Content

    private func buildContent() {
        // Header
        addHeader()

        // אם אין תוספים
        if supplements.isEmpty {
            addEmptyState()
            return
        }

        // קיבוץ לפי קטגוריה
        let groupedSupplements = Dictionary(grouping: supplements) { $0.category }

        for category in SupplementCategory.allCases {
            guard let categorySupplements = groupedSupplements[category], !categorySupplements.isEmpty else { continue }

            // כותרת קטגוריה
            addCategoryHeader(category)

            // כרטיסי תוספים
            for supplement in categorySupplements {
                addSupplementCard(supplement)
            }
        }

        // Disclaimer
        addDisclaimer()
    }

    // MARK: - Header

    private func addHeader() {
        let headerStack = UIStackView()
        headerStack.axis = .vertical
        headerStack.spacing = 8
        headerStack.alignment = .center

        // אייקון
        let iconLabel = UILabel()
        iconLabel.text = "💊"
        iconLabel.font = .systemFont(ofSize: 50)
        iconLabel.textAlignment = .center

        // Title
        let titleLabel = UILabel()
        titleLabel.text = "nutrition.supplementRecommendations".localized
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = textWhite
        titleLabel.textAlignment = .center

        // Subtitle
        let subtitleLabel = UILabel()
        subtitleLabel.text = "nutrition.basedOnAnalysis".localized
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = textGray
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        headerStack.addArrangedSubview(iconLabel)
        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(subtitleLabel)

        stack.addArrangedSubview(headerStack)

        // Spacer
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 8).isActive = true
        stack.addArrangedSubview(spacer)
    }

    // MARK: - Category Header

    private func addCategoryHeader(_ category: SupplementCategory) {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = "── \(category.rawValue) ──"
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = accentGreen
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
        ])

        stack.addArrangedSubview(container)
    }

    // MARK: - Supplement Card

    private func addSupplementCard(_ supplement: SupplementRecommendation) {
        let card = UIView()
        card.backgroundColor = cardBgColor
        card.layer.cornerRadius = 16
        card.layer.borderWidth = 1
        card.layer.borderColor = accentGreen.withAlphaComponent(0.2).cgColor
        card.translatesAutoresizingMaskIntoConstraints = false

        // אייקון גלולה
        let pillIcon = UILabel()
        pillIcon.text = "💊"
        pillIcon.font = .systemFont(ofSize: 24)
        pillIcon.translatesAutoresizingMaskIntoConstraints = false

        // שם התוסף
        let nameLabel = UILabel()
        nameLabel.text = supplement.name
        nameLabel.font = .systemFont(ofSize: 17, weight: .bold)
        nameLabel.textColor = textWhite
        nameLabel.textAlignment = .right
        nameLabel.numberOfLines = 0
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        // מינון - בתוך badge
        let dosageBadge = UIView()
        dosageBadge.backgroundColor = accentGreen.withAlphaComponent(0.15)
        dosageBadge.layer.cornerRadius = 8
        dosageBadge.translatesAutoresizingMaskIntoConstraints = false

        let dosageLabel = UILabel()
        dosageLabel.text = supplement.dosage
        dosageLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        dosageLabel.textColor = accentGreen
        dosageLabel.textAlignment = .center
        dosageLabel.translatesAutoresizingMaskIntoConstraints = false

        dosageBadge.addSubview(dosageLabel)
        NSLayoutConstraint.activate([
            dosageLabel.topAnchor.constraint(equalTo: dosageBadge.topAnchor, constant: 6),
            dosageLabel.leadingAnchor.constraint(equalTo: dosageBadge.leadingAnchor, constant: 12),
            dosageLabel.trailingAnchor.constraint(equalTo: dosageBadge.trailingAnchor, constant: -12),
            dosageLabel.bottomAnchor.constraint(equalTo: dosageBadge.bottomAnchor, constant: -6),
        ])

        // קו הפרדה
        let separator = UIView()
        separator.backgroundColor = AIONDesign.separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        // Reason
        let reasonTitleLabel = UILabel()
        reasonTitleLabel.text = "nutrition.whyRecommended".localized
        reasonTitleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        reasonTitleLabel.textColor = accentCyan
        reasonTitleLabel.textAlignment = LocalizationManager.shared.textAlignment
        reasonTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let reasonLabel = UILabel()
        reasonLabel.text = supplement.reason
        reasonLabel.font = .systemFont(ofSize: 14, weight: .regular)
        reasonLabel.textColor = textGray
        reasonLabel.textAlignment = .right
        reasonLabel.numberOfLines = 0
        reasonLabel.translatesAutoresizingMaskIntoConstraints = false

        // הוספה לכרטיס
        card.addSubview(pillIcon)
        card.addSubview(nameLabel)
        card.addSubview(dosageBadge)
        card.addSubview(separator)
        card.addSubview(reasonTitleLabel)
        card.addSubview(reasonLabel)

        NSLayoutConstraint.activate([
            // אייקון בפינה ימנית עליונה
            pillIcon.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            pillIcon.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            // שם התוסף
            nameLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: pillIcon.leadingAnchor, constant: -12),
            nameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: card.leadingAnchor, constant: 16),

            // Badge מינון
            dosageBadge.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 10),
            dosageBadge.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            // קו הפרדה
            separator.topAnchor.constraint(equalTo: dosageBadge.bottomAnchor, constant: 12),
            separator.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            separator.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            separator.heightAnchor.constraint(equalToConstant: 1),

            // כותרת סיבה
            reasonTitleLabel.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 12),
            reasonTitleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            reasonTitleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            // טקסט סיבה
            reasonLabel.topAnchor.constraint(equalTo: reasonTitleLabel.bottomAnchor, constant: 6),
            reasonLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            reasonLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            reasonLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        stack.addArrangedSubview(card)
    }

    // MARK: - Empty State

    private func addEmptyState() {
        let container = UIView()
        container.backgroundColor = cardBgColor
        container.layer.cornerRadius = 16
        container.translatesAutoresizingMaskIntoConstraints = false

        let iconLabel = UILabel()
        iconLabel.text = "🔍"
        iconLabel.font = .systemFont(ofSize: 48)
        iconLabel.textAlignment = .center
        iconLabel.translatesAutoresizingMaskIntoConstraints = false

        let messageLabel = UILabel()
        messageLabel.text = "nutrition.noRecommendationsYet".localized
        messageLabel.font = .systemFont(ofSize: 15, weight: .regular)
        messageLabel.textColor = textGray
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(iconLabel)
        container.addSubview(messageLabel)

        NSLayoutConstraint.activate([
            iconLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 32),
            iconLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            messageLabel.topAnchor.constraint(equalTo: iconLabel.bottomAnchor, constant: 16),
            messageLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            messageLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            messageLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -32),
        ])

        stack.addArrangedSubview(container)
    }

    // MARK: - Disclaimer

    private func addDisclaimer() {
        let label = UILabel()
        label.text = "⚠️ " + "nutrition.disclaimer".localized
        label.font = .systemFont(ofSize: 11, weight: .regular)
        label.textColor = textGray.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 16).isActive = true
        stack.addArrangedSubview(spacer)

        stack.addArrangedSubview(label)
    }
}
