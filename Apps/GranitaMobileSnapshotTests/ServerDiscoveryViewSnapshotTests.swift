import ClientConnectionDomain
import ClientConnectionUi
import SwiftUI
import Testing

/// Every state the discovery screen can be in, in every layout it has to survive.
///
/// This is the whole reason `ServerDiscoveryView` takes its state as a parameter instead of owning a
/// view model: two of these five states are otherwise reachable only by revoking a permission on a
/// physical device, and one of those is the state a reader is most likely to see and least likely to
/// understand. Here they are all just values.
/// Main-actor isolated, and it must be. Swift Testing runs `@Test` functions off the main actor by
/// default, and rendering touches UIKit view properties — which trap with
/// `_raiseExceptionForBackgroundThreadLayerPropertyModification`. That trap is worse than a plain
/// failure here: the crash restarts the test host, and the retry then reports "0 tests passed",
/// so the suite goes green having rendered nothing.
@Suite("Server discovery screen", .serialized)
@MainActor
struct ServerDiscoveryViewSnapshotTests {

    @Test(arguments: Case.all, SnapshotLayout.all)
    func `given a discovery state when rendering then it matches its baseline`(
        subject: Case,
        layout: SnapshotLayout
    ) {
        // given - when - then
        //
        // Wrapped in a NavigationStack because the composition root wraps it, and because
        // `.navigationTitle` renders nothing outside a navigation container — an unwrapped baseline
        // would silently stop covering the title bar the reader actually sees.
        //
        // Nothing clamps its width, because nothing in the app does either: through 0.7.0 both sides
        // held this stack in a 420pt centred column, and the iPad baselines photographed a screen
        // with white either side of it.
        assertScreenSnapshot(
            NavigationStack {
                ServerDiscoveryView(
                    state: subject.state,
                    onSearchAgain: {},
                    onOpenSettings: {}
                )
            },
            layout: layout,
            named: subject.name
        )
    }
}

// MARK: -

/// Named so the baseline filename says which state it captures, and so a failure names it too.
///
/// Twenty renderings come out of one test function: five states across four layouts. Writing them as
/// twenty near-identical functions would make adding a sixth state a twenty-four-line change, and
/// the sixth state is the one nobody would then add.
struct Case: Sendable, CustomTestStringConvertible {

    let name: String
    let state: DiscoveryState

    var testDescription: String { name }

    static let all: [Case] = [
        Case(name: "searching", state: .searching),

        // Distinct from `searching` on purpose: the browser is working and there is genuinely
        // nothing there, which needs different words from "still looking".
        Case(name: "nothing-found", state: .found([])),

        Case(name: "one-mac", state: .found([aMac(called: "Davide's MacBook Pro")])),

        // More than one, and one with a name long enough to find a truncation bug.
        Case(name: "several-macs", state: .found([
            aMac(called: "MacBook Pro"),
            aMac(called: "Mac Studio"),
            aMac(called: "Davide's 16-inch MacBook Pro (work)")
        ])),

        // The one the reader can act on, and the one that shipped broken: iOS reports a refusal one
        // way to a first browser and another way to every browser after it.
        Case(name: "permission-refused", state: .localNetworkDenied),

        // Two lines, because that is what the screen has to lay out: the system's sentence, which is
        // the same for almost every fault, and the code, which is the only part of it anyone can
        // act on. A one-line payload would stop covering the layout the reader actually gets.
        Case(name: "failed", state: .failed(diagnostic: "The operation couldn’t be completed.\nNWError -65563"))
    ]

    /// A browse result under the one name a Mac has on this network, which is both its identity and
    /// the string the row draws. The two are the same value and this list is where that shows: a
    /// Bonjour instance name is unique within a local domain, so nothing here has to disambiguate.
    private static func aMac(called name: String) -> DiscoveredServer {
        DiscoveredServer(id: BonjourInstanceName(rawValue: name), name: name)
    }
}
