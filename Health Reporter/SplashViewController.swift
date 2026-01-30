import UIKit
import HealthKit

/// Splash Screen דינמי שטוען נתונים ברקע
/// מוצג במקום LaunchScreen.storyboard הסטטי ומבצע את טעינת הנתונים
class SplashViewController: UIViewController {

    // MARK: - UI Elements
    private let logoImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "LaunchLogoNew"))
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "AION"
        label.font = .boldSystemFont(ofSize: 30)
        label.textColor = .white  // תמיד לבן ב-Splash (רקע כהה קבוע)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let accentBar: UIView = {
        let view = UIView()
        view.backgroundColor = AIONDesign.accentSecondary  // טורקיז
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "דוח בריאות אישי · Performance Lab"
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = UIColor(red: 0.612, green: 0.584, blue: 0.557, alpha: 1.0)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = AIONDesign.accentSecondary
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "טוען נתונים..."
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = UIColor(red: 0.612, green: 0.584, blue: 0.557, alpha: 1.0)
        label.textAlignment = .center
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        startLoading()
    }

    // MARK: - Setup

    private func setupUI() {
        // רקע כהה כמו ב-LaunchScreen
        view.backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.118, alpha: 1.0)

        // הוספת אלמנטים
        view.addSubview(logoImageView)
        view.addSubview(titleLabel)
        view.addSubview(accentBar)
        view.addSubview(subtitleLabel)
        view.addSubview(loadingIndicator)
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            // Logo - מרכז עם offset למעלה
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -80),
            logoImageView.widthAnchor.constraint(equalToConstant: 200),
            logoImageView.heightAnchor.constraint(equalToConstant: 200),

            // Title - מתחת ללוגו
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 16),

            // Accent bar - מתחת לכותרת
            accentBar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            accentBar.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            accentBar.widthAnchor.constraint(equalToConstant: 50),
            accentBar.heightAnchor.constraint(equalToConstant: 4),

            // Subtitle - מתחת לפס
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: accentBar.bottomAnchor, constant: 16),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),

            // Loading indicator - מתחת לכל
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),

            // Status label - מתחת ל-indicator
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: loadingIndicator.bottomAnchor, constant: 12),
        ])
    }

    // MARK: - Loading

    private func startLoading() {
        // הצג loading
        loadingIndicator.startAnimating()
        UIView.animate(withDuration: 0.3) {
            self.statusLabel.alpha = 1
        }

        // בדוק אם HealthKit זמין
        guard HealthKitManager.shared.isHealthDataAvailable() else {
            transitionToMain()
            return
        }

        // בקש הרשאות HealthKit
        HealthKitManager.shared.requestAuthorization { [weak self] success, _ in
            guard let self = self else { return }

            if !success {
                // אם אין הרשאה - עבור למסך הראשי בכל זאת
                DispatchQueue.main.async {
                    self.transitionToMain()
                }
                return
            }

            // טען נתונים
            self.loadHealthData()
        }
    }

    private func loadHealthData() {
        DispatchQueue.main.async {
            self.statusLabel.text = "מסנכרן עם Apple Health..."
        }

        // טעינת נתוני בריאות
        HealthKitManager.shared.fetchAllHealthData(for: .week) { [weak self] data, _ in
            guard let self = self else { return }

            // שמור ב-cache
            HealthDataCache.shared.healthData = data

            DispatchQueue.main.async {
                self.statusLabel.text = "מעבד נתונים..."
            }

            // טעינת נתוני גרפים
            HealthKitManager.shared.fetchChartData(for: .week) { [weak self] bundle in
                guard let self = self else { return }

                // שמור ב-cache
                HealthDataCache.shared.chartBundle = bundle

                DispatchQueue.main.async {
                    self.transitionToMain()
                }
            }
        }
    }

    // MARK: - Transition

    private func transitionToMain() {
        loadingIndicator.stopAnimating()

        guard let window = view.window else {
            // Fallback אם אין window
            let main = MainTabBarController()
            if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
                sceneDelegate.window?.rootViewController = main
                sceneDelegate.window?.makeKeyAndVisible()
            }
            return
        }

        let main = MainTabBarController()

        // אנימציית מעבר חלקה
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: {
            window.rootViewController = main
        }, completion: nil)
    }
}
