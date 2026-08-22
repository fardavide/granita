import Foundation
import Testing

import ServerApiDomain
import ServerMacDomain
import ServerMacPresentation

/// The Settings window as a whole — design §2, the thing every tab is composed into.
///
/// **Nothing rendered this until now**, so the screen that composes every tab sat in the views scope
/// contributing only to the denominator, and no picture of the assembled window existed.
///
/// **What these do not capture is the tab bar**, and that is worth stating rather than discovering.
/// A `TabView` hosted in a plain window draws the selected pane and no picker — the toolbar segments
/// are something the `Settings` scene puts there, and a test bundle has no `Settings` scene. So the
/// order and the symbols of the five tabs remain reviewed in the code, exactly like the accent tint.
/// What these hold is the pane a reader lands on and the state the model is really in when they do.
///
/// The model is driven before rendering rather than left at its initial value. `GranitaSettingsScreen`
/// does not start the server — the composition root does — so a screen rendered straight after
/// construction reports `.starting` whatever it was handed, and a baseline named "serving" showing
/// "Starting…" would be a picture asserting the opposite of its own name.
@Suite("Settings window screen")
@MainActor
struct GranitaSettingsScreenSnapshotTests {

    @Test(arguments: MacAppearance.all)
    func `given a Mac that is serving when the window opens then it matches its baseline`(
        appearance: MacAppearance
    ) async {
        // given
        let model = SettingsScreenFakes.model(
            state: .running(ServerEndpoint(host: "macbook-pro.local", port: 59_144)),
            attempts: [],
            git: .available(version: "2.52.0", path: "/opt/homebrew/bin/git"),
            projects: 2,
            devices: 2
        )
        await SettingsScreenFakes.drive(model)

        // when - then
        assertSettingsSnapshot(
            GranitaSettingsScreen(model: model),
            appearance: appearance,
            named: "serving"
        )
    }

    @Test(arguments: MacAppearance.all)
    func `given the server did not come up when the window opens then it matches its baseline`(
        appearance: MacAppearance
    ) async {
        // given — what a reader lands in when macOS is withholding local network access, which is
        // the failure this app is most likely to hit on a machine that has never run it.
        let model = SettingsScreenFakes.model(
            state: .failed(reason: "NWError: -65555"),
            attempts: [],
            git: .checking,
            projects: 0,
            devices: 0
        )
        await SettingsScreenFakes.drive(model)

        // when - then
        assertSettingsSnapshot(
            GranitaSettingsScreen(model: model),
            appearance: appearance,
            named: "not-serving"
        )
    }
}
