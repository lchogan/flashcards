import XCTest
import SwiftData
@testable import Flashcards

@MainActor
final class SessionEngineTests: XCTestCase {
    func test_rateGood_writesReview_updatesCard_enqueuesMutations() throws {
        let container = try ModelContainer(
            for: CardEntity.self, ReviewEntity.self, PendingMutationEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ctx = container.mainContext
        let card = CardEntity(id: "c1", deckId: "d1", frontText: "f", backText: "b", syncUpdatedAtMs: 0)
        ctx.insert(card)
        try ctx.save()

        let engine = SessionEngine(
            context: ctx,
            userId: "u1",
            scheduler: FsrsScheduler(weights: nil),
            sessionId: "s1"
        )

        try engine.rate(card: card, rating: .good, at: 1_000, mode: .smart)

        let reviews = try ctx.fetch(FetchDescriptor<ReviewEntity>())
        XCTAssertEqual(reviews.count, 1)
        XCTAssertEqual(reviews[0].cardId, "c1")
        XCTAssertEqual(reviews[0].rating, 3)

        XCTAssertNotEqual(card.state, "new")
        XCTAssertEqual(card.reps, 1)

        let pending = try MutationQueue(context: ctx).pendingCount()
        XCTAssertEqual(pending, 2)
    }

    func test_basicMode_writesReview_butDoesNotMutateCardState() throws {
        let container = try ModelContainer(
            for: CardEntity.self, ReviewEntity.self, PendingMutationEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ctx = container.mainContext
        let card = CardEntity(id: "c1", deckId: "d1", frontText: "f", backText: "b", syncUpdatedAtMs: 0)
        card.state = "review"
        card.stability = 4.0
        card.difficulty = 6.0
        ctx.insert(card)
        try ctx.save()

        let engine = SessionEngine(
            context: ctx,
            userId: "u1",
            scheduler: FsrsScheduler(weights: nil),
            sessionId: "s1"
        )
        try engine.rate(card: card, rating: .again, at: 1_000, mode: .basic)

        XCTAssertEqual(card.state, "review")
        XCTAssertEqual(card.stability, 4.0)
        XCTAssertEqual(card.difficulty, 6.0)

        let reviews = try ctx.fetch(FetchDescriptor<ReviewEntity>())
        XCTAssertEqual(reviews.count, 1)
    }
}
