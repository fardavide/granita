import XCTest

final class DiscoveryPrivacyUiTests: XCTestCase {

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
