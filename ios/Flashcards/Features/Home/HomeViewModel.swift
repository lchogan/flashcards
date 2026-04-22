/// HomeViewModel.swift
///
/// Observable view model for HomeView: loads the user's non-deleted decks and
/// computes due-card counts per deck by running SessionQueueBuilder's smart
/// query with a zero new-card limit (just the due-queue portion).
///
/// Dependencies: SwiftData, Observation, DeckRepository, SessionQueueBuilder,
/// Clock.

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
public final class HomeViewModel {
    public var decks: [DeckEntity] = []
    public var dueCountsByDeck: [String: Int] = [:]
    public var isLoading = false

    private let deckRepo: DeckRepository
    private let queueBuilder: SessionQueueBuilder
    private let userId: String

    public init(context: ModelContext, userId: String) {
        self.deckRepo = DeckRepository(context: context)
        self.queueBuilder = SessionQueueBuilder(context: context)
        self.userId = userId
    }

    public func load() throws {
        isLoading = true
        defer { isLoading = false }
        decks = try deckRepo.liveDecksForUser(userId)
        let now = Clock.nowMs()
        for deck in decks {
            let dueCount = try queueBuilder
                .smartQueue(deckId: deck.id, now: now, dailyNewCardLimit: 0)
                .count
            dueCountsByDeck[deck.id] = dueCount
        }
    }
}
