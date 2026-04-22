/// SessionEntity.swift
///
/// SwiftData model representing a study session — a bounded period of card review
/// activity against a single deck.  Sessions accumulate aggregated statistics
/// (cards reviewed, accuracy, mastery delta) that are computed client-side and pushed.
/// Participates in two-way sync under the "sessions" entity key.
///
/// Dependencies: SwiftData, Foundation, SyncableRecord (same module).
/// Key concepts: endedAtMs nil means the session is in-progress; accuracy and
/// masteryDelta are floating-point percentages in the range [0, 1].

import Foundation
import SwiftData

/// A bounded study session recording aggregate review statistics for one deck.
@Model
public final class SessionEntity: SyncableRecord {
    /// Stable UUID matching the server-side record id.
    @Attribute(.unique) public var id: String

    /// Session owner UUID — foreign key into UserEntity.
    public var userId: String

    /// Deck studied in this session — foreign key into DeckEntity.
    public var deckId: String

    /// Study mode active during the session: "smart" | "leitner" | "sequential".
    public var mode: String

    /// Wall-clock time (ms) the session was opened.
    public var startedAtMs: Int64

    /// Wall-clock time (ms) the session was closed; nil while in-progress.
    public var endedAtMs: Int64?

    /// Number of individual card reviews completed in this session.
    public var cardsReviewed: Int

    /// Accuracy as a fraction [0, 1] — proportion of cards rated Good or Easy.
    public var accuracyPct: Double

    /// Change in deck mastery score during this session, in the range [-1, 1].
    public var masteryDelta: Double

    /// Server updated_at_ms; used for LWW conflict resolution.
    public var syncUpdatedAtMs: Int64

    /// Soft-delete tombstone timestamp; non-nil means the record is deleted.
    public var syncDeletedAtMs: Int64?

    /// Creates an in-progress session with zero aggregated statistics.
    ///
    /// - Parameters:
    ///   - id: Client-generated UUID.
    ///   - userId: Owning user's UUID.
    ///   - deckId: Deck being studied.
    ///   - mode: Study algorithm mode.
    ///   - startedAtMs: Session open time in epoch milliseconds.
    ///   - syncUpdatedAtMs: Creation timestamp in milliseconds.
    public init(
        id: String,
        userId: String,
        deckId: String,
        mode: String,
        startedAtMs: Int64,
        syncUpdatedAtMs: Int64
    ) {
        self.id = id
        self.userId = userId
        self.deckId = deckId
        self.mode = mode
        self.startedAtMs = startedAtMs
        self.cardsReviewed = 0
        self.accuracyPct = 0
        self.masteryDelta = 0
        self.syncUpdatedAtMs = syncUpdatedAtMs
    }

    // MARK: - SyncableRecord

    /// Wire-format key for sync endpoints (e.g. "sessions").
    public static var syncEntityKey: String { "sessions" }
    /// Stable UUID string for sync identity.
    public var syncId: String { id }

    /// Serialises the session into the snake_case wire format.
    public func syncPayload() throws -> [String: Any] {
        [
            "id": id,
            "user_id": userId,
            "deck_id": deckId,
            "mode": mode,
            "started_at_ms": startedAtMs,
            "ended_at_ms": endedAtMs as Any,
            "cards_reviewed": cardsReviewed,
            "accuracy_pct": accuracyPct,
            "mastery_delta": masteryDelta,
            "updated_at_ms": syncUpdatedAtMs,
            "deleted_at_ms": syncDeletedAtMs as Any,
        ]
    }

    /// Applies a server payload, overwriting mutable fields.  Caller enforces LWW.
    public func applyRemote(_ p: [String: Any]) throws {
        if let s = p["mode"] as? String { mode = s }
        if let i = p["started_at_ms"] as? Int64 { startedAtMs = i }
        endedAtMs = p["ended_at_ms"] as? Int64
        if let i = p["cards_reviewed"] as? Int { cardsReviewed = i }
        if let d = p["accuracy_pct"] as? Double { accuracyPct = d }
        if let d = p["mastery_delta"] as? Double { masteryDelta = d }
        if let u = p["updated_at_ms"] as? Int64 { syncUpdatedAtMs = u }
        syncDeletedAtMs = p["deleted_at_ms"] as? Int64
    }
}
