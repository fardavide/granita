import Foundation
import Testing

import CorePairingDomain
import ServerApiDomain
import ServerMacDomain
import ServerMacUi

/// The Devices tab, design §5.
///
/// Every state here is a pure function of a fixed clock and a fixed code, which is the only reason a
/// countdown can be photographed at all: the pane takes `now` as a value, so *Expires in 1:46* is
/// arithmetic on two numbers rather than a reading taken at the moment the shutter opened.
///
/// The QR is part of what these compare, and it should be: a picture of the wrong link is the one
/// defect on this tab that a reader cannot see and a phone cannot recover from.
@Suite("Devices settings")
@MainActor
struct DevicesSettingsViewSnapshotTests {

    /// The moment every state below is measured against.
    private static let now = Date(timeIntervalSince1970: 1_755_864_000)

    /// When this run of the app began watching, which is what a device with no sighting reports.
    private static let launched = Date(timeIntervalSince1970: 1_755_862_320)

    @Test(arguments: MacAppearance.all)
    func `given two paired devices and a live code when Devices renders then it matches its baseline`(
        appearance: MacAppearance
    ) {
        // given — the frame's own state: one phone this run has served, one it has not, and a code
        // most of the way through its two minutes.
        // when - then
        assertSettingsSnapshot(
            view(devices: Self.devices, offer: .offered(Self.invitation(expiresIn: 106))),
            appearance: appearance,
            named: "two-paired-code-live"
        )
    }

    /// The state a first run is spent in, and the one that matters most: nothing has paired, so this
    /// pane is the entire reason the product does anything.
    @Test(arguments: MacAppearance.all)
    func `given nothing has paired when Devices renders then it matches its baseline`(
        appearance: MacAppearance
    ) {
        // given - when - then
        assertSettingsSnapshot(
            view(devices: [], offer: .offered(Self.invitation(expiresIn: 106))),
            appearance: appearance,
            named: "nothing-paired"
        )
    }

    @Test(arguments: MacAppearance.all)
    func `given the code has run out when Devices renders then it matches its baseline`(
        appearance: MacAppearance
    ) {
        // given — a code that quietly expired looks exactly like a wrong code from the phone's side,
        // which is the whole reason this state is drawn rather than left to the countdown reaching
        // zero and stopping there.
        // when - then
        assertSettingsSnapshot(
            view(devices: Self.devices, offer: .offered(Self.invitation(expiresIn: -30))),
            appearance: appearance,
            named: "expired"
        )
    }

    @Test(arguments: MacAppearance.all)
    func `given nothing is serving when Devices renders then it matches its baseline`(
        appearance: MacAppearance
    ) {
        // given - when - then
        assertSettingsSnapshot(
            view(devices: Self.devices, offer: .serverNotRunning),
            appearance: appearance,
            named: "server-not-running"
        )
    }

    @Test(arguments: MacAppearance.all)
    func `given a code is being made when Devices renders then it matches its baseline`(
        appearance: MacAppearance
    ) {
        // given - when - then
        assertSettingsSnapshot(
            view(devices: Self.devices, offer: .preparing),
            appearance: appearance,
            named: "preparing"
        )
    }

    @Test(arguments: MacAppearance.all)
    func `given the identity cannot be read when Devices renders then it matches its baseline`(
        appearance: MacAppearance
    ) {
        // given — not a state the frames draw, and it exists because the code is signed by something
        // out of the login keychain. Our sentence, the system's underneath.
        // when - then
        assertSettingsSnapshot(
            view(
                devices: Self.devices,
                offer: .unavailable(
                    reason: "the Keychain refused while looking for the existing certificate (-25308) — unlock the login keychain"
                )
            ),
            appearance: appearance,
            named: "no-code-possible"
        )
    }

    @Test(arguments: MacAppearance.all)
    func `given a revoke the store refused when Devices renders then it matches its baseline`(
        appearance: MacAppearance
    ) {
        // given — the row is still there, which is the point: this picture is what stops a Revoke
        // that did nothing from looking like one that worked.
        // when - then
        assertSettingsSnapshot(
            view(
                devices: Self.devices,
                offer: .offered(Self.invitation(expiresIn: 106)),
                failure: StoreWriteFailure(
                    sentence: "That change could not be saved.",
                    reason: "No space left on device"
                )
            ),
            appearance: appearance,
            named: "revoke-refused"
        )
    }

    // MARK: -

    private func view(
        devices: [PairedDevice],
        offer: PairingOffer,
        failure: StoreWriteFailure? = nil
    ) -> DevicesSettingsView {
        DevicesSettingsView(
            devices: devices,
            offer: offer,
            now: Self.now,
            failure: failure,
            onNewCode: {},
            onCopySpokenCode: {},
            onRevoke: { _ in },
            onOpenGeneral: {}
        )
    }

    private static let devices = [
        PairedDevice(
            id: "iphone",
            name: "Davide's iPhone",
            platform: "iOS",
            pairedAt: Date(timeIntervalSince1970: 1_754_179_200),
            sighting: .seen(at: now.addingTimeInterval(-260))
        ),
        PairedDevice(
            id: "ipad",
            name: "iPad Pro",
            platform: "iPadOS",
            pairedAt: Date(timeIntervalSince1970: 1_754_956_800),
            sighting: .notSeenSince(launched)
        )
    ]

    /// A fixed code, so the QR is the same picture every time these are recorded. A `UUID` or a
    /// random hexadecimal string would make every re-recording a diff of two different photographs.
    private static func invitation(expiresIn seconds: TimeInterval) -> PairingInvitation {
        PairingInvitation(
            link: PairingLink(
                host: "MacBook-Pro.local",
                port: 59_144,
                code: "0f3a1c7b9e2d4a6c8b0e5f7a3d1c9b2e",
                fingerprint: SpkiFingerprint(rawValue: "kZ8Qk1p3mR7vN2xT4yL6sB9wC0dF5gH8jK1lM3nP7qU=")
            ),
            spokenCode: "delta-pepper-amber-kelp-jasper-meadow",
            expiresAt: now.addingTimeInterval(seconds)
        )
    }
}
