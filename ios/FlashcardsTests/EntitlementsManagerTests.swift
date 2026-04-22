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
        let mgr = await makeManager(snapshot: snapshot(freeDefaults()))
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
        let mgr = await makeManager(snapshot: snapshot(freeDefaults()))
        await mgr.load()

        XCTAssertTrue(mgr.can(.decksCreate, currentCount: 2).allowed)
    }

    func testAllowStudySmart_whenBooleanTrue() async {
        let mgr = await makeManager(snapshot: snapshot(freeDefaults()))
        await mgr.load()

        XCTAssertTrue(mgr.can(.studySmart).allowed)
    }

    func testDenyImagesUse_whenBooleanFalse() async {
        let mgr = await makeManager(snapshot: snapshot(freeDefaults()))
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
        let mgr = await makeManager(
            snapshot: snapshot([
                "decks.create": EntitlementConfig(type: "max_count", max: 5, allowed: nil)
            ]))
        await mgr.load()

        XCTAssertFalse(mgr.can(.remindersAdd).allowed)
    }

    func testUnlimitedMax_allowsAnyCount() async {
        let mgr = await makeManager(
            snapshot: snapshot([
                "decks.create": EntitlementConfig(type: "max_count", max: nil, allowed: nil)
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

    private func makeManager(snapshot snap: PlanSnapshot) async -> EntitlementsManager {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let cache = PlansCache(defaults: defaults)
        await cache.store(snap)
        let api = StubAPIEntitlements(response: encode(snap))
        return EntitlementsManager(api: api, cache: cache)
    }

    private func encode(_ snapshot: PlanSnapshot) -> String {
        // Manually build the wire shape so the stub returns the same data the
        // test seeded — otherwise the network-refresh step in load() overwrites
        // the cached snapshot with an empty one.
        var ent: [String: [String: Any]] = [:]
        for (key, cfg) in snapshot.entitlements {
            var row: [String: Any] = ["type": cfg.type]
            if let max = cfg.max { row["max"] = max }
            if let allowed = cfg.allowed { row["allowed"] = allowed }
            ent[key] = row
        }
        let payload: [String: Any] = [
            "plan_key": snapshot.planKey,
            "version": snapshot.version,
            "entitlements": ent,
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        return String(data: data, encoding: .utf8)!
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
