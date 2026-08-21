import Foundation

/// Just enough DER to write one certificate.
///
/// Hand-rolled rather than taken from a library, for the reason recorded in `decisions.md`: the
/// project spends exactly three external dependencies and this is a few hundred bytes of encoding
/// whose output the system parser checks in a test. What is *not* negotiable is that the encoding
/// be right — X.690 has a handful of rules that a naive writer breaks silently, and each of them
/// produces a certificate that builds and then fails a handshake with no reason attached.
indirect enum DerValue {

    case boolean(Bool)

    case integer(Int)

    /// A non-negative number given as its bytes, most significant first — a serial number.
    case unsignedInteger([UInt8])

    case bitString([UInt8], unusedBits: UInt8)

    case octetString([UInt8])

    case objectIdentifier(DerObjectIdentifier)

    case utf8String(String)

    /// A time, written in whichever of the two encodings RFC 5280 requires for its year.
    case time(Date)

    case sequence([DerValue])

    case set([DerValue])

    /// A value wrapped in a context-specific tag, tag and all — `[n] EXPLICIT`.
    case explicitlyTagged(UInt8, DerValue)

    /// Content under a context-specific tag that replaces its own — `[n] IMPLICIT`.
    case implicitlyTagged(UInt8, bytes: [UInt8])

    /// Bytes that are already DER, spliced in as they stand. The public key arrives this way:
    /// CryptoKit encodes the whole `SubjectPublicKeyInfo`, and re-encoding it here would be a
    /// second implementation of the one structure the fingerprint is taken over.
    case verbatim([UInt8])

    var encoded: [UInt8] {
        switch self {
        case .boolean(let value):
            // DER admits exactly one true, unlike BER, which admits any non-zero byte.
            Self.tagged(0x01, [value ? 0xff : 0x00])
        case .integer(let value):
            Self.tagged(0x02, Self.twosComplement(of: value))
        case .unsignedInteger(let bytes):
            Self.tagged(0x02, Self.minimalUnsigned(bytes))
        case .bitString(let bytes, let unusedBits):
            Self.tagged(0x03, [unusedBits] + bytes)
        case .octetString(let bytes):
            Self.tagged(0x04, bytes)
        case .objectIdentifier(let identifier):
            Self.tagged(0x06, identifier.packed)
        case .utf8String(let text):
            Self.tagged(0x0c, Array(text.utf8))
        case .time(let date):
            Self.encodedTime(date)
        case .sequence(let values):
            Self.tagged(0x30, values.flatMap(\.encoded))
        case .set(let values):
            Self.tagged(0x31, values.flatMap(\.encoded))
        case .explicitlyTagged(let tag, let value):
            Self.tagged(0xa0 | tag, value.encoded)
        case .implicitlyTagged(let tag, let bytes):
            Self.tagged(0x80 | tag, bytes)
        case .verbatim(let bytes):
            bytes
        }
    }

    private static func tagged(_ tag: UInt8, _ content: [UInt8]) -> [UInt8] {
        [tag] + length(of: content.count) + content
    }

    /// **The rule a naive encoder breaks first.** A length under 128 is one byte; from 128 up, the
    /// high bit marks a count of length bytes that follow. Writing 200 as a single `0xc8` says
    /// "seventy-two length bytes follow" to every parser in the world.
    private static func length(of count: Int) -> [UInt8] {
        if count < 0x80 {
            return [UInt8(count)]
        }
        var bytes: [UInt8] = []
        var remaining = count
        while remaining > 0 {
            bytes.insert(UInt8(remaining & 0xff), at: 0)
            remaining >>= 8
        }
        return [0x80 | UInt8(bytes.count)] + bytes
    }

    /// Integers are two's complement, so a value whose leading bit is set needs a zero in front of
    /// it or it reads as negative — which for a serial number is something RFC 5280 forbids and
    /// which different stacks then disagree about.
    private static func minimalUnsigned(_ bytes: [UInt8]) -> [UInt8] {
        var trimmed = bytes
        while trimmed.count > 1, trimmed[0] == 0x00 {
            trimmed.removeFirst()
        }
        if trimmed.isEmpty {
            return [0x00]
        }
        return trimmed[0] & 0x80 == 0 ? trimmed : [0x00] + trimmed
    }

    private static func twosComplement(of value: Int) -> [UInt8] {
        var bytes: [UInt8] = []
        var remaining = value
        repeat {
            bytes.insert(UInt8(truncatingIfNeeded: remaining), at: 0)
            remaining >>= 8
        } while remaining != 0 && remaining != -1
        if value >= 0, let first = bytes.first, first & 0x80 != 0 {
            bytes.insert(0x00, at: 0)
        }
        return bytes
    }

    /// **UTCTime through 2049, GeneralizedTime from 2050.** RFC 5280 makes the choice a MUST rather
    /// than a preference, and the two differ only in whether the year has two digits — which is
    /// exactly the kind of difference a strict parser refuses and a lax one accepts.
    private static func encodedTime(_ date: Date) -> [UInt8] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMddHHmmss"
        let stamped = formatter.string(from: date)

        let isBeforeTheSwitch = stamped.prefix(4) < "2050"
        let digits = isBeforeTheSwitch ? String(stamped.dropFirst(2)) : stamped
        return tagged(isBeforeTheSwitch ? 0x17 : 0x18, Array("\(digits)Z".utf8))
    }
}

// MARK: -

/// An object identifier, held as its components so the file reads as the numbers RFC 5280 lists.
///
/// Split into a first, a second and the rest because the encoding packs the first two into one
/// byte, and a type that could hold fewer than two would need an error case for a value none of
/// the constants below can have.
struct DerObjectIdentifier: Hashable {

    let first: UInt
    let second: UInt
    let rest: [UInt]

    /// The signature algorithm, on the certificate and inside it. Both copies must agree, which is
    /// why there is one constant rather than two literals.
    static let ecdsaWithSha256 = Self(first: 1, second: 2, rest: [840, 10045, 4, 3, 2])

    static let commonName = Self(first: 2, second: 5, rest: [4, 3])
    static let keyUsage = Self(first: 2, second: 5, rest: [29, 15])
    static let subjectAlternativeName = Self(first: 2, second: 5, rest: [29, 17])
    static let basicConstraints = Self(first: 2, second: 5, rest: [29, 19])
    static let extendedKeyUsage = Self(first: 2, second: 5, rest: [29, 37])
    static let serverAuthentication = Self(first: 1, second: 3, rest: [6, 1, 5, 5, 7, 3, 1])

    /// The first two components share a byte and everything after them is base 128 with a
    /// continuation bit — so `10045` is two bytes and a byte-per-component encoder produces an
    /// identifier that names something else entirely.
    var packed: [UInt8] {
        var bytes = [UInt8(40 * first + second)]
        for component in rest {
            var digits: [UInt8] = [UInt8(component & 0x7f)]
            var remaining = component >> 7
            while remaining > 0 {
                digits.insert(UInt8(remaining & 0x7f) | 0x80, at: 0)
                remaining >>= 7
            }
            bytes += digits
        }
        return bytes
    }
}
