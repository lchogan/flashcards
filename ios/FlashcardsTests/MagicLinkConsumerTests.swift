//
//  MagicLinkConsumerTests.swift
//  FlashcardsTests
//
//  Purpose: Lock in the URL-parsing contract of
//           `MagicLinkConsumer.extractToken(from:)`: only URLs whose
//           path ends with `/auth/consume` qualify, and the `t` query
//           parameter must be present.
//  Dependencies: XCTest, Flashcards module (`MagicLinkConsumer`).
//  Key concepts: Pure function under test — no stubs, no async. Cases
//                cover the happy path, wrong path, missing query item,
//                trailing slash in path, URL fragment, and a "contains
//                but does not end with" path that must be rejected.
//

import XCTest
@testable import Flashcards

final class MagicLinkConsumerTests: XCTestCase {
    func test_extractsTokenFromValidURL() {
        let url = URL(string: "https://flashcards.app/auth/consume?t=abc123")!
        XCTAssertEqual(MagicLinkConsumer.extractToken(from: url), "abc123")
    }

    func test_returnsNilForWrongPath() {
        let url = URL(string: "https://flashcards.app/other?t=abc")!
        XCTAssertNil(MagicLinkConsumer.extractToken(from: url))
    }

    func test_returnsNilWhenTokenMissing() {
        let url = URL(string: "https://flashcards.app/auth/consume")!
        XCTAssertNil(MagicLinkConsumer.extractToken(from: url))
    }

    func test_extractsTokenWithTrailingSlashInPath() {
        let url = URL(string: "https://flashcards.app/auth/consume/?t=xyz")!
        XCTAssertEqual(MagicLinkConsumer.extractToken(from: url), "xyz")
    }

    func test_extractsTokenWithURLFragment() {
        let url = URL(string: "https://flashcards.app/auth/consume?t=abc#section")!
        XCTAssertEqual(MagicLinkConsumer.extractToken(from: url), "abc")
    }

    func test_returnsNilForPathContainingButNotEndingWithAuthConsume() {
        let url = URL(string: "https://flashcards.app/auth/consume/extra?t=xyz")!
        XCTAssertNil(MagicLinkConsumer.extractToken(from: url))
    }
}
