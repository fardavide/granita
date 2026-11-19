import XCTest

final class DiscoveryPrivacyUiTests: XCTestCase {

    @MainActor
    func testMacDownloadOffersGitHubAndUnavailableAppStoreBeforePairing() {
        // given
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["discovery-privacy", "discovery-download", "disable-test-animations"]
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.staticTexts["No Mac found"].waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertEqual(app.staticTexts["discovery-privacy.animations"].label, "UIKit animations enabled: false")

        // when
        let download = app.buttons["Get Granita for Mac"]
        XCTAssertTrue(download.isHittable, app.debugDescription)
        download.tap()

        // then
        let github = app.buttons["Download from GitHub"]
        XCTAssertTrue(github.waitForExistence(timeout: 5), app.debugDescription)
        let appStore = app.buttons["Mac App Store — Not available yet"]
        XCTAssertTrue(appStore.exists, app.debugDescription)
        XCTAssertFalse(appStore.isEnabled, app.debugDescription)
        let choices = XCTAttachment(screenshot: app.screenshot())
        choices.name = "Mac app download choices"
        choices.lifetime = .keepAlways
        add(choices)
        github.tap()
        let openedUrl = app.staticTexts["discovery-privacy.opened-url"]
        XCTAssertTrue(openedUrl.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(openedUrl.label, "https://github.com/fardavide/granita/releases/latest")
    }

    @MainActor
    func testMacDownloadCanBeCancelledWithoutOpeningAPage() {
        // given
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["discovery-privacy", "discovery-download", "disable-test-animations"]
        app.launch()
        defer { app.terminate() }
        let download = app.buttons["Get Granita for Mac"]
        XCTAssertTrue(download.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertEqual(app.staticTexts["discovery-privacy.animations"].label, "UIKit animations enabled: false")
        download.tap()
        XCTAssertTrue(app.buttons["Download from GitHub"].waitForExistence(timeout: 5), app.debugDescription)

        // when
        app.buttons["Cancel"].tap()

        // then
        XCTAssertFalse(app.buttons["Download from GitHub"].exists, app.debugDescription)
        XCTAssertTrue(download.isHittable, app.debugDescription)
        XCTAssertFalse(app.staticTexts["discovery-privacy.opened-url"].exists, app.debugDescription)
    }

    @MainActor
    func testPrivacyPolicyOpensFromMoreWhenLocalNetworkAccessIsDenied() {
        // given
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["discovery-privacy", "disable-test-animations"]
        app.launch()
        defer { app.terminate() }
        let permissionDenied = app.staticTexts["Local network access is off"]
        XCTAssertTrue(permissionDenied.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertEqual(app.staticTexts["discovery-privacy.animations"].label, "UIKit animations enabled: false")

        let privacyPolicy = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Privacy Policy")).firstMatch
        XCTAssertFalse(privacyPolicy.exists, "Privacy Policy should only appear in More.\n\(app.debugDescription)")

        // when
        let more = app.buttons["More"]
        XCTAssertTrue(more.isHittable, app.debugDescription)
        more.tap()
        XCTAssertTrue(privacyPolicy.waitForExistence(timeout: 5), app.debugDescription)
        privacyPolicy.tap()

        // then
        let openedUrl = app.staticTexts["discovery-privacy.opened-url"]
        XCTAssertTrue(openedUrl.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(openedUrl.label, "https://granita.fardavide.dev/privacy/")
    }
}
