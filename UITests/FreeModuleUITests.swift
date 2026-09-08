import XCTest

@MainActor
final class FreeModuleUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-test-store", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + extra
        app.launch()
        return app
    }

    func testWishlistMoveCanBeCancelledThenCommittedAndWearPersists() {
        let app = launch()
        XCTAssertTrue(app.buttons["collection.add"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Wishlist"].tap()
        app.buttons["wish.add"].tap()
        XCTAssertFalse(app.buttons["wish.save"].isEnabled)
        app.textFields["wish.brand"].tap()
        app.textFields["wish.brand"].typeText("Casio")
        app.textFields["wish.model"].tap()
        app.textFields["wish.model"].typeText("G-Shock")
        app.buttons["wish.save"].tap()
        let actions = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wish.actions.")).firstMatch
        XCTAssertTrue(actions.waitForExistence(timeout: 5))
        actions.tap()
        app.buttons["wish.move"].tap()
        XCTAssertEqual(app.textFields["editor.brand"].value as? String, "Casio")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.textFields["editor.brand"].waitForNonExistence(timeout: 5))
        if !actions.isHittable { app.swipeDown() }
        actions.tap()
        app.buttons["wish.move"].tap()
        app.buttons["editor.save"].tap()
        XCTAssertTrue(app.staticTexts["Your next watch"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Collection"].tap()
        XCTAssertTrue(app.staticTexts["G-Shock"].waitForExistence(timeout: 5))
        app.staticTexts["G-Shock"].tap()
        let today = app.buttons["wear.today"]
        XCTAssertTrue(today.isHittable)
        today.tap()
        XCTAssertFalse(today.isEnabled)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let quick = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wear.quick.")).firstMatch
        XCTAssertFalse(quick.isEnabled)
        app.staticTexts["G-Shock"].tap()
        app.buttons["detail.wear"].tap()
        XCTAssertTrue(app.buttons["wear.add"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wear.log.")).count, 1)
        app.buttons["Done"].tap()
        app.tabBars.buttons["Wearing"].tap()
        XCTAssertTrue(app.staticTexts["1 day worn"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wear.log.")).count, 1)
        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-test-store" }
        app.launch()
        XCTAssertTrue(app.buttons["collection.add"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Wearing"].tap()
        XCTAssertTrue(app.staticTexts["1 day worn"].waitForExistence(timeout: 5))
    }

    func testEnabledLockHidesCollectionOnLaunch() {
        let app = launch(extra: ["--test-lock-enabled"])
        XCTAssertTrue(app.staticTexts["Collection locked"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["collection.add"].exists)
        XCTAssertFalse(app.tabBars.buttons["Collection"].exists)
        // System authentication runs in a separate protected process. Its outcomes
        // are covered by AppLockTests; this checks the app's actual privacy window.
    }

    func testDocumentPreviewEditCancelSaveAndDelete() {
        let app = launch(extra: ["--test-document-fixture"])
        XCTAssertTrue(app.staticTexts["Document watch"].waitForExistence(timeout: 15))
        app.staticTexts["Document watch"].tap()
        app.buttons["detail.documents"].tap()
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "document.")).firstMatch.tap()
        XCTAssertTrue(app.buttons["document.actions"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Private test document"].exists)
        app.buttons["document.actions"].tap()
        app.buttons["document.edit"].tap()
        let name = app.textFields["document.name"]
        name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Test invoice".count) + "Discarded")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Test invoice"].exists)
        app.buttons["document.actions"].tap()
        app.buttons["document.edit"].tap()
        name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Test invoice".count) + "Receipt")
        app.buttons["document.save"].tap()
        XCTAssertTrue(app.navigationBars["Receipt"].waitForExistence(timeout: 5))
        app.buttons["document.actions"].tap()
        app.buttons["document.delete"].tap()
        app.buttons.matching(identifier: "document.confirmDelete").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["No documents yet"].waitForExistence(timeout: 5))
    }
}
