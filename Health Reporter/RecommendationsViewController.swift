//
//  RecommendationsViewController.swift
//  Health Reporter
//
//  עיצוב חדש: כרטיס המלצה לכל פריט, אייקונים, קריאות מקסימלית.
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
            if let item = parseBlock(block, iconIndex: &index) {
                result.append(item)
            }
        }
        if result.isEmpty {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                result.append(RecommendationItem(title: "המלצות", body: trimmed, iconName: "lightbulb.fill"))
            }
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
                let before = String(line[..<bEnd.lowerBound])
                let bold = before.replacingOccurrences(of: "*", with: "").replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespaces)
                let after = String(line[bEnd.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !bold.isEmpty {
                    if title == nil { title = bold; foundTitle = true }
                    if !after.isEmpty { bodyLines.append(after) }
                }
                continue
            }
            if foundTitle || title != nil {
                bodyLines.append(line)
            } else if line.hasPrefix("•") || line.hasPrefix("*") || line.hasPrefix("-") {
                let cleaned = String(line.drop(while: { "•*- \t".contains($0) }))
                if !cleaned.isEmpty { title = cleaned; foundTitle = true }
            } else if let match = line.range(of: "^(\\d+)\\.\\s*", options: .regularExpression) {
                let cleaned = String(line[match.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !cleaned.isEmpty { title = cleaned; foundTitle = true }
            } else {
                title = line
                foundTitle = true
            }
        }

        guard let t = title, !t.isEmpty else { return nil }
        let body = bodyLines.joined(separator: "\n\n")
        let icon = iconRotation[iconIndex % iconRotation.count]
        iconIndex += 1
        return RecommendationItem(title: t, body: body, iconName: icon)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AIONDesign.background
        view.semanticContentAttribute = .forceRightToLeft
        setupScrollAndStack()
        setupHeader()
        setupCloseButton()
        rebuildContent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

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

        let lead: CGFloat = 12
        let trail: CGFloat = 28
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: AIONDesign.spacingLarge),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: lead),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -trail),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -AIONDesign.spacingLarge),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -(lead + trail))
        ])
    }

    private func setupHeader() {
        let wrap = UIView()
        wrap.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = "המלצות"
        title.font = .systemFont(ofSize: 26, weight: .bold)
        title.textColor = AIONDesign.textPrimary
        title.textAlignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false

        let sub = UILabel()
        sub.text = "Directives מקצועיות"
        sub.font = .systemFont(ofSize: 15, weight: .regular)
        sub.textColor = AIONDesign.textSecondary
        sub.textAlignment = .center
        sub.translatesAutoresizingMaskIntoConstraints = false

        wrap.addSubview(title)
        wrap.addSubview(sub)
        stack.addArrangedSubview(wrap)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: wrap.topAnchor),
            title.leadingAnchor.constraint(equalTo: wrap.leadingAnchor),
            title.trailingAnchor.constraint(equalTo: wrap.trailingAnchor),

            sub.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            sub.leadingAnchor.constraint(equalTo: wrap.leadingAnchor),
            sub.trailingAnchor.constraint(equalTo: wrap.trailingAnchor),
            sub.bottomAnchor.constraint(equalTo: wrap.bottomAnchor)
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
            closeButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    private func rebuildContent() {
        stack.arrangedSubviews.filter { $0 is RecCardView || $0 is RecFallbackView }.forEach { $0.removeFromSuperview() }
        if items.isEmpty {
            let fallback = RecFallbackView(text: recommendationsText)
            stack.addArrangedSubview(fallback)
            return
        }
        for item in items {
            stack.addArrangedSubview(RecCardView(title: item.title, body: item.body, iconName: item.iconName))
        }
    }
}

// MARK: - Recommendation card

private final class RecCardView: UIView {
    init(title: String, body: String, iconName: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        semanticContentAttribute = .forceRightToLeft
        backgroundColor = AIONDesign.surface
        layer.cornerRadius = AIONDesign.cornerRadiusLarge
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.06
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 8

        let inner = UIStackView()
        inner.axis = .horizontal
        inner.spacing = AIONDesign.spacing
        inner.alignment = .top
        inner.semanticContentAttribute = .forceRightToLeft
        inner.translatesAutoresizingMaskIntoConstraints = false
        addSubview(inner)

        let iconBg = UIView()
        iconBg.backgroundColor = AIONDesign.accentSecondary.withAlphaComponent(0.12)
        iconBg.layer.cornerRadius = 12
        iconBg.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: iconName))
        icon.tintColor = AIONDesign.accentSecondary
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(icon)

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 6
        textStack.alignment = .leading
        textStack.semanticContentAttribute = .forceRightToLeft

        let titL = UILabel()
        titL.attributedText = AIONDesign.attributedStringRTL(title, font: .systemFont(ofSize: 17, weight: .semibold), color: AIONDesign.textPrimary)
        titL.numberOfLines = 0
        textStack.addArrangedSubview(titL)

        if !body.isEmpty {
            let bL = UILabel()
            bL.attributedText = AIONDesign.attributedStringRTL(body, font: .systemFont(ofSize: 15, weight: .regular), color: AIONDesign.textSecondary)
            bL.numberOfLines = 0
            textStack.addArrangedSubview(bL)
        }

        inner.addArrangedSubview(iconBg)
        inner.addArrangedSubview(textStack)

        let padLead: CGFloat = 14
        let padTrail: CGFloat = 24
        NSLayoutConstraint.activate([
            iconBg.widthAnchor.constraint(equalToConstant: 44),
            iconBg.heightAnchor.constraint(equalToConstant: 44),
            icon.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 22),

            inner.topAnchor.constraint(equalTo: topAnchor, constant: AIONDesign.spacingLarge),
            inner.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padLead),
            inner.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padTrail),
            inner.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -AIONDesign.spacingLarge)
        ])
    }

    required init?(coder: NSCoder) { nil }
}

// MARK: - Fallback

private final class RecFallbackView: UIView {
    init(text: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        semanticContentAttribute = .forceRightToLeft
        backgroundColor = AIONDesign.surface
        layer.cornerRadius = AIONDesign.cornerRadiusLarge
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.06
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 8

        let tv = UITextView()
        let str = text.isEmpty ? "אין המלצות זמינות כרגע." : text
        tv.attributedText = AIONDesign.attributedStringRTL(str, font: .systemFont(ofSize: 15, weight: .regular), color: AIONDesign.textPrimary)
        tv.backgroundColor = .clear
        tv.isEditable = false
        tv.textAlignment = .right
        tv.semanticContentAttribute = .forceRightToLeft
        tv.textContainerInset = UIEdgeInsets(top: AIONDesign.spacingLarge, left: 24, bottom: AIONDesign.spacingLarge, right: 14)
        tv.textContainer.lineFragmentPadding = 0
        tv.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tv)
        NSLayoutConstraint.activate([
            tv.topAnchor.constraint(equalTo: topAnchor),
            tv.leadingAnchor.constraint(equalTo: leadingAnchor),
            tv.trailingAnchor.constraint(equalTo: trailingAnchor),
            tv.bottomAnchor.constraint(equalTo: bottomAnchor),
            tv.heightAnchor.constraint(greaterThanOrEqualToConstant: 120)
        ])
    }
    required init?(coder: NSCoder) { nil }
}
