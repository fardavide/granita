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

    init(appearance: AppAppearance = .default, codeTheme: CodeTheme = .default) {
        preferences = FakeAppearancePreferences(appearance: appearance, codeTheme: codeTheme)
        sut = AppearanceModel(preferences: preferences)
    }
}
