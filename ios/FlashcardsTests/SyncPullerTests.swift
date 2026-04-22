import XCTest
import SwiftData
@testable import Flashcards

@MainActor
final class SyncPullerTests: XCTestCase {
    func test_pull_appliesIncomingTopicRecord() async throws {
        let container = try ModelContainer(
            for: TopicEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let stub = StubAPI(response: """
        {
          "server_clock_ms": 1000,
          "records": {
            "topics": [
              {"id": "t1", "name": "Biology", "color_hint": null, "updated_at_ms": 1000, "deleted_at_ms": null}
            ]
          },
          "has_more": false,
          "next_since": 1000
        }
        """)
        let puller = SyncPuller(context: container.mainContext, api: stub)

        try await puller.pull(entities: ["topics"], since: 0)

        let all = try container.mainContext.fetch(FetchDescriptor<TopicEntity>())
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.name, "Biology")
    }

    func test_pull_lwwSkipsStaleRow() async throws {
        let container = try ModelContainer(
            for: TopicEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let existing = TopicEntity(id: "t1", userId: "u1", name: "Current", syncUpdatedAtMs: 2000)
        container.mainContext.insert(existing)
        try container.mainContext.save()

        let stub = StubAPI(response: """
        {
          "server_clock_ms": 1500,
          "records": {
            "topics": [
              {"id": "t1", "name": "Stale", "updated_at_ms": 1000, "deleted_at_ms": null}
            ]
          }
        }
        """)
        let puller = SyncPuller(context: container.mainContext, api: stub)

        try await puller.pull(entities: ["topics"], since: 0)

        let fetched = try container.mainContext.fetch(FetchDescriptor<TopicEntity>())
        XCTAssertEqual(fetched.first?.name, "Current")
    }

    func test_pull_reviewsAreAppendOnly() async throws {
        let container = try ModelContainer(
            for: ReviewEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let stub = StubAPI(response: """
        {
          "server_clock_ms": 1000,
          "records": {
            "reviews": [
              {"id":"r1","card_id":"c1","user_id":"u1","rating":3,"review_duration_ms":1000,"rated_at_ms":1000,"state_before":{"state":"new"},"state_after":{"state":"learning","stability":1.0},"scheduler_version":"fsrs-6","updated_at_ms":1000}
            ]
          }
        }
        """)
        let puller = SyncPuller(context: container.mainContext, api: stub)

        try await puller.pull(entities: ["reviews"], since: 0)

        let all = try container.mainContext.fetch(FetchDescriptor<ReviewEntity>())
        XCTAssertEqual(all.count, 1)

        // Second pull with same id should NOT create a duplicate.
        try await puller.pull(entities: ["reviews"], since: 0)
        let after = try container.mainContext.fetch(FetchDescriptor<ReviewEntity>())
        XCTAssertEqual(after.count, 1)
    }
}
