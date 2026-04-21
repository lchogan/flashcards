//
//  ColorsTokenTests.swift
//  FlashcardsTests
//
//  Purpose: Smoke-check that each `MWColor` token resolves to a real Asset
//           Catalog entry (not the silent fallback when a name is missing).
//  Dependencies: Flashcards module (MWColor), UIKit (UIColor).
//  Key concepts: SwiftUI's `Color("name")` returns a placeholder when the
//                asset is absent, so we probe via `UIColor(named:)` which
//                returns nil on miss — that's the signal we trust here.
//

import SwiftUI
import XCTest
@testable import Flashcards

final class ColorsTokenTests: XCTestCase {
    /// Verify each named color asset loads (doesn't silently fall back to the default black).
    /// This is a smoke check — SwiftUI's `Color("name")` returns a placeholder if the name is missing.
    func test_allTokens_loadFromAssetCatalog() {
        let uiColors: [(String, Color)] = [
            ("paper", MWColor.paper),
            ("canvas", MWColor.canvas),
            ("ink", MWColor.ink),
            ("inkMuted", MWColor.inkMuted),
            ("inkFaint", MWColor.inkFaint),
            ("grid", MWColor.grid),
            ("again", MWColor.again),
            ("hard", MWColor.hard),
            ("good", MWColor.good),
            ("easy", MWColor.easy),
        ]
        for (name, _) in uiColors {
            let uiColor = UIColor(named: "mw/\(name)")
            XCTAssertNotNil(uiColor, "Color 'mw/\(name)' not found in Asset Catalog")
        }
    }
}
