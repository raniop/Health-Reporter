//
//  GeminiDebugViewController.swift
//  Health Reporter
//
//  מסך דיבאג להצגת השאילתה והתשובה מ-Gemini
//

import UIKit

class GeminiDebugViewController: UIViewController {

    // MARK: - UI Components

    private let segmentedControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["שאילתה", "תשובה", "הבדלים"])
        sc.selectedSegmentIndex = 0
        sc.translatesAutoresizingMaskIntoConstraints = false
        return sc
    }()

    private let textView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        tv.backgroundColor = UIColor.systemBackground
        tv.textColor = UIColor.label
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        return tv
    }()

    private let timestampLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .systemOrange
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let statsLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let copyButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("העתק", for: .normal)
        btn.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private let shareButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("שתף", for: .normal)
        btn.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    // MARK: - Data

    private var promptText: String = "אין שאילתה שמורה"
    private var responseText: String = "אין תשובה שמורה"
    private var differencesText: String = "אין הבדלים להצגה"
    private var differencesAttributedText: NSAttributedString?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
        updateDisplay()
    }

    // MARK: - Setup

    private func setupUI() {
        title = "Gemini Debug"
        view.backgroundColor = .systemBackground

        // Navigation bar
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "סגור",
            style: .done,
            target: self,
            action: #selector(closeTapped)
        )

        // Buttons stack
        let buttonsStack = UIStackView(arrangedSubviews: [copyButton, shareButton])
        buttonsStack.axis = .horizontal
        buttonsStack.spacing = 20
        buttonsStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(timestampLabel)
        view.addSubview(segmentedControl)
        view.addSubview(statsLabel)
        view.addSubview(textView)
        view.addSubview(buttonsStack)

        NSLayoutConstraint.activate([
            timestampLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            timestampLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            timestampLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            segmentedControl.topAnchor.constraint(equalTo: timestampLabel.bottomAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            statsLabel.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            statsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            textView.topAnchor.constraint(equalTo: statsLabel.bottomAnchor, constant: 8),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: buttonsStack.topAnchor, constant: -12),

            buttonsStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            buttonsStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        ])

        // Actions
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
    }

    private func loadData() {
        // Load saved prompt and response
        if let prompt = GeminiDebugStore.lastPrompt {
            promptText = prompt
        }
        if let response = GeminiDebugStore.lastResponse {
            responseText = response
        }

        // Timestamp
        if let timestamp = GeminiDebugStore.timestamp {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "he_IL")
            formatter.dateFormat = "dd/MM/yyyy  HH:mm:ss"
            timestampLabel.text = "🕐 שאילתה אחרונה: \(formatter.string(from: timestamp))"
        } else {
            timestampLabel.text = "🕐 אין שאילתה שמורה"
        }

        // Calculate differences
        calculateDifferences()
    }

    private func calculateDifferences() {
        guard let previousResponse = GeminiDebugStore.previousResponse,
              let currentResponse = GeminiDebugStore.lastResponse else {
            differencesText = "אין תשובה קודמת להשוואה"
            differencesAttributedText = nil
            return
        }

        // Parse both responses
        let previousParsed = parseResponse(previousResponse)
        let currentParsed = parseResponse(currentResponse)

        var differences: [(field: String, old: String, new: String)] = []

        // Compare car name
        if previousParsed.carName != currentParsed.carName {
            differences.append(("🚗 רכב", previousParsed.carName, currentParsed.carName))
        }

        // Compare health score
        if previousParsed.healthScore != currentParsed.healthScore {
            differences.append(("💯 ציון בריאות", previousParsed.healthScore, currentParsed.healthScore))
        }

        // Compare health status
        if previousParsed.healthStatus != currentParsed.healthStatus {
            differences.append(("📊 מצב בריאות", previousParsed.healthStatus, currentParsed.healthStatus))
        }

        // Compare explanation (summarized)
        if previousParsed.explanation != currentParsed.explanation {
            let oldSummary = String(previousParsed.explanation.prefix(100)) + (previousParsed.explanation.count > 100 ? "..." : "")
            let newSummary = String(currentParsed.explanation.prefix(100)) + (currentParsed.explanation.count > 100 ? "..." : "")
            differences.append(("📝 הסבר", oldSummary, newSummary))
        }

        // Build attributed text
        if differences.isEmpty {
            differencesText = "✅ אין הבדלים בין התשובות!\n\nהתשובה הנוכחית זהה לתשובה הקודמת."
            differencesAttributedText = nil
        } else {
            let attributed = NSMutableAttributedString()

            // Title
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .bold),
                .foregroundColor: UIColor.label
            ]
            attributed.append(NSAttributedString(string: "🔄 נמצאו \(differences.count) הבדלים:\n\n", attributes: titleAttrs))

            for (index, diff) in differences.enumerated() {
                // Field name
                let fieldAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                    .foregroundColor: UIColor.label
                ]
                attributed.append(NSAttributedString(string: "\(diff.field)\n", attributes: fieldAttrs))

                // Old value (red)
                let oldAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 13, weight: .regular),
                    .foregroundColor: UIColor.systemRed,
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue
                ]
                attributed.append(NSAttributedString(string: "- \(diff.old)\n", attributes: oldAttrs))

                // New value (green)
                let newAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 13, weight: .regular),
                    .foregroundColor: UIColor.systemGreen
                ]
                attributed.append(NSAttributedString(string: "+ \(diff.new)\n", attributes: newAttrs))

                // Separator
                if index < differences.count - 1 {
                    attributed.append(NSAttributedString(string: "\n", attributes: [:]))
                }
            }

            // Timestamps
            let timestampAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "he_IL")
            formatter.dateFormat = "dd/MM HH:mm"

            attributed.append(NSAttributedString(string: "\n\n", attributes: [:]))

            if let prevTime = GeminiDebugStore.previousTimestamp {
                attributed.append(NSAttributedString(string: "תשובה קודמת: \(formatter.string(from: prevTime))\n", attributes: timestampAttrs))
            }
            if let currTime = GeminiDebugStore.timestamp {
                attributed.append(NSAttributedString(string: "תשובה נוכחית: \(formatter.string(from: currTime))", attributes: timestampAttrs))
            }

            differencesAttributedText = attributed
            differencesText = attributed.string
        }
    }

    private func parseResponse(_ response: String) -> (carName: String, healthScore: String, healthStatus: String, explanation: String) {
        var carName = "לא נמצא"
        var healthScore = "לא נמצא"
        var healthStatus = "לא נמצא"
        var explanation = "לא נמצא"

        let lines = response.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Car name patterns
            if trimmed.hasPrefix("רכב:") || trimmed.hasPrefix("**רכב:**") {
                carName = trimmed
                    .replacingOccurrences(of: "**רכב:**", with: "")
                    .replacingOccurrences(of: "רכב:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("שם הרכב:") || trimmed.hasPrefix("**שם הרכב:**") {
                carName = trimmed
                    .replacingOccurrences(of: "**שם הרכב:**", with: "")
                    .replacingOccurrences(of: "שם הרכב:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }

            // Health score patterns
            if trimmed.hasPrefix("ציון בריאות:") || trimmed.hasPrefix("**ציון בריאות:**") {
                healthScore = trimmed
                    .replacingOccurrences(of: "**ציון בריאות:**", with: "")
                    .replacingOccurrences(of: "ציון בריאות:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("ציון:") || trimmed.hasPrefix("**ציון:**") {
                healthScore = trimmed
                    .replacingOccurrences(of: "**ציון:**", with: "")
                    .replacingOccurrences(of: "ציון:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }

            // Health status patterns
            if trimmed.hasPrefix("מצב בריאות:") || trimmed.hasPrefix("**מצב בריאות:**") {
                healthStatus = trimmed
                    .replacingOccurrences(of: "**מצב בריאות:**", with: "")
                    .replacingOccurrences(of: "מצב בריאות:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("סטטוס:") || trimmed.hasPrefix("**סטטוס:**") {
                healthStatus = trimmed
                    .replacingOccurrences(of: "**סטטוס:**", with: "")
                    .replacingOccurrences(of: "סטטוס:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }

            // Explanation patterns
            if trimmed.hasPrefix("הסבר:") || trimmed.hasPrefix("**הסבר:**") {
                explanation = trimmed
                    .replacingOccurrences(of: "**הסבר:**", with: "")
                    .replacingOccurrences(of: "הסבר:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("תיאור:") || trimmed.hasPrefix("**תיאור:**") {
                explanation = trimmed
                    .replacingOccurrences(of: "**תיאור:**", with: "")
                    .replacingOccurrences(of: "תיאור:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
        }

        return (carName, healthScore, healthStatus, explanation)
    }

    private func updateDisplay() {
        let selectedIndex = segmentedControl.selectedSegmentIndex

        switch selectedIndex {
        case 0: // שאילתה
            textView.attributedText = nil
            textView.text = promptText
            textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)

            let charCount = promptText.count
            let wordCount = promptText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
            statsLabel.text = "שאילתה: \(charCount.formatted()) תווים, \(wordCount.formatted()) מילים"

        case 1: // תשובה
            textView.attributedText = nil
            textView.text = responseText
            textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)

            let charCount = responseText.count
            let wordCount = responseText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
            statsLabel.text = "תשובה: \(charCount.formatted()) תווים, \(wordCount.formatted()) מילים"

        case 2: // הבדלים
            if let attributed = differencesAttributedText {
                textView.attributedText = attributed
            } else {
                textView.attributedText = nil
                textView.text = differencesText
                textView.font = .systemFont(ofSize: 14, weight: .regular)
            }
            statsLabel.text = "השוואה בין תשובה קודמת לנוכחית"

        default:
            break
        }

        // Scroll to top
        textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func segmentChanged() {
        updateDisplay()
    }

    @objc private func copyTapped() {
        let text: String
        switch segmentedControl.selectedSegmentIndex {
        case 0: text = promptText
        case 1: text = responseText
        case 2: text = differencesText
        default: text = ""
        }

        UIPasteboard.general.string = text

        // Feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Show toast
        showToast("הועתק!")
    }

    @objc private func shareTapped() {
        let text: String
        let label: String

        switch segmentedControl.selectedSegmentIndex {
        case 0:
            text = promptText
            label = "Gemini Prompt"
        case 1:
            text = responseText
            label = "Gemini Response"
        case 2:
            text = differencesText
            label = "Gemini Differences"
        default:
            text = ""
            label = ""
        }

        let activityVC = UIActivityViewController(
            activityItems: ["\(label):\n\n\(text)"],
            applicationActivities: nil
        )
        present(activityVC, animated: true)
    }

    private func showToast(_ message: String) {
        let toast = UILabel()
        toast.text = message
        toast.textAlignment = .center
        toast.backgroundColor = UIColor.label.withAlphaComponent(0.8)
        toast.textColor = UIColor.systemBackground
        toast.font = .systemFont(ofSize: 14, weight: .medium)
        toast.layer.cornerRadius = 8
        toast.clipsToBounds = true
        toast.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60),
            toast.widthAnchor.constraint(equalToConstant: 100),
            toast.heightAnchor.constraint(equalToConstant: 36)
        ])

        UIView.animate(withDuration: 0.3, delay: 1.0, options: [], animations: {
            toast.alpha = 0
        }) { _ in
            toast.removeFromSuperview()
        }
    }
}

// MARK: - Debug Store (Singleton to save prompt/response)

enum GeminiDebugStore {
    private static let promptKey = "GeminiDebug.LastPrompt"
    private static let responseKey = "GeminiDebug.LastResponse"
    private static let timestampKey = "GeminiDebug.Timestamp"
    private static let previousResponseKey = "GeminiDebug.PreviousResponse"
    private static let previousTimestampKey = "GeminiDebug.PreviousTimestamp"

    static var lastPrompt: String? {
        get { UserDefaults.standard.string(forKey: promptKey) }
        set { UserDefaults.standard.set(newValue, forKey: promptKey) }
    }

    static var lastResponse: String? {
        get { UserDefaults.standard.string(forKey: responseKey) }
        set { UserDefaults.standard.set(newValue, forKey: responseKey) }
    }

    static var timestamp: Date? {
        get { UserDefaults.standard.object(forKey: timestampKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: timestampKey) }
    }

    static var previousResponse: String? {
        get { UserDefaults.standard.string(forKey: previousResponseKey) }
        set { UserDefaults.standard.set(newValue, forKey: previousResponseKey) }
    }

    static var previousTimestamp: Date? {
        get { UserDefaults.standard.object(forKey: previousTimestampKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: previousTimestampKey) }
    }

    static func save(prompt: String, response: String) {
        // Save current as previous before overwriting
        if let currentResponse = lastResponse, let currentTimestamp = timestamp {
            previousResponse = currentResponse
            previousTimestamp = currentTimestamp
        }

        lastPrompt = prompt
        lastResponse = response
        timestamp = Date()
        print("=== GEMINI DEBUG: Saved prompt (\(prompt.count) chars) and response (\(response.count) chars) ===")
    }
}
