import XCTest

/// XCUIApplication's touch delivery requires XCTest; the separate UI bundle is the exception.
final class ContinuousDiffHorizontalSwipeUiTests: XCTestCase {
    func testTapOnCodeComposesThatLine() throws {
        // given
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        defer { app.terminate() }
        try waitForStatus("settled", in: app)
        let lineNumber = app.staticTexts["8"].firstMatch
        XCTAssertTrue(lineNumber.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(app.frame.contains(lineNumber.frame), app.debugDescription)
        let code = app.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0))
            .withOffset(CGVector(dx: 0, dy: lineNumber.frame.midY - app.frame.minY))
        let composerRange = app.staticTexts["selection-probe.composerRange"]
        XCTAssertEqual(composerRange.value as? String, "none")

        // when
        code.tap()

        // then
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "8:8"), object: composerRange)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed, app.debugDescription)
    }

    func testLongPressOnCodeHoldsThatLine() throws {
        // given
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        defer { app.terminate() }
        try waitForStatus("settled", in: app)
        let lineNumber = app.staticTexts["8"].firstMatch
        XCTAssertTrue(lineNumber.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(lineNumber.isHittable, app.debugDescription)
        let code = app.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0))
            .withOffset(CGVector(dx: 0, dy: lineNumber.frame.midY - app.frame.minY))
        let heldLine = app.staticTexts["selection-probe.heldLine"]
        XCTAssertEqual(heldLine.value as? String, "none")

        // when
        code.press(forDuration: 0.7)

        // then
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "8"), object: heldLine)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed, app.debugDescription)
    }

    func testLongPressAndDragOnCodeComposesRange() throws {
        // given
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        defer { app.terminate() }
        try waitForStatus("settled", in: app)
        let firstLine = app.staticTexts["8"].firstMatch
        let lastLine = app.staticTexts["12"].firstMatch
        XCTAssertTrue(firstLine.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(lastLine.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(app.frame.contains(firstLine.frame), app.debugDescription)
        XCTAssertTrue(app.frame.contains(lastLine.frame), app.debugDescription)
        let codeStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0))
            .withOffset(CGVector(dx: 0, dy: firstLine.frame.midY - app.frame.minY))
        let codeEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0))
            .withOffset(CGVector(dx: 0, dy: lastLine.frame.midY - app.frame.minY))
        let composerRange = app.staticTexts["selection-probe.composerRange"]
        XCTAssertEqual(composerRange.value as? String, "none")

        // when
        codeStart.press(forDuration: 0.7, thenDragTo: codeEnd)

        // then
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "8:12"), object: composerRange)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed, app.debugDescription)
    }

    func testDragAcrossHunkGapComposesRange() throws {
        // given
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["selection-gap"]
        app.launch()
        defer { app.terminate() }
        try waitForStatus("settled", in: app)
        let firstLine = app.staticTexts["8"].firstMatch
        let lastLine = app.staticTexts["17"].firstMatch
        XCTAssertTrue(firstLine.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(lastLine.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(app.frame.contains(firstLine.frame), app.debugDescription)
        XCTAssertTrue(app.frame.contains(lastLine.frame), app.debugDescription)
        let codeStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0))
            .withOffset(CGVector(dx: 0, dy: firstLine.frame.midY - app.frame.minY))
        let codeEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0))
            .withOffset(CGVector(dx: 0, dy: lastLine.frame.midY - app.frame.minY))
        let composerRange = app.staticTexts["selection-probe.composerRange"]
        XCTAssertEqual(composerRange.value as? String, "none")

        // when
        codeStart.press(forDuration: 0.7, thenDragTo: codeEnd)

        // then
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "8:17"), object: composerRange)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed, app.debugDescription)
    }

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

    func testHorizontalSwipeKeepsVerticalPositionAfterSelectingAndScrollingThirdFile() throws {
        // given
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["selector-jump"]
        app.launch()
        defer { app.terminate() }
        try waitForStatus("settled", in: app)
        let initialHeaderY = app.buttons["Sources/First.swift"].frame.minY
        app.buttons["Files"].tap()
        let filesHeading = app.staticTexts["Files"].firstMatch
        XCTAssertTrue(filesHeading.waitForExistence(timeout: 15), app.debugDescription)
        let thirdFileRow = try XCTUnwrap(
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Added, Sources/Third.swift,"))
                .allElementsBoundByIndex.first { $0.isHittable },
            app.debugDescription
        )
        thirdFileRow.tap()

        // Dismiss the real drawer by its native drag affordance, leaving the selected reader visible.
        let drawerHandle = app.buttons["Sheet Grabber"]
        XCTAssertTrue(drawerHandle.isHittable, app.debugDescription)
        drawerHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.96)))
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: filesHeading)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 15), .completed, app.debugDescription)
        try waitForStatus("settled", in: app)
        let thirdHeader = app.buttons["Sources/Third.swift"]
        XCTAssertTrue(thirdHeader.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(thirdHeader.isHittable, app.debugDescription)
        XCTAssertLessThan(abs(thirdHeader.frame.minY - initialHeaderY), 2, "Choosing the third file did not bring its header to the reader's viewport")
        let selectedPosition = try number("verticalPosition", in: app)

        // when
        let verticalStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.78))
        let verticalEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.28))
        verticalStart.press(forDuration: 0.05, thenDragTo: verticalEnd)
        try waitForStatus("settled", in: app)

        // then
        XCTAssertGreaterThan(try number("verticalPosition", in: app) - selectedPosition, 100, "A real vertical pan did not advance into the selected third file")
        XCTAssertTrue(thirdHeader.isHittable, app.debugDescription)
        XCTAssertLessThan(abs(thirdHeader.frame.minY - initialHeaderY), 2, "The third file's header did not remain pinned while reading its code")
        try assertHorizontalSwipeKeepsVerticalPosition(in: app)
    }

    func testReselectingThirdFileReturnsToItsFirstCodeLineAfterVerticalPan() throws {
        // given
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["selector-jump"]
        app.launch()
        defer { app.terminate() }
        try waitForStatus("settled", in: app)
        let initialHeaderY = app.buttons["Sources/First.swift"].frame.minY
        app.buttons["Files"].tap()
        let filesHeading = app.staticTexts["Files"].firstMatch
        XCTAssertTrue(filesHeading.waitForExistence(timeout: 15), app.debugDescription)
        let thirdFileRow = try XCTUnwrap(
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Added, Sources/Third.swift,"))
                .allElementsBoundByIndex.first { $0.isHittable },
            app.debugDescription
        )
        thirdFileRow.tap()
        let drawerHandle = app.buttons["Sheet Grabber"]
        XCTAssertTrue(drawerHandle.isHittable, app.debugDescription)
        drawerHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.96)))
        let firstDismissal = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: filesHeading)
        XCTAssertEqual(XCTWaiter.wait(for: [firstDismissal], timeout: 15), .completed, app.debugDescription)
        try waitForStatus("settled", in: app)
        let thirdHeader = app.buttons["Sources/Third.swift"]
        XCTAssertTrue(thirdHeader.isHittable, app.debugDescription)
        XCTAssertLessThan(abs(thirdHeader.frame.minY - initialHeaderY), 2)
        let firstCodeLine = try XCTUnwrap(
            app.staticTexts.matching(NSPredicate(format: "label == %@", "1"))
                .allElementsBoundByIndex.first { $0.isHittable && app.frame.contains($0.frame) },
            "The selected third file's first line is not visible. \(app.debugDescription)"
        )
        let firstCodeLineY = firstCodeLine.frame.minY
        let selectedPosition = try number("verticalPosition", in: app)
        let verticalStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.78))
        let verticalEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.28))
        verticalStart.press(forDuration: 0.05, thenDragTo: verticalEnd)
        try waitForStatus("settled", in: app)
        XCTAssertGreaterThan(try number("verticalPosition", in: app) - selectedPosition, 100)
        XCTAssertFalse(
            app.staticTexts.matching(NSPredicate(format: "label == %@", "1"))
                .allElementsBoundByIndex.contains { $0.isHittable && app.frame.contains($0.frame) },
            "The real vertical pan must leave the third file's first line above the viewport"
        )

        // when
        app.buttons["Files"].tap()
        XCTAssertTrue(filesHeading.waitForExistence(timeout: 15), app.debugDescription)
        let sameThirdFileRow = try XCTUnwrap(
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Added, Sources/Third.swift,"))
                .allElementsBoundByIndex.first { $0.isHittable },
            app.debugDescription
        )
        sameThirdFileRow.tap()
        XCTAssertTrue(drawerHandle.isHittable, app.debugDescription)
        drawerHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.96)))
        let secondDismissal = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: filesHeading)
        XCTAssertEqual(XCTWaiter.wait(for: [secondDismissal], timeout: 15), .completed, app.debugDescription)
        try waitForStatus("settled", in: app)

        // then
        XCTAssertTrue(thirdHeader.isHittable, app.debugDescription)
        XCTAssertLessThan(abs(thirdHeader.frame.minY - initialHeaderY), 2, "Reselecting the third file did not return its header to the original top")
        let returnedFirstCodeLine = try XCTUnwrap(
            app.staticTexts.matching(NSPredicate(format: "label == %@", "1"))
                .allElementsBoundByIndex.first { $0.isHittable && app.frame.contains($0.frame) },
            "Reselecting the same file did not bring its first code line back. \(app.debugDescription)"
        )
        XCTAssertLessThan(abs(returnedFirstCodeLine.frame.minY - firstCodeLineY), 2, "The first code line did not return to its original reading position")
        XCTAssertLessThan(abs(try number("verticalPosition", in: app) - selectedPosition), 2)
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
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 15),
            .completed,
            "\(app.debugDescription)\nNative scroll candidates: \(String(describing: app.staticTexts["swipe-probe.scrollCandidates"].value))"
        )
    }

    private func number(_ name: String, in app: XCUIApplication) throws -> Double {
        let value = try XCTUnwrap(app.staticTexts["swipe-probe.\(name)"].value as? String)
        return try XCTUnwrap(Double(value), "Invalid native metric \(name)=\(value)")
    }
}
