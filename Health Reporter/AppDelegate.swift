//
//  AppDelegate.swift
//  Health Reporter
//
//  Created by Rani Ophir on 24/01/2026.
//

import UIKit
import CoreData
import FirebaseCore
import FirebaseAuth
import FirebaseMessaging
import UserNotifications
import WatchConnectivity

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()

        // Setup Push Notifications
        setupPushNotifications(application: application)

        // Register Background Tasks
        MorningNotificationManager.shared.registerBackgroundTask()
        BedtimeNotificationManager.shared.registerBackgroundTask()

        // Schedule morning notification if enabled
        if MorningNotificationManager.shared.isEnabled {
            MorningNotificationManager.shared.scheduleMorningNotification()
        }

        // Schedule bedtime notification if enabled
        if BedtimeNotificationManager.shared.isEnabled {
            BedtimeNotificationManager.shared.scheduleBedtimeNotification()
        }

        // Sync notification settings to Firestore (for Cloud Functions)
        MorningNotificationManager.shared.syncSettingsOnLaunch()
        BedtimeNotificationManager.shared.syncSettingsOnLaunch()

        // Initialize Watch Connectivity
        _ = WatchConnectivityManager.shared
        print("WatchConnectivity: Initialized in AppDelegate")

        // Always register for remote notifications to ensure APNS token is available.
        // This triggers didRegisterForRemoteNotificationsWithDeviceToken which then refreshes the FCM token.
        // Safe to call multiple times - iOS ignores if already registered.
        application.registerForRemoteNotifications()
        print("[FCM] App launch: called registerForRemoteNotifications to ensure APNS token")

        if Auth.auth().currentUser != nil {
            print("[FCM] App launch: user logged in, FCM token will refresh after APNS token arrives")
        } else {
            print("[FCM] App launch: no user logged in, skipping FCM refresh")
        }

        return true
    }

    // MARK: - Push Notifications Setup

    private func setupPushNotifications(application: UIApplication) {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        // Check if user has already completed onboarding (returning user)
        // If so, request permissions now. Otherwise, onboarding will handle it.
        if OnboardingManager.hasCompletedOnboarding() {
            requestNotificationPermissions(application: application)
        } else {
            // For new users, just register without requesting permissions
            // Onboarding will handle the permission request
            print("🔔 [AppDelegate] Skipping notification permission request - onboarding will handle it")
        }
    }

    /// Request notification permissions - can be called from onboarding or for returning users.
    /// Checks current authorization status first to handle denied/already-authorized states.
    func requestNotificationPermissions(application: UIApplication? = nil) {
        let app = application ?? UIApplication.shared

        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                // First time — show system prompt
                let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
                UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
                    if let error = error {
                        print("[FCM] ❌ Notification permission request error: \(error.localizedDescription)")
                        return
                    }
                    print("[FCM] Notification permission: granted=\(granted) (must be true to get FCM token)")
                    DispatchQueue.main.async {
                        app.registerForRemoteNotifications()
                        if granted {
                            MorningNotificationManager.shared.scheduleMorningNotification()
                            if BedtimeNotificationManager.shared.isEnabled {
                                BedtimeNotificationManager.shared.scheduleBedtimeNotification()
                            }
                        }
                    }
                }

            case .denied:
                print("[FCM] ❌ Notification permission DENIED - user must enable in Settings to get token")
                DispatchQueue.main.async {
                    self?.showNotificationDeniedAlert()
                }

            case .authorized, .provisional, .ephemeral:
                print("[FCM] Notification already authorized, registering for remote notifications")
                DispatchQueue.main.async {
                    app.registerForRemoteNotifications()
                }

            @unknown default:
                break
            }
        }
    }

    /// Shows an alert explaining that notifications are disabled, with a button to open Settings.
    private func showNotificationDeniedAlert() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        let alert = UIAlertController(
            title: "notifications.denied.title".localized,
            message: "notifications.denied.message".localized,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "notifications.denied.openSettings".localized, style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })

        alert.addAction(UIAlertAction(title: "notifications.denied.later".localized, style: .cancel))

        // Present from the topmost VC
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        topVC.present(alert, animated: true)
    }

    // MARK: - Remote Notification Registration

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        print("[FCM] ✅ APNs device token received - FCM will now be able to get a token")

        // Now that APNS token is set, safe to request FCM token for logged-in users.
        // This fixes the "No APNS token specified before fetching FCM Token" (code 505) error.
        if Auth.auth().currentUser != nil {
            print("[FCM] APNS token ready + user logged in → refreshing FCM token now")
            FriendsFirestoreSync.refreshAndSaveFCMToken()
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[FCM] ❌ APNs registration FAILED: \(error.localizedDescription) (e.g. Simulator has no push - use real device)")
    }

    // MARK: - Silent Push (Cloud Function triggers)

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        if let type = userInfo["type"] as? String {
            switch type {
            case "morning_health_trigger":
                MorningNotificationManager.shared.handleMorningTrigger { success in
                    completionHandler(success ? .newData : .failed)
                }
            case "bedtime_trigger":
                BedtimeNotificationManager.shared.handleBedtimeTrigger { success in
                    completionHandler(success ? .newData : .failed)
                }
            default:
                completionHandler(.noData)
            }
        } else {
            completionHandler(.noData)
        }
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentContainer(name: "Health_Reporter")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                 
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        print("Notification received in foreground: \(userInfo)")

        // Show notification banner even when app is in foreground
        completionHandler([[.banner, .badge, .sound]])
    }

    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("Notification tapped: \(userInfo)")

        // Handle navigation based on notification type
        if let type = userInfo["type"] as? String {
            handleNotificationAction(type: type, userInfo: userInfo)
        }

        completionHandler()
    }

    private func handleNotificationAction(type: String, userInfo: [AnyHashable: Any]) {
        // Post notification to navigate to the appropriate screen
        switch type {
        case "friend_request_received", "friend_request_accepted",
             "follow_request_received", "follow_request_accepted",
             "new_follower":
            NotificationCenter.default.post(
                name: NSNotification.Name("OpenSocialHub"),
                object: nil,
                userInfo: userInfo as? [String: Any]
            )
        case "morning_health", "bedtime_recommendation":
            // Navigate to home/insights on tap
            break
        default:
            break
        }
    }
}

// MARK: - MessagingDelegate

extension AppDelegate: MessagingDelegate {

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        if let token = fcmToken, !token.isEmpty {
            print("[FCM] didReceiveRegistrationToken: got token, length \(token.count)")
        } else {
            print("[FCM] ❌ didReceiveRegistrationToken: token is nil or empty - push may not work")
            return
        }
        let token = fcmToken!

        guard Auth.auth().currentUser != nil else {
            print("[FCM] ⚠️ Token received but user NOT logged in - token NOT saved. Will save after login.")
            return
        }

        FriendsFirestoreSync.saveFCMToken(token) { error in
            if let error = error {
                print("[FCM] ❌ didReceiveRegistrationToken save failed: \(error.localizedDescription)")
            } else {
                print("[FCM] ✅ didReceiveRegistrationToken: token saved to Firestore")
            }
        }
    }
}
