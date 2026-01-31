//
//  GeminiDebugViewController.swift
//  Health Reporter
//
//  מסך דיבאג להצגת השאילתה והתשובה מ-Gemini
//

import UIKit

class GeminiDebugViewController: UIViewController {

    // MARK: - UI Components

    private lazy var segmentedControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: [
            "debug.query".localized,
            "debug.response".localized,
            "debug.differences".localized,
            "debug.history".localized
        ])
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

    private lazy var copyButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("debug.copy".localized, for: .normal)
        btn.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private lazy var shareButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("debug.share".localized, for: .normal)
        btn.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private let forceGeminiButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("🔄 קרא ל-Gemini עכשיו", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        btn.backgroundColor = .systemOrange
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 10
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private let geminiSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = .white
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()

    // MARK: - Data

    private lazy var promptText: String = "debug.noSavedQuery".localized
    private lazy var responseText: String = "debug.noSavedResponse".localized
    private lazy var differencesText: String = "debug.noDifferences".localized
    private var differencesAttributedText: NSAttributedString?
    private var historyEntries: [DebugLogEntry] = []
    private var historyAttributedText: NSAttributedString?

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
            title: "debug.close".localized,
            style: .done,
            target: self,
            action: #selector(closeTapped)
        )

        // Buttons stack
        let buttonsStack = UIStackView(arrangedSubviews: [copyButton, shareButton])
        buttonsStack.axis = .horizontal
        buttonsStack.spacing = 20
        buttonsStack.translatesAutoresizingMaskIntoConstraints = false

        // Add spinner to force button
        forceGeminiButton.addSubview(geminiSpinner)

        view.addSubview(timestampLabel)
        view.addSubview(segmentedControl)
        view.addSubview(statsLabel)
        view.addSubview(textView)
        view.addSubview(forceGeminiButton)
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
            textView.bottomAnchor.constraint(equalTo: forceGeminiButton.topAnchor, constant: -12),

            forceGeminiButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            forceGeminiButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            forceGeminiButton.heightAnchor.constraint(equalToConstant: 44),
            forceGeminiButton.bottomAnchor.constraint(equalTo: buttonsStack.topAnchor, constant: -12),

            geminiSpinner.centerYAnchor.constraint(equalTo: forceGeminiButton.centerYAnchor),
            geminiSpinner.trailingAnchor.constraint(equalTo: forceGeminiButton.trailingAnchor, constant: -16),

            buttonsStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            buttonsStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        ])

        // Actions
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        forceGeminiButton.addTarget(self, action: #selector(forceGeminiTapped), for: .touchUpInside)
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

        // Load history
        loadHistory()
    }

    private func loadHistory() {
        historyEntries = GeminiDebugStore.loadHistory()

        let attributed = NSMutableAttributedString()

        // Title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .bold),
            .foregroundColor: UIColor.label
        ]
        attributed.append(NSAttributedString(string: "📜 היסטוריה (\(historyEntries.count) רשומות, 7 ימים אחרונים)\n\n", attributes: titleAttrs))

        // Current Health Score from HealthScoreEngine
        if let healthResult = AnalysisCache.loadHealthScoreResult() {
            let currentScoreAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: UIColor.systemGreen
            ]
            attributed.append(NSAttributedString(string: "💯 ציון נוכחי (HealthScoreEngine): \(healthResult.healthScoreInt)\n", attributes: currentScoreAttrs))
            attributed.append(NSAttributedString(string: "📊 אמינות: \(healthResult.reliabilityScoreInt)%\n\n", attributes: currentScoreAttrs))
        }

        // Current Car from cache
        if let car = AnalysisCache.loadSelectedCar() {
            let carAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: UIColor.systemBlue
            ]
            attributed.append(NSAttributedString(string: "🚗 רכב נוכחי: \(car.name)\n", attributes: carAttrs))
            if !car.wikiName.isEmpty && car.wikiName != car.name {
                let wikiAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: UIColor.tertiaryLabel
                ]
                attributed.append(NSAttributedString(string: "   Wiki: \(car.wikiName)\n", attributes: wikiAttrs))
            }
            attributed.append(NSAttributedString(string: "\n", attributes: [:]))
        }

        if historyEntries.isEmpty {
            let noDataAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: UIColor.secondaryLabel
            ]
            attributed.append(NSAttributedString(string: "אין היסטוריה\n", attributes: noDataAttrs))
            historyAttributedText = attributed
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "he_IL")
        dateFormatter.dateFormat = "dd/MM HH:mm"

        for (index, entry) in historyEntries.enumerated() {
            // Date header
            let dateAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: UIColor.systemOrange
            ]
            attributed.append(NSAttributedString(string: "[\(dateFormatter.string(from: entry.timestamp))]\n", attributes: dateAttrs))

            // Try to parse car name from JSON response
            let carName = extractCarNameFromJSON(entry.response) ?? entry.carName ?? "לא זוהה"

            // Car name
            let carAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: UIColor.label
            ]
            attributed.append(NSAttributedString(string: "🚗 רכב: \(carName)\n", attributes: carAttrs))

            // Prompt/Response sizes
            let sizeAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.tertiaryLabel
            ]
            attributed.append(NSAttributedString(string: "📝 שאילתה: \(entry.prompt.count) תווים | תשובה: \(entry.response.count) תווים\n", attributes: sizeAttrs))

            // Separator
            if index < historyEntries.count - 1 {
                let separatorAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 8, weight: .regular),
                    .foregroundColor: UIColor.separator
                ]
                attributed.append(NSAttributedString(string: "───────────────────────────\n\n", attributes: separatorAttrs))
            }
        }

        historyAttributedText = attributed
    }

    private func calculateDifferences() {
        let attributed = NSMutableAttributedString()

        // כותרת
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .bold),
            .foregroundColor: UIColor.label
        ]

        // ציון בריאות נוכחי (מקומי)
        attributed.append(NSAttributedString(string: "💯 ציון בריאות (HealthScoreEngine)\n", attributes: titleAttrs))

        if let healthResult = AnalysisCache.loadHealthScoreResult() {
            let scoreAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: UIColor.systemGreen
            ]
            attributed.append(NSAttributedString(string: "ציון: \(healthResult.healthScoreInt) | אמינות: \(healthResult.reliabilityScoreInt)%\n\n", attributes: scoreAttrs))
        } else {
            let noDataAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: UIColor.secondaryLabel
            ]
            attributed.append(NSAttributedString(string: "אין נתונים\n\n", attributes: noDataAttrs))
        }

        // רכב נוכחי שמור
        attributed.append(NSAttributedString(string: "🚗 רכב נוכחי (שמור)\n", attributes: titleAttrs))
        if let car = AnalysisCache.loadSelectedCar() {
            let carAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: UIColor.label
            ]
            attributed.append(NSAttributedString(string: "\(car.name)\n", attributes: carAttrs))
            if !car.wikiName.isEmpty {
                let wikiAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: UIColor.tertiaryLabel
                ]
                attributed.append(NSAttributedString(string: "Wiki: \(car.wikiName)\n", attributes: wikiAttrs))
            }
        } else {
            let noCarAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: UIColor.secondaryLabel
            ]
            attributed.append(NSAttributedString(string: "לא נבחר רכב\n", attributes: noCarAttrs))
        }
        attributed.append(NSAttributedString(string: "\n", attributes: [:]))

        // השוואת תשובות Gemini - משתמשים בהיסטוריה!
        let history = GeminiDebugStore.loadHistory()
        guard history.count >= 2 else {
            attributed.append(NSAttributedString(string: "📊 השוואת תשובות Gemini\n", attributes: titleAttrs))
            let noCompareAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: UIColor.secondaryLabel
            ]
            attributed.append(NSAttributedString(string: "אין תשובה קודמת להשוואה (צריך לפחות 2 שאילתות בהיסטוריה)\n", attributes: noCompareAttrs))
            differencesAttributedText = attributed
            differencesText = attributed.string
            return
        }

        // השאילתא האחרונה (index 0) והשאילתא שלפניה (index 1)
        let currentEntry = history[0]
        let previousEntry = history[1]
        let currentResponse = currentEntry.response
        let previousResponse = previousEntry.response

        // סטטיסטיקות בסיסיות
        let prevLen = previousResponse.count
        let currLen = currentResponse.count
        let lenDiff = currLen - prevLen

        attributed.append(NSAttributedString(string: "📊 השוואת תשובות Gemini\n", attributes: titleAttrs))

        let statsAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel
        ]
        attributed.append(NSAttributedString(string: "תשובה קודמת: \(prevLen.formatted()) תווים\n", attributes: statsAttrs))
        attributed.append(NSAttributedString(string: "תשובה נוכחית: \(currLen.formatted()) תווים\n", attributes: statsAttrs))

        let diffColor: UIColor = lenDiff > 0 ? .systemGreen : (lenDiff < 0 ? .systemRed : .secondaryLabel)
        let diffAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: diffColor
        ]
        let diffSign = lenDiff > 0 ? "+" : ""
        attributed.append(NSAttributedString(string: "הפרש: \(diffSign)\(lenDiff) תווים\n\n", attributes: diffAttrs))

        // השוואת רכב - מההיסטוריה!
        let prevCar = previousEntry.carName ?? "לא זוהה"
        let currCar = currentEntry.carName ?? "לא זוהה"

        attributed.append(NSAttributedString(string: "🚗 רכב\n", attributes: titleAttrs))

        if prevCar == currCar {
            let sameAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: UIColor.secondaryLabel
            ]
            attributed.append(NSAttributedString(string: "ללא שינוי: \(currCar)\n\n", attributes: sameAttrs))
        } else {
            let oldAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: UIColor.systemRed,
                .strikethroughStyle: NSUnderlineStyle.single.rawValue
            ]
            let newAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: UIColor.systemGreen
            ]
            attributed.append(NSAttributedString(string: "- \(prevCar)\n", attributes: oldAttrs))
            attributed.append(NSAttributedString(string: "+ \(currCar)\n\n", attributes: newAttrs))
        }

        // השוואת שורות - מציאת הבדלים אמיתיים
        let prevLines = previousResponse.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let currLines = currentResponse.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let prevSet = Set(prevLines)
        let currSet = Set(currLines)

        let removed = prevSet.subtracting(currSet)
        let added = currSet.subtracting(prevSet)

        attributed.append(NSAttributedString(string: "📝 שינויים בתוכן\n", attributes: titleAttrs))

        if removed.isEmpty && added.isEmpty {
            let noChangeAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: UIColor.systemGreen
            ]
            attributed.append(NSAttributedString(string: "✅ התוכן זהה (רק הבדלי רווחים/שורות)\n\n", attributes: noChangeAttrs))
        } else {
            let summaryAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor.secondaryLabel
            ]
            attributed.append(NSAttributedString(string: "\(removed.count) שורות נמחקו, \(added.count) שורות נוספו\n\n", attributes: summaryAttrs))

            // שורות שנמחקו (מקסימום 10)
            if !removed.isEmpty {
                let removedHeaderAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
                    .foregroundColor: UIColor.systemRed
                ]
                attributed.append(NSAttributedString(string: "נמחקו:\n", attributes: removedHeaderAttrs))

                let removedLineAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: UIColor.systemRed.withAlphaComponent(0.8)
                ]
                for (index, line) in removed.prefix(10).enumerated() {
                    let truncated = line.count > 80 ? String(line.prefix(80)) + "..." : line
                    attributed.append(NSAttributedString(string: "- \(truncated)\n", attributes: removedLineAttrs))
                    if index == 9 && removed.count > 10 {
                        attributed.append(NSAttributedString(string: "  ...ועוד \(removed.count - 10) שורות\n", attributes: summaryAttrs))
                    }
                }
                attributed.append(NSAttributedString(string: "\n", attributes: [:]))
            }

            // שורות שנוספו (מקסימום 10)
            if !added.isEmpty {
                let addedHeaderAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
                    .foregroundColor: UIColor.systemGreen
                ]
                attributed.append(NSAttributedString(string: "נוספו:\n", attributes: addedHeaderAttrs))

                let addedLineAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: UIColor.systemGreen.withAlphaComponent(0.8)
                ]
                for (index, line) in added.prefix(10).enumerated() {
                    let truncated = line.count > 80 ? String(line.prefix(80)) + "..." : line
                    attributed.append(NSAttributedString(string: "+ \(truncated)\n", attributes: addedLineAttrs))
                    if index == 9 && added.count > 10 {
                        attributed.append(NSAttributedString(string: "  ...ועוד \(added.count - 10) שורות\n", attributes: summaryAttrs))
                    }
                }
            }
        }

        // Timestamps - מההיסטוריה
        let timestampAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: UIColor.tertiaryLabel
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "he_IL")
        formatter.dateFormat = "dd/MM HH:mm"

        attributed.append(NSAttributedString(string: "\n", attributes: [:]))
        attributed.append(NSAttributedString(string: "תשובה קודמת: \(formatter.string(from: previousEntry.timestamp))\n", attributes: timestampAttrs))
        attributed.append(NSAttributedString(string: "תשובה נוכחית: \(formatter.string(from: currentEntry.timestamp))", attributes: timestampAttrs))

        differencesAttributedText = attributed
        differencesText = attributed.string
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
            statsLabel.text = String(format: "debug.queryStats".localized, charCount.formatted(), wordCount.formatted())

        case 1: // תשובה - פרסור וה JSON והצגה יפה
            textView.attributedText = formatJSONResponse(responseText)

            let charCount = responseText.count
            let wordCount = responseText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
            statsLabel.text = String(format: "debug.responseStats".localized, charCount.formatted(), wordCount.formatted())

        case 2: // הבדלים
            if let attributed = differencesAttributedText {
                textView.attributedText = attributed
            } else {
                textView.attributedText = nil
                textView.text = differencesText
                textView.font = .systemFont(ofSize: 14, weight: .regular)
            }
            statsLabel.text = "debug.comparisonStats".localized

        case 3: // היסטוריה
            if let attributed = historyAttributedText {
                textView.attributedText = attributed
            } else {
                textView.attributedText = nil
                textView.text = "debug.noHistory".localized
                textView.font = .systemFont(ofSize: 14, weight: .regular)
            }
            statsLabel.text = String(format: "debug.entriesInLast7Days".localized, historyEntries.count)

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

    @objc private func forceGeminiTapped() {
        // התחלת טעינה
        forceGeminiButton.isEnabled = false
        forceGeminiButton.setTitle("debug.callingGemini".localized, for: .normal)
        geminiSpinner.startAnimating()

        // שליחת notification ל-Dashboard לבצע ניתוח
        NotificationCenter.default.post(
            name: NSNotification.Name("ForceGeminiAnalysis"),
            object: nil
        )

        // מאזין לתוצאה
        var observer: NSObjectProtocol?
        observer = NotificationCenter.default.addObserver(
            forName: HealthDashboardViewController.analysisDidCompleteNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            if let obs = observer {
                NotificationCenter.default.removeObserver(obs)
            }
            self.onGeminiComplete()
        }

        // Timeout אחרי 60 שניות
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            guard let self = self, !self.forceGeminiButton.isEnabled else { return }
            if let obs = observer {
                NotificationCenter.default.removeObserver(obs)
            }
            self.onGeminiComplete(timeout: true)
        }
    }

    private func onGeminiComplete(timeout: Bool = false) {
        geminiSpinner.stopAnimating()
        forceGeminiButton.isEnabled = true
        forceGeminiButton.setTitle("🔄 קרא ל-Gemini עכשיו", for: .normal)

        if timeout {
            showToast("Timeout!")
        } else {
            showToast("debug.completed".localized)
            // רענון הנתונים
            loadData()
            updateDisplay()
        }
    }

    @objc private func copyTapped() {
        let text: String
        switch segmentedControl.selectedSegmentIndex {
        case 0: text = promptText
        case 1: text = responseText
        case 2: text = differencesText
        case 3: text = historyAttributedText?.string ?? "debug.noHistory".localized
        default: text = ""
        }

        UIPasteboard.general.string = text

        // Feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Show toast
        showToast("debug.copied".localized)
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
        case 3:
            text = historyAttributedText?.string ?? "debug.noHistory".localized
            label = "Gemini History (7 days)"
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

    // MARK: - JSON Parsing Helpers

    /// חילוץ שם רכב מתשובת JSON
    private func extractCarNameFromJSON(_ response: String) -> String? {
        if let parsed = CarAnalysisParser.parseJSON(response) {
            return parsed.carModel.isEmpty ? nil : parsed.carModel
        }
        // Fallback to legacy extraction
        return GeminiDebugStore.extractCarName(from: response)
    }

    /// פרסור ועיצוב תשובת JSON
    private func formatJSONResponse(_ response: String) -> NSAttributedString {
        let attributed = NSMutableAttributedString()

        // Header
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: UIColor.systemGreen
        ]
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: UIColor.systemOrange
        ]
        let contentAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: UIColor.label
        ]
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: UIColor.secondaryLabel
        ]

        // Health Score from HealthScoreEngine
        if let healthResult = AnalysisCache.loadHealthScoreResult() {
            attributed.append(NSAttributedString(string: "═══════ ציון בריאות (מקומי) ═══════\n", attributes: headerAttrs))
            attributed.append(NSAttributedString(string: "💯 ציון: \(healthResult.healthScoreInt) | אמינות: \(healthResult.reliabilityScoreInt)%\n", attributes: contentAttrs))

            for domain in healthResult.includedDomains {
                let scoreInt = Int(round(domain.domainScore))
                let weightPercent = Int(round(domain.normalizedWeight * 100))
                attributed.append(NSAttributedString(string: "  • \(domain.domainName): \(scoreInt) (\(weightPercent)%)\n", attributes: labelAttrs))
            }
            if !healthResult.excludedDomains.isEmpty {
                attributed.append(NSAttributedString(string: "  ⚠️ לא נמדד: \(healthResult.excludedDomains.joined(separator: ", "))\n", attributes: labelAttrs))
            }
            attributed.append(NSAttributedString(string: "\n", attributes: [:]))
        }

        // Try to parse as JSON
        if let parsed = CarAnalysisParser.parseJSON(response) {
            attributed.append(NSAttributedString(string: "═══════ תשובת Gemini (JSON) ═══════\n\n", attributes: headerAttrs))

            // Car Identity
            attributed.append(NSAttributedString(string: "🚗 רכב\n", attributes: titleAttrs))
            attributed.append(NSAttributedString(string: "שם: ", attributes: labelAttrs))
            attributed.append(NSAttributedString(string: "\(parsed.carModel)\n", attributes: contentAttrs))
            if !parsed.carWikiName.isEmpty {
                attributed.append(NSAttributedString(string: "Wiki: ", attributes: labelAttrs))
                attributed.append(NSAttributedString(string: "\(parsed.carWikiName)\n", attributes: contentAttrs))
            }
            if !parsed.carExplanation.isEmpty {
                attributed.append(NSAttributedString(string: "\(parsed.carExplanation)\n", attributes: contentAttrs))
            }
            attributed.append(NSAttributedString(string: "\n", attributes: [:]))

            // Performance Review
            attributed.append(NSAttributedString(string: "📊 סקירת ביצועים\n", attributes: titleAttrs))
            if !parsed.engine.isEmpty {
                attributed.append(NSAttributedString(string: "מנוע: ", attributes: labelAttrs))
                attributed.append(NSAttributedString(string: "\(parsed.engine)\n", attributes: contentAttrs))
            }
            if !parsed.transmission.isEmpty {
                attributed.append(NSAttributedString(string: "תיבת הילוכים: ", attributes: labelAttrs))
                attributed.append(NSAttributedString(string: "\(parsed.transmission)\n", attributes: contentAttrs))
            }
            if !parsed.suspension.isEmpty {
                attributed.append(NSAttributedString(string: "מתלים: ", attributes: labelAttrs))
                attributed.append(NSAttributedString(string: "\(parsed.suspension)\n", attributes: contentAttrs))
            }
            if !parsed.fuelEfficiency.isEmpty {
                attributed.append(NSAttributedString(string: "יעילות דלק: ", attributes: labelAttrs))
                attributed.append(NSAttributedString(string: "\(parsed.fuelEfficiency)\n", attributes: contentAttrs))
            }
            if !parsed.electronics.isEmpty {
                attributed.append(NSAttributedString(string: "אלקטרוניקה: ", attributes: labelAttrs))
                attributed.append(NSAttributedString(string: "\(parsed.electronics)\n", attributes: contentAttrs))
            }
            attributed.append(NSAttributedString(string: "\n", attributes: [:]))

            // Bottlenecks
            if !parsed.bottlenecks.isEmpty {
                attributed.append(NSAttributedString(string: "⚠️ צווארי בקבוק\n", attributes: titleAttrs))
                for item in parsed.bottlenecks {
                    attributed.append(NSAttributedString(string: "• \(item)\n", attributes: contentAttrs))
                }
                attributed.append(NSAttributedString(string: "\n", attributes: [:]))
            }

            // Directives
            attributed.append(NSAttributedString(string: "📋 הנחיות פעולה\n", attributes: titleAttrs))
            if !parsed.directiveStop.isEmpty {
                attributed.append(NSAttributedString(string: "🛑 STOP: ", attributes: labelAttrs))
                attributed.append(NSAttributedString(string: "\(parsed.directiveStop)\n", attributes: contentAttrs))
            }
            if !parsed.directiveStart.isEmpty {
                attributed.append(NSAttributedString(string: "✅ START: ", attributes: labelAttrs))
                attributed.append(NSAttributedString(string: "\(parsed.directiveStart)\n", attributes: contentAttrs))
            }
            if !parsed.directiveWatch.isEmpty {
                attributed.append(NSAttributedString(string: "👀 WATCH: ", attributes: labelAttrs))
                attributed.append(NSAttributedString(string: "\(parsed.directiveWatch)\n", attributes: contentAttrs))
            }
            attributed.append(NSAttributedString(string: "\n", attributes: [:]))

            // Summary/Forecast
            if !parsed.summary.isEmpty {
                attributed.append(NSAttributedString(string: "📝 סיכום\n", attributes: titleAttrs))
                attributed.append(NSAttributedString(string: "\(parsed.summary)\n", attributes: contentAttrs))
                attributed.append(NSAttributedString(string: "\n", attributes: [:]))
            }

            // Supplements
            if !parsed.supplements.isEmpty {
                attributed.append(NSAttributedString(string: "💊 תוספים מומלצים\n", attributes: titleAttrs))
                for sup in parsed.supplements {
                    attributed.append(NSAttributedString(string: "• \(sup.name) (\(sup.dosage))\n", attributes: contentAttrs))
                    attributed.append(NSAttributedString(string: "  \(sup.reason)\n", attributes: labelAttrs))
                }
            }

        } else {
            // Fallback - show raw response
            attributed.append(NSAttributedString(string: "═══════ תשובת Gemini (Raw) ═══════\n\n", attributes: headerAttrs))
            let rawAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.label
            ]
            attributed.append(NSAttributedString(string: response, attributes: rawAttrs))
        }

        return attributed
    }
}

// MARK: - Debug Log Entry

struct DebugLogEntry: Codable {
    let timestamp: Date
    let prompt: String
    let response: String
    let carName: String?
    let healthScore: Int?

    /// מזהה ייחודי לכל entry
    var id: String {
        ISO8601DateFormatter().string(from: timestamp)
    }
}

// MARK: - Debug Store (Singleton to save prompt/response with 7-day history)

enum GeminiDebugStore {
    private static let promptKey = "GeminiDebug.LastPrompt"
    private static let responseKey = "GeminiDebug.LastResponse"
    private static let timestampKey = "GeminiDebug.Timestamp"
    private static let previousResponseKey = "GeminiDebug.PreviousResponse"
    private static let previousTimestampKey = "GeminiDebug.PreviousTimestamp"
    private static let historyKey = "GeminiDebug.History"

    /// מקסימום ימים לשמירה
    private static let maxDays: Int = 7
    /// מקסימום entries לשמירה
    private static let maxEntries: Int = 30

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

    // MARK: - History Management

    /// טוען את כל ההיסטוריה
    static func loadHistory() -> [DebugLogEntry] {
        guard let data = UserDefaults.standard.data(forKey: historyKey) else { return [] }
        do {
            let entries = try JSONDecoder().decode([DebugLogEntry].self, from: data)
            return entries.sorted { $0.timestamp > $1.timestamp }
        } catch {
            return []
        }
    }

    /// שומר את ההיסטוריה
    private static func saveHistory(_ entries: [DebugLogEntry]) {
        do {
            let data = try JSONEncoder().encode(entries)
            UserDefaults.standard.set(data, forKey: historyKey)
        } catch {
            // Silent failure
        }
    }

    /// מוסיף entry חדש להיסטוריה
    private static func addToHistory(_ entry: DebugLogEntry) {
        var history = loadHistory()

        // הוספת ה-entry החדש בתחילת הרשימה
        history.insert(entry, at: 0)

        // הסרת entries ישנים מ-7 ימים
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -maxDays, to: Date()) ?? Date()
        history = history.filter { $0.timestamp > cutoffDate }

        // הגבלה למקסימום entries
        if history.count > maxEntries {
            history = Array(history.prefix(maxEntries))
        }

        saveHistory(history)
    }

    /// מחזיר את הרכב מהשאילתא הקודמת (השנייה בהיסטוריה)
    /// משמש לקביעת הרכב הקודם האמיתי במקום keyPreviousCarName
    static func getPreviousCarFromHistory() -> String? {
        let history = loadHistory()
        // ההיסטוריה ממוינת מהחדש לישן, אז index 1 הוא השאילתא הקודמת
        guard history.count >= 2 else { return nil }
        return history[1].carName
    }

    /// מחלץ שם רכב מתשובת Gemini
    /// מחלץ שם רכב מתשובת Gemini (public לשימוש ב-calculateDifferences)
    static func extractCarName(from response: String) -> String? {
        // 1. חיפוש [CAR_WIKI: ...] - הפורמט העיקרי של Gemini
        let wikiPatterns = [
            #"\[CAR_WIKI:\s*([^\]\n]+)\]"#,
            #"CAR_WIKI:\s*([^\]\n]+)"#,
        ]
        for pattern in wikiPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: response, options: [], range: NSRange(response.startIndex..., in: response)),
               let range = Range(match.range(at: 1), in: response) {
                var name = String(response[range]).trimmingCharacters(in: .whitespaces)
                // הסרת (generation) וכו'
                if let paren = name.firstIndex(of: "(") {
                    name = String(name[..<paren]).trimmingCharacters(in: .whitespaces)
                }
                if !name.isEmpty && name.count > 2 {
                    return name
                }
            }
        }

        // 2. חיפוש "אתה כרגע כמו X" או "אתה כרגע X"
        let carPatterns = [
            #"אתה כרגע כמו\s+\*\*([^*]+)\*\*"#,
            #"אתה כרגע\s+\*\*([^*]+)\*\*"#,
            #"אתה כרגע כמו\s+([^:,\n]+)"#,
            #"אתה כרגע\s+([A-Za-z][A-Za-z0-9\s\-]+)"#,
            #"\(([A-Z][a-z]+\s+[A-Za-z0-9\s\-]+)\)"#,  // שם באנגלית בסוגריים
        ]
        for pattern in carPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: response, options: [], range: NSRange(response.startIndex..., in: response)),
               let range = Range(match.range(at: 1), in: response) {
                var name = String(response[range])
                    .replacingOccurrences(of: "**", with: "")
                    .trimmingCharacters(in: .whitespaces)
                // הסרת נקודה או נקודתיים בסוף
                while name.hasSuffix(".") || name.hasSuffix(":") {
                    name = String(name.dropLast()).trimmingCharacters(in: .whitespaces)
                }
                if !name.isEmpty && name.count > 2 && name.count < 60 {
                    return name
                }
            }
        }

        // 3. Fallback - חיפוש ישן
        let lines = response.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("רכב:") || trimmed.hasPrefix("**רכב:**") ||
               trimmed.hasPrefix("שם הרכב:") || trimmed.hasPrefix("**שם הרכב:**") {
                return trimmed
                    .replacingOccurrences(of: "**רכב:**", with: "")
                    .replacingOccurrences(of: "רכב:", with: "")
                    .replacingOccurrences(of: "**שם הרכב:**", with: "")
                    .replacingOccurrences(of: "שם הרכב:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    /// מחלץ ציון בריאות מתשובת Gemini
    private static func extractHealthScore(from response: String) -> Int? {
        let lines = response.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("ציון בריאות:") || trimmed.hasPrefix("**ציון בריאות:**") ||
               trimmed.hasPrefix("ציון:") || trimmed.hasPrefix("**ציון:**") {
                let value = trimmed
                    .replacingOccurrences(of: "**ציון בריאות:**", with: "")
                    .replacingOccurrences(of: "ציון בריאות:", with: "")
                    .replacingOccurrences(of: "**ציון:**", with: "")
                    .replacingOccurrences(of: "ציון:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                // מחלץ מספר מהטקסט
                let numbers = value.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                return Int(numbers)
            }
        }
        return nil
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

        // שימוש ב-CarAnalysisParser לחילוץ שם הרכב - אותו parser כמו ב-UI
        let parsed = CarAnalysisParser.parse(response)
        let carName: String?
        if !parsed.carModel.isEmpty && parsed.carModel.count > 3 {
            carName = parsed.carModel
        } else {
            carName = extractCarName(from: response)  // fallback לשיטה הישנה
        }

        // הוספה להיסטוריה
        let entry = DebugLogEntry(
            timestamp: Date(),
            prompt: prompt,
            response: response,
            carName: carName,
            healthScore: extractHealthScore(from: response)
        )
        addToHistory(entry)
    }

    /// מנקה את כל ההיסטוריה
    static func clearHistory() {
        UserDefaults.standard.removeObject(forKey: historyKey)
    }
}
