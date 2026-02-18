//
//  SceneDelegate.swift
//  Health Reporter
//
//  Created by Rani Ophir on 24/01/2026.
//

import UIKit
import UserNotifications
import FirebaseAuth
import GoogleSignIn

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        window = UIWindow(windowScene: windowScene)
        window?.overrideUserInterfaceStyle = .dark
        setRootByAuth()
        window?.makeKeyAndVisible()
    }

    func setRootByAuth() {
        let root: UIViewController
        if let user = Auth.auth().currentUser {
            // User logged in - show Splash Screen that will load data then transition to Main
            root = SplashViewController()

            // Analytics: Set user ID and language for returning users
            AnalyticsService.shared.setUserId(user.uid)
            AnalyticsService.shared.setLanguage(LocalizationManager.shared.currentLanguage.rawValue)
        } else {
            root = LoginViewController()
            // Analytics: Clear user ID for logged out state
            AnalyticsService.shared.setUserId(nil)
        }
        window?.rootViewController = root
    }

    func showLogin() {
        setRootByAuth()
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }

        // Handle aion:// deep links (e.g. aion://profile/uid123)
        if url.scheme == "aion" {
            handleDeepLink(url)
            return
        }

        _ = GIDSignIn.sharedInstance.handle(url)
    }

    // Handle Universal Links (https://aionapp.co/profile/{uid})
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else { return }
        handleDeepLink(url)
    }

    /// Parse deep link URL and navigate to the appropriate screen.
    /// Supports both aion://profile/{uid} and https://aionapp.co/profile/{uid}
    private func handleDeepLink(_ url: URL) {
        // Extract uid from path: /profile/{uid}
        let components = url.pathComponents  // e.g. ["/", "profile", "abc123"]
        guard components.count >= 3,
              components[1] == "profile" else {
            // For custom URL scheme: host is "profile", uid is in pathComponents
            if url.scheme == "aion", url.host == "profile",
               let uid = url.pathComponents.last, uid.count > 5 {
                postOpenProfile(uid: uid)
            }
            return
        }

        let uid = components[2]
        guard uid.count > 5 else { return }
        postOpenProfile(uid: uid)
    }

    private func postOpenProfile(uid: String) {
        NotificationCenter.default.post(
            name: NSNotification.Name("OpenUserProfile"),
            object: nil,
            userInfo: ["uid": uid]
        )
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Clear the app icon badge whenever the app becomes active
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Refresh pending notification content with fresh data.
        // If the user opens the app shortly before notification time,
        // the notification will have the freshest possible data.
        if MorningNotificationManager.shared.isEnabled {
            MorningNotificationManager.shared.refreshPendingNotification()
        }
        if BedtimeNotificationManager.shared.isEnabled {
            BedtimeNotificationManager.shared.refreshPendingNotification()
        }
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.

        // Save changes in the application's managed object context when the application transitions to the background.
        (UIApplication.shared.delegate as? AppDelegate)?.saveContext()
    }


}

