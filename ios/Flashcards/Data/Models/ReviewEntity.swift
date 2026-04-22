/// ReviewEntity.swift
///
/// SwiftData model representing a single card review event recorded during a study session.
/// Reviews are append-only — once synced they are never mutated, so applyRemote is a no-op.
/// Participates in one-way sync (push only) under the "reviews" entity key.
///
/// Dependencies: SwiftData, Foundation, SyncableRecord (same module).
/// Key concepts: state_before/state_after store FSRS-6 scheduler snapshots as JSON Data
/// to avoid schema changes when the scheduler evolves; syncDeletedAtMs is retained for
/// schema symmetry but is unused.

import Foundation
import SwiftData

/// An immutable record of one card review within a study session.
@Model
public final class ReviewEntity: SyncableRecord {
    /// Stable UUID matching the server-side record id.
    @Attribute(.unique) public var id: String

    /// Reviewed card UUID — foreign key into CardEntity.
    public var cardId: String

    /// Reviewing user UUID — foreign key into UserEntity.
    public var userId: String

    /// Optional parent session UUID — foreign key into SessionEntity.
    public var sessionId: String?

    /// User's response quality rating (1–4 in FSRS-6).
    public var rating: Int

    /// Time the user spent viewing the card before rating, in milliseconds.
    public var reviewDurationMs: Int

    /// Wall-clock time (ms) the rating was submitted.
    public var ratedAtMs: Int64

    /// FSRS-6 scheduler state snapshot before this review, serialised as JSON.
    public var stateBeforeJSON: Data

    /// FSRS-6 scheduler state snapshot after this review, serialised as JSON.
    public var stateAfterJSON: Data

    /// Scheduler algorithm version tag, e.g. "fsrs-6".
    public var schedulerVersion: String

    /// Server updated_at_ms; used for LWW (push path only).
    public var syncUpdatedAtMs: Int64

    /// Always nil — reviews are append-only and are never soft-deleted.
    public var syncDeletedAtMs: Int64?

    /// Creates a review record, serialising the before/after FSRS states to JSON.
    ///
    /// - Parameters:
    ///   - id: Client-generated UUID.
    ///   - cardId: UUID of the reviewed card.
    ///   - userId: UUID of the reviewing user.
    ///   - rating: FSRS-6 quality rating (1–4).
    ///   - ratedAtMs: Epoch milliseconds when the rating was submitted.
    ///   - stateBefore: FSRS scheduler state dictionary before the review.
    ///   - stateAfter: FSRS scheduler state dictionary after the review.
    ///   - syncUpdatedAtMs: Creation timestamp in milliseconds.
    public init(
        id: String,
        cardId: String,
        userId: String,
        rating: Int,
        ratedAtMs: Int64,
        stateBefore: [String: Any],
        stateAfter: [String: Any],
        syncUpdatedAtMs: Int64
    ) {
        self.id = id
        self.cardId = cardId
        self.userId = userId
        self.sessionId = nil
        self.rating = rating
        self.reviewDurationMs = 0
        self.ratedAtMs = ratedAtMs
        self.stateBeforeJSON = (try? JSONSerialization.data(withJSONObject: stateBefore)) ?? Data()
        self.stateAfterJSON = (try? JSONSerialization.data(withJSONObject: stateAfter)) ?? Data()
        self.schedulerVersion = "fsrs-6"
        self.syncUpdatedAtMs = syncUpdatedAtMs
    }

    // MARK: - SyncableRecord

    public static var syncEntityKey: String { "reviews" }
    public var syncId: String { id }

    /// Serialises the review into the snake_case wire format.
    /// Deserialises stateBeforeJSON/stateAfterJSON back to dictionaries for the payload.
    public func syncPayload() throws -> [String: Any] {
        [
            "id": id,
            "card_id": cardId,
            "user_id": userId,
            "session_id": sessionId as Any,
            "rating": rating,
            "review_duration_ms": reviewDurationMs,
            "rated_at_ms": ratedAtMs,
            "state_before": (try? JSONSerialization.jsonObject(with: stateBeforeJSON)) ?? [:],
            "state_after": (try? JSONSerialization.jsonObject(with: stateAfterJSON)) ?? [:],
            "scheduler_version": schedulerVersion,
            "updated_at_ms": syncUpdatedAtMs,
        ]
    }

    /// No-op: reviews are append-only and are never updated from the server.
    public func applyRemote(_ p: [String: Any]) throws {
        // Reviews are append-only; the server never sends a mutated review back.
    }
}
