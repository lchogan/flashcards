/// DeckRepository.swift
///
/// SwiftData-backed deck CRUD + duplicate. Every mutating method enqueues a
/// corresponding sync push via MutationQueue so the server converges on the
/// same shape.
///
/// Dependencies: SwiftData, Foundation, DeckEntity, CardEntity, SubTopicEntity,
/// MutationQueue, Clock, UUIDv7, MWAccent, SessionMode.

import Foundation
import SwiftData

/// Deck CRUD + duplicate, always enqueueing a sync mutation on write.
@MainActor
public final class DeckRepository {
    private let context: ModelContext

    /// Creates a new instance.
    public init(context: ModelContext) { self.context = context }

    /// create(title:accentColor:userId:defaultStudyMode:topicId:description:.
    public func create(
        title: String,
        accentColor: MWAccent,
        userId: String,
        defaultStudyMode: SessionMode = .smart,
        topicId: String? = nil,
        description: String? = nil
    ) throws -> DeckEntity {
        let now = Clock.nowMs()
        let deck = DeckEntity(
            id: UUIDv7.next(),
            userId: userId,
            title: title,
            accentColor: accentColor.rawValue,
            defaultStudyMode: defaultStudyMode.rawValue,
            syncUpdatedAtMs: now
        )
        deck.topicId = topicId
        deck.deckDescription = description
        context.insert(deck)
        try context.save()
        try MutationQueue(context: context).enqueue(
            entityKey: DeckEntity.syncEntityKey,
            recordId: deck.id,
            payload: deck.syncPayload()
        )
        return deck
    }

    /// update(_:apply:.
    public func update(_ deck: DeckEntity, apply: (DeckEntity) -> Void) throws {
        apply(deck)
        deck.syncUpdatedAtMs = Clock.nowMs()
        try context.save()
        try MutationQueue(context: context).enqueue(
            entityKey: DeckEntity.syncEntityKey,
            recordId: deck.id,
            payload: deck.syncPayload()
        )
    }

    /// softDelete(_:.
    public func softDelete(_ deck: DeckEntity) throws {
        let now = Clock.nowMs()
        deck.syncDeletedAtMs = now
        deck.syncUpdatedAtMs = now
        try context.save()
        try MutationQueue(context: context).enqueue(
            entityKey: DeckEntity.syncEntityKey,
            recordId: deck.id,
            payload: deck.syncPayload()
        )
    }

    /// liveDecksForUser(_:.
    public func liveDecksForUser(_ userId: String) throws -> [DeckEntity] {
        try context.fetch(
            FetchDescriptor<DeckEntity>(
                predicate: #Predicate { $0.userId == userId && $0.syncDeletedAtMs == nil },
                sortBy: [SortDescriptor(\.lastStudiedAtMs, order: .reverse)]
            ))
    }

    /// Duplicates a deck, carrying cards and sub-topics but NOT FSRS state
    /// (per spec §10.3 — a duplicate is a fresh learning surface).
    public func duplicate(_ source: DeckEntity) throws -> DeckEntity {
        let copy = try create(
            title: "\(source.title) (copy)",
            accentColor: MWAccent(rawValue: source.accentColor) ?? .amber,
            userId: source.userId,
            defaultStudyMode: SessionMode(rawValue: source.defaultStudyMode) ?? .smart,
            topicId: source.topicId,
            description: source.deckDescription
        )
        try cloneCards(from: source.id, to: copy.id)
        try cloneSubTopics(from: source.id, to: copy.id)
        try context.save()
        return copy
    }

    private func cloneCards(from sourceId: String, to destId: String) throws {
        let cards = try context.fetch(
            FetchDescriptor<CardEntity>(
                predicate: #Predicate { $0.deckId == sourceId && $0.syncDeletedAtMs == nil }
            ))
        let queue = MutationQueue(context: context)
        for card in cards {
            let newCard = CardEntity(
                id: UUIDv7.next(),
                deckId: destId,
                frontText: card.frontText,
                backText: card.backText,
                syncUpdatedAtMs: Clock.nowMs()
            )
            newCard.position = card.position
            context.insert(newCard)
            try queue.enqueue(
                entityKey: CardEntity.syncEntityKey,
                recordId: newCard.id,
                payload: newCard.syncPayload()
            )
        }
    }

    private func cloneSubTopics(from sourceId: String, to destId: String) throws {
        let subs = try context.fetch(
            FetchDescriptor<SubTopicEntity>(
                predicate: #Predicate { $0.deckId == sourceId && $0.syncDeletedAtMs == nil }
            ))
        let queue = MutationQueue(context: context)
        for sub in subs {
            let newSub = SubTopicEntity(
                id: UUIDv7.next(),
                deckId: destId,
                name: sub.name,
                position: sub.position,
                syncUpdatedAtMs: Clock.nowMs()
            )
            context.insert(newSub)
            try queue.enqueue(
                entityKey: SubTopicEntity.syncEntityKey,
                recordId: newSub.id,
                payload: newSub.syncPayload()
            )
        }
    }
}
