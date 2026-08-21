import Foundation
import Testing

import ServerIdentityData
import ServerIdentityDomain

/// What goes into the certificate's subject alternative names.
///
/// Asserted against the machine the test runs on rather than against a fixture, because the only
/// interesting property is that whatever the system reports survives the trip into bytes a
/// certificate can carry — and a fixture would assert that our own array literal is four bytes long.
struct LocalAddressesTests {

    @Test func `when reading this machine's addresses then it finds at least one`() {
        // given - when
        let addresses = LocalAddresses.current()

        // then
        // Loopback is always up, so an empty answer means the enumeration itself is broken rather
        // than that this machine is off the network — which is the failure worth catching on a
        // runner with no Wi-Fi.
        #expect(addresses.isEmpty == false)
    }

    @Test func `when reading this machine's addresses then every one is a length a certificate accepts`() {
        // given - when
        let addresses = LocalAddresses.current()

        // then
        #expect(addresses.allSatisfy { $0.bytes.count == 4 || $0.bytes.count == 16 })
    }

    @Test func `when reading this machine's addresses then none of them repeats`() {
        // given - when
        let addresses = LocalAddresses.current()

        // then
        #expect(Set(addresses).count == addresses.count)
    }

    @Test func `when reading this machine's addresses then no link-local address is among them`() {
        // given - when
        let addresses = LocalAddresses.current()

        // then
        // An IPv6 link-local address carries a zone index that a certificate has nowhere to put,
        // so one named here matches nothing and only lengthens the list.
        #expect(addresses.contains { $0.bytes.count == 16 && $0.bytes[0] == 0xfe && $0.bytes[1] & 0xc0 == 0x80 } == false)
    }

    @Test func `when reading this machine's addresses then loopback is among them`() {
        // given - when
        let addresses = LocalAddresses.current()

        // then
        // Kept rather than filtered, so that `curl` against the Mac itself reaches a name the
        // certificate covers — which is how the TLS path is exercised without a second device.
        #expect(addresses.contains(IpAddress(bytes: [127, 0, 0, 1])))
    }
}
