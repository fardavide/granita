import Testing

import CorePairingDomain
@testable import ClientConnectionData

/// A viewfinder hands the app a machine-readable code several times a second and most of them belong
/// to somebody else. What one of them amounts to is decided away from the session that produces
/// them — that session only runs in front of a real camera, and the object it delivers is made by
/// AVFoundation and cannot be built by a test at all, which is why the text comes off it first.
@Suite("Machine-readable code")
struct MachineReadableCodeTests {

    @Test func `given a code the camera saw but could not read when it is taken then it is not an event`() {
        // given - when — `stringValue` is optional on every machine-readable code, and one caught at
        // the edge of the frame arrives with none.
        let code = MachineReadableCode.scanned(nil)

        // then — the same silence as a stranger's code, and for the same reason: design §5 keeps
        // even a foreign QR down to a line under the reticle, and this is less than that.
        #expect(code == .somethingElse)
    }

    @Test func `given a whole pairing link when it is taken off a code then it is the one to spend`() {
        // given
        let text = "granita://pair?host=studio-display.local&port=54321&code=nine-of-hearts&spki=Kq7pR0aW"

        // when
        let code = MachineReadableCode.scanned(text)

        // then — compared against a link built by hand rather than by reading it back through the
        // parser, so this catches that reader rather than mirroring it.
        #expect(code == .pairingLink(PairingLink(
            host: "studio-display.local",
            port: 54321,
            code: "nine-of-hearts",
            fingerprint: SpkiFingerprint(rawValue: "Kq7pR0aW")
        )))
    }

    @Test func `given our link with its key missing when it is taken off a code then it is damaged`() {
        // given — the shape a Mac one release behind would show, and the reader is pointing straight
        // at it.
        let text = "granita://pair?host=studio-display.local&port=54321&code=nine-of-hearts"

        // when
        let code = MachineReadableCode.scanned(text)

        // then — kept apart from a stranger's code all the way down the seam, because the screen
        // says something different about each and cannot tell them apart later.
        #expect(code == .damagedPairingLink(.missingField(named: "spki")))
    }

    @Test func `given somebody else's code when it is taken then it is passed over in silence`() {
        // given — the single most likely thing to be in shot beside a Mac at a desk.
        let text = "WIFI:S:Davide's Network;T:WPA;P:hunter2;;"

        // when
        let code = MachineReadableCode.scanned(text)

        // then
        #expect(code == .somethingElse)
    }
}
