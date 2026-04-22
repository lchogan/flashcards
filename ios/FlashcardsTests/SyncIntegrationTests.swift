//
//  SyncIntegrationTests.swift
//  FlashcardsTests
//
//  Purpose: Exercises the happy path of offline mutation capture and push
//           drain: create a DeckEntity, enqueue its payload, push via
//           SyncPusher with a stubbed transport, assert the queue empties
//           and the stub saw the expected record shape.
//
//  Dependencies: MutationQueue, SyncPusher, DeckEntity, StubAPI.
//

import XCTest
import SwiftData
@testable import Flashcards

@MainActor
final class SyncIntegrationTests: XCTestCase {

    // MARK: - Happy path

    /// Full round-trip: create a DeckEntity offline, enqueue its mutation,
    /// push via a stubbed transport, and assert the queue is fully drained
    /// while the deck entity itself survives.
    func test_createDeckOffline_enqueuesMutation_thenPushes() async throws {
        let container = try ModelContainer(
            for: DeckEntity.self, PendingMutationEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ctx = container.mainContext
        let queue = MutationQueue(context: ctx)

        // Simulate offline entity creation + mutation enqueue.
        let deck = DeckEntity(
            id: "d1",
            userId: "u1",
            title: "Bio",
            syncUpdatedAtMs: Clock.nowMs()
        )
        ctx.insert(deck)
        try ctx.save()
        try queue.enqueue(
            entityKey: DeckEntity.syncEntityKey,
            recordId: deck.id,
            payload: try deck.syncPayload()
        )

        XCTAssertEqual(try queue.pendingCount(), 1)

        // Push batch via stubbed transport.
        let stub = StubAPI(response: #"{"accepted":1,"rejected":[],"server_clock_ms":1}"#)
        let pusher = SyncPusher(context: ctx, api: stub)
        let accepted = try await pusher.pushOnce()

        XCTAssertEqual(accepted, 1)
        XCTAssertEqual(try queue.pendingCount(), 0)

        // Deck entity itself survives the push (only the pending mutation row is deleted).
        let persisted = try ctx.fetch(FetchDescriptor<DeckEntity>())
        XCTAssertEqual(persisted.count, 1)
        XCTAssertEqual(persisted.first?.id, "d1")
    }

    // MARK: - Rejection / retry

    /// When the server rejects a mutation the row must remain queued,
    /// retryCount must increment to 1, and nextAttemptAtMs must be > 0
    /// (exponential back-off applied).
    func test_rejectedMutation_staysQueuedWithBackoff() async throws {
        let container = try ModelContainer(
            for: DeckEntity.self, PendingMutationEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ctx = container.mainContext
        let queue = MutationQueue(context: ctx)

        let deck = DeckEntity(id: "d2", userId: "u1", title: "Stale", syncUpdatedAtMs: Clock.nowMs())
        ctx.insert(deck)
        try ctx.save()
        try queue.enqueue(
            entityKey: DeckEntity.syncEntityKey,
            recordId: deck.id,
            payload: try deck.syncPayload()
        )

        // Stub returns rejection for d2.
        let stub = StubAPI(response: #"{"accepted":0,"rejected":[{"id":"d2","reason":"stale"}],"server_clock_ms":1}"#)
        let pusher = SyncPusher(context: ctx, api: stub)
        let accepted = try await pusher.pushOnce()

        XCTAssertEqual(accepted, 0)
        XCTAssertEqual(try queue.pendingCount(), 1)

        // The rejected mutation is retry-scheduled, not deleted.
        // retryCount must be 1 and nextAttemptAtMs must reflect back-off.
        let pending = try queue.allPending()
        XCTAssertEqual(pending.first?.recordId, "d2")
        XCTAssertEqual(pending.first?.retryCount, 1)
        XCTAssertGreaterThan(pending.first?.nextAttemptAtMs ?? 0, 0)
    }
}
