//
//  InsightsDashboardViews.swift
//  Health Reporter
//
//  כל ה-Views עבור מסך ה-Insights Dashboard
//

import UIKit
import FirebaseAuth

// MARK: - AIONDesign Extensions for InsightsDashboard

private extension AIONDesign {
    static var fontTitle2: UIFont { .systemFont(ofSize: 20, weight: .bold) }
    static var fontHeadline: UIFont { headlineFont() }
    static var fontBody: UIFont { bodyFont() }
    static var fontCaption: UIFont { captionFont() }

    static var statusPositive: UIColor { accentSuccess }
    static var statusNegative: UIColor { accentDanger }
    static var statusNeutral: UIColor { accentWarning }
}

// MARK: - RTL Helper

private var isRTL: Bool {
    // בודק את השפה הנוכחית של האפליקציה, לא של המערכת
    LocalizationManager.shared.currentLanguage == .hebrew
}

private var semanticAttribute: UISemanticContentAttribute {
    isRTL ? .forceRightToLeft : .forceLeftToRight
}

private var textAlignment: NSTextAlignment {
    isRTL ? .right : .left
}

// MARK: - Tappable Metric Card

/// כרטיס מדד לחיץ שמציג הסבר ב-bottom sheet
final class TappableMetricCard: UIView {

    private let metricTitle: String
    private let explanation: String
    private weak var parentVC: UIViewController?

    init(title: String, explanation: String, parentVC: UIViewController?) {
        self.metricTitle = title
        self.explanation = explanation
        self.parentVC = parentVC
        super.init(frame: .zero)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleTap() {
        guard let vc = parentVC ?? findViewController() else { return }

        let detailVC = SimpleMetricDetailViewController(title: metricTitle, explanation: explanation)
        vc.present(detailVC, animated: true)
    }

    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let nextResponder = responder?.next {
            if let vc = nextResponder as? UIViewController {
                return vc
            }
            responder = nextResponder
        }
        return nil
    }
}

// MARK: - Simple Metric Detail ViewController (Bottom Sheet)

final class SimpleMetricDetailViewController: UIViewController {

    private let metricTitle: String
    private let explanation: String

    init(title: String, explanation: String) {
        self.metricTitle = title
        self.explanation = explanation
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AIONDesign.background
        setupUI()
    }

    private func setupUI() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        // Title
        let titleLabel = UILabel()
        titleLabel.text = metricTitle
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = AIONDesign.textPrimary
        titleLabel.textAlignment = .center

        // Explanation
        let explanationLabel = UILabel()
        explanationLabel.text = explanation
        explanationLabel.font = AIONDesign.fontBody
        explanationLabel.textColor = AIONDesign.textSecondary
        explanationLabel.textAlignment = .center
        explanationLabel.numberOfLines = 0

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(explanationLabel)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }
}

// MARK: - Header View

final class InsightsDashboardHeaderView: UIView {

    private let greetingLabel = UILabel()
    private let dateLabel = UILabel()
    private let avatarImageView = UIImageView()
    private var mainStack: UIStackView?
    private var textStack: UIStackView?

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {
        // מחק את ה-subviews הקודמים ובנה מחדש לפי השפה הנוכחית
        subviews.forEach { $0.removeFromSuperview() }

        let currentIsRTL = LocalizationManager.shared.currentLanguage == .hebrew
        let currentTextAlignment: NSTextAlignment = currentIsRTL ? .right : .left

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        mainStack = stack

        let tStack = UIStackView(arrangedSubviews: [greetingLabel, dateLabel])
        tStack.axis = .vertical
        tStack.spacing = 4
        tStack.alignment = currentIsRTL ? .trailing : .leading
        textStack = tStack

        greetingLabel.font = AIONDesign.fontTitle2
        greetingLabel.textColor = AIONDesign.textPrimary
        greetingLabel.textAlignment = currentTextAlignment

        dateLabel.font = AIONDesign.fontCaption
        dateLabel.textColor = AIONDesign.textSecondary
        dateLabel.textAlignment = currentTextAlignment

        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.layer.cornerRadius = 20
        avatarImageView.backgroundColor = AIONDesign.surface

        // RTL: avatar on left, text on right
        // LTR: text on left, avatar on right
        let spacer = UIView()
        if currentIsRTL {
            stack.addArrangedSubview(avatarImageView)
            stack.addArrangedSubview(spacer)
            stack.addArrangedSubview(tStack)
        } else {
            stack.addArrangedSubview(tStack)
            stack.addArrangedSubview(spacer)
            stack.addArrangedSubview(avatarImageView)
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),

            avatarImageView.widthAnchor.constraint(equalToConstant: 40),
            avatarImageView.heightAnchor.constraint(equalToConstant: 40)
        ])

        // Greeting based on time
        let hour = Calendar.current.component(.hour, from: Date())
        let greetingKey: String
        switch hour {
        case 5..<12: greetingKey = "greeting.morning"
        case 12..<17: greetingKey = "greeting.afternoon"
        case 17..<21: greetingKey = "greeting.evening"
        default: greetingKey = "greeting.night"
        }
        greetingLabel.text = greetingKey.localized

        // Date
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.locale = currentIsRTL ? Locale(identifier: "he_IL") : Locale(identifier: "en_US")
        dateLabel.text = formatter.string(from: Date())

        // Avatar
        if let user = Auth.auth().currentUser {
            if let photoURL = user.photoURL {
                avatarImageView.loadImageAsync(from: photoURL)
            } else {
                avatarImageView.image = UIImage(systemName: "person.circle.fill")
                avatarImageView.tintColor = AIONDesign.textTertiary
            }
        }
    }
}

// MARK: - Period Selector

final class PeriodSelectorView: UIView {

    var onPeriodChanged: ((TimePeriod) -> Void)?

    private let segmentedControl = UISegmentedControl()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        // RTL/LTR support
        semanticContentAttribute = semanticAttribute
        segmentedControl.semanticContentAttribute = semanticAttribute

        for (index, period) in TimePeriod.allCases.enumerated() {
            segmentedControl.insertSegment(withTitle: period.localizationKey.localized, at: index, animated: false)
        }
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(periodChanged), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        addSubview(segmentedControl)

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: topAnchor),
            segmentedControl.leadingAnchor.constraint(equalTo: leadingAnchor),
            segmentedControl.trailingAnchor.constraint(equalTo: trailingAnchor),
            segmentedControl.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @objc private func periodChanged() {
        if let period = TimePeriod(rawValue: segmentedControl.selectedSegmentIndex) {
            onPeriodChanged?(period)
        }
    }
}

// MARK: - Hero Score Section

final class HeroScoreSection: UIView {

    var onWhyTapped: (() -> Void)?
    private weak var parentVC: UIViewController?
    private var currentEnergyForecast: EnergyForecast?

    private let mainScoreCard = UIView()
    private let scoreLabel = UILabel()
    private let scoreDescLabel = UILabel()
    private let whyIndicator = UIImageView()

    private let energyCard = UIView()
    private let energyIconView = UIImageView()
    private let energyLabel = UILabel()
    private let energyDescLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        // RTL/LTR support
        semanticContentAttribute = semanticAttribute

        let hStack = UIStackView()
        hStack.axis = .horizontal
        hStack.spacing = 12
        hStack.distribution = .fillEqually
        hStack.translatesAutoresizingMaskIntoConstraints = false
        hStack.semanticContentAttribute = semanticAttribute
        addSubview(hStack)

        // Main score card - tappable
        mainScoreCard.backgroundColor = AIONDesign.surface
        mainScoreCard.layer.cornerRadius = 16
        setupCardShadow(mainScoreCard)

        let scoreTap = UITapGestureRecognizer(target: self, action: #selector(scoreCardTapped))
        mainScoreCard.addGestureRecognizer(scoreTap)
        mainScoreCard.isUserInteractionEnabled = true

        // Small info indicator at bottom right
        whyIndicator.image = UIImage(systemName: "info.circle")
        whyIndicator.tintColor = AIONDesign.textTertiary
        whyIndicator.contentMode = .scaleAspectFit
        whyIndicator.translatesAutoresizingMaskIntoConstraints = false
        mainScoreCard.addSubview(whyIndicator)

        let mainStack = UIStackView(arrangedSubviews: [scoreLabel, scoreDescLabel])
        mainStack.axis = .vertical
        mainStack.alignment = .center
        mainStack.spacing = 4
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.isUserInteractionEnabled = false
        mainScoreCard.addSubview(mainStack)

        scoreLabel.font = UIFont.systemFont(ofSize: 52, weight: .bold)
        scoreLabel.textColor = AIONDesign.accentPrimary
        scoreLabel.textAlignment = .center

        scoreDescLabel.font = AIONDesign.fontCaption
        scoreDescLabel.textColor = AIONDesign.textSecondary
        scoreDescLabel.textAlignment = .center

        NSLayoutConstraint.activate([
            mainStack.centerXAnchor.constraint(equalTo: mainScoreCard.centerXAnchor),
            mainStack.centerYAnchor.constraint(equalTo: mainScoreCard.centerYAnchor),
            mainStack.leadingAnchor.constraint(greaterThanOrEqualTo: mainScoreCard.leadingAnchor, constant: 8),
            mainStack.trailingAnchor.constraint(lessThanOrEqualTo: mainScoreCard.trailingAnchor, constant: -8),

            whyIndicator.trailingAnchor.constraint(equalTo: mainScoreCard.trailingAnchor, constant: -10),
            whyIndicator.bottomAnchor.constraint(equalTo: mainScoreCard.bottomAnchor, constant: -10),
            whyIndicator.widthAnchor.constraint(equalToConstant: 16),
            whyIndicator.heightAnchor.constraint(equalToConstant: 16)
        ])

        // Energy card - tappable
        energyCard.backgroundColor = AIONDesign.surface
        energyCard.layer.cornerRadius = 16
        setupCardShadow(energyCard)

        let energyTap = UITapGestureRecognizer(target: self, action: #selector(energyCardTapped))
        energyCard.addGestureRecognizer(energyTap)
        energyCard.isUserInteractionEnabled = true

        // Small info indicator for energy card
        let energyInfoIndicator = UIImageView(image: UIImage(systemName: "info.circle"))
        energyInfoIndicator.tintColor = AIONDesign.textTertiary
        energyInfoIndicator.contentMode = .scaleAspectFit
        energyInfoIndicator.translatesAutoresizingMaskIntoConstraints = false
        energyCard.addSubview(energyInfoIndicator)

        let energyStack = UIStackView(arrangedSubviews: [energyIconView, energyLabel, energyDescLabel])
        energyStack.axis = .vertical
        energyStack.alignment = .center
        energyStack.spacing = 6
        energyStack.translatesAutoresizingMaskIntoConstraints = false
        energyStack.isUserInteractionEnabled = false
        energyCard.addSubview(energyStack)

        energyIconView.image = UIImage(systemName: "bolt.fill")
        energyIconView.tintColor = AIONDesign.statusPositive
        energyIconView.contentMode = .scaleAspectFit

        energyLabel.font = AIONDesign.fontTitle2
        energyLabel.textColor = AIONDesign.textPrimary
        energyLabel.textAlignment = .center

        energyDescLabel.font = AIONDesign.fontCaption
        energyDescLabel.textColor = AIONDesign.textSecondary
        energyDescLabel.textAlignment = .center
        energyDescLabel.numberOfLines = 2

        NSLayoutConstraint.activate([
            energyStack.centerXAnchor.constraint(equalTo: energyCard.centerXAnchor),
            energyStack.centerYAnchor.constraint(equalTo: energyCard.centerYAnchor),
            energyStack.leadingAnchor.constraint(greaterThanOrEqualTo: energyCard.leadingAnchor, constant: 8),
            energyStack.trailingAnchor.constraint(lessThanOrEqualTo: energyCard.trailingAnchor, constant: -8),

            energyIconView.widthAnchor.constraint(equalToConstant: 28),
            energyIconView.heightAnchor.constraint(equalToConstant: 28),

            energyInfoIndicator.trailingAnchor.constraint(equalTo: energyCard.trailingAnchor, constant: -10),
            energyInfoIndicator.bottomAnchor.constraint(equalTo: energyCard.bottomAnchor, constant: -10),
            energyInfoIndicator.widthAnchor.constraint(equalToConstant: 16),
            energyInfoIndicator.heightAnchor.constraint(equalToConstant: 16)
        ])

        hStack.addArrangedSubview(mainScoreCard)
        hStack.addArrangedSubview(energyCard)

        NSLayoutConstraint.activate([
            hStack.topAnchor.constraint(equalTo: topAnchor),
            hStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            hStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            hStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            hStack.heightAnchor.constraint(equalToConstant: 140)
        ])
    }

    private func setupCardShadow(_ view: UIView) {
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 8
    }

    @objc private func scoreCardTapped() {
        onWhyTapped?()
    }

    @objc private func energyCardTapped() {
        guard let vc = parentVC, let energy = currentEnergyForecast else { return }
        let detailVC = EnergyDetailViewController(energyForecast: energy)
        vc.present(detailVC, animated: true)
    }

    func configure(mainScore: Double?, energyForecast: EnergyForecast, parentVC: UIViewController? = nil) {
        self.parentVC = parentVC
        self.currentEnergyForecast = energyForecast

        if let score = mainScore {
            scoreLabel.text = "\(Int(score))"

            let level = RangeLevel.from(score: score)
            scoreDescLabel.text = "score.description.\(level.rawValue)".localized

            // Color based on score
            scoreLabel.textColor = colorForScore(score)
        } else {
            scoreLabel.text = "--"
            scoreDescLabel.text = "score.no_data".localized
            scoreLabel.textColor = AIONDesign.textTertiary
        }

        // Energy forecast
        if let energy = energyForecast.value {
            energyLabel.text = energyForecast.level.localizationKey.localized
            energyDescLabel.text = energyForecast.explanationKey.localized
            energyIconView.tintColor = colorForScore(energy)
        } else {
            energyLabel.text = "--"
            energyDescLabel.text = ""
        }
    }

    private func colorForScore(_ score: Double) -> UIColor {
        switch score {
        case 0..<30: return AIONDesign.statusNegative
        case 30..<60: return AIONDesign.statusNeutral
        case 60..<80: return AIONDesign.statusPositive
        default: return AIONDesign.accentPrimary
        }
    }
}

// MARK: - Energy Detail ViewController (Bottom Sheet)

final class EnergyDetailViewController: UIViewController {

    private let energyForecast: EnergyForecast

    init(energyForecast: EnergyForecast) {
        self.energyForecast = energyForecast
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AIONDesign.background
        setupUI()
    }

    private func setupUI() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        // Icon
        let iconView = UIImageView(image: UIImage(systemName: "bolt.fill"))
        iconView.tintColor = colorForEnergy(energyForecast.value)
        iconView.contentMode = .scaleAspectFit

        // Title
        let titleLabel = UILabel()
        titleLabel.text = "explanation.energy.title".localized
        titleLabel.font = AIONDesign.fontTitle2
        titleLabel.textColor = AIONDesign.textPrimary

        // Value
        let valueLabel = UILabel()
        valueLabel.text = energyForecast.level.localizationKey.localized
        valueLabel.font = UIFont.systemFont(ofSize: 36, weight: .bold)
        valueLabel.textColor = colorForEnergy(energyForecast.value)

        // Description
        let descLabel = UILabel()
        descLabel.text = energyForecast.explanationKey.localized
        descLabel.font = AIONDesign.fontBody
        descLabel.textColor = AIONDesign.textSecondary
        descLabel.textAlignment = .center
        descLabel.numberOfLines = 0

        // Detailed explanation
        let explanationLabel = UILabel()
        explanationLabel.text = "explanation.energy.message".localized
        explanationLabel.font = AIONDesign.fontBody
        explanationLabel.textColor = AIONDesign.textSecondary
        explanationLabel.textAlignment = .center
        explanationLabel.numberOfLines = 0

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(valueLabel)
        stack.addArrangedSubview(descLabel)
        stack.addArrangedSubview(explanationLabel)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 48),
            iconView.heightAnchor.constraint(equalToConstant: 48),

            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func colorForEnergy(_ value: Double?) -> UIColor {
        guard let v = value else { return AIONDesign.textTertiary }
        switch v {
        case 0..<30: return AIONDesign.statusNegative
        case 30..<60: return AIONDesign.statusNeutral
        case 60..<80: return AIONDesign.statusPositive
        default: return AIONDesign.accentPrimary
        }
    }
}

// MARK: - Star Metrics Bar

final class StarMetricsBarView: UIView {

    var onMetricTapped: ((any InsightMetric) -> Void)?

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        // RTL/LTR support
        semanticContentAttribute = semanticAttribute

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.semanticContentAttribute = semanticAttribute
        addSubview(scrollView)

        stackView.axis = .horizontal
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.semanticContentAttribute = semanticAttribute
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 80),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
    }

    func configure(with stars: StarMetrics) {
        let currentIsRTL = LocalizationManager.shared.currentLanguage == .hebrew

        // עדכון כיוון הגלילה
        scrollView.semanticContentAttribute = currentIsRTL ? .forceRightToLeft : .forceLeftToRight
        stackView.semanticContentAttribute = currentIsRTL ? .forceRightToLeft : .forceLeftToRight

        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for metric in stars.allMetrics {
            let cell = StarMetricCell()
            cell.configure(with: metric)
            cell.onTap = { [weak self] in
                self?.onMetricTapped?(metric)
            }
            stackView.addArrangedSubview(cell)
        }

        // גלול לתחילה (ימין בעברית, שמאל באנגלית)
        DispatchQueue.main.async {
            if currentIsRTL {
                let rightOffset = CGPoint(x: max(0, self.scrollView.contentSize.width - self.scrollView.bounds.width), y: 0)
                self.scrollView.setContentOffset(rightOffset, animated: false)
            } else {
                self.scrollView.setContentOffset(.zero, animated: false)
            }
        }
    }
}

// MARK: - Star Metric Cell

final class StarMetricCell: UIView {

    var onTap: (() -> Void)?

    private let iconView = UIImageView()
    private let valueLabel = UILabel()
    private let nameLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = AIONDesign.surface
        layer.cornerRadius = 12

        let stack = UIStackView(arrangedSubviews: [iconView, valueLabel, nameLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = AIONDesign.accentPrimary

        valueLabel.font = AIONDesign.fontHeadline
        valueLabel.textColor = AIONDesign.textPrimary

        nameLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        nameLabel.textColor = AIONDesign.textSecondary
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 2

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 90),

            stack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    @objc private func handleTap() {
        onTap?()
    }

    func configure(with metric: any InsightMetric) {
        iconView.image = UIImage(systemName: StarMetricsCalculator.icon(for: metric.id))
        valueLabel.text = metric.displayValue
        nameLabel.text = metric.nameKey.localized
        valueLabel.textColor = StarMetricsCalculator.color(for: metric)
    }
}

// MARK: - Why Score Section

final class WhyScoreSection: UIView {

    private let stackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = AIONDesign.surface
        layer.cornerRadius = 12

        // RTL/LTR support
        semanticContentAttribute = semanticAttribute

        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.semanticContentAttribute = semanticAttribute
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }

    func configure(with metrics: DailyMetrics) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let titleLabel = UILabel()
        titleLabel.text = "why.title".localized
        titleLabel.font = AIONDesign.fontHeadline
        titleLabel.textColor = AIONDesign.textPrimary
        titleLabel.textAlignment = isRTL ? .right : .left
        stackView.addArrangedSubview(titleLabel)

        // Add contribution items
        let contributions: [(String, Double?, Double)] = [
            ("why.recovery".localized, metrics.recoveryReadiness.value, 0.25),
            ("why.sleep".localized, metrics.sleepQuality.value, 0.20),
            ("why.nervous_system".localized, metrics.nervousSystemBalance.value, 0.20),
            ("why.energy".localized, metrics.energyForecast.value, 0.15),
            ("why.activity".localized, metrics.activityScore.value, 0.10),
            ("why.load".localized, metrics.loadBalance.value, 0.10)
        ]

        for (name, value, weight) in contributions {
            let row = createContributionRow(name: name, value: value, weight: weight)
            stackView.addArrangedSubview(row)
        }
    }

    private func createContributionRow(name: String, value: Double?, weight: Double) -> UIView {
        let container = UIView()
        container.semanticContentAttribute = semanticAttribute

        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = AIONDesign.fontBody
        nameLabel.textColor = AIONDesign.textSecondary
        nameLabel.textAlignment = isRTL ? .right : .left
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nameLabel)

        let valueLabel = UILabel()
        if let v = value {
            valueLabel.text = "\(Int(v)) (\(Int(weight * 100))%)"
        } else {
            valueLabel.text = "-- (\(Int(weight * 100))%)"
        }
        valueLabel.font = AIONDesign.fontBody
        valueLabel.textColor = AIONDesign.textPrimary
        valueLabel.textAlignment = isRTL ? .left : .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(valueLabel)

        // RTL: value on left, name on right
        // LTR: name on left, value on right
        if isRTL {
            NSLayoutConstraint.activate([
                valueLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

                nameLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                nameLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

                container.heightAnchor.constraint(equalToConstant: 28)
            ])
        } else {
            NSLayoutConstraint.activate([
                nameLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                nameLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

                valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

                container.heightAnchor.constraint(equalToConstant: 28)
            ])
        }

        return container
    }
}

// MARK: - Recovery Section

final class RecoverySectionView: UIView {

    private let titleLabel = UILabel()
    private let metricsStack = UIStackView()
    private weak var parentVC: UIViewController?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = AIONDesign.surface
        layer.cornerRadius = 12

        // RTL/LTR support
        semanticContentAttribute = semanticAttribute

        let mainStack = UIStackView(arrangedSubviews: [titleLabel, metricsStack])
        mainStack.axis = .vertical
        mainStack.spacing = 12
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.semanticContentAttribute = semanticAttribute
        addSubview(mainStack)

        titleLabel.text = "section.recovery".localized
        titleLabel.font = AIONDesign.fontHeadline
        titleLabel.textColor = AIONDesign.textPrimary
        titleLabel.textAlignment = isRTL ? .right : .left

        metricsStack.axis = .horizontal
        metricsStack.distribution = .fillEqually
        metricsStack.spacing = 8
        metricsStack.semanticContentAttribute = semanticAttribute

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }

    func configure(readiness: RecoveryReadiness, stressLoad: StressLoadIndex, morningFreshness: MorningFreshness, parentVC: UIViewController? = nil) {
        self.parentVC = parentVC

        // עדכון יישור לפי שפה נוכחית
        titleLabel.textAlignment = textAlignment

        metricsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        metricsStack.addArrangedSubview(createMiniCard(
            title: "metric.recovery_readiness.short".localized,
            value: readiness.displayValue,
            color: colorForScore(readiness.value),
            explanation: "explanation.recovery_readiness".localized
        ))

        metricsStack.addArrangedSubview(createMiniCard(
            title: "metric.stress_load_index.short".localized,
            value: stressLoad.displayValue,
            color: colorForStress(stressLoad.value),
            explanation: "explanation.stress_load".localized
        ))

        metricsStack.addArrangedSubview(createMiniCard(
            title: "metric.morning_freshness.short".localized,
            value: morningFreshness.displayValue,
            color: colorForScore(morningFreshness.value),
            explanation: "explanation.morning_freshness".localized
        ))
    }

    private func createMiniCard(title: String, value: String, color: UIColor, explanation: String) -> UIView {
        let card = TappableMetricCard(title: title, explanation: explanation, parentVC: parentVC)
        card.backgroundColor = AIONDesign.background
        card.layer.cornerRadius = 8

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isUserInteractionEnabled = false
        card.addSubview(stack)

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = AIONDesign.fontTitle2
        valueLabel.textColor = color

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        titleLabel.textColor = AIONDesign.textSecondary
        titleLabel.textAlignment = .center

        stack.addArrangedSubview(valueLabel)
        stack.addArrangedSubview(titleLabel)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -4),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8)
        ])

        return card
    }

    private func colorForScore(_ value: Double?) -> UIColor {
        guard let v = value else { return AIONDesign.textTertiary }
        switch v {
        case 0..<30: return AIONDesign.statusNegative
        case 30..<60: return AIONDesign.statusNeutral
        case 60..<80: return AIONDesign.statusPositive
        default: return AIONDesign.accentPrimary
        }
    }

    private func colorForStress(_ value: Double?) -> UIColor {
        guard let v = value else { return AIONDesign.textTertiary }
        // For stress, lower is better
        switch v {
        case 0..<30: return AIONDesign.statusPositive
        case 30..<60: return AIONDesign.statusNeutral
        default: return AIONDesign.statusNegative
        }
    }
}

// MARK: - Sleep Section

final class SleepSectionView: UIView {

    private let titleLabel = UILabel()
    private let mainStack = UIStackView()
    private weak var parentVC: UIViewController?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = AIONDesign.surface
        layer.cornerRadius = 12

        // RTL/LTR support
        semanticContentAttribute = semanticAttribute

        let containerStack = UIStackView(arrangedSubviews: [titleLabel, mainStack])
        containerStack.axis = .vertical
        containerStack.spacing = 12
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        containerStack.semanticContentAttribute = semanticAttribute
        addSubview(containerStack)

        titleLabel.text = "section.sleep".localized
        titleLabel.font = AIONDesign.fontHeadline
        titleLabel.textColor = AIONDesign.textPrimary
        titleLabel.textAlignment = isRTL ? .right : .left

        mainStack.axis = .vertical
        mainStack.spacing = 8
        mainStack.semanticContentAttribute = semanticAttribute

        NSLayoutConstraint.activate([
            containerStack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            containerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            containerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            containerStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }

    func configure(quality: SleepQuality, debt: SleepDebt, consistency: SleepConsistency, parentVC: UIViewController? = nil) {
        self.parentVC = parentVC

        // עדכון יישור לפי שפה נוכחית
        titleLabel.textAlignment = textAlignment

        mainStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Quality row
        let qualityRow = createRow(
            icon: "moon.zzz.fill",
            label: "sleep.quality".localized,
            value: quality.displayValue,
            detail: formatSleepDetails(quality),
            explanation: "explanation.sleep_quality".localized
        )
        mainStack.addArrangedSubview(qualityRow)

        // Debt row
        let debtRow = createRow(
            icon: debt.isInDebt ? "arrow.down.circle" : "arrow.up.circle",
            label: "sleep.debt".localized,
            value: debt.displayValue,
            detail: debt.isInDebt ? "sleep.debt.description".localized : "sleep.surplus.description".localized,
            explanation: "explanation.sleep_debt".localized
        )
        mainStack.addArrangedSubview(debtRow)
    }

    private func formatSleepDetails(_ quality: SleepQuality) -> String {
        var parts: [String] = []

        if let hours = quality.durationHours {
            let h = Int(hours)
            let m = Int((hours - Double(h)) * 60)
            parts.append("\(h)h \(m)m")
        }

        if let deep = quality.deepPercent {
            parts.append("Deep \(Int(deep))%")
        }

        if let rem = quality.remPercent {
            parts.append("REM \(Int(rem))%")
        }

        return parts.joined(separator: " | ")
    }

    private func createRow(icon: String, label: String, value: String, detail: String, explanation: String) -> UIView {
        let currentIsRTL = LocalizationManager.shared.currentLanguage == .hebrew

        let container = TappableMetricCard(title: label, explanation: explanation, parentVC: parentVC)

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = MetricCategory.sleep.colorHex.hexColor
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.isUserInteractionEnabled = false
        container.addSubview(iconView)

        let labelStack = UIStackView()
        labelStack.axis = .vertical
        labelStack.spacing = 2
        labelStack.alignment = currentIsRTL ? .trailing : .leading
        labelStack.translatesAutoresizingMaskIntoConstraints = false
        labelStack.isUserInteractionEnabled = false
        container.addSubview(labelStack)

        let nameLabel = UILabel()
        nameLabel.text = label
        nameLabel.font = AIONDesign.fontBody
        nameLabel.textColor = AIONDesign.textPrimary
        nameLabel.textAlignment = currentIsRTL ? .right : .left
        labelStack.addArrangedSubview(nameLabel)

        let detailLabel = UILabel()
        detailLabel.text = detail
        detailLabel.font = AIONDesign.fontCaption
        detailLabel.textColor = AIONDesign.textSecondary
        detailLabel.textAlignment = currentIsRTL ? .right : .left
        labelStack.addArrangedSubview(detailLabel)

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = AIONDesign.fontTitle2
        valueLabel.textColor = AIONDesign.textPrimary
        valueLabel.textAlignment = currentIsRTL ? .left : .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.isUserInteractionEnabled = false
        container.addSubview(valueLabel)

        // RTL: value on left, labels in middle, icon on right
        // LTR: icon on left, labels in middle, value on right
        if currentIsRTL {
            NSLayoutConstraint.activate([
                valueLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

                iconView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                iconView.widthAnchor.constraint(equalToConstant: 24),
                iconView.heightAnchor.constraint(equalToConstant: 24),

                labelStack.trailingAnchor.constraint(equalTo: iconView.leadingAnchor, constant: -12),
                labelStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),

                container.heightAnchor.constraint(equalToConstant: 50)
            ])
        } else {
            NSLayoutConstraint.activate([
                iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                iconView.widthAnchor.constraint(equalToConstant: 24),
                iconView.heightAnchor.constraint(equalToConstant: 24),

                labelStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
                labelStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),

                valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

                container.heightAnchor.constraint(equalToConstant: 50)
            ])
        }

        return container
    }
}

// MARK: - Training Section

final class TrainingSectionView: UIView {

    private let titleLabel = UILabel()
    private let metricsStack = UIStackView()
    private weak var parentVC: UIViewController?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = AIONDesign.surface
        layer.cornerRadius = 12

        // RTL/LTR support
        semanticContentAttribute = semanticAttribute

        let mainStack = UIStackView(arrangedSubviews: [titleLabel, metricsStack])
        mainStack.axis = .vertical
        mainStack.spacing = 12
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.semanticContentAttribute = semanticAttribute
        addSubview(mainStack)

        titleLabel.text = "section.training".localized
        titleLabel.font = AIONDesign.fontHeadline
        titleLabel.textColor = AIONDesign.textPrimary
        titleLabel.textAlignment = isRTL ? .right : .left

        metricsStack.axis = .horizontal
        metricsStack.distribution = .fillEqually
        metricsStack.spacing = 8
        metricsStack.semanticContentAttribute = semanticAttribute

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }

    func configure(strain: InsightTrainingStrain, loadBalance: LoadBalance, cardioTrend: CardioFitnessTrend, parentVC: UIViewController? = nil) {
        self.parentVC = parentVC

        // עדכון יישור לפי שפה נוכחית
        titleLabel.textAlignment = textAlignment

        metricsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        metricsStack.addArrangedSubview(createMiniCard(
            title: "metric.training_strain.short".localized,
            value: strain.displayValue,
            icon: "flame.fill",
            explanation: "explanation.training_strain".localized
        ))

        metricsStack.addArrangedSubview(createMiniCard(
            title: "metric.load_balance.short".localized,
            value: loadBalance.zone.localizationKey.localized,
            icon: "scale.3d",
            explanation: "explanation.load_balance".localized
        ))

        metricsStack.addArrangedSubview(createMiniCard(
            title: "metric.cardio_trend.short".localized,
            value: cardioTrend.displayValue,
            icon: cardioTrend.trend?.iconName ?? "arrow.right",
            explanation: "explanation.cardio_trend".localized
        ))
    }

    private func createMiniCard(title: String, value: String, icon: String, explanation: String) -> UIView {
        let card = TappableMetricCard(title: title, explanation: explanation, parentVC: parentVC)
        card.backgroundColor = AIONDesign.background
        card.layer.cornerRadius = 8

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isUserInteractionEnabled = false
        card.addSubview(stack)

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = AIONDesign.accentPrimary
        iconView.contentMode = .scaleAspectFit

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = AIONDesign.fontBody
        valueLabel.textColor = AIONDesign.textPrimary
        valueLabel.textAlignment = .center

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        titleLabel.textColor = AIONDesign.textSecondary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(valueLabel)
        stack.addArrangedSubview(titleLabel)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -4),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8)
        ])

        return card
    }
}

// MARK: - Activity Section (Compact)

final class ActivitySectionCompact: UIView {

    private let titleLabel = UILabel()
    private let ringsStack = UIStackView()
    private weak var parentVC: UIViewController?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = AIONDesign.surface
        layer.cornerRadius = 12

        // RTL/LTR support
        semanticContentAttribute = semanticAttribute

        let mainStack = UIStackView(arrangedSubviews: [titleLabel, ringsStack])
        mainStack.axis = .vertical
        mainStack.spacing = 12
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.semanticContentAttribute = semanticAttribute
        addSubview(mainStack)

        titleLabel.text = "section.activity".localized
        titleLabel.font = AIONDesign.fontHeadline
        titleLabel.textColor = AIONDesign.textPrimary
        titleLabel.textAlignment = isRTL ? .right : .left

        ringsStack.axis = .horizontal
        ringsStack.distribution = .fillEqually
        ringsStack.spacing = 8
        ringsStack.semanticContentAttribute = semanticAttribute

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }

    func configure(goals: DailyGoals, activityScore: ActivityScore, parentVC: UIViewController? = nil) {
        self.parentVC = parentVC

        // עדכון יישור לפי שפה נוכחית
        titleLabel.textAlignment = textAlignment

        ringsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        ringsStack.addArrangedSubview(createRingItem(
            label: "activity.move".localized,
            percent: goals.movePercent ?? 0,
            color: .systemRed,
            explanation: "explanation.activity_move".localized
        ))

        ringsStack.addArrangedSubview(createRingItem(
            label: "activity.exercise".localized,
            percent: goals.exercisePercent ?? 0,
            color: .systemGreen,
            explanation: "explanation.activity_exercise".localized
        ))

        ringsStack.addArrangedSubview(createRingItem(
            label: "activity.stand".localized,
            percent: goals.standPercent ?? 0,
            color: .systemCyan,
            explanation: "explanation.activity_stand".localized
        ))
    }

    private func createRingItem(label: String, percent: Double, color: UIColor, explanation: String) -> UIView {
        let container = TappableMetricCard(title: label, explanation: explanation, parentVC: parentVC)

        let percentLabel = UILabel()
        percentLabel.text = "\(Int(percent))%"
        percentLabel.font = AIONDesign.fontHeadline
        percentLabel.textColor = color
        percentLabel.textAlignment = .center
        percentLabel.translatesAutoresizingMaskIntoConstraints = false
        percentLabel.isUserInteractionEnabled = false
        container.addSubview(percentLabel)

        let nameLabel = UILabel()
        nameLabel.text = label
        nameLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        nameLabel.textColor = AIONDesign.textSecondary
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.isUserInteractionEnabled = false
        container.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            percentLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            percentLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            nameLabel.topAnchor.constraint(equalTo: percentLabel.bottomAnchor, constant: 4),
            nameLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            nameLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])

        return container
    }
}

// MARK: - Guidance Card

final class GuidanceCardView: UIView {

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = AIONDesign.accentPrimary.withAlphaComponent(0.1)
        layer.cornerRadius = 12

        // RTL/LTR support
        semanticContentAttribute = semanticAttribute

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, messageLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.semanticContentAttribute = semanticAttribute
        addSubview(stack)

        iconView.image = UIImage(systemName: "lightbulb.fill")
        iconView.tintColor = AIONDesign.accentPrimary
        iconView.contentMode = .scaleAspectFit

        titleLabel.font = AIONDesign.fontHeadline
        titleLabel.textColor = AIONDesign.textPrimary
        titleLabel.textAlignment = .center

        messageLabel.font = AIONDesign.fontBody
        messageLabel.textColor = AIONDesign.textSecondary
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }

    func configure(with metrics: DailyMetrics, stars: StarMetrics) {
        titleLabel.text = "guidance.title".localized

        // Generate guidance based on metrics
        let guidance = generateGuidance(metrics: metrics, stars: stars)
        messageLabel.text = guidance
    }

    private func generateGuidance(metrics: DailyMetrics, stars: StarMetrics) -> String {
        // Priority: Workout readiness -> Energy -> Stress -> Sleep
        if let workoutValue = metrics.workoutReadiness.value {
            let level = WorkoutReadinessLevel.from(score: workoutValue)
            return StarMetricsCalculator.actionAdvice(for: metrics.workoutReadiness)
        }

        if let energyValue = metrics.energyForecast.value {
            return StarMetricsCalculator.actionAdvice(for: metrics.energyForecast)
        }

        if let nsb = metrics.nervousSystemBalance.value {
            return StarMetricsCalculator.actionAdvice(for: metrics.nervousSystemBalance)
        }

        return "guidance.default".localized
    }
}

// MARK: - Metric Detail View Controller

final class MetricDetailViewController: UIViewController {

    private let metric: any InsightMetric

    init(metric: any InsightMetric) {
        self.metric = metric
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AIONDesign.background
        setupUI()
    }

    private func setupUI() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        // Icon
        let iconView = UIImageView(image: UIImage(systemName: StarMetricsCalculator.icon(for: metric.id)))
        iconView.tintColor = StarMetricsCalculator.color(for: metric)
        iconView.contentMode = .scaleAspectFit

        // Title
        let titleLabel = UILabel()
        titleLabel.text = metric.nameKey.localized
        titleLabel.font = AIONDesign.fontTitle2
        titleLabel.textColor = AIONDesign.textPrimary

        // Value
        let valueLabel = UILabel()
        valueLabel.text = metric.displayValue
        valueLabel.font = UIFont.systemFont(ofSize: 48, weight: .bold)
        valueLabel.textColor = StarMetricsCalculator.color(for: metric)

        // Why it matters
        let whyLabel = UILabel()
        whyLabel.text = StarMetricsCalculator.whyItMatters(for: metric.id)
        whyLabel.font = AIONDesign.fontBody
        whyLabel.textColor = AIONDesign.textSecondary
        whyLabel.textAlignment = .center
        whyLabel.numberOfLines = 0

        // Action advice
        let actionLabel = UILabel()
        actionLabel.text = StarMetricsCalculator.actionAdvice(for: metric)
        actionLabel.font = AIONDesign.fontBody
        actionLabel.textColor = AIONDesign.textPrimary
        actionLabel.textAlignment = .center
        actionLabel.numberOfLines = 0

        // Reliability badge
        let reliabilityLabel = UILabel()
        reliabilityLabel.text = "\("reliability.label".localized): \(metric.reliability.localizationKey.localized)"
        reliabilityLabel.font = AIONDesign.fontCaption
        reliabilityLabel.textColor = AIONDesign.textTertiary

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(valueLabel)
        stack.addArrangedSubview(whyLabel)
        stack.addArrangedSubview(actionLabel)
        stack.addArrangedSubview(reliabilityLabel)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 48),
            iconView.heightAnchor.constraint(equalToConstant: 48),

            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }
}

// MARK: - Helper Extensions

extension String {
    var hexColor: UIColor {
        var hexString = self.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexString.hasPrefix("#") {
            hexString.remove(at: hexString.startIndex)
        }

        var rgbValue: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgbValue)

        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
}

extension UIImageView {
    func loadImageAsync(from url: URL) {
        DispatchQueue.global().async { [weak self] in
            if let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self?.image = image
                }
            }
        }
    }
}
