//
//  RecommendationsViewController.swift
//  Health Reporter
//
//  Created on 24/01/2026.
//

import UIKit

class RecommendationsViewController: UIViewController {
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let headerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let gradientLayer: CAGradientLayer = {
        let gradient = CAGradientLayer()
        gradient.colors = [AIONDesign.accentSecondary.cgColor, AIONDesign.accentPrimary.cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.locations = [0.0, 1.0]
        return gradient
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "RECOMMENDATIONS"
        label.font = .systemFont(ofSize: 24, weight: .semibold)
        label.textAlignment = .right
        label.textColor = AIONDesign.textPrimary
        label.numberOfLines = 0
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Professional Directives"
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textAlignment = .right
        label.textColor = AIONDesign.textSecondary
        return label
    }()
    
    private let recommendationsCard: UIView = {
        let view = UIView()
        view.backgroundColor = AIONDesign.surface
        view.layer.cornerRadius = AIONDesign.cornerRadius
        view.layer.borderWidth = 1
        view.layer.borderColor = AIONDesign.separator.cgColor
        // Glassmorphism effect
        view.alpha = 0.95
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let blurEffectView: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let blurView = UIVisualEffectView(effect: blur)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        return blurView
    }()
    
    private let recommendationsTextView: UITextView = {
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 15, weight: .regular)
        textView.textAlignment = .right
        textView.isEditable = false
        textView.backgroundColor = .clear
        textView.textColor = AIONDesign.textPrimary
        textView.textContainerInset = UIEdgeInsets(top: 32, left: 24, bottom: 32, right: 24)
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.lineBreakMode = .byWordWrapping
        // Better line spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        textView.typingAttributes = [.paragraphStyle: paragraphStyle]
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()
    
    var recommendationsText: String = "" {
        didSet {
            // Format text with better styling
            let formattedText = formatText(recommendationsText)
            recommendationsTextView.attributedText = formattedText
        }
    }
    
    private func formatText(_ text: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        paragraphStyle.paragraphSpacing = 12
        
        let fullRange = NSRange(location: 0, length: text.count)
        attributedString.addAttribute(.foregroundColor, value: AIONDesign.textPrimary, range: fullRange)
        attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 15, weight: .regular), range: fullRange)
        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
        
        // Make headers bold and larger
        let headerPattern = "##\\s+(.+?)\\n"
        if let regex = try? NSRegularExpression(pattern: headerPattern, options: []) {
            regex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
                if let match = match, match.numberOfRanges > 1 {
                    let headerRange = match.range(at: 1)
                    attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 18, weight: .bold), range: headerRange)
                    attributedString.addAttribute(.foregroundColor, value: AIONDesign.accentSecondary, range: headerRange)
                }
            }
        }
        
        // Make bold text (between **)
        let boldPattern = "\\*\\*(.+?)\\*\\*"
        if let regex = try? NSRegularExpression(pattern: boldPattern, options: []) {
            regex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
                if let match = match, match.numberOfRanges > 1 {
                    let boldRange = match.range(at: 1)
                    attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 15, weight: .semibold), range: boldRange)
                }
            }
        }
        
        return attributedString
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
    }
    
    private func setupNavigationBar() {
        let closeButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeTapped))
        closeButton.tintColor = AIONDesign.textPrimary
        navigationItem.rightBarButtonItem = closeButton
        
        // Set navigation bar appearance
        if let navBar = navigationController?.navigationBar {
            navBar.barTintColor = AIONDesign.background
            navBar.titleTextAttributes = [.foregroundColor: AIONDesign.textPrimary]
        }
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    private func setupUI() {
        view.backgroundColor = AIONDesign.background
        
        // Header עם gradient
        headerView.layer.insertSublayer(gradientLayer, at: 0)
        headerView.addSubview(titleLabel)
        headerView.addSubview(subtitleLabel)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 60),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -24),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -24),
            subtitleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -32)
        ])
        
        // Recommendations card with glassmorphism
        recommendationsCard.insertSubview(blurEffectView, at: 0)
        recommendationsCard.addSubview(recommendationsTextView)
        
        NSLayoutConstraint.activate([
            blurEffectView.topAnchor.constraint(equalTo: recommendationsCard.topAnchor),
            blurEffectView.leadingAnchor.constraint(equalTo: recommendationsCard.leadingAnchor),
            blurEffectView.trailingAnchor.constraint(equalTo: recommendationsCard.trailingAnchor),
            blurEffectView.bottomAnchor.constraint(equalTo: recommendationsCard.bottomAnchor),
            
            recommendationsTextView.topAnchor.constraint(equalTo: recommendationsCard.topAnchor),
            recommendationsTextView.leadingAnchor.constraint(equalTo: recommendationsCard.leadingAnchor),
            recommendationsTextView.trailingAnchor.constraint(equalTo: recommendationsCard.trailingAnchor),
            recommendationsTextView.bottomAnchor.constraint(equalTo: recommendationsCard.bottomAnchor)
        ])
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(headerView)
        contentView.addSubview(recommendationsCard)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 200),
            headerView.widthAnchor.constraint(equalTo: contentView.widthAnchor),
            
            recommendationsCard.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -30),
            recommendationsCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            recommendationsCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            recommendationsCard.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32),
            recommendationsCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 500)
        ])
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = headerView.bounds
    }
}
