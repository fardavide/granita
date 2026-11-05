import XCTest

/// XCUIApplication's touch delivery requires XCTest; the separate UI bundle is the exception.
final class TrailingContextExpansionUiTests: XCTestCase {

    @MainActor
    func testTrailingExpansionRevealsRemainderAndDisappearsAtEndOfFile() {
        // given
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["trailing-context", "disable-test-animations"]
        app.launch()
        defer { app.terminate() }
        let animations = app.staticTexts["context-probe.animations"]
        XCTAssertTrue(animations.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertEqual(animations.value as? String, "UIKit=false;SwiftUI=true", app.debugDescription)
        let remainder = app.buttons["23 hidden lines, remainder of file"]
        XCTAssertTrue(remainder.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertFalse(app.staticTexts["unchanged line 604"].exists, app.debugDescription)

        // when
        remainder.tap()

        // then
        let lastWindow = app.buttons["3 hidden lines, remainder of file"]
        XCTAssertTrue(lastWindow.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(app.staticTexts["unchanged line 604"].isHittable, app.debugDescription)
        XCTAssertFalse(app.staticTexts["unchanged line 626"].exists, app.debugDescription)
        lastWindow.tap()
        let finalLine = app.staticTexts["unchanged line 626"]
        XCTAssertTrue(finalLine.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(finalLine.isHittable, app.debugDescription)
        XCTAssertEqual(
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "remainder of file")).count,
            0,
            app.debugDescription
        )
    }
}
