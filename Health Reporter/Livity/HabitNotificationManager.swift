//
//  HabitNotificationManager.swift
//  Health Reporter
//
//  Schedules the local daily reminder for each habit. Each habit's notification
//  has a stable identifier keyed on its UUID so add/update/delete stay in sync.
//

import Foundation
import UserNotifications

enum HabitNotificationManager {

    private static func identifier(for habit: Habit) -> String {
        "livity.habit.reminder.\(habit.id.uuidString)"
    }

    /// Requests local-notification authorization if we haven't asked yet. Safe to
    /// call repeatedly — iOS only surfaces the system prompt once, then returns
    /// the cached decision. `completion` is called with the final granted state.
    static func requestAuthorizationIfNeeded(completion: ((Bool) -> Void)? = nil) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    DispatchQueue.main.async { completion?(granted) }
                }
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async { completion?(true) }
            default:
                DispatchQueue.main.async { completion?(false) }
            }
        }
    }

    /// Schedules (or replaces) the repeating daily calendar notification for a
    /// habit. Silently no-ops when `habit.dailyReminders` is off — and cancels
    /// any previously-scheduled reminder for the same habit.
    static func schedule(for habit: Habit) {
        let id = identifier(for: habit)
        guard habit.dailyReminders else {
            NotificationScheduler.cancel(identifier: id)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = habit.type.displayName
        content.body = reminderBody(for: habit)
        content.sound = .default
        content.userInfo = ["type": "habit_reminder", "habitId": habit.id.uuidString]

        NotificationScheduler.scheduleCalendarNotification(
            identifier: id,
            content: content,
            hour: habit.reminderHour,
            minute: habit.reminderMinute,
            repeats: true
        ) { error in
            if let error {
                print("🎯 [Habit] Failed to schedule reminder: \(error)")
            } else {
                print("🎯 [Habit] Scheduled \(habit.type.displayName) at \(String(format: "%02d:%02d", habit.reminderHour, habit.reminderMinute))")
            }
        }
    }

    /// Removes the habit's reminder (used after delete, or when `dailyReminders`
    /// toggles off during an edit).
    static func cancel(for habit: Habit) {
        NotificationScheduler.cancelAll(identifier: identifier(for: habit))
    }

    /// Re-installs reminders for every habit — handy after app launch or when
    /// the user changes locale / timezone and cached notifications may be stale.
    static func rescheduleAll() {
        for habit in HabitStore.shared.habits {
            schedule(for: habit)
        }
    }

    private static func reminderBody(for habit: Habit) -> String {
        let goalInt = Int(habit.goal.rounded())
        let unit = habit.type.unit
        if unit.isEmpty {
            return "Goal: \(goalInt)"
        }
        return "Goal: \(goalInt) \(unit)"
    }
}
