/// DeckEntity.swift
///
/// SwiftData model representing a flashcard deck owned by the user.
/// Participates in two-way sync via /v1/sync/push and /v1/sync/pull under the
/// "decks" entity key.
///
/// Dependencies: SwiftData, Foundation, SyncableRecord (same module).
/// Key concepts: `deckDescription` avoids collision with NSObject.description;
/// cardCount is a denormalised counter maintained by the API.

import Foundation
import SwiftData

/// A collection of flashcards with a shared topic, accent colour, and study mode.
@Model
public final class DeckEntity: SyncableRecord {
    /// Stable UUID matching the server-side record id.
    @Attribute(.unique) public var id: String

    /// Owner user UUID — foreign key into UserEntity.
    public var userId: String

    /// Optional parent topic UUID — foreign key into TopicEntity.
    public var topicId: String?

    /// Deck display name shown in lists and headers.
    public var title: String

    /// Optional long-form description. Named `deckDescription` to avoid
    /// collision with NSObject.description.
    public var deckDescription: String?

    /// Accent colour token, e.g. "amber", "violet". Drives UI tinting.
    public var accentColor: String

    /// Study algorithm/mode: "smart" | "leitner" | "sequential".
    public var defaultStudyMode: String

    /// Denormalised total card count, kept in sync by the API.
    public var cardCount: Int

    /// Wall-clock time (ms) the user last opened a study session for this deck.
    public var lastStudiedAtMs: Int64?

    /// Server updated_at_ms; used for LWW conflict resolution.
    public var syncUpdatedAtMs: Int64

    /// Soft-delete tombstone timestamp; non-nil means the record is deleted.
    public var syncDeletedAtMs: Int64?

    /// Creates a deck with required fields and sensible defaults.
    ///
    /// - Parameters:
    ///   - id: Client-generated UUID.
    ///   - userId: Owning user's UUID.
    ///   - title: Display name for the deck.
    ///   - accentColor: Colour token (default "amber").
    ///   - defaultStudyMode: Study algorithm (default "smart").
    ///   - syncUpdatedAtMs: Creation timestamp in milliseconds.
    public init(
        id: String,
        userId: String,
        title: String,
        accentColor: String = "amber",
        defaultStudyMode: String = "smart",
        syncUpdatedAtMs: Int64
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.accentColor = accentColor
        self.defaultStudyMode = defaultStudyMode
        self.cardCount = 0
        self.syncUpdatedAtMs = syncUpdatedAtMs
    }

    // MARK: - SyncableRecord

    /// Wire-format key for sync endpoints (e.g. "decks").
    public static var syncEntityKey: String { "decks" }
    /// Stable UUID string for sync identity.
    public var syncId: String { id }

    /// Serialises the deck into the snake_case wire format expected by the API.
    public func syncPayload() throws -> [String: Any] {
        [
            "id": id,
            "topic_id": topicId as Any,
            "title": title,
            "description": deckDescription as Any,
            "accent_color": accentColor,
            "default_study_mode": defaultStudyMode,
            "card_count": cardCount,
            "last_studied_at_ms": lastStudiedAtMs as Any,
            "updated_at_ms": syncUpdatedAtMs,
            "deleted_at_ms": syncDeletedAtMs as Any,
        ]
    }

    /// Applies a server payload, overwriting mutable fields.  Caller enforces LWW.
    public func applyRemote(_ payload: [String: Any]) throws {
        topicId = payload["topic_id"] as? String
        if let t = payload["title"] as? String { title = t }
        deckDescription = payload["description"] as? String
        if let a = payload["accent_color"] as? String { accentColor = a }
        if let m = payload["default_study_mode"] as? String { defaultStudyMode = m }
        if let c = payload["card_count"] as? Int { cardCount = c }
        lastStudiedAtMs = payload["last_studied_at_ms"] as? Int64
        if let u = payload["updated_at_ms"] as? Int64 { syncUpdatedAtMs = u }
        syncDeletedAtMs = payload["deleted_at_ms"] as? Int64
    }
}
