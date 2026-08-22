import Observation

import ClientConnectionDomain

/// What the phone knows about Macs nearby.
///
/// **One model for the unit, not one per screen.** Discovery and pairing are two views onto the same
/// question — which Mac is this phone talking to — so when the pairing sheet exists it reads this
/// rather than bringing a second state object with it.
///
/// It carries only the browse today, deliberately. `MacPairing` in `Domain` is what joins a Mac, and
/// it is built and tested; nothing on this side calls it because there is no scanner and no pairing
/// sheet to call it from, and a property no screen reads is a property no screen has agreed to.
/// The pairing surface lands here in the pull request that draws the screen.
@Observable
public final class ClientConnectionModel {

    public private(set) var discovery: DiscoveryState = .idle

    /// Which browse is current. The screen keys its task on this, so changing it is what tears the
    /// running browse down and starts another.
    ///
    /// A restart has to be a new browser rather than a new reading of the old one: a dead browser is
    /// dead for good, and the reader taps Search Again precisely when the one they have has stopped
    /// finding anything.
    public private(set) var attempt = 0

    private let browsing: any ServerDiscovering

    public init(browsing: any ServerDiscovering) {
        self.browsing = browsing
    }

    /// Consumes discovery updates until the stream ends or the surrounding task is cancelled.
    ///
    /// Servers appear and disappear while the screen is open — a Mac waking from sleep is the common
    /// case — so this follows the stream rather than taking one reading.
    public func start() async {
        for await update in browsing.discover() {
            discovery = update
        }
    }

    /// Throws the current browse away and begins another.
    ///
    /// Reported as searching straight away rather than waiting for the replacement to say so,
    /// because the tap has to visibly do something and searching is what is true from this instant.
    public func searchAgain() {
        discovery = .searching
        attempt += 1
    }
}
