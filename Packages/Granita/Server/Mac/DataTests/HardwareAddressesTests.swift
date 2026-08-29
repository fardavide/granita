import Foundation
import Testing

@testable import ServerMacData

/// The addresses a phone sends a magic packet to.
///
/// The walk over the real interface list is one call and is asserted loosely — what a test machine
/// has plugged in is not ours to say. The formatting is where a bug would be silent and reach the
/// phone as a Mac that never wakes, so that is asserted exactly.
@Suite("Hardware addresses")
struct HardwareAddressesTests {

    // MARK: - Formatting

    @Test
    func `given six bytes when they are formatted then they read as a colon-separated hardware address`() {
        // given
        let bytes: [UInt8] = [0x3e, 0x2d, 0xc6, 0xc3, 0x4b, 0xfe]

        // when
        let formatted = HardwareAddresses.formatted(bytes)

        // then
        #expect(formatted == "3e:2d:c6:c3:4b:fe")
    }

    @Test
    func `given a byte under sixteen when it is formatted then it keeps its leading zero`() {
        // given — the one that a naive `String(_:radix:)` drops, turning six bytes into eleven
        // characters and a packet no Mac answers.
        let bytes: [UInt8] = [0x00, 0x0a, 0x0f, 0x10, 0xff, 0x01]

        // when
        let formatted = HardwareAddresses.formatted(bytes)

        // then
        #expect(formatted == "00:0a:0f:10:ff:01")
    }

    @Test
    func `given fewer than six bytes when they are formatted then nothing is made of them`() {
        // given - when
        let formatted = HardwareAddresses.formatted([0x3e, 0x2d, 0xc6])

        // then — a short address is not an address. Reporting one would put the phone to work
        // sending packets that cannot wake anything.
        #expect(formatted == nil)
    }

    @Test
    func `given six zero bytes when they are formatted then nothing is made of them`() {
        // given - when — what an interface with no hardware address reports, and it is not one.
        let formatted = HardwareAddresses.formatted([0, 0, 0, 0, 0, 0])

        // then
        #expect(formatted == nil)
    }

    // MARK: - Reading this Mac

    @Test
    func `given this Mac when its interfaces are read then every address it reports is well formed`() {
        // given - when
        let addresses = HardwareAddresses.ofThisMac()

        // then — how many depends on what is plugged in, so the shape is what is asserted. Six
        // pairs of hex digits, and never the all-zero placeholder.
        for address in addresses {
            #expect(address.count == 17)
            #expect(address.split(separator: ":").count == 6)
            #expect(address != "00:00:00:00:00:00")
        }
    }

    @Test
    func `given this Mac when its interfaces are read then no address is reported twice`() {
        // given - when
        let addresses = HardwareAddresses.ofThisMac()

        // then — one wake per address, and a duplicate would be a second identical packet.
        #expect(addresses.count == Set(addresses).count)
    }

    @Test
    func `given an interface whose name is long when this Mac is read then its address is not dropped`() {
        // given — `bridge0` is the case that exposed the trap: seven characters of name plus six of
        // address is thirteen, past the twelve bytes `sdl_data` declares, so a read bounded against
        // that copy returned nothing for it. Every Mac with a Thunderbolt port has one.

        // when
        let addresses = HardwareAddresses.ofThisMac()

        // then — counted against an independent walk bounded by `sdl_len` rather than by the stub.
        // Before the fix these disagreed on this very machine.
        #expect(addresses.count == everyHardwareAddress().count)
        #expect(Set(addresses) == everyHardwareAddress())
    }
}

// MARK: -

/// Every distinct hardware address this Mac has, read through the pointer and bounded by `sdl_len` —
/// the independent answer the production walk is checked against.
private func everyHardwareAddress() -> Set<String> {
    var start: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&start) == 0, let start else { return [] }
    defer { freeifaddrs(start) }

    var found: Set<String> = []
    for interface in sequence(first: start, next: { $0.pointee.ifa_next }) {
        guard let address = interface.pointee.ifa_addr,
              address.pointee.sa_family == UInt8(AF_LINK),
              interface.pointee.ifa_flags & UInt32(IFF_LOOPBACK) == 0
        else {
            continue
        }
        address.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) { link in
            let length = Int(link.pointee.sdl_alen)
            let offset = MemoryLayout<sockaddr_dl>.offset(of: \.sdl_data).unsafelyUnwrapped
                + Int(link.pointee.sdl_nlen)
            guard length == 6, offset + length <= Int(link.pointee.sdl_len) else { return }
            let raw = UnsafeRawBufferPointer(start: link, count: Int(link.pointee.sdl_len))
            let bytes = Array(raw[offset..<(offset + length)])
            guard bytes.contains(where: { $0 != 0 }) else { return }
            found.insert(bytes.map { String(format: "%02x", $0) }.joined(separator: ":"))
        }
    }
    return found
}
