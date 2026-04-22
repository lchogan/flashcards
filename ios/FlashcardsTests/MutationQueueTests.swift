/// MutationQueueTests.swift
///
/// Unit tests for MutationQueue.  All tests run on the main actor so they can
/// interact directly with the SwiftData main context without crossing isolation
/// boundaries.
///
/// Dependencies: XCTest, SwiftData, Flashcards (testable)

import SwiftData
import XCTest

@testable import Flashcards

final class MutationQueueTests: XCTestCase {
    var container: ModelContainer!

    override func setUp() async throws {
        container = try ModelContainer(
            for: PendingMutationEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @MainActor
    func test_enqueue_persists_one_row() throws {
        let q = MutationQueue(context: container.mainContext)
        try q.enqueue(entityKey: "decks", recordId: "r1", payload: ["id": "r1", "title": "T"])
        XCTAssertEqual(try q.pendingCount(), 1)
    }

    @MainActor
    func test_takeBatch_returnsDueAndNotFuture() throws {
        let q = MutationQueue(context: container.mainContext)
        try q.enqueue(entityKey: "decks", recordId: "r1", payload: ["id": "r1"])
        let m = try q.allPending().first!
        m.nextAttemptAtMs = Int64.max
        try container.mainContext.save()

        XCTAssertTrue(try q.takeBatch(now: 0, limit: 100).isEmpty)
    }

    @MainActor
    func test_backoff_schedule_increases() {
        XCTAssertEqual(MutationQueue.backoffMs(retry: 0), 2_000)
        XCTAssertEqual(MutationQueue.backoffMs(retry: 1), 8_000)
        XCTAssertEqual(MutationQueue.backoffMs(retry: 2), 30_000)
        XCTAssertEqual(MutationQueue.backoffMs(retry: 3), 120_000)
        XCTAssertEqual(MutationQueue.backoffMs(retry: 99), 900_000) // cap 15 min
    }

    @MainActor
    func test_markFailure_schedules_first_retry_at_2s() throws {
        let q = MutationQueue(context: container.mainContext)
        try q.enqueue(entityKey: "decks", recordId: "r1", payload: ["id": "r1"])
        let m = try q.allPending().first!
        try q.markFailure(m, now: 1_000)
        XCTAssertEqual(m.nextAttemptAtMs, 1_000 + 2_000)
        XCTAssertEqual(m.retryCount, 1)
    }

    @MainActor
    func test_markFailure_second_retry_is_8s() throws {
        let q = MutationQueue(context: container.mainContext)
        try q.enqueue(entityKey: "decks", recordId: "r1", payload: ["id": "r1"])
        let m = try q.allPending().first!
        try q.markFailure(m, now: 0)
        try q.markFailure(m, now: 10_000)
        XCTAssertEqual(m.nextAttemptAtMs, 10_000 + 8_000)
        XCTAssertEqual(m.retryCount, 2)
    }
}
