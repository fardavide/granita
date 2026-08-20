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
@Suite("Server discovery screen")
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
        assertScreenSnapshot(
            NavigationStack {
                ServerDiscoveryView(state: subject.state, onSelect: { _ in }, onOpenSettings: {})
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

        Case(name: "one-mac", state: .found([
            DiscoveredServer(id: "Davide's MacBook Pro", name: "Davide's MacBook Pro")
        ])),

        // More than one, and one with a name long enough to find a truncation bug.
        Case(name: "several-macs", state: .found([
            DiscoveredServer(id: "MacBook Pro", name: "MacBook Pro"),
            DiscoveredServer(id: "Mac Studio", name: "Mac Studio"),
            DiscoveredServer(
                id: "Davide's 16-inch MacBook Pro (work)",
                name: "Davide's 16-inch MacBook Pro (work)"
            )
        ])),

        // The one the reader can act on, and the one that shipped broken: iOS reports a refusal one
        // way to a first browser and another way to every browser after it.
        Case(name: "permission-refused", state: .localNetworkDenied),

        Case(name: "failed", state: .failed("The operation couldn’t be completed."))
    ]
}
