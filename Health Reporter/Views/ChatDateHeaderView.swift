//
//  ChatDateHeaderView.swift
//  Health Reporter
//
//  Date separator pill shown between message groups in the chat screen.
//

import UIKit

final class ChatDateHeaderView: UITableViewHeaderFooterView {

    static let reuseIdentifier = "ChatDateHeaderView"

    // MARK: - UI Elements

    private let pillContainer: UIView = {
        let v = UIView()
        v.backgroundColor = AIONDesign.surfaceElevated.withAlphaComponent(0.9)
        v.layer.cornerRadius = 12
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let dateLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12, weight: .semibold)
        l.textColor = AIONDesign.textSecondary
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Init

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundView = UIView()
        backgroundView?.backgroundColor = .clear

        contentView.addSubview(pillContainer)
        pillContainer.addSubview(dateLabel)

        NSLayoutConstraint.activate([
            pillContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            pillContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            dateLabel.topAnchor.constraint(equalTo: pillContainer.topAnchor, constant: 4),
            dateLabel.bottomAnchor.constraint(equalTo: pillContainer.bottomAnchor, constant: -4),
            dateLabel.leadingAnchor.constraint(equalTo: pillContainer.leadingAnchor, constant: 12),
            dateLabel.trailingAnchor.constraint(equalTo: pillContainer.trailingAnchor, constant: -12),
        ])
    }

    // MARK: - Configure

    func configure(with date: Date) {
        dateLabel.text = formatDate(date)
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "chat.today".localized
        }
        if calendar.isDateInYesterday(date) {
            return "chat.yesterday".localized
        }

        let formatter = DateFormatter()
        formatter.locale = LocalizationManager.shared.currentLocale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
