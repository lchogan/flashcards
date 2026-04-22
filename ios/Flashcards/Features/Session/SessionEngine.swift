/// SessionEngine.swift
///
/// Applies a single rating to a card during a study session: persists the Review,
/// updates the Card (Smart mode only), and enqueues both in the MutationQueue for
/// later sync. Basic mode records reviews without mutating FSRS state.
///
/// Dependencies: SwiftData, Foundation, FsrsScheduler, MutationQueue, UUIDv7.
/// Key concepts: the scheduler is a pure function of (card, rating, now) — side
/// effects (insert, save, enqueue) live here, not in FsrsScheduler.

import Foundation
import SwiftData

/// Which study mode the user selected. Determines whether FSRS state gets mutated.
public enum SessionMode: String, Codable, Sendable { case smart, basic }

/// Orchestrates a rating event end-to-end: Review + Card + sync enqueue.
@MainActor
public final class SessionEngine {
    private let context: ModelContext
    private let userId: String
    private let scheduler: FsrsScheduler
    private let sessionId: String

    public init(context: ModelContext, userId: String, scheduler: FsrsScheduler, sessionId: String) {
        self.context = context
        self.userId = userId
        self.scheduler = scheduler
        self.sessionId = sessionId
    }

    /// Records a rating for `card`. In Smart mode the card's FSRS state is advanced;
    /// in Basic mode only the reps/lastReviewedAtMs counters move.
    public func rate(card: CardEntity, rating: MWRating, at nowMs: Int64, mode: SessionMode) throws {
        let stateBefore = card.fsrsState()
        let stateAfter: FsrsScheduler.CardState =
            (mode == .smart)
            ? scheduler.applyReview(to: stateBefore, rating: rating, at: nowMs)
            : stateBefore

        let review = ReviewEntity(
            id: UUIDv7.next(),
            cardId: card.id,
            userId: userId,
            rating: rating.rawValue,
            ratedAtMs: nowMs,
            stateBefore: stateBefore.dict(),
            stateAfter: stateAfter.dict(),
            syncUpdatedAtMs: nowMs
        )
        review.sessionId = sessionId
        context.insert(review)

        if mode == .smart {
            card.stability = stateAfter.stability
            card.difficulty = stateAfter.difficulty
            card.state = stateAfter.state.rawValue
            card.lastReviewedAtMs = stateAfter.lastReviewedAtMs
            card.dueAtMs = stateAfter.dueAtMs
            card.reps = stateAfter.reps
            card.lapses = stateAfter.lapses
            card.syncUpdatedAtMs = nowMs
        } else {
            card.reps += 1
            card.lastReviewedAtMs = nowMs
            card.syncUpdatedAtMs = nowMs
        }

        try context.save()

        let q = MutationQueue(context: context)
        try q.enqueue(
            entityKey: ReviewEntity.syncEntityKey,
            recordId: review.id,
            payload: review.syncPayload()
        )
        try q.enqueue(
            entityKey: CardEntity.syncEntityKey,
            recordId: card.id,
            payload: card.syncPayload()
        )
    }
}

public extension CardEntity {
    /// Projects the card's persisted FSRS columns back into a value-type snapshot.
    func fsrsState() -> FsrsScheduler.CardState {
        FsrsScheduler.CardState(
            stability: stability,
            difficulty: difficulty,
            state: FsrsScheduler.State(rawValue: state) ?? .new,
            lastReviewedAtMs: lastReviewedAtMs,
            dueAtMs: dueAtMs,
            reps: reps,
            lapses: lapses
        )
    }
}

public extension FsrsScheduler.CardState {
    /// Serialises the snapshot to the snake_case wire shape for ReviewEntity.stateBefore/stateAfter.
    func dict() -> [String: Any] {
        [
            "stability": stability as Any,
            "difficulty": difficulty as Any,
            "state": state.rawValue,
            "last_reviewed_at_ms": lastReviewedAtMs as Any,
            "due_at_ms": dueAtMs as Any,
            "reps": reps,
            "lapses": lapses,
        ]
    }
}
