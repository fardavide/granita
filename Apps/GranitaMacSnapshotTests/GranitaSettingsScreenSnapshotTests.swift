import Foundation
import Testing

import ServerApiDomain
import ServerMacDomain
import ServerMacPresentation

/// The Settings window as a whole — design §2, the thing every tab is composed into.
///
/// **What these do not capture is the tab bar**, and that is worth stating rather than discovering.
/// A `TabView` hosted in a plain window draws the selected pane and no picker — the toolbar segments
/// are something the `Settings` scene puts there, and a test bundle has no `Settings` scene. So the
/// order and the symbols of the five tabs remain reviewed in the code, exactly like the accent tint.
///
/// **What they do capture is each pane wired to a real model, which nothing else does.** A pane's
/// own baselines are taken against values a test hands it directly; here the values come through the
/// closures the window composes it from, and a closure handed the wrong one — Devices drawing
/// Projects' failure, a Revoke carrying the neighbouring row's identifier — is invisible everywhere
/// else. Until this walked the tabs, only General had ever been rendered this way and the other four
/// tabs' composition was code no picture executed.
///
/// The model is driven before rendering rather than left at its initial value. `GranitaSettingsScreen`
/// does not start the server — the composition root does — so a screen rendered straight after
/// construction reports `.starting` whatever it was handed, and a baseline named "serving" showing
/// "Starting…" would be a picture asserting the opposite of its own name.
@Suite("Settings window screen")
@MainActor
struct GranitaSettingsScreenSnapshotTests {

    @Test(arguments: SettingsTab.allCases, MacAppearance.all)
    func `given a Mac that is serving when a pane is opened then it matches its baseline`(
        tab: SettingsTab,
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

        // when
        model.showSettingsTab(tab)

        // then
        assertSettingsSnapshot(
            GranitaSettingsScreen(model: model),
            appearance: appearance,
            named: "serving-\(name(of: tab))"
        )
    }

    @Test(arguments: MacAppearance.all)
    func `given the server did not come up when the window opens then it matches its baseline`(
        appearance: MacAppearance
    ) async {
        // given — what a reader lands in when macOS is withholding local network access, which is
        // the failure this app is most likely to hit on a machine that has never run it. On General,
        // because that is the pane the window opens on and the one carrying the way out.
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

    // MARK: -

    /// Spelled out rather than derived from the case, so a baseline's filename does not change
    /// because a `CustomStringConvertible` somewhere did.
    private func name(of tab: SettingsTab) -> String {
        switch tab {
        case .general: "general"
        case .projects: "projects"
        case .devices: "devices"
        case .connections: "connections"
        case .advanced: "advanced"
        }
    }
}

extension SettingsTab: @retroactive CustomTestStringConvertible {

    public var testDescription: String { "\(self)" }
}
