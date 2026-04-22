/// CardSubTopicEntity.swift
///
/// SwiftData model representing the many-to-many join between cards and sub-topics.
/// Each row pins one card to one sub-topic within the same deck.
/// Participates in two-way sync under the "card_sub_topics" entity key.
///
/// Dependencies: SwiftData, Foundation, SyncableRecord (same module).
/// Key concepts: immutable pivot — once created the only mutation is soft-delete;
/// applyRemote therefore only updates timestamp fields.

import Foundation
import SwiftData

/// Join record linking a card to a sub-topic.
@Model
public final class CardSubTopicEntity: SyncableRecord {
    /// Stable UUID matching the server-side record id.
    @Attribute(.unique) public var id: String

    /// Associated card UUID — foreign key into CardEntity.
    public var cardId: String

    /// Associated sub-topic UUID — foreign key into SubTopicEntity.
    public var subTopicId: String

    /// Server updated_at_ms; used for LWW conflict resolution.
    public var syncUpdatedAtMs: Int64

    /// Soft-delete tombstone timestamp; non-nil means the relationship is removed.
    public var syncDeletedAtMs: Int64?

    /// Creates the pivot record linking a card to a sub-topic.
    ///
    /// - Parameters:
    ///   - id: Client-generated UUID for this join row.
    ///   - cardId: UUID of the card.
    ///   - subTopicId: UUID of the sub-topic.
    ///   - syncUpdatedAtMs: Creation timestamp in milliseconds.
    public init(id: String, cardId: String, subTopicId: String, syncUpdatedAtMs: Int64) {
        self.id = id
        self.cardId = cardId
        self.subTopicId = subTopicId
        self.syncUpdatedAtMs = syncUpdatedAtMs
    }

    // MARK: - SyncableRecord

    public static var syncEntityKey: String { "card_sub_topics" }
    public var syncId: String { id }

    /// Serialises the join row into the snake_case wire format.
    public func syncPayload() throws -> [String: Any] {
        [
            "id": id,
            "card_id": cardId,
            "sub_topic_id": subTopicId,
            "updated_at_ms": syncUpdatedAtMs,
            "deleted_at_ms": syncDeletedAtMs as Any,
        ]
    }

    /// Applies a server payload.  The pivot's FK fields are immutable after creation;
    /// only timestamp fields are updated.
    public func applyRemote(_ p: [String: Any]) throws {
        if let u = p["updated_at_ms"] as? Int64 { syncUpdatedAtMs = u }
        syncDeletedAtMs = p["deleted_at_ms"] as? Int64
    }
}
