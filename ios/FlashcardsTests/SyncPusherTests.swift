//
//  SyncPusherTests.swift
//  FlashcardsTests
//
//  Purpose: Unit tests for SyncPusher — verifies batch grouping, accepted/
//           rejected reconciliation, and empty-queue short-circuit.
//
//  Dependencies: XCTest, SwiftData, Flashcards (SyncPusher, MutationQueue,
//                PendingMutationEntity, APIClientProtocol, APIEndpoint).
//  Key concepts: In-memory SwiftData container keeps tests isolated and fast.
//                StubAPI returns canned JSON, bypassing real network I/O.
//

import XCTest
import SwiftData
@testable import Flashcards

@MainActor
final class SyncPusherTests: XCTestCase {

    // MARK: - Empty queue

    /// SyncPusher returns 0 immediately when there are no pending mutations.
    func test_push_emptyQueue_returnsZero() async throws {
        let container = try ModelContainer(
            for: PendingMutationEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let stub = StubAPI()
        let pusher = SyncPusher(context: container.mainContext, api: stub)

        let accepted = try await pusher.pushOnce()

        XCTAssertEqual(accepted, 0)
    }

    // MARK: - Successful batch

    /// Two mutations for different entity types are POSTed together; both are
    /// deleted from the queue after the server accepts them.
    func test_push_groupsByEntityAndSendsBatch() async throws {
        let container = try ModelContainer(
            for: PendingMutationEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let q = MutationQueue(context: container.mainContext)
        try q.enqueue(entityKey: "topics", recordId: "t1", payload: ["id": "t1"])
        try q.enqueue(entityKey: "decks",  recordId: "d1", payload: ["id": "d1"])

        let stub = StubAPI(response: #"{"accepted":2,"rejected":[],"server_clock_ms":0}"#)
        let pusher = SyncPusher(context: container.mainContext, api: stub)

        let accepted = try await pusher.pushOnce()

        XCTAssertEqual(accepted, 2)
        XCTAssertEqual(try q.pendingCount(), 0)
    }

    // MARK: - Partial rejection

    /// The server rejects one record ("d2") and accepts the other ("d1").
    /// The rejected record stays in the queue for retry; the accepted one is removed.
    func test_push_rejectedRowsAreRetryQueued() async throws {
        let container = try ModelContainer(
            for: PendingMutationEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let q = MutationQueue(context: container.mainContext)
        try q.enqueue(entityKey: "decks", recordId: "d1", payload: ["id": "d1"])
        try q.enqueue(entityKey: "decks", recordId: "d2", payload: ["id": "d2"])

        let stub = StubAPI(response: #"{"accepted":1,"rejected":[{"id":"d2","reason":"stale"}],"server_clock_ms":0}"#)
        let pusher = SyncPusher(context: container.mainContext, api: stub)

        let accepted = try await pusher.pushOnce()

        XCTAssertEqual(accepted, 1)
        // d2 remains in the queue, scheduled for retry
        XCTAssertEqual(try q.pendingCount(), 1)
    }
}

// MARK: - Helpers

/// Minimal `APIClientProtocol` stub. Returns the `response` JSON string
/// verbatim for every `send(_:)` call, regardless of endpoint.
final class StubAPI: APIClientProtocol, @unchecked Sendable {
    /// The raw JSON string returned by every `send(_:)` call.
    var response: String

    /// Creates a stub returning the given JSON.
    ///
    /// - Parameter response: Valid JSON matching the expected response type.
    init(response: String = #"{"accepted":0,"rejected":[],"server_clock_ms":0}"#) {
        self.response = response
    }

    func send<R>(_ endpoint: APIEndpoint<R>) async throws -> R where R: Decodable & Sendable {
        // Force-unwrap is intentional in tests: a bad stub JSON string is a
        // test authoring error, not a runtime edge case.
        try JSONDecoder.api.decode(R.self, from: response.data(using: .utf8)!)
    }
}
