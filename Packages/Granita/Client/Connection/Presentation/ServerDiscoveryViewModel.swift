import ClientConnectionDomain
import Observation

/// Drives the screen the app opens on before it is paired.
///
/// It owns one piece of state and no view. Everything it needs arrives through a protocol its own
/// Domain declares, so a test drives it with a hand-written fake and no network, no Bonjour and no
/// simulator.
@Observable
public final class ServerDiscoveryViewModel {

    public private(set) var state: DiscoveryState = .idle

    /// Which browse is current. The screen keys its task on this, so changing it is what tears the
    /// running browse down and starts another.
    ///
    /// A restart has to be a new browser rather than a new reading of the old one: a dead browser is
    /// dead for good, and the reader taps Search Again precisely when the one they have has stopped
    /// finding anything.
    public private(set) var attempt = 0

    /// Whether the user is looking at something they can act on, rather than something to wait out.
    /// The view offers a route into Settings when this is true.
    public var isPermissionRefused: Bool {
        state == .localNetworkDenied
    }

    private let discovery: any ServerDiscovering

    public init(discovery: any ServerDiscovering) {
        self.discovery = discovery
    }

    /// Consumes discovery updates until the stream ends or the surrounding task is cancelled.
    ///
    /// Servers appear and disappear while the screen is open — a Mac waking from sleep is the common
    /// case — so this follows the stream rather than taking one reading.
    public func start() async {
        for await update in discovery.discover() {
            state = update
        }
    }

    /// Throws the current browse away and begins another.
    ///
    /// Reported as searching straight away rather than waiting for the replacement to say so, because
    /// the tap has to visibly do something and searching is what is true from this instant.
    public func searchAgain() {
        state = .searching
        attempt += 1
    }
}
