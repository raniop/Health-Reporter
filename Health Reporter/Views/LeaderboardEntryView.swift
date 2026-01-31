//
//  LeaderboardEntryView.swift
//  Health Reporter
//
//  תצוגת שורה בלידרבורד - מציגה דירוג, אווטר, שם, ציון ורכב.
//

import UIKit

final class LeaderboardEntryView: UIView {

    // MARK: - UI Elements

    private let rankLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .bold)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 22
        iv.backgroundColor = AIONDesign.surface
        iv.image = UIImage(systemName: "person.circle.fill")
        iv.tintColor = AIONDesign.textTertiary
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .semibold)
        l.textColor = AIONDesign.textPrimary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let tierLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12, weight: .medium)
        l.textColor = AIONDesign.textSecondary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let carNameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11, weight: .regular)
        l.textColor = AIONDesign.textTertiary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let scoreLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 20, weight: .bold)
        l.textColor = AIONDesign.accentPrimary
        l.textAlignment = .left
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let scoreMaxLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12, weight: .regular)
        l.textColor = AIONDesign.textTertiary
        l.text = "/100"
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let highlightView: UIView = {
        let v = UIView()
        v.backgroundColor = AIONDesign.accentPrimary.withAlphaComponent(0.1)
        v.layer.cornerRadius = AIONDesign.cornerRadius
        v.isHidden = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = AIONDesign.surface
        layer.cornerRadius = AIONDesign.cornerRadius
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(highlightView)
        addSubview(rankLabel)
        addSubview(avatarImageView)
        addSubview(nameLabel)
        addSubview(tierLabel)
        addSubview(carNameLabel)
        addSubview(scoreLabel)
        addSubview(scoreMaxLabel)

        let isRTL = LocalizationManager.shared.currentLanguage.isRTL

        NSLayoutConstraint.activate([
            highlightView.topAnchor.constraint(equalTo: topAnchor),
            highlightView.leadingAnchor.constraint(equalTo: leadingAnchor),
            highlightView.trailingAnchor.constraint(equalTo: trailingAnchor),
            highlightView.bottomAnchor.constraint(equalTo: bottomAnchor),

            heightAnchor.constraint(equalToConstant: 72),

            // Score on leading (left for LTR, right for RTL)
            scoreLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            scoreLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -4),

            scoreMaxLabel.leadingAnchor.constraint(equalTo: scoreLabel.trailingAnchor, constant: 2),
            scoreMaxLabel.bottomAnchor.constraint(equalTo: scoreLabel.bottomAnchor, constant: -2),

            // Rank on trailing
            rankLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            rankLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            rankLabel.widthAnchor.constraint(equalToConstant: 32),

            // Avatar next to rank
            avatarImageView.trailingAnchor.constraint(equalTo: rankLabel.leadingAnchor, constant: -12),
            avatarImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 44),
            avatarImageView.heightAnchor.constraint(equalToConstant: 44),

            // Name and tier labels
            nameLabel.trailingAnchor.constraint(equalTo: avatarImageView.leadingAnchor, constant: -12),
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: scoreMaxLabel.trailingAnchor, constant: 12),

            tierLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            tierLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),

            carNameLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            carNameLabel.topAnchor.constraint(equalTo: tierLabel.bottomAnchor, constant: 1),
        ])

        nameLabel.textAlignment = .right
        tierLabel.textAlignment = .right
        carNameLabel.textAlignment = .right
    }

    // MARK: - Configure

    func configure(with entry: LeaderboardEntry) {
        // Rank
        if let rank = entry.rank {
            rankLabel.text = rankText(for: rank)
            rankLabel.textColor = rankColor(for: rank)
        } else {
            rankLabel.text = "-"
            rankLabel.textColor = AIONDesign.textTertiary
        }

        // Name
        nameLabel.text = entry.displayName

        // Tier with emoji
        let tier = CarTierEngine.tiers[safe: entry.carTierIndex]
        tierLabel.text = "\(tier?.emoji ?? "") \(entry.carTierLabel)"
        tierLabel.textColor = tier?.color ?? AIONDesign.textSecondary

        // Car name
        carNameLabel.text = entry.carTierName

        // Score
        scoreLabel.text = "\(entry.healthScore)"
        scoreLabel.textColor = tier?.color ?? AIONDesign.accentPrimary

        // Avatar
        loadAvatar(from: entry.photoURL)

        // Highlight current user
        highlightView.isHidden = !entry.isCurrentUser
        if entry.isCurrentUser {
            layer.borderWidth = 2
            layer.borderColor = AIONDesign.accentPrimary.cgColor
        } else {
            layer.borderWidth = 0
        }
    }

    // MARK: - Helpers

    private func rankText(for rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "#\(rank)"
        }
    }

    private func rankColor(for rank: Int) -> UIColor {
        switch rank {
        case 1: return UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Gold
        case 2: return UIColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1.0) // Silver
        case 3: return UIColor(red: 0.8, green: 0.5, blue: 0.2, alpha: 1.0) // Bronze
        default: return AIONDesign.textSecondary
        }
    }

    private func loadAvatar(from urlString: String?) {
        guard let urlString = urlString, let url = URL(string: urlString) else {
            avatarImageView.image = UIImage(systemName: "person.circle.fill")
            avatarImageView.tintColor = AIONDesign.textTertiary
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.avatarImageView.image = image
                self?.avatarImageView.tintColor = nil
            }
        }.resume()
    }
}

// MARK: - Array Safe Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
