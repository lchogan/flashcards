//
//  SyncManager.swift
//  Flashcards
//
//  Purpose: Orchestrates a single sync cycle: push pending mutations, pull
//           remote changes for all sync entities, update lastSyncedAt
//           cursor, emit observability events.
//
//  Dependencies: SyncPusher, SyncPuller, Reachability, MutationQueue,
//                APIClientProtocol, AnalyticsClient.
//
//  Key concepts: @Observable + @MainActor because ModelContext is main-
//                actor-isolated and Views observe lastSyncedAt/lastError.
//                syncNow is a no-op when offline. Errors are captured on
//                self but never rethrown — sync is fire-and-forget from
//                the caller's perspective. Cursor (lastSyncedAtMs) is
//                persisted to UserDefaults so it survives app relaunches.
//                sync.queue.stuck is emitted when >100 mutations are pending
//                and the last successful sync was more than 10 minutes ago.
//

import Foundation
import Observation
import SwiftData

/// Orchestrator for a single push→pull cycle. Observable for UI surfaces.
@Observable
@MainActor
public final class SyncManager {
    /// Timestamp of the most recently completed sync cycle.
    public var lastSyncedAt: Date?
    /// Human-readable description of the last sync failure, or nil on success.
    public var lastError: String?
    /// True while a push→pull cycle is in flight.
    public var isSyncing: Bool = false

    private let context: ModelContext
    private let pusher: SyncPusher
    private let puller: SyncPuller
    private let reachability: Reachability

    private static let lastSyncCursorKey = "mw.lastSyncedAtMs"
    private static let syncEntities = [
        "topics", "decks", "sub_topics", "cards",
        "card_sub_topics", "reviews", "sessions",
    ]

    /// Creates the sync manager wrapping the given context, API client, and reachability probe.
    public init(
        context: ModelContext,
        api: APIClientProtocol,
        reachability: Reachability = Reachability()
    ) {
        self.context = context
        self.pusher = SyncPusher(context: context, api: api)
        self.puller = SyncPuller(context: context, api: api)
        self.reachability = reachability
    }

    /// Run one complete sync cycle. Silent no-op when offline.
    public func syncNow() async {
        guard await reachability.isConnected else {
            return
        }
        guard !isSyncing else {
            return
        }
        isSyncing = true
        defer { isSyncing = false }

        let pending = (try? MutationQueue(context: context).pendingCount()) ?? 0
        if pending > 100,
            let last = lastSyncedAt,
            Date().timeIntervalSince(last) > 600
        {
            AnalyticsClient.track(
                "sync.queue.stuck",
                properties: ["pending": pending]
            )
        }

        do {
            _ = try await pusher.pushOnce()
            try await puller.pull(
                entities: Self.syncEntities,
                since: lastSyncedAtMs()
            )
            lastSyncedAt = Date()
            setLastSyncedAtMs(Clock.nowMs())
            lastError = nil
            publishDueCount()
            AnalyticsClient.track("sync.cycle.ok")
        } catch {
            lastError = String(describing: error)
            AnalyticsClient.track(
                "sync.cycle.fail",
                properties: ["error": lastError ?? ""]
            )
        }
    }

    /// Reads the persisted sync cursor from UserDefaults.
    ///
    /// - Returns: Milliseconds since Unix epoch of last successful pull, or 0
    ///   if no sync has completed yet.
    private func lastSyncedAtMs() -> Int64 {
        Int64(UserDefaults.standard.integer(forKey: Self.lastSyncCursorKey))
    }

    /// Persists the sync cursor to UserDefaults so it survives app relaunches.
    ///
    /// - Parameter ms: Milliseconds since Unix epoch to store as the cursor.
    private func setLastSyncedAtMs(_ ms: Int64) {
        UserDefaults.standard.set(Int(ms), forKey: Self.lastSyncCursorKey)
    }

    /// Writes the latest due-card count to the shared App Group so the
    /// Notification Content Extension can render it on the next daily
    /// reminder without a second database read.
    private func publishDueCount() {
        let now = Clock.nowMs()
        let descriptor = FetchDescriptor<CardEntity>(
            predicate: #Predicate { card in
                card.syncDeletedAtMs == nil
                    && card.state != "new"
                    && card.dueAtMs != nil
                    && (card.dueAtMs ?? now) <= now
            }
        )
        let count = (try? context.fetchCount(descriptor)) ?? 0
        DueCountPublisher.publish(count)
    }
}
