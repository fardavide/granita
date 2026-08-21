import Foundation
import SystemConfiguration

import CoreBrandingDomain
import ServerIdentityDomain

public extension IdentitySubject {

    /// What this Mac's certificate claims: the product's name, and every way to reach the machine.
    ///
    /// Built here rather than at each composition root because the two must produce the *same*
    /// subject — the common name is what the Keychain is searched by, so a menu bar app and a
    /// terminal that disagreed about it would generate an identity each and pin different keys.
    ///
    /// **The common name is a constant and the addresses are not in it.** Every way this Mac is
    /// actually addressed goes in the subject alternative names, which is where RFC 5280 puts them
    /// and where every modern client looks. The common name is left as the product's own, so that
    /// renaming the Mac — or joining a different network — does not orphan the identity that every
    /// paired phone is pinning.
    static var thisMac: IdentitySubject {
        IdentitySubject(
            commonName: Branding.productName,
            subjectAlternativeNames: [.dnsName(localHostName)]
                + LocalAddresses.current().map { .ipAddress($0) }
        )
    }

    /// The name that resolves to this Mac on the local network.
    ///
    /// From System Configuration rather than from a reverse lookup: `ProcessInfo.hostName` asks the
    /// network what this address currently resolves to, which on Davide's connection answers with
    /// his ISP's name for it — a certificate covering that matches nothing anyone would type.
    private static var localHostName: String {
        guard let name = SCDynamicStoreCopyLocalHostName(nil) as String? else {
            return ProcessInfo.processInfo.hostName
        }
        return "\(name).local"
    }
}
