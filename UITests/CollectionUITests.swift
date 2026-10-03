import XCTest

@MainActor
final class CollectionUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testCreateEditPersistArchiveRestoreAndDelete() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-test-store", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["collection.add"].waitForExistence(timeout: 15))
        app.buttons["collection.add"].tap()
        XCTAssertFalse(app.buttons["editor.save"].isEnabled)
        focus(app.textFields["editor.brand"], in: app)
        app.textFields["editor.brand"].typeText("Seiko")
        focus(app.textFields["editor.model"], in: app)
        app.textFields["editor.model"].typeText("Prospex")
        app.buttons["editor.save"].tap()
        XCTAssertTrue(app.staticTexts["Prospex"].waitForExistence(timeout: 5))
        app.staticTexts["Prospex"].tap()
        app.buttons["detail.edit"].tap()
        let model = app.textFields["editor.model"]
        focus(model, in: app)
        model.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Prospex".count) + "Alpinist")
        app.buttons["editor.save"].tap()
        XCTAssertTrue(app.staticTexts["detail.model"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["detail.model"].label, "Seiko Alpinist")
        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-test-store" }
        app.launch()
        XCTAssertTrue(app.staticTexts["Alpinist"].waitForExistence(timeout: 10))
        app.staticTexts["Alpinist"].tap()
        reveal(app.buttons["detail.sell"], in: app)
        app.buttons["detail.sell"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.segmentedControls.buttons["Archive"].tap()
        app.staticTexts["Alpinist"].tap()
        reveal(app.buttons["detail.restore"], in: app)
        app.buttons["detail.restore"].tap()
        reveal(app.buttons["detail.delete"], in: app)
        app.buttons["detail.delete"].tap()
        // iOS 26 exposes nested button elements for the same confirmation action.
        let confirmation = app.buttons.matching(identifier: "confirm.delete").firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.tap()
        XCTAssertTrue(app.staticTexts["Archive is empty"].waitForExistence(timeout: 5))
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    func testPolishLocalizationAndCancel() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-test-store", "-AppleLanguages", "(pl)", "-AppleLocale", "pl_PL"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Kolekcja"].waitForExistence(timeout: 15))
        app.buttons["collection.add"].tap()
        XCTAssertTrue(app.textFields["editor.brand"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["editor.brand"].placeholderValue, "Marka")
        focus(app.textFields["editor.brand"], in: app)
        app.textFields["editor.brand"].typeText("Casio")
        app.buttons["Anuluj"].tap()
        XCTAssertTrue(app.buttons["collection.addFirst"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Casio"].exists)
    }
}

@MainActor extension XCTestCase {
    /// DeviceHub can expose transient scaled frames while an app/sheet is animating.
    /// Focus is verified through the keyboard before synthesizing text, rather than assuming a tap succeeded.
    func focus(_ field: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: field)
        wait(for: [ready], timeout: 5)
        field.tap()
        if !app.keyboards.firstMatch.waitForExistence(timeout: 3) {
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
    }
}
