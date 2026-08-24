import Foundation
import Testing

import ServerMacData
import ServerMacDomain

/// Which pane the Settings window was last on, across launches.
///
/// The defaults are a real suite rather than the shared one, so a test run does not decide which tab
/// opens the next time Davide launches the app.
@Suite("Remembered settings tab")
struct UserDefaultsSettingsTabMemoryTests {

    @Test
    func `given nothing was ever stored when the last pane is read then there is none`() {
        // given
        let scenario = Scenario()

        // when - then — the absence is what a first run is, and it is the caller's job to know what
        // to open instead. Answering with a pane here would make every launch look like a return.
        #expect(scenario.sut.lastUsedTab() == nil)
    }

    @Test
    func `given a pane was remembered when the last pane is read then it is the one that was stored`() {
        // given
        let scenario = Scenario()

        // when
        scenario.sut.remember(.connections)

        // then
        #expect(scenario.sut.lastUsedTab() == .connections)
    }

    @Test
    func `given a pane was remembered when another is remembered then the later one wins`() {
        // given
        let scenario = Scenario()
        scenario.sut.remember(.connections)

        // when
        scenario.sut.remember(.devices)

        // then
        #expect(scenario.sut.lastUsedTab() == .devices)
    }

    @Test
    func `given a word no release ever wrote when the last pane is read then there is none`() {
        // given — a defaults value edited by hand, or written by a version that spelled a pane
        // differently. Either way it names no pane, and a first run is the honest reading of it.
        let scenario = Scenario()
        scenario.defaults.set("diagnostics", forKey: UserDefaultsSettingsTabMemory.defaultsKey)

        // when - then
        #expect(scenario.sut.lastUsedTab() == nil)
    }
}

// MARK: -

private struct Scenario {

    let sut: UserDefaultsSettingsTabMemory
    let defaults: UserDefaults

    init() {
        // A suite per subject, named for it, so two tests running at once cannot read each other's
        // answer — and removed first, because a suite outlives the process that made it.
        let name = "granita.tests.\(UUID().uuidString)"
        UserDefaults.standard.removePersistentDomain(forName: name)
        defaults = UserDefaults(suiteName: name) ?? .standard
        sut = UserDefaultsSettingsTabMemory(defaults: defaults)
    }
}
