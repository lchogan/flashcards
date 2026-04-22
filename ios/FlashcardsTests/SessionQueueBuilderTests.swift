import XCTest
import SwiftData
@testable import Flashcards

@MainActor
final class SessionQueueBuilderTests: XCTestCase {
    func test_smartQueue_prioritizesDueOverNew() throws {
        let container = try ModelContainer(
            for: CardEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ctx = container.mainContext

        let deckId = "d1"
        let now: Int64 = 10_000
        let dueOverdue = CardEntity(id: "c1", deckId: deckId, frontText: "d1", backText: "e1", syncUpdatedAtMs: 0)
        dueOverdue.state = "review"
        dueOverdue.dueAtMs = 5_000
        let newCard = CardEntity(id: "c2", deckId: deckId, frontText: "d2", backText: "e2", syncUpdatedAtMs: 0)
        newCard.state = "new"
        let futureCard = CardEntity(id: "c3", deckId: deckId, frontText: "d3", backText: "e3", syncUpdatedAtMs: 0)
        futureCard.state = "review"
        futureCard.dueAtMs = 20_000
        [dueOverdue, newCard, futureCard].forEach { ctx.insert($0) }
        try ctx.save()

        let builder = SessionQueueBuilder(context: ctx)
        let q = try builder.smartQueue(deckId: deckId, now: now, dailyNewCardLimit: 10)

        XCTAssertEqual(q.map(\.id), ["c1", "c2"])
    }

    func test_smartQueue_respectsNewLimit() throws {
        let container = try ModelContainer(
            for: CardEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ctx = container.mainContext

        for i in 0..<20 {
            let c = CardEntity(id: "c\(i)", deckId: "d", frontText: "f", backText: "b", syncUpdatedAtMs: 0)
            c.state = "new"
            c.position = i
            ctx.insert(c)
        }
        try ctx.save()

        let q = try SessionQueueBuilder(context: ctx)
            .smartQueue(deckId: "d", now: 0, dailyNewCardLimit: 5)

        XCTAssertEqual(q.count, 5)
    }

    func test_basicQueue_returnsAllCardsByPosition() throws {
        let container = try ModelContainer(
            for: CardEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ctx = container.mainContext
        for i in 0..<3 {
            let c = CardEntity(id: "c\(i)", deckId: "d", frontText: "\(i)", backText: "\(i)", syncUpdatedAtMs: 0)
            c.position = 2 - i
            ctx.insert(c)
        }
        try ctx.save()

        let q = try SessionQueueBuilder(context: ctx).basicQueue(deckId: "d")
        XCTAssertEqual(q.map(\.id), ["c2", "c1", "c0"])
    }
}
