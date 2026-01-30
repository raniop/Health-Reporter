//
//  DataSourceSettingsViewController.swift
//  Health Reporter
//
//  מסך הגדרות לבחירת מקור נתונים (Apple Watch / Garmin / Oura)
//

import UIKit
import HealthKit

final class DataSourceSettingsViewController: UIViewController {

    // MARK: - UI Elements

    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    private let headerLabel = UILabel()
    private let descriptionLabel = UILabel()

    private lazy var sourceSegment: UISegmentedControl = {
        let items = ["dataSources.automatic".localized, "Apple Watch", "Garmin", "Oura"]
        let seg = UISegmentedControl(items: items)
        seg.selectedSegmentTintColor = AIONDesign.accentPrimary
        seg.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        seg.setTitleTextAttributes([.foregroundColor: AIONDesign.textSecondary], for: .normal)
        seg.translatesAutoresizingMaskIntoConstraints = false
        return seg
    }()

    private let detectedSourcesCard = UIView()
    private let detectedSourcesHeaderLabel = UILabel()
    private let detectedSourcesList = UIStackView()
    private let noSourcesLabel = UILabel()

    private let strengthsCard = UIView()
    private let strengthsHeaderLabel = UILabel()
    private let strengthsLabel = UILabel()

    private let infoCard = UIView()
    private let infoLabel = UILabel()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "dataSources.title".localized
        view.backgroundColor = AIONDesign.background
        view.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute

        setupUI()
        loadCurrentSelection()
        detectSources()
    }

    // MARK: - Setup UI

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        view.addSubview(scrollView)

        stack.axis = .vertical
        stack.spacing = AIONDesign.spacingLarge
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        // Header
        headerLabel.text = "dataSources.selectSource".localized
        headerLabel.font = .systemFont(ofSize: 22, weight: .bold)
        headerLabel.textColor = AIONDesign.textPrimary
        headerLabel.textAlignment = LocalizationManager.shared.textAlignment
        headerLabel.translatesAutoresizingMaskIntoConstraints = false

        // Description
        descriptionLabel.text = "dataSources.description".localized
        descriptionLabel.font = .systemFont(ofSize: 14, weight: .regular)
        descriptionLabel.textColor = AIONDesign.textSecondary
        descriptionLabel.textAlignment = LocalizationManager.shared.textAlignment
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false

        // Segment action
        sourceSegment.addTarget(self, action: #selector(sourceChanged), for: .valueChanged)

        // Detected Sources Card
        setupDetectedSourcesCard()

        // Strengths Card
        setupStrengthsCard()

        // Info Card
        setupInfoCard()

        // Add to stack
        stack.addArrangedSubview(headerLabel)
        stack.addArrangedSubview(descriptionLabel)
        stack.addArrangedSubview(sourceSegment)
        stack.addArrangedSubview(detectedSourcesCard)
        stack.addArrangedSubview(strengthsCard)
        stack.addArrangedSubview(infoCard)

        stack.setCustomSpacing(8, after: headerLabel)
        stack.setCustomSpacing(20, after: descriptionLabel)
        stack.setCustomSpacing(24, after: sourceSegment)

        // Constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: AIONDesign.spacingLarge),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: AIONDesign.spacing),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -AIONDesign.spacing),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -AIONDesign.spacingLarge),

            sourceSegment.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    private func setupDetectedSourcesCard() {
        detectedSourcesCard.backgroundColor = AIONDesign.surface
        detectedSourcesCard.layer.cornerRadius = AIONDesign.cornerRadius
        detectedSourcesCard.translatesAutoresizingMaskIntoConstraints = false

        detectedSourcesHeaderLabel.text = "dataSources.detectedSources".localized
        detectedSourcesHeaderLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        detectedSourcesHeaderLabel.textColor = AIONDesign.textPrimary
        detectedSourcesHeaderLabel.textAlignment = LocalizationManager.shared.textAlignment
        detectedSourcesHeaderLabel.translatesAutoresizingMaskIntoConstraints = false

        detectedSourcesList.axis = .vertical
        detectedSourcesList.spacing = 8
        detectedSourcesList.alignment = .fill
        detectedSourcesList.translatesAutoresizingMaskIntoConstraints = false

        noSourcesLabel.text = "dataSources.checkingSources".localized
        noSourcesLabel.font = .systemFont(ofSize: 14, weight: .regular)
        noSourcesLabel.textColor = AIONDesign.textTertiary
        noSourcesLabel.textAlignment = .center
        noSourcesLabel.translatesAutoresizingMaskIntoConstraints = false

        detectedSourcesCard.addSubview(detectedSourcesHeaderLabel)
        detectedSourcesCard.addSubview(detectedSourcesList)
        detectedSourcesCard.addSubview(noSourcesLabel)

        NSLayoutConstraint.activate([
            detectedSourcesHeaderLabel.topAnchor.constraint(equalTo: detectedSourcesCard.topAnchor, constant: AIONDesign.spacing),
            detectedSourcesHeaderLabel.leadingAnchor.constraint(equalTo: detectedSourcesCard.leadingAnchor, constant: AIONDesign.spacing),
            detectedSourcesHeaderLabel.trailingAnchor.constraint(equalTo: detectedSourcesCard.trailingAnchor, constant: -AIONDesign.spacing),

            detectedSourcesList.topAnchor.constraint(equalTo: detectedSourcesHeaderLabel.bottomAnchor, constant: 12),
            detectedSourcesList.leadingAnchor.constraint(equalTo: detectedSourcesCard.leadingAnchor, constant: AIONDesign.spacing),
            detectedSourcesList.trailingAnchor.constraint(equalTo: detectedSourcesCard.trailingAnchor, constant: -AIONDesign.spacing),
            detectedSourcesList.bottomAnchor.constraint(equalTo: detectedSourcesCard.bottomAnchor, constant: -AIONDesign.spacing),

            noSourcesLabel.centerXAnchor.constraint(equalTo: detectedSourcesCard.centerXAnchor),
            noSourcesLabel.topAnchor.constraint(equalTo: detectedSourcesHeaderLabel.bottomAnchor, constant: 16),
            noSourcesLabel.bottomAnchor.constraint(equalTo: detectedSourcesCard.bottomAnchor, constant: -16),
        ])
    }

    private func setupStrengthsCard() {
        strengthsCard.backgroundColor = AIONDesign.surface
        strengthsCard.layer.cornerRadius = AIONDesign.cornerRadius
        strengthsCard.translatesAutoresizingMaskIntoConstraints = false

        strengthsHeaderLabel.text = "dataSources.deviceStrengths".localized
        strengthsHeaderLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        strengthsHeaderLabel.textColor = AIONDesign.textPrimary
        strengthsHeaderLabel.textAlignment = LocalizationManager.shared.textAlignment
        strengthsHeaderLabel.translatesAutoresizingMaskIntoConstraints = false

        strengthsLabel.font = .systemFont(ofSize: 14, weight: .regular)
        strengthsLabel.textColor = AIONDesign.textSecondary
        strengthsLabel.textAlignment = .right
        strengthsLabel.numberOfLines = 0
        strengthsLabel.translatesAutoresizingMaskIntoConstraints = false

        strengthsCard.addSubview(strengthsHeaderLabel)
        strengthsCard.addSubview(strengthsLabel)

        NSLayoutConstraint.activate([
            strengthsHeaderLabel.topAnchor.constraint(equalTo: strengthsCard.topAnchor, constant: AIONDesign.spacing),
            strengthsHeaderLabel.leadingAnchor.constraint(equalTo: strengthsCard.leadingAnchor, constant: AIONDesign.spacing),
            strengthsHeaderLabel.trailingAnchor.constraint(equalTo: strengthsCard.trailingAnchor, constant: -AIONDesign.spacing),

            strengthsLabel.topAnchor.constraint(equalTo: strengthsHeaderLabel.bottomAnchor, constant: 8),
            strengthsLabel.leadingAnchor.constraint(equalTo: strengthsCard.leadingAnchor, constant: AIONDesign.spacing),
            strengthsLabel.trailingAnchor.constraint(equalTo: strengthsCard.trailingAnchor, constant: -AIONDesign.spacing),
            strengthsLabel.bottomAnchor.constraint(equalTo: strengthsCard.bottomAnchor, constant: -AIONDesign.spacing),
        ])

        updateStrengthsCard()
    }

    private func setupInfoCard() {
        infoCard.backgroundColor = AIONDesign.accentPrimary.withAlphaComponent(0.1)
        infoCard.layer.cornerRadius = AIONDesign.cornerRadius
        infoCard.translatesAutoresizingMaskIntoConstraints = false

        let infoIcon = UIImageView(image: UIImage(systemName: "info.circle.fill"))
        infoIcon.tintColor = AIONDesign.accentPrimary
        infoIcon.contentMode = .scaleAspectFit
        infoIcon.translatesAutoresizingMaskIntoConstraints = false

        infoLabel.text = "dataSources.note".localized
        infoLabel.font = .systemFont(ofSize: 13, weight: .regular)
        infoLabel.textColor = AIONDesign.textSecondary
        infoLabel.textAlignment = LocalizationManager.shared.textAlignment
        infoLabel.numberOfLines = 0
        infoLabel.translatesAutoresizingMaskIntoConstraints = false

        infoCard.addSubview(infoIcon)
        infoCard.addSubview(infoLabel)

        NSLayoutConstraint.activate([
            infoIcon.topAnchor.constraint(equalTo: infoCard.topAnchor, constant: AIONDesign.spacing),
            infoIcon.trailingAnchor.constraint(equalTo: infoCard.trailingAnchor, constant: -AIONDesign.spacing),
            infoIcon.widthAnchor.constraint(equalToConstant: 20),
            infoIcon.heightAnchor.constraint(equalToConstant: 20),

            infoLabel.topAnchor.constraint(equalTo: infoCard.topAnchor, constant: AIONDesign.spacing),
            infoLabel.leadingAnchor.constraint(equalTo: infoCard.leadingAnchor, constant: AIONDesign.spacing),
            infoLabel.trailingAnchor.constraint(equalTo: infoIcon.leadingAnchor, constant: -8),
            infoLabel.bottomAnchor.constraint(equalTo: infoCard.bottomAnchor, constant: -AIONDesign.spacing),
        ])
    }

    // MARK: - Load/Save

    private func loadCurrentSelection() {
        let current = DataSourceManager.shared.preferredSource
        switch current {
        case .autoDetect: sourceSegment.selectedSegmentIndex = 0
        case .appleWatch: sourceSegment.selectedSegmentIndex = 1
        case .garmin: sourceSegment.selectedSegmentIndex = 2
        case .oura: sourceSegment.selectedSegmentIndex = 3
        default: sourceSegment.selectedSegmentIndex = 0
        }
    }

    @objc private func sourceChanged() {
        let selected: HealthDataSource
        switch sourceSegment.selectedSegmentIndex {
        case 0: selected = .autoDetect
        case 1: selected = .appleWatch
        case 2: selected = .garmin
        case 3: selected = .oura
        default: selected = .autoDetect
        }

        DataSourceManager.shared.preferredSource = selected
        updateStrengthsCard()

        // הודעה לדשבורד לטעון מחדש
        NotificationCenter.default.post(name: .dataSourceChanged, object: selected)
    }

    private func updateStrengthsCard() {
        let source = DataSourceManager.shared.effectiveSource()
        let strengths = source.strengths

        if strengths.isEmpty {
            strengthsLabel.text = "dataSources.selectDeviceToSeeStrengths".localized
        } else {
            strengthsLabel.text = strengths.map { "• \($0)" }.joined(separator: "\n")
        }
    }

    // MARK: - Detect Sources

    private func detectSources() {
        guard let rhrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            showNoSources()
            return
        }

        HealthKitManager.shared.detectDataSources(for: rhrType, days: 14) { [weak self] result in
            guard let self = self else { return }

            if let result = result, !result.detectedSources.isEmpty {
                self.displayDetectedSources(result)
            } else {
                self.showNoSources()
            }
        }
    }

    private func displayDetectedSources(_ result: SourceDetectionResult) {
        noSourcesLabel.isHidden = true
        detectedSourcesList.isHidden = false

        // Clear existing
        detectedSourcesList.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for source in result.detectedSources.sorted(by: { result.sourceCounts[$0] ?? 0 > result.sourceCounts[$1] ?? 0 }) {
            let row = makeSourceRow(source: source, count: result.sourceCounts[source] ?? 0, lastSync: result.lastSyncDates[source])
            detectedSourcesList.addArrangedSubview(row)
        }
    }

    private func showNoSources() {
        noSourcesLabel.isHidden = false
        noSourcesLabel.text = "dataSources.noSourcesFound".localized
        detectedSourcesList.isHidden = true
    }

    private func makeSourceRow(source: HealthDataSource, count: Int, lastSync: Date?) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: source.icon))
        icon.tintColor = AIONDesign.accentPrimary
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = UILabel()
        nameLabel.text = source.displayNameHebrew
        nameLabel.font = .systemFont(ofSize: 15, weight: .medium)
        nameLabel.textColor = AIONDesign.textPrimary
        nameLabel.textAlignment = .right
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let detailLabel = UILabel()
        var detail = "\(count) \("dataSources.samples".localized)"
        if let sync = lastSync {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            formatter.locale = Locale(identifier: LocalizationManager.shared.currentLanguage == .hebrew ? "he" : "en")
            detail += " • \("dataSources.lastSync".localized): \(formatter.localizedString(for: sync, relativeTo: Date()))"
        }
        detailLabel.text = detail
        detailLabel.font = .systemFont(ofSize: 12, weight: .regular)
        detailLabel.textColor = AIONDesign.textTertiary
        detailLabel.textAlignment = .right
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(icon)
        row.addSubview(nameLabel)
        row.addSubview(detailLabel)

        NSLayoutConstraint.activate([
            icon.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            icon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),

            nameLabel.trailingAnchor.constraint(equalTo: icon.leadingAnchor, constant: -8),
            nameLabel.topAnchor.constraint(equalTo: row.topAnchor),

            detailLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            detailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            detailLabel.bottomAnchor.constraint(equalTo: row.bottomAnchor),

            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])

        return row
    }
}
