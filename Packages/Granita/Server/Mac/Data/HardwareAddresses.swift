import Foundation

/// The hardware addresses of this Mac's network interfaces, which is what a magic packet is aimed at.
///
/// **This exists because macOS 15 stopped waking itself.** The Bonjour Sleep Proxy *client* was
/// compiled out of mDNSResponder in Sequoia, so a sleeping Mac now withdraws its advertisement
/// rather than handing it to a proxy on the network — and with nothing answering for it, a phone
/// that tries to reach it finds nothing and can wake nothing. The mechanism that still works is the
/// packet the proxy would itself have sent, so health reports these and the phone sends it.
///
/// An enumeration of statics rather than a protocol with a fake: `getifaddrs` is the whole
/// implementation and there is nothing above it to invert. What is worth holding to its behaviour
/// is the formatting, which is why that is a function of its own rather than a loop body.
public enum HardwareAddresses {

    /// Every distinct hardware address this Mac has, in the order the system lists them.
    ///
    /// **All of them, deliberately.** Which interface the phone shares a network with is not
    /// knowable from here — Wi-Fi today, a dock's Ethernet tomorrow — and a wrong guess is a Mac
    /// that never wakes with no way to tell why. Sending a handful of small datagrams costs nothing
    /// and needs no guess.
    ///
    /// Loopback is skipped because it is not a thing anything can be woken through, and it would
    /// otherwise contribute the all-zero address that `formatted` already refuses.
    public static func ofThisMac() -> [String] {
        var start: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&start) == 0, let start else { return [] }
        defer { freeifaddrs(start) }

        var found: [String] = []
        for interface in sequence(first: start, next: { $0.pointee.ifa_next }) {
            guard let address = interface.pointee.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_LINK),
                  interface.pointee.ifa_flags & UInt32(IFF_LOOPBACK) == 0
            else {
                continue
            }
            guard let formatted = formatted(hardwareBytes(of: address)) else { continue }
            // An interface appears once per address family it carries, so the same hardware address
            // arrives several times over. The phone wants one packet per interface, not per family.
            if found.contains(formatted) == false {
                found.append(formatted)
            }
        }
        return found
    }

    /// The colon-separated form, or nothing when what was read is not a hardware address.
    ///
    /// **Two refusals, and both of them reach the phone as a Mac that cannot be woken rather than as
    /// a packet that wakes nothing.** Anything but six bytes is not one; six zero bytes is what an
    /// interface with no hardware of its own reports, and a magic packet aimed at it is addressed to
    /// nobody.
    ///
    /// `%02x` rather than `String(_:radix:)`, which drops the leading zero on a byte under sixteen
    /// and yields an address one character short that looks almost right.
    static func formatted(_ bytes: [UInt8]) -> String? {
        guard bytes.count == 6, bytes.contains(where: { $0 != 0 }) else { return nil }
        return bytes.map { String(format: "%02x", $0) }.joined(separator: ":")
    }

    /// The bytes a link-layer address carries, which `sockaddr_dl` stores after the interface name
    /// rather than at a fixed offset.
    ///
    /// **TRAP: `sockaddr_dl` is variable length and `sdl_data` is a stub, so it must be read through
    /// the pointer and never through a copy.** `net/if_dl.h` declares `char sdl_data[12]` and calls
    /// it a "minimum work area"; the record `getifaddrs` actually hands back is `sdl_len` bytes and
    /// the address begins at `sdl_nlen`, which is past byte twelve for any interface whose name runs
    /// to seven characters. Reading `withUnsafeBytes(of: link.pointee.sdl_data)` copies the twelve
    /// declared bytes and nothing else, so a bound against that copy silently drops `bridge0` —
    /// present on every Mac with a Thunderbolt port, name seven long, address six — along with
    /// `vmenet0` and `bridge100`. The bound belongs against `sdl_len`, which is the length of the
    /// thing that was really returned.
    private static func hardwareBytes(of address: UnsafeMutablePointer<sockaddr>) -> [UInt8] {
        address.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) { link in
            let length = Int(link.pointee.sdl_alen)
            let start = MemoryLayout<sockaddr_dl>.offset(of: \.sdl_data).unsafelyUnwrapped
                + Int(link.pointee.sdl_nlen)
            guard length > 0, start + length <= Int(link.pointee.sdl_len) else { return [] }
            let raw = UnsafeRawBufferPointer(start: link, count: Int(link.pointee.sdl_len))
            return Array(raw[start..<(start + length)])
        }
    }
}
