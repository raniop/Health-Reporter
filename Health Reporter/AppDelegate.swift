//
//  AppDelegate.swift
//  Health Reporter
//
//  Created by Rani Ophir on 24/01/2026.
//

import UIKit
import CoreData
import FirebaseCore
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

        // Schedule morning notification if enabled
        if MorningNotificationManager.shared.isEnabled {
            MorningNotificationManager.shared.scheduleMorningNotification()
        }

        // Sync morning notification settings to Firestore (for Cloud Function)
        MorningNotificationManager.shared.syncSettingsOnLaunch()

        // Initialize Watch Connectivity
        _ = WatchConnectivityManager.shared
        print("WatchConnectivity: Initialized in AppDelegate")

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

    /// Request notification permissions - can be called from onboarding or for returning users
    func requestNotificationPermissions(application: UIApplication? = nil) {
        let app = application ?? UIApplication.shared
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
            if let error = error {
                print("Push notification authorization error: \(error)")
                return
            }
            print("Push notification permission granted: \(granted)")

            DispatchQueue.main.async {
                app.registerForRemoteNotifications()
            }
        }
    }

    // MARK: - Remote Notification Registration

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        print("APNs token registered successfully")
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
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
        case "friend_request_received", "friend_request_accepted":
            NotificationCenter.default.post(
                name: NSNotification.Name("OpenSocialHub"),
                object: nil,
                userInfo: userInfo as? [String: Any]
            )
        default:
            break
        }
    }
}

// MARK: - MessagingDelegate

extension AppDelegate: MessagingDelegate {

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else {
            print("FCM token is nil")
            return
        }
        print("FCM token received: \(token)")

        // Save token to Firestore for the current user
        FriendsFirestoreSync.saveFCMToken(token) { error in
            if let error = error {
                print("Failed to save FCM token: \(error)")
            } else {
                print("FCM token saved to Firestore")
            }
        }
    }
}
