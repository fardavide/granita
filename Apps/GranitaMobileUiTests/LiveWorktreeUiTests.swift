import UIKit
import XCTest

/// XCUIApplication requires the native XCTest UI runner.
final class LiveWorktreeUiTests: XCTestCase {
    @MainActor
    func testRepairConfirmsTheListedRegistrationsAndKeepsTheHealthyWorktree() {
        // given
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["worktree-repair", "disable-test-animations"]
        app.launch()
        defer { app.terminate() }
        let animations = app.staticTexts["context-probe.animations"]
        XCTAssertTrue(animations.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertEqual(animations.value as? String, "UIKit=false;SwiftUI=true", app.debugDescription)
        let healthy = app.staticTexts["Review A"]
        XCTAssertTrue(healthy.waitForExistence(timeout: 15), app.debugDescription)
        let approvals = app.staticTexts["worktree-repair.approvals"]
        XCTAssertEqual(approvals.value as? String, "none", app.debugDescription)

        // when
        let repair = app.buttons["Repair…"]
        XCTAssertTrue(repair.waitForExistence(timeout: 15), app.debugDescription)
        repair.tap()
        let confirm = app.buttons["Back Up 2 Stale Registrations"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(app.staticTexts["boiler-check-in"].exists, app.debugDescription)
        XCTAssertTrue(app.staticTexts["boiler-reserve"].exists, app.debugDescription)
        confirm.tap()

        // then
        let expectedApproval = "00000000-0000-0000-0000-000000000042"
        let approved = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", expectedApproval), object: approvals
        )
        wait(for: [approved], timeout: 10)
        XCTAssertEqual(approvals.value as? String, expectedApproval, app.debugDescription)
        XCTAssertTrue(healthy.isHittable, app.debugDescription)
        XCTAssertFalse(app.staticTexts["Missing review"].exists, app.debugDescription)
    }

    @MainActor
    func testLiveWorktreeListUpdatesWhileNoReviewIsOpen() {
        // given
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["live-list", "disable-test-animations"]
        app.launch()
        defer { app.terminate() }
        let animations = app.staticTexts["context-probe.animations"]
        XCTAssertTrue(animations.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertEqual(animations.value as? String, "UIKit=false;SwiftUI=true", app.debugDescription)
        let reviewed = app.staticTexts["Review A"]
        XCTAssertTrue(reviewed.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Agent B"].isHittable, app.debugDescription)
        let subscribed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "1"),
            object: app.staticTexts["live-probe.subscriptions"]
        )
        wait(for: [subscribed], timeout: 10)
        let reviewedFrame = reviewed.frame

        // when
        app.buttons["Change other worktree"].tap()

        // then
        let changed = app.staticTexts["Agent B completed"]
        XCTAssertTrue(changed.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(changed.isHittable, app.debugDescription)
        XCTAssertFalse(app.staticTexts["Agent B"].exists, app.debugDescription)
        XCTAssertTrue(reviewed.isHittable, app.debugDescription)
        XCTAssertEqual(reviewed.frame, reviewedFrame, app.debugDescription)
        XCTAssertEqual(app.progressIndicators.count, 0, app.debugDescription)
    }

    @MainActor
    func testOtherWorktreeChangesUpdateTheMacSidebarAndLeaveTheReviewUntouched() {
        // given
        let showsSidebar = UIDevice.current.userInterfaceIdiom == .pad
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [showsSidebar ? "live-sidebar" : "live-worktrees", "disable-test-animations"]
        app.launch()
        defer { app.terminate() }
        let animations = app.staticTexts["context-probe.animations"]
        XCTAssertTrue(animations.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertEqual(animations.value as? String, "UIKit=false;SwiftUI=true", app.debugDescription)
        // The wide fixture preselects through the production Mac split composition; the phone
        // opens the production review directly. Mobile value-navigation remains outside this check.
        let code = app.staticTexts["review revision 1"]
        XCTAssertTrue(code.waitForExistence(timeout: 15), app.debugDescription)
        if showsSidebar {
            let subscribed = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value == %@", "2"), object: app.staticTexts["live-probe.subscriptions"]
            )
            wait(for: [subscribed], timeout: 10)
            let otherRow = app.staticTexts["Agent B"]
            XCTAssertTrue(otherRow.isHittable, app.debugDescription)
        }
        let codeFrame = code.frame
        let reads = app.staticTexts["live-probe.reads"].value as? String

        // when
        app.buttons["Change other worktree"].tap()
        let otherChanged = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "2"), object: app.staticTexts["live-probe.otherRevision"]
        )
        wait(for: [otherChanged], timeout: 10)

        // then
        if showsSidebar {
            let changed = app.staticTexts["Agent B completed"]
            XCTAssertTrue(changed.waitForExistence(timeout: 15), app.debugDescription)
            XCTAssertTrue(changed.isHittable, app.debugDescription)
            XCTAssertFalse(app.staticTexts["Agent B"].exists, app.debugDescription)
        }
        let unexpectedRead = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value != %@", reads ?? ""), object: app.staticTexts["live-probe.reads"]
        )
        unexpectedRead.isInverted = true
        wait(for: [unexpectedRead], timeout: 1)
        XCTAssertEqual(app.staticTexts["live-probe.reads"].value as? String, reads, app.debugDescription)
        XCTAssertEqual(code.frame, codeFrame, app.debugDescription)
        XCTAssertTrue(code.isHittable, app.debugDescription)
        XCTAssertEqual(app.progressIndicators.count, 0, app.debugDescription)
    }

    @MainActor
    func testLiveChangesReloadOnlyTheReviewedWorktree() {
        // given
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["live-worktrees", "disable-test-animations"]
        app.launch()
        defer { app.terminate() }
        let animations = app.staticTexts["context-probe.animations"]
        XCTAssertTrue(animations.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertEqual(animations.value as? String, "UIKit=false;SwiftUI=true", app.debugDescription)
        XCTAssertTrue(app.staticTexts["review revision 1"].waitForExistence(timeout: 15), app.debugDescription)

        // when — the own-worktree update proves the live subscription is operating.
        app.buttons["Change this worktree"].tap()
        XCTAssertTrue(app.staticTexts["review revision 2"].waitForExistence(timeout: 15), app.debugDescription)
        let reads = app.staticTexts["live-probe.reads"].value as? String
        app.buttons["Change other worktree"].tap()

        // then
        let unexpectedRead = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value != %@", reads ?? ""),
            object: app.staticTexts["live-probe.reads"]
        )
        unexpectedRead.isInverted = true
        wait(for: [unexpectedRead], timeout: 1)
        XCTAssertTrue(app.staticTexts["review revision 2"].isHittable, app.debugDescription)
        XCTAssertEqual(app.staticTexts["live-probe.reads"].value as? String, reads, app.debugDescription)
        XCTAssertEqual(app.progressIndicators.count, 0, app.debugDescription)
    }
}
