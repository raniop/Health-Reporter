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
    private var dashboardBellBadgeLabel: UILabel?

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

        // Add bell button to Dashboard nav bar
        setupDashboardBellButton(for: home)

        // Listen for background color changes
        NotificationCenter.default.addObserver(self, selector: #selector(backgroundColorDidChange), name: .backgroundColorChanged, object: nil)

        // Listen for notification to open Social Hub
        NotificationCenter.default.addObserver(self, selector: #selector(handleOpenSocialHub(_:)), name: NSNotification.Name("OpenSocialHub"), object: nil)

        // Update follow request badges on launch
        updateFollowRequestBadge()

        // Fallback: prompt users who skipped notifications during onboarding
        checkNotificationPermissionFallback()
    }

    // MARK: - Dashboard Bell Button

    private func setupDashboardBellButton(for vc: UIViewController) {
        let bellContainer = UIView(frame: CGRect(x: 0, y: 0, width: 32, height: 32))
        let bellImageView = UIImageView(image: UIImage(systemName: "bell.fill"))
        bellImageView.tintColor = AIONDesign.accentPrimary
        bellImageView.contentMode = .scaleAspectFit
        bellImageView.frame = CGRect(x: 2, y: 4, width: 24, height: 24)
        bellContainer.addSubview(bellImageView)

        let badge = UILabel()
        badge.font = .systemFont(ofSize: 10, weight: .bold)
        badge.textColor = .white
        badge.backgroundColor = AIONDesign.accentDanger
        badge.textAlignment = .center
        badge.layer.cornerRadius = 8
        badge.clipsToBounds = true
        badge.frame = CGRect(x: 18, y: 0, width: 16, height: 16)
        badge.isHidden = true
        bellContainer.addSubview(badge)
        dashboardBellBadgeLabel = badge

        let bellTap = UITapGestureRecognizer(target: self, action: #selector(dashboardBellTapped))
        bellContainer.addGestureRecognizer(bellTap)
        bellContainer.isUserInteractionEnabled = true

        let bellBarButton = UIBarButtonItem(customView: bellContainer)
        vc.navigationItem.rightBarButtonItem = bellBarButton
    }

    @objc private func dashboardBellTapped() {
        let vc = NotificationsCenterViewController()
        vc.delegate = self
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true)
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

    // MARK: - Badge Management

    /// Update bell button badges on Dashboard and Profile, plus app icon badge
    func updateFollowRequestBadge() {
        FriendsFirestoreSync.fetchUnreadNotificationsCount { [weak self] count in
            DispatchQueue.main.async {
                // Update Dashboard bell badge
                if count > 0 {
                    self?.dashboardBellBadgeLabel?.text = "\(count)"
                    self?.dashboardBellBadgeLabel?.isHidden = false
                } else {
                    self?.dashboardBellBadgeLabel?.isHidden = true
                }

                // Update app icon badge
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
