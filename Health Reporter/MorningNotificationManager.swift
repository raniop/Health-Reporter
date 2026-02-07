//
//  MorningNotificationManager.swift
//  Health Reporter
//
//  Manages daily morning notifications with personalized health information.
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

    // MARK: - Constants
    private let defaultStepGoal = 10000

    // MARK: - Properties

    var isEnabled: Bool {
        get {
            // Default to true (enabled) if never set
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
            // Sync to Firestore for Cloud Function
            syncSettingsToFirestore()
        }
    }

    var notificationHour: Int {
        get {
            let hour = UserDefaults.standard.integer(forKey: Keys.hour)
            return hour == 0 ? 8 : hour // Default 8:00
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.hour)
            if isEnabled { scheduleMorningNotification() }
            // Sync to Firestore for Cloud Function
            syncSettingsToFirestore()
        }
    }

    var notificationMinute: Int {
        get { UserDefaults.standard.integer(forKey: Keys.minute) }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.minute)
            if isEnabled { scheduleMorningNotification() }
            // Sync to Firestore for Cloud Function
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

    /// Last saved score (for trend calculation)
    private var lastHealthScore: Int {
        get { UserDefaults.standard.integer(forKey: Keys.lastHealthScore) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.lastHealthScore) }
    }

    /// Steps streak
    private var stepStreak: Int {
        get { UserDefaults.standard.integer(forKey: Keys.stepStreak) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.stepStreak) }
    }

    // MARK: - Formatted Time

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

    // MARK: - Schedule Notification

    func scheduleMorningNotification() {
        guard isEnabled else {
            print("🔔 [MorningNotification] Notifications disabled, skipping schedule")
            return
        }

        // Cancel existing
        cancelMorningNotification()

        // Schedule the notification directly with calendar trigger (reliable!)
        scheduleRepeatingNotification()

        // Also try to schedule BGTask for data refresh (best effort)
        scheduleBackgroundRefresh()

        print("🔔 [MorningNotification] Scheduled for \(formattedTime)")
    }

    /// Schedule a repeating daily notification at the specified time
    private func scheduleRepeatingNotification() {
        // Build notification content with cached data (will be updated if BGTask runs)
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.userInfo = ["type": "morning_health"]

        // Get user's first name for personalized greeting
        let userName = getUserFirstName()
        if let name = userName, !name.isEmpty {
            content.title = String(format: "morning.notification.title".localized, name)
        } else {
            content.title = "morning.notification.title.noname".localized
        }

        // Build body from cached data - use mainScore (daily) instead of widget healthScore (90-day)
        let mainScore = AnalysisCache.loadMainScore()
        let widgetData = WidgetDataManager.shared.loadCurrentData()
        let weeklyStats = AnalysisCache.loadWeeklyStats()
        let dailyActivity = AnalysisCache.loadDailyActivity()

        if mainScore != nil || widgetData != nil || weeklyStats != nil {
            // Priority for sleep: widgetData (last night) > weeklyStats (average)
            // Track if we're using average so we can show different text
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

            // Get yesterday's steps (separate cache - not daily activity which is today's)
            let yesterdaySteps = AnalysisCache.loadYesterdaySteps()

            // Get readiness from weekly stats (cached)
            let readinessScore: Int?
            if let r = weeklyStats?.readiness {
                readinessScore = Int(r)
            } else {
                readinessScore = nil
            }

            let bodyLines = buildBodyParts(
                healthScore: mainScore ?? widgetData?.healthScore ?? 0,
                sleepHours: sleepHours,
                isAverageSleep: isAverageSleep,
                yesterdaySteps: yesterdaySteps,
                readinessScore: readinessScore
            )
            content.body = bodyLines.isEmpty ? "morning.notification.checkin".localized : bodyLines.joined(separator: "\n")
        } else {
            content.body = "morning.notification.checkin".localized
        }

        // Create calendar trigger for the specified time (repeating daily)
        var dateComponents = DateComponents()
        dateComponents.hour = notificationHour
        dateComponents.minute = notificationMinute
        dateComponents.timeZone = .current  // Explicit timezone to prevent duplicate at wrong offset

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🔔 [MorningNotification] Failed to schedule repeating notification: \(error)")
            } else {
                print("🔔 [MorningNotification] ✅ Repeating notification scheduled for \(self.formattedTime) daily")
            }
        }
    }

    /// Build body parts for notification (simplified version for scheduling/fallback)
    /// - Parameter isAverageSleep: true if sleepHours is weekly average, false if it's last night's sleep
    private func buildBodyParts(healthScore: Int?, sleepHours: Double?, isAverageSleep: Bool = false, yesterdaySteps: Int? = nil, readinessScore: Int? = nil) -> [String] {
        var lines: [String] = []

        // Sleep (first, most important morning info)
        if includeSleep, let hours = sleepHours, hours > 0 {
            // Round up to match HealthDashboard display (same as main screen)
            let totalMinutes = Int(ceil(hours * 60))
            let hoursInt = totalMinutes / 60
            let minutes = totalMinutes % 60

            // Calculate quality based on hours
            let qualityText: String
            if hours >= 7.5 {
                qualityText = "morning.quality.high".localized
            } else if hours >= 6.5 {
                qualityText = "morning.quality.good".localized
            } else {
                qualityText = "morning.quality.low".localized
            }

            if isAverageSleep {
                // Use different string for weekly average
                lines.append(String(format: "morning.sleep.line.average".localized, hoursInt, minutes))
            } else {
                lines.append(String(format: "morning.sleep.line".localized, hoursInt, minutes, qualityText))
            }
        }

        // Recovery/Readiness (if enabled and available)
        if includeRecovery, let recovery = readinessScore, recovery > 0 {
            let readinessMessage: String
            if recovery >= 75 {
                readinessMessage = "morning.readiness.high".localized
            } else if recovery <= 50 {
                readinessMessage = "morning.readiness.low".localized
            } else {
                readinessMessage = "morning.readiness.moderate".localized
            }
            lines.append(String(format: "morning.readiness.line".localized, recovery, readinessMessage))
        }

        // Health score
        if includeScore, let score = healthScore, score > 0 {
            lines.append(String(format: "morning.score.line.value".localized, score))
        }

        // Steps (yesterday + today's goal)
        if let steps = yesterdaySteps, steps > 0 {
            let stepsFormatted = formatNumber(steps)
            let goalFormatted = formatNumber(defaultStepGoal)
            lines.append(String(format: "morning.steps.line".localized, stepsFormatted, goalFormatted))
        }

        // Closing message (dynamic based on score)
        if includeMotivation {
            let closingMessage: String
            if let score = healthScore {
                if score >= 80 {
                    closingMessage = "morning.closing.excellent".localized
                } else if score >= 60 {
                    closingMessage = "morning.closing.good".localized
                } else {
                    closingMessage = "morning.closing.rest".localized
                }
            } else {
                closingMessage = "morning.closing.good".localized
            }
            lines.append("")
            lines.append(closingMessage)
        }

        return lines
    }

    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = nextRefreshDate()

        do {
            try BGTaskScheduler.shared.submit(request)
            print("🔔 [MorningNotification] BGTask scheduled for \(nextRefreshDate()?.description ?? "nil")")
        } catch {
            print("🔔 [MorningNotification] Failed to schedule BGTask: \(error) - notification will still work with cached data")
        }
    }

    /// Next refresh date (15 minutes before notification time)
    private func nextRefreshDate() -> Date? {
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = notificationHour
        components.minute = max(0, notificationMinute - 15) // 15 minutes before

        guard let todayTarget = calendar.nextDate(
            after: Date(),
            matching: components,
            matchingPolicy: .nextTime
        ) else { return nil }

        // If the time has already passed today, schedule for tomorrow
        if todayTarget <= Date() {
            return calendar.date(byAdding: .day, value: 1, to: todayTarget)
        }

        return todayTarget
    }

    /// Next notification date
    private func nextNotificationDate() -> Date? {
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = notificationHour
        components.minute = notificationMinute

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

    private func handleMorningRefresh(task: BGAppRefreshTask) {
        print("🔔 [MorningNotification] Background refresh started")

        // Schedule next refresh
        scheduleBackgroundRefresh()

        // Set expiration handler
        task.expirationHandler = {
            print("🔔 [MorningNotification] Background task expired")
            task.setTaskCompleted(success: false)
        }

        // Fetch health data and send notification
        refreshDataAndSendNotification { success in
            task.setTaskCompleted(success: success)
        }
    }

    private func refreshDataAndSendNotification(completion: @escaping (Bool) -> Void) {
        // Fetch daily health data for scoring
        HealthKitManager.shared.fetchDailyHealthData(days: 90) { [weak self] entries in
            guard let self = self else {
                completion(false)
                return
            }

            guard !entries.isEmpty else {
                print("🔔 [MorningNotification] No health data available")
                self.sendNotificationWithCachedData()
                completion(false)
                return
            }

            // Get data from multiple sources for accuracy
            let widgetData = WidgetDataManager.shared.loadCurrentData()

            // Get TODAY's data from entries (for steps yesterday)
            let todayData = self.getTodayData(from: entries)
            let yesterdayData = self.getYesterdayData(from: entries)

            // CRITICAL: Use mainScore (daily score) NOT widgetData.healthScore (90-day average)!
            // mainScore = the daily score the user sees (54)
            // widgetData.healthScore = 90-day average score (70)
            let healthScore = AnalysisCache.loadMainScore() ?? widgetData?.healthScore ?? 0
            let sleepHours = widgetData?.sleepHours ?? todayData.sleep

            // Build and send notification with CORRECT data
            self.sendMorningNotificationWithData(
                healthScore: healthScore,
                sleepHours: sleepHours,
                readinessScore: todayData.readiness,  // Today's readiness
                yesterdaySteps: yesterdayData.steps   // Yesterday's steps
            )
            completion(true)
        }
    }

    /// Extract TODAY's data from health entries (sleep from last night, readiness)
    private func getTodayData(from entries: [RawDailyHealthEntry]) -> (sleep: Double?, readiness: Int?, steps: Int?) {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        // Find today's entry (sleep recorded today = last night's sleep)
        if let entry = entries.first(where: { calendar.isDate($0.date, inSameDayAs: todayStart) }) {
            return (
                sleep: entry.sleepHours,
                readiness: entry.readinessScore.map { Int($0) },
                steps: entry.steps.map { Int($0) }
            )
        }

        return (nil, nil, nil)
    }

    /// Extract yesterday's data from health entries (for steps)
    private func getYesterdayData(from entries: [RawDailyHealthEntry]) -> (sleep: Double?, readiness: Int?, steps: Int?) {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayStart = calendar.startOfDay(for: yesterday)

        // Find yesterday's entry
        if let entry = entries.first(where: { calendar.isDate($0.date, inSameDayAs: yesterdayStart) }) {
            return (
                sleep: entry.sleepHours,
                readiness: entry.readinessScore.map { Int($0) },
                steps: entry.steps.map { Int($0) }
            )
        }

        return (nil, nil, nil)
    }

    /// Get today's health score (mainScore = daily score, NOT 90-day average)
    private func getTodayHealthScore() -> Int? {
        // Priority: mainScore (daily) > widget healthScore (90-day average)
        return AnalysisCache.loadMainScore() ?? WidgetDataManager.shared.loadCurrentData()?.healthScore
    }

    private func sendNotificationWithCachedData() {
        // Use mainScore (daily) as priority, fallback to widget data
        let mainScore = AnalysisCache.loadMainScore()
        let widgetData = WidgetDataManager.shared.loadCurrentData()
        let weeklyStats = AnalysisCache.loadWeeklyStats()
        let dailyActivity = AnalysisCache.loadDailyActivity()

        if mainScore != nil || widgetData != nil || weeklyStats != nil {
            // Priority for sleep: widgetData (last night) > weeklyStats (average)
            // Track if we're using average so we can show different text
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

            // Get yesterday's steps (separate cache - not daily activity which is today's)
            let yesterdaySteps = AnalysisCache.loadYesterdaySteps()

            // Get readiness from weekly stats (cached)
            let readinessScore: Int?
            if let r = weeklyStats?.readiness {
                readinessScore = Int(r)
            } else {
                readinessScore = nil
            }

            let content = buildNotificationContent(
                healthScore: mainScore ?? widgetData?.healthScore ?? 0,
                recoveryScore: readinessScore,
                sleepHours: sleepHours,
                sleepQuality: nil,
                trend: nil,
                yesterdaySteps: yesterdaySteps,
                isAverageSleep: isAverageSleep
            )
            sendImmediateNotification(content: content)
        } else {
            // Send generic notification
            let content = UNMutableNotificationContent()
            content.title = "morning.notification.title.noname".localized
            content.body = "morning.notification.generic".localized
            content.sound = .default
            content.userInfo = ["type": "morning_health"]
            sendImmediateNotification(content: content)
        }
    }

    // MARK: - Send Notification

    /// Send morning notification with CORRECT data (yesterday's sleep/readiness, today's health score)
    private func sendMorningNotificationWithData(
        healthScore: Int,
        sleepHours: Double?,
        readinessScore: Int?,
        yesterdaySteps: Int?
    ) {
        // Calculate trend
        let previousScore = lastHealthScore
        let trend: String?
        if previousScore > 0 && healthScore > 0 {
            let diff = healthScore - previousScore
            if diff > 2 {
                trend = "improving"
            } else if diff < -2 {
                trend = "declining"
            } else {
                trend = "stable"
            }
        } else {
            trend = nil
        }

        // Save current score for next comparison
        lastHealthScore = healthScore

        // Calculate sleep quality based on hours (simple heuristic)
        let sleepQuality: Int?
        if let hours = sleepHours {
            if hours >= 7.5 {
                sleepQuality = 85  // Excellent
            } else if hours >= 6.5 {
                sleepQuality = 70  // Good
            } else if hours >= 5.5 {
                sleepQuality = 55  // Fair
            } else {
                sleepQuality = 40  // Poor
            }
        } else {
            sleepQuality = nil
        }

        // Build notification content with CORRECT data
        let content = buildNotificationContent(
            healthScore: healthScore,
            recoveryScore: readinessScore,
            sleepHours: sleepHours,
            sleepQuality: sleepQuality,
            trend: trend,
            yesterdaySteps: yesterdaySteps
        )

        // Send immediately
        sendImmediateNotification(content: content)
    }

    /// Legacy method - kept for compatibility
    private func sendMorningNotification(with result: HealthScoringResult, yesterdaySteps: Int? = nil) {
        // Get additional data - NOTE: These are AVERAGES, not yesterday's data!
        let recoveryScore = result.includedDomains.first { $0.domainName == "Recovery" }?.domainScore
        let sleepDomain = result.includedDomains.first { $0.domainName == "Sleep" }
        let sleepHours = sleepDomain?.usedMetrics.first?.rawValue

        // Calculate trend
        let previousScore = lastHealthScore
        let currentScore = result.healthScoreInt
        let trend: String?
        if previousScore > 0 && currentScore > 0 {
            let diff = currentScore - previousScore
            if diff > 2 {
                trend = "improving"
            } else if diff < -2 {
                trend = "declining"
            } else {
                trend = "stable"
            }
        } else {
            trend = nil
        }

        // Save current score for next comparison
        lastHealthScore = currentScore

        // Build notification content
        let content = buildNotificationContent(
            healthScore: currentScore,
            recoveryScore: recoveryScore.map { Int($0) },
            sleepHours: sleepHours,
            sleepQuality: sleepDomain.map { Int($0.domainScore) },
            trend: trend,
            yesterdaySteps: yesterdaySteps
        )

        // Send immediately (triggered by Cloud Function)
        sendImmediateNotification(content: content)
    }

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

        // Get user's first name for personalized greeting
        let userName = getUserFirstName()

        // Title with user name
        if let name = userName, !name.isEmpty {
            content.title = String(format: "morning.notification.title".localized, name)
        } else {
            content.title = "morning.notification.title.noname".localized
        }

        // Build body lines (with newlines for better readability)
        var bodyLines: [String] = []

        // 1. Sleep summary (if enabled and available) - First line, most important morning info
        if includeSleep, let hours = sleepHours, hours > 0 {
            // Round up to match HealthDashboard display (same as main screen)
            let totalMinutes = Int(ceil(hours * 60))
            let hoursInt = totalMinutes / 60
            let minutes = totalMinutes % 60

            if isAverageSleep {
                // Use different string for weekly average
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

        // 2. Recovery/Readiness (if enabled and available)
        if includeRecovery, let recovery = recoveryScore {
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

        // 3. Health score + trend (if enabled and available)
        if includeScore, let score = healthScore, score > 0 {
            if let trendValue = trend {
                switch trendValue {
                case "improving":
                    bodyLines.append(String(format: "morning.score.line.up".localized, score))
                case "declining":
                    bodyLines.append(String(format: "morning.score.line.down".localized, score))
                default:
                    bodyLines.append(String(format: "morning.score.line.stable".localized, score))
                }
            } else {
                bodyLines.append(String(format: "morning.score.line.value".localized, score))
            }
        }

        // 4. Steps (yesterday + today's goal)
        if let steps = yesterdaySteps, steps > 0 {
            let stepsFormatted = formatNumber(steps)
            let goalFormatted = formatNumber(defaultStepGoal)
            bodyLines.append(String(format: "morning.steps.line".localized, stepsFormatted, goalFormatted))
        }

        // 5. Step streak (if enabled and significant)
        if includeAchievements && stepStreak >= 3 {
            bodyLines.append(String(format: "morning.streak.line".localized, stepStreak))
        }

        // 6. Closing message (dynamic based on health score)
        if includeMotivation {
            let closingMessage: String
            if let score = healthScore {
                if score >= 80 {
                    closingMessage = "morning.closing.excellent".localized
                } else if score >= 60 {
                    closingMessage = "morning.closing.good".localized
                } else {
                    closingMessage = "morning.closing.rest".localized
                }
            } else {
                closingMessage = "morning.closing.good".localized
            }
            bodyLines.append("")  // Empty line before closing
            bodyLines.append(closingMessage)
        }

        // Join body lines with newlines
        content.body = bodyLines.joined(separator: "\n")

        return content
    }

    // MARK: - Helper Methods

    /// Get user's first name from Firebase Auth
    private func getUserFirstName() -> String? {
        guard let displayName = Auth.auth().currentUser?.displayName else {
            return nil
        }
        // Return first name only (first word before space)
        return displayName.components(separatedBy: " ").first
    }

    /// Format number with thousands separator
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    /// Send notification immediately (triggered by Cloud Function)
    private func sendImmediateNotification(content: UNMutableNotificationContent) {
        // Send in 1 second (minimal delay for reliability)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "\(notificationIdentifier)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🔔 [MorningNotification] Failed to send immediate notification: \(error)")
            } else {
                print("🔔 [MorningNotification] ✅ Immediate notification sent with fresh data!")
            }
        }
    }

    private func scheduleLocalNotification(content: UNMutableNotificationContent) {
        // Schedule for the notification time
        var dateComponents = DateComponents()
        dateComponents.hour = notificationHour
        dateComponents.minute = notificationMinute
        dateComponents.timeZone = .current  // Explicit timezone to prevent duplicate at wrong offset

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🔔 [MorningNotification] Failed to schedule: \(error)")
            } else {
                print("🔔 [MorningNotification] Notification scheduled successfully")
            }
        }
    }

    /// Schedule notification directly without background refresh (fallback)
    private func scheduleNotificationDirectly() {
        let content = UNMutableNotificationContent()
        content.title = "morning.notification.title.noname".localized
        content.body = "morning.notification.checkin".localized
        content.sound = .default
        content.userInfo = ["type": "morning_health"]

        scheduleLocalNotification(content: content)
    }

    // MARK: - Cancel Notification

    func cancelMorningNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationIdentifier]
        )
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
        print("🔔 [MorningNotification] Cancelled")
    }

    // MARK: - Update Streak

    func updateStepStreak(stepsToday: Int, stepsGoal: Int = 6000) {
        if stepsToday >= stepsGoal {
            stepStreak += 1
        } else {
            stepStreak = 0
        }
    }

    // MARK: - Firestore Sync (for Cloud Function)

    /// Syncs notification settings to Firestore so Cloud Function knows when to send
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

    /// Call this on app launch to ensure Firestore has the current settings
    func syncSettingsOnLaunch() {
        // Only sync if user is logged in (will be handled by FriendsFirestoreSync)
        syncSettingsToFirestore()
    }

    // MARK: - Handle Silent Push from Cloud Function

    /// Called when we receive a silent push from the Cloud Function
    /// This triggers fresh HealthKit data fetch and sends the local notification
    func handleMorningTrigger(completion: @escaping (Bool) -> Void) {
        print("🔔 [MorningNotification] ☁️ Received trigger from Cloud Function")

        guard isEnabled else {
            print("🔔 [MorningNotification] Notifications disabled, ignoring trigger")
            completion(false)
            return
        }

        // Fetch fresh health data
        refreshDataAndSendNotification(completion: completion)
    }

    // MARK: - Test Notification (for debugging)

    /// Send a test notification with REAL data from HealthKit (YESTERDAY's data!)
    func sendTestNotification() {
        print("🔔 [MorningNotification] Fetching real data for test notification...")

        // Fetch real health data
        HealthKitManager.shared.fetchDailyHealthData(days: 90) { [weak self] entries in
            guard let self = self else { return }

            print("🔔 [MorningNotification] Got \(entries.count) entries from HealthKit")

            if entries.isEmpty {
                // No data - send basic test
                print("🔔 [MorningNotification] No health data, sending basic test")
                self.sendBasicTestNotification()
                return
            }

            // Get data from multiple sources
            let widgetData = WidgetDataManager.shared.loadCurrentData()
            let weeklyStats = AnalysisCache.loadWeeklyStats()
            let dailyActivity = AnalysisCache.loadDailyActivity()

            // Get today's and yesterday's data from entries
            let todayData = self.getTodayData(from: entries)
            let yesterdayData = self.getYesterdayData(from: entries)

            // CRITICAL: Use mainScore (daily score) NOT widgetData.healthScore (90-day average)!
            let healthScore = AnalysisCache.loadMainScore() ?? widgetData?.healthScore ?? 0
            let sleepHours = widgetData?.sleepHours ?? todayData.sleep ?? weeklyStats?.sleepHours

            // Get readiness - prefer today's data, fallback to weekly stats
            let readinessScore: Int?
            if let todayReadiness = todayData.readiness {
                readinessScore = todayReadiness
            } else if let weeklyReadiness = weeklyStats?.readiness {
                readinessScore = Int(weeklyReadiness)
            } else {
                readinessScore = nil
            }

            // Get steps - prefer yesterday's from HealthKit, fallback to daily activity cache
            let yesterdaySteps = yesterdayData.steps ?? dailyActivity?.steps

            print("🔔 [MorningNotification] Data for test:")
            print("   - healthScore: \(healthScore)")
            print("   - sleepHours: \(sleepHours ?? 0)")
            print("   - readinessScore: \(readinessScore ?? 0)")
            print("   - yesterdaySteps: \(yesterdaySteps ?? 0)")
            print("   - widgetData sleepHours: \(widgetData?.sleepHours ?? 0)")
            print("   - weeklyStats sleepHours: \(weeklyStats?.sleepHours ?? 0)")
            print("   - weeklyStats readiness: \(weeklyStats?.readiness ?? 0)")

            // Calculate sleep quality based on hours
            let sleepQuality: Int?
            if let hours = sleepHours {
                if hours >= 7.5 {
                    sleepQuality = 85
                } else if hours >= 6.5 {
                    sleepQuality = 70
                } else if hours >= 5.5 {
                    sleepQuality = 55
                } else {
                    sleepQuality = 40
                }
            } else {
                sleepQuality = nil
            }

            // Build full notification content with CORRECT data (mainScore + widget sleep)
            let content = self.buildNotificationContent(
                healthScore: healthScore,
                recoveryScore: readinessScore,       // Today's readiness or weekly avg
                sleepHours: sleepHours,              // From widget/today/weekly
                sleepQuality: sleepQuality,
                trend: nil,  // No trend for test
                yesterdaySteps: yesterdaySteps       // Yesterday's steps
            )

            // Send in 3 seconds
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
                    print("🔔 [MorningNotification] ✅ Test notification with REAL data scheduled (3 seconds)")
                }
            }
        }
    }

    /// Basic test notification when no health data available
    private func sendBasicTestNotification() {
        let content = UNMutableNotificationContent()

        // Get user name
        let userName = getUserFirstName()
        if let name = userName, !name.isEmpty {
            content.title = String(format: "morning.notification.title".localized, name)
        } else {
            content.title = "morning.notification.title.noname".localized
        }

        content.body = "morning.notification.test".localized
        content.sound = .default
        content.userInfo = ["type": "morning_health"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(
            identifier: "morning-test-notification",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🔔 [MorningNotification] Basic test failed: \(error)")
            } else {
                print("🔔 [MorningNotification] Basic test notification scheduled (3 seconds)")
            }
        }
    }
}
