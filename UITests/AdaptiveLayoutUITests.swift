import XCTest

@MainActor
final class AdaptiveLayoutUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws { XCUIDevice.shared.orientation = .portrait }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitesting", "--reset-test-store", "--test-wear-fixture", "--test-photo-preview-fixture",
            "--test-document-fixture",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
        ]
        app.launch()
        XCTAssertTrue(app.buttons["collection.add"].waitForExistence(timeout: 15))
        return app
    }

    func testWatchSelectionAndPhotoSurviveRotation() {
        let app = launch()
        app.staticTexts["Photo watch"].tap()
        let photo = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "detail.photo.")).firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        photo.tap()
        XCTAssertTrue(app.images["photoPreview.image"].waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.images["photoPreview.image"].waitForExistence(timeout: 5))
        app.buttons["photoPreview.close"].tap()
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
    }

    func testUnsavedWatchDraftSurvivesRotation() {
        let app = launch()
        app.staticTexts["Photo watch"].tap()
        app.buttons["detail.edit"].tap()
        let model = app.textFields["editor.model"]
        focus(model, in: app)
        model.typeText(" Duo")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertEqual(model.value as? String, "Photo watch Duo")
        XCUIDevice.shared.orientation = .portrait
        XCTAssertEqual(model.value as? String, "Photo watch Duo")
    }

    func testWearSelectionSurvivesRotationAndDaysStayTappable() {
        let app = launch()
        app.staticTexts["Calendar watch"].tap()
        app.buttons["detail.wear"].tap()
        let addDays = app.buttons["wear.add"]
        XCTAssertTrue(addDays.waitForExistence(timeout: 5))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: addDays)
        wait(for: [ready], timeout: 5)
        addDays.tap()
        let initial = XCTAttachment(screenshot: app.screenshot())
        initial.name = "Wear editor before rotation"
        initial.lifetime = .keepAlways
        add(initial)
        let previous = app.buttons["wear.selection.month.previous"]
        XCTAssertTrue(previous.waitForExistence(timeout: 5))
        previous.tap()
        let days = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wear.selection.day."))
        let day = days.firstMatch
        if !day.isHittable { app.swipeUp() }
        XCTAssertGreaterThanOrEqual(day.frame.width, 44)
        XCTAssertGreaterThanOrEqual(day.frame.height, 44)
        day.tap()
        let save = app.buttons["wear.save"]
        XCTAssertTrue(save.isEnabled)
        let month = app.buttons["wear.selection.month.title"].label
        XCUIDevice.shared.orientation = .landscapeRight
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        let rotated = XCTAttachment(screenshot: app.screenshot())
        rotated.name = "Wear editor in landscape"
        rotated.lifetime = .keepAlways
        add(rotated)
        XCTAssertEqual(app.buttons["wear.selection.month.title"].label, month)
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: save)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed)
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(save.isEnabled)
        XCTAssertEqual(app.buttons["wear.selection.month.title"].label, month)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Calendar selection after resizing"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testUnsavedWishlistDraftSurvivesRotation() {
        let app = launch()
        app.tabBars.buttons["Wishlist"].tap()
        app.buttons["wish.add"].tap()
        let brand = app.textFields["wish.brand"]
        XCTAssertTrue(brand.waitForExistence(timeout: 5))
        brand.tap()
        brand.typeText("Duo test")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertEqual(brand.value as? String, "Duo test")
        XCUIDevice.shared.orientation = .portrait
        XCTAssertEqual(brand.value as? String, "Duo test")
        XCTAssertTrue(app.buttons["wish.save"].exists)
    }

    func testExistingWearEntryKeepsEditModeAfterRotation() {
        let app = launch()
        app.staticTexts["Calendar watch"].tap()
        app.buttons["detail.wear"].tap()
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let today = app.buttons["wear.day.\(formatter.string(from: Date()))"]
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        today.tap()
        let entry = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wear.log.")).firstMatch
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: entry)
        wait(for: [ready], timeout: 5)
        entry.tap()
        XCTAssertTrue(app.navigationBars["Edit wear day"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.datePickers.firstMatch.exists)
        XCUIDevice.shared.orientation = .landscapeRight
        XCTAssertTrue(app.navigationBars["Edit wear day"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["wear.save"].isEnabled)
        app.buttons["wear.save"].tap()
        XCTAssertTrue(app.buttons["wear.add"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wear.log.")).count, 1)
    }
}
