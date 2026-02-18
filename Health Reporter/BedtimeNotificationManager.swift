//
//  BedtimeNotificationManager.swift
//  Health Reporter
//
//  Manages daily bedtime recommendation notifications.
//
//  Architecture: ONE calendar-triggered notification per day.
//  BGTask, Cloud Function, and foreground entry only REFRESH the pending
//  notification's content — they never send a separate notification.
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
        static let sleepGoalHours = "bedtimeNotification.sleepGoalHours"
    }

    // MARK: - Properties

    var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Keys.enabled) == nil {
                return false  // Opt-in only
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
            return hour == 0 && UserDefaults.standard.object(forKey: Keys.hour) == nil ? 19 : hour
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

    var sleepGoalHours: Double {
        get {
            let val = UserDefaults.standard.double(forKey: Keys.sleepGoalHours)
            return val > 0 ? val : 7.5
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.sleepGoalHours)
            syncSettingsToFirestore()
        }
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

    // MARK: - Schedule / Cancel

    func scheduleBedtimeNotification() {
        guard isEnabled else {
            print("🌙 [BedtimeNotification] Disabled, skipping schedule")
            return
        }

        cancelBedtimeNotification()

        // Build content from cache and schedule the single calendar notification
        let content = buildContentFromCache()
        NotificationScheduler.scheduleCalendarNotification(
            identifier: notificationIdentifier,
            content: content,
            hour: notificationHour,
            minute: notificationMinute,
            repeats: true
        ) { error in
            if let error = error {
                print("🌙 [BedtimeNotification] Failed to schedule: \(error)")
            } else {
                print("🌙 [BedtimeNotification] ✅ Scheduled for \(self.formattedTime) daily")
            }
        }

        scheduleBackgroundRefresh()
    }

    func cancelBedtimeNotification() {
        NotificationScheduler.cancelAll(identifier: notificationIdentifier)
        NotificationScheduler.cleanupLegacyNotifications(prefix: notificationIdentifier)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
        print("🌙 [BedtimeNotification] Cancelled")
    }

    // MARK: - Refresh Pending Notification

    /// Calls Gemini for a fresh recommendation and replaces the pending notification content.
    /// Does NOT send a new notification — only updates the pending one.
    func refreshPendingNotification(completion: ((Bool) -> Void)? = nil) {
        guard isEnabled else {
            completion?(false)
            return
        }

        BedtimeRecommendationService.shared.generateRecommendation { [weak self] recommendation, error in
            guard let self = self else {
                completion?(false)
                return
            }

            let content: UNMutableNotificationContent
            if let recommendation = recommendation {
                print("🌙 [BedtimeNotification] Gemini OK: bedtime=\(recommendation.recommendedBedtimeLocal)")
                content = self.buildContent(from: recommendation)
            } else {
                print("🌙 [BedtimeNotification] Gemini failed: \(error?.localizedDescription ?? "unknown"), using cache")
                content = self.buildContentFromCache()
            }

            NotificationScheduler.scheduleCalendarNotification(
                identifier: self.notificationIdentifier,
                content: content,
                hour: self.notificationHour,
                minute: self.notificationMinute,
                repeats: true
            ) { error in
                if let error = error {
                    print("🌙 [BedtimeNotification] Failed to refresh: \(error)")
                    completion?(false)
                } else {
                    print("🌙 [BedtimeNotification] ✅ Refreshed with fresh data")
                    completion?(true)
                }
            }
        }
    }

    // MARK: - Background Refresh

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

    private func nextRefreshDate() -> Date? {
        let calendar = Calendar.current
        var notifComponents = DateComponents()
        notifComponents.hour = notificationHour
        notifComponents.minute = notificationMinute

        guard let nextNotifTime = calendar.nextDate(
            after: Date(),
            matching: notifComponents,
            matchingPolicy: .nextTime
        ) else { return nil }

        return calendar.date(byAdding: .minute, value: -30, to: nextNotifTime)
    }

    private func handleBedtimeRefresh(task: BGAppRefreshTask) {
        print("🌙 [BedtimeNotification] Background refresh started")
        scheduleBackgroundRefresh()

        task.expirationHandler = {
            print("🌙 [BedtimeNotification] Background task expired")
            task.setTaskCompleted(success: false)
        }

        refreshPendingNotification { success in
            task.setTaskCompleted(success: success)
        }
    }

    // MARK: - Content Building

    private func buildContent(from recommendation: BedtimeRecommendation) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.userInfo = ["type": "bedtime_recommendation"]

        let isHebrew = LocalizationManager.shared.currentLanguage == .hebrew
        content.title = buildGreetingTitle()
        content.body = isHebrew ? recommendation.notification.body_he : recommendation.notification.body_en

        return content
    }

    private func buildContentFromCache() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.userInfo = ["type": "bedtime_recommendation"]

        content.title = buildGreetingTitle()

        if let cached = AnalysisCache.loadBedtimeRecommendation() {
            let isHebrew = LocalizationManager.shared.currentLanguage == .hebrew
            content.body = isHebrew ? cached.notification.body_he : cached.notification.body_en
        } else {
            content.body = "bedtime.notification.generic".localized
        }

        return content
    }

    private func buildGreetingTitle() -> String {
        let userName = getUserFirstName()
        if let name = userName, !name.isEmpty {
            return String(format: "bedtime.notification.title".localized, name)
        } else {
            return "bedtime.notification.title.noname".localized
        }
    }

    // MARK: - Helpers

    private func getUserFirstName() -> String? {
        guard let displayName = Auth.auth().currentUser?.displayName else { return nil }
        return displayName.components(separatedBy: " ").first
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
        print("🌙 [BedtimeNotification] ===== TEST NOTIFICATION START =====")
        print("🌙 [BedtimeNotification] Calling Gemini for fresh recommendation...")

        BedtimeRecommendationService.shared.generateRecommendation { [weak self] recommendation, error in
            guard let self = self else { return }

            let content: UNMutableNotificationContent
            if let recommendation = recommendation {
                print("🌙 [BedtimeNotification] ✅ Gemini returned: \(recommendation.recommendedBedtimeLocal)")
                content = self.buildContent(from: recommendation)

                // Save full Gemini data to Firestore
                let isHebrew = LocalizationManager.shared.currentLanguage == .hebrew
                let geminiTitle = isHebrew ? recommendation.notification.title_he : recommendation.notification.title_en
                let geminiBody = isHebrew ? recommendation.notification.body_he : recommendation.notification.body_en

                FriendsFirestoreSync.saveNotificationItem(
                    type: "bedtime_recommendation",
                    title: content.title,
                    body: content.body,
                    data: [
                        "fullTitle": geminiTitle,
                        "fullBody": geminiBody,
                        "recommendedBedtime": recommendation.recommendedBedtimeLocal,
                        "sleepNeedMinutes": recommendation.sleepNeedTonightMinutes
                    ]
                )
            } else {
                print("🌙 [BedtimeNotification] ❌ Gemini failed: \(error?.localizedDescription ?? "unknown")")
                content = self.buildBasicTestContent()

                FriendsFirestoreSync.saveNotificationItem(
                    type: "bedtime_recommendation",
                    title: content.title,
                    body: content.body,
                    data: ["fullTitle": content.title, "fullBody": content.body]
                )
            }

            // Send test in 3 seconds (separate identifier)
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
                    print("🌙 [BedtimeNotification] ✅ Test notification scheduled (3 seconds)")
                }
            }
        }
    }

    private func buildBasicTestContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = buildGreetingTitle()
        content.body = "bedtime.notification.generic".localized
        content.sound = .default
        content.userInfo = ["type": "bedtime_recommendation"]
        return content
    }
}
