import SwiftUI
import Testing

import ClientConnectionDomain
import CorePairingDomain

@testable import ClientConnectionPresentation

/// The stack's state and the one rule that reads it: what a pairing that worked does to the path.
///
/// **This is a host test for something that used to be lines of a composition root**, and the move
/// is the point: a rendered baseline can say what one push looks like, and only this can say what a
/// sequence of them does.
///
/// It used to assert a second rule — the 420pt measure everything before a paired Mac was clamped
/// to, and its release past the spine. That measure is gone, so its six tests are too. See
/// `.claude/docs/decisions.md`.
@Suite("Pairing spine navigation")
struct PairingSpineNavigationTests {

    @Test
    func `given a pairing that worked when the Mac is opened then the pairing screens are replaced`() {
        // given — design §5: back from the worktrees returns to the Mac list, never to a viewfinder
        // holding a code that has already been spent. So the path is assigned, not appended.
        let navigation = PairingSpineNavigation(startingAt: NavigationPath())
        navigation.path.append(aMacTheBrowseFound)
        navigation.path.append(PairingStep.scanTheCode)

        // when
        navigation.paired(with: aPairedMac)

        // then
        #expect(navigation.path.count == 1)
    }

    @Test
    func `given the app opens at a pushed Mac when the stack is read then that Mac is on it`() {
        // given - when — the snapshot suite opens the stack at the push it is photographing, which
        // is the only reason this initialiser takes a path at all.
        var path = NavigationPath()
        path.append(aMacTheBrowseFound)
        let navigation = PairingSpineNavigation(startingAt: path)

        // then
        #expect(navigation.path.count == 1)
    }
}

// MARK: -

private let aMacTheBrowseFound = DiscoveredServer(
    id: BonjourInstanceName(rawValue: "Mac Studio"),
    name: "Mac Studio"
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
    fingerprint: SpkiFingerprint(rawValue: "cf83e1357eefb8bdf1542850d66d8007"),
    wakeAddresses: []
)
