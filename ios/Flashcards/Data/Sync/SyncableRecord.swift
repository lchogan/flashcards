import Foundation

/// A SwiftData entity that participates in sync.
public protocol SyncableRecord: AnyObject {
    static var syncEntityKey: String { get }  // e.g. "decks"
    var syncId: String { get }
    var syncUpdatedAtMs: Int64 { get set }
    var syncDeletedAtMs: Int64? { get set }

    /// Snake_case-keyed JSON payload including envelope fields.
    func syncPayload() throws -> [String: Any]
    /// Apply remote payload, respecting LWW (caller enforces).
    func applyRemote(_ payload: [String: Any]) throws
}
