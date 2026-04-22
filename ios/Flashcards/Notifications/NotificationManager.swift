//
//  NotificationManager.swift
//  Flashcards
//
//  Purpose: Thin wrapper around UNUserNotificationCenter authorization.
//           Centralizing permission checks here keeps call sites declarative
//           ("did the user grant us notifications?") without letting each
//           one rediscover the UNAuthorizationStatus API.
//  Dependencies: Foundation, UserNotifications.
//

import Foundation
import UserNotifications

public actor NotificationManager {
    public static let shared = NotificationManager()

    public init() {}

    /// Requests notification authorization if we don't already have it.
    /// Returns true if the final authorization status is authorized.
    public func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let current = await center.notificationSettings()
        if current.authorizationStatus == .authorized {
            return true
        }
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    public func currentStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}
