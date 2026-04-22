/// SubTopicRepository.swift
///
/// SwiftData CRUD for sub-topics scoped to a deck. Reorder re-indexes positions
/// atomically. Every mutation enqueues sync pushes.
///
/// Dependencies: SwiftData, Foundation, SubTopicEntity, MutationQueue,
/// Clock, UUIDv7.

import Foundation
import SwiftData

/// Sub-topic CRUD + reorder for a single deck.
@MainActor
public final class SubTopicRepository {
    private let context: ModelContext

    /// Creates a new instance.
    public init(context: ModelContext) { self.context = context }

    /// create(deckId:name:.
    public func create(deckId: String, name: String) throws -> SubTopicEntity {
        let pos = try maxPosition(deckId: deckId) + 1
        let subTopic = SubTopicEntity(
            id: UUIDv7.next(),
            deckId: deckId,
            name: name,
            position: pos,
            syncUpdatedAtMs: Clock.nowMs()
        )
        context.insert(subTopic)
        try context.save()
        try MutationQueue(context: context).enqueue(
            entityKey: SubTopicEntity.syncEntityKey,
            recordId: subTopic.id,
            payload: subTopic.syncPayload()
        )
        return subTopic
    }

    /// list(deckId:.
    public func list(deckId: String) throws -> [SubTopicEntity] {
        try context.fetch(
            FetchDescriptor<SubTopicEntity>(
                predicate: #Predicate { $0.deckId == deckId && $0.syncDeletedAtMs == nil },
                sortBy: [SortDescriptor(\.position)]
            ))
    }

    /// reorder(_:.
    public func reorder(_ subTopics: [SubTopicEntity]) throws {
        let now = Clock.nowMs()
        let queue = MutationQueue(context: context)
        for (idx, subTopic) in subTopics.enumerated() {
            subTopic.position = idx
            subTopic.syncUpdatedAtMs = now
            try queue.enqueue(
                entityKey: SubTopicEntity.syncEntityKey,
                recordId: subTopic.id,
                payload: subTopic.syncPayload()
            )
        }
        try context.save()
    }

    /// rename(_:to:.
    public func rename(_ subTopic: SubTopicEntity, to name: String) throws {
        subTopic.name = name
        subTopic.syncUpdatedAtMs = Clock.nowMs()
        try context.save()
        try MutationQueue(context: context).enqueue(
            entityKey: SubTopicEntity.syncEntityKey,
            recordId: subTopic.id,
            payload: subTopic.syncPayload()
        )
    }

    /// softDelete(_:.
    public func softDelete(_ subTopic: SubTopicEntity) throws {
        let now = Clock.nowMs()
        subTopic.syncDeletedAtMs = now
        subTopic.syncUpdatedAtMs = now
        try context.save()
        try MutationQueue(context: context).enqueue(
            entityKey: SubTopicEntity.syncEntityKey,
            recordId: subTopic.id,
            payload: subTopic.syncPayload()
        )
    }

    private func maxPosition(deckId: String) throws -> Int {
        try list(deckId: deckId).map(\.position).max() ?? -1
    }
}
