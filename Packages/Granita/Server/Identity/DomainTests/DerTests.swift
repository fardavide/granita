import Foundation
import Testing

@testable import ServerIdentityDomain

/// The encoder underneath the certificate, asserted against the encodings X.690 fixes rather than
/// against anything this repository decided.
///
/// Every one of these is a rule a naive implementation gets wrong in a way nothing reports: a
/// length written in one byte when it needs three, an integer whose leading bit turns a positive
/// serial negative, an object identifier whose first two components are not packed. The certificate
/// still *builds*; it is the handshake three layers away that fails.
struct DerTests {

    // MARK: - Lengths

    @Test func `given a short value when encoding then its length is one byte`() {
        // given - when
        let encoded = DerValue.octetString([0x01, 0x02]).encoded

        // then
        #expect(encoded == [0x04, 0x02, 0x01, 0x02])
    }

    @Test func `given a value of exactly 128 bytes when encoding then the length is written long form`() {
        // given
        let content = [UInt8](repeating: 0xaa, count: 128)

        // when
        let encoded = DerValue.octetString(content).encoded

        // then
        // 127 is the last length that fits in one byte. At 128 the high bit would read as the
        // long-form marker, so the length must be escaped even though it still fits in a byte.
        #expect(Array(encoded.prefix(3)) == [0x04, 0x81, 0x80])
        #expect(encoded.count == 131)
    }

    @Test func `given a value longer than 255 bytes when encoding then the length takes two bytes`() {
        // given
        let content = [UInt8](repeating: 0xaa, count: 300)

        // when
        let encoded = DerValue.octetString(content).encoded

        // then
        #expect(Array(encoded.prefix(4)) == [0x04, 0x82, 0x01, 0x2c])
        #expect(encoded.count == 304)
    }

    // MARK: - Integers

    @Test func `given a positive integer when encoding then it is written as it stands`() {
        // given - when
        let encoded = DerValue.integer(2).encoded

        // then
        #expect(encoded == [0x02, 0x01, 0x02])
    }

    @Test func `given bytes whose leading bit is set when encoding an integer then a zero is prepended`() {
        // given
        let serial: [UInt8] = [0x80, 0x01]

        // when
        let encoded = DerValue.unsignedInteger(serial).encoded

        // then
        // Without the pad this is a negative serial number, which RFC 5280 forbids and which some
        // stacks reject and others silently renumber.
        #expect(encoded == [0x02, 0x03, 0x00, 0x80, 0x01])
    }

    @Test func `given bytes with leading zeros when encoding an integer then they are dropped`() {
        // given
        let serial: [UInt8] = [0x00, 0x00, 0x2a]

        // when
        let encoded = DerValue.unsignedInteger(serial).encoded

        // then
        #expect(encoded == [0x02, 0x01, 0x2a])
    }

    @Test func `given bytes that are all zero when encoding an integer then one zero survives`() {
        // given
        let serial: [UInt8] = [0x00, 0x00]

        // when
        let encoded = DerValue.unsignedInteger(serial).encoded

        // then
        #expect(encoded == [0x02, 0x01, 0x00])
    }

    // MARK: - Object identifiers

    @Test func `given ecdsa with sha256 when encoding its identifier then it is what x690 packs`() {
        // given - when
        let encoded = DerValue.objectIdentifier(.ecdsaWithSha256).encoded

        // then
        // The first two components share a byte and 10045 spans two, which is the whole of what
        // this encoding does that a byte-per-component one does not.
        #expect(encoded == [0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x04, 0x03, 0x02])
    }

    @Test func `given the subject alternative name extension when encoding its identifier then it is three bytes`() {
        // given - when
        let encoded = DerValue.objectIdentifier(.subjectAlternativeName).encoded

        // then
        #expect(encoded == [0x06, 0x03, 0x55, 0x1d, 0x11])
    }

    @Test func `given server authentication when encoding its identifier then it is what rfc 5280 lists`() {
        // given - when
        let encoded = DerValue.objectIdentifier(.serverAuthentication).encoded

        // then
        #expect(encoded == [0x06, 0x08, 0x2b, 0x06, 0x01, 0x05, 0x05, 0x07, 0x03, 0x01])
    }

    // MARK: - Bit strings

    @Test func `given a signature when encoding it as a bit string then no bits are declared unused`() {
        // given - when
        let encoded = DerValue.bitString([0xde, 0xad], unusedBits: 0).encoded

        // then
        #expect(encoded == [0x03, 0x03, 0x00, 0xde, 0xad])
    }

    @Test func `given the digital signature key usage when encoding it then seven bits are unused`() {
        // given - when
        let encoded = DerValue.bitString([0x80], unusedBits: 7).encoded

        // then
        #expect(encoded == [0x03, 0x02, 0x07, 0x80])
    }

    // MARK: - Times

    @Test func `given a date before 2050 when encoding it then it is a two digit year`() {
        // given
        let date = Date(timeIntervalSince1970: 1_771_632_000)

        // when
        let encoded = DerValue.time(date).encoded

        // then
        // RFC 5280 requires UTCTime up to 2049 and GeneralizedTime after it, and a certificate that
        // picks the wrong one is refused by anything strict.
        #expect(encoded.first == 0x17)
        #expect(String(decoding: encoded.dropFirst(2), as: UTF8.self) == "260221000000Z")
    }

    @Test func `given a date in 2050 when encoding it then it is a four digit year`() {
        // given
        let date = Date(timeIntervalSince1970: 2_524_608_000)

        // when
        let encoded = DerValue.time(date).encoded

        // then
        #expect(encoded.first == 0x18)
        #expect(String(decoding: encoded.dropFirst(2), as: UTF8.self) == "20500101000000Z")
    }

    // MARK: - Composites

    @Test func `given nested values when encoding a sequence then it wraps their encodings in order`() {
        // given - when
        let encoded = DerValue.sequence([.integer(1), .octetString([0xff])]).encoded

        // then
        #expect(encoded == [0x30, 0x06, 0x02, 0x01, 0x01, 0x04, 0x01, 0xff])
    }

    @Test func `given a value in an explicit context tag when encoding then the tag wraps the whole thing`() {
        // given - when
        let encoded = DerValue.explicitlyTagged(0, .integer(2)).encoded

        // then
        #expect(encoded == [0xa0, 0x03, 0x02, 0x01, 0x02])
    }

    @Test func `given a value in an implicit context tag when encoding then only its tag changes`() {
        // given - when
        let encoded = DerValue.implicitlyTagged(2, bytes: Array("a.local".utf8)).encoded

        // then
        #expect(encoded == [0x82, 0x07] + Array("a.local".utf8))
    }
}
