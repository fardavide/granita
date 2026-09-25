import SwiftUI
import Testing

import ClientConnectionDomain
import CorePairingDomain

@testable import ClientConnectionPresentation

/// The stack's state and the rules that read it: what a pairing that worked does to the path, and
/// where a launch opens.
///
/// **This is a host test for something that used to be lines of a composition root**, and the move
/// is the point: a rendered baseline can say what one push looks like, and only this can say what a
/// sequence of them does — or what happens before the first one is drawn at all.
///
/// It used to assert a second rule — the 420pt measure everything before a paired Mac was clamped
/// to, and its release past the spine. That measure is gone, so its six tests are too. See
/// `.ai/docs/decisions.md`.
@Suite("Pairing spine navigation")
struct PairingSpineNavigationTests {

    @Test
    func `given a selected Mac on an existing stack when pairing again then its typed pairing destination replaces that stack`() {
        // given
        let server = DiscoveredServer(id: BonjourInstanceName(rawValue: "Mac awaiting a new pairing"), name: "Review Mac")
        var path = NavigationPath()
        path.append(server)
        path.append(PairingStep.scanTheCode)
        let scenario = Scenario(startingAt: path)

        // when
        scenario.sut.pairAgain(with: server)

        // then
        #expect(scenario.sut.path == NavigationPath([PairingAgain(server: server)]))
    }

    @Test
    func `given a pairing that worked when the Mac is opened then the pairing screens are replaced`() {
        // given — design §5: back from the worktrees returns to the Mac list, never to a viewfinder
        // holding a code that has already been spent. So the path is assigned, not appended.
        let scenario = Scenario()
        scenario.sut.path.append(aMacTheBrowseFound)
        scenario.sut.path.append(PairingStep.scanTheCode)

        // when
        scenario.sut.paired(with: aPairedMac)

        // then
        #expect(scenario.sut.path.count == 1)
    }

    @Test
    func `given the app opens at a pushed Mac when the stack is read then that Mac is on it`() {
        // given - when — the snapshot suite opens the stack at the push it is photographing, which
        // is the only reason this initialiser takes a path at all.
        var path = NavigationPath()
        path.append(aMacTheBrowseFound)
        let scenario = Scenario(startingAt: path)

        // then
        #expect(scenario.sut.path.count == 1)
    }

    // MARK: - Where a launch opens

    @Test
    func `given a Mac this phone opened last when the app opens then its worktrees are on the stack`() {
        // given - when — the whole of what resuming is. The value is `ResumedMac` rather than the
        // Mac itself, because the destination a browsed Mac reaches is decided against a set filled
        // by a task that has not run when this path is first resolved.
        let scenario = Scenario(havingOpened: aMacTheBrowseFound)

        // then
        #expect(scenario.sut.path == NavigationPath([ResumedMac(server: aMacTheBrowseFound)]))
    }

    @Test
    func `given a phone that has never opened a Mac when the app opens then it opens at the Mac list`() {
        // given - when
        let scenario = Scenario()

        // then
        #expect(scenario.sut.path.isEmpty)
    }

    @Test
    func `given a Mac this phone opened last when the stack is opened at a push then that push is kept`() {
        // given — the snapshot suite, on a machine whose defaults happen to hold a record. A resume
        // that took a given path over would photograph a screen no baseline asked for.
        var path = NavigationPath()
        path.append(PairingAgain(server: anotherMacTheBrowseFound))

        // when
        let scenario = Scenario(startingAt: path, havingOpened: aMacTheBrowseFound)

        // then
        #expect(scenario.sut.path == NavigationPath([PairingAgain(server: anotherMacTheBrowseFound)]))
    }

    // MARK: - What the next launch resumes

    @Test
    func `given a Mac already paired with when its worktrees are opened then the next launch opens there`() {
        // given
        let scenario = Scenario()

        // when
        scenario.sut.opened(anotherMacTheBrowseFound)

        // then
        #expect(scenario.lastOpened.remembered == anotherMacTheBrowseFound)
    }

    @Test
    func `given a pairing that worked when the Mac is opened then the next launch opens there`() {
        // given — the other route past the spine, and it has to write the same record: a reader who
        // paired on this launch is reading that Mac's worktrees on the next one.
        let scenario = Scenario()

        // when
        scenario.sut.paired(with: aPairedMac)

        // then
        #expect(scenario.lastOpened.remembered == aMacTheBrowseFound)
    }

    @Test
    func `given a Mac this phone opened last when it has to be paired with again then nothing is resumed`() {
        // given — *Pair Again* is the one control a revoked pairing offers, so reaching it means the
        // credential behind the resume is the thing in question. A launch that went on assuming it
        // would land on a worktree list that can only fail.
        let scenario = Scenario(havingOpened: aMacTheBrowseFound)

        // when
        scenario.sut.pairAgain(with: aMacTheBrowseFound)

        // then
        #expect(scenario.lastOpened.remembered == nil)
    }

    private struct Scenario {

        let sut: PairingSpineNavigation
        let lastOpened: FakeLastOpenedMacPreference

        init(startingAt path: NavigationPath = NavigationPath(), havingOpened mac: DiscoveredServer? = nil) {
            lastOpened = FakeLastOpenedMacPreference(opened: mac)
            sut = PairingSpineNavigation(startingAt: path, remembering: lastOpened)
        }
    }
}

// MARK: -

private let aMacTheBrowseFound = DiscoveredServer(
    id: BonjourInstanceName(rawValue: "Mac Studio"),
    name: "Mac Studio"
)

private let anotherMacTheBrowseFound = DiscoveredServer(
    id: BonjourInstanceName(rawValue: "MacBook Pro (work)"),
    name: "MacBook Pro (work)"
)

/// What a pairing produces, and the value the path carries on the other route past the spine.
private let aPairedMac = PairedMac(
    instance: aMacTheBrowseFound.id,
    name: aMacTheBrowseFound.name,
    device: PairedDevice(
        token: PairingToken(rawValue: "1f0e4d7c6b5a49382736251403f2e1d0"),
        deviceId: DeviceId(rawValue: "8C4F2A11-0000-4E5D-9A3B-77F1C0DE0001"),
        serverInstanceId: ServerInstanceId(rawValue: "3B9AC0DE-1111-4A2C-8D6E-55E0B1CAFE22")
    ),
    address: ServerAddress(host: "mac-studio.local", port: 59_144),
    fallbackAddress: nil,
    fingerprint: SpkiFingerprint(rawValue: "cf83e1357eefb8bdf1542850d66d8007"),
    wakeAddresses: []
)
