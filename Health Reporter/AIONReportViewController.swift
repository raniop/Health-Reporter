//
//  AIONReportViewController.swift
//  Health Reporter
//
//  Separate screen for full AION report (insights + recommendations + risk factors). RTL.
//

import UIKit

class AIONReportViewController: UIViewController {

    var reportText: String = "" {
        didSet { parsed = Self.parse(reportText); rebuildContent() }
    }

    private var parsed: ParsedReport?
    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    private struct ParsedReport {
        var intro: String?
        var statusPills: [(label: String, color: UIColor)]
        var risksSection: [(title: String, body: String)]
        var recommendationsSection: [(title: String, body: String)]
        var otherSections: [(title: String, items: [(title: String, body: String)])]
        var rawFallback: String?
    }

    private static func parse(_ text: String) -> ParsedReport? {
        let red = AIONDesign.accentDanger
        let yellow = AIONDesign.accentWarning
        let green = AIONDesign.accentSuccess
        var intro: String?
        var pills: [(String, UIColor)] = []
        var risks: [(String, String)] = []
        var recs: [(String, String)] = []
        var other: [(String, [(String, String)])] = []
        var currentTitle = ""
        var currentItems: [(String, String)] = []
        var fallback: [String] = []

        func addPill(_ label: String, _ color: UIColor) {
            if !label.isEmpty { pills.append((label, color)) }
        }

        func flushSection() {
            if !currentItems.isEmpty {
                let t = currentTitle.isEmpty ? "פרטים" : currentTitle
                if t.contains("סיכון") || t.contains("גורמי") { risks.append(contentsOf: currentItems) }
                else if t.contains("המלצות") || t.contains("מעשיות") { recs.append(contentsOf: currentItems) }
                else { other.append((t, currentItems)) }
                currentItems = []
            }
            currentTitle = ""
        }

        let blocks = text.components(separatedBy: "\n\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

        func isSectionHeader(_ s: String) -> String? {
            let t = s.trimmingCharacters(in: .whitespaces)
            if t == "המלצות:" || t.hasPrefix("המלצות:") { return "המלצות" }
            if t.contains("גורמי סיכון") { return "גורמי סיכון (אם יש)" }
            return nil
        }

        for block in blocks {
            if block.contains("שלום") && block.count < 200 {
                intro = block
                continue
            }
            if block.contains("THREE-LIGHT") || block.contains("🚦") {
                if block.contains("🔴") || block.range(of: "RED", options: .caseInsensitive) != nil { addPill("🔴 RED", red) }
                if block.contains("🟡") || block.range(of: "YELLOW", options: .caseInsensitive) != nil { addPill("🟡 YELLOW", yellow) }
                if block.contains("🟢") || block.range(of: "GREEN", options: .caseInsensitive) != nil { addPill("🟢 GREEN", green) }
                continue
            }
            if block.hasPrefix("## ") {
                flushSection()
                let rest = String(block.dropFirst(3))
                let firstLine = rest.components(separatedBy: "\n").first ?? rest
                currentTitle = firstLine.replacingOccurrences(of: "##", with: "").trimmingCharacters(in: .whitespaces)
                for line in rest.components(separatedBy: "\n").dropFirst() {
                    parseBullet(line, into: &currentItems, fallback: &fallback)
                }
                continue
            }
            let lines = block.components(separatedBy: "\n")
            var i = 0
            while i < lines.count {
                let line = lines[i]
                if let h = isSectionHeader(line) {
                    flushSection()
                    currentTitle = h
                    i += 1
                    while i < lines.count {
                        parseBullet(lines[i], into: &currentItems, fallback: &fallback)
                        i += 1
                    }
                    break
                }
                parseBullet(line, into: &currentItems, fallback: &fallback)
                i += 1
            }
        }
        flushSection()

        let fb = fallback.isEmpty ? nil : fallback.joined(separator: "\n\n")
        return ParsedReport(intro: intro, statusPills: pills, risksSection: risks, recommendationsSection: recs, otherSections: other, rawFallback: fb)
    }

    private static func parseBullet(_ line: String, into items: inout [(String, String)], fallback: inout [String]) {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        if let bEnd = t.range(of: "**:") {
            let before = String(t[..<bEnd.lowerBound])
            let bold = before.replacingOccurrences(of: "*", with: "").replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespaces)
            let after = String(t[bEnd.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !bold.isEmpty { items.append((bold, after)); return }
        }
        if let m = t.range(of: "^(\\d+)\\.\\s*", options: .regularExpression) {
            let rest = String(t[m.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !rest.isEmpty { items.append((rest, "")); return }
        }
        fallback.append(t)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AIONDesign.background
        view.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        title = "report.title".localized
        setupScrollAndStack()
        setupHeader()
        rebuildContent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    private func setupScrollAndStack() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        scrollView.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        view.addSubview(scrollView)

        stack.axis = .vertical
        stack.spacing = AIONDesign.spacingLarge
        stack.alignment = .fill
        stack.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: AIONDesign.spacingLarge),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: AIONDesign.spacing),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -AIONDesign.spacing),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -AIONDesign.spacingLarge),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -AIONDesign.spacing * 2)
        ])
    }

    private func setupHeader() {
        let wrap = UIView()
        wrap.translatesAutoresizingMaskIntoConstraints = false
        wrap.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute

        let accent = UIView()
        accent.backgroundColor = AIONDesign.accentPrimary
        accent.layer.cornerRadius = 2
        accent.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "report.title".localized
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = AIONDesign.textPrimary
        titleLabel.textAlignment = LocalizationManager.shared.textAlignment
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let sub = UILabel()
        sub.text = "report.subtitle".localized
        sub.font = .systemFont(ofSize: 15, weight: .regular)
        sub.textColor = AIONDesign.textSecondary
        sub.textAlignment = LocalizationManager.shared.textAlignment
        sub.translatesAutoresizingMaskIntoConstraints = false

        wrap.addSubview(accent)
        wrap.addSubview(titleLabel)
        wrap.addSubview(sub)
        stack.addArrangedSubview(wrap)

        NSLayoutConstraint.activate([
            accent.topAnchor.constraint(equalTo: wrap.topAnchor),
            accent.trailingAnchor.constraint(equalTo: wrap.trailingAnchor),
            accent.widthAnchor.constraint(equalToConstant: 4),
            accent.heightAnchor.constraint(equalToConstant: 28),

            titleLabel.topAnchor.constraint(equalTo: wrap.topAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: accent.leadingAnchor, constant: -12),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: wrap.leadingAnchor),

            sub.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            sub.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            sub.leadingAnchor.constraint(greaterThanOrEqualTo: wrap.leadingAnchor),
            sub.bottomAnchor.constraint(equalTo: wrap.bottomAnchor)
        ])
    }

    private func rebuildContent() {
        stack.arrangedSubviews.filter { $0 is ReportCardView || $0 is StatusPillRow || $0 is ReportIntroView || $0 is ReportFallbackView }.forEach { $0.removeFromSuperview() }
        guard let p = parsed else {
            addFallback(reportText)
            return
        }

        if let intro = p.intro, !intro.isEmpty {
            stack.addArrangedSubview(ReportIntroView(text: intro))
        }
        if !p.statusPills.isEmpty {
            stack.addArrangedSubview(StatusPillRow(pills: p.statusPills))
        }
        if !p.risksSection.isEmpty {
            stack.addArrangedSubview(ReportCardView(sectionTitle: "גורמי סיכון (אם יש)", items: p.risksSection, iconName: "exclamationmark.triangle.fill"))
        }
        if !p.recommendationsSection.isEmpty {
            stack.addArrangedSubview(ReportCardView(sectionTitle: "המלצות", items: p.recommendationsSection, iconName: "lightbulb.fill"))
        }
        for sec in p.otherSections {
            stack.addArrangedSubview(ReportCardView(sectionTitle: sec.title, items: sec.items, iconName: nil))
        }
        if let fb = p.rawFallback, !fb.isEmpty {
            addFallback(fb)
        }
    }

    private func addFallback(_ text: String) {
        stack.addArrangedSubview(ReportFallbackView(text: text))
    }
}

// MARK: - Report card (RTL)

private final class ReportCardView: UIView {
    init(sectionTitle: String, items: [(title: String, body: String)], iconName: String?) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        backgroundColor = AIONDesign.surface
        layer.cornerRadius = AIONDesign.cornerRadiusLarge
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.06
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 8

        let inner = UIStackView()
        inner.axis = .vertical
        inner.spacing = AIONDesign.spacing
        inner.alignment = .trailing
        inner.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        inner.translatesAutoresizingMaskIntoConstraints = false
        addSubview(inner)

        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.spacing = 8
        headerStack.alignment = .center
        headerStack.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute

        if let icon = iconName {
            let iv = UIImageView(image: UIImage(systemName: icon))
            iv.tintColor = AIONDesign.accentWarning
            iv.contentMode = .scaleAspectFit
            iv.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([iv.widthAnchor.constraint(equalToConstant: 22), iv.heightAnchor.constraint(equalToConstant: 22)])
            headerStack.addArrangedSubview(iv)
        }
        let l = UILabel()
        l.text = sectionTitle
        l.font = .systemFont(ofSize: 17, weight: .semibold)
        l.textColor = AIONDesign.textPrimary
        l.textAlignment = LocalizationManager.shared.textAlignment
        l.numberOfLines = 0
        headerStack.addArrangedSubview(l)
        inner.addArrangedSubview(headerStack)

        for (tit, body) in items {
            let row = UIStackView()
            row.axis = .vertical
            row.spacing = 4
            row.alignment = .trailing
            row.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute

            let titL = UILabel()
            titL.text = tit
            titL.font = .systemFont(ofSize: 15, weight: .semibold)
            titL.textColor = AIONDesign.textPrimary
            titL.numberOfLines = 0
            titL.textAlignment = LocalizationManager.shared.textAlignment

            row.addArrangedSubview(titL)
            if !body.isEmpty {
                let bL = UILabel()
                bL.text = body
                bL.font = .systemFont(ofSize: 14, weight: .regular)
                bL.textColor = AIONDesign.textSecondary
                bL.numberOfLines = 0
                bL.textAlignment = LocalizationManager.shared.textAlignment
                row.addArrangedSubview(bL)
            }
            inner.addArrangedSubview(row)
        }

        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: topAnchor, constant: AIONDesign.spacingLarge),
            inner.leadingAnchor.constraint(equalTo: leadingAnchor, constant: AIONDesign.spacing),
            inner.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -AIONDesign.spacing),
            inner.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -AIONDesign.spacingLarge)
        ])
    }

    required init?(coder: NSCoder) { nil }
}

// MARK: - Status pills (RTL)

private final class StatusPillRow: UIView {
    init(pills: [(label: String, color: UIColor)]) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        let h = UIStackView()
        h.axis = .horizontal
        h.spacing = 8
        h.distribution = .fill
        h.alignment = .center
        h.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        h.translatesAutoresizingMaskIntoConstraints = false
        addSubview(h)
        for (l, c) in pills {
            let wrap = UIView()
            wrap.backgroundColor = c
            wrap.layer.cornerRadius = 10
            wrap.translatesAutoresizingMaskIntoConstraints = false
            let p = UILabel()
            p.text = "  \(l)  "
            p.font = .systemFont(ofSize: 13, weight: .semibold)
            p.textColor = .white
            p.textAlignment = .center
            wrap.addSubview(p)
            p.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                p.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 6),
                p.leadingAnchor.constraint(equalTo: wrap.leadingAnchor),
                p.trailingAnchor.constraint(equalTo: wrap.trailingAnchor),
                p.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -6)
            ])
            h.addArrangedSubview(wrap)
        }
        NSLayoutConstraint.activate([
            h.topAnchor.constraint(equalTo: topAnchor),
            h.trailingAnchor.constraint(equalTo: trailingAnchor),
            h.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            h.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    required init?(coder: NSCoder) { nil }
}

// MARK: - Intro (RTL)

private final class ReportIntroView: UIView {
    init(text: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: 15, weight: .regular)
        l.textColor = AIONDesign.textSecondary
        l.numberOfLines = 0
        l.textAlignment = LocalizationManager.shared.textAlignment
        l.translatesAutoresizingMaskIntoConstraints = false
        addSubview(l)
        NSLayoutConstraint.activate([
            l.topAnchor.constraint(equalTo: topAnchor),
            l.leadingAnchor.constraint(equalTo: leadingAnchor),
            l.trailingAnchor.constraint(equalTo: trailingAnchor),
            l.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    required init?(coder: NSCoder) { nil }
}

// MARK: - Fallback (RTL)

private final class ReportFallbackView: UIView {
    init(text: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        backgroundColor = AIONDesign.surface
        layer.cornerRadius = AIONDesign.cornerRadiusLarge
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.06
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 8

        let tv = UITextView()
        tv.text = text
        tv.font = .systemFont(ofSize: 15, weight: .regular)
        tv.textColor = AIONDesign.textPrimary
        tv.backgroundColor = .clear
        tv.isEditable = false
        tv.textAlignment = LocalizationManager.shared.textAlignment
        tv.textContainerInset = UIEdgeInsets(top: AIONDesign.spacingLarge, left: AIONDesign.spacing, bottom: AIONDesign.spacingLarge, right: AIONDesign.spacing)
        tv.textContainer.lineFragmentPadding = 0
        tv.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
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
