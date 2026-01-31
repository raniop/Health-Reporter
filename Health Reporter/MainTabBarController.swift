//
//  MainTabBarController.swift
//  Health Reporter
//
//  טאב בר ראשי – Dashboard, פעילות+מגמות, Insights, Social, Profile. עיצוב Pro Lab.
//

import UIKit
import HealthKit
import FirebaseAuth

final class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        requestHealthKitAuthorizationUpfront()
        configureLiquidGlassTabBar()
        syncCurrentUserProfile()
        tabBar.tintColor = AIONDesign.accentPrimary
        tabBar.unselectedItemTintColor = AIONDesign.textTertiary

        let dash = HealthDashboardViewController()
        dash.tabBarItem = UITabBarItem(title: "tab.dashboard".localized, image: UIImage(systemName: "square.grid.2x2"), tag: 0)

        // מסך משולב פעילות + מגמות
        let unified = UnifiedTrendsActivityViewController()
        unified.tabBarItem = UITabBarItem(title: "tab.unified".localized, image: UIImage(systemName: "figure.run"), tag: 1)

        let insights = InsightsTabViewController()
        insights.tabBarItem = UITabBarItem(title: "tab.insights".localized, image: UIImage(systemName: "sparkles"), tag: 2)

        let social = SocialHubViewController()
        social.tabBarItem = UITabBarItem(title: "tab.social".localized, image: UIImage(systemName: "person.2"), tag: 3)

        let profile = ProfileViewController()
        profile.tabBarItem = UITabBarItem(title: "tab.profile".localized, image: UIImage(systemName: "person.circle"), tag: 4)

        viewControllers = [
            UINavigationController(rootViewController: dash),
            UINavigationController(rootViewController: unified),
            UINavigationController(rootViewController: insights),
            UINavigationController(rootViewController: social),
            UINavigationController(rootViewController: profile),
        ]

        for nav in viewControllers as? [UINavigationController] ?? [] {
            configureNavigationBar(nav.navigationBar)
        }

        // Listen for background color changes
        NotificationCenter.default.addObserver(self, selector: #selector(backgroundColorDidChange), name: .backgroundColorChanged, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func backgroundColorDidChange() {
        for nav in viewControllers as? [UINavigationController] ?? [] {
            configureNavigationBar(nav.navigationBar)
        }
    }

    private func configureNavigationBar(_ navBar: UINavigationBar) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = AIONDesign.background
        appearance.titleTextAttributes = [.foregroundColor: AIONDesign.textPrimary]
        appearance.largeTitleTextAttributes = [.foregroundColor: AIONDesign.textPrimary]

        navBar.standardAppearance = appearance
        navBar.scrollEdgeAppearance = appearance
        navBar.compactAppearance = appearance
        navBar.tintColor = AIONDesign.accentPrimary
        navBar.barStyle = AIONDesign.navBarStyle
    }

    /// עיצוב Liquid Glass ל־tab bar (iOS 26): רקע ברירת מחדל, שקיפות, ללא דריסה של רקע מלא.
    private func configureLiquidGlassTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.isTranslucent = true
    }

    /// מבקש הרשאות HealthKit להכל מראש – שינה, טמפרטורה, פעילות, תזונה, לב, נשימה וכו׳.
    private func requestHealthKitAuthorizationUpfront() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        HealthKitManager.shared.requestAuthorization { _, _ in }
    }

    /// מסנכרן את פרטי המשתמש ל-Firestore (כדי שניתן יהיה לחפש אותו ולהציג תמונה).
    /// רץ פעם אחת בכל פתיחת אפליקציה למשתמשים מחוברים.
    private func syncCurrentUserProfile() {
        guard let user = Auth.auth().currentUser else { return }

        // סנכרון שם
        if let displayName = user.displayName, !displayName.isEmpty {
            ProfileFirestoreSync.saveDisplayName(displayName)
        }

        // סנכרון תמונת פרופיל
        if let photoURL = user.photoURL?.absoluteString {
            ProfileFirestoreSync.savePhotoURL(photoURL)
        }
    }
}
