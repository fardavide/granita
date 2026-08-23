import Foundation
import Testing

import ServerMacDomain
@testable import ServerMacData

/// The two settings panes this app sends a reader to.
///
/// Only the spellings are asserted, and that is the whole of what is assertable here: opening one
/// hands a URL to the system and there is nothing to read back. What a test *can* catch is the
/// failure these have — a mistyped scheme or extension identifier opens System Settings on its front
/// page, which looks like the app working and leaves the reader hunting.
@Suite("System settings panes")
struct AppKitSystemGesturesTests {

    @Test
    func `given the local network pane when its address is built then it names that extension`() {
        // given - when
        let url = SystemSettingsPane.localNetwork.url

        // then
        #expect(url.scheme == "x-apple.systempreferences")
        #expect(url.absoluteString.contains("com.apple.settings.PrivacySecurity.extension"))
        #expect(url.absoluteString.hasSuffix("Privacy_LocalNetwork"))
    }

    @Test
    func `given the login items pane when its address is built then it names that extension`() {
        // given - when
        let url = SystemSettingsPane.loginItems.url

        // then
        #expect(url.scheme == "x-apple.systempreferences")
        #expect(url.absoluteString.hasSuffix("com.apple.LoginItems-Settings.extension"))
    }

    @Test(arguments: [SystemSettingsPane.localNetwork, .loginItems])
    func `given a pane when its address is built then the literal beside it parsed`(
        pane: SystemSettingsPane
    ) {
        // given - when - then — the force-unwraps in the switch are only safe while every literal is
        // a well-formed URL, and nothing else in the product would notice if one stopped being one.
        #expect(pane.url.absoluteString.isEmpty == false)
    }
}
