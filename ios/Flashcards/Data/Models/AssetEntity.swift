/// AssetEntity.swift
///
/// SwiftData model representing a binary asset (image, audio) associated with a card.
/// This entity is reserved for v1.5 and does NOT conform to SyncableRecord — asset
/// sync will be implemented as a separate upload/download pipeline, not via the
/// standard push/pull sync routes.
///
/// Dependencies: SwiftData, Foundation.
/// Key concepts: uploadStatus tracks the R2 upload lifecycle ("pending" → "uploaded");
/// localPath is the on-device cache path, r2Key is the remote object key.

import Foundation
import SwiftData

/// A media asset (image, audio) attached to a card face.  Reserved for v1.5.
@Model
public final class AssetEntity {
    /// Stable UUID matching the server-side record id.
    @Attribute(.unique) public var id: String

    /// Owner user UUID — foreign key into UserEntity.
    public var userId: String

    /// MIME type of the asset, e.g. "image/jpeg" or "image/png".
    public var mimeType: String

    /// File size in bytes; nil until the upload is complete.
    public var bytes: Int?

    /// Cloudflare R2 object key; nil until the asset has been uploaded.
    public var r2Key: String?

    /// Absolute path to the locally cached copy of the asset, nil if not cached.
    public var localPath: String?

    /// Upload lifecycle state: "pending" | "uploading" | "uploaded" | "failed".
    public var uploadStatus: String

    /// Server updated_at_ms; retained for schema symmetry with other entities.
    public var syncUpdatedAtMs: Int64

    /// Tombstone timestamp; retained for schema symmetry; unused until v1.5.
    public var syncDeletedAtMs: Int64?

    /// Creates a pending asset record before the binary data has been uploaded.
    ///
    /// - Parameters:
    ///   - id: Client-generated UUID.
    ///   - userId: Owning user's UUID.
    ///   - mimeType: MIME type of the binary content.
    ///   - syncUpdatedAtMs: Creation timestamp in milliseconds.
    public init(id: String, userId: String, mimeType: String, syncUpdatedAtMs: Int64) {
        self.id = id
        self.userId = userId
        self.mimeType = mimeType
        self.uploadStatus = "pending"
        self.syncUpdatedAtMs = syncUpdatedAtMs
    }
}
