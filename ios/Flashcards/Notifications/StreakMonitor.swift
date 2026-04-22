//
//  StreakMonitor.swift
//  Flashcards
//
//  Purpose: Detects "streak at risk" — the user has studied yesterday but
//           hasn't reviewed anything today. Used to fire a nudge notification
//           at 20:00 local so the user doesn't silently break their streak.
//  Dependencies: Foundation, SwiftData, ReviewEntity.
//

import Foundation
import SwiftData

/// Pure-function-style helper that queries the local review log to decide
/// whether to nudge the user. Not @Observable — no UI state.
@MainActor
public final class StreakMonitor {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// Returns true if the user has a streak (reviewed yesterday) but has
    /// not yet reviewed anything today.
    public func streakAtRisk(now: Date = Date()) -> Bool {
        let cal = Calendar.current
        let todayStart = Int64(cal.startOfDay(for: now).timeIntervalSince1970 * 1000)
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: now) else {
            return false
        }
        let yesterdayStart = Int64(cal.startOfDay(for: yesterday).timeIntervalSince1970 * 1000)

        let todayDescriptor = FetchDescriptor<ReviewEntity>(
            predicate: #Predicate { $0.ratedAtMs >= todayStart },
        )
        let yesterdayDescriptor = FetchDescriptor<ReviewEntity>(
            predicate: #Predicate { $0.ratedAtMs >= yesterdayStart && $0.ratedAtMs < todayStart },
        )

        let studiedToday = ((try? context.fetchCount(todayDescriptor)) ?? 0) > 0
        let studiedYesterday = ((try? context.fetchCount(yesterdayDescriptor)) ?? 0) > 0

        return studiedYesterday && !studiedToday
    }
}
