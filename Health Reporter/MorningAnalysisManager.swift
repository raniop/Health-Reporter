//
//  MorningAnalysisManager.swift
//  Health Reporter
//
//  Runs Gemini analysis in the background via BGProcessingTask before the user
//  wakes up. When the user opens the app, the cached result is ready → instant splash.
//
//  Architecture:
//  - Uses BGProcessingTask (not BGAppRefreshTask) because Gemini calls take 15-45s.
//  - Scheduled to run early morning (default 5:00 AM, or 1 hour before morning notification).
//  - Calls AIONAnalysisOrchestrator.ensureTodayResult() which caches the result in GeminiResultStore.
//  - If the task doesn't run (iOS decides), the normal splash flow handles it as before.
//

import Foundation
import BackgroundTasks

final class MorningAnalysisManager {

    static let shared = MorningAnalysisManager()
    private init() {}

    // MARK: - Constants

    static let taskIdentifier = "com.rani.Health-Reporter.morningAnalysis"

    // MARK: - Registration (call once from AppDelegate)

    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handleAnalysisTask(task: task as! BGProcessingTask)
        }
        print("🌅 [MorningAnalysis] Background processing task registered")
    }

    // MARK: - Schedule

    /// Schedules a BGProcessingTask to run early morning.
    /// Called from AppDelegate and after each successful completion.
    func scheduleIfNeeded() {
        // Don't schedule if today's result already exists
        if let existing = GeminiResultStore.load(), Calendar.current.isDateInToday(existing.date) {
            print("🌅 [MorningAnalysis] Today's result exists — scheduling for tomorrow")
        }

        let request = BGProcessingTaskRequest(identifier: Self.taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = nextAnalysisDate()

        do {
            try BGTaskScheduler.shared.submit(request)
            print("🌅 [MorningAnalysis] ✅ Scheduled for \(nextAnalysisDate()?.description ?? "nil")")
        } catch {
            print("🌅 [MorningAnalysis] ❌ Failed to schedule: \(error)")
        }
    }

    // MARK: - Execution

    private func handleAnalysisTask(task: BGProcessingTask) {
        print("🌅 [MorningAnalysis] 🚀 Background analysis started")

        // Schedule next run for tomorrow
        scheduleIfNeeded()

        // Set expiration handler
        task.expirationHandler = {
            GeminiService.shared.cancelCurrentRequest()
            print("🌅 [MorningAnalysis] ⏰ Task expired by system")
            task.setTaskCompleted(success: false)
        }

        // Skip if today's result already cached
        if let existing = GeminiResultStore.load(), Calendar.current.isDateInToday(existing.date) {
            print("🌅 [MorningAnalysis] Today's result already cached — done")
            task.setTaskCompleted(success: true)
            return
        }

        // Run the full analysis
        AIONAnalysisOrchestrator.shared.ensureTodayResult { result, failureReason in
            if let result = result {
                print("🌅 [MorningAnalysis] ✅ Analysis complete — score: \(result.scores.healthScore ?? -1)")
                task.setTaskCompleted(success: true)
            } else {
                print("🌅 [MorningAnalysis] ❌ Analysis failed: \(failureReason.map { "\($0)" } ?? "unknown")")
                task.setTaskCompleted(success: false)
            }
        }
    }

    // MARK: - Next Run Date

    /// Returns the optimal time for the next analysis.
    /// Strategy: 1 hour before the user's morning notification, or 5:00 AM by default.
    private func nextAnalysisDate() -> Date? {
        let calendar = Calendar.current

        // Use morning notification time if available, otherwise default to 6:00 AM
        let notifHour = MorningNotificationManager.shared.notificationHour
        let notifMinute = MorningNotificationManager.shared.notificationMinute

        // Target: 1 hour before the notification
        var targetComponents = DateComponents()
        targetComponents.hour = notifHour
        targetComponents.minute = notifMinute

        guard let nextNotifTime = calendar.nextDate(
            after: Date(),
            matching: targetComponents,
            matchingPolicy: .nextTime
        ) else {
            // Fallback: next 5:00 AM
            var fallback = DateComponents()
            fallback.hour = 5
            fallback.minute = 0
            return calendar.nextDate(after: Date(), matching: fallback, matchingPolicy: .nextTime)
        }

        // 1 hour before notification, but not before 3:00 AM
        let targetDate = calendar.date(byAdding: .hour, value: -1, to: nextNotifTime) ?? nextNotifTime
        let minHour = calendar.component(.hour, from: targetDate)
        if minHour < 3 {
            // Too early — use 5:00 AM instead
            var fallback = DateComponents()
            fallback.hour = 5
            fallback.minute = 0
            return calendar.nextDate(after: Date(), matching: fallback, matchingPolicy: .nextTime)
        }

        return targetDate
    }
}
