import Foundation

import ServerIdentityDomain

/// Every address this Mac currently answers on, for the certificate's subject alternative names.
///
/// Read once, when the identity is generated, and never again — see `ServerIdentityStore` for why
/// a certificate that chased the current addresses would unpair every device that ever connected.
public enum LocalAddresses {

    public static func current() -> [IpAddress] {
        var first: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&first) == 0, let first else { return [] }
        defer { freeifaddrs(first) }

        var found: [IpAddress] = []
        for interface in sequence(first: first, next: \.pointee.ifa_next) {
            guard let address = interface.pointee.ifa_addr,
                  interface.pointee.ifa_flags & UInt32(IFF_UP) != 0,
                  let read = certifiableAddress(of: address)
            else {
                continue
            }
            // One address can be reported on several interfaces, and a certificate that names the
            // same address twice is not wrong so much as odd to read in Keychain Access.
            if found.contains(read) == false {
                found.append(read)
            }
        }
        return found
    }

    /// One socket address as the bytes a certificate can carry, or nothing when it can carry none.
    ///
    /// **Public because the enumeration above cannot be made to answer a question.** It reports
    /// whatever this machine has up at that instant, so the IPv6 branches ran or did not depending on
    /// whether a runner had an interface — and the link-local rejection, which is the one case with
    /// a consequence a reader would ever meet, was covered by luck. Separating the pure half lets all
    /// four answers be decided by a test, and leaves the enumeration with a smoke test against the
    /// real machine, which is the only thing it can honestly be.
    public static func certifiableAddress(of address: UnsafePointer<sockaddr>) -> IpAddress? {
        switch Int32(address.pointee.sa_family) {
        case AF_INET:
            let read = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                $0.pointee.sin_addr.s_addr
            }
            return IpAddress(bytes: withUnsafeBytes(of: read) { Array($0) })

        case AF_INET6:
            let read = address.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
                withUnsafeBytes(of: $0.pointee.sin6_addr) { Array($0) }
            }
            // Link-local addresses carry a zone that a certificate has nowhere to put, so a
            // certificate naming one matches nothing and only makes the list longer.
            guard read.count == 16, read[0] != 0xfe || read[1] & 0xc0 != 0x80 else { return nil }
            return IpAddress(bytes: read)

        default:
            return nil
        }
    }
}
