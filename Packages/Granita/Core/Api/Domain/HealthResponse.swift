import CoreBrandingDomain

/// The body of `/v1/health`, and the first thing a phone ever reads from a Mac.
///
/// It answers before pairing, so it is what tells "wrong address" apart from "wrong version" apart
/// from "not authorised". The Mac app and the TestFlight phone app ship independently, so version
/// skew is guaranteed rather than unlikely: the client refuses to pair on an `apiVersion` mismatch
/// instead of decoding a payload it half-understands.
///
/// A `Core` type because both halves name it, and a field spelled differently on the two sides is a
/// phone that cannot read a Mac rather than a rename.
public struct HealthResponse: Codable, Hashable, Sendable {

    public let name: String
    public let apiVersion: Int
    public let serverVersion: String

    /// The hardware addresses a magic packet may be sent to, to wake this Mac.
    ///
    /// **The phone is this Mac's sleep proxy now, which is why an address is on the wire at all.**
    /// macOS 15 compiled the Bonjour Sleep Proxy *client* out of mDNSResponder, so a sleeping Mac
    /// withdraws its advertisement instead of handing it to the Apple TV that used to hold it — and
    /// with nothing on the network answering for it, nothing wakes it either. What still works is
    /// the packet the proxy itself would have sent, and the phone can send that.
    ///
    /// **Optional, and the two empty answers mean different things.** Absent is a Mac from before
    /// this field existed, which the phone cannot wake and must not claim it can; empty is a Mac
    /// that looked and found nothing wakeable. Every address rather than a chosen one, because
    /// which interface the phone shares a network with is not knowable from here.
    ///
    /// Served unauthenticated with the rest of health, which is a deliberate call: a hardware
    /// address is already broadcast in the clear by ARP and mDNS to everyone on the LAN, so this
    /// publishes nothing that was not already there for the asking.
    public let wakeAddresses: [String]?

    public init(name: String, apiVersion: Int, serverVersion: String, wakeAddresses: [String]?) {
        self.name = name
        self.apiVersion = apiVersion
        self.serverVersion = serverVersion
        self.wakeAddresses = wakeAddresses
    }

    /// The values a running server reports — the two that are not constants.
    public init(serverVersion: String, wakeAddresses: [String]) {
        self.init(
            name: Branding.productName,
            apiVersion: Branding.apiVersion,
            serverVersion: serverVersion,
            wakeAddresses: wakeAddresses
        )
    }
}
