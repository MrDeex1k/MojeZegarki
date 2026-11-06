import UIKit
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
        app.buttons["collection.back"].tap()
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

    func testShowCollectionClearsArchiveSearchAndDetailSelection() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitesting", "--reset-test-store", "--test-wear-fixture", "--test-photo-preview-fixture",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
        ]
        app.launch()
        XCTAssertTrue(app.staticTexts["Calendar watch"].waitForExistence(timeout: 15))
        app.staticTexts["Calendar watch"].tap()
        reveal(app.buttons["detail.sell"], in: app)
        app.buttons["detail.sell"].tap()
        app.buttons["collection.back"].tap()
        app.segmentedControls.buttons["Archive"].tap()
        app.swipeDown()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Calendar\n")
        app.staticTexts["Calendar watch"].tap()
        XCTAssertTrue(app.buttons["detail.edit"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Wishlist"].tap()
        let move = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wish.quickMove.")).firstMatch
        XCTAssertTrue(move.waitForExistence(timeout: 5))
        move.tap()
        app.buttons["Show collection"].tap()
        XCTAssertTrue(app.staticTexts["Photo wish"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Collection"].isSelected)
        XCTAssertTrue(app.segmentedControls.buttons["In collection"].isSelected)
        XCTAssertFalse(app.buttons["detail.edit"].exists)
        XCTAssertFalse(app.staticTexts["Calendar watch"].exists)
    }

    func testRemovingCurrentPhotoCanBeCancelledThenSavedWithoutBreakingGallery() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitesting", "--reset-test-store", "--test-photo-preview-fixture", "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
        ]
        app.launch()
        XCTAssertTrue(app.staticTexts["Photo watch"].waitForExistence(timeout: 15))
        app.staticTexts["Photo watch"].tap()
        let photos = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "detail.photo."))
        XCTAssertTrue(photos.firstMatch.waitForExistence(timeout: 5))
        let original = photos.firstMatch.identifier
        let removeID = original.replacingOccurrences(of: "detail.photo.", with: "editor.photo.remove.")
        app.buttons["detail.edit"].tap()
        reveal(app.buttons[removeID], in: app)
        app.buttons[removeID].tap()
        app.buttons["editor.cancel"].tap()
        app.buttons["Discard changes"].tap()
        XCTAssertTrue(app.buttons[original].waitForExistence(timeout: 5))
        app.buttons[original].tap()
        XCTAssertTrue(app.images["photoPreview.image"].waitForExistence(timeout: 5))
        app.buttons["photoPreview.close"].tap()
        app.buttons["detail.edit"].tap()
        reveal(app.buttons[removeID], in: app)
        app.buttons[removeID].tap()
        app.buttons["editor.save"].tap()
        XCTAssertTrue(photos.firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons[original].exists)
        let remaining = photos.firstMatch.identifier
        photos.firstMatch.tap()
        XCTAssertTrue(app.images["photoPreview.image"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-test-store" }
        app.launch()
        XCTAssertTrue(app.staticTexts["Photo watch"].waitForExistence(timeout: 15))
        app.staticTexts["Photo watch"].tap()
        XCTAssertTrue(app.buttons[remaining].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons[original].exists)
    }

    func testDetailShowsAllAcceptedPriceDigits() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-test-store", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["collection.add"].waitForExistence(timeout: 15))
        app.buttons["collection.add"].tap()
        focus(app.textFields["editor.brand"], in: app)
        app.textFields["editor.brand"].typeText("Test")
        focus(app.textFields["editor.model"], in: app)
        app.textFields["editor.model"].typeText("Precision")
        reveal(app.textFields["editor.price"], in: app)
        focus(app.textFields["editor.price"], in: app)
        app.textFields["editor.price"].typeText("12.123456")
        app.buttons["editor.save"].tap()
        XCTAssertTrue(app.staticTexts["Precision"].waitForExistence(timeout: 5))
        app.staticTexts["Precision"].tap()
        let price = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "12.123456")).firstMatch
        reveal(price, in: app)
        XCTAssertTrue(price.exists)
    }

    /// Opens an existing price with an unsupported code and checks that a supported choice replaces it.
    func testLegacyCurrencyExplainsHowToSaveAnExistingPrice() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitesting", "--reset-test-store", "--test-legacy-currency", "-AppleLanguages", "(en)", "-AppleLocale",
            "en_US",
        ]
        app.launch()
        let watch = app.staticTexts["Legacy currency watch"]
        XCTAssertTrue(watch.waitForExistence(timeout: 15))
        watch.tap()
        app.buttons["detail.edit"].tap()
        let picker = app.buttons["currency.picker"]
        reveal(picker, in: app)
        picker.tap()

        let legacy = app.buttons["currency.ZZZ"]
        XCTAssertTrue(legacy.waitForExistence(timeout: 5))
        XCTAssertTrue(legacy.isSelected)
        XCTAssertTrue(legacy.label.contains("Unsupported currency. Choose another currency to save a price."))
        let supported = app.buttons["currency.USD"]
        XCTAssertTrue(supported.isHittable)
        supported.tap()
        XCTAssertTrue(supported.isSelected)
        XCTAssertFalse(legacy.exists)
    }

    /// Searches by a localized name without diacritics and verifies that the chosen row exposes its selection.
    func testCurrencySearchMatchesPolishNameAndExposesSelectedRow() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-test-store", "-AppleLanguages", "(pl)", "-AppleLocale", "pl_PL"]
        app.launch()
        XCTAssertTrue(app.buttons["collection.add"].waitForExistence(timeout: 15))
        app.buttons["collection.add"].tap()
        let picker = app.buttons["currency.picker"]
        reveal(picker, in: app)
        picker.tap()

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        XCTAssertEqual(search.placeholderValue, "Szukaj walut")
        search.tap()
        search.typeText("japonski")
        let yen = app.buttons["currency.JPY"]
        XCTAssertTrue(yen.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["currency.PLN"].exists)
        yen.tap()
        XCTAssertTrue(yen.isSelected)
    }

    func testBackgroundShieldCoversPhotoPreviewAndUnsavedEditor() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitesting", "--reset-test-store", "--test-photo-preview-fixture", "--test-lock-enabled",
            "--test-authentication-lifecycle", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
        ]
        app.launch()
        XCTAssertTrue(app.staticTexts["Photo watch"].waitForExistence(timeout: 15))
        app.staticTexts["Photo watch"].tap()
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "detail.photo.")).firstMatch.tap()
        XCTAssertTrue(app.images["photoPreview.image"].waitForExistence(timeout: 5))
        let visiblePhoto = XCUIScreen.main.screenshot()
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["lock.unlock"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.images["photoPreview.image"].exists)
        let lockedPhoto = lockScreenshot(named: "Shield over photo preview")
        app.buttons["lock.unlock"].tap()
        XCTAssertTrue(app.images["photoPreview.image"].waitForExistence(timeout: 5))
        app.buttons["photoPreview.close"].tap()
        app.buttons["detail.edit"].tap()
        focus(app.textFields["editor.brand"], in: app)
        app.textFields["editor.brand"].typeText(" Unsaved\n")
        // Let UIKit finish the text input session before exercising scene activation.
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        let visibleEditor = XCUIScreen.main.screenshot()
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["lock.unlock"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.textFields["editor.brand"].exists)
        let lockedEditor = lockScreenshot(named: "Shield over unsaved editor")
        do {
            XCTAssertGreaterThan(try pixelDifference(visiblePhoto, visibleEditor), 0.25)
            XCTAssertGreaterThan(try pixelDifference(visiblePhoto, lockedPhoto), 0.05)
            XCTAssertGreaterThan(try pixelDifference(visibleEditor, lockedEditor), 0.05)
            XCTAssertLessThan(
                try pixelDifference(lockedPhoto, lockedEditor), 0.02,
                "The shield should render the same screen over two visibly different private views")
        } catch {
            XCTFail("Could not compare the captured screens: \(error)")
        }
        app.buttons["lock.unlock"].tap()
        XCTAssertTrue(app.textFields["editor.brand"].waitForExistence(timeout: 5))
        XCTAssertTrue((app.textFields["editor.brand"].value as? String ?? "").contains("Unsaved"))
    }

    /// Retains visual evidence even when all accessibility checks pass.
    private func lockScreenshot(named name: String) -> XCUIScreenshot {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        return screenshot
    }

    /// Compares the screen interior at a fixed scale, ignoring status and home indicator chrome.
    private func pixelDifference(_ first: XCUIScreenshot, _ second: XCUIScreenshot) throws -> Double {
        let width = 80
        let height = 160
        func sample(_ screenshot: XCUIScreenshot) throws -> [UInt8] {
            let image = try XCTUnwrap(screenshot.image.cgImage)
            let rect = CGRect(x: 0, y: image.height / 12, width: image.width, height: image.height * 5 / 6)
            let interior = try XCTUnwrap(image.cropping(to: rect))
            var pixels = [UInt8](repeating: 0, count: width * height * 4)
            try pixels.withUnsafeMutableBytes { buffer in
                let context = try XCTUnwrap(
                    CGContext(
                        data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                        bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
                context.draw(interior, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
            return pixels
        }
        let left = try sample(first)
        let right = try sample(second)
        let differences = stride(from: 0, to: left.count, by: 4).count { index in
            (0..<3).contains { channel in abs(Int(left[index + channel]) - Int(right[index + channel])) > 20 }
        }
        return Double(differences) / Double(width * height)
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
    /// Verify the target field owns keyboard focus even when another field already opened the keyboard.
    func focus(_ field: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: field)
        wait(for: [ready], timeout: 5)
        field.tap()
        let focused = NSPredicate(format: "hasKeyboardFocus == true")
        let initialFocus = XCTNSPredicateExpectation(predicate: focused, object: field)
        if XCTWaiter.wait(for: [initialFocus], timeout: 3) != .completed {
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        let confirmedFocus = XCTNSPredicateExpectation(predicate: focused, object: field)
        XCTAssertEqual(
            XCTWaiter.wait(for: [confirmedFocus], timeout: 5), .completed,
            "The target field must own keyboard focus before typing")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
    }
}
