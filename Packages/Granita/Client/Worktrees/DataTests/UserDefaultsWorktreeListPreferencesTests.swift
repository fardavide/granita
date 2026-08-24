import Foundation
import Testing

import ClientWorktreesData
import ClientWorktreesDomain

/// How the sidebar was left, across launches.
///
/// The defaults are a real suite rather than the shared one, so a test run does not decide how the
/// list opens the next time the app is launched.
@Suite("Remembered worktree list preferences")
struct UserDefaultsWorktreeListPreferencesTests {

    @Test
    func `given nothing was ever stored when the mode is read then it is grouped by project`() {
        // given
        let scenario = Scenario()

        // when - then — the first run groups, because one project is not a special case: a single
        // section header costs 28pt once, and starting flat would make the list change shape the day
        // a second project is added.
        #expect(scenario.sut.mode() == .groupedByProject)
    }

    @Test
    func `given nothing was ever stored when the quiet switch is read then they are hidden`() {
        // given
        let scenario = Scenario()

        // when - then
        #expect(scenario.sut.showsQuietWorktrees() == false)
    }

    @Test
    func `given a mode was remembered when it is read then it is the one that was stored`() {
        // given
        let scenario = Scenario()

        // when
        scenario.sut.remember(.mostRecentFirst)

        // then
        #expect(scenario.sut.mode() == .mostRecentFirst)
    }

    @Test
    func `given the quiet ones were shown when the switch is read then they still are`() {
        // given
        let scenario = Scenario()

        // when
        scenario.sut.rememberShowingQuietWorktrees(true)

        // then
        #expect(scenario.sut.showsQuietWorktrees())
    }

    @Test
    func `given a word no release ever wrote when the mode is read then the default stands`() {
        // given — a defaults value edited by hand, or written by a version that spelled a mode
        // differently. Falling back is the only reading that still opens a list.
        let scenario = Scenario()
        scenario.defaults.set("alphabetical", forKey: UserDefaultsWorktreeListPreferences.modeKey)

        // when - then
        #expect(scenario.sut.mode() == .groupedByProject)
    }
}

// MARK: -

private struct Scenario {

    let sut: UserDefaultsWorktreeListPreferences
    let defaults: UserDefaults

    init() {
        // A suite per subject, named for it, so two tests running at once cannot read each other's
        // answer — and removed first, because a suite outlives the process that made it.
        let name = "granita.tests.\(UUID().uuidString)"
        UserDefaults.standard.removePersistentDomain(forName: name)
        defaults = UserDefaults(suiteName: name) ?? .standard
        sut = UserDefaultsWorktreeListPreferences(defaults: defaults)
    }
}
