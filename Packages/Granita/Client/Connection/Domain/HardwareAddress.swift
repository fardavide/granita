/// One network interface's hardware address, as something a magic packet can be built from.
///
/// **A type rather than the string it arrives as, because the string is not trustworthy.** It comes
/// off the wire from a Mac of some other version and out of the Keychain from a pairing of some
/// other age, and a magic packet built from six bytes that are not six bytes wakes nothing while
/// looking exactly like one that works. Parsing once, here, is what makes every layer above this
/// hold something that is an address rather than something that was called one.
public struct HardwareAddress: Hashable, Sendable {

    /// The six bytes, which is what the packet repeats and the only reason this exists.
    public let bytes: [UInt8]

    /// The canonical text — lowercase, colon-separated — which is what goes back into the Keychain.
    ///
    /// Rebuilt from the bytes rather than kept from the input, so a Mac that reported `3E-2D-C6` in
    /// some other spelling is stored the one way and compares equal to itself next time.
    public var text: String {
        bytes.map { byte in
            let hex = String(byte, radix: 16)
            return byte < 0x10 ? "0\(hex)" : hex
        }
        .joined(separator: ":")
    }

    /// Six colon-separated bytes, or nothing.
    ///
    /// **Nothing is a real answer and not a defensive one.** An interface with no hardware of its
    /// own reports six zero bytes, which is a valid parse and an address no packet can reach — so it
    /// is refused here rather than turned into a datagram sent to nobody. Anything that is not six
    /// bytes is refused for the plainer reason that it is not an address.
    public init?(text: String) {
        let parts = text.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 6 else { return nil }
        var parsed: [UInt8] = []
        for part in parts {
            // Two digits exactly. A single-digit group would parse and shift every byte after it,
            // which is the failure that looks most like success.
            guard part.count == 2, let byte = UInt8(part, radix: 16) else { return nil }
            parsed.append(byte)
        }
        guard parsed.contains(where: { $0 != 0 }) else { return nil }
        bytes = parsed
    }
}

public extension HardwareAddress {

    /// How many of these a Mac is believed at most.
    ///
    /// **A cap, because the list arrives unauthenticated and is replayed as broadcast traffic.**
    /// `/v1/health` answers before pairing, and on the spoken path trust is first-use — so whatever
    /// answers at a Bonjour name gets to seed this. A Mac has a handful of interfaces; a list of
    /// fifty thousand is not a Mac, it is a phone turned into a broadcast flood every time the
    /// discovery screen appears, on a link where broadcast frames go out at the lowest basic rate.
    /// Eight is past anything real and far short of anything harmful.
    static var mostPerMac: Int { 8 }

    /// Every one of those that is an address, dropping the ones that are not, and never more than
    /// `mostPerMac` of them.
    ///
    /// **Dropping rather than failing**, because the alternative is a pairing that stops working
    /// over one bad entry in a list of several — and the reader would be sent back through the
    /// pairing screens for a Mac they are already paired with.
    static func all(in texts: [String]) -> [HardwareAddress] {
        texts.lazy.compactMap(HardwareAddress.init(text:)).prefix(mostPerMac).map { $0 }
    }
}
