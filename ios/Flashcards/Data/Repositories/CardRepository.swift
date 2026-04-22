/// CardRepository.swift
///
/// SwiftData-backed card CRUD plus reset-progress. Creating a card optionally
/// seeds sub-topic join rows. Every mutating method enqueues sync pushes.
///
/// Dependencies: SwiftData, Foundation, CardEntity, CardSubTopicEntity,
/// MutationQueue, Clock, UUIDv7.

import Foundation
import SwiftData

/// Card CRUD that keeps position ordering and sync queue in sync.
@MainActor
public final class CardRepository {
    private let context: ModelContext

    /// Creates a new instance.
    public init(context: ModelContext) { self.context = context }

    /// create(deckId:frontText:backText:subTopicIds:.
    public func create(
        deckId: String,
        frontText: String,
        backText: String,
        subTopicIds: [String] = []
    ) throws -> CardEntity {
        let now = Clock.nowMs()
        let nextPos = try maxPosition(deckId: deckId) + 1
        let card = CardEntity(
            id: UUIDv7.next(),
            deckId: deckId,
            frontText: frontText,
            backText: backText,
            syncUpdatedAtMs: now
        )
        card.position = nextPos
        context.insert(card)

        let queue = MutationQueue(context: context)
        try queue.enqueue(
            entityKey: CardEntity.syncEntityKey,
            recordId: card.id,
            payload: card.syncPayload()
        )

        for subTopicId in subTopicIds {
            let join = CardSubTopicEntity(
                id: UUIDv7.next(),
                cardId: card.id,
                subTopicId: subTopicId,
                syncUpdatedAtMs: now
            )
            context.insert(join)
            try queue.enqueue(
                entityKey: CardSubTopicEntity.syncEntityKey,
                recordId: join.id,
                payload: join.syncPayload()
            )
        }
        try context.save()
        return card
    }

    /// update(_:apply:.
    public func update(_ card: CardEntity, apply: (CardEntity) -> Void) throws {
        apply(card)
        card.syncUpdatedAtMs = Clock.nowMs()
        try context.save()
        try MutationQueue(context: context).enqueue(
            entityKey: CardEntity.syncEntityKey,
            recordId: card.id,
            payload: card.syncPayload()
        )
    }

    /// softDelete(_:.
    public func softDelete(_ card: CardEntity) throws {
        let now = Clock.nowMs()
        card.syncDeletedAtMs = now
        card.syncUpdatedAtMs = now
        try context.save()
        try MutationQueue(context: context).enqueue(
            entityKey: CardEntity.syncEntityKey,
            recordId: card.id,
            payload: card.syncPayload()
        )
    }

    /// liveCards(deckId:.
    public func liveCards(deckId: String) throws -> [CardEntity] {
        try context.fetch(
            FetchDescriptor<CardEntity>(
                predicate: #Predicate { $0.deckId == deckId && $0.syncDeletedAtMs == nil },
                sortBy: [SortDescriptor(\.position)]
            ))
    }

    /// resetProgress(_:.
    public func resetProgress(_ card: CardEntity) throws {
        try update(card) { instance in
            instance.stability = nil
            instance.difficulty = nil
            instance.state = "new"
            instance.dueAtMs = nil
            instance.lastReviewedAtMs = nil
            instance.reps = 0
            instance.lapses = 0
        }
    }

    private func maxPosition(deckId: String) throws -> Int {
        let all = try context.fetch(
            FetchDescriptor<CardEntity>(
                predicate: #Predicate { $0.deckId == deckId }
            ))
        return all.map(\.position).max() ?? -1
    }
}
