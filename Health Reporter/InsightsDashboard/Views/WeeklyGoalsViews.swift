//
//  WeeklyGoalsViews.swift
//  Health Reporter
//
//  UI components for the weekly actionable goals system.
//  Follows the glass-morphism card pattern from NewHomeViews.swift.
//

import UIKit

// MARK: - RTL Helper (private)

private var isRTL: Bool {
    LocalizationManager.shared.currentLanguage == .hebrew
}
private var semanticAttr: UISemanticContentAttribute {
    isRTL ? .forceRightToLeft : .forceLeftToRight
}
private var txtAlignment: NSTextAlignment {
    isRTL ? .right : .left
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Weekly Goals Section View (Home Screen)
// ═══════════════════════════════════════════════════════════════════

final class WeeklyGoalsSectionView: UIView {

    var onHistoryTapped: (() -> Void)?
    var onGenerateGoalsTapped: (() -> Void)?
    var onRefreshGoalsTapped: (() -> Void)?

    private let sectionTitle = UILabel()
    private let progressLabel = UILabel()
    private let refreshButton = UIButton(type: .system)
    private let cardsStack = UIStackView()
    private let historyButton = UIButton(type: .system)
    private let emptyLabel = UILabel()
    private let allDoneContainer = UIView()
    private let generateContainer = UIView()
    private let generateButton = UIButton(type: .system)
    private let loadingSpinner = UIActivityIndicatorView(style: .medium)
    private let loadingLabel = UILabel()
    private var generateTargetIcon: UIImageView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        semanticContentAttribute = semanticAttr

        // Section title row (title + progress + refresh)
        let titleRow = UIStackView(arrangedSubviews: [sectionTitle, progressLabel, refreshButton])
        titleRow.axis = .horizontal
        titleRow.alignment = .center
        titleRow.distribution = .fill
        titleRow.spacing = 8
        titleRow.semanticContentAttribute = semanticAttr

        sectionTitle.text = "goals.title".localized
        sectionTitle.font = .systemFont(ofSize: 18, weight: .bold)
        sectionTitle.textColor = AIONDesign.textPrimary
        sectionTitle.textAlignment = txtAlignment
        sectionTitle.setContentHuggingPriority(.defaultLow, for: .horizontal)

        progressLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        progressLabel.textColor = AIONDesign.accentSecondary
        progressLabel.textAlignment = isRTL ? .left : .right

        // Refresh button (small circular icon)
        let refreshSize: CGFloat = 28
        refreshButton.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        refreshButton.layer.cornerRadius = refreshSize / 2
        refreshButton.layer.borderWidth = 0.5
        refreshButton.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        let refreshCfg = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        refreshButton.setImage(UIImage(systemName: "arrow.triangle.2.circlepath", withConfiguration: refreshCfg), for: .normal)
        refreshButton.tintColor = UIColor.white
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        refreshButton.accessibilityLabel = "goals.refresh".localized
        refreshButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)
        refreshButton.isHidden = true // Hidden until goals exist
        NSLayoutConstraint.activate([
            refreshButton.widthAnchor.constraint(equalToConstant: refreshSize),
            refreshButton.heightAnchor.constraint(equalToConstant: refreshSize),
        ])

        // Cards stack
        cardsStack.axis = .vertical
        cardsStack.spacing = 10

        // All-done view
        setupAllDoneContainer()

        // Generate goals container (shown when no goals exist)
        setupGenerateContainer()

        // Empty label (fallback, hidden by default)
        emptyLabel.text = "goals.noGoals".localized
        emptyLabel.font = .systemFont(ofSize: 14, weight: .regular)
        emptyLabel.textColor = AIONDesign.textSecondary
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.isHidden = true

        // History button
        historyButton.setTitle("goals.history".localized, for: .normal)
        historyButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        historyButton.setTitleColor(AIONDesign.accentPrimary, for: .normal)
        historyButton.addTarget(self, action: #selector(historyTapped), for: .touchUpInside)
        historyButton.contentHorizontalAlignment = isRTL ? .right : .left

        let mainStack = UIStackView(arrangedSubviews: [titleRow, cardsStack, allDoneContainer, generateContainer, emptyLabel, historyButton])
        mainStack.axis = .vertical
        mainStack.spacing = 10
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.semanticContentAttribute = semanticAttr
        addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func setupAllDoneContainer() {
        allDoneContainer.isHidden = true

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: AIONDesign.glassBlurStyle))
        blur.alpha = AIONDesign.glassBlurAlpha
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = AIONDesign.cornerRadius
        blur.clipsToBounds = true
        allDoneContainer.addSubview(blur)
        allDoneContainer.layer.cornerRadius = AIONDesign.cornerRadius

        let checkCfg = UIImage.SymbolConfiguration(pointSize: 32, weight: .medium)
        let checkIcon = UIImageView(image: UIImage(systemName: "checkmark.circle.fill", withConfiguration: checkCfg))
        checkIcon.tintColor = AIONDesign.accentSuccess
        checkIcon.contentMode = .scaleAspectFit

        let doneLabel = UILabel()
        doneLabel.text = "goals.allDone".localized
        doneLabel.font = .systemFont(ofSize: 16, weight: .bold)
        doneLabel.textColor = AIONDesign.accentSuccess
        doneLabel.textAlignment = .center

        let subtitleLabel = UILabel()
        subtitleLabel.text = "goals.allDone.subtitle".localized
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = AIONDesign.textSecondary
        subtitleLabel.textAlignment = .center

        let innerStack = UIStackView(arrangedSubviews: [checkIcon, doneLabel, subtitleLabel])
        innerStack.axis = .vertical
        innerStack.spacing = 6
        innerStack.alignment = .center
        innerStack.translatesAutoresizingMaskIntoConstraints = false
        allDoneContainer.addSubview(innerStack)

        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: allDoneContainer.topAnchor),
            blur.leadingAnchor.constraint(equalTo: allDoneContainer.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: allDoneContainer.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: allDoneContainer.bottomAnchor),

            innerStack.topAnchor.constraint(equalTo: allDoneContainer.topAnchor, constant: 20),
            innerStack.leadingAnchor.constraint(equalTo: allDoneContainer.leadingAnchor, constant: 20),
            innerStack.trailingAnchor.constraint(equalTo: allDoneContainer.trailingAnchor, constant: -20),
            innerStack.bottomAnchor.constraint(equalTo: allDoneContainer.bottomAnchor, constant: -20),
        ])
    }

    private func setupGenerateContainer() {
        generateContainer.isHidden = true
        generateContainer.translatesAutoresizingMaskIntoConstraints = false

        // Glass background
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: AIONDesign.glassBlurStyle))
        blur.alpha = AIONDesign.glassBlurAlpha
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = AIONDesign.cornerRadius
        blur.clipsToBounds = true
        generateContainer.addSubview(blur)
        generateContainer.layer.cornerRadius = AIONDesign.cornerRadius

        // Target icon
        let iconCfg = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        let targetIcon = UIImageView(image: UIImage(systemName: "target", withConfiguration: iconCfg))
        targetIcon.tintColor = AIONDesign.textSecondary
        targetIcon.contentMode = .scaleAspectFit
        targetIcon.translatesAutoresizingMaskIntoConstraints = false
        self.generateTargetIcon = targetIcon

        // Subtitle
        let subtitleLabel = UILabel()
        subtitleLabel.text = "goals.generate.subtitle".localized
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = AIONDesign.textSecondary
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        // Generate button (matching recommendations retry style)
        generateButton.setTitle("goals.generate.button".localized, for: .normal)
        generateButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        generateButton.setTitleColor(.white, for: .normal)
        generateButton.backgroundColor = AIONDesign.accentPrimary
        generateButton.layer.cornerRadius = 12
        generateButton.translatesAutoresizingMaskIntoConstraints = false
        generateButton.addTarget(self, action: #selector(generateTapped), for: .touchUpInside)

        // Sparkles icon on button
        let sparkleCfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        let sparkleImage = UIImage(systemName: "sparkles", withConfiguration: sparkleCfg)
        generateButton.setImage(sparkleImage, for: .normal)
        generateButton.tintColor = .white
        generateButton.semanticContentAttribute = semanticAttr
        if isRTL {
            generateButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 0)
        } else {
            generateButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 6)
        }

        // Loading spinner (hidden by default)
        loadingSpinner.color = AIONDesign.accentPrimary
        loadingSpinner.hidesWhenStopped = true
        loadingSpinner.translatesAutoresizingMaskIntoConstraints = false

        // Loading label (hidden by default)
        loadingLabel.text = "goals.generate.loading".localized
        loadingLabel.font = .systemFont(ofSize: 14, weight: .medium)
        loadingLabel.textColor = AIONDesign.textSecondary
        loadingLabel.textAlignment = .center
        loadingLabel.isHidden = true

        let innerStack = UIStackView(arrangedSubviews: [targetIcon, subtitleLabel, generateButton, loadingSpinner, loadingLabel])
        innerStack.axis = .vertical
        innerStack.spacing = 10
        innerStack.alignment = .center
        innerStack.translatesAutoresizingMaskIntoConstraints = false
        generateContainer.addSubview(innerStack)

        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: generateContainer.topAnchor),
            blur.leadingAnchor.constraint(equalTo: generateContainer.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: generateContainer.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: generateContainer.bottomAnchor),

            innerStack.topAnchor.constraint(equalTo: generateContainer.topAnchor, constant: 20),
            innerStack.leadingAnchor.constraint(equalTo: generateContainer.leadingAnchor, constant: 20),
            innerStack.trailingAnchor.constraint(equalTo: generateContainer.trailingAnchor, constant: -20),
            innerStack.bottomAnchor.constraint(equalTo: generateContainer.bottomAnchor, constant: -20),

            generateButton.heightAnchor.constraint(equalToConstant: 44),
            generateButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
        ])
    }

    @objc private func generateTapped() {
        onGenerateGoalsTapped?()
    }

    @objc private func refreshTapped() {
        onRefreshGoalsTapped?()
    }

    @objc private func historyTapped() {
        onHistoryTapped?()
    }

    // MARK: - Loading State

    /// Show spinning animation on the refresh button to indicate loading.
    func showRefreshLoading() {
        refreshButton.isEnabled = false
        refreshButton.alpha = 0.6

        // Continuous rotation animation
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = CGFloat.pi * 2
        rotation.duration = 1.0
        rotation.repeatCount = .infinity
        refreshButton.imageView?.layer.add(rotation, forKey: "refreshSpin")
    }

    /// Stop spinning animation on the refresh button.
    func hideRefreshLoading() {
        refreshButton.isEnabled = true
        refreshButton.imageView?.layer.removeAnimation(forKey: "refreshSpin")

        UIView.animate(withDuration: 0.25) {
            self.refreshButton.alpha = 1
        }
    }

    /// Show in-place loading animation inside the generate container.
    func showGenerateLoading() {
        UIView.animate(withDuration: 0.25) {
            self.generateButton.alpha = 0
        } completion: { _ in
            self.generateButton.isHidden = true
        }

        loadingSpinner.startAnimating()
        loadingLabel.isHidden = false
        loadingLabel.alpha = 0

        UIView.animate(withDuration: 0.25) {
            self.loadingLabel.alpha = 1
        }

        // Pulse the target icon
        generateTargetIcon?.pulseAnimation()
    }

    /// Hide loading state — restore the generate button (on error) or hide container (on success via configure).
    func hideGenerateLoading() {
        loadingSpinner.stopAnimating()
        loadingLabel.isHidden = true
        generateButton.isHidden = false

        UIView.animate(withDuration: 0.25) {
            self.generateButton.alpha = 1
        }

        // Remove pulse animation
        generateTargetIcon?.layer.removeAllAnimations()
    }

    // MARK: - Configure

    func configure(goals: [WeeklyGoal]) {
        // Clear existing cards
        cardsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let pendingGoals = goals.filter { $0.status == .pending }
        let completedGoals = goals.filter { $0.status != .pending }
        let allDone = pendingGoals.isEmpty && !goals.isEmpty

        // Update progress label
        let completedCount = goals.filter { $0.status == .completed }.count
        progressLabel.text = String(format: "goals.progress".localized, completedCount, goals.count)

        if goals.isEmpty {
            cardsStack.isHidden = true
            allDoneContainer.isHidden = true
            generateContainer.isHidden = false
            hideGenerateLoading() // Reset loading state
            emptyLabel.isHidden = true
            refreshButton.isHidden = true
            historyButton.isHidden = WeeklyGoalStore.loadAll().isEmpty
            return
        }

        emptyLabel.isHidden = true
        generateContainer.isHidden = true
        refreshButton.isHidden = false
        hideRefreshLoading()
        historyButton.isHidden = false

        if allDone {
            cardsStack.isHidden = true
            allDoneContainer.isHidden = false
        } else {
            cardsStack.isHidden = false
            allDoneContainer.isHidden = true

            // Show pending goals first, then completed
            let orderedGoals = pendingGoals + completedGoals
            for goal in orderedGoals {
                let card = GoalCardView()
                card.configure(goal: goal)
                cardsStack.addArrangedSubview(card)
            }
        }
    }

    func showEmpty() {
        cardsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        cardsStack.isHidden = true
        allDoneContainer.isHidden = true
        generateContainer.isHidden = false
        hideGenerateLoading()
        emptyLabel.isHidden = true
        refreshButton.isHidden = true
        progressLabel.text = ""
        historyButton.isHidden = WeeklyGoalStore.loadAll().isEmpty
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Single Goal Card (Read-Only — auto-verified by system)
// ═══════════════════════════════════════════════════════════════════

private final class GoalCardView: UIView {

    private var currentGoal: WeeklyGoal?
    private let accentBar = UIView()
    private let iconView = UIImageView()
    private let goalLabel = UILabel()
    private let statusIcon = UIImageView()
    private let categoryLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        // Frosted glass background
        backgroundColor = .clear
        layer.borderWidth = 0.5
        layer.borderColor = AIONDesign.glassCardBorder.cgColor

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: AIONDesign.glassBlurStyle))
        blur.alpha = AIONDesign.glassBlurAlpha
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = AIONDesign.cornerRadius
        blur.clipsToBounds = true
        addSubview(blur)
        layer.cornerRadius = AIONDesign.cornerRadius

        // Accent bar
        accentBar.layer.cornerRadius = 2
        accentBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(accentBar)

        // Category icon
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        // Category label
        categoryLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        categoryLabel.textAlignment = txtAlignment

        // Goal text
        goalLabel.font = .systemFont(ofSize: 14, weight: .regular)
        goalLabel.textColor = AIONDesign.textPrimary
        goalLabel.numberOfLines = 0
        goalLabel.textAlignment = txtAlignment

        // Status icon (read-only indicator)
        statusIcon.contentMode = .scaleAspectFit
        statusIcon.translatesAutoresizingMaskIntoConstraints = false

        // Layout
        let textStack = UIStackView(arrangedSubviews: [categoryLabel, goalLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let contentStack = UIStackView(arrangedSubviews: [iconView, textStack, statusIcon])
        contentStack.axis = .horizontal
        contentStack.spacing = 12
        contentStack.alignment = .center
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.semanticContentAttribute = semanticAttr
        addSubview(contentStack)

        let isCurrentRTL = isRTL

        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor),

            accentBar.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            accentBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            accentBar.widthAnchor.constraint(equalToConstant: 4),

            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            statusIcon.widthAnchor.constraint(equalToConstant: 24),
            statusIcon.heightAnchor.constraint(equalToConstant: 24),

            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
        ])

        if isCurrentRTL {
            NSLayoutConstraint.activate([
                accentBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
                contentStack.trailingAnchor.constraint(equalTo: accentBar.leadingAnchor, constant: -10),
                contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            ])
        } else {
            NSLayoutConstraint.activate([
                accentBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
                contentStack.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 10),
                contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            ])
        }
    }

    func configure(goal: WeeklyGoal) {
        currentGoal = goal

        let color = goal.category.color
        accentBar.backgroundColor = color

        let cfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        iconView.image = UIImage(systemName: goal.category.iconName, withConfiguration: cfg)
        iconView.tintColor = color

        categoryLabel.text = goal.category.localizedName
        categoryLabel.textColor = color

        goalLabel.text = goal.text

        // Update status icon (read-only)
        updateStatusIcon(for: goal.status)

        // Visual state for completed goals
        if goal.status == .completed {
            goalLabel.textColor = AIONDesign.textTertiary
            let attributed = NSAttributedString(
                string: goal.text,
                attributes: [
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .foregroundColor: AIONDesign.textTertiary
                ]
            )
            goalLabel.attributedText = attributed
            alpha = 0.7
        } else if goal.status == .skipped {
            goalLabel.textColor = AIONDesign.textTertiary
            alpha = 0.5
        } else {
            goalLabel.textColor = AIONDesign.textPrimary
            goalLabel.attributedText = nil
            goalLabel.text = goal.text
            alpha = 1.0
        }
    }

    private func updateStatusIcon(for status: GoalStatus) {
        let cfg = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        switch status {
        case .completed:
            statusIcon.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: cfg)
            statusIcon.tintColor = AIONDesign.accentSuccess
        case .pending:
            statusIcon.image = UIImage(systemName: "circle.dotted", withConfiguration: cfg)
            statusIcon.tintColor = AIONDesign.textTertiary
        case .skipped:
            statusIcon.image = UIImage(systemName: "forward.circle", withConfiguration: cfg)
            statusIcon.tintColor = AIONDesign.textTertiary
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Goal History View Controller
// ═══════════════════════════════════════════════════════════════════

final class GoalHistoryViewController: UIViewController {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var goalSets: [WeeklyGoalSet] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "goals.history.title".localized
        applyAIONGradientBackground()

        goalSets = WeeklyGoalStore.loadAll().reversed() // Most recent first

        if let sheet = sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissTapped)
        )

        setupTableView()
    }

    @objc private func dismissTapped() {
        dismiss(animated: true)
    }

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = AIONDesign.background
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "GoalCell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        if goalSets.isEmpty {
            let emptyLabel = UILabel()
            emptyLabel.text = "goals.history.empty".localized
            emptyLabel.textColor = AIONDesign.textSecondary
            emptyLabel.textAlignment = .center
            emptyLabel.font = .systemFont(ofSize: 16, weight: .medium)
            tableView.backgroundView = emptyLabel
        }
    }
}

extension GoalHistoryViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        goalSets.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        goalSets[section].goals.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let set = goalSets[section]
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let progress = "\(set.completedCount)/\(set.goals.count)"
        return "\(formatter.string(from: set.weekStartDate)) — \(progress)"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "GoalCell", for: indexPath)
        let goal = goalSets[indexPath.section].goals[indexPath.row]

        var content = cell.defaultContentConfiguration()
        content.text = goal.text
        content.textProperties.font = .systemFont(ofSize: 14)
        content.textProperties.numberOfLines = 0

        let color = goal.category.color
        let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)

        switch goal.status {
        case .completed:
            content.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: cfg)
            content.imageProperties.tintColor = AIONDesign.accentSuccess
            content.textProperties.color = AIONDesign.textSecondary

            // Show improvement if available
            if let after = goal.afterMetrics, !after.isEmpty {
                let improvements = goal.linkedMetricIds.compactMap { metricId -> String? in
                    guard let baseline = goal.baselineMetrics[metricId],
                          let current = after[metricId] else { return nil }
                    let delta = Int(current - baseline)
                    return delta >= 0 ? "+\(delta)" : "\(delta)"
                }
                if !improvements.isEmpty {
                    content.secondaryText = improvements.joined(separator: ", ")
                    content.secondaryTextProperties.color = AIONDesign.accentSuccess
                    content.secondaryTextProperties.font = .systemFont(ofSize: 12, weight: .semibold)
                }
            }
        case .skipped:
            content.image = UIImage(systemName: "forward.circle", withConfiguration: cfg)
            content.imageProperties.tintColor = AIONDesign.textTertiary
            content.textProperties.color = AIONDesign.textTertiary
        case .pending:
            content.image = UIImage(systemName: "circle.dotted", withConfiguration: cfg)
            content.imageProperties.tintColor = color
            content.textProperties.color = AIONDesign.textPrimary
        }

        cell.contentConfiguration = content
        cell.backgroundColor = AIONDesign.surface
        cell.selectionStyle = .none
        return cell
    }
}
