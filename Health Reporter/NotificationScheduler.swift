//
//  NotificationScheduler.swift
//  Health Reporter
//
//  Shared utility for scheduling a single pending notification per identifier.
//  Ensures exactly ONE notification exists per identifier by always removing before adding.
//

import Foundation
import UserNotifications

final class NotificationScheduler {

    /// Schedule (or replace) a calendar-triggered notification.
    /// If a notification with this identifier already exists, it is replaced atomically.
    static func scheduleCalendarNotification(
        identifier: String,
        content: UNMutableNotificationContent,
        hour: Int,
        minute: Int,
        repeats: Bool = true,
        completion: ((Error?) -> Void)? = nil
    ) {
        let center = UNUserNotificationCenter.current()

        // Remove existing first — atomic replacement
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        // Do NOT set timeZone — iOS uses device timezone automatically.
        // Setting .current explicitly causes issues across DST transitions.

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: repeats
        )

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            completion?(error)
        }
    }

    /// Remove a pending notification.
    static func cancel(identifier: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// Remove both pending and delivered notifications.
    static func cancelAll(identifier: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    /// Clean up legacy notifications with timestamp-appended identifiers.
    static func cleanupLegacyNotifications(prefix: String) {
        let center = UNUserNotificationCenter.current()
        center.getDeliveredNotifications { notifications in
            let legacyIds = notifications
                .map { $0.request.identifier }
                .filter { $0.hasPrefix(prefix) && $0 != prefix }
            if !legacyIds.isEmpty {
                center.removeDeliveredNotifications(withIdentifiers: legacyIds)
            }
        }
        center.getPendingNotificationRequests { requests in
            let legacyIds = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix(prefix) && $0 != prefix }
            if !legacyIds.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: legacyIds)
            }
        }
    }
}
