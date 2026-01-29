//
//  MainTabBarController.swift
//  Health Reporter
//
//  טאב בר ראשי – Dashboard, Trends, Insights, Profile. עיצוב Pro Lab.
//

import UIKit
import HealthKit

final class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        requestHealthKitAuthorizationUpfront()
        configureLiquidGlassTabBar()
        tabBar.tintColor = AIONDesign.accentPrimary
        tabBar.unselectedItemTintColor = AIONDesign.textTertiary

        let dash = HealthDashboardViewController()
        dash.tabBarItem = UITabBarItem(title: "דשבורד", image: UIImage(systemName: "square.grid.2x2"), tag: 0)

        let trends = TrendsViewController()
        trends.tabBarItem = UITabBarItem(title: "מגמות", image: UIImage(systemName: "chart.line.uptrend.xyaxis"), tag: 1)

        let activity = ActivityViewController()
        activity.tabBarItem = UITabBarItem(title: "פעילות", image: UIImage(systemName: "figure.run"), tag: 2)

        let insights = InsightsTabViewController()
        insights.tabBarItem = UITabBarItem(title: "תובנות", image: UIImage(systemName: "sparkles"), tag: 3)

        let profile = ProfileViewController()
        profile.tabBarItem = UITabBarItem(title: "פרופיל", image: UIImage(systemName: "person.circle"), tag: 4)

        viewControllers = [
            UINavigationController(rootViewController: dash),
            UINavigationController(rootViewController: trends),
            UINavigationController(rootViewController: activity),
            UINavigationController(rootViewController: insights),
            UINavigationController(rootViewController: profile),
        ]

        for nav in viewControllers as? [UINavigationController] ?? [] {
            nav.navigationBar.barTintColor = AIONDesign.background
            nav.navigationBar.backgroundColor = AIONDesign.background
            nav.navigationBar.isTranslucent = false
            nav.navigationBar.titleTextAttributes = [.foregroundColor: AIONDesign.textPrimary]
            nav.navigationBar.tintColor = AIONDesign.accentPrimary
            nav.navigationBar.barStyle = .black
        }
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
}
