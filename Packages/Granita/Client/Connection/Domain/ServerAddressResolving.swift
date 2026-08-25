/// Turns a Mac the browse listed into somewhere a request can be sent.
///
/// **Only the spoken path needs this.** A scanned link carries a host and a port on the Mac's own
/// screen, so the camera arrives with an address before it has anything else. Six words carry a code
/// and nothing else, and what the browse offered alongside them is a Bonjour instance name — an
/// identity, not a location. Something has to close that gap, and it is this.
///
/// A one-shot rather than a stream, unlike the browse next door: what comes back is spent
/// immediately on one handshake and is stale the moment the Mac restarts, so there is nothing here
/// for a screen to keep watching.
public protocol ServerAddressResolving: Sendable {

    func address(of server: DiscoveredServer) async throws(ServerAddressResolutionFailure) -> ServerAddress
}

// MARK: -

/// Why a Mac the browse listed could not be turned into an address.
///
/// **Two cases, because two is what a screen can say something different about.** Every other
/// distinction a resolver could draw — no such record, no route, a connection that came up and died
/// — ends in the same sentence and the same button, so they arrive as one case carrying what the
/// system said rather than as a vocabulary nothing branches on.
public enum ServerAddressResolutionFailure: Error, Hashable, Sendable {

    /// Nothing answered for that Mac: it slept, it left the network, or the browse result outlived
    /// the thing that published it. Trying again is the whole remedy, which is the row design §5's
    /// outcome screen already draws.
    ///
    /// The payload is a **diagnostic**, not advice, and the label says so: the screen writes its own
    /// sentence and prints this underneath in small print. Handing Network.framework's own words to
    /// the line a reader acts on makes the advice "the operation couldn't be completed" — true of
    /// every failure there has ever been, and actionable in none of them.
    case unreachable(diagnostic: String)

    /// iOS will not let this app speak to the local network at all.
    ///
    /// Its own case for the reason the browse next door gives it one: it is the one a reader can
    /// fix, and folding it into `unreachable` would put *Try Again* in front of a permission that
    /// will never grant itself. It is reachable from here even though only a browse result leads
    /// here — the switch lives in Settings, and the app was in the background while it was thrown.
    case localNetworkDenied
}
