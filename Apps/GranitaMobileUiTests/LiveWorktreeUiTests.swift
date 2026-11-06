import UIKit
import XCTest

/// XCUIApplication requires the native XCTest UI runner.
final class LiveWorktreeUiTests: XCTestCase {
    @MainActor
    func testOtherWorktreeChangesLeaveTheVisibleSidebarAndReviewUntouched() {
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
        let sidebar: SidebarFrame
        if showsSidebar {
            let subscribed = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value == %@", "2"), object: app.staticTexts["live-probe.subscriptions"]
            )
            wait(for: [subscribed], timeout: 10)
            let otherRow = app.staticTexts["Agent B"]
            XCTAssertTrue(otherRow.isHittable, app.debugDescription)
            sidebar = .visible(otherRow.frame)
        } else {
            sidebar = .notVisible
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
        let unexpectedRead = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value != %@", reads ?? ""), object: app.staticTexts["live-probe.reads"]
        )
        unexpectedRead.isInverted = true
        var unchanged = [unexpectedRead]
        switch sidebar {
        case .notVisible: break
        case .visible:
            let sidebarChanged = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == true"), object: app.staticTexts["Agent B completed"]
            )
            sidebarChanged.isInverted = true
            unchanged.append(sidebarChanged)
        }
        wait(for: unchanged, timeout: 1)
        XCTAssertEqual(app.staticTexts["live-probe.reads"].value as? String, reads, app.debugDescription)
        switch sidebar {
        case .notVisible: break
        case .visible(let frame): XCTAssertEqual(app.staticTexts["Agent B"].frame, frame, app.debugDescription)
        }
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

    private enum SidebarFrame {
        case notVisible
        case visible(CGRect)
    }
}
