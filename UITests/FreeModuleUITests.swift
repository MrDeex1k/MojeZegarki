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

    func testWatchPhotosOpenFullScreenAndReturnToGallery() {
        let app = launch(extra: ["--test-photo-preview-fixture"])
        XCTAssertTrue(app.staticTexts["Photo watch"].waitForExistence(timeout: 15))
        app.staticTexts["Photo watch"].tap()
        let photos = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "detail.photo."))
        let first = photos.firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        let firstID = first.identifier
        first.tap()
        XCTAssertTrue(app.images["photoPreview.image"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.firstMatch.isHittable)
        saveScreenshot(app, name: "Landscape photo preview")
        app.buttons["photoPreview.close"].tap()
        XCTAssertTrue(app.buttons[firstID].waitForExistence(timeout: 5))
        app.buttons[firstID].swipeLeft()
        let second = photos.matching(NSPredicate(format: "identifier != %@", firstID)).firstMatch
        XCTAssertTrue(second.waitForExistence(timeout: 5))
        second.tap()
        XCTAssertTrue(app.images["photoPreview.image"].waitForExistence(timeout: 5))
        saveScreenshot(app, name: "Portrait photo preview")
        app.buttons["photoPreview.close"].tap()
        XCTAssertTrue(second.waitForExistence(timeout: 5))
    }

    func testWishlistPhotoPreviewDoesNotChangeDraft() {
        let app = launch(extra: ["--test-photo-preview-fixture"])
        XCTAssertTrue(app.buttons["collection.add"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Wishlist"].tap()
        app.staticTexts["Photo wish"].tap()
        let photo = app.buttons["wish.photo.preview"]
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        photo.tap()
        XCTAssertTrue(app.images["photoPreview.image"].waitForExistence(timeout: 5))
        app.buttons["photoPreview.close"].tap()
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["wish.add"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Discard changes"].exists)
        XCTAssertTrue(app.staticTexts["Photo wish"].exists)
    }

    func testMissingWatchPhotoPreviewCanBeClosed() {
        let app = launch(extra: ["--test-photo-preview-fixture", "--test-missing-photo"])
        XCTAssertTrue(app.staticTexts["Photo watch"].waitForExistence(timeout: 15))
        app.staticTexts["Photo watch"].tap()
        let photo = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "detail.photo.")).firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        photo.tap()
        XCTAssertTrue(app.staticTexts["Photo unavailable"].waitForExistence(timeout: 5))
        app.buttons["photoPreview.close"].tap()
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
    }

    private func saveScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testWishlistDragOrderPersistsAfterRelaunch() {
        let app = launch()
        XCTAssertTrue(app.buttons["collection.add"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Wishlist"].tap()
        for model in ["First", "Second", "Third"] {
            app.buttons["wish.add"].tap()
            focus(app.textFields["wish.brand"], in: app)
            app.textFields["wish.brand"].typeText("Seiko")
            focus(app.textFields["wish.model"], in: app)
            app.textFields["wish.model"].typeText(model)
            app.buttons["wish.save"].tap()
            XCTAssertTrue(app.staticTexts[model].waitForExistence(timeout: 5))
        }
        let rows = app.cells.containing(.button, identifier: "Add to collection")
        XCTAssertEqual(rows.count, 3)
        XCTAssertTrue(rows.element(boundBy: 0).staticTexts["Third"].exists)
        let reorder = app.buttons["wish.reorder"]
        let addWish = app.buttons["wish.add"]
        XCTAssertLessThan(reorder.frame.maxX, addWish.frame.minX)
        let actions = rows.element(boundBy: 0).buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "wish.actions.")
        ).firstMatch
        XCTAssertEqual(actions.frame.midY, rows.element(boundBy: 0).frame.midY, accuracy: 2)
        reorder.tap()
        let source = rows.element(boundBy: 0)
        let destination = rows.element(boundBy: 2)
        source.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).press(
            forDuration: 1,
            thenDragTo: destination.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.85)))
        app.buttons["wish.reorder"].tap()
        wait(
            for: [
                XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "exists == true"),
                    object: rows.element(boundBy: 2).staticTexts["Third"])
            ], timeout: 5)
        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-test-store" }
        app.launch()
        app.tabBars.buttons["Wishlist"].tap()
        XCTAssertTrue(rows.element(boundBy: 2).staticTexts["Third"].waitForExistence(timeout: 5))
        XCTAssertTrue(rows.element(boundBy: 0).staticTexts["Second"].exists)
        app.swipeDown()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))
        app.searchFields.firstMatch.tap()
        app.searchFields.firstMatch.typeText("Second")
        XCTAssertFalse(app.buttons["wish.reorder"].exists)
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
        let visibleLog = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"), object: logs.firstMatch)
        wait(for: [visibleLog], timeout: 5)
        XCTAssertTrue(app.buttons["wear.add"].exists)
        XCTAssertEqual(logs.count, 1)
        app.buttons["Done"].tap()
        app.tabBars.buttons["Wearing"].tap()
        XCTAssertTrue(app.staticTexts["1 day worn"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wear.log.")).count, 0)
        app.buttons[todayID].tap()
        let tabLog = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wear.log.")).firstMatch
        wait(
            for: [
                XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "isHittable == true"), object: tabLog)
            ], timeout: 5)
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
    func testWearCalendarRemainsStableAfterScrollingInSheet() {
        let app = launch(extra: ["--test-wear-fixture"])
        XCTAssertTrue(app.staticTexts["Calendar watch"].waitForExistence(timeout: 15))
        app.staticTexts["Calendar watch"].tap()
        app.buttons["detail.wear"].tap()
        let month = app.buttons["wear.month.title"]
        XCTAssertTrue(month.waitForExistence(timeout: 5))
        XCTAssertLessThan(
            app.navigationBars["Wear overview"].frame.height, 80,
            "The watch's wear sheet should use an inline title so scrolling cannot collapse a large header")
        let hint = app.staticTexts["wear.calendarHint"]
        for _ in 0..<3 {
            app.swipeUp(velocity: .slow)
            // Allow the scroll's deceleration to finish, then check for layout oscillation.
            RunLoop.current.run(until: Date().addingTimeInterval(1))
            let position = month.frame.minY
            for _ in 0..<5 {
                RunLoop.current.run(until: Date().addingTimeInterval(0.2))
                XCTAssertEqual(month.frame.minY, position, accuracy: 1)
            }
            XCTAssertTrue(hint.isHittable, "The calendar hint should be reachable at the bottom of the sheet")
            app.swipeDown(velocity: .slow)
        }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "wear-calendar-after-scrolling"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testWearDaySelectionScrollsToEntriesAndEmptyState() {
        let app = launch(extra: ["--test-wear-fixture"])
        XCTAssertTrue(app.staticTexts["Calendar watch"].waitForExistence(timeout: 15))
        app.staticTexts["Calendar watch"].tap()
        app.buttons["detail.wear"].tap()
        XCTAssertTrue(app.buttons["wear.month.title"].waitForExistence(timeout: 5))

        let calendar = Calendar(identifier: .gregorian)
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        var displayedMonth = today
        for date in [yesterday, today, yesterday, today] {
            if !calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month) {
                app.buttons[date < displayedMonth ? "wear.month.previous" : "wear.month.next"].tap()
                displayedMonth = date
            }
            app.buttons["wear.day.\(formatter.string(from: date))"].tap()
            let target =
                calendar.isDate(date, inSameDayAs: today)
                ? app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wear.log.")).firstMatch
                : app.staticTexts["No wear entries for this day"]
            wait(
                for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: target)],
                timeout: 5)
        }
    }

    func testWearSheetKeepsScrollingWithAccessibilityText() {
        let app = launch(extra: [
            "--test-wear-fixture", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ])
        XCTAssertTrue(app.staticTexts["Calendar watch"].waitForExistence(timeout: 15))
        app.staticTexts["Calendar watch"].tap()
        app.buttons["detail.wear"].tap()
        XCTAssertTrue(app.navigationBars["Wear overview"].waitForExistence(timeout: 5))

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let today = app.buttons["wear.day.\(formatter.string(from: Date()))"]
        for _ in 0..<20 {
            if today.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(today.isHittable, "Disabling bounce must not disable scrolling through a large calendar")
        today.tap()
        let entry = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wear.log.")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        XCTAssertTrue(entry.isHittable, "The selected day's entry should still scroll into view")
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
