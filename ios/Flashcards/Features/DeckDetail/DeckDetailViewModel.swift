/// DeckDetailViewModel.swift
///
/// Observable view model for the deck detail screen: loads the deck, its cards,
/// sub-topics, recent sessions, and due-count.
///
/// Dependencies: SwiftData, Observation, DeckEntity, CardEntity,
/// SubTopicEntity, SessionEntity, CardRepository, SubTopicRepository,
/// SessionQueueBuilder, Clock.

import Foundation
import Observation
import SwiftData

/// DeckDetailViewModel.
@MainActor
@Observable
public final class DeckDetailViewModel {
    /// deck.
    public var deck: DeckEntity?
    /// cards.
    public var cards: [CardEntity] = []
    /// subTopics.
    public var subTopics: [SubTopicEntity] = []
    /// recentSessions.
    public var recentSessions: [SessionEntity] = []
    /// dueCount.
    public var dueCount: Int = 0

    /// Exposed (non-private) so tab views can construct repositories against the
    /// same context without re-plumbing through the view tree.
    public let context: ModelContext
    private let deckId: String

    /// Creates a new instance.
    public init(context: ModelContext, deckId: String) {
        self.context = context
        self.deckId = deckId
    }

    /// load.
    public func load() throws {
        let targetId = deckId
        deck = try context.fetch(
            FetchDescriptor<DeckEntity>(
                predicate: #Predicate { $0.id == targetId }
            )
        ).first
        cards = try CardRepository(context: context).liveCards(deckId: deckId)
        subTopics = try SubTopicRepository(context: context).list(deckId: deckId)
        dueCount = try SessionQueueBuilder(context: context)
            .smartQueue(deckId: deckId, now: Clock.nowMs(), dailyNewCardLimit: 0)
            .count
        recentSessions = try context.fetch(
            FetchDescriptor<SessionEntity>(
                predicate: #Predicate { $0.deckId == targetId },
                sortBy: [SortDescriptor(\.startedAtMs, order: .reverse)]
            )
        ).prefix(20).map { $0 }
    }
}
