//
//  BedtimeNotificationManager.swift
//  Health Reporter
//
//  Manages daily bedtime recommendation notifications.
//  Mirrors MorningNotificationManager pattern: local scheduling + Cloud Function trigger.
//

import Foundation
import UserNotifications
import BackgroundTasks
import FirebaseAuth

final class BedtimeNotificationManager {

    // MARK: - Singleton
    static let shared = BedtimeNotificationManager()
    private init() {}

    // MARK: - Constants
    private let taskIdentifier = "com.rani.Health-Reporter.bedtimeRefresh"
    private let notificationIdentifier = "bedtime-recommendation-notification"

    // MARK: - UserDefaults Keys
    private enum Keys {
        static let enabled = "bedtimeNotification.enabled"
        static let hour = "bedtimeNotification.hour"
        static let minute = "bedtimeNotification.minute"
    }

    // MARK: - Properties

    var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Keys.enabled) == nil {
                return false  // Default to disabled (user must opt-in)
            }
            return UserDefaults.standard.bool(forKey: Keys.enabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.enabled)
            if newValue {
                scheduleBedtimeNotification()
            } else {
                cancelBedtimeNotification()
            }
            syncSettingsToFirestore()
        }
    }

    var notificationHour: Int {
        get {
            let hour = UserDefaults.standard.integer(forKey: Keys.hour)
            return hour == 0 && UserDefaults.standard.object(forKey: Keys.hour) == nil ? 19 : hour // Default 19:00
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.hour)
            if isEnabled { scheduleBedtimeNotification() }
            syncSettingsToFirestore()
        }
    }

    var notificationMinute: Int {
        get { UserDefaults.standard.integer(forKey: Keys.minute) }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.minute)
            if isEnabled { scheduleBedtimeNotification() }
            syncSettingsToFirestore()
        }
    }

    var formattedTime: String {
        String(format: "%02d:%02d", notificationHour, notificationMinute)
    }

    // MARK: - Background Task Registration

    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handleBedtimeRefresh(task: task as! BGAppRefreshTask)
        }
        print("🌙 [BedtimeNotification] Background task registered")
    }

    // MARK: - Schedule Notification

    func scheduleBedtimeNotification() {
        guard isEnabled else {
            print("🌙 [BedtimeNotification] Notifications disabled, skipping schedule")
            return
        }

        cancelBedtimeNotification()
        scheduleRepeatingNotification()
        scheduleBackgroundRefresh()
        print("🌙 [BedtimeNotification] Scheduled for \(formattedTime)")
    }

    /// Schedule a repeating daily notification at the specified time
    private func scheduleRepeatingNotification() {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.userInfo = ["type": "bedtime_recommendation"]

        // Load cached recommendation for fallback content
        if let cached = AnalysisCache.loadBedtimeRecommendation() {
            let isHebrew = LocalizationManager.shared.currentLanguage == .hebrew
            content.title = isHebrew ? cached.notification.title_he : cached.notification.title_en
            content.body = isHebrew ? cached.notification.body_he : cached.notification.body_en
        } else {
            // Fallback: generic notification
            let userName = getUserFirstName()
            if let name = userName, !name.isEmpty {
                content.title = String(format: "bedtime.notification.title".localized, name)
            } else {
                content.title = "bedtime.notification.title.noname".localized
            }
            content.body = "bedtime.notification.generic".localized
        }

        var dateComponents = DateComponents()
        dateComponents.hour = notificationHour
        dateComponents.minute = notificationMinute
        dateComponents.timeZone = .current

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🌙 [BedtimeNotification] Failed to schedule repeating notification: \(error)")
            } else {
                print("🌙 [BedtimeNotification] Repeating notification scheduled for \(self.formattedTime) daily")
            }
        }
    }

    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = nextRefreshDate()

        do {
            try BGTaskScheduler.shared.submit(request)
            print("🌙 [BedtimeNotification] BGTask scheduled for \(nextRefreshDate()?.description ?? "nil")")
        } catch {
            print("🌙 [BedtimeNotification] Failed to schedule BGTask: \(error)")
        }
    }

    /// Next refresh date (15 minutes before notification time)
    private func nextRefreshDate() -> Date? {
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = notificationHour
        components.minute = max(0, notificationMinute - 15)

        guard let todayTarget = calendar.nextDate(
            after: Date(),
            matching: components,
            matchingPolicy: .nextTime
        ) else { return nil }

        if todayTarget <= Date() {
            return calendar.date(byAdding: .day, value: 1, to: todayTarget)
        }
        return todayTarget
    }

    // MARK: - Handle Background Refresh

    private func handleBedtimeRefresh(task: BGAppRefreshTask) {
        print("🌙 [BedtimeNotification] Background refresh started")
        scheduleBackgroundRefresh()

        task.expirationHandler = {
            print("🌙 [BedtimeNotification] Background task expired")
            task.setTaskCompleted(success: false)
        }

        fetchAndSendNotification { success in
            task.setTaskCompleted(success: success)
        }
    }

    private func fetchAndSendNotification(completion: @escaping (Bool) -> Void) {
        BedtimeRecommendationService.shared.generateRecommendation { [weak self] recommendation, error in
            guard let self = self else {
                completion(false)
                return
            }

            if let recommendation = recommendation {
                self.sendImmediateNotification(with: recommendation)
                completion(true)
            } else {
                print("🌙 [BedtimeNotification] Gemini call failed: \(error?.localizedDescription ?? "unknown")")
                self.sendNotificationWithCachedData()
                completion(false)
            }
        }
    }

    // MARK: - Send Notification

    private func sendImmediateNotification(with recommendation: BedtimeRecommendation) {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.userInfo = ["type": "bedtime_recommendation"]

        let isHebrew = LocalizationManager.shared.currentLanguage == .hebrew
        content.title = isHebrew ? recommendation.notification.title_he : recommendation.notification.title_en
        content.body = isHebrew ? recommendation.notification.body_he : recommendation.notification.body_en

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(notificationIdentifier)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🌙 [BedtimeNotification] Failed to send immediate notification: \(error)")
            } else {
                print("🌙 [BedtimeNotification] Immediate notification sent: bedtime \(recommendation.recommendedBedtimeLocal)")
            }
        }

        // Save to Firestore notification center
        FriendsFirestoreSync.saveNotificationItem(
            type: "bedtime_recommendation",
            title: content.title,
            body: content.body,
            data: [
                "fullTitle": content.title,
                "fullBody": content.body,
                "recommendedBedtime": recommendation.recommendedBedtimeLocal,
                "sleepNeedMinutes": recommendation.sleepNeedTonightMinutes
            ]
        )
    }

    private func sendNotificationWithCachedData() {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.userInfo = ["type": "bedtime_recommendation"]

        if let cached = AnalysisCache.loadBedtimeRecommendation() {
            let isHebrew = LocalizationManager.shared.currentLanguage == .hebrew
            content.title = isHebrew ? cached.notification.title_he : cached.notification.title_en
            content.body = isHebrew ? cached.notification.body_he : cached.notification.body_en
        } else {
            let userName = getUserFirstName()
            if let name = userName, !name.isEmpty {
                content.title = String(format: "bedtime.notification.title".localized, name)
            } else {
                content.title = "bedtime.notification.title.noname".localized
            }
            content.body = "bedtime.notification.generic".localized
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(notificationIdentifier)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🌙 [BedtimeNotification] Failed to send cached notification: \(error)")
            } else {
                print("🌙 [BedtimeNotification] Cached notification sent")
            }
        }

        // Save to Firestore notification center
        FriendsFirestoreSync.saveNotificationItem(
            type: "bedtime_recommendation",
            title: content.title,
            body: content.body,
            data: ["fullTitle": content.title, "fullBody": content.body]
        )
    }

    // MARK: - Cloud Function Trigger Handler

    /// Called when we receive a silent push from the Cloud Function
    func handleBedtimeTrigger(completion: @escaping (Bool) -> Void) {
        print("🌙 [BedtimeNotification] Received trigger from Cloud Function")

        guard isEnabled else {
            print("🌙 [BedtimeNotification] Notifications disabled, ignoring trigger")
            completion(false)
            return
        }

        fetchAndSendNotification(completion: completion)
    }

    // MARK: - Cancel

    func cancelBedtimeNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationIdentifier]
        )
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
        print("🌙 [BedtimeNotification] Cancelled")
    }

    // MARK: - Firestore Sync

    func syncSettingsToFirestore() {
        FriendsFirestoreSync.saveBedtimeNotificationSettings(
            enabled: isEnabled,
            hour: notificationHour,
            minute: notificationMinute
        ) { error in
            if let error = error {
                print("🌙 [BedtimeNotification] Failed to sync to Firestore: \(error)")
            } else {
                print("🌙 [BedtimeNotification] Settings synced to Firestore")
            }
        }
    }

    func syncSettingsOnLaunch() {
        syncSettingsToFirestore()
    }

    // MARK: - Test Notification

    func sendTestNotification() {
        print("🌙 [BedtimeNotification] Generating test recommendation...")

        BedtimeRecommendationService.shared.generateRecommendation { [weak self] recommendation, error in
            guard let self = self else { return }

            if let recommendation = recommendation {
                print("🌙 [BedtimeNotification] Test: bedtime \(recommendation.recommendedBedtimeLocal)")

                let content = UNMutableNotificationContent()
                content.sound = .default
                content.userInfo = ["type": "bedtime_recommendation"]

                let isHebrew = LocalizationManager.shared.currentLanguage == .hebrew
                content.title = isHebrew ? recommendation.notification.title_he : recommendation.notification.title_en
                content.body = isHebrew ? recommendation.notification.body_he : recommendation.notification.body_en

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "bedtime-test-notification-\(Date().timeIntervalSince1970)",
                    content: content,
                    trigger: trigger
                )

                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("🌙 [BedtimeNotification] Test failed: \(error)")
                    } else {
                        print("🌙 [BedtimeNotification] Test notification scheduled (3 seconds)")
                    }
                }

                // Save to Firestore notification center
                FriendsFirestoreSync.saveNotificationItem(
                    type: "bedtime_recommendation",
                    title: content.title,
                    body: content.body,
                    data: [
                        "fullTitle": content.title,
                        "fullBody": content.body,
                        "recommendedBedtime": recommendation.recommendedBedtimeLocal,
                        "sleepNeedMinutes": recommendation.sleepNeedTonightMinutes
                    ]
                )
            } else {
                print("🌙 [BedtimeNotification] Test failed - sending generic: \(error?.localizedDescription ?? "unknown")")
                self.sendBasicTestNotification()
            }
        }
    }

    private func sendBasicTestNotification() {
        let content = UNMutableNotificationContent()
        let userName = getUserFirstName()
        if let name = userName, !name.isEmpty {
            content.title = String(format: "bedtime.notification.title".localized, name)
        } else {
            content.title = "bedtime.notification.title.noname".localized
        }
        content.body = "bedtime.notification.generic".localized
        content.sound = .default
        content.userInfo = ["type": "bedtime_recommendation"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(
            identifier: "bedtime-test-notification",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🌙 [BedtimeNotification] Basic test failed: \(error)")
            } else {
                print("🌙 [BedtimeNotification] Basic test notification scheduled (3 seconds)")
            }
        }

        // Save to Firestore notification center
        FriendsFirestoreSync.saveNotificationItem(
            type: "bedtime_recommendation",
            title: content.title,
            body: content.body,
            data: ["fullTitle": content.title, "fullBody": content.body]
        )
    }

    // MARK: - Helpers

    private func getUserFirstName() -> String? {
        guard let displayName = Auth.auth().currentUser?.displayName else { return nil }
        return displayName.components(separatedBy: " ").first
    }
}
