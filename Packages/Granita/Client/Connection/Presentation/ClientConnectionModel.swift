import Observation

import ClientConnectionDomain
import CorePairingDomain

/// Everything the phone knows about Macs nearby and about joining one.
///
/// **One model for the unit, not one per screen.** Discovery and pairing are two views onto the same
/// question — which Mac is this phone talking to — and splitting them across two objects would put
/// the seam where a screen is rather than where a layer is. The discovery list, the pairing sheet
/// and the paired/unpaired sections all read this.
@Observable
public final class ClientConnectionModel {

    /// How far an attempt to join a Mac has got.
    public enum PairingState: Hashable, Sendable {

        case notStarted

        /// Reading `/v1/health`, **before** the single-use code is spent. A code offered to a Mac
        /// this phone cannot read is a code wasted for a reason the reader never sees.
        case checkingTheContract

        /// The two ends do not speak the same contract, and nothing was spent finding out.
        case wrongContract(ApiCompatibility)

        case pairing

        case paired(ServerInstanceId)

        case failed(ApiFailure)

        /// Paired, and the token could not be written down.
        ///
        /// The worst outcome there is, and it earns a case of its own: the Mac now has a device
        /// record for a credential this phone does not hold, so the reader has to revoke it there
        /// before pairing again.
        case tokenNotStored(PairingTokenStoreFailure)
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
    private let tokens: any PairingTokenStore
    private let handshake: (PairingLink) -> any ServerPairing

    /// - Parameter handshake: builds the client for one Mac. A closure rather than a stored client,
    ///   because a pinned session is per Mac: the fingerprint arrives with the link, and a session
    ///   built for one Mac must be unable to reach another.
    public init(
        browsing: any ServerDiscovering,
        tokens: any PairingTokenStore,
        handshake: @escaping (PairingLink) -> any ServerPairing
    ) {
        self.browsing = browsing
        self.tokens = tokens
        self.handshake = handshake
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
    ///
    /// Silent on failure by design: a Keychain that will not enumerate costs an ordering, and
    /// refusing to show the Macs that are actually on the network because of it would be a worse
    /// screen than an unordered list.
    public func loadPairingHistory() async {
        pairedServers = (try? await tokens.pairedServers()) ?? []
    }

    /// Spends a pairing code and keeps the only copy of what it buys.
    ///
    /// The contract is checked first and the code is spent second, in that order and never the
    /// other way round: a code is single use and lasts two minutes, so discovering the skew
    /// afterwards costs the reader a trip back to the Mac for another one.
    public func pair(using link: PairingLink, as device: PairingDevice) async {
        let server = handshake(link)
        pairing = .checkingTheContract
        do {
            let health = try await server.health()
            guard health.compatibility == .sameContract else {
                pairing = .wrongContract(health.compatibility)
                return
            }

            pairing = .pairing
            let paired = try await server.pair(with: link.code, as: device)
            do {
                try await tokens.save(paired.token, issuedBy: paired.serverInstanceId)
            } catch {
                pairing = .tokenNotStored(error)
                return
            }
            pairedServers.insert(paired.serverInstanceId)
            pairing = .paired(paired.serverInstanceId)
        } catch {
            pairing = .failed(error)
        }
    }
}
