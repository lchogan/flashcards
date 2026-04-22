import Foundation
import SwiftFSRS

/// Bridges the Flashcards domain (Int64-ms timestamps, nullable stability/difficulty,
/// MW-facing rating enum) to SwiftFSRS (Date, non-optional Doubles, library Rating).
///
/// Callers should never import `SwiftFSRS` directly — this wrapper is the single seam
/// where the underlying FSRS implementation can be swapped without touching callers.
public final class FsrsScheduler {
    public enum State: String, Codable, Sendable {
        case new, learning, review, relearning
    }

    public struct CardState: Equatable, Sendable {
        public var stability: Double?
        public var difficulty: Double?
        public var state: State
        public var lastReviewedAtMs: Int64?
        public var dueAtMs: Int64?
        public var reps: Int
        public var lapses: Int

        public init(
            stability: Double? = nil,
            difficulty: Double? = nil,
            state: State = .new,
            lastReviewedAtMs: Int64? = nil,
            dueAtMs: Int64? = nil,
            reps: Int = 0,
            lapses: Int = 0
        ) {
            self.stability = stability
            self.difficulty = difficulty
            self.state = state
            self.lastReviewedAtMs = lastReviewedAtMs
            self.dueAtMs = dueAtMs
            self.reps = reps
            self.lapses = lapses
        }
    }

    private let algorithm: FSRSAlgorithm
    private let scheduler: any Scheduler

    /// - Parameters:
    ///   - weights: FSRS parameter vector of length 17 or 19. `nil` → SwiftFSRS v5 defaults.
    ///   - useLongTerm: Use `LongTermScheduler` (no short-term intra-day steps) when `true`.
    public init(weights: [Double]? = nil, useLongTerm: Bool = false) {
        var algo = FSRSAlgorithm.v5
        if let w = weights {
            if w.count == 19 {
                algo.parameters = w
            } else if w.count == 17 {
                algo.parameters = w + [0.0, 0.0]
            }
        }
        self.algorithm = algo
        self.scheduler = (useLongTerm ? SchedulerType.longTerm : .shortTerm).implementation
    }

    /// Apply a rating to `card` at `nowMs`; returns the post-review CardState.
    ///
    /// `new/learning/relearning → review` transitions, difficulty/stability progression,
    /// and due-date scheduling are delegated to SwiftFSRS.
    public func applyReview(to card: CardState, rating: MWRating, at nowMs: Int64) -> CardState {
        let now = Self.date(fromMs: nowMs)
        let input = toLibraryCard(card, nowMs: nowMs)
        let review = scheduler.schedule(
            card: input,
            algorithm: algorithm,
            reviewRating: toLibraryRating(rating),
            reviewTime: now
        )
        return fromLibraryCard(review.postReviewCard)
    }

    /// Compute next-due deltas (in ms) for all four ratings at `nowMs`.
    public func intervalPreview(for card: CardState, at nowMs: Int64) -> [MWRating: Int64] {
        var preview: [MWRating: Int64] = [:]
        for rating in MWRating.allCases {
            let next = applyReview(to: card, rating: rating, at: nowMs)
            preview[rating] = (next.dueAtMs ?? nowMs) - nowMs
        }
        return preview
    }

    // MARK: - Bridging helpers

    private func toLibraryCard(_ c: CardState, nowMs: Int64) -> Card {
        Card(
            due: Self.date(fromMs: c.dueAtMs ?? nowMs),
            stability: c.stability ?? 0,
            difficulty: c.difficulty ?? 0,
            elapsedDays: 0,
            scheduledDays: 0,
            reps: c.reps,
            lapses: c.lapses,
            status: toLibraryStatus(c.state),
            lastReview: c.lastReviewedAtMs.map(Self.date(fromMs:))
        )
    }

    private func fromLibraryCard(_ c: Card) -> CardState {
        CardState(
            stability: c.stability,
            difficulty: c.difficulty,
            state: fromLibraryStatus(c.status),
            lastReviewedAtMs: c.lastReview.map(Self.ms(fromDate:)),
            dueAtMs: Self.ms(fromDate: c.due),
            reps: c.reps,
            lapses: c.lapses
        )
    }

    private func toLibraryStatus(_ s: State) -> Status {
        switch s {
        case .new: .new
        case .learning: .learning
        case .review: .review
        case .relearning: .relearning
        }
    }

    private func fromLibraryStatus(_ s: Status) -> State {
        switch s {
        case .new: .new
        case .learning: .learning
        case .review: .review
        case .relearning: .relearning
        }
    }

    private func toLibraryRating(_ r: MWRating) -> Rating {
        switch r {
        case .again: .again
        case .hard: .hard
        case .good: .good
        case .easy: .easy
        }
    }

    private static func date(fromMs ms: Int64) -> Date {
        Date(timeIntervalSince1970: Double(ms) / 1000.0)
    }

    private static func ms(fromDate d: Date) -> Int64 {
        Int64(d.timeIntervalSince1970 * 1000)
    }
}
