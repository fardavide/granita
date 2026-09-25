import Foundation
import Testing

import ClientConnectionDomain

@testable import ClientConnectionData

/// The one record a launch reads before it draws anything, and the two ways it can be absent.
@Suite("User defaults last opened Mac")
struct UserDefaultsLastOpenedMacTests {

    @Test
    func `given a Mac was opened when the record is read then both halves of it come back`() {
        // given
        let scenario = Scenario()

        // when
        scenario.sut.remember(
            DiscoveredServer(id: BonjourInstanceName(rawValue: "Mac-mini-7f21._granita._tcp."), name: "Studio Mac mini")
        )

        // then — the identity and the name are separate strings and are asserted as such, because a
        // record carrying one Mac's instance under another's name resumes onto a screen titled after
        // the wrong machine.
        #expect(scenario.sut.lastOpenedMac()?.id == BonjourInstanceName(rawValue: "Mac-mini-7f21._granita._tcp."))
        #expect(scenario.sut.lastOpenedMac()?.name == "Studio Mac mini")
    }

    @Test
    func `given a phone that has never opened a Mac when the record is read then there is nothing to resume`() {
        // given - when
        let scenario = Scenario()

        // then
        #expect(scenario.sut.lastOpenedMac() == nil)
    }

    @Test
    func `given only the instance name was written when the record is read then there is nothing to resume`() {
        // given — what a defaults file holds after a release that spelled the second key differently.
        // Half a record would resume onto a worktree list with no name on its title.
        let scenario = Scenario()
        scenario.defaults.set("Mac-mini-7f21._granita._tcp.", forKey: UserDefaultsLastOpenedMac.instanceKey)

        // when - then
        #expect(scenario.sut.lastOpenedMac() == nil)
    }

    @Test
    func `given only the name was written when the record is read then there is nothing to resume`() {
        // given
        let scenario = Scenario()
        scenario.defaults.set("Studio Mac mini", forKey: UserDefaultsLastOpenedMac.nameKey)

        // when - then
        #expect(scenario.sut.lastOpenedMac() == nil)
    }

    @Test
    func `given a Mac was opened when it is forgotten then there is nothing to resume`() {
        // given
        let scenario = Scenario()
        scenario.sut.remember(
            DiscoveredServer(id: BonjourInstanceName(rawValue: "MacBook-Pro-0c48._granita._tcp."), name: "Work laptop")
        )

        // when
        scenario.sut.forget()

        // then
        #expect(scenario.sut.lastOpenedMac() == nil)
    }

    @Test
    func `given a Mac was opened when another one is opened then the record names only the second`() {
        // given
        let scenario = Scenario()
        scenario.sut.remember(
            DiscoveredServer(id: BonjourInstanceName(rawValue: "MacBook-Pro-0c48._granita._tcp."), name: "Work laptop")
        )

        // when
        scenario.sut.remember(
            DiscoveredServer(id: BonjourInstanceName(rawValue: "Mac-mini-7f21._granita._tcp."), name: "Studio Mac mini")
        )

        // then
        #expect(scenario.sut.lastOpenedMac()?.name == "Studio Mac mini")
    }

    private struct Scenario {

        let sut: UserDefaultsLastOpenedMac
        let defaults: UserDefaults

        init() {
            // A suite per subject, named for it, so two tests running at once cannot read each
            // other's answer — and removed first, because a suite outlives the process that made it.
            let name = "granita.tests.\(UUID().uuidString)"
            UserDefaults.standard.removePersistentDomain(forName: name)
            defaults = UserDefaults(suiteName: name) ?? .standard
            sut = UserDefaultsLastOpenedMac(defaults: defaults)
        }
    }
}
