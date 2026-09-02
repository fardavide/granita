import SwiftUI
import Testing

import ClientConnectionDomain
import ClientConnectionUi
import CorePairingDomain

@testable import ClientConnectionPresentation

/// The stack's state and the one rule that reads it: how wide the app is allowed to be.
///
/// **This is a host test for something that used to be four lines of a composition root**, and the
/// move is the point. Design §5 clamps everything before a paired Mac to a 420pt centred column and
/// §2 gives the worktree list a split view that needs the window, so the container carries a
/// decision — and the version of that decision that shipped in 0.4.1 released the measure only for a
/// Mac *just paired with*, which is the rarer of the two ways past the spine by far. A Mac is paired
/// with once and opened every day after, and every one of those days the iPad drew its worktrees
/// through a phone-shaped slot.
///
/// A rendered baseline can say what one push looks like. Only this can say what the sequence does.
@Suite("Pairing spine navigation")
struct PairingSpineNavigationTests {

    @Test
    func `given the Mac list when the measure is read then it is the pairing column`() {
        // given - when
        let navigation = PairingSpineNavigation(startingAt: NavigationPath())

        // then
        #expect(navigation.contentWidth == ServerDiscoveryView.contentWidth)
    }

    @Test
    func `given a Mac being paired with when the measure is read then it is still the pairing column`() {
        // given — the pairing spine is everything the clamp is for: a Mac's own screen, the
        // viewfinder, the six words and the receipt all sit at depth one or deeper.
        let navigation = PairingSpineNavigation(startingAt: NavigationPath())

        // when
        navigation.path.append(aMacTheBrowseFound)

        // then
        #expect(navigation.contentWidth == ServerDiscoveryView.contentWidth)
    }

    @Test
    func `given a worktree list was opened when the measure is read then it is the whole window`() {
        // given
        let navigation = PairingSpineNavigation(startingAt: NavigationPath())
        navigation.path.append(aMacTheBrowseFound)

        // when
        navigation.openedAWorktreeList()

        // then
        #expect(navigation.contentWidth == .infinity)
    }

    @Test
    func `given a diff was opened over a worktree list when the measure is read then it is still the whole window`() {
        // given — the phone pushes a worktree over the list rather than opening a column beside it,
        // so the path grows past the one screen that released the measure. Nothing about that puts
        // the reader back before the spine.
        let navigation = PairingSpineNavigation(startingAt: NavigationPath())
        navigation.path.append(aMacTheBrowseFound)
        navigation.openedAWorktreeList()

        // when
        navigation.path.append(aMacTheBrowseFound)

        // then
        #expect(navigation.contentWidth == .infinity)
    }

    @Test
    func `given a worktree list when the reader goes back to the Mac list then the measure returns`() {
        // given
        let navigation = PairingSpineNavigation(startingAt: NavigationPath())
        navigation.path.append(aMacTheBrowseFound)
        navigation.openedAWorktreeList()

        // when — the system's own back button, which nothing of ours is told about: emptying the
        // path is the only signal there is.
        navigation.path = NavigationPath()

        // then
        #expect(navigation.contentWidth == ServerDiscoveryView.contentWidth)
    }

    @Test
    func `given a worktree list was left when another Mac is paired with then the measure is the pairing column`() {
        // given — the whole of what the reset is for. Without it the second Mac's pairing screens
        // inherit the first Mac's worktree measure, and the six-word field draws at full window
        // width on an iPad.
        let navigation = PairingSpineNavigation(startingAt: NavigationPath())
        navigation.path.append(aMacTheBrowseFound)
        navigation.openedAWorktreeList()
        navigation.path = NavigationPath()

        // when
        navigation.path.append(aMacTheBrowseFound)

        // then
        #expect(navigation.contentWidth == ServerDiscoveryView.contentWidth)
    }

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
    func `given the app opens at a pushed Mac when the measure is read then it is the pairing column`() {
        // given - when — the snapshot suite opens the stack at the push it is photographing, which
        // is the only reason this initialiser takes a path at all.
        var path = NavigationPath()
        path.append(aMacTheBrowseFound)
        let navigation = PairingSpineNavigation(startingAt: path)

        // then
        #expect(navigation.path.count == 1)
        #expect(navigation.contentWidth == ServerDiscoveryView.contentWidth)
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
