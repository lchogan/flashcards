/// TopicEntity.swift
///
/// SwiftData model representing a user-defined topic that groups decks thematically.
/// Participates in two-way sync via /v1/sync/push and /v1/sync/pull under the
/// "topics" entity key.
///
/// Dependencies: SwiftData, Foundation, SyncableRecord (same module).
/// Key concepts: soft-delete via syncDeletedAtMs, LWW merge enforced by caller.

import Foundation
import SwiftData

/// A named grouping of decks, optionally tinted with a colour hint.
@Model
public final class TopicEntity: SyncableRecord {
    /// Stable UUID matching the server-side record id.
    @Attribute(.unique) public var id: String

    /// Owner user UUID — foreign key into UserEntity.
    public var userId: String

    /// Human-readable topic label shown in the UI.
    public var name: String

    /// Optional CSS-compatible colour string used to tint the topic chip.
    public var colorHint: String?

    /// Server updated_at_ms; used for LWW conflict resolution.
    public var syncUpdatedAtMs: Int64

    /// Soft-delete tombstone timestamp; non-nil means the record is deleted.
    public var syncDeletedAtMs: Int64?

    /// Creates a new topic with required fields; optional fields default to nil.
    ///
    /// - Parameters:
    ///   - id: Client-generated UUID.
    ///   - userId: Owning user's UUID.
    ///   - name: Display name for the topic.
    ///   - syncUpdatedAtMs: Creation timestamp in milliseconds.
    public init(id: String, userId: String, name: String, syncUpdatedAtMs: Int64) {
        self.id = id
        self.userId = userId
        self.name = name
        self.syncUpdatedAtMs = syncUpdatedAtMs
    }

    // MARK: - SyncableRecord

    public static var syncEntityKey: String { "topics" }
    public var syncId: String { id }

    /// Serialises the topic into the snake_case wire format expected by the API.
    public func syncPayload() throws -> [String: Any] {
        [
            "id": id,
            "name": name,
            "color_hint": colorHint as Any,
            "updated_at_ms": syncUpdatedAtMs,
            "deleted_at_ms": syncDeletedAtMs as Any,
        ]
    }

    /// Applies a server payload, overwriting mutable fields.  Caller has already
    /// verified the remote timestamp is newer (LWW).
    public func applyRemote(_ payload: [String: Any]) throws {
        if let s = payload["name"] as? String { name = s }
        colorHint = payload["color_hint"] as? String
        if let u = payload["updated_at_ms"] as? Int64 { syncUpdatedAtMs = u }
        syncDeletedAtMs = payload["deleted_at_ms"] as? Int64
    }
}
