//
//  AIONSummaryViewController.swift
//  Health Reporter
//
//  מסך נפרד לסיכום AION (החלק התחתון מהתובנות). RTL.
//

import UIKit

class AIONSummaryViewController: UIViewController {

    var summaryText: String = "" {
        didSet { updateText() }
    }

    private let scrollView = UIScrollView()
    private let textView = UITextView()
    private let closeButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AIONDesign.background
        view.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        setupScrollAndText()
        setupCloseButton()
        updateText()
    }

    private func updateText() {
        textView.attributedText = AIONDesign.attributedStringRTL(
            summaryText,
            font: .systemFont(ofSize: 17, weight: .regular),
            color: AIONDesign.textPrimary
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    private func setupScrollAndText() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        scrollView.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        view.addSubview(scrollView)

        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = AIONDesign.surface
        textView.layer.cornerRadius = AIONDesign.cornerRadiusLarge
        textView.textContainerInset = UIEdgeInsets(top: AIONDesign.spacingLarge, left: AIONDesign.spacingLarge, bottom: AIONDesign.spacingLarge, right: AIONDesign.spacingLarge)
        textView.textContainer.lineFragmentPadding = 0
        textView.textAlignment = LocalizationManager.shared.textAlignment
        textView.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        textView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(textView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            textView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: AIONDesign.spacingLarge),
            textView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: AIONDesign.spacing),
            textView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -AIONDesign.spacing),
            textView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -AIONDesign.spacingLarge),
            textView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -AIONDesign.spacing * 2)
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
}
