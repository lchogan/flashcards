/// PendingMutationEntity.swift
///
/// SwiftData model representing a queued write operation that has not yet been
/// successfully persisted to the remote API.  Each row captures a full JSON
/// snapshot of the affected record so the pusher can replay it independently
/// of in-memory state.
///
/// Dependencies: SwiftData, Foundation, Clock (same module)
/// Key concepts: append-only insert, exponential-backoff retry scheduling.

import Foundation
import SwiftData

/// A single pending mutation awaiting remote synchronisation.
@Model
public final class PendingMutationEntity {
    /// Stable row identifier — unique across all pending mutations.
    @Attribute(.unique) public var id: UUID

    /// The API entity collection this mutation targets, e.g. "decks" or "cards".
    public var entityKey: String

    /// Client-side UUID of the affected record.
    public var recordId: String

    /// Full JSON snapshot of the record at enqueue time, serialised for transport.
    public var payloadJSON: Data

    /// Wall-clock time this mutation was enqueued, in milliseconds since Unix epoch.
    public var createdAtMs: Int64

    /// Number of failed push attempts so far (0 = never attempted).
    public var retryCount: Int

    /// Earliest wall-clock time (ms) at which this mutation may next be attempted.
    /// Zero means "eligible immediately".
    public var nextAttemptAtMs: Int64

    /// Creates a new pending mutation and serialises the payload.
    ///
    /// - Parameters:
    ///   - entityKey: The API collection name.
    ///   - recordId:  Client UUID of the record.
    ///   - payload:   Full record dictionary; must be JSON-serialisable.
    public init(entityKey: String, recordId: String, payload: [String: Any]) {
        self.id = UUID()
        self.entityKey = entityKey
        self.recordId = recordId
        self.payloadJSON = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
        self.createdAtMs = Clock.nowMs()
        self.retryCount = 0
        self.nextAttemptAtMs = 0
    }
}
