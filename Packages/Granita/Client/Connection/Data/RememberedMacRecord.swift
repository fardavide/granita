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
/// Four strings rather than the domain types they become. The wrappers exist to stop a token being
/// passed where a device identifier was expected, which is a rule about this app's own code; what
/// goes on disk is text either way, and re-deriving the typing at the boundary is where a boundary
/// is supposed to do its work.
struct RememberedMacRecord: Codable, Hashable, Sendable {

    let token: String
    let deviceId: String
    let serverInstanceId: String
    let fingerprint: String

    init(of pairing: PairedMac) {
        token = pairing.device.token.rawValue
        deviceId = pairing.device.deviceId.rawValue
        serverInstanceId = pairing.device.serverInstanceId.rawValue
        fingerprint = pairing.fingerprint.rawValue
    }

    var remembered: RememberedMac {
        RememberedMac(
            device: PairedDevice(
                token: PairingToken(rawValue: token),
                deviceId: DeviceId(rawValue: deviceId),
                serverInstanceId: ServerInstanceId(rawValue: serverInstanceId)
            ),
            fingerprint: SpkiFingerprint(rawValue: fingerprint)
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
