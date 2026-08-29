/// A resolve that wakes the Mac and asks again, rather than giving up the first time nothing answers.
///
/// **The browse can be a step ahead of the machine.** A Mac woken at the start of a browse takes
/// seconds to come back — the radio, then the network, then mDNSResponder re-publishing what it
/// withdrew on the way down — and the record the phone is holding in the meantime resolves to
/// nothing. One attempt, and the reader gets *Could not read your Mac* about a Mac that is at that
/// moment waking up two rooms away.
///
/// **Only `unreachable` is retried.** A refused local-network permission is not a Mac that is
/// asleep; it is the one refusal the reader can act on, and burning fifteen seconds of wakes before
/// saying so would delay the only sentence on that screen worth reading.
public struct WakingServerAddresses: ServerAddressResolving {

    private let addresses: any ServerAddressResolving
    private let macs: any RememberedMacStore
    private let waking: any MacWaking

    /// How long to wait after each wake before asking again, one entry per further attempt.
    ///
    /// **A list rather than a count and an interval**, so the shape of the wait is stated rather
    /// than computed: the first retry is quick because a Mac that was merely slow will already be
    /// back, and the later ones are spaced because a Mac that was genuinely asleep needs the time.
    /// No default on the initialiser — a test that means "this Mac never comes back" has to say how
    /// long the reader waits before being told so, which is the same seam `MacPairing` uses.
    private let patience: [Duration]

    public init(
        addresses: any ServerAddressResolving,
        macs: any RememberedMacStore,
        waking: any MacWaking,
        patience: [Duration]
    ) {
        self.addresses = addresses
        self.macs = macs
        self.waking = waking
        self.patience = patience
    }

    /// The shipped wait: a little over fifteen seconds across three further attempts.
    ///
    /// Measured against what a Mac actually takes to come back from sleep on Wi-Fi, and bounded by
    /// what a reader will hold a phone still for. Longer would catch a Mac in deep standby and cost
    /// everyone else a screen that looks stuck.
    public static let defaultPatience: [Duration] = [.seconds(2), .seconds(5), .seconds(8)]

    public func address(of server: DiscoveredServer) async throws(ServerAddressResolutionFailure) -> ServerAddress {
        // Not an optional with a `??` at the throw: the first pass never waits, so an attempt always
        // happens and always replaces this — which would make the fallback a branch no test could
        // ever reach and the coverage gate would rightly charge for it.
        var lastFailure = ServerAddressResolutionFailure.unreachable(
            diagnostic: "this Mac did not answer, and was not woken by trying"
        )
        for wait in [Duration.zero] + patience {
            if wait > .zero {
                // Cancellation is the reader leaving the screen, and it ends the wait rather than
                // the attempt: a sleep that ignored it would hold them on a spinner they have
                // already walked away from.
                do {
                    try await Task.sleep(for: wait)
                } catch {
                    break
                }
            }
            do {
                return try await addresses.address(of: server)
            } catch {
                switch error {
                case .unreachable:
                    lastFailure = error
                case .localNetworkDenied:
                    throw error
                }
            }
            await wakeEverythingKnown()
        }
        // The last thing that actually went wrong, so the small print under the sentence names the
        // final attempt rather than the first — which is the one whose timing the reader saw.
        throw lastFailure
    }

    /// Wakes every Mac this phone has paired with, not merely the one being resolved.
    ///
    /// **Because which addresses belong to this Mac is not knowable here.** A pairing is filed under
    /// a Bonjour instance name, and the browse result being resolved carries that name — but a Mac
    /// that has been renamed, or one whose record predates this field, would match nothing and be
    /// left asleep. A handful of extra datagrams on a home network is not a cost worth optimising
    /// against that.
    private func wakeEverythingKnown() async {
        guard let addresses = try? await macs.wakeAddresses(), addresses.isEmpty == false else { return }
        await waking.wake(addresses)
    }
}
