import Foundation

import ClientConnectionDomain
import CorePairingDomain

/// A remembered Mac as the bytes that go into one Keychain item.
///
/// **It is separate from the Keychain store so that it can be tested at all.** A SwiftPM test binary
/// is unsigned and has no keychain of its own, so everything in that file is unrunnable by
/// construction and exempt from the coverage rows — and the part most worth holding to its behaviour
/// is this one, because a shape that changed silently would read as a Mac that was never paired with
/// and send the reader back through the pairing screens with no way to tell why.
///
/// Strings rather than the domain types they become. The wrappers exist to stop a token being
/// passed where a device identifier was expected, which is a rule about this app's own code; what
/// goes on disk is text either way, and re-deriving the typing at the boundary is where a boundary
/// is supposed to do its work.
struct RememberedMacRecord: Codable, Hashable, Sendable {

    let token: String
    let deviceId: String
    let serverInstanceId: String
    let fingerprint: String

    /// What to send a magic packet to when this Mac is asleep.
    ///
    /// **Optional so that a record written before it existed still decodes.** Every Mac already
    /// paired with when this shipped has no such field, and a non-optional one would make every one
    /// of those pairings unreadable — which reads to the reader as a Mac they must pair with again,
    /// for no reason they could see. Absent and empty both mean "cannot be woken", and nothing here
    /// needs to tell them apart.
    let wakeAddresses: [String]?

    init(of pairing: PairedMac) {
        token = pairing.device.token.rawValue
        deviceId = pairing.device.deviceId.rawValue
        serverInstanceId = pairing.device.serverInstanceId.rawValue
        fingerprint = pairing.fingerprint.rawValue
        wakeAddresses = pairing.wakeAddresses.map(\.text)
    }

    var remembered: RememberedMac {
        RememberedMac(
            device: PairedDevice(
                token: PairingToken(rawValue: token),
                deviceId: DeviceId(rawValue: deviceId),
                serverInstanceId: ServerInstanceId(rawValue: serverInstanceId)
            ),
            fingerprint: SpkiFingerprint(rawValue: fingerprint),
            // Re-parsed rather than trusted: what is on disk was written by some other version, and
            // one entry that is not an address must cost that entry rather than the pairing.
            wakeAddresses: HardwareAddress.all(in: wakeAddresses ?? [])
        )
    }

    /// The bytes to store, or nothing if this value cannot be written down.
    ///
    /// **Returns rather than throws, because a caller could do nothing different either way**: four
    /// strings always encode, so `nil` here would be a Foundation failure nobody can act on, and it
    /// arrives at the reader as the same refusal a locked Keychain gives.
    var encoded: Data? {
        try? JSONEncoder().encode(self)
    }

    /// What was stored, or nothing if it is not a pairing this version can read.
    ///
    /// The absent case is real rather than defensive: 0.4.0 and earlier stored a bare token under a
    /// different key, and anything else under this one is a Mac that has to be paired with again.
    static func decoded(from data: Data) -> RememberedMacRecord? {
        try? JSONDecoder().decode(RememberedMacRecord.self, from: data)
    }
}
