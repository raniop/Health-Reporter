//
//  ProfileViewController.swift
//  Health Reporter
//
//  Livity-style profile hub: title + grouped section cards.
//

import UIKit
import SwiftUI
import FirebaseAuth
import SafariServices

// MARK: - ProfileViewController

final class ProfileViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute

        buildNavigationBar()
        buildLayout()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(backgroundColorDidChange),
                                               name: .backgroundColorChanged,
                                               object: nil)

        AnalyticsService.shared.logScreenView(.profile)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: - Nav bar

    private func buildNavigationBar() {
        title = ""
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
    }

    // MARK: - Layout

    private func buildLayout() {
        // Title label centered at top
        let titleLabel = UILabel()
        titleLabel.text = "profile.title".localized
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // Scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(scrollView)

        // Content stack
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = ProfileUI.sectionSpacing
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: ProfileUI.hPadding),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -ProfileUI.hPadding),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -40),
        ])

        addSections()
    }

    private func addSections() {
        // MARK: Subscription
        contentStack.addArrangedSubview(
            buildSection(
                headerIcon: "creditcard.fill",
                headerTitle: "profile.section.subscription".localized,
                rows: [
                    .init(icon: "dollarsign.circle.fill",
                          iconTint: ProfileUI.green,
                          title: "profile.manageSubscriptions".localized,
                          subtitle: "profile.manageSubscriptions.desc".localized,
                          badge: nil,
                          action: #selector(manageSubscriptionsTapped))
                ]
            )
        )

        // MARK: App
        contentStack.addArrangedSubview(
            buildSection(
                headerIcon: "gearshape.fill",
                headerTitle: "profile.section.app".localized,
                rows: [
                    .init(icon: "slider.horizontal.3",
                          iconTint: ProfileUI.blue,
                          title: "profile.preferences".localized,
                          subtitle: "profile.preferences.desc".localized,
                          badge: nil,
                          action: #selector(preferencesTapped)),
                    .init(icon: "link",
                          iconTint: ProfileUI.blue,
                          title: "profile.integrations".localized,
                          subtitle: "profile.integrations.desc".localized,
                          badge: "profile.new".localized,
                          action: #selector(integrationsTapped))
                ]
            )
        )

        // MARK: More
        contentStack.addArrangedSubview(
            buildSection(
                headerIcon: "ellipsis",
                headerTitle: "profile.section.more".localized,
                rows: [
                    .init(icon: "hand.raised.fill",
                          iconTint: ProfileUI.blue,
                          title: "profile.privacyData".localized,
                          subtitle: "profile.privacyData.desc".localized,
                          badge: nil,
                          action: #selector(privacyDataTapped)),
                    .init(icon: "questionmark.circle.fill",
                          iconTint: ProfileUI.blue,
                          title: "profile.helpSupport".localized,
                          subtitle: "profile.helpSupport.desc".localized,
                          badge: nil,
                          action: #selector(helpSupportTapped)),
                    .init(icon: "person.crop.circle.fill",
                          iconTint: ProfileUI.purple,
                          title: "profile.account".localized,
                          subtitle: "profile.account.desc".localized,
                          badge: nil,
                          action: #selector(accountTapped))
                ]
            )
        )

        // MARK: Community
        contentStack.addArrangedSubview(
            buildSection(
                headerIcon: "hand.thumbsup.fill",
                headerTitle: "profile.section.community".localized,
                rows: [
                    .init(icon: "hand.thumbsup.fill",
                          iconTint: ProfileUI.blue,
                          title: "profile.voteFeatures".localized,
                          subtitle: "profile.voteFeatures.desc".localized,
                          badge: nil,
                          badgeIcon: "star.fill",
                          action: #selector(voteFeaturesTapped))
                ]
            )
        )
    }

    // MARK: - Section builder

    private struct RowSpec {
        let icon: String
        let iconTint: UIColor
        let title: String
        let subtitle: String
        let badge: String?
        var badgeIcon: String? = nil
        let action: Selector
    }

    private func buildSection(headerIcon: String, headerTitle: String, rows: [RowSpec]) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let header = buildSectionHeader(icon: headerIcon, title: headerTitle)
        container.addSubview(header)

        let card = buildCard(rows: rows)
        container.addSubview(card)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            header.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -4),

            card.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 12),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    private func buildSectionHeader(icon: String, title: String) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: UIImage(systemName: icon,
                                                   withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)))
        iconView.tintColor = UIColor.white.withAlphaComponent(0.55)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        row.addSubview(iconView)

        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = UIColor.white.withAlphaComponent(0.55)
        label.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(label)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            iconView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor),

            row.heightAnchor.constraint(equalToConstant: 22),
        ])
        return row
    }

    private func buildCard(rows: [RowSpec]) -> UIView {
        let card = UIView()
        card.backgroundColor = ProfileUI.cardBackground
        card.layer.cornerRadius = ProfileUI.cardCornerRadius
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        for (i, spec) in rows.enumerated() {
            let row = buildRow(spec: spec)
            stack.addArrangedSubview(row)
            if i < rows.count - 1 {
                stack.addArrangedSubview(buildDivider())
            }
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])

        return card
    }

    private func buildRow(spec: RowSpec) -> UIView {
        let row = UIControl()
        row.backgroundColor = .clear
        row.translatesAutoresizingMaskIntoConstraints = false
        row.addTarget(self, action: spec.action, for: .touchUpInside)
        row.addTarget(self, action: #selector(rowHighlight(_:)), for: [.touchDown, .touchDragEnter])
        row.addTarget(self, action: #selector(rowUnhighlight(_:)),
                       for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])

        // Icon
        let iconView = UIImageView(image: UIImage(systemName: spec.icon,
                                                   withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)))
        iconView.tintColor = spec.iconTint
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.isUserInteractionEnabled = false
        row.addSubview(iconView)

        // Title
        let titleLabel = UILabel()
        titleLabel.text = spec.title
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.setContentHuggingPriority(.required, for: .vertical)
        row.addSubview(titleLabel)

        // Subtitle
        let subtitleLabel = UILabel()
        subtitleLabel.text = spec.subtitle
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.55)
        subtitleLabel.numberOfLines = 2
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(subtitleLabel)

        // Chevron
        let isRTL = LocalizationManager.shared.currentLanguage.isRTL
        let chevronName = isRTL ? "chevron.left" : "chevron.right"
        let chevron = UIImageView(image: UIImage(systemName: chevronName,
                                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)))
        chevron.tintColor = UIColor.white.withAlphaComponent(0.35)
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.contentMode = .scaleAspectFit
        row.addSubview(chevron)

        // Optional badge (pill) or icon
        var badgeView: UIView?
        if let badgeText = spec.badge {
            badgeView = makeBadge(text: badgeText)
        } else if let badgeIcon = spec.badgeIcon {
            let iv = UIImageView(image: UIImage(systemName: badgeIcon,
                                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)))
            iv.tintColor = .white
            iv.contentMode = .center
            let wrap = UIView()
            wrap.backgroundColor = ProfileUI.blue
            wrap.layer.cornerRadius = 9
            wrap.clipsToBounds = true
            wrap.translatesAutoresizingMaskIntoConstraints = false
            iv.translatesAutoresizingMaskIntoConstraints = false
            wrap.addSubview(iv)
            NSLayoutConstraint.activate([
                wrap.widthAnchor.constraint(equalToConstant: 22),
                wrap.heightAnchor.constraint(equalToConstant: 18),
                iv.centerXAnchor.constraint(equalTo: wrap.centerXAnchor),
                iv.centerYAnchor.constraint(equalTo: wrap.centerYAnchor),
            ])
            badgeView = wrap
        }

        if let b = badgeView {
            b.translatesAutoresizingMaskIntoConstraints = false
            b.isUserInteractionEnabled = false
            row.addSubview(b)
        }

        // Constraints
        let leftPad: CGFloat = 16
        let rightPad: CGFloat = 14
        let vPad: CGFloat = 14

        var constraints: [NSLayoutConstraint] = [
            iconView.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: leftPad),
            iconView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 26),
            iconView.heightAnchor.constraint(equalToConstant: 26),

            chevron.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -rightPad),
            chevron.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 12),
            chevron.heightAnchor.constraint(equalToConstant: 16),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 14),
            titleLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: vPad),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -8),
            subtitleLabel.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -vPad),

            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 68),
        ]

        if let b = badgeView {
            constraints.append(contentsOf: [
                b.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
                b.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
                b.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -8),
            ])
            titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        } else {
            constraints.append(titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -8))
        }

        NSLayoutConstraint.activate(constraints)
        return row
    }

    private func makeBadge(text: String) -> UIView {
        let pill = UIView()
        pill.backgroundColor = ProfileUI.blue
        pill.layer.cornerRadius = 10
        pill.clipsToBounds = true

        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 11, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(label)

        NSLayoutConstraint.activate([
            pill.heightAnchor.constraint(equalToConstant: 20),
            label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: pill.topAnchor),
            label.bottomAnchor.constraint(equalTo: pill.bottomAnchor),
        ])
        return pill
    }

    private func buildDivider() -> UIView {
        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false

        let line = UIView()
        line.backgroundColor = AIONDesign.separator
        line.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(line)

        NSLayoutConstraint.activate([
            wrapper.heightAnchor.constraint(equalToConstant: 0.5),
            line.topAnchor.constraint(equalTo: wrapper.topAnchor),
            line.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            line.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 56),
            line.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
        ])
        return wrapper
    }

    // MARK: - Row highlight

    @objc private func rowHighlight(_ sender: UIControl) {
        UIView.animate(withDuration: 0.1) {
            sender.backgroundColor = UIColor.white.withAlphaComponent(0.04)
        }
    }

    @objc private func rowUnhighlight(_ sender: UIControl) {
        UIView.animate(withDuration: 0.15) {
            sender.backgroundColor = .clear
        }
    }

    // MARK: - Row actions

    @objc private func manageSubscriptionsTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let paywall = UIHostingController(rootView: PaywallSheet())
        paywall.modalPresentationStyle = .pageSheet
        present(paywall, animated: true)
    }

    @objc private func preferencesTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.pushViewController(SettingsViewController(), animated: true)
    }

    @objc private func integrationsTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.pushViewController(DataSourceSettingsViewController(), animated: true)
    }

    @objc private func privacyDataTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.pushViewController(SettingsViewController(), animated: true)
    }

    @objc private func helpSupportTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let subject = "Health Reporter — " + "profile.helpSupport".localized
        let email = "support@healthreporter.app"
        let body = ""
        let urlString = "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body)"
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            let alert = UIAlertController(title: "profile.helpSupport".localized,
                                            message: email,
                                            preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "ok".localized, style: .default))
            present(alert, animated: true)
        }
    }

    @objc private func accountTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.pushViewController(SettingsViewController(), animated: true)
    }

    @objc private func voteFeaturesTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if let url = URL(string: "https://healthreporter.app/vote") {
            let safari = SFSafariViewController(url: url)
            present(safari, animated: true)
        }
    }

    // MARK: - Observers

    @objc private func backgroundColorDidChange() {
        view.backgroundColor = .black
    }
}

// MARK: - Design tokens

private enum ProfileUI {
    static let hPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 28
    static let cardBackground = UIColor(white: 0.11, alpha: 1.0)
    static let cardCornerRadius: CGFloat = 18

    static let blue = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
    static let green = UIColor(red: 0.20, green: 0.82, blue: 0.33, alpha: 1.0)
    static let purple = UIColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1.0)
    static let orange = UIColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1.0)
    static let red = UIColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 1.0)
}
