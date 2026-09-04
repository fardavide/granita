import Foundation
import Network

import ClientConnectionDomain

/// Puts a datagram on the local network, addressed to everyone.
///
/// **A seam of one method, because the packet is the part worth testing and the socket is not.** A
/// magic packet is 102 bytes with a shape that is easy to get subtly wrong and impossible to observe
/// once it has left — nothing acknowledges it — so what is held to its behaviour is the bytes, and
/// what is behind this protocol is a socket doing the one thing it does.
///
/// **Public because the composition root does the wiring**, which is the layering's own rule rather
/// than a concession: a convenience initialiser here that assembled the real sender would be wiring
/// living in `Data`, reachable from no test, and charged for by the coverage gate forever.
public protocol DatagramBroadcasting: Sendable {

    func broadcast(_ payload: [UInt8], toPort port: UInt16) async
}

// MARK: -

/// Wakes a Mac by broadcasting the packet its network card is listening for while it sleeps.
///
/// **This is the phone standing in for a sleep proxy.** macOS 15 compiled the Bonjour Sleep Proxy
/// client out of mDNSResponder, so a sleeping Mac no longer leaves its advertisement with an Apple
/// TV that would wake it on demand. The magic packet is the mechanism that proxy itself used and it
/// still works — the card watches for it in every low-power state that has a network at all.
///
/// **Broadcast rather than sent to the Mac's address, and that is the point.** A sleeping Mac does
/// not answer ARP, so there is no address to send to; a broadcast reaches the card without anything
/// having to know where the machine is. It also means this cannot be aimed, which is why the packet
/// carries the hardware address inside it — every card on the network sees it and only the named one
/// acts.
public struct MagicPacketWake: MacWaking {

    private let datagrams: any DatagramBroadcasting

    /// The two ports wake-on-lan is conventionally sent to.
    ///
    /// **Neither is standardised and both are used**, which is why both are sent rather than one
    /// being chosen. The packet is read by the network card below any port at all, so a port that
    /// nothing is listening on is not a failure — it is the ordinary case, and the datagram is
    /// twelve bytes of overhead either way.
    public static let conventionalPorts: [UInt16] = [9, 7]

    /// Which ports this one sends to. Injectable only so a test can point the whole path at a port
    /// it is allowed to bind — 9 and 7 are both privileged, so an end-to-end test cannot listen on
    /// either without running as root.
    private let ports: [UInt16]

    /// **One initialiser, and the composition root supplies both halves.** A no-argument convenience
    /// that assembled the real sender would read better and would be wiring in the wrong layer —
    /// unreachable from any test, and so permanently uncovered.
    public init(datagrams: any DatagramBroadcasting, ports: [UInt16]) {
        self.datagrams = datagrams
        self.ports = ports
    }

    public func wake(_ addresses: [HardwareAddress]) async {
        for address in addresses {
            let packet = Self.packet(for: address)
            for port in ports {
                await datagrams.broadcast(packet, toPort: port)
            }
        }
    }

    /// Six bytes of `0xff`, then the hardware address sixteen times over — 102 bytes in all.
    ///
    /// The shape is the whole specification and it has no version, no checksum and no reply. A
    /// packet with fifteen repetitions is not rejected by anything; it simply never wakes the Mac,
    /// which is why the count is asserted in a test rather than trusted to a loop bound.
    static func packet(for address: HardwareAddress) -> [UInt8] {
        [UInt8](repeating: 0xff, count: 6) + Array(repeating: address.bytes, count: 16).flatMap { $0 }
    }
}

// MARK: -

/// The socket, which is the part with nothing to decide.
///
/// **A POSIX socket rather than `NWConnection`, and the reason is that broadcast is exactly what one
/// is for.** `NWConnection` to `255.255.255.255` has to be told which interface to leave by — on a
/// phone the default path can be cellular, where the datagram goes nowhere — and reports nothing
/// when it does not. `SO_BROADCAST` and `sendto` are the mechanism every wake-on-lan implementation
/// has used for thirty years, and the failure modes are visible rather than inferred.
///
/// **Failures are swallowed on purpose, and the protocol above says why**: nothing acknowledges a
/// magic packet, so there is no outcome to report and nothing a caller could do differently. A
/// network that will not take the datagram is indistinguishable from a Mac that is powered off, and
/// both end the same way — the Mac does not appear in the browse, which is a state the discovery
/// screen already draws.
public struct BroadcastDatagrams: DatagramBroadcasting {

    /// Where each datagram goes.
    ///
    /// **A closure so the socket can be exercised against loopback in a test.** Everything below is
    /// syscalls with no branches worth arguing about and one that is easy to get wrong — the port's
    /// byte order — and the only way to hold any of it to its behaviour is to actually send a
    /// datagram and receive it. Aimed at a broadcast address that cannot happen; aimed at
    /// `127.0.0.1` it is deterministic on any machine.
    private let destinations: @Sendable () -> [String]

    public init(destinations: @escaping @Sendable () -> [String]) {
        self.destinations = destinations
    }

    /// Where the app aims: the limited broadcast, and every subnet-directed one.
    ///
    /// **Both, because access points disagree about which they forward** — some drop
    /// `255.255.255.255` and pass the directed form, some the reverse. Sending both costs a hundred
    /// bytes and removes the disagreement from the list of reasons a Mac did not wake.
    ///
    /// A function the composition root passes in rather than a default inside the initialiser, so
    /// that what the app actually aims at is something a test can call and assert on.
    public static func everywhereOnThisNetwork() -> [String] {
        ["255.255.255.255"] + BroadcastAddresses.ofThisDevice()
    }

    public func broadcast(_ payload: [UInt8], toPort port: UInt16) async {
        // Unguarded, because every failure below is already swallowed and this one is no different:
        // a socket that could not be opened is `-1`, on which `setsockopt` and `sendto` fail
        // harmlessly and `close` is a no-op. A guard would be a branch no test could reach, for a
        // behaviour identical to falling through.
        let socketHandle = socket(AF_INET, SOCK_DGRAM, 0)
        defer { close(socketHandle) }

        // Unchecked, deliberately. `SO_BROADCAST` on a datagram socket this process just opened has
        // no failure a caller could act on — and if it somehow did fail, the `sendto` below refuses
        // with `EACCES`, which lands in the same place: swallowed, because nothing acknowledges a
        // magic packet and there is no outcome to report. A guard here would be a branch no test
        // could ever reach.
        var enabled: Int32 = 1
        setsockopt(socketHandle, SOL_SOCKET, SO_BROADCAST, &enabled, socklen_t(MemoryLayout<Int32>.size))

        for destination in destinations() {
            var address = sockaddr_in()
            address.sin_family = sa_family_t(AF_INET)
            address.sin_port = port.bigEndian
            guard inet_pton(AF_INET, destination, &address.sin_addr) == 1 else { continue }
            withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { generic in
                    _ = sendto(
                        socketHandle,
                        payload,
                        payload.count,
                        0,
                        generic,
                        socklen_t(MemoryLayout<sockaddr_in>.size)
                    )
                }
            }
        }
    }
}

// MARK: -

/// The subnet-directed broadcast address of each network this device is on.
///
/// **`255.255.255.255` alone is not enough in practice.** It is never forwarded past the first hop
/// by design, and several consumer access points drop it outright while passing the directed form —
/// which is the difference between a Mac that wakes and one that does not, with no symptom either
/// way. Deriving the directed address needs this device's own address and mask, which is what the
/// walk below is for.
enum BroadcastAddresses {

    static func ofThisDevice() -> [String] {
        var start: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&start) == 0, let start else { return [] }
        defer { freeifaddrs(start) }

        var found: [String] = []
        for interface in sequence(first: start, next: { $0.pointee.ifa_next }) {
            guard let address = interface.pointee.ifa_addr,
                  let mask = interface.pointee.ifa_netmask,
                  address.pointee.sa_family == UInt8(AF_INET),
                  interface.pointee.ifa_flags & UInt32(IFF_LOOPBACK) == 0,
                  interface.pointee.ifa_flags & UInt32(IFF_UP) != 0
            else {
                continue
            }
            let directed = broadcast(
                of: address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr.s_addr },
                mask: mask.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr.s_addr }
            )
            let text = text(of: directed)
            if found.contains(text) == false {
                found.append(text)
            }
        }
        return found
    }

    /// The address with every host bit set, which is what "everyone on this subnet" means.
    ///
    /// Both arguments are in network byte order and so is the answer, which is why the arithmetic
    /// needs no swapping: inverting the mask and setting those bits is the same operation whichever
    /// end the bytes start from.
    static func broadcast(of address: in_addr_t, mask: in_addr_t) -> in_addr_t {
        address | ~mask
    }

    /// The dotted form.
    ///
    /// Total rather than failing: four bytes always have one, so `inet_ntop` here would contribute a
    /// failure branch that nothing can reach and no test could ever pay for. The bytes are already
    /// in network order, which is the order they are written in.
    static func text(of address: in_addr_t) -> String {
        withUnsafeBytes(of: address) { bytes in
            bytes.map { String($0) }.joined(separator: ".")
        }
    }
}
