//
//  InsightsViewController.swift
//  Health Reporter
//
//  מציג את מלוא התובנות – ללא סינון – RTL, קריא.
//

import UIKit

class InsightsViewController: UIViewController {

    var insightsText: String = "" {
        didSet { rebuildContent() }
    }

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let closeButton = UIButton(type: .system)
    private var contentView: UIView?

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
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        scrollView.semanticContentAttribute = .forceRightToLeft
        view.addSubview(scrollView)

        stack.axis = .vertical
        stack.spacing = AIONDesign.spacingLarge
        stack.alignment = .fill
        stack.semanticContentAttribute = .forceRightToLeft
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
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -AIONDesign.spacingLarge * 2),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -AIONDesign.spacing * 2)
        ])
    }

    private func setupHeader() {
        let wrap = UIView()
        wrap.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = "תובנות AION"
        title.font = .systemFont(ofSize: 26, weight: .bold)
        title.textColor = AIONDesign.textPrimary
        title.textAlignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false

        let sub = UILabel()
        sub.text = "ניתוח ביומטרי מבוסס נתונים"
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
        contentView?.removeFromSuperview()
        contentView = nil
        let display = insightsText.trimmingCharacters(in: .whitespacesAndNewlines)
        if display.isEmpty {
            let empty = UILabel()
            empty.text = "אין תובנות זמינות.\nהרץ ניתוח מחדש (רענן נתונים) בדשבורד."
            empty.font = .systemFont(ofSize: 16, weight: .regular)
            empty.textColor = AIONDesign.textSecondary
            empty.textAlignment = .center
            empty.numberOfLines = 0
            empty.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(empty)
            contentView = empty
            return
        }
        let full = InsightFullContentView(text: Self.stripMarkdownForDisplay(display))
        stack.addArrangedSubview(full)
        contentView = full
    }

    /// מסיר ** ומחליף ## בשורות ריקות לתצוגה נקייה.
    private static func stripMarkdownForDisplay(_ s: String) -> String {
        var t = s
        while let r = t.range(of: "**") {
            t.removeSubrange(r)
        }
        t = t.replacingOccurrences(of: "## ", with: "\n\n")
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - תוכן מלא (כל התובנות, RTL)

private final class InsightFullContentView: UIView {
    init(text: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        semanticContentAttribute = .forceRightToLeft
        backgroundColor = AIONDesign.surface
        layer.cornerRadius = AIONDesign.cornerRadiusLarge

        let tv = UITextView()
        tv.attributedText = AIONDesign.attributedStringRTL(text, font: .systemFont(ofSize: 16, weight: .regular), color: AIONDesign.textPrimary)
        tv.backgroundColor = .clear
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.textAlignment = .right
        tv.semanticContentAttribute = .forceRightToLeft
        tv.textContainerInset = UIEdgeInsets(top: AIONDesign.spacing, left: AIONDesign.spacing, bottom: AIONDesign.spacing, right: AIONDesign.spacing)
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
