//
//  NotificationDetailViewController.swift
//  Health Reporter
//
//  Detail view shown when tapping a notification in the bell.
//  Livity-style light look — adaptive system colors, tinted hero strip matching the
//  notification type, pills for structured data (e.g. bedtime / sleep need).
//

import UIKit

final class NotificationDetailViewController: UIViewController {

    private let notification: NotificationItem

    init(notification: NotificationItem) {
        self.notification = notification
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setupNavigation()
        buildUI()
    }

    private func setupNavigation() {
        let closeButton = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeTapped)
        )
        closeButton.tintColor = .label
        navigationItem.rightBarButtonItem = closeButton

        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = .systemGroupedBackground
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    // MARK: - UI

    private func buildUI() {
        let fullTitle = (notification.data["fullTitle"] as? String) ?? notification.title
        let fullBody = (notification.data["fullBody"] as? String) ?? notification.body
        let palette = palette(for: notification.type)
        let isRTL = LocalizationManager.shared.currentLanguage.isRTL
        let naturalAlign: NSTextAlignment = isRTL ? .right : .left

        // Hero strip — tinted band with a large icon circle
        let hero = UIView()
        hero.translatesAutoresizingMaskIntoConstraints = false
        hero.backgroundColor = palette.tint
        hero.layer.cornerRadius = 24
        hero.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]

        let iconCircle = UIView()
        iconCircle.translatesAutoresizingMaskIntoConstraints = false
        iconCircle.backgroundColor = palette.accent
        iconCircle.layer.cornerRadius = 36
        iconCircle.layer.shadowColor = palette.accent.cgColor
        iconCircle.layer.shadowOpacity = 0.25
        iconCircle.layer.shadowRadius = 12
        iconCircle.layer.shadowOffset = CGSize(width: 0, height: 4)

        let iconView = UIImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = UIImage(systemName: notification.type.icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 30, weight: .semibold))
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit

        iconCircle.addSubview(iconView)
        hero.addSubview(iconCircle)

        // Content card
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 20

        // Title
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.text = fullTitle

        // Timestamp — placed right under the title in a smaller muted style
        let timeLabel = UILabel()
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = .systemFont(ofSize: 13, weight: .medium)
        timeLabel.textColor = .tertiaryLabel
        timeLabel.textAlignment = .center
        timeLabel.text = formattedTimestamp()

        // Divider
        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = .separator

        // Body
        let bodyLabel = UILabel()
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.font = .systemFont(ofSize: 16, weight: .regular)
        bodyLabel.textColor = .label
        bodyLabel.textAlignment = naturalAlign
        bodyLabel.numberOfLines = 0
        bodyLabel.text = fullBody

        card.addSubview(titleLabel)
        card.addSubview(timeLabel)
        card.addSubview(divider)
        card.addSubview(bodyLabel)

        // Optional structured data row for bedtime
        var pillsStack: UIStackView?
        if notification.type == .bedtimeRecommendation {
            let pills = buildBedtimePills()
            if !pills.isEmpty {
                let stack = UIStackView(arrangedSubviews: pills)
                stack.translatesAutoresizingMaskIntoConstraints = false
                stack.axis = .horizontal
                stack.spacing = 10
                stack.distribution = .fillEqually
                pillsStack = stack
                card.addSubview(stack)
            }
        }

        // Scroll wrapper so long analyses are readable on small devices
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = true
        scroll.showsVerticalScrollIndicator = false

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scroll)
        scroll.addSubview(container)
        container.addSubview(hero)
        container.addSubview(card)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            container.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            container.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            container.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),

            hero.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            hero.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            hero.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            hero.heightAnchor.constraint(equalToConstant: 140),

            iconCircle.centerXAnchor.constraint(equalTo: hero.centerXAnchor),
            iconCircle.centerYAnchor.constraint(equalTo: hero.centerYAnchor),
            iconCircle.widthAnchor.constraint(equalToConstant: 72),
            iconCircle.heightAnchor.constraint(equalToConstant: 72),

            iconView.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 36),
            iconView.heightAnchor.constraint(equalToConstant: 36),

            card.topAnchor.constraint(equalTo: hero.bottomAnchor, constant: 14),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            timeLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            timeLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            timeLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            divider.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 16),
            divider.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            divider.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            divider.heightAnchor.constraint(equalToConstant: 0.5),

            bodyLabel.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 16),
            bodyLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            bodyLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
        ])

        if let pills = pillsStack {
            NSLayoutConstraint.activate([
                pills.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 18),
                pills.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
                pills.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
                pills.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -22),
                card.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -24),
            ])
        } else {
            NSLayoutConstraint.activate([
                bodyLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -22),
                card.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -24),
            ])
        }
    }

    // MARK: - Helpers

    private func formattedTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = LocalizationManager.shared.currentLocale
        return formatter.string(from: notification.createdAt)
    }

    private func buildBedtimePills() -> [UIView] {
        var pills: [UIView] = []
        if let bedtime = notification.data["recommendedBedtime"] as? String, !bedtime.isEmpty {
            pills.append(makeLabeledPill(
                label: "bedtime.detail.recommendedBedtime".localized,
                icon: "bed.double.fill",
                value: bedtime,
                color: .systemIndigo
            ))
        }
        if let mins = notification.data["sleepNeedMinutes"] as? Int, mins > 0 {
            let h = mins / 60
            let m = mins % 60
            let value = m > 0 ? "\(h)h \(m)m" : "\(h)h"
            pills.append(makeLabeledPill(
                label: "bedtime.detail.sleepNeed".localized,
                icon: "clock.fill",
                value: value,
                color: .systemTeal
            ))
        }
        return pills
    }

    private func makeLabeledPill(label: String, icon: String, value: String, color: UIColor) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let caption = UILabel()
        caption.translatesAutoresizingMaskIntoConstraints = false
        caption.font = .systemFont(ofSize: 11, weight: .semibold)
        caption.textColor = .secondaryLabel
        caption.textAlignment = .center
        caption.text = label.uppercased()

        let pill = UIView()
        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.backgroundColor = color.withAlphaComponent(0.12)
        pill.layer.cornerRadius = 14

        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.image = UIImage(systemName: icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold))
        iv.tintColor = color
        iv.contentMode = .scaleAspectFit

        let val = UILabel()
        val.translatesAutoresizingMaskIntoConstraints = false
        val.font = .monospacedDigitSystemFont(ofSize: 16, weight: .bold)
        val.textColor = color
        val.text = value

        let stack = UIStackView(arrangedSubviews: [iv, val])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center

        pill.addSubview(stack)
        container.addSubview(caption)
        container.addSubview(pill)

        NSLayoutConstraint.activate([
            caption.topAnchor.constraint(equalTo: container.topAnchor),
            caption.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            caption.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            pill.topAnchor.constraint(equalTo: caption.bottomAnchor, constant: 6),
            pill.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            pill.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            pill.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            pill.heightAnchor.constraint(equalToConstant: 44),

            stack.centerXAnchor.constraint(equalTo: pill.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
        ])

        return container
    }

    private func palette(for type: NotificationType) -> (tint: UIColor, accent: UIColor) {
        switch type {
        case .followRequest:
            return (UIColor.systemBlue.withAlphaComponent(0.12), .systemBlue)
        case .followAccepted:
            return (UIColor.systemGreen.withAlphaComponent(0.12), .systemGreen)
        case .newFollower:
            return (UIColor.systemTeal.withAlphaComponent(0.12), .systemTeal)
        case .morningSummary:
            return (UIColor.systemOrange.withAlphaComponent(0.12), .systemOrange)
        case .bedtimeRecommendation:
            return (UIColor.systemIndigo.withAlphaComponent(0.12), .systemIndigo)
        case .healthMilestone:
            return (UIColor.systemYellow.withAlphaComponent(0.18), .systemOrange)
        }
    }
}
