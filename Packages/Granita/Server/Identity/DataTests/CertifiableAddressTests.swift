import Foundation
import Testing

import ServerIdentityData
import ServerIdentityDomain

/// The conversion from one socket address to the bytes a certificate can carry, over addresses this
/// test supplies rather than over whatever the machine happens to have up.
///
/// **The suite beside this one can only assert what this machine is.** Its IPv6 cases run when an
/// IPv6 address is up at that instant and silently do not when it is not, so the branch that reads
/// `sin6_addr` was covered by luck and the link-local rejection — the one case with a real
/// consequence, a certificate naming an address that matches nothing — was covered by whether a
/// runner happened to have a Wi-Fi interface. All four answers are decided here instead.
struct CertifiableAddressTests {

    @Test func `given an IPv4 address when converting then it is the four bytes in wire order`() {
        // given
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        #expect(inet_pton(AF_INET, "192.168.1.42", &address.sin_addr) == 1)

        // when
        let read = certifiableAddress(of: &address)

        // then
        #expect(read == IpAddress(bytes: [192, 168, 1, 42]))
    }

    @Test func `given a routable IPv6 address when converting then it is the sixteen bytes`() {
        // given
        var address = sockaddr_in6()
        address.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
        address.sin6_family = sa_family_t(AF_INET6)
        #expect(inet_pton(AF_INET6, "2001:db8::1", &address.sin6_addr) == 1)

        // when
        let read = certifiableAddress(of: &address)

        // then
        #expect(read == IpAddress(bytes: [0x20, 0x01, 0x0d, 0xb8] + Array(repeating: 0, count: 11) + [0x01]))
    }

    @Test(arguments: ["fe80::1", "fe80::1c2d:3e4f:5a6b:7c8d", "febf::1"])
    func `given a link-local IPv6 address when converting then a certificate is offered nothing`(
        spelling: String
    ) {
        // given — fe80::/10, so the second byte's top two bits are what decides it rather than the
        // whole byte. `febf` is the last address in the range and `fec0` below is the first outside.
        var address = sockaddr_in6()
        address.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
        address.sin6_family = sa_family_t(AF_INET6)
        #expect(inet_pton(AF_INET6, spelling, &address.sin6_addr) == 1)

        // when
        let read = certifiableAddress(of: &address)

        // then — a link-local address carries a zone index a certificate has nowhere to put, so one
        // named in a subject alternative name matches nothing and only lengthens the list.
        #expect(read == nil)
    }

    @Test func `given an address just outside the link-local range when converting then it is kept`() {
        // given — the boundary the mask exists for. `fec0::` differs from `febf::` in the bits the
        // guard reads, and a guard written against the whole second byte would reject both.
        var address = sockaddr_in6()
        address.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
        address.sin6_family = sa_family_t(AF_INET6)
        #expect(inet_pton(AF_INET6, "fec0::1", &address.sin6_addr) == 1)

        // when
        let read = certifiableAddress(of: &address)

        // then
        #expect(read?.bytes.first == 0xfe)
        #expect(read?.bytes.count == 16)
    }

    @Test func `given a family that is not IP when converting then a certificate is offered nothing`() {
        // given — a link-layer address, which every Mac reports on every interface alongside its IP
        // ones. This is the branch that runs most often in production and was asserted by nothing.
        var address = sockaddr()
        address.sa_len = UInt8(MemoryLayout<sockaddr>.size)
        address.sa_family = sa_family_t(AF_LINK)

        // when
        let read = withUnsafePointer(to: &address) { LocalAddresses.certifiableAddress(of: $0) }

        // then
        #expect(read == nil)
    }

    /// Rebinds a concrete socket address to the generic one the enumeration hands over, which is the
    /// same reinterpretation `getifaddrs` results go through.
    private func certifiableAddress<Address>(of address: inout Address) -> IpAddress? {
        withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                LocalAddresses.certifiableAddress(of: $0)
            }
        }
    }
}
