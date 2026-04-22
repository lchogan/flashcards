/// SessionRootView.swift
///
/// Top-level study session host. Loads the deck, builds the queue from
/// SessionQueueBuilder, creates a SessionEntity, and swaps between
/// SmartStudyView / BasicStudyView per card. On completion shows
/// SessionSummaryView.
///
/// Dependencies: SwiftUI, SwiftData, DS, SessionQueueBuilder, SessionEngine,
/// SessionEntity, ReviewEntity, FsrsScheduler, Clock, UUIDv7, MutationQueue.

import SwiftData
import SwiftUI

struct SessionRootView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    let deckId: String
    let onDismiss: () -> Void

    @State private var deck: DeckEntity?
    @State private var session: SessionEntity?
    @State private var queue: [CardEntity] = []
    @State private var index = 0
    @State private var isShowingSummary = false

    var body: some View {
        MWScreen {
            if let deck, let session, !queue.isEmpty, index < queue.count {
                let card = queue[index]
                switch SessionMode(rawValue: deck.defaultStudyMode) ?? .smart {
                case .smart:
                    SmartStudyView(card: card, sessionId: session.id, onAdvance: advance)
                case .basic:
                    BasicStudyView(card: card, sessionId: session.id, onNext: advance)
                }
            } else if isShowingSummary, let session {
                SessionSummaryView(session: session, onDismiss: onDismiss)
            } else {
                ProgressView().task {
                    try? await start()
                    if queue.isEmpty {
                        // Nothing to study — skip straight to summary (0 cards).
                        finish()
                    }
                }
            }
        }
    }

    private func start() async throws {
        let targetId = deckId
        guard let loaded = try context.fetch(FetchDescriptor<DeckEntity>(
            predicate: #Predicate { $0.id == targetId }
        )).first else {
            return
        }
        deck = loaded
        let mode = SessionMode(rawValue: loaded.defaultStudyMode) ?? .smart
        let builder = SessionQueueBuilder(context: context)
        queue = try mode == .smart
            ? builder.smartQueue(deckId: loaded.id, now: Clock.nowMs(), dailyNewCardLimit: 10)
            : builder.basicQueue(deckId: loaded.id)

        let sessionEntity = SessionEntity(
            id: UUIDv7.next(),
            userId: currentUserId(),
            deckId: loaded.id,
            mode: mode.rawValue,
            startedAtMs: Clock.nowMs(),
            syncUpdatedAtMs: Clock.nowMs()
        )
        context.insert(sessionEntity)
        try context.save()
        session = sessionEntity
    }

    private func advance() {
        index += 1
        if index >= queue.count {
            finish()
        }
    }

    private func finish() {
        guard let session else {
            return
        }
        session.endedAtMs = Clock.nowMs()
        session.cardsReviewed = index
        let targetSessionId = session.id
        let reviews = (try? context.fetch(FetchDescriptor<ReviewEntity>(
            predicate: #Predicate { $0.sessionId == targetSessionId }
        ))) ?? []
        if !reviews.isEmpty {
            let positive = reviews.filter { $0.rating >= 3 }.count
            session.accuracyPct = Double(positive) / Double(reviews.count) * 100.0
        }
        session.syncUpdatedAtMs = Clock.nowMs()
        try? context.save()
        try? MutationQueue(context: context).enqueue(
            entityKey: SessionEntity.syncEntityKey,
            recordId: session.id,
            payload: session.syncPayload()
        )
        isShowingSummary = true
    }

    private func currentUserId() -> String {
        if case .authenticated(let id) = appState.authStatus {
            return id
        }
        return "anonymous"
    }
}
