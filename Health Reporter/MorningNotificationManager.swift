//
//  MorningNotificationManager.swift
//  Health Reporter
//
//  Manages daily morning notifications with personalized health information.
//
//  Architecture: ONE calendar-triggered notification per day.
//  BGTask, Cloud Function, and foreground entry only REFRESH the pending
//  notification's content — they never send a separate notification.
//

import Foundation
import UserNotifications
import BackgroundTasks
import FirebaseAuth

final class MorningNotificationManager {

    // MARK: - Singleton
    static let shared = MorningNotificationManager()
    private init() {}

    // MARK: - Constants
    private let taskIdentifier = "com.rani.Health-Reporter.morningRefresh"
    private let notificationIdentifier = "morning-health-notification"
    private let defaultStepGoal = 10000

    // MARK: - UserDefaults Keys
    private enum Keys {
        static let enabled = "morningNotification.enabled"
        static let hour = "morningNotification.hour"
        static let minute = "morningNotification.minute"
        static let includeRecovery = "morningNotification.includeRecovery"
        static let includeSleep = "morningNotification.includeSleep"
        static let includeScore = "morningNotification.includeScore"
        static let includeMotivation = "morningNotification.includeMotivation"
        static let includeAchievements = "morningNotification.includeAchievements"
        static let lastHealthScore = "morningNotification.lastHealthScore"
        static let stepStreak = "morningNotification.stepStreak"
        static let dailyStepGoal = "morningNotification.dailyStepGoal"
    }

    // MARK: - Properties

    var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Keys.enabled) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Keys.enabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.enabled)
            if newValue {
                scheduleMorningNotification()
            } else {
                cancelMorningNotification()
            }
            syncSettingsToFirestore()
        }
    }

    var notificationHour: Int {
        get {
            let hour = UserDefaults.standard.integer(forKey: Keys.hour)
            return hour == 0 ? 8 : hour
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.hour)
            if isEnabled { scheduleMorningNotification() }
            syncSettingsToFirestore()
        }
    }

    var notificationMinute: Int {
        get { UserDefaults.standard.integer(forKey: Keys.minute) }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.minute)
            if isEnabled { scheduleMorningNotification() }
            syncSettingsToFirestore()
        }
    }

    var includeRecovery: Bool {
        get { UserDefaults.standard.object(forKey: Keys.includeRecovery) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.includeRecovery) }
    }

    var includeSleep: Bool {
        get { UserDefaults.standard.object(forKey: Keys.includeSleep) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.includeSleep) }
    }

    var includeScore: Bool {
        get { UserDefaults.standard.object(forKey: Keys.includeScore) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.includeScore) }
    }

    var includeMotivation: Bool {
        get { UserDefaults.standard.object(forKey: Keys.includeMotivation) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.includeMotivation) }
    }

    var includeAchievements: Bool {
        get { UserDefaults.standard.object(forKey: Keys.includeAchievements) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.includeAchievements) }
    }

    private var lastHealthScore: Int {
        get { UserDefaults.standard.integer(forKey: Keys.lastHealthScore) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.lastHealthScore) }
    }

    private var stepStreak: Int {
        get { UserDefaults.standard.integer(forKey: Keys.stepStreak) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.stepStreak) }
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
            self?.handleMorningRefresh(task: task as! BGAppRefreshTask)
        }
        print("🔔 [MorningNotification] Background task registered")
    }

    // MARK: - Schedule / Cancel

    func scheduleMorningNotification() {
        guard isEnabled else {
            print("🔔 [MorningNotification] Disabled, skipping schedule")
            return
        }

        // Cancel existing (including legacy timestamp-appended ones)
        cancelMorningNotification()

        // Build content from cached data and schedule the single calendar notification
        let content = buildContentFromCache()
        NotificationScheduler.scheduleCalendarNotification(
            identifier: notificationIdentifier,
            content: content,
            hour: notificationHour,
            minute: notificationMinute,
            repeats: true
        ) { error in
            if let error = error {
                print("🔔 [MorningNotification] Failed to schedule: \(error)")
            } else {
                print("🔔 [MorningNotification] ✅ Scheduled for \(self.formattedTime) daily")
            }
        }

        // Schedule BGTask to refresh content before notification fires
        scheduleBackgroundRefresh()
    }

    func cancelMorningNotification() {
        NotificationScheduler.cancelAll(identifier: notificationIdentifier)
        NotificationScheduler.cleanupLegacyNotifications(prefix: notificationIdentifier)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
        print("🔔 [MorningNotification] Cancelled")
    }

    // MARK: - Refresh Pending Notification

    /// Fetches fresh data and replaces the pending notification content.
    /// Called from BGTask, Cloud Function silent push, and foreground entry.
    /// Does NOT send a new notification — only updates the pending one.
    func refreshPendingNotification(completion: ((Bool) -> Void)? = nil) {
        guard isEnabled else {
            completion?(false)
            return
        }

        fetchFreshDataAndBuildContent { [weak self] content in
            guard let self = self else {
                completion?(false)
                return
            }

            NotificationScheduler.scheduleCalendarNotification(
                identifier: self.notificationIdentifier,
                content: content,
                hour: self.notificationHour,
                minute: self.notificationMinute,
                repeats: true
            ) { error in
                if let error = error {
                    print("🔔 [MorningNotification] Failed to refresh: \(error)")
                    completion?(false)
                } else {
                    print("🔔 [MorningNotification] ✅ Refreshed with fresh data")
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
            print("🔔 [MorningNotification] BGTask scheduled for \(nextRefreshDate()?.description ?? "nil")")
        } catch {
            print("🔔 [MorningNotification] Failed to schedule BGTask: \(error)")
        }
    }

    /// Returns 30 minutes before the next notification time.
    /// Uses Date arithmetic (not DateComponents subtraction) to correctly handle hour boundaries.
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

    private func handleMorningRefresh(task: BGAppRefreshTask) {
        print("🔔 [MorningNotification] Background refresh started")

        // Schedule next refresh for tomorrow
        scheduleBackgroundRefresh()

        task.expirationHandler = {
            print("🔔 [MorningNotification] Background task expired")
            task.setTaskCompleted(success: false)
        }

        // Refresh the pending notification content (do NOT send a new one)
        refreshPendingNotification { success in
            task.setTaskCompleted(success: success)
        }
    }

    // MARK: - Data Fetching & Content Building

    private func fetchFreshDataAndBuildContent(completion: @escaping (UNMutableNotificationContent) -> Void) {
        HealthKitManager.shared.fetchDailyHealthData(days: 90) { [weak self] entries in
            guard let self = self else { return }

            if entries.isEmpty {
                print("🔔 [MorningNotification] No HealthKit data, using cache")
                completion(self.buildContentFromCache())
                return
            }

            let widgetData = WidgetDataManager.shared.loadCurrentData()
            let weeklyStats = AnalysisCache.loadWeeklyStats()
            let todayData = self.getTodayData(from: entries)
            let yesterdayData = self.getYesterdayData(from: entries)

            let healthScore = GeminiResultStore.loadHealthScore() ?? widgetData?.healthScore ?? 0
            let sleepHours = widgetData?.sleepHours ?? todayData.sleep

            // Calculate trend
            let previousScore = self.lastHealthScore
            var trend: String? = nil
            if previousScore > 0 && healthScore > 0 {
                let diff = healthScore - previousScore
                trend = diff > 2 ? "improving" : (diff < -2 ? "declining" : "stable")
            }
            self.lastHealthScore = healthScore

            // Readiness: prefer today's HealthKit → daily ScoreBreakdown → weekly avg
            let readinessScore: Int?
            if let todayReadiness = todayData.readiness {
                readinessScore = todayReadiness
            } else {
                let dailyRecovery = AnalysisCache.loadScoreBreakdown().recovery
                if let dr = dailyRecovery, dr > 0 {
                    readinessScore = dr
                } else if let weeklyReadiness = weeklyStats?.readiness {
                    readinessScore = Int(weeklyReadiness)
                } else {
                    readinessScore = nil
                }
            }

            // Steps: yesterday from HealthKit
            let yesterdaySteps = yesterdayData.steps ?? AnalysisCache.loadYesterdaySteps()

            let content = self.buildNotificationContent(
                healthScore: healthScore,
                recoveryScore: readinessScore,
                sleepHours: sleepHours,
                sleepQuality: self.sleepQualityFromHours(sleepHours),
                trend: trend,
                yesterdaySteps: yesterdaySteps
            )

            completion(content)
        }
    }

    /// Build notification content from cached data (used at schedule time and as fallback).
    private func buildContentFromCache() -> UNMutableNotificationContent {
        let mainScore = GeminiResultStore.loadHealthScore()
        let widgetData = WidgetDataManager.shared.loadCurrentData()
        let weeklyStats = AnalysisCache.loadWeeklyStats()

        guard mainScore != nil || widgetData != nil || weeklyStats != nil else {
            // No data at all — generic notification
            let content = UNMutableNotificationContent()
            let userName = getUserFirstName()
            if let name = userName, !name.isEmpty {
                content.title = String(format: "morning.notification.title".localized, name)
            } else {
                content.title = "morning.notification.title.noname".localized
            }
            content.body = "morning.notification.checkin".localized
            content.sound = .default
            content.userInfo = ["type": "morning_health"]
            return content
        }

        // Sleep priority: widget (last night) > weekly (average)
        let sleepHours: Double?
        let isAverageSleep: Bool
        if let widgetSleep = widgetData?.sleepHours, widgetSleep > 0 {
            sleepHours = widgetSleep
            isAverageSleep = false
        } else if let avgSleep = weeklyStats?.sleepHours, avgSleep > 0 {
            sleepHours = avgSleep
            isAverageSleep = true
        } else {
            sleepHours = nil
            isAverageSleep = false
        }

        let readinessScore: Int?
        let dailyRecovery = AnalysisCache.loadScoreBreakdown().recovery
        if let dr = dailyRecovery, dr > 0 {
            readinessScore = dr
        } else if let r = weeklyStats?.readiness {
            readinessScore = Int(r)
        } else {
            readinessScore = nil
        }

        let yesterdaySteps = AnalysisCache.loadYesterdaySteps()
        let healthScore = mainScore ?? widgetData?.healthScore ?? 0

        return buildNotificationContent(
            healthScore: healthScore,
            recoveryScore: readinessScore,
            sleepHours: sleepHours,
            sleepQuality: sleepQualityFromHours(sleepHours),
            trend: nil,
            yesterdaySteps: yesterdaySteps,
            isAverageSleep: isAverageSleep
        )
    }

    // MARK: - Notification Content Builder

    private func buildNotificationContent(
        healthScore: Int?,
        recoveryScore: Int?,
        sleepHours: Double?,
        sleepQuality: Int?,
        trend: String?,
        yesterdaySteps: Int? = nil,
        isAverageSleep: Bool = false
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.userInfo = ["type": "morning_health"]

        // Title
        let userName = getUserFirstName()
        if let name = userName, !name.isEmpty {
            content.title = String(format: "morning.notification.title".localized, name)
        } else {
            content.title = "morning.notification.title.noname".localized
        }

        var bodyLines: [String] = []

        // 1. Sleep
        if includeSleep, let hours = sleepHours, hours > 0 {
            let totalMinutes = Int(ceil(hours * 60))
            let hoursInt = totalMinutes / 60
            let minutes = totalMinutes % 60

            if isAverageSleep {
                bodyLines.append(String(format: "morning.sleep.line.average".localized, hoursInt, minutes))
            } else if let quality = sleepQuality {
                let qualityText: String
                if quality >= 80 {
                    qualityText = "morning.quality.high".localized
                } else if quality >= 60 {
                    qualityText = "morning.quality.good".localized
                } else {
                    qualityText = "morning.quality.low".localized
                }
                bodyLines.append(String(format: "morning.sleep.line".localized, hoursInt, minutes, qualityText))
            } else {
                bodyLines.append(String(format: "morning.sleep.line.short".localized, hoursInt, minutes))
            }
        }

        // 2. Recovery/Readiness
        if includeRecovery, let recovery = recoveryScore, recovery > 0 {
            let readinessMessage: String
            if recovery >= 75 {
                readinessMessage = "morning.readiness.high".localized
            } else if recovery <= 50 {
                readinessMessage = "morning.readiness.low".localized
            } else {
                readinessMessage = "morning.readiness.moderate".localized
            }
            bodyLines.append(String(format: "morning.readiness.line".localized, recovery, readinessMessage))
        }

        // 3. Health score + trend + description
        if includeScore, let score = healthScore, score > 0 {
            let scoreDesc: String
            switch score {
            case 82...100: scoreDesc = "score.description.very_high".localized
            case 65...81:  scoreDesc = "score.description.high".localized
            case 45...64:  scoreDesc = "score.description.medium".localized
            case 25...44:  scoreDesc = "score.description.low".localized
            default:       scoreDesc = "score.description.very_low".localized
            }

            if let trendValue = trend {
                switch trendValue {
                case "improving":
                    bodyLines.append(String(format: "morning.score.line.up".localized, score, scoreDesc))
                case "declining":
                    bodyLines.append(String(format: "morning.score.line.down".localized, score, scoreDesc))
                default:
                    bodyLines.append(String(format: "morning.score.line.stable".localized, score, scoreDesc))
                }
            } else {
                bodyLines.append(String(format: "morning.score.line.value".localized, score, scoreDesc))
            }
        }

        // 4. Steps
        if let steps = yesterdaySteps, steps > 0 {
            let stepsFormatted = formatNumber(steps)
            let goalFormatted = formatNumber(defaultStepGoal)
            bodyLines.append(String(format: "morning.steps.line".localized, stepsFormatted, goalFormatted))
        }

        // 5. Step streak
        if includeAchievements && stepStreak >= 3 {
            bodyLines.append(String(format: "morning.streak.line".localized, stepStreak))
        }

        // 6. Motivational closing
        if includeMotivation {
            let tier: String
            if let score = healthScore, score > 0 {
                if score >= 80 {
                    tier = "morning.closing.excellent"
                } else if score >= 60 {
                    tier = "morning.closing.good"
                } else {
                    tier = "morning.closing.rest"
                }
            } else {
                tier = "morning.closing.good"
            }
            let variant = Int.random(in: 0...4)
            let closingMessage = "\(tier).\(variant)".localized
            bodyLines.append("")
            bodyLines.append(closingMessage)
        }

        content.body = bodyLines.isEmpty ? "morning.notification.checkin".localized : bodyLines.joined(separator: "\n")
        return content
    }

    // MARK: - Helpers

    private func getUserFirstName() -> String? {
        guard let displayName = Auth.auth().currentUser?.displayName else { return nil }
        return displayName.components(separatedBy: " ").first
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    private func sleepQualityFromHours(_ hours: Double?) -> Int? {
        guard let hours = hours else { return nil }
        if hours >= 7.5 { return 85 }
        if hours >= 6.5 { return 70 }
        if hours >= 5.5 { return 55 }
        return 40
    }

    private func getTodayData(from entries: [RawDailyHealthEntry]) -> (sleep: Double?, readiness: Int?, steps: Int?) {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        if let entry = entries.first(where: { calendar.isDate($0.date, inSameDayAs: todayStart) }) {
            return (
                sleep: entry.sleepHours,
                readiness: entry.readinessScore.map { Int($0) },
                steps: entry.steps.map { Int($0) }
            )
        }
        return (nil, nil, nil)
    }

    private func getYesterdayData(from entries: [RawDailyHealthEntry]) -> (sleep: Double?, readiness: Int?, steps: Int?) {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayStart = calendar.startOfDay(for: yesterday)
        if let entry = entries.first(where: { calendar.isDate($0.date, inSameDayAs: yesterdayStart) }) {
            return (
                sleep: entry.sleepHours,
                readiness: entry.readinessScore.map { Int($0) },
                steps: entry.steps.map { Int($0) }
            )
        }
        return (nil, nil, nil)
    }

    // MARK: - Step Streak

    func updateStepStreak(stepsToday: Int, stepsGoal: Int = 6000) {
        if stepsToday >= stepsGoal {
            stepStreak += 1
        } else {
            stepStreak = 0
        }
    }

    // MARK: - Firestore Sync

    func syncSettingsToFirestore() {
        FriendsFirestoreSync.saveMorningNotificationSettings(
            enabled: isEnabled,
            hour: notificationHour,
            minute: notificationMinute
        ) { error in
            if let error = error {
                print("🔔 [MorningNotification] Failed to sync to Firestore: \(error)")
            } else {
                print("🔔 [MorningNotification] Settings synced to Firestore")
            }
        }
    }

    func syncSettingsOnLaunch() {
        syncSettingsToFirestore()
    }

    // MARK: - Test Notification

    func sendTestNotification() {
        print("🔔 [MorningNotification] Fetching data for test notification...")

        HealthKitManager.shared.fetchDailyHealthData(days: 90) { [weak self] entries in
            guard let self = self else { return }

            let content: UNMutableNotificationContent
            if entries.isEmpty {
                content = self.buildBasicTestContent()
            } else {
                let widgetData = WidgetDataManager.shared.loadCurrentData()
                let weeklyStats = AnalysisCache.loadWeeklyStats()
                let todayData = self.getTodayData(from: entries)
                let yesterdayData = self.getYesterdayData(from: entries)

                let healthScore = GeminiResultStore.loadHealthScore() ?? widgetData?.healthScore ?? 0
                let sleepHours = widgetData?.sleepHours ?? todayData.sleep ?? weeklyStats?.sleepHours

                let readinessScore: Int?
                if let todayReadiness = todayData.readiness {
                    readinessScore = todayReadiness
                } else {
                    let dailyRecovery = AnalysisCache.loadScoreBreakdown().recovery
                    if let dr = dailyRecovery, dr > 0 {
                        readinessScore = dr
                    } else if let weeklyReadiness = weeklyStats?.readiness {
                        readinessScore = Int(weeklyReadiness)
                    } else {
                        readinessScore = nil
                    }
                }

                let yesterdaySteps = yesterdayData.steps ?? AnalysisCache.loadYesterdaySteps()

                content = self.buildNotificationContent(
                    healthScore: healthScore,
                    recoveryScore: readinessScore,
                    sleepHours: sleepHours,
                    sleepQuality: self.sleepQualityFromHours(sleepHours),
                    trend: nil,
                    yesterdaySteps: yesterdaySteps
                )
            }

            // Send test in 3 seconds (separate identifier — does not affect scheduled notification)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
            let request = UNNotificationRequest(
                identifier: "morning-test-notification-\(Date().timeIntervalSince1970)",
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("🔔 [MorningNotification] Test failed: \(error)")
                } else {
                    print("🔔 [MorningNotification] ✅ Test notification scheduled (3 seconds)")
                }
            }

            // Save to Firestore
            FriendsFirestoreSync.saveNotificationItem(
                type: "morning_summary",
                title: content.title,
                body: content.body,
                data: ["fullTitle": content.title, "fullBody": content.body]
            )
        }
    }

    private func buildBasicTestContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let userName = getUserFirstName()
        if let name = userName, !name.isEmpty {
            content.title = String(format: "morning.notification.title".localized, name)
        } else {
            content.title = "morning.notification.title.noname".localized
        }
        content.body = "morning.notification.test".localized
        content.sound = .default
        content.userInfo = ["type": "morning_health"]
        return content
    }
}
