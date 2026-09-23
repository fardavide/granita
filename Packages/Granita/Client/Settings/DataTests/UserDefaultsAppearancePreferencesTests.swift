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

    @Test
    func `given no release ever wrote the key when the code size is read then both halves follow the system`() {
        // given — every reader updating into this release. *Follow system* at Large is today's two
        // constants, so nobody's code changes size on the first launch after the update.
        let scenario = Scenario()

        // when - then
        #expect(scenario.sut.codeSize() == .default)
    }

    @Test
    func `given a code size was remembered when it is read then both halves are what was stored`() {
        // given — two halves that differ, so a read that returned one of them twice fails here.
        let scenario = Scenario()

        // when
        scenario.sut.remember(CodeSize(unified: .custom(14), split: .custom(9)))

        // then
        #expect(scenario.sut.codeSize() == CodeSize(unified: .custom(14), split: .custom(9)))
    }

    @Test
    func `given one half was put back on the system when it is read then only that half moved`() {
        // given — the segmented control's other direction, which has to clear the stored number
        // rather than leave it behind for the next read to find.
        let scenario = Scenario()
        scenario.sut.remember(CodeSize(unified: .custom(14), split: .custom(9)))

        // when
        scenario.sut.remember(CodeSize(unified: .followSystem, split: .custom(9)))

        // then
        #expect(scenario.sut.codeSize() == CodeSize(unified: .followSystem, split: .custom(9)))
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
