//
//  MainTabBarController.swift
//  Health Reporter
//
//  טאב בר ראשי – מסך ראשי חדש (InsightsDashboard), ביצועים (סיכום+פעילות+מגמות), Insights, Social, Profile.
//

import UIKit
import HealthKit
import FirebaseAuth
import UserNotifications

final class MainTabBarController: UITabBarController {

    private var socialNavController: UINavigationController?

    override func viewDidLoad() {
        super.viewDidLoad()
        requestHealthKitAuthorizationUpfront()
        configureLiquidGlassTabBar()
        configureSemanticContentAttribute()
        syncCurrentUserProfile()
        tabBar.tintColor = AIONDesign.accentPrimary
        tabBar.unselectedItemTintColor = AIONDesign.textTertiary

        // מסך ראשי חדש – משמעות ולא נתונים גולמיים
        let home = InsightsDashboardViewController()
        home.tabBarItem = UITabBarItem(title: "tab.dashboard".localized, image: UIImage(systemName: "square.grid.2x2"), tag: 0)

        // ביצועים: סיכום (דשבורד ישן) + פעילות + מגמות
        let unified = UnifiedTrendsActivityViewController()
        unified.tabBarItem = UITabBarItem(title: "tab.unified".localized, image: UIImage(systemName: "figure.run"), tag: 1)

        let insights = InsightsTabViewController()
        insights.tabBarItem = UITabBarItem(title: "tab.insights".localized, image: UIImage(systemName: "sparkles"), tag: 2)

        let social = SocialHubViewController()
        social.tabBarItem = UITabBarItem(title: "tab.social".localized, image: UIImage(systemName: "person.2"), tag: 3)

        let profile = ProfileViewController()
        profile.tabBarItem = UITabBarItem(title: "tab.profile".localized, image: UIImage(systemName: "person.circle"), tag: 4)

        let socialNav = UINavigationController(rootViewController: social)
        socialNavController = socialNav

        viewControllers = [
            UINavigationController(rootViewController: home),
            UINavigationController(rootViewController: unified),
            UINavigationController(rootViewController: insights),
            socialNav,
            UINavigationController(rootViewController: profile),
        ]

        for nav in viewControllers as? [UINavigationController] ?? [] {
            configureNavigationBar(nav.navigationBar)
        }

        // Listen for background color changes
        NotificationCenter.default.addObserver(self, selector: #selector(backgroundColorDidChange), name: .backgroundColorChanged, object: nil)

        // Listen for notification to open Social Hub
        NotificationCenter.default.addObserver(self, selector: #selector(handleOpenSocialHub(_:)), name: NSNotification.Name("OpenSocialHub"), object: nil)

        // Update social tab badge on launch
        updateSocialTabBadge()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Deep Linking

    @objc private func handleOpenSocialHub(_ notification: Notification) {
        // Switch to Social tab (index 3)
        selectedIndex = 3

        // Pop to root in case we're deep in navigation
        socialNavController?.popToRootViewController(animated: false)

        // If this is a friend request notification, switch to the requests segment
        if let userInfo = notification.userInfo,
           let type = userInfo["type"] as? String,
           type == "friend_request_received" {
            // Give the view controller time to load, then switch to requests segment
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                if let socialVC = self?.socialNavController?.viewControllers.first as? SocialHubViewController {
                    socialVC.switchToRequestsSegment()
                }
            }
        }
    }

    // MARK: - Badge Management

    /// עדכון badge בטאב Social לפי מספר הבקשות הממתינות
    func updateSocialTabBadge() {
        FriendsFirestoreSync.fetchPendingRequestsCount { [weak self] count in
            DispatchQueue.main.async {
                if count > 0 {
                    self?.socialNavController?.tabBarItem.badgeValue = "\(count)"
                } else {
                    self?.socialNavController?.tabBarItem.badgeValue = nil
                }

                // Update app icon badge
                UNUserNotificationCenter.current().setBadgeCount(count) { _ in }
            }
        }
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

    /// הגדרת כיוון סמנטי (RTL/LTR) לפי שפת המערכת
    private func configureSemanticContentAttribute() {
        let isRTL = UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft
        let semanticAttribute: UISemanticContentAttribute = isRTL ? .forceRightToLeft : .forceLeftToRight

        // הגדרת כיוון לטאב בר
        tabBar.semanticContentAttribute = semanticAttribute
        view.semanticContentAttribute = semanticAttribute

        // הגדרת כיוון לכל ה-navigation controllers
        for nav in viewControllers as? [UINavigationController] ?? [] {
            nav.view.semanticContentAttribute = semanticAttribute
            nav.navigationBar.semanticContentAttribute = semanticAttribute
        }
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
