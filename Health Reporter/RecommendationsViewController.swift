//
//  RecommendationsViewController.swift
//  Health Reporter
//
//  עמוד המלצות – עיצוב מחדש. Pro Lab, כרטיסים מעוצבים, גרדיאנטים.
//

import UIKit

class RecommendationsViewController: UIViewController {

    var recommendationsText: String = "" {
        didSet { items = Self.parse(recommendationsText); rebuildContent() }
    }

    private var items: [RecommendationItem] = []
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let closeButton = UIButton(type: .system)
    private let heroGradient = CAGradientLayer()

    private struct RecommendationItem {
        let title: String
        let body: String
        let iconName: String
    }

    private static let iconRotation: [String] = [
        "figure.walk", "bed.double.fill", "leaf.fill",
        "heart.fill", "flame.fill", "drop.fill"
    ]

    private static func parse(_ text: String) -> [RecommendationItem] {
        var result: [RecommendationItem] = []
        var index = 0
        let blocks = text.components(separatedBy: "\n\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        for block in blocks {
            if let item = parseBlock(block, iconIndex: &index) { result.append(item) }
        }
        if result.isEmpty {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { result.append(RecommendationItem(title: "recommendations.title".localized, body: trimmed, iconName: "lightbulb.fill")) }
        }
        return result
    }

    private static func parseBlock(_ block: String, iconIndex: inout Int) -> RecommendationItem? {
        let lines = block.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !lines.isEmpty else { return nil }
        var title: String?
        var bodyLines: [String] = []
        var foundTitle = false
        for line in lines {
            if let bEnd = line.range(of: "**:") {
                let before = String(line[..<bEnd.lowerBound]).replacingOccurrences(of: "*", with: "").replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespaces)
                let after = String(line[bEnd.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !before.isEmpty { if title == nil { title = before; foundTitle = true }; if !after.isEmpty { bodyLines.append(after) } }
                continue
            }
            if foundTitle || title != nil { bodyLines.append(line); continue }
            if line.hasPrefix("•") || line.hasPrefix("*") || line.hasPrefix("-") {
                let cleaned = String(line.drop(while: { "•*- \t".contains($0) }))
                if !cleaned.isEmpty { title = cleaned; foundTitle = true }
            } else if let match = line.range(of: "^(\\d+)\\.\\s*", options: .regularExpression) {
                let cleaned = String(line[match.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !cleaned.isEmpty { title = cleaned; foundTitle = true }
            } else { title = line; foundTitle = true }
        }
        guard let t = title, !t.isEmpty else { return nil }
        let body = bodyLines.joined(separator: "\n\n")
        let icon = iconRotation[iconIndex % iconRotation.count]
        iconIndex += 1
        return RecommendationItem(title: t, body: body, iconName: icon)
    }

    private var isTabMode: Bool { tabBarController != nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "recommendations.title".localized
        view.backgroundColor = AIONDesign.background
        view.semanticContentAttribute = .forceRightToLeft
        setupScrollAndStack()
        setupHero()
        if !isTabMode { setupCloseButton() }
        rebuildContent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if isTabMode {
            navigationController?.setNavigationBarHidden(false, animated: animated)
            // נשתמש בפרסר החדש לחילוץ המלצות מתשובת Gemini
            if recommendationsText.isEmpty, let insights = AnalysisCache.loadLatest(), !insights.isEmpty {
                let parsed = CarAnalysisParser.parse(insights)
                // בנינו מחדש את המלצות מהסקשנים הרלוונטיים
                var recs: [String] = []
                if !parsed.habitToAdd.isEmpty { recs.append("להוסיף: \(parsed.habitToAdd)") }
                if !parsed.habitToRemove.isEmpty { recs.append("להסיר: \(parsed.habitToRemove)") }
                if !parsed.trainingAdjustments.isEmpty { recs.append("אימון: \(parsed.trainingAdjustments)") }
                if !parsed.recoveryChanges.isEmpty { recs.append("התאוששות: \(parsed.recoveryChanges)") }
                recs.append(contentsOf: parsed.upgrades)
                if !recs.isEmpty {
                    recommendationsText = recs.joined(separator: "\n\n")
                }
            }
        } else {
            navigationController?.setNavigationBarHidden(true, animated: animated)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        heroGradient.frame = heroContainer?.bounds ?? .zero
    }

    private var heroContainer: UIView?

    private func setupScrollAndStack() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.semanticContentAttribute = .forceRightToLeft
        view.addSubview(scrollView)

        stack.axis = .vertical
        stack.spacing = AIONDesign.spacingLarge
        stack.alignment = .fill
        stack.semanticContentAttribute = .forceRightToLeft
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        let pad: CGFloat = AIONDesign.spacing
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: pad),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -pad),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -AIONDesign.spacingLarge),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -pad * 2),
        ])
    }

    private func setupHero() {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = AIONDesign.surface
        container.layer.cornerRadius = AIONDesign.cornerRadiusLarge
        container.clipsToBounds = true
        heroContainer = container

        heroGradient.colors = [
            AIONDesign.accentPrimary.withAlphaComponent(0.15).cgColor,
            AIONDesign.accentSuccess.withAlphaComponent(0.08).cgColor,
        ]
        heroGradient.startPoint = CGPoint(x: 0, y: 0)
        heroGradient.endPoint = CGPoint(x: 1, y: 1)
        container.layer.insertSublayer(heroGradient, at: 0)

        let iconBg = UIView()
        iconBg.backgroundColor = AIONDesign.accentPrimary.withAlphaComponent(0.2)
        iconBg.layer.cornerRadius = 28
        iconBg.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: "lightbulb.fill"))
        icon.tintColor = AIONDesign.accentPrimary
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(icon)

        let titleL = UILabel()
        titleL.text = "recommendations.title".localized
        titleL.font = .systemFont(ofSize: 28, weight: .bold)
        titleL.textColor = AIONDesign.textPrimary
        titleL.textAlignment = .center
        titleL.translatesAutoresizingMaskIntoConstraints = false

        let subL = UILabel()
        subL.text = "recommendations.subtitle".localized
        subL.font = .systemFont(ofSize: 14, weight: .medium)
        subL.textColor = AIONDesign.textSecondary
        subL.textAlignment = .center
        subL.numberOfLines = 0
        subL.translatesAutoresizingMaskIntoConstraints = false

        [iconBg, titleL, subL].forEach { container.addSubview($0) }
        stack.addArrangedSubview(container)

        NSLayoutConstraint.activate([
            iconBg.widthAnchor.constraint(equalToConstant: 56),
            iconBg.heightAnchor.constraint(equalToConstant: 56),
            iconBg.topAnchor.constraint(equalTo: container.topAnchor, constant: AIONDesign.spacingLarge),
            iconBg.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            icon.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 26),
            icon.heightAnchor.constraint(equalToConstant: 26),
            titleL.topAnchor.constraint(equalTo: iconBg.bottomAnchor, constant: 14),
            titleL.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: AIONDesign.spacing),
            titleL.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -AIONDesign.spacing),
            subL.topAnchor.constraint(equalTo: titleL.bottomAnchor, constant: 6),
            subL.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: AIONDesign.spacing),
            subL.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -AIONDesign.spacing),
            subL.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -AIONDesign.spacingLarge),
        ])
    }

    private func setupCloseButton() {
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = AIONDesign.textTertiary
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 36),
            closeButton.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    @objc private func closeTapped() { dismiss(animated: true) }

    private func rebuildContent() {
        stack.arrangedSubviews.filter { $0 is RecCardView || $0 is RecEmptyView }.forEach { $0.removeFromSuperview() }
        if items.isEmpty {
            let empty = RecEmptyView()
            stack.addArrangedSubview(empty)
            return
        }
        for (idx, item) in items.enumerated() {
            let card = RecCardView(index: idx + 1, title: item.title, body: item.body, iconName: item.iconName)
            stack.addArrangedSubview(card)
        }
    }
}

// MARK: - כרטיס המלצה מעוצב

private final class RecCardView: UIView {
    init(index: Int, title: String, body: String, iconName: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        semanticContentAttribute = .forceRightToLeft
        backgroundColor = AIONDesign.surface
        layer.cornerRadius = AIONDesign.cornerRadiusLarge
        layer.borderWidth = 1
        layer.borderColor = AIONDesign.separator.cgColor

        let accent = UIView()
        accent.backgroundColor = AIONDesign.accentPrimary
        accent.layer.cornerRadius = 3
        accent.translatesAutoresizingMaskIntoConstraints = false

        let iconBg = UIView()
        iconBg.backgroundColor = AIONDesign.accentSecondary.withAlphaComponent(0.15)
        iconBg.layer.cornerRadius = 20
        iconBg.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: iconName))
        icon.tintColor = AIONDesign.accentSecondary
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(icon)

        let titleL = UILabel()
        titleL.attributedText = AIONDesign.attributedStringRTL(title, font: .systemFont(ofSize: 17, weight: .semibold), color: AIONDesign.textPrimary)
        titleL.numberOfLines = 0
        titleL.translatesAutoresizingMaskIntoConstraints = false

        let bodyL = UILabel()
        bodyL.attributedText = AIONDesign.attributedStringRTL(body, font: .systemFont(ofSize: 15, weight: .regular), color: AIONDesign.textSecondary)
        bodyL.numberOfLines = 0
        bodyL.translatesAutoresizingMaskIntoConstraints = false

        let row = UIStackView(arrangedSubviews: [iconBg, titleL])
        row.axis = .horizontal
        row.spacing = AIONDesign.spacing
        row.alignment = .center
        row.semanticContentAttribute = .forceRightToLeft
        row.translatesAutoresizingMaskIntoConstraints = false

        [accent, row, bodyL].forEach { addSubview($0) }

        NSLayoutConstraint.activate([
            accent.leadingAnchor.constraint(equalTo: leadingAnchor, constant: AIONDesign.spacing),
            accent.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            accent.widthAnchor.constraint(equalToConstant: 4),
            accent.heightAnchor.constraint(equalToConstant: 22),

            iconBg.widthAnchor.constraint(equalToConstant: 40),
            iconBg.heightAnchor.constraint(equalToConstant: 40),
            icon.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),

            row.topAnchor.constraint(equalTo: topAnchor, constant: AIONDesign.spacingLarge),
            row.leadingAnchor.constraint(equalTo: accent.trailingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -AIONDesign.spacing),
            bodyL.topAnchor.constraint(equalTo: row.bottomAnchor, constant: 12),
            bodyL.leadingAnchor.constraint(equalTo: leadingAnchor, constant: AIONDesign.spacing),
            bodyL.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -AIONDesign.spacing),
            bodyL.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -AIONDesign.spacingLarge),
        ])
    }

    required init?(coder: NSCoder) { nil }
}

// MARK: - מצב ריק

private final class RecEmptyView: UIView {
    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        semanticContentAttribute = .forceRightToLeft
        backgroundColor = AIONDesign.surface
        layer.cornerRadius = AIONDesign.cornerRadiusLarge
        layer.borderWidth = 1
        layer.borderColor = AIONDesign.separator.cgColor

        let icon = UIImageView(image: UIImage(systemName: "sparkles"))
        icon.tintColor = AIONDesign.textTertiary
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let msg = UILabel()
        msg.text = "recommendations.noRecommendations".localized
        msg.font = .systemFont(ofSize: 15, weight: .regular)
        msg.textColor = AIONDesign.textSecondary
        msg.textAlignment = .center
        msg.numberOfLines = 0
        msg.translatesAutoresizingMaskIntoConstraints = false

        [icon, msg].forEach { addSubview($0) }
        NSLayoutConstraint.activate([
            icon.topAnchor.constraint(equalTo: topAnchor, constant: AIONDesign.spacingLarge * 2),
            icon.centerXAnchor.constraint(equalTo: centerXAnchor),
            icon.widthAnchor.constraint(equalToConstant: 48),
            icon.heightAnchor.constraint(equalToConstant: 48),
            msg.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: AIONDesign.spacing),
            msg.leadingAnchor.constraint(equalTo: leadingAnchor, constant: AIONDesign.spacingLarge),
            msg.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -AIONDesign.spacingLarge),
            msg.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -AIONDesign.spacingLarge * 2),
        ])
    }
    required init?(coder: NSCoder) { nil }
}
