/// CardEntity.swift
///
/// SwiftData model representing a single flashcard (front/back pair) within a deck.
/// Stores FSRS-6 scheduler state alongside content fields.
/// Participates in two-way sync under the "cards" entity key.
///
/// Dependencies: SwiftData, Foundation, SyncableRecord (same module).
/// Key concepts: stability and difficulty are nullable until the card has been
/// reviewed at least once; state transitions: "new" → "learning" → "review" → "relearning".

import Foundation
import SwiftData

/// A flashcard with front/back content and embedded FSRS-6 scheduler state.
@Model
public final class CardEntity: SyncableRecord {
    /// Stable UUID matching the server-side record id.
    @Attribute(.unique) public var id: String

    /// Parent deck UUID — foreign key into DeckEntity.
    public var deckId: String

    /// Markdown-capable front-face content.
    public var frontText: String

    /// Markdown-capable back-face content.
    public var backText: String

    /// Optional asset UUID for a front-face image — foreign key into AssetEntity.
    public var frontImageAssetId: String?

    /// Optional asset UUID for a back-face image — foreign key into AssetEntity.
    public var backImageAssetId: String?

    /// 0-indexed display order within the parent deck.
    public var position: Int

    /// FSRS-6 stability value; nil until first review.
    public var stability: Double?

    /// FSRS-6 difficulty value; nil until first review.
    public var difficulty: Double?

    /// FSRS-4/6 state string: "new" | "learning" | "review" | "relearning".
    public var state: String

    /// Wall-clock time (ms) of the most recent review, nil if never reviewed.
    public var lastReviewedAtMs: Int64?

    /// Wall-clock time (ms) at which this card is next due for review.
    public var dueAtMs: Int64?

    /// Number of times the card has lapsed back to learning state.
    public var lapses: Int

    /// Total number of review repetitions.
    public var reps: Int

    /// Server updated_at_ms; used for LWW conflict resolution.
    public var syncUpdatedAtMs: Int64

    /// Soft-delete tombstone timestamp; non-nil means the record is deleted.
    public var syncDeletedAtMs: Int64?

    /// Creates a new card in the "new" state with zero scheduler history.
    ///
    /// - Parameters:
    ///   - id: Client-generated UUID.
    ///   - deckId: Parent deck UUID.
    ///   - frontText: Front-face content.
    ///   - backText: Back-face content.
    ///   - syncUpdatedAtMs: Creation timestamp in milliseconds.
    public init(
        id: String,
        deckId: String,
        frontText: String,
        backText: String,
        syncUpdatedAtMs: Int64
    ) {
        self.id = id
        self.deckId = deckId
        self.frontText = frontText
        self.backText = backText
        self.position = 0
        self.state = "new"
        self.lapses = 0
        self.reps = 0
        self.syncUpdatedAtMs = syncUpdatedAtMs
    }

    // MARK: - SyncableRecord

    /// Wire-format key for sync endpoints (e.g. "cards").
    public static var syncEntityKey: String { "cards" }
    /// Stable UUID string for sync identity.
    public var syncId: String { id }

    /// Serialises the card and its scheduler state into the snake_case wire format.
    public func syncPayload() throws -> [String: Any] {
        [
            "id": id,
            "deck_id": deckId,
            "front_text": frontText,
            "back_text": backText,
            "front_image_asset_id": frontImageAssetId as Any,
            "back_image_asset_id": backImageAssetId as Any,
            "position": position,
            "stability": stability as Any,
            "difficulty": difficulty as Any,
            "state": state,
            "last_reviewed_at_ms": lastReviewedAtMs as Any,
            "due_at_ms": dueAtMs as Any,
            "lapses": lapses,
            "reps": reps,
            "updated_at_ms": syncUpdatedAtMs,
            "deleted_at_ms": syncDeletedAtMs as Any,
        ]
    }

    /// Applies a server payload, overwriting all mutable fields.  Caller enforces LWW.
    public func applyRemote(_ p: [String: Any]) throws {
        if let s = p["front_text"] as? String { frontText = s }
        if let s = p["back_text"] as? String { backText = s }
        frontImageAssetId = p["front_image_asset_id"] as? String
        backImageAssetId = p["back_image_asset_id"] as? String
        if let i = p["position"] as? Int { position = i }
        stability = p["stability"] as? Double
        difficulty = p["difficulty"] as? Double
        if let s = p["state"] as? String { state = s }
        lastReviewedAtMs = p["last_reviewed_at_ms"] as? Int64
        dueAtMs = p["due_at_ms"] as? Int64
        if let i = p["lapses"] as? Int { lapses = i }
        if let i = p["reps"] as? Int { reps = i }
        if let u = p["updated_at_ms"] as? Int64 { syncUpdatedAtMs = u }
        syncDeletedAtMs = p["deleted_at_ms"] as? Int64
    }
}
