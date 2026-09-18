import Testing

import ServerMacDomain

/// The order of the panes, and the names they are written down under.
///
/// Both are contracts rather than details. The order is design §2's, and the window's tab bar is
/// built by walking these cases; the spelling is what a previous release wrote into this Mac's
/// defaults, so changing one silently sends a reader back to the pane they were not on.
@Suite("Settings tab")
struct SettingsTabTests {

    @Test
    func `given the panes when they are listed then Advanced is last and Review is fourth`() {
        // given - when - then — the first four are the pipeline outward: this Mac, what it serves,
        // who may read it, and what comes back from them. Then live diagnostics, then the drawer
        // with Reset All Data at the bottom of it.
        #expect(
            SettingsTab.allCases == [.general, .projects, .devices, .review, .connections, .advanced]
        )
    }

    @Test(arguments: [
        (SettingsTab.general, "general"),
        (SettingsTab.projects, "projects"),
        (SettingsTab.devices, "devices"),
        (SettingsTab.review, "review"),
        (SettingsTab.connections, "connections"),
        (SettingsTab.advanced, "advanced")
    ])
    func `given a pane when it is written down then it keeps the spelling an earlier release stored`(
        tab: SettingsTab,
        spelling: String
    ) {
        // given - when - then
        #expect(tab.rawValue == spelling)
    }
}
