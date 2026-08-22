import Observation

import ClientConnectionDomain
import CorePairingDomain

/// Everything the phone knows about Macs nearby and about joining one.
///
/// **One model for the unit, not one per screen.** Discovery and pairing are two views onto the same
/// question — which Mac is this phone talking to — and splitting them across two objects would put
/// the seam where a screen is rather than where a layer is. The discovery list, the pairing sheet
/// and the paired/unpaired sections all read this.
///
/// It holds outcomes and never sequences. Reading a Mac's health, spending the code and writing the
/// token down is one operation over three protocols, and that belongs in the layer that owns them.
@Observable
public final class ClientConnectionModel {

    /// How far an attempt to join a Mac has got, from this screen's point of view.
    public enum PairingState: Hashable, Sendable {
        case notStarted
        case joining
        case finished(PairingOutcome)
    }

    public private(set) var discovery: DiscoveryState = .idle

    /// Which browse is current. The screen keys its task on this, so changing it is what tears the
    /// running browse down and starts another.
    ///
    /// A restart has to be a new browser rather than a new reading of the old one: a dead browser is
    /// dead for good, and the reader taps Search Again precisely when the one they have has stopped
    /// finding anything.
    public private(set) var attempt = 0

    public private(set) var pairing: PairingState = .notStarted

    /// Which Macs this phone holds a token for.
    ///
    /// This is the data the design's *Recent* and *Other Macs* sections are built from. What is
    /// still missing is the **join**: a discovered Mac is a Bonjour instance name, a token is keyed
    /// by the Mac's own instance identifier, and nothing carries the second to the phone until
    /// SPEC §8's TXT record does. Until then the list ships as the single unlabelled section the
    /// design says it degrades to, and this is loaded, correct and not yet joinable.
    public private(set) var pairedServers: Set<ServerInstanceId> = []

    /// Whether the reader is looking at something they can act on rather than something to wait out.
    /// The view offers a route into Settings when this is true.
    public var isPermissionRefused: Bool {
        discovery == .localNetworkDenied
    }

    private let browsing: any ServerDiscovering
    private let joining: any MacJoining

    public init(browsing: any ServerDiscovering, joining: any MacJoining) {
        self.browsing = browsing
        self.joining = joining
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

    /// Reads which Macs this phone has paired with before.
    public func loadPairingHistory() async {
        pairedServers = await joining.alreadyPaired()
    }

    /// Joins the Mac a scanned link points at, and records what came of it.
    public func join(_ link: PairingLink, as device: PairingDevice) async {
        pairing = .joining
        let outcome = await joining.pair(with: link, as: device)
        if case .paired(let paired) = outcome {
            pairedServers.insert(paired.serverInstanceId)
        }
        pairing = .finished(outcome)
    }
}
