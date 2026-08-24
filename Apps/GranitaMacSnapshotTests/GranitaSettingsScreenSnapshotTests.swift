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

    /// **The sheet is not in this picture, and the name says so.** A hosted view presents a `.sheet`
    /// into a window of its own, which the raster does not include — the same limitation as the tab
    /// bar above, and for the same reason. What the baseline pins is that presenting it leaves the
    /// pane beneath undisturbed; what the test *executes* is the presentation itself, which is the
    /// part that had never run: the `.sheet` builder, the binding it reads, and the branch deciding
    /// there is a scan to show. Measured — it takes `GranitaSettingsScreen` from 47 uncovered
    /// regions to 43.
    ///
    /// Naming it for the sheet would be a picture asserting the opposite of its own name, which this
    /// suite already refuses one line above.
    @Test(arguments: MacAppearance.all)
    func `given a scan found repositories when the window is drawn then the pane beneath is undisturbed`(
        appearance: MacAppearance
    ) async {
        // given — the one thing the window does that is not a pane: it presents design §4's sheet
        // over Projects. Every other baseline here photographs a tab, so the presentation itself was
        // composition no picture executed, on the flow that is the security boundary.
        let model = SettingsScreenFakes.model(
            state: .running(ServerEndpoint(host: "macbook-pro.local", port: 59_144)),
            attempts: [],
            git: .available(version: "2.52.0", path: "/opt/homebrew/bin/git"),
            projects: 2,
            devices: 2,
            candidates: [
                RepositoryCandidate(path: "/Users/davide/Dev/Oltre", name: "Oltre", relativePath: "Oltre"),
                RepositoryCandidate(
                    path: "/Users/davide/Dev/experiments/granita",
                    name: "granita",
                    relativePath: "experiments/granita"
                )
            ]
        )
        await SettingsScreenFakes.drive(model)
        model.showSettingsTab(.projects)

        // when — the scan a reader starts from the plus bar, which puts its results in front of them
        // rather than into the list.
        await model.scanForRepositories(under: URL(filePath: "/Users/davide/Dev", directoryHint: .isDirectory))

        // then
        assertSettingsSnapshot(
            GranitaSettingsScreen(model: model),
            appearance: appearance,
            named: "projects-beneath-the-scan-sheet"
        )
    }

    @Test(arguments: MacAppearance.all)
    func `given the server did not come up when the window opens then it matches its baseline`(
        appearance: MacAppearance
    ) async {
        // given — what a reader lands in when macOS is withholding local network access, which is
        // the failure this app is most likely to hit on a machine that has never run it. On General,
        // because that is the pane carrying the way out — and the fake memory says General was the
        // last one up, since a Mac with nothing remembered opens on Projects now.
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
