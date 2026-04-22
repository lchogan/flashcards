/// TopicRepository.swift
///
/// SwiftData CRUD for user-owned topics. Minimal surface for v1 — create + list.
///
/// Dependencies: SwiftData, Foundation, TopicEntity, MutationQueue, Clock, UUIDv7.

import Foundation
import SwiftData

/// Topic CRUD scoped to one user.
@MainActor
public final class TopicRepository {
    private let context: ModelContext

    public init(context: ModelContext) { self.context = context }

    public func create(userId: String, name: String) throws -> TopicEntity {
        let topic = TopicEntity(
            id: UUIDv7.next(),
            userId: userId,
            name: name,
            syncUpdatedAtMs: Clock.nowMs()
        )
        context.insert(topic)
        try context.save()
        try MutationQueue(context: context).enqueue(
            entityKey: TopicEntity.syncEntityKey,
            recordId: topic.id,
            payload: topic.syncPayload()
        )
        return topic
    }

    public func list(userId: String) throws -> [TopicEntity] {
        try context.fetch(FetchDescriptor<TopicEntity>(
            predicate: #Predicate { $0.userId == userId && $0.syncDeletedAtMs == nil },
            sortBy: [SortDescriptor(\.name)]
        ))
    }
}
