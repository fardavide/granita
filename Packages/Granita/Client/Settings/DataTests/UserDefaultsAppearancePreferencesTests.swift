import Foundation
import Testing

import ClientSettingsData
import ClientSettingsDomain
import ClientViewerDomain

/// The two settings this device decides for itself, across launches.
///
/// The defaults are a real suite rather than the shared one, so a test run does not decide which
/// appearance the app opens in the next time it is launched.
@Suite("Remembered appearance preferences")
struct UserDefaultsAppearancePreferencesTests {

    @Test
    func `given nothing was ever stored when the appearance is read then it follows the system`() {
        // given
        let scenario = Scenario()

        // when - then — following the phone is a real answer rather than the absence of one, and it is
        // what every screen did before this setting existed.
        #expect(scenario.sut.appearance() == .system)
    }

    @Test
    func `given nothing was ever stored when the theme is read then it is Xcode's pair`() {
        // given
        let scenario = Scenario()

        // when - then — shipped since 0.8.0, so a reader who never opens the sheet is reported the
        // colours they were already reading in.
        #expect(scenario.sut.codeTheme() == .xcode)
    }

    @Test
    func `given an appearance was remembered when it is read then it is the one that was stored`() {
        // given
        let scenario = Scenario()

        // when
        scenario.sut.remember(AppAppearance.dark)

        // then
        #expect(scenario.sut.appearance() == .dark)
    }

    @Test
    func `given a theme was remembered when it is read then it is the one that was stored`() {
        // given
        let scenario = Scenario()

        // when
        scenario.sut.remember(CodeTheme.stackOverflow)

        // then
        #expect(scenario.sut.codeTheme() == .stackOverflow)
    }

    @Test
    func `given a word no release ever wrote when the appearance is read then the default stands`() {
        // given — a defaults file edited by hand, or written by a version that spelled a case
        // differently. Falling back is the only reading that still draws a screen.
        let scenario = Scenario()
        scenario.defaults.set("sepia", forKey: UserDefaultsAppearancePreferences.appearanceKey)

        // when - then
        #expect(scenario.sut.appearance() == .system)
    }

    @Test
    func `given a theme this build has no stylesheet for when it is read then the default stands`() {
        // given — **the one case here that is reachable without a hand-edited file.** A reader on a
        // newer build picks a sixth pair, restores that backup onto an older one, and the older build
        // has no stylesheet for the name it reads. Xcode's colours are what it shipped with.
        let scenario = Scenario()
        scenario.defaults.set("solarized", forKey: UserDefaultsAppearancePreferences.codeThemeKey)

        // when - then
        #expect(scenario.sut.codeTheme() == .xcode)
    }

    @Test
    func `given side by side was remembered when it is read then it is what was stored`() {
        // given
        let scenario = Scenario()

        // when
        scenario.sut.remember(isSideBySide: true)

        // then
        #expect(scenario.sut.isSideBySide())
    }

    @Test
    func `given no release ever wrote the key when side by side is read then it is off`() {
        // given — every reader updating into this release, and the one case with no stored value at
        // all. Unified is what they have been reading in, and a setting that turned itself on for
        // them would be a layout change nobody asked for on first launch.
        let scenario = Scenario()

        // when - then
        #expect(scenario.sut.isSideBySide() == false)
    }
}

// MARK: -

private struct Scenario {

    let sut: UserDefaultsAppearancePreferences
    let defaults: UserDefaults

    init() {
        // A suite per subject, named for it, so two tests running at once cannot read each other's
        // answer — and removed first, because a suite outlives the process that made it.
        let name = "granita.tests.\(UUID().uuidString)"
        UserDefaults.standard.removePersistentDomain(forName: name)
        defaults = UserDefaults(suiteName: name) ?? .standard
        sut = UserDefaultsAppearancePreferences(defaults: defaults)
    }
}
