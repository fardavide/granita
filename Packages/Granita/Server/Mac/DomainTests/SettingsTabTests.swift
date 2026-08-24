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
    func `given the panes when they are listed then Advanced is last and Connections is its own`() {
        // given - when - then
        #expect(SettingsTab.allCases == [.general, .projects, .devices, .connections, .advanced])
    }

    @Test(arguments: [
        (SettingsTab.general, "general"),
        (SettingsTab.projects, "projects"),
        (SettingsTab.devices, "devices"),
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
