//
//  MainTabBarController.swift
//  Health Reporter
//
//  Main tab bar – new main screen (InsightsDashboard), Performance (summary+activity+trends), Insights, Social, Profile.
//

import UIKit
import HealthKit
import FirebaseAuth
import UserNotifications

final class MainTabBarController: UITabBarController {

    private var socialNavController: UINavigationController?
    private var dashboardNavController: UINavigationController?
    private var profileNavController: UINavigationController?

    override func viewDidLoad() {
        super.viewDidLoad()
        requestHealthKitAuthorizationUpfront()
        configureLiquidGlassTabBar()
        configureSemanticContentAttribute()
        syncCurrentUserProfile()
        tabBar.tintColor = AIONDesign.accentPrimary
        tabBar.unselectedItemTintColor = AIONDesign.textTertiary

        let home = InsightsDashboardViewController()
        home.tabBarItem = UITabBarItem(title: "tab.dashboard".localized, image: UIImage(systemName: "square.grid.2x2"), tag: 0)

        let unified = UnifiedTrendsActivityViewController()
        unified.tabBarItem = UITabBarItem(title: "tab.unified".localized, image: UIImage(systemName: "figure.run"), tag: 1)

        let insights = InsightsTabViewController()
        insights.tabBarItem = UITabBarItem(title: "tab.insights".localized, image: UIImage(systemName: "sparkles"), tag: 2)

        let social = SocialHubViewController()
        social.tabBarItem = UITabBarItem(title: "tab.social".localized, image: UIImage(systemName: "person.2"), tag: 3)

        let profile = ProfileViewController()
        profile.tabBarItem = UITabBarItem(title: "tab.profile".localized, image: UIImage(systemName: "person.circle"), tag: 4)

        let homeNav = UINavigationController(rootViewController: home)
        dashboardNavController = homeNav

        let socialNav = UINavigationController(rootViewController: social)
        socialNavController = socialNav

        let profileNav = UINavigationController(rootViewController: profile)
        profileNavController = profileNav

        viewControllers = [
            homeNav,
            UINavigationController(rootViewController: unified),
            UINavigationController(rootViewController: insights),
            socialNav,
            profileNav,
        ]

        for nav in viewControllers as? [UINavigationController] ?? [] {
            configureNavigationBar(nav.navigationBar)
        }

        // Listen for background color changes
        NotificationCenter.default.addObserver(self, selector: #selector(backgroundColorDidChange), name: .backgroundColorChanged, object: nil)

        // Listen for notification to open Social Hub
        NotificationCenter.default.addObserver(self, selector: #selector(handleOpenSocialHub(_:)), name: NSNotification.Name("OpenSocialHub"), object: nil)

        // Listen for notification to open Notifications Center (morning/bedtime tap)
        NotificationCenter.default.addObserver(self, selector: #selector(handleOpenNotificationsCenter), name: NSNotification.Name("OpenNotificationsCenter"), object: nil)

        // Refresh app icon badge when a new notification is saved
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotificationItemSaved), name: NSNotification.Name("NotificationItemSaved"), object: nil)

        // Update follow request badges on launch
        updateFollowRequestBadge()

        // Fallback: prompt users who skipped notifications during onboarding
        checkNotificationPermissionFallback()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Deep Linking

    @objc private func handleOpenSocialHub(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let type = userInfo["type"] as? String,
           (type == "friend_request_received" || type == "follow_request_received") {
            // Show Social tab for follow requests
            selectedIndex = 3
            socialNavController?.popToRootViewController(animated: false)
        } else {
            // Switch to Social tab
            selectedIndex = 3
            socialNavController?.popToRootViewController(animated: false)
        }
    }

    // MARK: - Deep Link: Notifications Center

    @objc private func handleOpenNotificationsCenter() {
        // Switch to home tab
        selectedIndex = 0
        dashboardNavController?.popToRootViewController(animated: false)

        // Present notifications center
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            // Avoid presenting if something is already presented
            if self.presentedViewController != nil { return }
            let vc = NotificationsCenterViewController()
            vc.delegate = self
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .formSheet
            self.present(nav, animated: true)
        }
    }

    // MARK: - Badge Management

    @objc private func handleNotificationItemSaved() {
        updateFollowRequestBadge()
    }

    /// Update app icon badge
    func updateFollowRequestBadge() {
        FriendsFirestoreSync.fetchUnreadNotificationsCount { count in
            DispatchQueue.main.async {
                UNUserNotificationCenter.current().setBadgeCount(count) { _ in }
            }
        }
    }

    /// Backward compatibility alias
    func updateSocialTabBadge() {
        updateFollowRequestBadge()
    }

    // MARK: - Notification Permission Fallback

    /// For users who skipped notifications during onboarding, re-prompt after a delay.
    /// Throttled to once per 7 days to avoid being annoying.
    private func checkNotificationPermissionFallback() {
        let lastPromptKey = "lastNotificationPromptDate"
        let lastPrompt = UserDefaults.standard.object(forKey: lastPromptKey) as? Date ?? .distantPast
        let daysSinceLastPrompt = Calendar.current.dateComponents([.day], from: lastPrompt, to: Date()).day ?? 999

        guard daysSinceLastPrompt >= 7 else { return }

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }

            // User has never decided — prompt after short delay so the UI is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                UserDefaults.standard.set(Date(), forKey: lastPromptKey)
                (UIApplication.shared.delegate as? AppDelegate)?.requestNotificationPermissions()
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

    /// Liquid Glass styling for tab bar (iOS 26): default background, transparency, no full background override.
    private func configureLiquidGlassTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.isTranslucent = true
    }

    /// Set semantic direction (RTL/LTR) based on system language
    private func configureSemanticContentAttribute() {
        let isRTL = UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft
        let semanticAttribute: UISemanticContentAttribute = isRTL ? .forceRightToLeft : .forceLeftToRight

        // Set direction for tab bar
        tabBar.semanticContentAttribute = semanticAttribute
        view.semanticContentAttribute = semanticAttribute

        // Set direction for all navigation controllers
        for nav in viewControllers as? [UINavigationController] ?? [] {
            nav.view.semanticContentAttribute = semanticAttribute
            nav.navigationBar.semanticContentAttribute = semanticAttribute
        }
    }

    /// Requests all HealthKit permissions upfront – sleep, temperature, activity, nutrition, heart, respiration, etc.
    private func requestHealthKitAuthorizationUpfront() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        HealthKitManager.shared.requestAuthorization { _, _ in }
    }

    /// Syncs the user's details to Firestore (so they can be searched and their photo displayed).
    /// Runs once per app launch for logged-in users.
    private func syncCurrentUserProfile() {
        guard let user = Auth.auth().currentUser else { return }

        // Sync name
        if let displayName = user.displayName, !displayName.isEmpty {
            ProfileFirestoreSync.saveDisplayName(displayName)
        }

        // Sync profile photo
        if let photoURL = user.photoURL?.absoluteString {
            ProfileFirestoreSync.savePhotoURL(photoURL)
        }
    }
}

// MARK: - NotificationsCenterViewControllerDelegate

extension MainTabBarController: NotificationsCenterViewControllerDelegate {
    func notificationsCenterDidUpdate(_ controller: NotificationsCenterViewController) {
        updateFollowRequestBadge()
    }
}
