//
//  SyncPuller.swift
//  Flashcards
//
//  Purpose: Fetches GET /api/v1/sync/pull and applies incoming records to
//           local SwiftData models using last-write-wins semantics.
//
//  Dependencies: APIClientProtocol / APIEndpoint, all Data/Models/*Entity
//                types, ModelContext.
//
//  Key concepts: Runs on @MainActor because ModelContext is main-actor-
//                isolated. Per-entity apply methods compare the incoming
//                updated_at_ms against the local row; if the local row is
//                newer-or-equal, the remote is dropped (LWW rule). Reviews
//                are append-only: an existing row causes the incoming row
//                to be ignored entirely. Response bodies are decoded via a
//                small AnyCodable shim so heterogeneous JSON values
//                survive decoding into [String: Any].
//

import Foundation
import SwiftData

/// Decoded response body for GET /api/v1/sync/pull.
public struct SyncPullResponse: Decodable, Sendable {
    /// Server wall-clock timestamp (ms since epoch) at the time the response was generated.
    public let serverClockMs: Int64
    /// Entity records keyed by entity name, each row encoded as a field→value dictionary.
    public let records: [String: [[String: AnyCodable]]]
    /// True when additional pages are available for this cursor range.
    public let hasMore: Bool?
    /// Cursor to supply as `since` on the next page request, or nil when no more pages.
    public let nextSince: Int64?
}

/// Type-erased decodable wrapper that lets us decode heterogeneous JSON values
/// (string, int, double, bool, null, dict, list) into a single type suitable
/// for dictionary interop.
///
/// `@unchecked Sendable` is required because `Any` cannot be statically
/// proven Sendable. In practice the only values stored here are JSON
/// primitives (String, Int64, Double, Bool, NSNull, or collections of
/// those), all of which are safe to cross concurrency boundaries.
public struct AnyCodable: Codable, @unchecked Sendable {
    /// Decoded JSON value: String, Int64, Double, Bool, [Any], [String: Any], or NSNull.
    public let value: Any

    /// Decode the next single-value container, trying primitives, dict, list, null in order.
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self.value = NSNull()
            return
        }
        if let v = try? c.decode(Int64.self) {
            self.value = v
            return
        }
        if let v = try? c.decode(Double.self) {
            self.value = v
            return
        }
        if let v = try? c.decode(Bool.self) {
            self.value = v
            return
        }
        if let v = try? c.decode(String.self) {
            self.value = v
            return
        }
        if let v = try? c.decode([String: AnyCodable].self) {
            self.value = v.mapValues(\.value)
            return
        }
        if let v = try? c.decode([AnyCodable].self) {
            self.value = v.map(\.value)
            return
        }
        throw DecodingError.dataCorruptedError(
            in: c, debugDescription: "AnyCodable: unsupported JSON value"
        )
    }

    /// No-op: AnyCodable is decode-only (sync pull never serialises back).
    public func encode(to encoder: Encoder) throws {
        // Decode-only — sync pull is GET, we never serialise AnyCodable back.
    }
}

/// Applies /v1/sync/pull records onto local SwiftData models with LWW.
///
/// All work happens on the main actor because it mutates ModelContext.
@MainActor
public final class SyncPuller {
    private let context: ModelContext
    private let api: APIClientProtocol

    /// Creates the puller wrapping the given ModelContext and API client.
    public init(context: ModelContext, api: APIClientProtocol) {
        self.context = context
        self.api = api
    }

    /// Pull records for the given entity keys changed after `since`.
    ///
    /// - Parameters:
    ///   - entities: Wire-format entity keys (e.g. ["topics", "decks"]).
    ///   - since: Millisecond cursor; only records updated after this are fetched.
    /// - Throws: Any `APIError` or SwiftData save error.
    public func pull(entities: [String], since: Int64) async throws {
        let csv = entities.joined(separator: ",")
        let path = "/api/v1/sync/pull?since=\(since)&entities=\(csv)"

        let resp: SyncPullResponse = try await api.send(
            APIEndpoint<SyncPullResponse>(
                method: "GET", path: path, body: nil, requiresAuth: true
            ))

        for (entityKey, rows) in resp.records {
            let rawRows: [[String: Any]] = rows.map { $0.mapValues(\.value) }
            try apply(entityKey: entityKey, rows: rawRows)
        }
        try context.save()
    }

    private func apply(entityKey: String, rows: [[String: Any]]) throws {
        switch entityKey {
        case "topics": try applyTopics(rows)
        case "decks": try applyDecks(rows)
        case "sub_topics": try applySubTopics(rows)
        case "cards": try applyCards(rows)
        case "card_sub_topics": try applyCardSubTopics(rows)
        case "reviews": try applyReviews(rows)
        case "sessions": try applySessions(rows)
        default: return
        }
    }

    // MARK: - Per-entity apply

    private func applyTopics(_ rows: [[String: Any]]) throws {
        for row in rows {
            guard let id = row["id"] as? String else { continue }
            let incoming = row["updated_at_ms"] as? Int64 ?? 0
            let descriptor = FetchDescriptor<TopicEntity>(
                predicate: #Predicate { $0.id == id }
            )
            if let existing = try context.fetch(descriptor).first {
                if existing.syncUpdatedAtMs >= incoming { continue }
                try existing.applyRemote(row)
            } else {
                let t = TopicEntity(
                    id: id,
                    userId: (row["user_id"] as? String) ?? "",
                    name: (row["name"] as? String) ?? "",
                    syncUpdatedAtMs: incoming
                )
                context.insert(t)
                try t.applyRemote(row)
            }
        }
    }

    private func applyDecks(_ rows: [[String: Any]]) throws {
        for row in rows {
            guard let id = row["id"] as? String else { continue }
            let incoming = row["updated_at_ms"] as? Int64 ?? 0
            let descriptor = FetchDescriptor<DeckEntity>(
                predicate: #Predicate { $0.id == id }
            )
            if let existing = try context.fetch(descriptor).first {
                if existing.syncUpdatedAtMs >= incoming { continue }
                try existing.applyRemote(row)
            } else {
                let d = DeckEntity(
                    id: id,
                    userId: (row["user_id"] as? String) ?? "",
                    title: (row["title"] as? String) ?? "",
                    syncUpdatedAtMs: incoming
                )
                context.insert(d)
                try d.applyRemote(row)
            }
        }
    }

    private func applySubTopics(_ rows: [[String: Any]]) throws {
        for row in rows {
            guard let id = row["id"] as? String else { continue }
            let incoming = row["updated_at_ms"] as? Int64 ?? 0
            let descriptor = FetchDescriptor<SubTopicEntity>(
                predicate: #Predicate { $0.id == id }
            )
            if let existing = try context.fetch(descriptor).first {
                if existing.syncUpdatedAtMs >= incoming { continue }
                try existing.applyRemote(row)
            } else {
                let s = SubTopicEntity(
                    id: id,
                    deckId: (row["deck_id"] as? String) ?? "",
                    name: (row["name"] as? String) ?? "",
                    position: (row["position"] as? Int) ?? 0,
                    syncUpdatedAtMs: incoming
                )
                context.insert(s)
                try s.applyRemote(row)
            }
        }
    }

    private func applyCards(_ rows: [[String: Any]]) throws {
        for row in rows {
            guard let id = row["id"] as? String else { continue }
            let incoming = row["updated_at_ms"] as? Int64 ?? 0
            let descriptor = FetchDescriptor<CardEntity>(
                predicate: #Predicate { $0.id == id }
            )
            if let existing = try context.fetch(descriptor).first {
                if existing.syncUpdatedAtMs >= incoming { continue }
                try existing.applyRemote(row)
            } else {
                let c = CardEntity(
                    id: id,
                    deckId: (row["deck_id"] as? String) ?? "",
                    frontText: (row["front_text"] as? String) ?? "",
                    backText: (row["back_text"] as? String) ?? "",
                    syncUpdatedAtMs: incoming
                )
                context.insert(c)
                try c.applyRemote(row)
            }
        }
    }

    private func applyCardSubTopics(_ rows: [[String: Any]]) throws {
        for row in rows {
            guard let id = row["id"] as? String else { continue }
            let incoming = row["updated_at_ms"] as? Int64 ?? 0
            let descriptor = FetchDescriptor<CardSubTopicEntity>(
                predicate: #Predicate { $0.id == id }
            )
            if let existing = try context.fetch(descriptor).first {
                if existing.syncUpdatedAtMs >= incoming { continue }
                try existing.applyRemote(row)
            } else {
                let j = CardSubTopicEntity(
                    id: id,
                    cardId: (row["card_id"] as? String) ?? "",
                    subTopicId: (row["sub_topic_id"] as? String) ?? "",
                    syncUpdatedAtMs: incoming
                )
                context.insert(j)
                try j.applyRemote(row)
            }
        }
    }

    private func applyReviews(_ rows: [[String: Any]]) throws {
        for row in rows {
            guard let id = row["id"] as? String else { continue }
            let descriptor = FetchDescriptor<ReviewEntity>(
                predicate: #Predicate { $0.id == id }
            )
            if try context.fetch(descriptor).first != nil {
                continue  // append-only
            }
            let r = ReviewEntity(
                id: id,
                cardId: (row["card_id"] as? String) ?? "",
                userId: (row["user_id"] as? String) ?? "",
                rating: (row["rating"] as? Int) ?? 3,
                ratedAtMs: (row["rated_at_ms"] as? Int64) ?? 0,
                stateBefore: (row["state_before"] as? [String: Any]) ?? [:],
                stateAfter: (row["state_after"] as? [String: Any]) ?? [:],
                syncUpdatedAtMs: (row["updated_at_ms"] as? Int64) ?? 0
            )
            context.insert(r)
        }
    }

    private func applySessions(_ rows: [[String: Any]]) throws {
        for row in rows {
            guard let id = row["id"] as? String else { continue }
            let incoming = row["updated_at_ms"] as? Int64 ?? 0
            let descriptor = FetchDescriptor<SessionEntity>(
                predicate: #Predicate { $0.id == id }
            )
            if let existing = try context.fetch(descriptor).first {
                if existing.syncUpdatedAtMs >= incoming { continue }
                try existing.applyRemote(row)
            } else {
                let s = SessionEntity(
                    id: id,
                    userId: (row["user_id"] as? String) ?? "",
                    deckId: (row["deck_id"] as? String) ?? "",
                    mode: (row["mode"] as? String) ?? "smart",
                    startedAtMs: (row["started_at_ms"] as? Int64) ?? 0,
                    syncUpdatedAtMs: incoming
                )
                context.insert(s)
                try s.applyRemote(row)
            }
        }
    }
}
