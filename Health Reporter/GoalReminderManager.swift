//
//  GoalReminderManager.swift
//  Health Reporter
//
//  Manages notification reminders for weekly goals.
//  Mid-week check-in (Wednesday) and end-of-week summary (Sunday).
//

import Foundation
import UserNotifications

final class GoalReminderManager {

    static let shared = GoalReminderManager()
    private init() {}

    private let midWeekIdentifier = "weekly-goals-midweek"
    private let endWeekIdentifier = "weekly-goals-endweek"

    // MARK: - Schedule Reminders

    /// Call when new goals are saved. Schedules mid-week and end-of-week reminders.
    func scheduleReminders() {
        scheduleMidWeekReminder()
        scheduleEndOfWeekReminder()
    }

    /// Cancel all goal reminders (e.g. when all goals are completed).
    func cancelReminders() {
        NotificationScheduler.cancel(identifier: midWeekIdentifier)
        NotificationScheduler.cancel(identifier: endWeekIdentifier)
    }

    // MARK: - Mid-Week Reminder (Wednesday 10:00)

    private func scheduleMidWeekReminder() {
        guard let goalSet = WeeklyGoalStore.currentWeek(),
              goalSet.pendingCount > 0 else {
            NotificationScheduler.cancel(identifier: midWeekIdentifier)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "goals.midweekReminder.title".localized
        content.body = String(format: "goals.midweekReminder.body".localized, goalSet.pendingCount)
        content.sound = .default

        // Schedule for Wednesday at 10:00
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [midWeekIdentifier])

        var dateComponents = DateComponents()
        dateComponents.weekday = 4  // Wednesday
        dateComponents.hour = 10
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: midWeekIdentifier, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("❌ [GoalReminder] Mid-week scheduling failed: \(error)")
            } else {
                print("📅 [GoalReminder] Mid-week reminder scheduled for Wednesday 10:00")
            }
        }
    }

    // MARK: - End-of-Week Summary (Sunday 9:00)

    private func scheduleEndOfWeekReminder() {
        guard let goalSet = WeeklyGoalStore.currentWeek() else {
            NotificationScheduler.cancel(identifier: endWeekIdentifier)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "goals.endweekSummary.title".localized
        content.body = String(format: "goals.endweekSummary.body".localized, goalSet.completedCount, goalSet.goals.count)
        content.sound = .default

        // Schedule for Sunday at 9:00
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [endWeekIdentifier])

        var dateComponents = DateComponents()
        dateComponents.weekday = 1  // Sunday
        dateComponents.hour = 9
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: endWeekIdentifier, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("❌ [GoalReminder] End-of-week scheduling failed: \(error)")
            } else {
                print("📅 [GoalReminder] End-of-week summary scheduled for Sunday 9:00")
            }
        }
    }

    // MARK: - Refresh on Goal Completion

    /// Call when a goal is completed. If all goals are done, cancel reminders.
    func refreshAfterGoalUpdate() {
        guard let goalSet = WeeklyGoalStore.currentWeek() else { return }
        if goalSet.isAllCompleted {
            cancelReminders()
        } else {
            // Reschedule with updated pending count
            scheduleMidWeekReminder()
        }
    }
}
