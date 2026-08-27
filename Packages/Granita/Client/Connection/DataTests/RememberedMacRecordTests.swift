import Foundation
import Testing

import ClientConnectionDomain
import CorePairingDomain

@testable import ClientConnectionData

/// The bytes of one Keychain item, asserted here because the store that writes them cannot be run at
/// all: a SwiftPM test binary is unsigned and has no keychain of its own.
@Suite("A remembered Mac's record")
struct RememberedMacRecordTests {

    @Test
    func `given a pairing when it is written and read back then nothing about it is lost`() async {
        // given — the whole reason a shape is asserted rather than assumed: what comes out of here is
        // what a session is pinned with and authenticates with, and a field dropped in the round trip
        // is a Mac that answers every request with a refusal nobody can explain.
        let bytes = RememberedMacRecord(of: aPairedMac).encoded

        // when
        let read = bytes.flatMap(RememberedMacRecord.decoded(from:))

        // then
        #expect(read?.remembered == RememberedMac(device: aPairedDevice, fingerprint: aFingerprint))
    }

    @Test
    func `given a bare token when it is read then it is not a pairing`() async {
        // given — exactly what 0.4.0 and earlier wrote, which is still sitting in the Keychain of
        // every phone that has ever paired. Read as a pairing it would be a token with no key beside
        // it; read as nothing it is a Mac the reader pairs with once more and never again.
        let bytes = Data("1f0e4d7c6b5a49382736251403f2e1d0".utf8)

        // when - then
        #expect(RememberedMacRecord.decoded(from: bytes) == nil)
    }

    @Test
    func `given a pairing when it is written then the address it was reached at is not in it`() async {
        // given — the system chooses the port every time a Mac binds, so a stored address is wrong
        // the first time it restarts. Keeping one would be a phone reporting a Mac two feet away as
        // unreachable, which is worse than the lookup it saves.
        let record = RememberedMacRecord(of: aPairedMac)

        // when
        let written = String(data: record.encoded ?? Data(), encoding: .utf8) ?? ""

        // then
        #expect(!written.contains("davides-macbook-pro.local"))
        #expect(!written.contains("59144"))
    }
}

// MARK: -

private let aFingerprint = SpkiFingerprint(rawValue: "cf83e1357eefb8bdf1542850d66d8007")

private let aPairedDevice = PairedDevice(
    token: PairingToken(rawValue: "1f0e4d7c6b5a49382736251403f2e1d0"),
    deviceId: DeviceId(rawValue: "8C4F2A11-0000-4E5D-9A3B-77F1C0DE0001"),
    serverInstanceId: ServerInstanceId(rawValue: "3B9AC0DE-1111-4A2C-8D6E-55E0B1CAFE22")
)

private let aPairedMac = PairedMac(
    instance: BonjourInstanceName(rawValue: "Davide's MacBook Pro"),
    name: "Davide's MacBook Pro",
    device: aPairedDevice,
    address: ServerAddress(host: "davides-macbook-pro.local", port: 59_144),
    fingerprint: aFingerprint
)
