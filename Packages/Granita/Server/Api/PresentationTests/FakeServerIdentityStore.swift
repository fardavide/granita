import CryptoKit
import Foundation

import ServerIdentityDomain

/// A real certificate, generated in memory and never stored anywhere.
///
/// Handwritten because the only thing the Keychain conformer adds is the Keychain, and that is the
/// part no host test can reach: a SwiftPM test binary is unsigned and has no keychain of its own,
/// so exercising the real one would mean writing into Davide's login keychain. What comes out of
/// this is a genuine certificate with a genuine fingerprint, which is all anything downstream reads.
final class FakeServerIdentityStore: ServerIdentityStore {

    /// What to answer with instead, when a test is about the failure rather than the certificate —
    /// a locked Keychain, or an identity somebody deleted by hand.
    let failure: ServerIdentityError?

    private let generated: ServerIdentity

    init(
        commonName: String = "Fake Mac",
        subjectAlternativeNames: [SubjectAlternativeName] = [.dnsName("fake-mac.local")],
        failure: ServerIdentityError? = nil
    ) throws {
        self.failure = failure
        let notBefore = Date(timeIntervalSince1970: 1_771_632_000)
        generated = try SelfSignedCertificate.identity(
            signedBy: P256.Signing.PrivateKey(),
            commonName: commonName,
            subjectAlternativeNames: subjectAlternativeNames,
            serialNumber: [0x2a, 0x2a, 0x2a, 0x2a],
            notBefore: notBefore,
            notAfter: notBefore.addingTimeInterval(ServerIdentity.tenYears)
        )
    }

    /// What this fake would answer with, for a test that wants to compare against it.
    var certificate: ServerIdentity {
        generated
    }

    func identity() async throws(ServerIdentityError) -> ServerIdentity {
        if let failure {
            throw failure
        }
        return generated
    }
}
