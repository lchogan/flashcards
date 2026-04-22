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

public actor ReminderScheduler {
    public static let studyCategory = "MW_STUDY_REMINDER"
    public static let streakCategory = "MW_STREAK_NUDGE"

    public init() {}

    /// Schedules a repeating daily local notification at `time`. Removes any
    /// existing request with the same identifier first so the caller doesn't
    /// have to track lifecycle.
    public func schedule(
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

    public func cancel(identifier: String) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [identifier],
        )
    }

    public func cancelAll() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
