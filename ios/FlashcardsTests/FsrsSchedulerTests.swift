import XCTest
@testable import Flashcards

final class FsrsSchedulerTests: XCTestCase {
    func test_firstReview_new_toLearning_onGood() {
        let sched = FsrsScheduler(weights: nil)
        let now: Int64 = 1_000
        let card = FsrsScheduler.CardState(
            stability: nil,
            difficulty: nil,
            state: .new,
            lastReviewedAtMs: nil,
            dueAtMs: nil,
            reps: 0,
            lapses: 0
        )

        let next = sched.applyReview(to: card, rating: .good, at: now)

        XCTAssertNotEqual(next.state, .new)
        XCTAssertNotNil(next.stability)
        XCTAssertNotNil(next.difficulty)
        XCTAssertGreaterThan(next.dueAtMs ?? 0, now)
    }

    func test_again_fromReview_toRelearning() {
        let sched = FsrsScheduler(weights: nil)
        let card = FsrsScheduler.CardState(
            stability: 10.0,
            difficulty: 6.0,
            state: .review,
            lastReviewedAtMs: 0,
            dueAtMs: 100,
            reps: 3,
            lapses: 0
        )
        let next = sched.applyReview(to: card, rating: .again, at: 200)
        XCTAssertEqual(next.state, .relearning)
        XCTAssertEqual(next.lapses, 1)
    }

    func test_intervalPreview_returnsFourCandidates() {
        let sched = FsrsScheduler(weights: nil)
        let card = FsrsScheduler.CardState(
            stability: 2.0,
            difficulty: 5.0,
            state: .review,
            lastReviewedAtMs: 0,
            dueAtMs: 100,
            reps: 1,
            lapses: 0
        )
        let preview = sched.intervalPreview(for: card, at: 100)
        XCTAssertEqual(preview.count, 4)
        XCTAssertLessThan(preview[.again]!, preview[.good]!)
        XCTAssertLessThan(preview[.good]!, preview[.easy]!)
    }
}
