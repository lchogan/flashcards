/// MutationQueue.swift
///
/// Append-only queue of pending remote mutations backed by SwiftData.  The
/// queue is responsible for enqueuing new mutations, retrieving batches that
/// are due for dispatch, and recording success or failure with exponential
/// back-off scheduling.
///
/// Dependencies: SwiftData, Foundation, PendingMutationEntity, Clock
/// Key concepts: main-actor isolation matches SwiftData main context; all
/// public methods are synchronous because SwiftData's ModelContext is not
/// Sendable and must be accessed on one actor.

import Foundation
import SwiftData

/// Manages the ordered queue of mutations waiting to be pushed to the API.
///
/// All methods must be called on the main actor because they access
/// `ModelContext`, which is main-actor–isolated.
@MainActor
public final class MutationQueue {
    private let context: ModelContext

    /// Creates a queue backed by the supplied SwiftData context.
    ///
    /// - Parameter context: The `ModelContext` used for all persistence
    ///   operations.  Typically `modelContainer.mainContext`.
    public init(context: ModelContext) { self.context = context }

    /// Appends a new mutation to the queue and immediately saves.
    ///
    /// - Parameters:
    ///   - entityKey: API collection name (e.g. "decks").
    ///   - recordId:  Client-side UUID of the affected record.
    ///   - payload:   Full record snapshot; must be JSON-serialisable.
    /// - Throws: `ModelContext` save errors.
    public func enqueue(entityKey: String, recordId: String, payload: [String: Any]) throws {
        let m = PendingMutationEntity(entityKey: entityKey, recordId: recordId, payload: payload)
        context.insert(m)
        try context.save()
    }

    /// Returns the total number of pending mutations in the store.
    ///
    /// - Returns: Row count.
    /// - Throws: `ModelContext` fetch errors.
    public func pendingCount() throws -> Int {
        try context.fetchCount(FetchDescriptor<PendingMutationEntity>())
    }

    /// Returns all pending mutations ordered by enqueue time (oldest first).
    ///
    /// - Returns: Ordered array of all `PendingMutationEntity` rows.
    /// - Throws: `ModelContext` fetch errors.
    public func allPending() throws -> [PendingMutationEntity] {
        try context.fetch(
            FetchDescriptor<PendingMutationEntity>(
                sortBy: [SortDescriptor(\.createdAtMs)]
            )
        )
    }

    /// Returns up to `limit` mutations whose `nextAttemptAtMs` is at or before
    /// `now`, ordered oldest-first.
    ///
    /// - Parameters:
    ///   - now:   Current time in milliseconds since Unix epoch.
    ///   - limit: Maximum number of mutations to return.
    /// - Returns: Slice of due mutations.
    /// - Throws: `ModelContext` fetch errors.
    public func takeBatch(now: Int64, limit: Int = 100) throws -> [PendingMutationEntity] {
        let all = try allPending()
        return Array(all.filter { $0.nextAttemptAtMs <= now }.prefix(limit))
    }

    /// Removes a successfully pushed mutation from the queue.
    ///
    /// - Parameter m: The mutation to delete.
    /// - Throws: `ModelContext` save errors.
    public func markSuccess(_ m: PendingMutationEntity) throws {
        context.delete(m)
        try context.save()
    }

    /// Increments the retry counter and schedules the next attempt using
    /// exponential back-off.
    ///
    /// - Parameters:
    ///   - m:   The mutation that failed.
    ///   - now: Current time in milliseconds since Unix epoch.
    /// - Throws: `ModelContext` save errors.
    public func markFailure(_ m: PendingMutationEntity, now: Int64) throws {
        m.retryCount += 1
        m.nextAttemptAtMs = now + Self.backoffMs(retry: m.retryCount)
        try context.save()
    }

    /// Returns the back-off delay in milliseconds for the given retry index.
    ///
    /// Schedule: 2 s → 8 s → 30 s → 2 min → 15 min (cap).
    ///
    /// - Parameter retry: Number of attempts already made (0-based).
    /// - Returns: Milliseconds to wait before the next attempt.
    public static func backoffMs(retry: Int) -> Int64 {
        let steps: [Int64] = [2_000, 8_000, 30_000, 120_000, 900_000]
        return steps[min(retry, steps.count - 1)]
    }
}
