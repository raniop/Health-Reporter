//
//  MainTabBarController.swift
//  Health Reporter
//
//  Main tab bar – new main screen (InsightsDashboard), Performance (summary+activity+trends), Insights, Social, Profile.
//

import UIKit
import SwiftUI
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
        syncCurrentUserProfile()

        let home = LivityOverviewHostingController()
        home.tabBarItem = UITabBarItem(title: "tab.overview".localized, image: UIImage(systemName: "heart.fill"), tag: 0)

        let unified = LivityGoalsHostingController()
        unified.tabBarItem = UITabBarItem(title: "tab.goals".localized, image: UIImage(systemName: "target"), tag: 1)

        let insights = InsightsTabViewController()
        insights.tabBarItem = UITabBarItem(title: "tab.insights".localized, image: UIImage(systemName: "sparkles"), tag: 2)

        let social = SocialHubViewController()
        social.tabBarItem = UITabBarItem(title: "tab.social".localized, image: UIImage(systemName: "person.2"), tag: 3)

        let profile = LivityProfileHostingController()
        let profileItem = UITabBarItem(title: "tab.profile".localized, image: UIImage(systemName: "person.circle"), tag: 4)
        profile.tabBarItem = profileItem
        loadProfileTabAvatar(into: profileItem)

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

        // Tab bar appearance and the iOS 26 minimize-behavior opt-out must be applied
        // *after* viewControllers is set, otherwise the system reinitializes the tab bar
        // with default Liquid Glass behavior and the labels stay hidden until first tap.
        configureLiquidGlassTabBar()
        tabBar.tintColor = UIColor(LivityTheme.info)
        tabBar.unselectedItemTintColor = UIColor(LivityTheme.textPrimary)
        configureSemanticContentAttribute()

        // Listen for background color changes
        NotificationCenter.default.addObserver(self, selector: #selector(backgroundColorDidChange), name: .backgroundColorChanged, object: nil)

        // Listen for notification to open Social Hub
        NotificationCenter.default.addObserver(self, selector: #selector(handleOpenSocialHub(_:)), name: NSNotification.Name("OpenSocialHub"), object: nil)

        // Listen for notification to open Notifications Center (morning/bedtime tap)
        NotificationCenter.default.addObserver(self, selector: #selector(handleOpenNotificationsCenter), name: NSNotification.Name("OpenNotificationsCenter"), object: nil)

        // Listen for chat message notification tap
        NotificationCenter.default.addObserver(self, selector: #selector(handleOpenChat(_:)), name: NSNotification.Name("OpenChatFromNotification"), object: nil)

        // Listen for profile deep links (aion://profile/{uid})
        NotificationCenter.default.addObserver(self, selector: #selector(handleOpenUserProfile(_:)), name: NSNotification.Name("OpenUserProfile"), object: nil)

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

    // MARK: - Deep Link: Chat Message

    @objc private func handleOpenChat(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let chatId = userInfo["chatId"] as? String,
              let senderUid = userInfo["senderUid"] as? String else {
            print("🔔 [DeepLink] handleOpenChat — missing chatId or senderUid in userInfo")
            return
        }

        print("🔔 [DeepLink] Opening chat \(chatId) from notification, senderUid=\(senderUid)")

        // Switch to Social tab and navigate to chat
        selectedIndex = 3
        socialNavController?.popToRootViewController(animated: false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let socialNav = self?.socialNavController else { return }
            // Push chat list then open the specific chat
            let chatList = ChatListViewController()
            socialNav.pushViewController(chatList, animated: false)

            // Load the conversation and push the chat view
            ChatFirestoreSync.getOrCreateConversation(with: senderUid) { conversation, error in
                guard let conversation = conversation else { return }
                let chatVC = ChatViewController(conversation: conversation)
                socialNav.pushViewController(chatVC, animated: true)
            }
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

    // MARK: - Deep Link: User Profile

    @objc private func handleOpenUserProfile(_ notification: Notification) {
        guard let uid = notification.userInfo?["uid"] as? String else { return }
        print("🔗 [DeepLink] Opening profile for uid=\(uid)")

        // Switch to social tab and push profile
        selectedIndex = 3
        socialNavController?.popToRootViewController(animated: false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            let vc = UserProfileViewController(userUid: uid)
            self?.socialNavController?.pushViewController(vc, animated: true)
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
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.titleTextAttributes = [.foregroundColor: AIONDesign.textPrimary]
        appearance.largeTitleTextAttributes = [.foregroundColor: AIONDesign.textPrimary]

        navBar.standardAppearance = appearance
        navBar.scrollEdgeAppearance = appearance
        navBar.compactAppearance = appearance
        navBar.tintColor = UIColor.white
        navBar.barStyle = .black
    }

    /// Liquid-glass tab bar: transparent background, dark icons/labels for readability.
    private func configureLiquidGlassTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear

        let unselectedColor = UIColor(LivityTheme.textPrimary)
        let selectedColor = UIColor(LivityTheme.info)

        let stacked = appearance.stackedLayoutAppearance
        stacked.normal.iconColor = unselectedColor
        stacked.normal.titleTextAttributes = [
            .foregroundColor: unselectedColor,
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold)
        ]
        stacked.selected.iconColor = selectedColor
        stacked.selected.titleTextAttributes = [
            .foregroundColor: selectedColor,
            .font: UIFont.systemFont(ofSize: 11, weight: .bold)
        ]

        appearance.inlineLayoutAppearance = stacked
        appearance.compactInlineLayoutAppearance = stacked

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance

        // iOS 26 Liquid Glass tab bar shrinks to icons-only while a scroll view
        // scrolls — and worse, can launch in that minimized state, leaving labels
        // invisible until the user taps a tab. Opt out entirely.
        if #available(iOS 26.0, *) {
            tabBarMinimizeBehavior = .never
        }

        tabBar.setNeedsLayout()
        tabBar.layoutIfNeeded()
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

    /// Downloads the current user's profile photo (if any) and renders it into a
    /// circular template image used as the Profile tab icon. Falls back to the
    /// system `person.circle` glyph when the user has no photo.
    private func loadProfileTabAvatar(into item: UITabBarItem) {
        guard let photoURL = Auth.auth().currentUser?.photoURL else { return }
        URLSession.shared.dataTask(with: photoURL) { [weak item] data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            let avatar = MainTabBarController.makeCircularTabIcon(from: image, size: 28)
            DispatchQueue.main.async {
                item?.image = avatar
                item?.selectedImage = avatar
            }
        }.resume()
    }

    /// Renders `image` into a circular tab-bar-sized icon. Returns the image as
    /// `.alwaysOriginal` so iOS doesn't re-tint it with the active accent color.
    static func makeCircularTabIcon(from image: UIImage, size: CGFloat) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        let renderer = UIGraphicsImageRenderer(size: rect.size)
        let circular = renderer.image { _ in
            UIBezierPath(ovalIn: rect).addClip()
            // Aspect-fill crop so face stays centred.
            let aspect = image.size.width / image.size.height
            var drawRect = rect
            if aspect > 1 {
                drawRect = CGRect(x: -(size * aspect - size) / 2, y: 0,
                                  width: size * aspect, height: size)
            } else if aspect < 1 {
                drawRect = CGRect(x: 0, y: -(size / aspect - size) / 2,
                                  width: size, height: size / aspect)
            }
            image.draw(in: drawRect)
        }
        return circular.withRenderingMode(.alwaysOriginal)
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
