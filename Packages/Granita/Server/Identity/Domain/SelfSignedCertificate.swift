import CryptoKit
import Foundation

import CorePairingDomain

/// Builds the self-signed certificate SPEC §8 asks for: P-256, ten years, a subject alternative
/// name for every way this Mac can be reached.
///
/// Pure arithmetic over a key it is handed, so the whole of it runs in a host test and the only
/// part that cannot — where the key is kept — sits behind `ServerIdentityStore` instead.
public enum SelfSignedCertificate {

    /// Produces the DER `ECDSA-Sig-Value` over the certificate body, or `nil` if the key refused.
    ///
    /// A closure rather than a key, because the key that matters most never leaves the Keychain:
    /// it is generated there and only ever asked to sign. The `P256` overload below is for tests
    /// and for anything that legitimately holds key material.
    public typealias Signing = (_ body: [UInt8]) -> [UInt8]?

    /// - Parameter serialNumber: Chosen by the caller rather than here, so that "which certificate
    ///   is this" stays a question with a deterministic answer in a test.
    public static func identity(
        subjectPublicKeyInfoDer: [UInt8],
        commonName: String,
        subjectAlternativeNames: [SubjectAlternativeName],
        serialNumber: [UInt8],
        notBefore: Date,
        notAfter: Date,
        sign: Signing
    ) throws(ServerIdentityError) -> ServerIdentity {
        try check(commonName: commonName, subjectAlternativeNames: subjectAlternativeNames)

        // The same algorithm identifier appears inside the signed body and beside the signature.
        // A certificate whose two copies disagree is rejected, so there is one value here.
        let algorithm = DerValue.sequence([.objectIdentifier(.ecdsaWithSha256)])

        // Self-signed: the issuer and the subject are the same name, and this is what makes it so.
        let name = DerValue.sequence([
            .set([.sequence([.objectIdentifier(.commonName), .utf8String(commonName)])])
        ])

        let body = DerValue.sequence([
            // Version 3, which is what having extensions at all requires.
            .explicitlyTagged(0, .integer(2)),
            .unsignedInteger(serialNumber),
            algorithm,
            name,
            .sequence([.time(notBefore), .time(notAfter)]),
            name,
            .verbatim(subjectPublicKeyInfoDer),
            .explicitlyTagged(3, .sequence(extensions(covering: subjectAlternativeNames)))
        ])
        let signedBytes = body.encoded

        guard let signature = sign(signedBytes) else {
            throw ServerIdentityError.notSignable(reason: "the key would not sign the certificate")
        }

        let certificate = DerValue.sequence([
            .verbatim(signedBytes),
            algorithm,
            .bitString(signature, unusedBits: 0)
        ])

        return ServerIdentity(
            certificateDer: certificate.encoded,
            fingerprint: SpkiFingerprint(subjectPublicKeyInfoDer: subjectPublicKeyInfoDer),
            commonName: commonName,
            notBefore: notBefore,
            notAfter: notAfter
        )
    }

    /// The same thing, for a key this process is holding — the tests, and the fake behind
    /// `ServerIdentityStore`.
    public static func identity(
        signedBy key: P256.Signing.PrivateKey,
        commonName: String,
        subjectAlternativeNames: [SubjectAlternativeName],
        serialNumber: [UInt8],
        notBefore: Date,
        notAfter: Date
    ) throws(ServerIdentityError) -> ServerIdentity {
        try identity(
            subjectPublicKeyInfoDer: Array(key.publicKey.derRepresentation),
            commonName: commonName,
            subjectAlternativeNames: subjectAlternativeNames,
            serialNumber: serialNumber,
            notBefore: notBefore,
            notAfter: notAfter,
            sign: { body in (try? key.signature(for: Data(body))).map { Array($0.derRepresentation) } }
        )
    }

    private static func extensions(covering names: [SubjectAlternativeName]) -> [DerValue] {
        [
            // An empty SEQUENCE is `cA FALSE`, because DER omits a field at its default. This is an
            // end-entity certificate: the phone pins its key rather than chaining to it.
            certificateExtension(.basicConstraints, isCritical: true, value: .sequence([])),
            // digitalSignature alone — the only bit an ECDSA key can be used for here.
            certificateExtension(.keyUsage, isCritical: true, value: .bitString([0x80], unusedBits: 7)),
            certificateExtension(
                .extendedKeyUsage,
                isCritical: false,
                value: .sequence([.objectIdentifier(.serverAuthentication)])
            ),
            // Not critical, because the common name is present too and a client that reads only
            // the name still gets an answer. Every modern client reads this instead.
            certificateExtension(
                .subjectAlternativeName,
                isCritical: false,
                value: .sequence(names.map(generalName))
            )
        ]
    }

    private static func certificateExtension(
        _ identifier: DerObjectIdentifier,
        isCritical: Bool,
        value: DerValue
    ) -> DerValue {
        var parts: [DerValue] = [.objectIdentifier(identifier)]
        // Written only when true: `critical` defaults to false, and DER forbids encoding a field
        // that holds its default.
        if isCritical {
            parts.append(.boolean(true))
        }
        parts.append(.octetString(value.encoded))
        return .sequence(parts)
    }

    private static func generalName(_ name: SubjectAlternativeName) -> DerValue {
        switch name {
        case .dnsName(let text): .implicitlyTagged(2, bytes: Array(text.utf8))
        case .ipAddress(let address): .implicitlyTagged(7, bytes: address.bytes)
        }
    }

    /// Refuses what the encoding cannot carry, rather than carrying it wrongly.
    ///
    /// Each of these would otherwise produce a certificate that is accepted here and matches
    /// nothing on the network — which is a fault with no symptom other than a phone that will not
    /// connect, and that is the failure this whole slice exists to make legible.
    private static func check(
        commonName: String,
        subjectAlternativeNames: [SubjectAlternativeName]
    ) throws(ServerIdentityError) {
        guard commonName.isEmpty == false else {
            throw ServerIdentityError.malformedSubject(reason: "an empty name")
        }
        guard subjectAlternativeNames.isEmpty == false else {
            throw ServerIdentityError.malformedSubject(reason: "no names at all")
        }
        for name in subjectAlternativeNames {
            switch name {
            case .dnsName(let text):
                // A DNS name is IA5String, which has no room for anything outside ASCII.
                guard text.allSatisfy(\.isASCII), text.isEmpty == false else {
                    throw ServerIdentityError.malformedSubject(reason: "a DNS name outside ASCII: \(text)")
                }
            case .ipAddress(let address):
                guard address.bytes.count == 4 || address.bytes.count == 16 else {
                    throw ServerIdentityError.malformedSubject(
                        reason: "an IP address of \(address.bytes.count) bytes"
                    )
                }
            }
        }
    }
}
