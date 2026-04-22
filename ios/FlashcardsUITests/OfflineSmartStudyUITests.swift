import XCTest

/// End-to-end smart-study flow: launches the app with a stub auth identity
/// (see `UITestLaunch`), creates a deck, adds a card, rates it Good, and
/// verifies the session summary appears.
///
/// Requires the `-uiTestFreshInstall true` launch arg so `UITestLaunch.isActive`
/// returns true in the hosted app target — that short-circuits onboarding and
/// drops the user straight into HomeView.
final class OfflineSmartStudyUITests: XCTestCase {
    @MainActor
    func test_createDeckAndStudyOneCard_offline() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestFreshInstall", "true", "-offlineMode", "true"]
        app.launch()

        // Home
        XCTAssertTrue(app.staticTexts["Decks"].waitForExistence(timeout: 5))
        app.buttons["mw.home.create"].firstMatch.tap()

        // Create Deck
        let titleField = app.textFields["Title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        app.typeText("Greek roots")
        app.buttons["Create deck"].tap()

        // Open deck
        app.staticTexts["Greek roots"].firstMatch.tap()

        // Add card
        app.navigationBars.buttons.element(boundBy: 1).tap()
        let front = app.textViews.firstMatch
        front.tap()
        app.typeText("bios")
        // Tab to back field by tapping the second text view
        let textViews = app.textViews
        textViews.element(boundBy: 1).tap()
        app.typeText("life")
        app.buttons["Save"].tap()

        // Study
        app.buttons["Study now"].tap()

        // Flip + rate
        let card = app.otherElements["mw.session.card"]
        XCTAssertTrue(card.waitForExistence(timeout: 3))
        card.tap()
        app.buttons["Good"].firstMatch.tap()

        // Summary — Done button is the deterministic signal that the summary
        // screen rendered. The cards-reviewed text may be rendered beneath a
        // staticText that tests can't always enumerate.
        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10), "Session summary screen never appeared")
    }
}
