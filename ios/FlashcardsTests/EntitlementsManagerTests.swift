//
//  EntitlementsManagerTests.swift
//  FlashcardsTests
//
//  Purpose: Verify EntitlementsManager gate logic end-to-end: boolean gates,
//           max_count caps, unknown-key deny, and cache-first boot.
//

import XCTest
@testable import Flashcards

@MainActor
final class EntitlementsManagerTests: XCTestCase {
    func testDenyDecksCreate_whenAtMax() async throws {
        let mgr = makeManager(cached: snapshot(freeDefaults()))
        await mgr.load()

        let result = mgr.can(.decksCreate, currentCount: 5)

        XCTAssertFalse(result.allowed)
        guard case .paywall(let reason, let limit) = result.outcome else {
            XCTFail("expected .paywall outcome")
            return
        }
        XCTAssertEqual(reason, .decksCreate)
        XCTAssertEqual(limit, 5)
    }

    func testAllowDecksCreate_whenBelowMax() async {
        let mgr = makeManager(cached: snapshot(freeDefaults()))
        await mgr.load()

        XCTAssertTrue(mgr.can(.decksCreate, currentCount: 2).allowed)
    }

    func testAllowStudySmart_whenBooleanTrue() async {
        let mgr = makeManager(cached: snapshot(freeDefaults()))
        await mgr.load()

        XCTAssertTrue(mgr.can(.studySmart).allowed)
    }

    func testDenyImagesUse_whenBooleanFalse() async {
        let mgr = makeManager(cached: snapshot(freeDefaults()))
        await mgr.load()

        let result = mgr.can(.imagesUse)
        XCTAssertFalse(result.allowed)
        if case .paywall(let reason, _) = result.outcome {
            XCTAssertEqual(reason, .imagesUse)
        } else {
            XCTFail("expected .paywall")
        }
    }

    func testUnknownKey_deniesByDefault() async {
        // Snapshot intentionally omits reminders.add.
        let mgr = makeManager(cached: snapshot([
            "decks.create": EntitlementConfig(type: "max_count", max: 5, allowed: nil),
        ]))
        await mgr.load()

        XCTAssertFalse(mgr.can(.remindersAdd).allowed)
    }

    func testUnlimitedMax_allowsAnyCount() async {
        let mgr = makeManager(cached: snapshot([
            "decks.create": EntitlementConfig(type: "max_count", max: nil, allowed: nil),
        ]))
        await mgr.load()

        XCTAssertTrue(mgr.can(.decksCreate, currentCount: 9999).allowed)
    }

    // MARK: - Helpers

    private func snapshot(_ ent: [String: EntitlementConfig]) -> PlanSnapshot {
        PlanSnapshot(planKey: "free", version: 1, entitlements: ent)
    }

    private func freeDefaults() -> [String: EntitlementConfig] {
        [
            "decks.create": EntitlementConfig(type: "max_count", max: 5, allowed: nil),
            "study.smart": EntitlementConfig(type: "boolean", max: nil, allowed: true),
            "images.use": EntitlementConfig(type: "boolean", max: nil, allowed: false),
        ]
    }

    private func makeManager(cached snap: PlanSnapshot) -> EntitlementsManager {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let cache = PlansCache(defaults: defaults)
        // Pre-populate cache. Since store() is actor-isolated we dispatch and
        // wait via semaphore; cleaner options aren't worth the extra surface.
        let done = DispatchSemaphore(value: 0)
        Task {
            await cache.store(snap)
            done.signal()
        }
        done.wait()
        let api = StubAPIEntitlements(response: #"{"plan_key":"free","version":1,"entitlements":{}}"#)
        return EntitlementsManager(api: api, cache: cache)
    }
}

private final class StubAPIEntitlements: APIClientProtocol, @unchecked Sendable {
    let response: String

    init(response: String) {
        self.response = response
    }

    func send<R>(_ endpoint: APIEndpoint<R>) async throws -> R where R: Decodable & Sendable {
        try JSONDecoder.api.decode(R.self, from: response.data(using: .utf8)!)
    }
}
