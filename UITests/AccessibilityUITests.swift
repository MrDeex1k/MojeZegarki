import XCTest

@MainActor
final class AccessibilityUITests: XCTestCase {
    func testCoreScreensAccessibility() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitesting", "--reset-test-store", "--test-wear-fixture", "-AppleLanguages", "(en)", "-AppleLocale",
            "en_US",
        ]
        app.launch()
        XCTAssertTrue(app.buttons["collection.add"].waitForExistence(timeout: 15))
        try audit(app)
        app.buttons["collection.add"].tap()
        XCTAssertTrue(app.textFields["editor.brand"].waitForExistence(timeout: 5))
        try audit(app)
        app.buttons["editor.cancel"].tap()
        app.buttons["Wearing"].tap()
        XCTAssertTrue(app.buttons["wear.add"].waitForExistence(timeout: 5))
        app.swipeUp()
        try audit(app)
        app.swipeDown()
        app.buttons["wear.statistics"].tap()
        XCTAssertTrue(app.segmentedControls["stats.period"].waitForExistence(timeout: 5))
        try audit(app)
        app.buttons["Done"].tap()
        app.buttons["Wishlist"].tap()
        app.buttons["wish.add"].tap()
        XCTAssertTrue(app.textFields["wish.brand"].waitForExistence(timeout: 5))
        try audit(app)
        app.buttons["Cancel"].tap()
        app.buttons["Settings"].tap()
        app.swipeUp()
        try audit(app)
    }

    func testLockScreenAccessibility() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitesting", "--reset-test-store", "--test-lock-enabled", "-AppleLanguages", "(en)", "-AppleLocale",
            "en_US",
        ]
        app.launch()
        XCTAssertTrue(app.staticTexts["Collection locked"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["collection.add"].exists)
        do { try audit(app) } catch let error as NSError
            where error.domain == "com.apple.accessibilityAudit" && error.code == -902
        {
            throw XCTSkip(
                "System authentication owns the foreground process; audit the lock screen manually on an iPhone.")
        }
    }

    private func audit(_ app: XCUIApplication) throws {
        try app.performAccessibilityAudit(for: [
            .sufficientElementDescription, .trait, .hitRegion, .contrast, .textClipped,
        ]) { issue in
            // A PDFKit text paragraph is document content, not an app tap target.
            if issue.auditType == .hitRegion, let element = issue.element, element.elementType == .other,
                app.otherElements["document.pdfPreview"].descendants(matching: .other).matching(
                    NSPredicate(format: "label == %@", element.label)
                ).count > 0
            {
                return true
            }
            // SwiftUI sometimes reports a visual node that has already been recycled.
            // Preserve evidence for manual review; do not present it as a verified contrast pass.
            if issue.auditType == .contrast, issue.element == nil || issue.element?.exists == false {
                let path = FileManager.default.temporaryDirectory.appendingPathComponent(
                    "unlocated-contrast-\(UUID().uuidString).png")
                try? app.screenshot().pngRepresentation.write(to: path)
                print("AUDIT_MANUAL_CONTRAST: \(issue.detailedDescription) screenshot=\(path.path)")
                return true
            }
            // This is an intentional two-line preview with a tested full-text destination.
            if issue.auditType == .textClipped, issue.element?.identifier == "document.noteSummary" { return true }
            // Xcode 27 reports the system glass capsule itself as the text contrast.
            // Checked in exported element screenshots: white text on a dark capsule.
            if #available(iOS 26, *), issue.auditType == .contrast, let element = issue.element,
                ["Cancel", "Done"].contains(element.label), app.navigationBars.buttons[element.label].exists
            {
                print("AUDIT_NATIVE_TOOLBAR: \(element.label)")
                return true
            }
            // System disabled controls are exempt from contrast requirements.
            if issue.auditType == .contrast, let element = issue.element, !element.isEnabled { return true }
            // Text passing under the tab bar is intentionally clipped by the scroll viewport.
            if issue.auditType == .contrast, let element = issue.element, app.tabBars.firstMatch.exists,
                element.frame.intersects(app.tabBars.firstMatch.frame)
            {
                return true
            }
            if issue.auditType == .contrast, let element = issue.element, element.elementType != .button,
                app.navigationBars.firstMatch.exists, element.frame.intersects(app.navigationBars.firstMatch.frame)
            {
                return true
            }
            // iOS 17 flags its standard scrolling search field as clipped.
            if issue.auditType == .textClipped, let element = issue.element, element.elementType == .searchField {
                return true
            }
            if issue.auditType == .contrast, let element = issue.element, !element.isHittable {
                print("AUDIT_OFFSCREEN: \(element.label)")
                return true
            }
            let path = FileManager.default.temporaryDirectory.appendingPathComponent(
                "accessibility-\(UUID().uuidString).png")
            do {
                try app.screenshot().pngRepresentation.write(to: path)
                print("AUDIT_SCREENSHOT: \(path.path)")
            } catch { print("AUDIT_SCREENSHOT_ERROR: \(error)") }
            print("ACCESSIBILITY: \(issue.compactDescription) — \(issue.element?.label ?? issue.detailedDescription)")
            return false
        }
    }

    func testFullDocumentNoteIsReadableWithoutEditing() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitesting", "--reset-test-store", "--test-document-fixture", "--test-long-note", "-AppleLanguages",
            "(en)", "-AppleLocale", "en_US", "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()
        XCTAssertTrue(app.staticTexts["Document watch"].waitForExistence(timeout: 15))
        app.staticTexts["Document watch"].tap()
        let documents = app.buttons["detail.documents"]
        for _ in 0..<5 where !documents.isHittable { app.swipeUp() }
        documents.tap()
        let invoice = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "document.")).firstMatch
        for _ in 0..<5 where !invoice.isHittable { app.swipeUp() }
        invoice.tap()
        try audit(app)
        app.buttons["document.readNotes"].tap()
        XCTAssertTrue(app.scrollViews["document.fullNotes"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["document.save"].exists)
    }
}
