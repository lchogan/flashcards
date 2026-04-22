//
//  ControlTokenTests.swift
//  FlashcardsTests
//
//  Purpose: Lock the `MWControl.Height` spec values so any accidental drift
//           on the button trio's tap-target geometry fails fast.
//  Dependencies: Flashcards module (MWControl), XCTest.
//  Key concepts: 52pt is the dominant CTA height shared by primary/secondary;
//                44pt is the Apple Human Interface minimum tap target, used
//                for the text-link-style destructive action. Both values are
//                contractual — snapshot baselines and layout math downstream
//                assume them.
//

import XCTest
@testable import Flashcards

final class ControlTokenTests: XCTestCase {
    /// Verify the height tokens resolve to the contractual pt values
    /// (52 for enclosed CTAs, 44 for compact/HIG-minimum controls).
    func test_heightTokens_haveExpectedValues() {
        XCTAssertEqual(MWControl.Height.primary, 52)
        XCTAssertEqual(MWControl.Height.compact, 44)
    }
}
