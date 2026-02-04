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

        // Greeting based on time + user name
        let hour = Calendar.current.component(.hour, from: Date())
        let greetingKey: String
        switch hour {
        case 5..<12: greetingKey = "greeting.morning"
        case 12..<17: greetingKey = "greeting.afternoon"
        case 17..<21: greetingKey = "greeting.evening"
        default: greetingKey = "greeting.night"
        }
        let greeting = greetingKey.localized
        if let displayName = Auth.auth().currentUser?.displayName, !displayName.isEmpty {
            let firstName = displayName.components(separatedBy: " ").first ?? displayName
            greetingLabel.text = "\(greeting), \(firstName)"
        } else {
            greetingLabel.text = greeting
        }

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

// MARK: - Hero Score Section (3 Score Cubes + Energy Forecast)

final class HeroScoreSection: UIView {

    var onWhyTapped: (() -> Void)?
    var onCarTapped: (() -> Void)?
    var onSleepTapped: (() -> Void)?
    private weak var parentVC: UIViewController?
    private var currentEnergyForecast: EnergyForecast?

    // שמירת הציונים הנוכחיים עבור ה-bottom sheets
    private var currentHealthScore: Int?
    private var currentCarScore: Int?
    private var currentCarName: String?
    private var currentSleepScore: Int?

    // MARK: - Score Cubes
    private let cubesStack = UIStackView()

    // Cube 1: Health Score
    private let healthCube = UIView()
    private let healthIconView = UIImageView()
    private let healthScoreLabel = UILabel()
    private let healthTitleLabel = UILabel()

    // Cube 2: Car Tier Score
    private let carCube = UIView()
    private let carIconView = UIImageView()
    private let carScoreLabel = UILabel()
    private let carTitleLabel = UILabel()
    private let carNameLabel = UILabel()

    // Cube 3: Sleep Score
    private let sleepCube = UIView()
    private let sleepIconView = UIImageView()
    private let sleepScoreLabel = UILabel()
    private let sleepTitleLabel = UILabel()

    // MARK: - Energy Forecast Card
    private let energyCard = UIView()
    private let energyGradientLayer = CAGradientLayer()  // גרדיאנט רקע
    private let energyIconView = UIImageView()  // אייקון ברק
    private let energyScoreLabel = UILabel()    // ציון אנרגיה גדול
    private let energyLevelLabel = UILabel()    // רמה (גבוה/בינוני/נמוך)
    private let energyTitleLabel = UILabel()
    private let energyTextLabel = UILabel()

    // Loading indicators
    private let healthLoadingIndicator = UIActivityIndicatorView(style: .medium)
    private let carLoadingIndicator = UIActivityIndicatorView(style: .medium)
    private let sleepLoadingIndicator = UIActivityIndicatorView(style: .medium)
    private let energyLoadingIndicator = UIActivityIndicatorView(style: .medium)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        semanticContentAttribute = semanticAttribute

        let mainStack = UIStackView()
        mainStack.axis = .vertical
        mainStack.spacing = 12
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.semanticContentAttribute = semanticAttribute
        addSubview(mainStack)

        // === Score Cubes Row ===
        cubesStack.axis = .horizontal
        cubesStack.spacing = 10
        cubesStack.distribution = .fillEqually
        cubesStack.semanticContentAttribute = semanticAttribute
        mainStack.addArrangedSubview(cubesStack)

        setupCube(healthCube, icon: healthIconView, scoreLabel: healthScoreLabel, titleLabel: healthTitleLabel,
                  iconName: "battery.100.bolt", iconColor: AIONDesign.accentSuccess,
                  title: "dashboard.healthScore".localized, loading: healthLoadingIndicator,
                  action: #selector(healthCubeTapped))

        setupCube(carCube, icon: carIconView, scoreLabel: carScoreLabel, titleLabel: carTitleLabel,
                  iconName: "car.fill", iconColor: AIONDesign.accentPrimary,
                  title: "dashboard.carTier".localized, loading: carLoadingIndicator,
                  action: #selector(carCubeTapped), subtitle: carNameLabel)

        setupCube(sleepCube, icon: sleepIconView, scoreLabel: sleepScoreLabel, titleLabel: sleepTitleLabel,
                  iconName: "moon.zzz.fill", iconColor: AIONDesign.accentSecondary,
                  title: "dashboard.sleepScore".localized, loading: sleepLoadingIndicator,
                  action: #selector(sleepCubeTapped))

        cubesStack.addArrangedSubview(healthCube)
        cubesStack.addArrangedSubview(carCube)
        cubesStack.addArrangedSubview(sleepCube)

        // === Energy Forecast Card ===
        setupEnergyForecastCard()
        mainStack.addArrangedSubview(energyCard)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor),

            cubesStack.heightAnchor.constraint(equalToConstant: 110),
            energyCard.heightAnchor.constraint(equalToConstant: 150)
        ])
    }

    private func setupCube(_ cube: UIView, icon: UIImageView, scoreLabel: UILabel, titleLabel: UILabel,
                           iconName: String, iconColor: UIColor, title: String,
                           loading: UIActivityIndicatorView, action: Selector, subtitle: UILabel? = nil) {
        cube.backgroundColor = AIONDesign.surface
        cube.layer.cornerRadius = AIONDesign.cornerRadius
        setupCardShadow(cube)

        let tap = UITapGestureRecognizer(target: self, action: action)
        cube.addGestureRecognizer(tap)
        cube.isUserInteractionEnabled = true

        // Icon
        let cfg = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        icon.image = UIImage(systemName: iconName, withConfiguration: cfg)
        icon.tintColor = iconColor
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        cube.addSubview(icon)

        // Score
        scoreLabel.font = .systemFont(ofSize: 32, weight: .bold)
        scoreLabel.textColor = AIONDesign.textPrimary
        scoreLabel.textAlignment = .center
        scoreLabel.translatesAutoresizingMaskIntoConstraints = false
        cube.addSubview(scoreLabel)

        // Title
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = AIONDesign.textSecondary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cube.addSubview(titleLabel)

        // Loading indicator
        loading.color = AIONDesign.accentPrimary
        loading.hidesWhenStopped = true
        loading.translatesAutoresizingMaskIntoConstraints = false
        cube.addSubview(loading)

        NSLayoutConstraint.activate([
            icon.topAnchor.constraint(equalTo: cube.topAnchor, constant: 8),
            icon.centerXAnchor.constraint(equalTo: cube.centerXAnchor),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),

            scoreLabel.centerXAnchor.constraint(equalTo: cube.centerXAnchor),
            scoreLabel.centerYAnchor.constraint(equalTo: cube.centerYAnchor),

            titleLabel.bottomAnchor.constraint(equalTo: cube.bottomAnchor, constant: -8),
            titleLabel.centerXAnchor.constraint(equalTo: cube.centerXAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: cube.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: cube.trailingAnchor, constant: -4),

            loading.centerXAnchor.constraint(equalTo: cube.centerXAnchor),
            loading.centerYAnchor.constraint(equalTo: cube.centerYAnchor)
        ])

        // Optional subtitle (for car name)
        if let subtitle = subtitle {
            subtitle.font = .systemFont(ofSize: 9, weight: .regular)
            subtitle.textColor = AIONDesign.textTertiary
            subtitle.textAlignment = .center
            subtitle.numberOfLines = 1
            subtitle.lineBreakMode = .byTruncatingTail
            subtitle.translatesAutoresizingMaskIntoConstraints = false
            cube.addSubview(subtitle)

            NSLayoutConstraint.activate([
                subtitle.topAnchor.constraint(equalTo: scoreLabel.bottomAnchor, constant: 1),
                subtitle.centerXAnchor.constraint(equalTo: cube.centerXAnchor),
                subtitle.leadingAnchor.constraint(equalTo: cube.leadingAnchor, constant: 4),
                subtitle.trailingAnchor.constraint(equalTo: cube.trailingAnchor, constant: -4)
            ])

            // Adjust title position when subtitle exists
            titleLabel.removeFromSuperview()
            cube.addSubview(titleLabel)
            NSLayoutConstraint.activate([
                titleLabel.bottomAnchor.constraint(equalTo: cube.bottomAnchor, constant: -6),
                titleLabel.centerXAnchor.constraint(equalTo: cube.centerXAnchor),
                titleLabel.leadingAnchor.constraint(equalTo: cube.leadingAnchor, constant: 4),
                titleLabel.trailingAnchor.constraint(equalTo: cube.trailingAnchor, constant: -4)
            ])
        }
    }

    private func setupEnergyForecastCard() {
        energyCard.backgroundColor = AIONDesign.surface
        energyCard.layer.cornerRadius = AIONDesign.cornerRadiusLarge
        energyCard.clipsToBounds = true
        setupCardShadow(energyCard)

        let tap = UITapGestureRecognizer(target: self, action: #selector(energyCardTapped))
        energyCard.addGestureRecognizer(tap)
        energyCard.isUserInteractionEnabled = true

        // === גרדיאנט רקע עדין ===
        energyGradientLayer.colors = [
            UIColor.systemOrange.withAlphaComponent(0.15).cgColor,
            UIColor.systemYellow.withAlphaComponent(0.05).cgColor
        ]
        energyGradientLayer.startPoint = CGPoint(x: 0, y: 0)
        energyGradientLayer.endPoint = CGPoint(x: 1, y: 1)
        energyCard.layer.insertSublayer(energyGradientLayer, at: 0)

        // === שורה עליונה: ציון + רמה (ממורכז) ===
        // ציון אנרגיה גדול ובולט
        energyScoreLabel.font = .systemFont(ofSize: 48, weight: .heavy)
        energyScoreLabel.textColor = AIONDesign.textPrimary
        energyScoreLabel.textAlignment = .center
        energyScoreLabel.translatesAutoresizingMaskIntoConstraints = false
        energyCard.addSubview(energyScoreLabel)

        // רמת אנרגיה (גבוה/בינוני/נמוך) - בולטת יותר
        energyLevelLabel.font = .systemFont(ofSize: 20, weight: .bold)
        energyLevelLabel.textColor = AIONDesign.accentWarning
        energyLevelLabel.textAlignment = .center
        energyLevelLabel.translatesAutoresizingMaskIntoConstraints = false
        energyCard.addSubview(energyLevelLabel)

        // אייקון ברק קטן ליד הרמה
        let iconCfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        energyIconView.image = UIImage(systemName: "bolt.fill", withConfiguration: iconCfg)
        energyIconView.tintColor = AIONDesign.accentWarning
        energyIconView.contentMode = .scaleAspectFit
        energyIconView.translatesAutoresizingMaskIntoConstraints = false
        energyCard.addSubview(energyIconView)

        // === שורה תחתונה: הסבר (ממורכז) ===
        energyTextLabel.font = .systemFont(ofSize: 14, weight: .medium)
        energyTextLabel.textColor = AIONDesign.textSecondary
        energyTextLabel.textAlignment = .center
        energyTextLabel.numberOfLines = 2
        energyTextLabel.translatesAutoresizingMaskIntoConstraints = false
        energyCard.addSubview(energyTextLabel)

        // כותרת קטנה למעלה
        energyTitleLabel.text = "dashboard.energyForecast".localized
        energyTitleLabel.font = .systemFont(ofSize: 10, weight: .medium)
        energyTitleLabel.textColor = AIONDesign.textTertiary
        energyTitleLabel.textAlignment = .center
        energyTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        energyCard.addSubview(energyTitleLabel)

        // Loading indicator
        energyLoadingIndicator.color = AIONDesign.accentPrimary
        energyLoadingIndicator.hidesWhenStopped = true
        energyLoadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        energyCard.addSubview(energyLoadingIndicator)

        NSLayoutConstraint.activate([
            // כותרת קטנה למעלה
            energyTitleLabel.topAnchor.constraint(equalTo: energyCard.topAnchor, constant: 10),
            energyTitleLabel.centerXAnchor.constraint(equalTo: energyCard.centerXAnchor),

            // ציון במרכז
            energyScoreLabel.topAnchor.constraint(equalTo: energyTitleLabel.bottomAnchor, constant: 2),
            energyScoreLabel.centerXAnchor.constraint(equalTo: energyCard.centerXAnchor),

            // אייקון ברק ליד הרמה
            energyIconView.centerYAnchor.constraint(equalTo: energyLevelLabel.centerYAnchor),
            energyIconView.trailingAnchor.constraint(equalTo: energyLevelLabel.leadingAnchor, constant: -4),
            energyIconView.widthAnchor.constraint(equalToConstant: 18),
            energyIconView.heightAnchor.constraint(equalToConstant: 18),

            // רמה מתחת לציון
            energyLevelLabel.topAnchor.constraint(equalTo: energyScoreLabel.bottomAnchor, constant: -2),
            energyLevelLabel.centerXAnchor.constraint(equalTo: energyCard.centerXAnchor, constant: 10),

            // הסבר בתחתית
            energyTextLabel.topAnchor.constraint(equalTo: energyLevelLabel.bottomAnchor, constant: 8),
            energyTextLabel.leadingAnchor.constraint(equalTo: energyCard.leadingAnchor, constant: 16),
            energyTextLabel.trailingAnchor.constraint(equalTo: energyCard.trailingAnchor, constant: -16),
            energyTextLabel.bottomAnchor.constraint(lessThanOrEqualTo: energyCard.bottomAnchor, constant: -12),

            energyLoadingIndicator.centerXAnchor.constraint(equalTo: energyCard.centerXAnchor),
            energyLoadingIndicator.centerYAnchor.constraint(equalTo: energyCard.centerYAnchor)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // עדכון גודל הגרדיאנט
        energyGradientLayer.frame = energyCard.bounds
    }

    private func setupCardShadow(_ view: UIView) {
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 8
    }

    // MARK: - Actions

    @objc private func healthCubeTapped() {
        guard let vc = parentVC, let score = currentHealthScore else {
            onWhyTapped?()
            return
        }
        let detailVC = HealthScoreDetailViewController(score: score)
        vc.present(detailVC, animated: true)
    }

    @objc private func carCubeTapped() {
        guard let vc = parentVC, let score = currentCarScore else {
            onCarTapped?()
            return
        }
        let detailVC = CarScoreDetailViewController(score: score, carName: currentCarName)
        vc.present(detailVC, animated: true)
    }

    @objc private func sleepCubeTapped() {
        guard let vc = parentVC, let score = currentSleepScore else {
            onSleepTapped?()
            return
        }
        let detailVC = SleepScoreDetailViewController(score: score)
        vc.present(detailVC, animated: true)
    }

    @objc private func energyCardTapped() {
        guard let vc = parentVC, let energy = currentEnergyForecast else { return }
        let detailVC = EnergyDetailViewController(energyForecast: energy)
        vc.present(detailVC, animated: true)
    }

    // MARK: - Configuration

    func configure(healthScore: Int?, carScore: Int?, carName: String?, sleepScore: Int?,
                   energyForecast: EnergyForecast, parentVC: UIViewController? = nil, isLoading: Bool = false) {
        self.parentVC = parentVC
        self.currentEnergyForecast = energyForecast

        // שמירת הציונים עבור ה-bottom sheets
        self.currentHealthScore = healthScore
        self.currentCarScore = carScore
        self.currentCarName = carName
        self.currentSleepScore = sleepScore

        // Health Score Cube
        if let score = healthScore, score > 0 {
            healthLoadingIndicator.stopAnimating()
            healthScoreLabel.isHidden = false
            healthScoreLabel.text = "\(score)"
            healthScoreLabel.textColor = colorForScore(Double(score))
        } else if isLoading {
            healthScoreLabel.isHidden = true
            healthLoadingIndicator.startAnimating()
        } else {
            // No data - show placeholder
            healthLoadingIndicator.stopAnimating()
            healthScoreLabel.isHidden = false
            healthScoreLabel.text = "—"
            healthScoreLabel.textColor = AIONDesign.textTertiary
        }

        // Car Score Cube
        if let score = carScore, score > 0 {
            carLoadingIndicator.stopAnimating()
            carScoreLabel.isHidden = false
            carScoreLabel.text = "\(score)"
            carScoreLabel.textColor = colorForScore(Double(score))
            carNameLabel.text = carName
            carNameLabel.isHidden = carName == nil || carName?.isEmpty == true
        } else if isLoading {
            carScoreLabel.isHidden = true
            carNameLabel.isHidden = true
            carLoadingIndicator.startAnimating()
        } else {
            // No data - show placeholder
            carLoadingIndicator.stopAnimating()
            carScoreLabel.isHidden = false
            carScoreLabel.text = "—"
            carScoreLabel.textColor = AIONDesign.textTertiary
            carNameLabel.isHidden = true
        }

        // Sleep Score Cube
        if let score = sleepScore, score > 0 {
            sleepLoadingIndicator.stopAnimating()
            sleepScoreLabel.isHidden = false
            sleepScoreLabel.text = "\(score)"
            sleepScoreLabel.textColor = colorForScore(Double(score))
        } else if isLoading {
            sleepScoreLabel.isHidden = true
            sleepLoadingIndicator.startAnimating()
        } else {
            // No data - show placeholder
            sleepLoadingIndicator.stopAnimating()
            sleepScoreLabel.isHidden = false
            sleepScoreLabel.text = "—"
            sleepScoreLabel.textColor = AIONDesign.textTertiary
        }

        // Energy Forecast
        configureEnergyForecast(energyForecast, isLoading: isLoading)
    }

    // Legacy configure method for backward compatibility
    func configure(mainScore: Double?, energyForecast: EnergyForecast, parentVC: UIViewController? = nil) {
        // Calculate car score from weekly stats
        let stats = AnalysisCache.loadWeeklyStats()
        let carScore = CarTierEngine.computeHealthScore(
            readinessAvg: stats?.readiness,
            sleepHoursAvg: stats?.sleepHours,
            hrvAvg: stats?.hrv,
            strainAvg: stats?.strain
        )
        let carTier = CarTierEngine.tierForScore(carScore)
        let savedCar = AnalysisCache.loadSelectedCar()
        let carName = savedCar?.name ?? carTier.name

        // Get sleep score from energy forecast or calculate
        let sleepScore: Int? = energyForecast.value != nil ? Int(energyForecast.value! * 0.8) : nil

        configure(
            healthScore: mainScore != nil ? Int(mainScore!) : nil,
            carScore: carScore > 0 ? carScore : nil,
            carName: carName,
            sleepScore: sleepScore,
            energyForecast: energyForecast,
            parentVC: parentVC
        )
    }

    private func configureEnergyForecast(_ forecast: EnergyForecast, isLoading: Bool = false) {
        if let energy = forecast.value {
            energyLoadingIndicator.stopAnimating()
            energyScoreLabel.isHidden = false
            energyIconView.isHidden = false
            energyLevelLabel.isHidden = false
            energyTextLabel.isHidden = false
            energyTitleLabel.isHidden = false

            // הצגת ציון האנרגיה
            energyScoreLabel.text = "\(Int(energy))"

            // צבע ורמה לפי האנרגיה
            let color: UIColor
            let levelText: String
            if energy >= 70 {
                color = AIONDesign.accentSuccess  // ירוק - אנרגיה גבוהה
                levelText = "energy.level.high".localized
            } else if energy >= 40 {
                color = AIONDesign.accentWarning  // כתום - אנרגיה בינונית
                levelText = "energy.level.medium".localized
            } else {
                color = AIONDesign.accentDanger   // אדום - אנרגיה נמוכה
                levelText = "energy.level.low".localized
            }

            energyLevelLabel.text = levelText
            energyLevelLabel.textColor = color
            energyIconView.tintColor = color  // צבע האייקון
            energyScoreLabel.textColor = color  // גם הציון בצבע

            // עדכון גרדיאנט לפי הצבע - יותר בולט
            energyGradientLayer.colors = [
                color.withAlphaComponent(0.20).cgColor,
                color.withAlphaComponent(0.05).cgColor
            ]

            // טקסט הסבר
            energyTextLabel.text = forecast.explanationKey.localized
        } else if isLoading {
            energyScoreLabel.isHidden = true
            energyIconView.isHidden = true
            energyLevelLabel.isHidden = true
            energyTextLabel.text = "dashboard.energyForecast.loading".localized
            energyTextLabel.isHidden = false
            energyTitleLabel.isHidden = false
            energyLoadingIndicator.startAnimating()
        } else {
            // No data - show placeholder
            energyLoadingIndicator.stopAnimating()
            energyScoreLabel.isHidden = false
            energyScoreLabel.text = "—"
            energyScoreLabel.textColor = AIONDesign.textTertiary
            energyIconView.isHidden = true
            energyLevelLabel.isHidden = true
            energyTextLabel.text = "dashboard.noData".localized
            energyTextLabel.isHidden = false
            energyTitleLabel.isHidden = false
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

// MARK: - Trend Direction

private enum TrendDirection {
    case rising, falling, stable

    var iconName: String {
        switch self {
        case .rising: return "arrow.up.right"
        case .falling: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }

    var color: UIColor {
        switch self {
        case .rising: return AIONDesign.accentSuccess
        case .falling: return AIONDesign.accentDanger
        case .stable: return AIONDesign.accentWarning
        }
    }
}

// MARK: - Mini Trend Graph View

private final class MiniTrendGraphView: UIView {

    private var trend: TrendDirection = .stable
    private let lineLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        lineLayer.fillColor = UIColor.clear.cgColor
        lineLayer.lineWidth = 2
        lineLayer.lineCap = .round
        lineLayer.lineJoin = .round
        layer.addSublayer(lineLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        drawTrendLine()
    }

    func configure(trend: TrendDirection) {
        self.trend = trend
        lineLayer.strokeColor = trend.color.cgColor
        setNeedsLayout()
    }

    private func drawTrendLine() {
        let path = UIBezierPath()
        let w = bounds.width
        let h = bounds.height
        let padding: CGFloat = 4

        switch trend {
        case .rising:
            path.move(to: CGPoint(x: padding, y: h - padding))
            path.addQuadCurve(
                to: CGPoint(x: w - padding, y: padding),
                controlPoint: CGPoint(x: w * 0.5, y: h * 0.3)
            )
        case .falling:
            path.move(to: CGPoint(x: padding, y: padding))
            path.addQuadCurve(
                to: CGPoint(x: w - padding, y: h - padding),
                controlPoint: CGPoint(x: w * 0.5, y: h * 0.7)
            )
        case .stable:
            path.move(to: CGPoint(x: padding, y: h * 0.5))
            path.addCurve(
                to: CGPoint(x: w - padding, y: h * 0.5),
                controlPoint1: CGPoint(x: w * 0.33, y: h * 0.3),
                controlPoint2: CGPoint(x: w * 0.66, y: h * 0.7)
            )
        }

        lineLayer.path = path.cgPath
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

// MARK: - Health Score Detail (Bottom Sheet)

final class HealthScoreDetailViewController: UIViewController {

    private let score: Int

    init(score: Int) {
        self.score = score
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
        let iconView = UIImageView(image: UIImage(systemName: "battery.100.bolt"))
        iconView.tintColor = AIONDesign.accentSuccess
        iconView.contentMode = .scaleAspectFit

        // Title
        let titleLabel = UILabel()
        titleLabel.text = "healthScore.detail.title".localized
        titleLabel.font = AIONDesign.fontTitle2
        titleLabel.textColor = AIONDesign.textPrimary

        // Score
        let scoreLabel = UILabel()
        scoreLabel.text = "\(score)"
        scoreLabel.font = UIFont.systemFont(ofSize: 56, weight: .bold)
        scoreLabel.textColor = colorForScore(Double(score))

        // Explanation
        let explanationLabel = UILabel()
        explanationLabel.text = "healthScore.detail.explanation".localized
        explanationLabel.font = AIONDesign.fontBody
        explanationLabel.textColor = AIONDesign.textSecondary
        explanationLabel.textAlignment = .center
        explanationLabel.numberOfLines = 0

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(scoreLabel)
        stack.addArrangedSubview(explanationLabel)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 48),
            iconView.heightAnchor.constraint(equalToConstant: 48),

            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
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

// MARK: - Car Score Detail (Bottom Sheet)

final class CarScoreDetailViewController: UIViewController {

    private let score: Int
    private let carName: String?

    init(score: Int, carName: String?) {
        self.score = score
        self.carName = carName
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
        let iconView = UIImageView(image: UIImage(systemName: "car.fill"))
        iconView.tintColor = AIONDesign.accentPrimary
        iconView.contentMode = .scaleAspectFit

        // Title
        let titleLabel = UILabel()
        titleLabel.text = "carScore.detail.title".localized
        titleLabel.font = AIONDesign.fontTitle2
        titleLabel.textColor = AIONDesign.textPrimary

        // Score
        let scoreLabel = UILabel()
        scoreLabel.text = "\(score)"
        scoreLabel.font = UIFont.systemFont(ofSize: 56, weight: .bold)
        scoreLabel.textColor = colorForScore(Double(score))

        // Car Name (if available)
        if let name = carName, !name.isEmpty {
            let carNameLabel = UILabel()
            carNameLabel.text = name
            carNameLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
            carNameLabel.textColor = AIONDesign.textSecondary
            stack.addArrangedSubview(iconView)
            stack.addArrangedSubview(titleLabel)
            stack.addArrangedSubview(scoreLabel)
            stack.addArrangedSubview(carNameLabel)
        } else {
            stack.addArrangedSubview(iconView)
            stack.addArrangedSubview(titleLabel)
            stack.addArrangedSubview(scoreLabel)
        }

        // Explanation
        let explanationLabel = UILabel()
        explanationLabel.text = "carScore.detail.explanation".localized
        explanationLabel.font = AIONDesign.fontBody
        explanationLabel.textColor = AIONDesign.textSecondary
        explanationLabel.textAlignment = .center
        explanationLabel.numberOfLines = 0
        stack.addArrangedSubview(explanationLabel)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 48),
            iconView.heightAnchor.constraint(equalToConstant: 48),

            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
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

// MARK: - Sleep Score Detail (Bottom Sheet)

final class SleepScoreDetailViewController: UIViewController {

    private let score: Int

    init(score: Int) {
        self.score = score
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
        let iconView = UIImageView(image: UIImage(systemName: "moon.zzz.fill"))
        iconView.tintColor = AIONDesign.accentSecondary
        iconView.contentMode = .scaleAspectFit

        // Title
        let titleLabel = UILabel()
        titleLabel.text = "sleepScore.detail.title".localized
        titleLabel.font = AIONDesign.fontTitle2
        titleLabel.textColor = AIONDesign.textPrimary

        // Score
        let scoreLabel = UILabel()
        scoreLabel.text = "\(score)"
        scoreLabel.font = UIFont.systemFont(ofSize: 56, weight: .bold)
        scoreLabel.textColor = colorForScore(Double(score))

        // Explanation
        let explanationLabel = UILabel()
        explanationLabel.text = "sleepScore.detail.explanation".localized
        explanationLabel.font = AIONDesign.fontBody
        explanationLabel.textColor = AIONDesign.textSecondary
        explanationLabel.textAlignment = .center
        explanationLabel.numberOfLines = 0

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(scoreLabel)
        stack.addArrangedSubview(explanationLabel)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 48),
            iconView.heightAnchor.constraint(equalToConstant: 48),

            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
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

// MARK: - Tappable Sleep Bar (לחיצה על יום בגרף)

final class TappableSleepBar: UIView {

    private let entry: DailySleepEntry
    private let isRTL: Bool
    private weak var parentVC: UIViewController?

    init(entry: DailySleepEntry, isRTL: Bool, parentVC: UIViewController?) {
        self.entry = entry
        self.isRTL = isRTL
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
        guard entry.hours > 0 else { return }

        // פורמט התאריך
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: isRTL ? "he_IL" : "en_US")
        dateFormatter.dateFormat = isRTL ? "EEEE, d בMMMM" : "EEEE, MMMM d"
        let dateStr = dateFormatter.string(from: entry.date)

        // פורמט שעות - עם עיגול נכון
        let hours = Int(entry.hours)
        let minutes = Int(round((entry.hours - Double(hours)) * 60))
        let timeStr = isRTL ? "\(hours) שע׳ \(minutes) דק׳" : "\(hours)h \(minutes)m"

        // יצירת tooltip צף (כמו באפל)
        showTooltip(dateStr: dateStr, timeStr: timeStr)
    }

    private func showTooltip(dateStr: String, timeStr: String) {
        guard let window = window else { return }

        // הסרת tooltip קודם אם קיים
        window.subviews.filter { $0.tag == 9999 }.forEach { $0.removeFromSuperview() }

        // יצירת tooltip view
        let tooltip = UIView()
        tooltip.tag = 9999
        tooltip.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        tooltip.layer.cornerRadius = 10
        tooltip.translatesAutoresizingMaskIntoConstraints = false

        // תוכן ה-tooltip
        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 4
        contentStack.alignment = .center
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        tooltip.addSubview(contentStack)

        let dateLabel = UILabel()
        dateLabel.text = dateStr
        dateLabel.font = .systemFont(ofSize: 12, weight: .medium)
        dateLabel.textColor = .white.withAlphaComponent(0.7)
        dateLabel.textAlignment = .center

        let timeLabel = UILabel()
        timeLabel.text = timeStr
        timeLabel.font = .systemFont(ofSize: 16, weight: .bold)
        timeLabel.textColor = .white
        timeLabel.textAlignment = .center

        contentStack.addArrangedSubview(dateLabel)
        contentStack.addArrangedSubview(timeLabel)

        // חץ קטן למטה
        let arrow = UIView()
        arrow.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        arrow.translatesAutoresizingMaskIntoConstraints = false
        arrow.transform = CGAffineTransform(rotationAngle: .pi / 4)
        tooltip.addSubview(arrow)

        window.addSubview(tooltip)

        // מיקום ה-tooltip מעל הבר - עם תיקון לגבולות המסך
        let barFrame = convert(bounds, to: window)
        let tooltipWidth: CGFloat = 150 // רוחב משוער של ה-tooltip
        let screenWidth = window.bounds.width
        let padding: CGFloat = 12

        // חישוב מיקום X - וידוא שלא יוצא מהמסך
        var tooltipCenterX = barFrame.midX

        // אם יוצא מימין - הזז שמאלה
        if tooltipCenterX + tooltipWidth / 2 > screenWidth - padding {
            tooltipCenterX = screenWidth - padding - tooltipWidth / 2
        }
        // אם יוצא משמאל - הזז ימינה
        if tooltipCenterX - tooltipWidth / 2 < padding {
            tooltipCenterX = padding + tooltipWidth / 2
        }

        // חישוב offset של החץ ביחס למרכז ה-tooltip
        let arrowOffsetX = barFrame.midX - tooltipCenterX

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: tooltip.topAnchor, constant: 8),
            contentStack.leadingAnchor.constraint(equalTo: tooltip.leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(equalTo: tooltip.trailingAnchor, constant: -12),
            contentStack.bottomAnchor.constraint(equalTo: tooltip.bottomAnchor, constant: -12),

            arrow.widthAnchor.constraint(equalToConstant: 12),
            arrow.heightAnchor.constraint(equalToConstant: 12),
            arrow.centerXAnchor.constraint(equalTo: tooltip.centerXAnchor, constant: arrowOffsetX),
            arrow.bottomAnchor.constraint(equalTo: tooltip.bottomAnchor, constant: 4),

            tooltip.centerXAnchor.constraint(equalTo: window.leadingAnchor, constant: tooltipCenterX),
            tooltip.bottomAnchor.constraint(equalTo: window.topAnchor, constant: barFrame.minY - 8)
        ])

        // אנימציה
        tooltip.alpha = 0
        tooltip.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
            tooltip.alpha = 1
            tooltip.transform = .identity
        }

        // הסתרה אוטומטית אחרי 2 שניות
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            UIView.animate(withDuration: 0.2, animations: {
                tooltip.alpha = 0
                tooltip.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            }) { _ in
                tooltip.removeFromSuperview()
            }
        }
    }
}

// MARK: - Sleep Section (Apple Health Style)

final class SleepSectionView: UIView {

    private let mainStack = UIStackView()
    private weak var parentVC: UIViewController?

    // צבעים בסגנון אפל
    private let sleepPurple = UIColor(red: 0.55, green: 0.45, blue: 0.95, alpha: 1.0) // סגול בהיר כמו באפל
    private let sleepPurpleLight = UIColor(red: 0.55, green: 0.45, blue: 0.95, alpha: 0.3)
    private let targetLineColor = UIColor(red: 0.4, green: 0.75, blue: 0.95, alpha: 1.0) // כחול בהיר לקו הממוצע

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = AIONDesign.surface
        layer.cornerRadius = 16

        mainStack.axis = .vertical
        mainStack.spacing = 16
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }

    func configure(quality: SleepQuality, debt: SleepHighlight, consistency: SleepConsistency, parentVC: UIViewController? = nil) {
        self.parentVC = parentVC
        mainStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let currentIsRTL = LocalizationManager.shared.currentLanguage == .hebrew

        // === כרטיס איכות שינה ===
        let qualityCard = createQualityCard(quality: quality, isRTL: currentIsRTL)
        mainStack.addArrangedSubview(qualityCard)

        // === קו מפריד דק ===
        let separator = UIView()
        separator.backgroundColor = AIONDesign.textTertiary.withAlphaComponent(0.2)
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        mainStack.addArrangedSubview(separator)

        // === כרטיס דגש שינה (בסגנון אפל) ===
        let highlightCard = createSleepHighlightCard(highlight: debt, isRTL: currentIsRTL)
        mainStack.addArrangedSubview(highlightCard)
    }

    // MARK: - Quality Card

    private func createQualityCard(quality: SleepQuality, isRTL: Bool) -> UIView {
        let container = UIView()

        // כותרת עם אייקון
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.spacing = 8
        headerStack.alignment = .center
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(headerStack)

        let iconView = UIImageView(image: UIImage(systemName: "bed.double.fill"))
        iconView.tintColor = sleepPurple
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 20).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 20).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = "sleep.quality".localized
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = sleepPurple

        if isRTL {
            headerStack.addArrangedSubview(titleLabel)
            headerStack.addArrangedSubview(iconView)
        } else {
            headerStack.addArrangedSubview(iconView)
            headerStack.addArrangedSubview(titleLabel)
        }

        // ציון ופרטים
        let scoreLabel = UILabel()
        scoreLabel.text = quality.displayValue
        scoreLabel.font = .systemFont(ofSize: 34, weight: .bold)
        scoreLabel.textColor = AIONDesign.textPrimary
        scoreLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scoreLabel)

        let detailLabel = UILabel()
        detailLabel.text = formatSleepDetails(quality)
        detailLabel.font = .systemFont(ofSize: 13, weight: .regular)
        detailLabel.textColor = AIONDesign.textSecondary
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(detailLabel)

        if isRTL {
            NSLayoutConstraint.activate([
                headerStack.topAnchor.constraint(equalTo: container.topAnchor),
                headerStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),

                scoreLabel.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 8),
                scoreLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),

                detailLabel.topAnchor.constraint(equalTo: scoreLabel.bottomAnchor, constant: 4),
                detailLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                detailLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
        } else {
            NSLayoutConstraint.activate([
                headerStack.topAnchor.constraint(equalTo: container.topAnchor),
                headerStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),

                scoreLabel.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 8),
                scoreLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),

                detailLabel.topAnchor.constraint(equalTo: scoreLabel.bottomAnchor, constant: 4),
                detailLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                detailLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
        }

        return container
    }

    // MARK: - Sleep Highlight Card (Apple Style)

    private func createSleepHighlightCard(highlight: SleepHighlight, isRTL: Bool) -> UIView {
        let container = UIView()

        // כותרת עם אייקון
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.spacing = 8
        headerStack.alignment = .center
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(headerStack)

        let iconView = UIImageView(image: UIImage(systemName: "moon.zzz.fill"))
        iconView.tintColor = sleepPurple
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 20).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 20).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = "sleep.highlight.title".localized
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = sleepPurple

        if isRTL {
            headerStack.addArrangedSubview(titleLabel)
            headerStack.addArrangedSubview(iconView)
        } else {
            headerStack.addArrangedSubview(iconView)
            headerStack.addArrangedSubview(titleLabel)
        }

        // טקסט תיאור (בסגנון אפל)
        let descLabel = UILabel()
        descLabel.numberOfLines = 0
        descLabel.textAlignment = isRTL ? .right : .left

        if let avgHours = highlight.value {
            let hours = Int(avgHours)
            let minutes = Int(round((avgHours - Double(hours)) * 60))
            let timeStr = isRTL ? "\(hours) שע׳ \(minutes) דק׳" : "\(hours)h \(minutes)m"
            let daysCount = highlight.dailySleepData.filter { $0.hours > 0 }.count

            if isRTL {
                descLabel.text = "ב-\(daysCount) הימים האחרונים, ממוצע שעות השינה שלך היה \(timeStr)."
            } else {
                descLabel.text = "In the last \(daysCount) days, your average sleep was \(timeStr)."
            }
        } else {
            descLabel.text = "sleep.highlight.no_data".localized
        }
        descLabel.font = .systemFont(ofSize: 15, weight: .regular)
        descLabel.textColor = AIONDesign.textPrimary
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(descLabel)

        // גרף בר-צ'ארט בסגנון אפל
        let chartContainer = createBarChart(highlight: highlight, isRTL: isRTL)
        chartContainer.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(chartContainer)

        // ממוצע וציון מספרי בצד
        let avgStack = createAverageDisplay(highlight: highlight, isRTL: isRTL)
        avgStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(avgStack)

        // מיקום - גרף בצד ימין, ממוצע בצד שמאל (תמיד - כי ככה נראה טוב יותר בעברית)
        print("📊 [SleepHighlightCard] isRTL=\(isRTL)")

        NSLayoutConstraint.activate([
            // כותרת - תמיד בצד ימין
            headerStack.topAnchor.constraint(equalTo: container.topAnchor),
            headerStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            // תיאור - מלא רוחב
            descLabel.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 12),
            descLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            descLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            // גרף - על כל הרוחב כדי שהקו יגיע מקצה לקצה
            chartContainer.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 16),
            chartContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            chartContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            chartContainer.heightAnchor.constraint(equalToConstant: 120),
            chartContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            // ממוצע - בצד שמאל, מעל הגרף
            avgStack.topAnchor.constraint(equalTo: chartContainer.topAnchor),
            avgStack.leadingAnchor.constraint(equalTo: container.leadingAnchor)
        ])

        return container
    }

    // MARK: - Bar Chart (Apple Style)

    private func createBarChart(highlight: SleepHighlight, isRTL: Bool) -> UIView {
        let container = UIView()

        // Apple Style: גובה גרף וממדים
        let chartHeight: CGFloat = 100
        let barWidth: CGFloat = 28
        let barSpacing: CGFloat = 6

        // חישוב טווח הנתונים לזום אין
        let entries = highlight.dailySleepData
        let validHours = entries.map { $0.hours }.filter { $0 > 0 }
        let actualAvg = highlight.value ?? highlight.targetHours

        // מציאת מינימום ומקסימום עם padding
        let minDataHours = validHours.min() ?? 0
        let maxDataHours = validHours.max() ?? 8

        // הגדרת טווח התצוגה - הממוצע יהיה בערך באמצע הגרף
        let range = max(maxDataHours - minDataHours, 2.0) // לפחות 2 שעות טווח
        let displayMin = max(0, minDataHours - range * 0.3)
        let displayMax = maxDataHours + range * 0.3

        // לוג לדיבוג
        print("📊 [BarChart Apple] actualAvg=\(actualAvg), range=[\(displayMin)-\(displayMax)]")

        // Stack לעמודות
        let barsStack = UIStackView()
        barsStack.axis = .horizontal
        barsStack.spacing = barSpacing
        barsStack.alignment = .bottom
        barsStack.distribution = .equalSpacing
        barsStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(barsStack)

        // Stack לימים
        let daysStack = UIStackView()
        daysStack.axis = .horizontal
        daysStack.spacing = barSpacing
        daysStack.alignment = .center
        daysStack.distribution = .equalSpacing
        daysStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(daysStack)

        for entry in entries {
            // עמודה לחיצה
            let barContainer = TappableSleepBar(entry: entry, isRTL: isRTL, parentVC: parentVC)
            barContainer.translatesAutoresizingMaskIntoConstraints = false

            let bar = UIView()
            bar.backgroundColor = entry.hours > 0 ? sleepPurpleLight : AIONDesign.textTertiary.withAlphaComponent(0.2)
            bar.layer.cornerRadius = 4
            bar.translatesAutoresizingMaskIntoConstraints = false
            bar.isUserInteractionEnabled = false
            barContainer.addSubview(bar)

            // חישוב גובה יחסי עם זום אין
            var barHeight: CGFloat = 4
            if entry.hours > 0 {
                let normalizedValue = (entry.hours - displayMin) / (displayMax - displayMin)
                barHeight = max(chartHeight * CGFloat(normalizedValue), 8)
            }
            print("📊 [BarChart Apple] \(entry.dayOfWeekShort): \(entry.hours)h → barHeight=\(barHeight)px")

            NSLayoutConstraint.activate([
                barContainer.widthAnchor.constraint(equalToConstant: barWidth),
                barContainer.heightAnchor.constraint(equalToConstant: chartHeight),

                bar.bottomAnchor.constraint(equalTo: barContainer.bottomAnchor),
                bar.leadingAnchor.constraint(equalTo: barContainer.leadingAnchor),
                bar.trailingAnchor.constraint(equalTo: barContainer.trailingAnchor),
                bar.heightAnchor.constraint(equalToConstant: barHeight)
            ])

            barsStack.addArrangedSubview(barContainer)

            // תווית יום
            let dayLabel = UILabel()
            dayLabel.text = entry.dayOfWeekShort
            dayLabel.font = .systemFont(ofSize: 11, weight: .medium)
            dayLabel.textColor = AIONDesign.textSecondary
            dayLabel.textAlignment = .center
            dayLabel.translatesAutoresizingMaskIntoConstraints = false
            dayLabel.widthAnchor.constraint(equalToConstant: barWidth).isActive = true
            daysStack.addArrangedSubview(dayLabel)
        }

        // קו הממוצע האופקי - Apple Style (עובר על כל הרוחב)
        let avgNormalized = (actualAvg - displayMin) / (displayMax - displayMin)
        let avgLineY = CGFloat(avgNormalized) * chartHeight
        print("📊 [BarChart Apple] avgLineY=\(avgLineY)px")

        let avgLine = UIView()
        avgLine.backgroundColor = targetLineColor
        avgLine.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(avgLine)

        // יישור - הגרף בצד ימין, הקו עובר מקצה לקצה
        NSLayoutConstraint.activate([
            barsStack.topAnchor.constraint(equalTo: container.topAnchor),
            barsStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            barsStack.heightAnchor.constraint(equalToConstant: chartHeight),

            daysStack.topAnchor.constraint(equalTo: barsStack.bottomAnchor, constant: 4),
            daysStack.leadingAnchor.constraint(equalTo: barsStack.leadingAnchor),
            daysStack.trailingAnchor.constraint(equalTo: barsStack.trailingAnchor),

            // הקו עובר על כל רוחב הקונטיינר - כמו באפל
            avgLine.bottomAnchor.constraint(equalTo: barsStack.bottomAnchor, constant: -avgLineY),
            avgLine.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            avgLine.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            avgLine.heightAnchor.constraint(equalToConstant: 2)
        ])

        return container
    }

    // MARK: - Average Display

    private func createAverageDisplay(highlight: SleepHighlight, isRTL: Bool) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .leading  // תמיד שמאל כי הממוצע בצד שמאל
        stack.spacing = 2

        let titleLabel = UILabel()
        titleLabel.text = "sleep.highlight.avg".localized
        titleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = AIONDesign.textSecondary
        stack.addArrangedSubview(titleLabel)

        if let avgHours = highlight.value {
            let hours = Int(avgHours)
            let minutes = Int(round((avgHours - Double(hours)) * 60))

            let hoursLabel = UILabel()
            hoursLabel.font = .systemFont(ofSize: 28, weight: .bold)
            hoursLabel.textColor = AIONDesign.textPrimary

            let attrString = NSMutableAttributedString()
            attrString.append(NSAttributedString(string: "\(hours)", attributes: [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: AIONDesign.textPrimary
            ]))
            attrString.append(NSAttributedString(string: isRTL ? "שע׳ " : "h ", attributes: [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: AIONDesign.textSecondary
            ]))
            attrString.append(NSAttributedString(string: "\(minutes)", attributes: [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: AIONDesign.textPrimary
            ]))
            attrString.append(NSAttributedString(string: isRTL ? "דק׳" : "m", attributes: [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: AIONDesign.textSecondary
            ]))

            hoursLabel.attributedText = attrString
            stack.addArrangedSubview(hoursLabel)
        } else {
            let noDataLabel = UILabel()
            noDataLabel.text = "--"
            noDataLabel.font = .systemFont(ofSize: 28, weight: .bold)
            noDataLabel.textColor = AIONDesign.textTertiary
            stack.addArrangedSubview(noDataLabel)
        }

        return stack
    }

    // MARK: - Helpers

    private func formatSleepDetails(_ quality: SleepQuality) -> String {
        let currentIsRTL = LocalizationManager.shared.currentLanguage == .hebrew
        var parts: [String] = []

        if let hours = quality.durationHours {
            let totalMins = Int(round(hours * 60))
            let h = totalMins / 60
            let m = totalMins % 60
            if currentIsRTL {
                parts.append("\(h) שע׳ \(m) דק׳")
            } else {
                parts.append("\(h)h \(m)m")
            }
        }

        if let deep = quality.deepPercent {
            if currentIsRTL {
                parts.append("עמוקה \(Int(deep))%")
            } else {
                parts.append("Deep \(Int(deep))%")
            }
        }

        if let rem = quality.remPercent {
            parts.append("REM \(Int(rem))%")
        }

        return parts.joined(separator: " | ")
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
