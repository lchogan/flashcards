//
//  ReminderScheduler.swift
//  Flashcards
//
//  Purpose: Schedules repeating daily-study reminders via
//           UNCalendarNotificationTrigger. Uses a stable identifier per
//           reminder so editing a time removes-then-reschedules cleanly.
//  Dependencies: Foundation, UserNotifications.
//

import Foundation
import UserNotifications

internal actor ReminderScheduler {
    internal static let studyCategory = "MW_STUDY_REMINDER"
    internal static let streakCategory = "MW_STREAK_NUDGE"

    internal init() {}

    /// Schedules a repeating daily local notification at `time`. Removes any
    /// existing request with the same identifier first so the caller doesn't
    /// have to track lifecycle.
    internal func schedule(
        time: DateComponents,
        identifier: String,
        title: String,
        body: String,
        category: String = "MW_STUDY_REMINDER",
    ) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category

        let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger,
        )
        try? await center.add(request)
    }

    internal func cancel(identifier: String) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [identifier],
        )
    }

    internal func cancelAll() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
