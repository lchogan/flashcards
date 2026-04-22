//
//  DueCountPublisher.swift
//  Flashcards
//
//  Purpose: Write the current due-card count to the shared App Group so the
//           Notification Content Extension can render it live when the daily
//           reminder fires. The content extension cannot talk to SwiftData
//           or the server — the shared UserDefaults is the hand-off.
//  Dependencies: Foundation only.
//

import Foundation

public enum DueCountPublisher {
    public static let appGroup = "group.com.lukehogan.flashcards"
    public static let dueCountKey = "mw.dueCount"

    /// Publishes the latest due-card count to the shared App Group defaults
    /// so the Notification Content Extension can read it from its own
    /// process. Safe to call on any actor / thread.
    public static func publish(_ count: Int) {
        UserDefaults(suiteName: appGroup)?.set(count, forKey: dueCountKey)
    }

    /// Reads the last-published due count. Nil if the publisher hasn't run
    /// yet since install / group provisioning.
    public static func read() -> Int? {
        guard let defaults = UserDefaults(suiteName: appGroup) else {
            return nil
        }
        return defaults.object(forKey: dueCountKey) as? Int
    }
}
