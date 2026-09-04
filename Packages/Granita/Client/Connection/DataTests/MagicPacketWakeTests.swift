import Foundation
import Testing

import ClientConnectionDomain

@testable import ClientConnectionData

/// The 102 bytes that wake a Mac.
///
/// **Nothing acknowledges a magic packet**, so a wrong one is silent: the Mac stays asleep and the
/// reader is told it could not be reached. That is the entire reason the shape is asserted here byte
/// for byte rather than trusted to a loop.
@Suite("Magic packet")
struct MagicPacketWakeTests {

    // MARK: - The packet

    @Test
    func `given an address when a packet is built then it opens with six bytes of all ones`() throws {
        // given
        let address = try #require(HardwareAddress(text: "3e:2d:c6:c3:4b:fe"))

        // when
        let packet = MagicPacketWake.packet(for: address)

        // then
        #expect(Array(packet.prefix(6)) == [0xff, 0xff, 0xff, 0xff, 0xff, 0xff])
    }

    @Test
    func `given an address when a packet is built then it repeats that address sixteen times`() throws {
        // given
        let address = try #require(HardwareAddress(text: "3e:2d:c6:c3:4b:fe"))

        // when
        let packet = MagicPacketWake.packet(for: address)

        // then — fifteen repetitions is not refused by anything, it simply never wakes the Mac.
        let body = Array(packet.dropFirst(6))
        #expect(body.count == 96)
        for repetition in 0..<16 {
            #expect(Array(body[(repetition * 6)..<(repetition * 6 + 6)]) == address.bytes)
        }
    }

    @Test
    func `given an address when a packet is built then it is a hundred and two bytes`() throws {
        // given
        let address = try #require(HardwareAddress(text: "a4:83:e7:11:22:33"))

        // when - then
        #expect(MagicPacketWake.packet(for: address).count == 102)
    }

    // MARK: - Sending it

    @Test
    func `given two addresses when they are woken then each gets its own packet`() async throws {
        // given
        let datagrams = RecordingDatagrams()
        let sut = MagicPacketWake(datagrams: datagrams, ports: MagicPacketWake.conventionalPorts)
        let addresses = HardwareAddress.all(in: ["3e:2d:c6:c3:4b:fe", "a4:83:e7:11:22:33"])

        // when
        await sut.wake(addresses)

        // then — two addresses over two ports.
        let sent = await datagrams.sent
        #expect(sent.count == 4)
        #expect(Set(sent.map(\.payload)).count == 2)
    }

    @Test
    func `given an address when it is woken then the packet goes to both conventional ports`() async throws {
        // given
        let datagrams = RecordingDatagrams()
        let sut = MagicPacketWake(datagrams: datagrams, ports: MagicPacketWake.conventionalPorts)

        // when
        await sut.wake(HardwareAddress.all(in: ["3e:2d:c6:c3:4b:fe"]))

        // then — neither port is standardised and both are in use, so both are sent.
        #expect(await datagrams.sent.map(\.port).sorted() == [7, 9])
        #expect(MagicPacketWake.conventionalPorts == [9, 7])
    }

    @Test
    func `given no address when a wake is asked for then nothing is sent`() async throws {
        // given
        let datagrams = RecordingDatagrams()
        let sut = MagicPacketWake(datagrams: datagrams, ports: MagicPacketWake.conventionalPorts)

        // when
        await sut.wake([])

        // then — an empty broadcast is not a wake, and sending one would be noise on the network.
        #expect(await datagrams.sent.isEmpty)
    }

    @Test
    func `given the app's own waker when a Mac is woken then a real packet leaves through the real socket`() async throws {
        // given — the real sender rather than a recorder, so this is the one test that proves the
        // packet reaches a socket at all. Loopback is the only substitution.
        let listener = try #require(UdpListener())
        defer { listener.close() }
        let sut = MagicPacketWake(
            datagrams: BroadcastDatagrams(destinations: { ["127.0.0.1"] }),
            // 9 and 7 are both privileged, so a test cannot bind either without running as root.
            ports: [listener.port]
        )
        let address = try #require(HardwareAddress(text: "3e:2d:c6:c3:4b:fe"))

        // when
        await sut.wake([address])

        // then — the 102 bytes a network card is watching for, off the wire rather than out of the
        // builder that made them.
        #expect(listener.receive() == MagicPacketWake.packet(for: address))
    }
}

// MARK: -

/// Where a broadcast goes, which is the part that decides whether the packet reaches the Mac at all.
///
/// Several access points drop `255.255.255.255` while forwarding the subnet-directed form, so this
/// arithmetic is the difference between a Mac that wakes and one that does not — with no symptom
/// either way, which is why it is asserted rather than trusted.
@Suite("Broadcast addresses")
struct BroadcastAddressesTests {

    @Test
    func `given a twenty-four bit subnet when its broadcast is derived then the last octet is all ones`() {
        // given — the ordinary home network.
        let address = ipv4("192.168.1.24")
        let mask = ipv4("255.255.255.0")

        // when
        let broadcast = BroadcastAddresses.broadcast(of: address, mask: mask)

        // then
        #expect(BroadcastAddresses.text(of: broadcast) == "192.168.1.255")
    }

    @Test
    func `given a sixteen bit subnet when its broadcast is derived then both host octets are all ones`() {
        // given
        let broadcast = BroadcastAddresses.broadcast(of: ipv4("172.16.4.9"), mask: ipv4("255.255.0.0"))

        // when - then
        #expect(BroadcastAddresses.text(of: broadcast) == "172.16.255.255")
    }

    @Test
    func `given a subnet that does not fall on an octet when its broadcast is derived then only the host bits are set`() {
        // given — a /26, which is where an implementation that worked on whole octets goes wrong.
        let broadcast = BroadcastAddresses.broadcast(of: ipv4("10.0.0.130"), mask: ipv4("255.255.255.192"))

        // then — the block is 10.0.0.128 to 10.0.0.191, so the broadcast is the top of that block
        // and not 10.0.0.255.
        #expect(BroadcastAddresses.text(of: broadcast) == "10.0.0.191")
    }

    @Test
    func `given a full mask when its broadcast is derived then it is the address itself`() {
        // given - when — a point-to-point link, where there is no subnet to broadcast to.
        let broadcast = BroadcastAddresses.broadcast(of: ipv4("10.1.2.3"), mask: ipv4("255.255.255.255"))

        // then
        #expect(BroadcastAddresses.text(of: broadcast) == "10.1.2.3")
    }

    @Test
    func `given this device when its broadcasts are read then each is a well formed address`() {
        // given - when — what is plugged in on a runner is not ours to assert, so the shape is.
        let addresses = BroadcastAddresses.ofThisDevice()

        // then
        for address in addresses {
            #expect(address.split(separator: ".").count == 4)
        }
        #expect(addresses.count == Set(addresses).count)
    }
}

// MARK: -

/// The socket itself, sent and received.
///
/// **A real datagram over loopback, because there is no other way to hold this to its behaviour.**
/// Everything in `BroadcastDatagrams` is a syscall, and the one thing that is easy to get wrong —
/// the port's byte order — produces a packet that goes to the wrong place and reports success. A
/// fake socket would assert that the code calls the functions it calls, which is not the question.
/// Aimed at `127.0.0.1` rather than a broadcast address, so it is deterministic on any machine.
@Suite("Broadcast datagrams")
struct BroadcastDatagramsTests {

    @Test
    func `given a datagram when it is broadcast then it arrives at the port intact`() async throws {
        // given
        let listener = try #require(UdpListener())
        defer { listener.close() }
        let sut = BroadcastDatagrams(destinations: { ["127.0.0.1"] })
        let payload: [UInt8] = [0xff, 0xff, 0xff, 0x3e, 0x2d, 0xc6, 0x00, 0x01, 0x02]

        // when
        await sut.broadcast(payload, toPort: listener.port)

        // then — the bytes and the port both, since a swapped port would send this somewhere else
        // and report nothing at all.
        #expect(listener.receive() == payload)
    }

    @Test
    func `given two destinations when a datagram is broadcast then each one receives it`() async throws {
        // given — the loop, which is what sends to the limited and the directed address both.
        let listener = try #require(UdpListener())
        defer { listener.close() }
        let sut = BroadcastDatagrams(destinations: { ["127.0.0.1", "127.0.0.1"] })

        // when
        await sut.broadcast([0x01, 0x02], toPort: listener.port)

        // then
        #expect(listener.receive() == [0x01, 0x02])
        #expect(listener.receive() == [0x01, 0x02])
    }

    @Test
    func `given a destination that is not an address when a datagram is broadcast then it is skipped`() async throws {
        // given — the guard on `inet_pton`, which a corrupted interface list could reach.
        let listener = try #require(UdpListener())
        defer { listener.close() }
        let sut = BroadcastDatagrams(destinations: { ["not-an-address", "127.0.0.1"] })

        // when
        await sut.broadcast([0x09], toPort: listener.port)

        // then — the good one still goes, rather than the bad one ending the loop.
        #expect(listener.receive() == [0x09])
    }

    @Test
    func `given the shipped sender when its destinations are read then they lead with the limited broadcast`() {
        // given - when — what `BroadcastDatagrams()` actually aims at, asked of the production
        // function rather than of a literal the test wrote itself.
        let destinations = BroadcastDatagrams.everywhereOnThisNetwork()

        // when - then — the limited broadcast first, then one subnet-directed address per network
        // this device is on. Several access points forward only one of the two.
        #expect(destinations.first == "255.255.255.255")
        #expect(destinations.dropFirst().elementsEqual(BroadcastAddresses.ofThisDevice()))
    }
}

// MARK: -

/// A UDP socket on a port the system chose, so two tests never collide on one.
private final class UdpListener {

    let port: UInt16

    private let handle: Int32

    init?() {
        let opened = socket(AF_INET, SOCK_DGRAM, 0)
        guard opened >= 0 else { return nil }

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr.s_addr = INADDR_ANY.bigEndian
        let bound = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { generic in
                bind(opened, generic, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0 else {
            Darwin.close(opened)
            return nil
        }

        var assigned = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &assigned) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { generic in
                getsockname(opened, generic, &length)
            }
        }
        guard named == 0 else {
            Darwin.close(opened)
            return nil
        }

        // A second of patience, so a lost datagram fails the test rather than hanging the suite.
        var timeout = timeval(tv_sec: 1, tv_usec: 0)
        setsockopt(opened, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        handle = opened
        port = assigned.sin_port.bigEndian
    }

    func receive() -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: 256)
        let count = recv(handle, &buffer, buffer.count, 0)
        guard count > 0 else { return [] }
        return Array(buffer.prefix(count))
    }

    func close() {
        _ = Darwin.close(handle)
    }
}

/// A dotted address as the bytes a socket holds, so a test states the address it means rather than
/// the integer it becomes.
private func ipv4(_ text: String) -> in_addr_t {
    var address = in_addr()
    _ = inet_pton(AF_INET, text, &address)
    return address.s_addr
}

// MARK: -

/// The socket, recorded rather than opened.
private actor RecordingDatagrams: DatagramBroadcasting {

    private(set) var sent: [(payload: [UInt8], port: UInt16)] = []

    func broadcast(_ payload: [UInt8], toPort port: UInt16) async {
        sent.append((payload, port))
    }
}
