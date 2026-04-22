//
//  AppStateTests.swift
//  FlashcardsTests
//
//  Purpose: Guard the default values of `AppState` so a future edit can't
//           silently change what a fresh instance looks like at launch.
//  Dependencies: XCTest, Flashcards module (`AppState`).
//  Key concepts: Cheap insurance — these defaults matter because the
//                onboarding and auth flows will key off them on first run.
//

import XCTest
@testable import Flashcards

final class AppStateTests: XCTestCase {
    /// A freshly constructed `AppState` should declare all four defaults we rely on
    /// at launch: auth is checking, tier is free, no prior sync, zero pending writes.
    func test_defaults_matchLaunchValues() {
        let state = AppState()

        XCTAssertEqual(state.authStatus, .checking)
        XCTAssertEqual(state.subscriptionTier, .free)
        XCTAssertNil(state.lastSyncAt)
        XCTAssertEqual(state.pendingMutationCount, 0)
    }
}
