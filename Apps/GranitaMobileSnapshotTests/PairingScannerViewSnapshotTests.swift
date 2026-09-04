import ClientConnectionDomain
import ClientConnectionUi
import SwiftUI
import Testing

/// Every state the viewfinder can be in, in every layout it has to survive.
///
/// **This is what the injected preview was for.** Four of these six are otherwise reachable only by
/// answering a system alert on a physical device, and the other two need a Mac showing a QR code
/// across a room — so the camera arrives as a still and every one of them is just a value.
///
/// The two layouts are not the same screen. On the phone the preview fills the window and the app
/// goes dark behind it; on the iPad it is a 4:3 card inside the 420pt measure on the ordinary
/// background, because blacking out 1,194pt to host a 420pt card makes a modal out of a pushed
/// screen. Both halves are photographed, which is the only way that call is held to.
///
/// Main-actor isolated, and it must be. Swift Testing runs `@Test` functions off the main actor by
/// default, and rendering touches UIKit view properties — which trap with
/// `_raiseExceptionForBackgroundThreadLayerPropertyModification`. That trap is worse than a plain
/// failure: the crash restarts the test host, and the retry then reports "0 tests passed", so the
/// suite goes green having rendered nothing.
@Suite("Pairing scanner screen", .serialized)
@MainActor
struct PairingScannerViewSnapshotTests {

    @Test(arguments: ScannerCase.all, SnapshotLayout.all)
    func `given a viewfinder state when rendering then it matches its baseline`(
        subject: ScannerCase,
        layout: SnapshotLayout
    ) {
        // given - when - then
        //
        // Clamped outside the navigation container like every screen before a paired Mac, and the
        // camera is inside it: design §5 asks for a 420pt-wide card on the iPad rather than a
        // full-bleed preview, so the measure is what produces the card.
        assertScreenSnapshot(
            NavigationStack {
                PairingScannerView(
                    macName: aMacName,
                    state: subject.state,
                    onEnterWords: {},
                    onOpenSettings: {}
                ) {
                    CameraStill()
                }
            }
            .frame(maxWidth: ServerDiscoveryView.contentWidth)
            .frame(maxWidth: .infinity),
            layout: layout,
            named: subject.name
        )
    }
}

// MARK: -

/// Named so the baseline filename says which state it captures, and so a failure names it too.
struct ScannerCase: Sendable, CustomTestStringConvertible {

    let name: String
    let state: PairingState

    var testDescription: String { name }

    static let all: [ScannerCase] = [
        // The screen the permission alert lands on, and the state usually left undrawn: the reader
        // reads it while deciding, so it already carries the way past it. `notStarted` draws the
        // same thing, because before the task that asks has run, waiting for access is exactly what
        // this screen is doing.
        ScannerCase(name: "waiting-for-camera-access", state: .waitingForCameraAccess),

        // A refusal is a preference rather than a fault: the other credential is the primary action
        // and Settings is a plain button that is not mentioned in the description at all.
        ScannerCase(name: "camera-refused", state: .cameraRefused),

        // The same screen minus the one control that cannot work. Under a policy there is no switch
        // behind that button, so it is absent rather than dead — which is the difference this
        // baseline exists to hold, because the two states are one glance apart.
        ScannerCase(name: "camera-restricted", state: .cameraRestricted),

        ScannerCase(name: "looking", state: .looking),

        // A QR that is not ours, said as a line rather than as an interruption: the capsule replaces
        // the hint and the camera keeps running. The pair with `looking` is the assertion — what has
        // to be true is that nothing else on the screen moved.
        ScannerCase(name: "saw-something-else", state: .sawSomethingElse),

        // Finding one freezes the frame: the preview dims, the six-word button goes because there is
        // nothing left to choose, and the back button is hidden because a code that works once must
        // not be abandonable halfway.
        ScannerCase(name: "spending", state: .spending)
    ]
}
