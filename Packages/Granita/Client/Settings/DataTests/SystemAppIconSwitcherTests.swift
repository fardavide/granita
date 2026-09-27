import Testing

import ClientSettingsData
import ClientSettingsDomain

/// How an icon is named to the system, and what a device that cannot change its icon answers.
@Suite("System app icon switcher")
@MainActor
struct SystemAppIconSwitcherTests {

    // MARK: - Naming an icon to the system

    @Test
    func `given the glass when it is named to the system then it is the primary icon`() {
        // given - when - then — iOS spells *the app's own icon* as no name at all, so asking for the
        // glass by any string would ask for an icon set that does not exist.
        #expect(SystemAppIconSwitcher.alternateName(for: .granita) == nil)
    }

    @Test
    func `given the cube when it is named to the system then it is the alternate icon set`() {
        // given - when - then — the name the asset catalog's icon set is built under, which the build
        // setting in `project.yml` lists and `make icons` writes.
        #expect(SystemAppIconSwitcher.alternateName(for: .iceCube) == "AppIcon-IceCube")
    }

    @Test
    func `given the system reports no alternate when the icon is read then it is the glass`() {
        // given - when - then
        #expect(SystemAppIconSwitcher.icon(forAlternateName: nil) == .granita)
    }

    @Test
    func `given the system reports the cube's set when the icon is read then it is the cube`() {
        // given - when - then
        #expect(SystemAppIconSwitcher.icon(forAlternateName: "AppIcon-IceCube") == .iceCube)
    }

    @Test
    func `given a name no release ever shipped when the icon is read then the default stands`() {
        // given — reachable only by an older build reading a name a newer one set, since iOS keeps the
        // alternate across an update. The glass is what that build ships as its own icon.
        let name = "AppIcon-Retired"

        // when - then
        #expect(SystemAppIconSwitcher.icon(forAlternateName: name) == .granita)
    }

    // MARK: - A device that cannot change its icon

    #if !canImport(UIKit)
    @Test
    func `given a Mac when it is asked whether the icon can change then it cannot`() {
        // given - when - then — which is what makes the row absent there rather than dead.
        #expect(SystemAppIconSwitcher().canChangeIcon == false)
    }

    @Test
    func `given a Mac when the icon is read then it is the one Granita ships with`() {
        // given - when - then
        #expect(SystemAppIconSwitcher().currentIcon() == .granita)
    }

    @Test
    func `given a Mac when it is asked to show the cube then it refuses in words`() async {
        // given
        let sut = SystemAppIconSwitcher()

        // when - then — unreachable through the screen, which draws no row here; refusing rather than
        // succeeding silently keeps a future caller from reporting a change that never happened.
        await #expect(throws: AppIconRefusal(reason: "This device shows the icon Granita was built with.")) {
            try await sut.show(.iceCube)
        }
    }
    #endif
}
