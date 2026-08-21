import CryptoKit
import Foundation
import Security

import CorePairingDomain
import ServerIdentityDomain

/// A Keychain identity on its way out of the actor that holds it.
///
/// `SecIdentity` is a Core Foundation object: immutable once created and safe to hand to any
/// thread, which is not something the compiler can see. The promise is made here, once, instead of
/// at every place one crosses an isolation boundary.
public struct KeychainIdentity: @unchecked Sendable {

    public let reference: SecIdentity

    public init(reference: SecIdentity) {
        self.reference = reference
    }
}

/// The identity in the login Keychain: found if it is there, generated once if it is not.
///
/// An actor because "look, and create if absent" is exactly the sequence two callers must not
/// interleave — the menu bar app asks for the description while the bind asks for the handle, and
/// two certificates generated a millisecond apart would leave the second one serving a key the
/// pairing link does not name.
///
/// Nothing in a test constructs this. A SwiftPM test binary is unsigned and has no keychain of its
/// own, so exercising it would mean writing into Davide's real login keychain — which is precisely
/// why `ServerIdentityStore` exists and why everything downstream is tested against a fake.
///
/// **TRAP: every query here says `kSecUseDataProtectionKeychain: false`, and it is load-bearing.**
/// Without it the modern keychain answers, and it refuses a process with no keychain access group
/// — `errSecMissingEntitlement`, -34018 — which is every ad-hoc-signed binary, `swift run
/// granita-server` included. SPEC §8 asks for the login keychain anyway; this is what asking for it
/// looks like.
public actor KeychainServerIdentityStore: ServerIdentityStore {

    private let subject: IdentitySubject
    private let now: @Sendable () -> Date
    private var loaded: (described: ServerIdentity, keychain: SecIdentity)?

    public init(subject: IdentitySubject, now: @escaping @Sendable () -> Date) {
        self.subject = subject
        self.now = now
    }

    public func identity() async throws(ServerIdentityError) -> ServerIdentity {
        try loadOrCreate().described
    }

    /// The Security-framework handle for the same certificate — what a TLS bind is given.
    ///
    /// A second accessor rather than a second lookup: both return whatever this actor loaded or
    /// created first, so the key the phone pinned and the key the server serves cannot be two
    /// different keys.
    public func keychainIdentity() async throws(ServerIdentityError) -> KeychainIdentity {
        KeychainIdentity(reference: try loadOrCreate().keychain)
    }

    // MARK: - Finding it, or making it

    private func loadOrCreate() throws(ServerIdentityError) -> (described: ServerIdentity, keychain: SecIdentity) {
        if let loaded {
            return loaded
        }
        let identity: SecIdentity
        if let stored = try storedIdentity() {
            identity = stored
        } else {
            try generate()
            guard let created = try storedIdentity() else {
                throw .identityUnusable(reason: "the identity this Mac just generated could not be found again")
            }
            identity = created
        }
        let found = (try described(identity), identity)
        loaded = found
        return found
    }

    /// Finds our certificate by the name it goes under, then asks the Keychain for the key beside
    /// it.
    ///
    /// **Two traps, both of which cost a fingerprint that changed on every restart** — and a
    /// fingerprint that changes is every paired phone silently locked out, since the key is what
    /// they pin.
    ///
    /// The first is that the file-based keychain **derives a certificate's label from its subject
    /// common name** and discards whatever `SecItemAdd` was given, so searching back for a label of
    /// our choosing finds nothing and every run generates a new identity. That is why the common
    /// name is the handle here, and why it is a constant rather than this Mac's name: renaming a
    /// Mac must not orphan its identity.
    ///
    /// The second is that a `kSecClassIdentity` search **does not filter on the key attributes it
    /// documents** — asked for one carrying our application tag, this machine's keychain returned
    /// an Apple Development identity instead, whose RSA key then failed to read as P-256 three
    /// calls later. So the search is over certificates, where the filter works, and the pairing
    /// with a private key is a second step.
    private func storedIdentity() throws(ServerIdentityError) -> SecIdentity? {
        var item: CFTypeRef?
        let status = SecItemCopyMatching(
            [
                kSecClass as String: kSecClassCertificate,
                kSecAttrLabel as String: subject.commonName,
                kSecUseDataProtectionKeychain as String: false,
                // Bytes rather than a reference: a reference comes back as an untyped `CFTypeRef`
                // that only an unchecked cast turns into a certificate, and data bridges to `Data`
                // on its own. Re-parsing costs microseconds, once per run.
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitAll
            ] as CFDictionary,
            &item
        )
        switch status {
        case errSecSuccess:
            guard let candidates = item as? [Data] else { return nil }
            // Several certificates can share a name — an expired one this Mac replaced by hand,
            // or something unrelated. Ours is the one with a private key beside it.
            for der in candidates {
                guard let certificate = SecCertificateCreateWithData(nil, der as CFData) else { continue }
                var found: SecIdentity?
                guard SecIdentityCreateWithCertificate(nil, certificate, &found) == errSecSuccess,
                      let found
                else {
                    continue
                }
                return found
            }
            return nil
        case errSecItemNotFound:
            return nil
        default:
            throw .keychainRefused(operation: "looking for the existing certificate", status: status)
        }
    }

    private func generate() throws(ServerIdentityError) {
        let key = try generatedKey()
        let notBefore = now()
        let built = try SelfSignedCertificate.identity(
            subjectPublicKeyInfoDer: try subjectPublicKeyInfo(of: key),
            commonName: subject.commonName,
            subjectAlternativeNames: subject.subjectAlternativeNames,
            // Twenty random bytes, well inside RFC 5280's twenty-octet ceiling and well past the
            // sixty-four bits CA/Browser Forum entropy rules ask for.
            serialNumber: (0..<20).map { _ in UInt8.random(in: 0...255) },
            notBefore: notBefore,
            notAfter: notBefore.addingTimeInterval(ServerIdentity.tenYears),
            // The one thing the key is ever asked to do. `…MessageX962SHA256` hashes with SHA-256
            // and answers in the DER shape a certificate wants, which is what makes signing a call
            // rather than a place key material has to be.
            sign: { body in
                SecKeyCreateSignature(key, .ecdsaSignatureMessageX962SHA256, Data(body) as CFData, nil)
                    .map { Array($0 as Data) }
            }
        )

        guard let certificate = SecCertificateCreateWithData(nil, Data(built.certificateDer) as CFData) else {
            // The system refusing to parse what was just built is the one failure the encoder can
            // have, and it has no other symptom.
            throw .identityUnusable(reason: "the certificate this Mac built could not be parsed back")
        }
        try store(certificate: certificate)
    }

    /// Generates the key **inside** the Keychain rather than importing one.
    ///
    /// **TRAP.** The obvious shape — generate with CryptoKit, then `SecItemAdd` the imported
    /// `SecKey` — is refused by the file-based keychain with `errSecInvalidItemRef` (-25304): a key
    /// made by `SecKeyCreateWithData` is a free-standing object rather than an item any keychain
    /// has seen, and `kSecValueRef` wants one it has. Generating it here is both the thing that
    /// works and the better answer, because the private half then never exists outside the Keychain
    /// at all — this process only ever asks it to sign.
    private func generatedKey() throws(ServerIdentityError) -> SecKey {
        var failure: Unmanaged<CFError>?
        let key = SecKeyCreateRandomKey(
            [
                kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                kSecAttrKeySizeInBits as String: 256,
                kSecUseDataProtectionKeychain as String: false,
                kSecPrivateKeyAttrs as String: [
                    kSecAttrIsPermanent as String: true,
                    kSecAttrLabel as String: subject.commonName
                ]
            ] as CFDictionary,
            &failure
        )
        guard let key else {
            throw .keychainRefused(
                operation: "generating the private key (\(String(describing: failure?.takeRetainedValue())))",
                status: errSecInternalError
            )
        }
        return key
    }

    /// The public half, in the encoding the certificate and the fingerprint both want.
    ///
    /// Security reports an elliptic-curve public key as its bare point; a `SubjectPublicKeyInfo` is
    /// that point wrapped in the algorithm that gives it meaning. CryptoKit does the wrapping, so
    /// there is one encoder for it rather than two that can disagree.
    private func subjectPublicKeyInfo(of key: SecKey) throws(ServerIdentityError) -> [UInt8] {
        guard let publicKey = SecKeyCopyPublicKey(key),
              let point = SecKeyCopyExternalRepresentation(publicKey, nil) as Data?,
              let restated = try? P256.Signing.PublicKey(x963Representation: point)
        else {
            throw .identityUnusable(reason: "the generated key's public half could not be read")
        }
        return Array(restated.derRepresentation)
    }

    private func store(certificate: SecCertificate) throws(ServerIdentityError) {
        let status = SecItemAdd(
            [
                kSecClass as String: kSecClassCertificate,
                kSecValueRef as String: certificate,
                kSecUseDataProtectionKeychain as String: false
            ] as CFDictionary,
            nil
        )
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            throw .keychainRefused(operation: "storing the certificate", status: status)
        }
    }

    // MARK: - Reading one back

    /// Describes the identity from the certificate inside it, rather than from whatever this
    /// process was configured with — the one in the Keychain may have been generated by a much
    /// older run of a much older version.
    private func described(_ identity: SecIdentity) throws(ServerIdentityError) -> ServerIdentity {
        var stored: SecCertificate?
        let status = SecIdentityCopyCertificate(identity, &stored)
        guard status == errSecSuccess, let certificate = stored else {
            throw .identityUnusable(
                reason: "the stored identity has no certificate in it (status \(status)); "
                    + "delete \"\(subject.commonName)\" in Keychain Access and restart to generate a new one"
            )
        }

        guard let publicKey = SecCertificateCopyKey(certificate),
              let point = SecKeyCopyExternalRepresentation(publicKey, nil) as Data?,
              let restated = try? P256.Signing.PublicKey(x963Representation: point)
        else {
            throw .identityUnusable(
                reason: "\"\(subject.commonName)\" in the Keychain is not the P-256 certificate this serves under; "
                    + "delete it in Keychain Access and restart to generate a new one"
            )
        }

        guard let notBefore = validity(of: certificate, at: kSecOIDX509V1ValidityNotBefore),
              let notAfter = validity(of: certificate, at: kSecOIDX509V1ValidityNotAfter)
        else {
            throw .identityUnusable(reason: "the stored certificate does not say when it is valid")
        }

        var name: CFString?
        SecCertificateCopyCommonName(certificate, &name)

        return ServerIdentity(
            certificateDer: Array(SecCertificateCopyData(certificate) as Data),
            fingerprint: SpkiFingerprint(subjectPublicKeyInfoDer: restated.derRepresentation),
            // Falls back to what this run would have called it. Cosmetic — it is what a Settings
            // row reads, while everything that decides anything uses the fingerprint.
            commonName: name as String? ?? subject.commonName,
            notBefore: notBefore,
            notAfter: notAfter
        )
    }

    /// The dates come back through the general-purpose accessor, which reports them as Core
    /// Foundation absolute times — seconds since 2001, not since 1970.
    private func validity(of certificate: SecCertificate, at key: CFString) -> Date? {
        guard let values = SecCertificateCopyValues(certificate, [key] as CFArray, nil) as? [CFString: Any],
              let field = values[key] as? [CFString: Any],
              let seconds = field[kSecPropertyKeyValue] as? Double
        else {
            return nil
        }
        return Date(timeIntervalSinceReferenceDate: seconds)
    }
}
