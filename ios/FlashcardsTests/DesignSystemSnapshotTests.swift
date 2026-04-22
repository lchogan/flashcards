//
//  DesignSystemSnapshotTests.swift
//  FlashcardsTests
//
//  Purpose: Visual-regression baseline for the Modernist design-system atoms.
//           Pins the rendered appearance of `MWButton` (primary, light + dark),
//           `MWTextField`, and `MWCard` against reference PNGs under
//           `__Snapshots__/` so any future drift in a token, modifier, or
//           atom is caught at CI time.
//  Dependencies: swift-snapshot-testing (pointfreeco), SwiftUI + UIKit
//                (`UIHostingController` is UIKit), Flashcards module
//                (`@testable import Flashcards` exposes `MWButton`,
//                `MWTextField`, `mwCard()`, and the `StatefulPreviewWrapper`
//                helper introduced in Task 0.26).
//  Key concepts: The committed default is `isRecording = false` — record
//                mode is a one-shot local operation to regenerate the
//                reference PNGs, not a committed state. CI runs the tests
//                in verify mode; a pixel diff fails the build. Each test
//                renders through `UIHostingController` at a fixed
//                `ViewImageConfig.iPhone13Pro` so the image shape is stable
//                regardless of the simulator the test executes against.
//                The second button test passes `named: "dark"` so its
//                reference PNG coexists with the light-mode one.
//                Each test method is `@MainActor` — SwiftUI views and
//                `UIHostingController` are MainActor-isolated under Swift 6
//                strict concurrency, and the test body constructs both.
//

import SnapshotTesting
import SwiftUI
import UIKit
import XCTest
@testable import Flashcards

final class DesignSystemSnapshotTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Record once locally, then commit. CI runs in verify mode.
        isRecording = false
    }

    @MainActor
    func test_MWButton_primary_idle() {
        let view = MWButton("Continue") {}.frame(width: 340).padding()
        assertSnapshot(
            of: UIHostingController(rootView: view),
            as: .image(on: .iPhone13Pro)
        )
    }

    @MainActor
    func test_MWButton_primary_dark() {
        let view = MWButton("Continue") {}.frame(width: 340).padding()
            .environment(\.colorScheme, .dark)
        assertSnapshot(
            of: UIHostingController(rootView: view),
            as: .image(on: .iPhone13Pro),
            named: "dark"
        )
    }

    @MainActor
    func test_MWTextField() {
        let view = StatefulPreviewWrapper("user@example.com") { binding in
            MWTextField(label: "Email", text: binding, contentType: .emailAddress).padding()
        }.frame(width: 340)
        assertSnapshot(
            of: UIHostingController(rootView: view),
            as: .image(on: .iPhone13Pro)
        )
    }

    @MainActor
    func test_MWCard() {
        let view = Text("Card body").mwCard().frame(width: 340).padding()
        assertSnapshot(
            of: UIHostingController(rootView: view),
            as: .image(on: .iPhone13Pro)
        )
    }
}
