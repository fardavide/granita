import ClientConnectionDomain
import ClientConnectionUi
import SwiftUI
import Testing

/// The screen a Mac's row leads to, in every layout it has to survive.
///
/// One appearance and two subjects, which is what design §5 draws: the entry screen exists for the
/// sentence about the other machine rather than for the choice under it, so there is no state where
/// it says anything else. What differs between the two is the line at the bottom — a browse result
/// is an identity rather than a location, so the address is absent until something has resolved one,
/// and *absent* is a layout of its own rather than a shorter version of the other.
///
/// Main-actor isolated, and it must be. Swift Testing runs `@Test` functions off the main actor by
/// default, and rendering touches UIKit view properties — which trap with
/// `_raiseExceptionForBackgroundThreadLayerPropertyModification`. That trap is worse than a plain
/// failure: the crash restarts the test host, and the retry then reports "0 tests passed", so the
/// suite goes green having rendered nothing.
@Suite("Pairing entry screen")
@MainActor
struct PairingEntryViewSnapshotTests {

    @Test(arguments: EntryCase.all, SnapshotLayout.all)
    func `given a Mac to pair with when rendering then it matches its baseline`(
        subject: EntryCase,
        layout: SnapshotLayout
    ) {
        // given - when - then
        //
        // Wrapped and clamped the way the composition root wraps it, on the same side of the stack
        // as design §1's screens: this is one of the four that live before a paired Mac, and §5 puts
        // every one of them in a 420pt column, title included. Applied inside the navigation
        // container it would assert an alignment the app does not have, because iOS draws the title
        // in the bar rather than in the content.
        assertScreenSnapshot(
            NavigationStack {
                PairingEntryView(
                    macName: aMacName,
                    address: subject.address,
                    onScanCode: {},
                    onEnterWords: {}
                )
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
struct EntryCase: Sendable, CustomTestStringConvertible {

    let name: String
    let address: ServerAddress?

    var testDescription: String { name }

    static let all: [EntryCase] = [
        // Resolved, which is the state the screen settles into a moment after it appears.
        EntryCase(name: "address-known", address: aMacAddress),

        // And the state it is pushed in, which is the one a slow Bonjour lookup leaves up for as
        // long as it takes: the two buttons sit on the bottom edge with nothing under them. It is
        // photographed because a caption that appears late is a layout the reader sees first.
        EntryCase(name: "address-not-yet-known", address: nil)
    ]
}
