/// SubTopicEntity.swift
///
/// SwiftData model representing a sub-topic (section/tag) within a deck.
/// Sub-topics let users organise cards into labelled groups inside a single deck.
/// Participates in two-way sync under the "sub_topics" entity key.
///
/// Dependencies: SwiftData, Foundation, SyncableRecord (same module).
/// Key concepts: position is 0-indexed display order within the parent deck;
/// soft-delete via syncDeletedAtMs.

import Foundation
import SwiftData

/// A named section within a deck, used to group related cards.
@Model
public final class SubTopicEntity: SyncableRecord {
    /// Stable UUID matching the server-side record id.
    @Attribute(.unique) public var id: String

    /// Parent deck UUID — foreign key into DeckEntity.
    public var deckId: String

    /// Display label shown on the sub-topic chip/section header.
    public var name: String

    /// 0-indexed display order within the parent deck.
    public var position: Int

    /// Optional colour hint for UI tinting, mirroring TopicEntity.colorHint.
    public var colorHint: String?

    /// Server updated_at_ms; used for LWW conflict resolution.
    public var syncUpdatedAtMs: Int64

    /// Soft-delete tombstone timestamp; non-nil means the record is deleted.
    public var syncDeletedAtMs: Int64?

    /// Creates a sub-topic with required fields.
    ///
    /// - Parameters:
    ///   - id: Client-generated UUID.
    ///   - deckId: Parent deck UUID.
    ///   - name: Display label.
    ///   - position: Display order (default 0).
    ///   - syncUpdatedAtMs: Creation timestamp in milliseconds.
    public init(id: String, deckId: String, name: String, position: Int = 0, syncUpdatedAtMs: Int64) {
        self.id = id
        self.deckId = deckId
        self.name = name
        self.position = position
        self.syncUpdatedAtMs = syncUpdatedAtMs
    }

    // MARK: - SyncableRecord

    /// Wire-format key for sync endpoints (e.g. "sub_topics").
    public static var syncEntityKey: String { "sub_topics" }
    /// Stable UUID string for sync identity.
    public var syncId: String { id }

    /// Serialises the sub-topic into the snake_case wire format expected by the API.
    public func syncPayload() throws -> [String: Any] {
        [
            "id": id,
            "deck_id": deckId,
            "name": name,
            "position": position,
            "color_hint": colorHint as Any,
            "updated_at_ms": syncUpdatedAtMs,
            "deleted_at_ms": syncDeletedAtMs as Any,
        ]
    }

    /// Applies a server payload, overwriting mutable fields.  Caller enforces LWW.
    public func applyRemote(_ p: [String: Any]) throws {
        if let s = p["name"] as? String { name = s }
        if let i = p["position"] as? Int { position = i }
        colorHint = p["color_hint"] as? String
        if let u = p["updated_at_ms"] as? Int64 { syncUpdatedAtMs = u }
        syncDeletedAtMs = p["deleted_at_ms"] as? Int64
    }
}
