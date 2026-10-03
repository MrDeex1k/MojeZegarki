import XCTest

@MainActor
final class FreeModuleUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments =
            ["--uitesting", "--reset-test-store", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + extra
        app.launch()
        return app
    }

    func testWishlistMoveCanBeCancelledThenCommittedAndWearPersists() {
        let app = launch()
        XCTAssertTrue(app.buttons["collection.add"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Wishlist"].tap()
        app.buttons["wish.add"].tap()
        XCTAssertFalse(app.buttons["wish.save"].isEnabled)
        focus(app.textFields["wish.brand"], in: app)
        app.textFields["wish.brand"].typeText("Casio")
        focus(app.textFields["wish.model"], in: app)
        app.textFields["wish.model"].typeText("G-Shock")
        app.buttons["wish.save"].tap()
        let actions = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wish.actions.")).firstMatch
        XCTAssertTrue(actions.waitForExistence(timeout: 5))
        actions.tap()
        app.buttons["wish.move"].tap()
        XCTAssertEqual(app.textFields["editor.brand"].value as? String, "Casio")
        let cancel = app.buttons["editor.cancel"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: cancel)
        wait(for: [ready], timeout: 5)
        cancel.tap()
        let dismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: app.textFields["editor.brand"])
        wait(for: [dismissed], timeout: 8)
        XCTAssertTrue(actions.waitForExistence(timeout: 5))
        let quickMove = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wish.quickMove."))
            .firstMatch
        XCTAssertTrue(quickMove.waitForExistence(timeout: 5))
        quickMove.tap()
        XCTAssertFalse(app.buttons["editor.save"].exists)
        XCTAssertTrue(app.staticTexts["Your next watch"].waitForExistence(timeout: 5))
        app.buttons["Show collection"].tap()
        XCTAssertTrue(app.staticTexts["G-Shock"].waitForExistence(timeout: 5))
        app.staticTexts["G-Shock"].tap()
        let today = app.buttons["wear.today"]
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        XCTAssertTrue(today.isHittable)
        today.tap()
        let disabled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == false"),
            object: today
        )
        wait(for: [disabled], timeout: 5)
        XCTAssertFalse(today.isEnabled)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let quick = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wear.quick.")).firstMatch
        XCTAssertFalse(quick.isEnabled)
        app.staticTexts["G-Shock"].tap()
        app.buttons["detail.wear"].tap()
        let month = app.buttons["wear.month.title"]
        XCTAssertTrue(month.waitForExistence(timeout: 5))
        let currentMonth = month.label
        XCTAssertFalse(app.buttons["wear.month.next"].isEnabled)
        app.buttons["wear.month.previous"].tap()
        XCTAssertNotEqual(month.label, currentMonth)
        app.buttons["wear.month.next"].tap()
        XCTAssertEqual(month.label, currentMonth)
        let dayFormatter = DateFormatter()
        dayFormatter.calendar = Calendar(identifier: .gregorian)
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.dateFormat = "yyyy-MM-dd"
        let todayID = "wear.day.\(dayFormatter.string(from: Date()))"
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wear.log.")).count, 0)
        app.buttons[todayID].tap()
        let logs = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wear.log."))
        for _ in 0..<3 where !logs.firstMatch.isHittable { app.swipeUp() }
        XCTAssertTrue(app.buttons["wear.add"].exists)
        XCTAssertEqual(logs.count, 1)
        app.buttons["Done"].tap()
        app.tabBars.buttons["Wearing"].tap()
        XCTAssertTrue(app.staticTexts["1 day worn"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wear.log.")).count, 0)
        app.buttons[todayID].tap()
        app.swipeUp()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wear.log.")).count, 1)
        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-test-store" }
        app.launch()
        XCTAssertTrue(app.buttons["collection.add"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Wearing"].tap()
        XCTAssertTrue(app.staticTexts["1 day worn"].waitForExistence(timeout: 5))
        app.buttons["wear.statistics"].tap()
        XCTAssertTrue(app.segmentedControls["stats.period"].waitForExistence(timeout: 5))
        app.segmentedControls["stats.period"].buttons["All time"].tap()
        XCTAssertTrue(app.staticTexts["Share of recorded days"].exists)
        XCTAssertTrue(app.buttons["stats.watch"].exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["wear.statistics"].waitForExistence(timeout: 5))
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
        focus(name, in: app)
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Test invoice".count) + "Discarded")
        app.buttons["Cancel"].tap()
        app.buttons["Discard changes"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Test invoice"].exists)
        app.buttons["document.actions"].tap()
        app.buttons["document.edit"].tap()
        focus(name, in: app)
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Test invoice".count) + "Receipt")
        app.buttons["document.save"].tap()
        XCTAssertTrue(app.navigationBars["Receipt"].waitForExistence(timeout: 5))
        app.buttons["document.actions"].tap()
        app.buttons["document.delete"].tap()
        app.buttons.matching(identifier: "document.confirmDelete").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["No documents yet"].waitForExistence(timeout: 5))
    }
    func testCalendarShowsSavedDaysAndCountsOnlyNewSelection() {
        let app = launch(extra: ["--test-wear-fixture"])
        XCTAssertTrue(app.staticTexts["Calendar watch"].waitForExistence(timeout: 15))
        app.staticTexts["Calendar watch"].tap()
        app.buttons["detail.wear"].tap()
        app.buttons["wear.add"].tap()
        XCTAssertTrue(app.buttons["wear.save"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["wear.save"].isEnabled)
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let today = app.buttons["wear.selection.day.\(formatter.string(from: Date()))"]
        XCTAssertFalse(today.isEnabled)
        XCTAssertEqual(today.value as? String, "Already worn")
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        if Calendar.current.component(.day, from: Date()) == 1 { app.buttons["wear.selection.month.previous"].tap() }
        let previous = app.buttons["wear.selection.day.\(formatter.string(from: yesterday))"]
        previous.tap()
        XCTAssertTrue(app.buttons["wear.save"].isEnabled)
        XCTAssertEqual(app.staticTexts["wear.selectionCount"].label, "Selected days: 1")
        previous.tap()
        XCTAssertFalse(app.buttons["wear.save"].isEnabled)
        previous.tap()
        app.buttons["wear.save"].tap()
        XCTAssertTrue(app.alerts["Wear history updated"].waitForExistence(timeout: 5))
        app.alerts.buttons["OK"].tap()
        app.buttons["wear.add"].tap()
        if Calendar.current.component(.day, from: Date()) == 1 { app.buttons["wear.selection.month.previous"].tap() }
        XCTAssertFalse(previous.isEnabled)
        XCTAssertFalse(app.buttons["wear.save"].isEnabled)
    }

    func testMissingAndCorruptDocumentShowsRecoverableError() {
        for variant in [
            ["--test-missing-document"], ["--test-corrupt-document"],
            ["--test-image-document", "--test-corrupt-document"],
        ] {
            let app = launch(extra: ["--test-document-fixture"] + variant)
            XCTAssertTrue(app.staticTexts["Document watch"].waitForExistence(timeout: 15))
            app.staticTexts["Document watch"].tap()
            app.buttons["detail.documents"].tap()
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "document.")).firstMatch.tap()
            XCTAssertTrue(app.staticTexts["Document unavailable"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["document.actions"].isHittable)
            app.terminate()
        }
    }

    func testImageDocumentOpens() {
        let app = launch(extra: ["--test-document-fixture", "--test-image-document"])
        XCTAssertTrue(app.staticTexts["Document watch"].waitForExistence(timeout: 15))
        app.staticTexts["Document watch"].tap()
        app.buttons["detail.documents"].tap()
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "document.")).firstMatch.tap()
        XCTAssertTrue(app.images["Document preview"].waitForExistence(timeout: 5))
    }

    func testCalendarAppearanceAndLocalizationMatrix() {
        for locale in ["en", "pl"] {
            for dark in [false, true] {
                for large in [false, true] {
                    let app = XCUIApplication()
                    app.launchArguments = [
                        "--uitesting", "--reset-test-store", "--test-wear-fixture",
                        "-AppleLanguages", "(\(locale))", "-AppleLocale", locale == "pl" ? "pl_PL" : "en_US",
                        dark ? "--test-dark" : "--test-light", "-UIPreferredContentSizeCategoryName",
                        large ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL",
                    ]
                    app.launch()
                    XCTAssertTrue(app.buttons["collection.add"].waitForExistence(timeout: 15))
                    app.tabBars.buttons[locale == "pl" ? "Noszenie" : "Wearing"].tap()
                    XCTAssertTrue(app.buttons["wear.filter"].waitForExistence(timeout: 5))
                    XCTAssertTrue(app.buttons["wear.add"].isHittable)
                    let overview = XCTAttachment(screenshot: app.screenshot())
                    overview.name = "history-\(locale)-dark\(dark)-large\(large)"
                    overview.lifetime = .keepAlways
                    add(overview)
                    app.buttons["wear.add"].tap()
                    XCTAssertTrue(app.buttons["wear.save"].waitForExistence(timeout: 5))
                    XCTAssertFalse(app.buttons["wear.save"].isEnabled)
                    let editor = XCTAttachment(screenshot: app.screenshot())
                    editor.name = "editor-\(locale)-dark\(dark)-large\(large)"
                    editor.lifetime = .keepAlways
                    add(editor)
                    app.terminate()
                }
            }
        }
    }

}
