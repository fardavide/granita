import XCTest

/// XCUIApplication's touch delivery requires XCTest; the separate UI bundle is the exception.
final class ContinuousDiffHorizontalSwipeUiTests: XCTestCase {
    func testHorizontalSwipeKeepsLaterFileVerticalPosition() throws {
        // given
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        defer { app.terminate() }
        try waitForStatus("settled", in: app)
        let firstFileEnd = try number("firstFileEnd", in: app)
        let verticalStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.78))
        let verticalEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.28))
        verticalStart.press(forDuration: 0.05, thenDragTo: verticalEnd)
        try waitForStatus("settled", in: app)
        verticalStart.press(forDuration: 0.05, thenDragTo: verticalEnd)
        try waitForStatus("settled", in: app)
        XCTAssertGreaterThan(try number("verticalDepth", in: app), firstFileEnd, "The first file has not scrolled above the viewport")

        // when - then
        try assertHorizontalSwipeKeepsVerticalPosition(in: app)
    }

    func testHorizontalSwipeKeepsLaterFileVerticalPositionAfterReviewingPinnedFirstFile() throws {
        // given
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        defer { app.terminate() }
        try waitForStatus("settled", in: app)
        let firstFileEnd = try number("firstFileEnd", in: app)
        let firstHeader = app.buttons["Sources/First.swift"]
        XCTAssertTrue(firstHeader.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(firstHeader.isHittable, app.debugDescription)
        let initialHeaderY = firstHeader.frame.minY
        let shortStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        shortStart.press(forDuration: 0.05, thenDragTo: shortStart.withOffset(CGVector(dx: 0, dy: -80)))
        try waitForStatus("settled", in: app)
        let pinnedDepth = try number("verticalDepth", in: app)
        XCTAssertGreaterThan(pinnedDepth, 46, "The first header has not passed its natural 46pt slot. \(app.debugDescription)")
        XCTAssertLessThan(pinnedDepth, firstFileEnd, "The setup scrolled beyond the first file. \(app.debugDescription)")
        XCTAssertTrue(firstHeader.isHittable, app.debugDescription)
        XCTAssertLessThan(abs(firstHeader.frame.minY - initialHeaderY), 2, "The first source header is not pinned at its initial viewport position. \(app.debugDescription)")
        let firstViewedControl = try XCTUnwrap(
            app.buttons.matching(NSPredicate(format: "label == %@", "Not viewed"))
                .allElementsBoundByIndex.filter { $0.isHittable }
                .min { $0.frame.minY < $1.frame.minY },
            app.debugDescription
        )
        XCTAssertLessThan(abs(firstViewedControl.frame.midY - firstHeader.frame.midY), 2, "The reviewed control does not belong to the pinned first header. \(app.debugDescription)")
        firstViewedControl.tap()
        try waitForStatus("settled", in: app)
        XCTAssertFalse(firstHeader.isHittable, app.debugDescription)
        let middleHeader = app.buttons["Sources/Middle.swift"]
        XCTAssertTrue(middleHeader.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(middleHeader.isHittable, app.debugDescription)
        XCTAssertLessThan(abs(middleHeader.frame.minY - initialHeaderY), 2, "Reviewing the pinned first file did not advance to the middle header. \(app.debugDescription)")
        let verticalStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.78))
        let verticalEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.28))
        verticalStart.press(forDuration: 0.05, thenDragTo: verticalEnd)
        try waitForStatus("settled", in: app)
        verticalStart.press(forDuration: 0.05, thenDragTo: verticalEnd)
        try waitForStatus("settled", in: app)
        XCTAssertGreaterThan(try number("verticalDepth", in: app), firstFileEnd, "The horizontal gesture must occur inside later code")

        // when - then
        try assertHorizontalSwipeKeepsVerticalPosition(in: app)
    }

    private func assertHorizontalSwipeKeepsVerticalPosition(in app: XCUIApplication) throws {
        let verticalBefore = try number("verticalPosition", in: app)
        app.buttons["Observe swipe"].tap()
        try waitForStatus("armed", in: app)

        // Actual touch input, at equal vertical coordinates inside the visible code.
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
        try waitForStatus("complete", in: app)

        XCTAssertLessThan(try number("verticalDrift", in: app), 2, "The vertical viewport moved during the horizontal swipe")
        XCTAssertLessThan(abs(try number("verticalPosition", in: app) - verticalBefore), 2)
        XCTAssertGreaterThan(try number("panFrames", in: app), 0, "The native horizontal pan never began")
        XCTAssertGreaterThan(try number("sampleCount", in: app), 0)
        XCTAssertEqual(try number("missingFrames", in: app), 0, "Native geometry was unavailable during the observed swipe")
        XCTAssertGreaterThan(try number("horizontalTravel", in: app), 100, "Rendered code did not move horizontally")
        XCTAssertEqual(app.staticTexts["swipe-probe.codeChanged"].value as? String, "true")
    }

    private func waitForStatus(_ value: String, in app: XCUIApplication) throws {
        let status = app.staticTexts["swipe-probe.status"]
        XCTAssertTrue(status.waitForExistence(timeout: 15), app.debugDescription)
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 15), .completed, app.debugDescription)
    }

    private func number(_ name: String, in app: XCUIApplication) throws -> Double {
        let value = try XCTUnwrap(app.staticTexts["swipe-probe.\(name)"].value as? String)
        return try XCTUnwrap(Double(value), "Invalid native metric \(name)=\(value)")
    }
}
