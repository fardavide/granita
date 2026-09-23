import SwiftUI
import Testing

import ClientSettingsDomain
import ClientSettingsPresentation
import ClientViewerDomain

/// What this device decides for itself, and the one thing that makes it different from every other
/// model in this app: it cannot fail, so there is no standing to assert and no failure to arrange.
@Suite("Appearance model")
@MainActor
struct AppearanceModelTests {

    @Test
    func `given nothing ever chosen when the model is made then it follows the system in Xcode's colours`() {
        // given
        let scenario = Scenario()

        // when - then
        #expect(scenario.sut.appearance == .system)
        #expect(scenario.sut.codeTheme == .xcode)
    }

    @Test
    func `given values already stored when the model is made then it opens on them`() {
        // given — **no `load()` and nothing to await**, which is the whole shape of this model: both
        // values are local, so they are in hand the moment it exists and the sheet has no loading state
        // to draw.
        let scenario = Scenario(appearance: .dark, codeTheme: .stackOverflow)

        // when - then
        #expect(scenario.sut.appearance == .dark)
        #expect(scenario.sut.codeTheme == .stackOverflow)
    }

    @Test
    func `given an appearance chosen when it is read back then the device remembered it`() {
        // given
        let scenario = Scenario()

        // when
        scenario.sut.choose(AppAppearance.light)

        // then — on the model for this launch, and in the defaults for the next one. The second
        // expectation is the one that matters: a picker that moved only the first would look right until
        // the app was relaunched.
        #expect(scenario.sut.appearance == .light)
        #expect(scenario.preferences.appearance() == .light)
    }

    @Test
    func `given a theme chosen when it is read back then the device remembered it`() {
        // given
        let scenario = Scenario()

        // when
        scenario.sut.choose(CodeTheme.atomOne)

        // then
        #expect(scenario.sut.codeTheme == .atomOne)
        #expect(scenario.preferences.codeTheme() == .atomOne)
    }

    @Test
    func `given a theme chosen when the appearance is read then it did not move`() {
        // given — the two settings share a section and a footer, and nothing else. A reader picking
        // colours has not asked to stop following their phone.
        let scenario = Scenario(appearance: .dark)

        // when
        scenario.sut.choose(CodeTheme.atomOne)

        // then
        #expect(scenario.sut.appearance == .dark)
    }

    @Test
    func `given side by side chosen when it is read back then the device remembered it`() {
        // given — off is what every reader has been reading in, so the interesting direction is on.
        let scenario = Scenario()

        // when
        scenario.sut.chooseSideBySide(true)

        // then — the second expectation is the whole point of the control. A change set with no
        // paired run in it draws identically either way, so being remembered is the *only*
        // perceivable effect a press can have there, and a model that moved the flag without writing
        // it would look right until the app was relaunched.
        #expect(scenario.sut.isSideBySide)
        #expect(scenario.preferences.isSideBySide())
    }

    @Test
    func `given side by side turned back off when it is read back then that was remembered too`() {
        // given — a reader who tried it and went back. The off direction has to persist as well, or
        // the setting is a one-way door.
        let scenario = Scenario(isSideBySide: true)

        // when
        scenario.sut.chooseSideBySide(false)

        // then
        #expect(scenario.sut.isSideBySide == false)
        #expect(scenario.preferences.isSideBySide() == false)
    }

    @Test
    func `given side by side chosen when the theme and appearance are read then neither moved`() {
        // given — three settings share one device and nothing else. Asking for two columns is not
        // asking for different colours.
        let scenario = Scenario(appearance: .dark, codeTheme: .atomOne)

        // when
        scenario.sut.chooseSideBySide(true)

        // then
        #expect(scenario.sut.appearance == .dark)
        #expect(scenario.sut.codeTheme == .atomOne)
    }

    // MARK: - The code's size

    @Test
    func `given a code size chosen when it is read back then the device remembered it`() {
        // given
        let scenario = Scenario()

        // when — two halves that differ, so a model writing one of them into both fails here.
        scenario.sut.choose(CodeSize(unified: .custom(13), split: .custom(10)))

        // then
        #expect(scenario.sut.codeSize == CodeSize(unified: .custom(13), split: .custom(10)))
        #expect(scenario.preferences.codeSize() == CodeSize(unified: .custom(13), split: .custom(10)))
    }

    @Test
    func `given a code size chosen when the other three settings are read then none of them moved`() {
        // given — four settings share one device and nothing else.
        let scenario = Scenario(appearance: .dark, codeTheme: .atomOne, isSideBySide: true)

        // when
        scenario.sut.choose(CodeSize(unified: .custom(13), split: .followSystem))

        // then
        #expect(scenario.sut.appearance == .dark)
        #expect(scenario.sut.codeTheme == .atomOne)
        #expect(scenario.sut.isSideBySide)
    }

    @Test
    func `given a phone that has reported itself when the readout is asked for then it is that phone's`() {
        // given — the four facts the screen's sentences are arithmetic over, and the only place they
        // are all held at once.
        let scenario = Scenario()
        scenario.sut.note(windowWidth: 390, fitsSelectorColumn: false, textSize: .default)

        // when
        scenario.sut.choose(CodeSize(unified: .custom(10), split: .followSystem))

        // then — 54 characters a line at 10pt and 22 a side at the system's 11, which is issue
        // #106's own table read from the two halves at once.
        #expect(scenario.sut.codeSizeReadout.unified.characters == 54)
        #expect(scenario.sut.codeSizeReadout.split.pointSize == 11)
        #expect(scenario.sut.codeSizeReadout.split.characters == 22)
    }

    // MARK: - How wide a row of code is here

    @Test
    func `given nothing has been measured when the row width is read then it is nothing`() {
        // given - when - then — a first render has not reported a geometry yet, and an invented width
        // would have the *Code size* screen state a character count for a device that is not there.
        #expect(Scenario().sut.diffRowWidth == 0)
    }

    @Test
    func `given a phone's window when it is noted then the whole of it is the row`() {
        // given — no column fits, so the code has the window.
        let scenario = Scenario()

        // when
        scenario.sut.note(windowWidth: 390, fitsSelectorColumn: false, textSize: .xLarge)

        // then — 390pt, which is the width every number in design §4 and in issue #106 is stated at.
        #expect(scenario.sut.diffRowWidth == 390)
        #expect(scenario.sut.fitsSelectorColumn == false)
        #expect(scenario.sut.textSize == .xLarge)
    }

    @Test
    func `given a window wide enough for the tree when it is noted then the tree's width comes off it`() {
        // given — **the room rather than the fold**, which is `DiffPaneLayout`'s own rule: folding the
        // tree gives the code more space, and taking the size up with it would reflow every row of the
        // file the reader is looking at in exchange for a fold they may undo a second later.
        let scenario = Scenario()

        // when
        scenario.sut.note(windowWidth: 1_194, fitsSelectorColumn: true, textSize: .default)

        // then
        #expect(scenario.sut.diffRowWidth == 1_194 - DiffPaneLayout.selectorColumnWidth)
        #expect(scenario.sut.fitsSelectorColumn)
    }

    // MARK: - What the app draws in

    @Test
    func `given the system appearance when the scheme is read then nothing is forced`() {
        // given — **`nil` is what makes System work**: it is SwiftUI's own spelling of *do not
        // override*, so following the phone costs no branch and a sunset keeps working. A model that
        // answered `.light` here would pin every reader to light for the life of the app.
        let scenario = Scenario(appearance: .system)

        // when - then
        #expect(scenario.sut.colorScheme == nil)
    }

    @Test(arguments: [(AppAppearance.light, ColorScheme.light), (.dark, .dark)])
    func `given a forced appearance when the scheme is read then it is that one`(
        appearance: AppAppearance,
        expected: ColorScheme
    ) {
        // given
        let scenario = Scenario(appearance: appearance)

        // when - then
        #expect(scenario.sut.colorScheme == expected)
    }
}

// MARK: -

@MainActor
private struct Scenario {

    let sut: AppearanceModel
    let preferences: FakeAppearancePreferences

    init(
        appearance: AppAppearance = .default,
        codeTheme: CodeTheme = .default,
        isSideBySide: Bool = false
    ) {
        preferences = FakeAppearancePreferences(
            appearance: appearance,
            codeTheme: codeTheme,
            isSideBySide: isSideBySide
        )
        sut = AppearanceModel(preferences: preferences)
    }
}
