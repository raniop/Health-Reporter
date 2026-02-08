//
//  NotificationDetailViewController.swift
//  Health Reporter
//
//  Detail view shown when tapping a morning/bedtime notification in the bell.
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
        view.backgroundColor = AIONDesign.background
        buildUI()
    }

    // MARK: - UI

    private func buildUI() {
        let fullTitle = (notification.data["fullTitle"] as? String) ?? notification.title
        let fullBody = (notification.data["fullBody"] as? String) ?? notification.body

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL
        let align: NSTextAlignment = isRTL ? .right : .left

        // Icon circle
        let iconSize: CGFloat = 56
        let iconContainer = UIView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.layer.cornerRadius = iconSize / 2

        let iconImageView = UIImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .white
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        iconImageView.image = UIImage(systemName: notification.type.icon, withConfiguration: config)
        iconContainer.addSubview(iconImageView)

        let (bg, tint) = iconColors(for: notification.type)
        iconContainer.backgroundColor = bg
        iconImageView.tintColor = tint

        // Title
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = AIONDesign.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.text = fullTitle

        // Divider
        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = AIONDesign.separator

        // Body
        let bodyLabel = UILabel()
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.font = .systemFont(ofSize: 16, weight: .regular)
        bodyLabel.textColor = AIONDesign.textSecondary
        bodyLabel.textAlignment = align
        bodyLabel.numberOfLines = 0
        bodyLabel.text = fullBody

        // Time
        let timeLabel = UILabel()
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = .systemFont(ofSize: 13, weight: .medium)
        timeLabel.textColor = AIONDesign.textTertiary
        timeLabel.textAlignment = .center

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        if isRTL { formatter.locale = Locale(identifier: "he") }
        timeLabel.text = formatter.string(from: notification.createdAt)

        // Content card
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = AIONDesign.surface
        card.layer.cornerRadius = AIONDesign.cornerRadius

        // Extra data row (bedtime only)
        var extraStack: UIStackView?
        if notification.type == .bedtimeRecommendation {
            let bedtime = notification.data["recommendedBedtime"] as? String
            let sleepMin = notification.data["sleepNeedMinutes"] as? Int

            if bedtime != nil || sleepMin != nil {
                var pills: [UIView] = []

                if let bedtime = bedtime {
                    pills.append(makePill(icon: "bed.double.fill", text: bedtime, color: .systemIndigo))
                }
                if let mins = sleepMin {
                    let h = mins / 60
                    let m = mins % 60
                    let txt = m > 0 ? "\(h)h \(m)m" : "\(h)h"
                    pills.append(makePill(icon: "clock.fill", text: txt, color: AIONDesign.accentPrimary))
                }

                let s = UIStackView(arrangedSubviews: pills)
                s.translatesAutoresizingMaskIntoConstraints = false
                s.axis = .horizontal
                s.spacing = 10
                s.distribution = .fillEqually
                extraStack = s
            }
        }

        // Layout
        view.addSubview(card)
        card.addSubview(iconContainer)
        card.addSubview(titleLabel)
        card.addSubview(divider)
        card.addSubview(bodyLabel)
        card.addSubview(timeLabel)

        NSLayoutConstraint.activate([
            iconContainer.centerXAnchor.constraint(equalTo: iconImageView.centerXAnchor),
            iconContainer.centerYAnchor.constraint(equalTo: iconImageView.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: iconSize),
            iconContainer.heightAnchor.constraint(equalToConstant: iconSize),
            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
        ])

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            iconContainer.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            iconContainer.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            titleLabel.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            divider.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            divider.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            divider.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            divider.heightAnchor.constraint(equalToConstant: 1),

            bodyLabel.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 16),
            bodyLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            bodyLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
        ])

        if let extra = extraStack {
            card.addSubview(extra)
            NSLayoutConstraint.activate([
                extra.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 20),
                extra.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
                extra.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

                timeLabel.topAnchor.constraint(equalTo: extra.bottomAnchor, constant: 20),
            ])
        } else {
            timeLabel.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 20).isActive = true
        }

        NSLayoutConstraint.activate([
            timeLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            timeLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            timeLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
        ])
    }

    // MARK: - Helpers

    private func makePill(icon: String, text: String, color: UIColor) -> UIView {
        let pill = UIView()
        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.backgroundColor = color.withAlphaComponent(0.12)
        pill.layer.cornerRadius = AIONDesign.cornerRadiusSmall

        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.image = UIImage(systemName: icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .medium))
        iv.tintColor = color
        iv.contentMode = .scaleAspectFit

        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        lbl.textColor = color
        lbl.text = text

        let stack = UIStackView(arrangedSubviews: [iv, lbl])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center

        pill.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: pill.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            pill.heightAnchor.constraint(equalToConstant: 40),
        ])

        return pill
    }

    private func iconColors(for type: NotificationType) -> (UIColor, UIColor) {
        switch type {
        case .followRequest:
            return (AIONDesign.accentPrimary.withAlphaComponent(0.15), AIONDesign.accentPrimary)
        case .followAccepted:
            return (AIONDesign.accentSuccess.withAlphaComponent(0.15), AIONDesign.accentSuccess)
        case .newFollower:
            return (AIONDesign.accentSecondary.withAlphaComponent(0.15), AIONDesign.accentSecondary)
        case .morningSummary:
            return (AIONDesign.accentWarning.withAlphaComponent(0.15), AIONDesign.accentWarning)
        case .bedtimeRecommendation:
            return (UIColor.systemIndigo.withAlphaComponent(0.15), UIColor.systemIndigo)
        case .healthMilestone:
            return (UIColor(hex: "#FFD700")!.withAlphaComponent(0.15), UIColor(hex: "#FFD700")!)
        }
    }
}
