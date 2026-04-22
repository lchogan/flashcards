/// SessionQueueBuilder.swift
///
/// Builds the ordered list of cards for a study session. Two modes:
/// - `smartQueue` — due cards first, then new cards up to a daily limit (FSRS flow).
/// - `basicQueue` — all cards in `position` order (bulk drill flow).

import Foundation
import SwiftData

/// Fetches deck cards from SwiftData and orders them for a Smart or Basic session.
@MainActor
public final class SessionQueueBuilder {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// Due cards (most-overdue first), then new cards in position order up to `dailyNewCardLimit`.
    public func smartQueue(deckId: String, now: Int64, dailyNewCardLimit: Int) throws -> [CardEntity] {
        let due = try fetchDue(deckId: deckId, now: now)
        let new = try fetchNew(deckId: deckId, limit: dailyNewCardLimit)
        return due + new
    }

    /// Every non-deleted card in the deck, ordered by `position`.
    public func basicQueue(deckId: String) throws -> [CardEntity] {
        var descriptor = FetchDescriptor<CardEntity>(
            predicate: #Predicate { $0.deckId == deckId && $0.syncDeletedAtMs == nil },
            sortBy: [SortDescriptor(\.position)]
        )
        descriptor.fetchLimit = 1000
        return try context.fetch(descriptor)
    }

    private func fetchDue(deckId: String, now: Int64) throws -> [CardEntity] {
        let sentinel: Int64 = 9_223_372_036_854_775_807 // Int64.max as a literal for #Predicate compatibility
        var descriptor = FetchDescriptor<CardEntity>(
            predicate: #Predicate {
                $0.deckId == deckId &&
                $0.syncDeletedAtMs == nil &&
                $0.state != "new" &&
                ($0.dueAtMs ?? sentinel) <= now
            },
            sortBy: [SortDescriptor(\.dueAtMs)]
        )
        descriptor.fetchLimit = 500
        return try context.fetch(descriptor)
    }

    private func fetchNew(deckId: String, limit: Int) throws -> [CardEntity] {
        var descriptor = FetchDescriptor<CardEntity>(
            predicate: #Predicate {
                $0.deckId == deckId &&
                $0.syncDeletedAtMs == nil &&
                $0.state == "new"
            },
            sortBy: [SortDescriptor(\.position)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }
}
