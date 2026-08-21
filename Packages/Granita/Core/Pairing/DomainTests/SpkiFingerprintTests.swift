import CryptoKit
import Foundation
import Testing

import CorePairingDomain

/// The fingerprint is what the phone pins, and getting it wrong fails only on device — a handshake
/// that is refused with no other symptom. So both halves of it are asserted against a vector
/// produced by `openssl` rather than against anything in this repository:
///
/// ```
/// openssl ec -in key.pem -pubout -outform DER | xxd -p -c 200
/// openssl ec -in key.pem -pubout -outform DER | openssl dgst -sha256 -binary | openssl base64
/// ```
///
/// A test that hashed our own encoder's output would agree with it however wrong it was.
struct SpkiFingerprintTests {

    // MARK: - Against the vector

    @Test func `given the vector key when reading its subject public key info then it is what openssl encodes`() throws {
        // given
        let key = try P256.Signing.PrivateKey(rawRepresentation: Data(vectorPrivateKey))

        // when
        let encoded = Array(key.publicKey.derRepresentation)

        // then
        #expect(encoded == vectorSubjectPublicKeyInfo)
    }

    @Test func `given the vector key when fingerprinting it then it matches openssl`() throws {
        // given
        let key = try P256.Signing.PrivateKey(rawRepresentation: Data(vectorPrivateKey))

        // when
        let fingerprint = SpkiFingerprint(subjectPublicKeyInfoDer: key.publicKey.derRepresentation)

        // then
        #expect(fingerprint.rawValue == "I5uJIP2xbKC5fDV8f2rN/QyE6RnEDh4HxjReWb18jXQ=")
    }

    @Test func `when fingerprinting known bytes then it is the base64 of their sha256`() {
        // given - when
        let fingerprint = SpkiFingerprint(subjectPublicKeyInfoDer: Data("granita".utf8))

        // then
        // `printf 'granita' | openssl dgst -sha256 -binary | openssl base64`
        #expect(fingerprint.rawValue == "fgYbsEg8toAI9GI9dw6nSYMa4Pv2wy6Qp6cHgvkYhh8=")
    }

    // MARK: - As a value

    @Test func `given two fingerprints of the same key then they are equal`() throws {
        // given
        let key = try P256.Signing.PrivateKey(rawRepresentation: Data(vectorPrivateKey))

        // when
        let first = SpkiFingerprint(subjectPublicKeyInfoDer: key.publicKey.derRepresentation)
        let second = SpkiFingerprint(subjectPublicKeyInfoDer: key.publicKey.derRepresentation)

        // then
        #expect(first == second)
    }

    @Test func `given two different keys then their fingerprints differ`() throws {
        // given
        let one = P256.Signing.PrivateKey()
        let other = P256.Signing.PrivateKey()

        // when
        let first = SpkiFingerprint(subjectPublicKeyInfoDer: one.publicKey.derRepresentation)
        let second = SpkiFingerprint(subjectPublicKeyInfoDer: other.publicKey.derRepresentation)

        // then
        #expect(first != second)
    }
}

// MARK: -

/// The private key `openssl ecparam -name prime256v1 -genkey` produced, as its 32 raw bytes.
let vectorPrivateKey: [UInt8] = [
    0xf2, 0xac, 0x6b, 0xc8, 0xdc, 0xb5, 0xe8, 0x68, 0xbb, 0x64, 0xf0, 0xbb, 0x7f, 0x6a, 0x7d, 0x0d,
    0x20, 0x93, 0x00, 0xda, 0x2b, 0x95, 0x2a, 0x0c, 0x9b, 0x80, 0xad, 0x74, 0xec, 0x51, 0xec, 0x79
]

/// That key's public half, as `openssl ec -pubout -outform DER` encodes it.
let vectorSubjectPublicKeyInfo: [UInt8] = [
    0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x08, 0x2a,
    0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00, 0x04, 0x50, 0x8c, 0x85, 0x4c, 0xd2,
    0xeb, 0xd8, 0x45, 0x17, 0x7b, 0x0f, 0x7d, 0x8a, 0xfb, 0x1e, 0x19, 0x67, 0x19, 0x98, 0xa4, 0xe2,
    0xb6, 0xdc, 0x6c, 0x30, 0xaf, 0x41, 0x42, 0x15, 0xb8, 0x78, 0x46, 0x18, 0xa1, 0x93, 0x8f, 0x9f,
    0x1f, 0x84, 0x83, 0x6e, 0x62, 0x4a, 0x86, 0xfd, 0xe8, 0x8a, 0xd3, 0x12, 0x37, 0x42, 0x5c, 0xe7,
    0x1f, 0x01, 0x8e, 0x74, 0x9c, 0x86, 0x81, 0x66, 0x39, 0x11, 0xfa
]
