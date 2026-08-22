import ClientConnectionDomain
import ClientConnectionUi
import SwiftUI
import Testing

/// What a reader sees after tapping a Mac, until pairing has a screen of its own.
///
/// **This baseline exists because its absence was the defect.** The discovery rows are
/// `NavigationLink`s and nothing declared a destination for them, so tapping the Mac you opened the
/// app to read did nothing at all — and no test noticed, because a snapshot of the *list* is green
/// whether or not its rows lead anywhere.
///
/// So read this suite for what it is and is not. It proves the message renders and reads well. It
/// does **not** prove the row reaches it — nothing here can, because a snapshot renders a view
/// someone handed it. That proof needs a behavioural test that taps a row, which is the `ui` kind
/// this project does not have a target for yet, and this defect is what earns it.
@Suite("Pairing not ready")
@MainActor
struct PairingNotReadyViewSnapshotTests {

    @Test(arguments: SnapshotLayout.all)
    func `given a Mac was tapped when pairing is unbuilt then the screen says so`(
        layout: SnapshotLayout
    ) {
        // given — a long-ish device name, because the sentence names the Mac and the name is the
        // part that can push it onto another line at 390pt.
        let server = DiscoveredServer(id: "davides-macbook-pro", name: "Davide's MacBook Pro")

        // when - then
        //
        // Wrapped and clamped exactly as the discovery screen is, for the same two reasons: a
        // `.navigationTitle` renders nothing outside a navigation container, and the measure only
        // takes the large title with it from outside one.
        assertScreenSnapshot(
            NavigationStack {
                PairingNotReadyView(server: server)
            }
            .frame(maxWidth: ServerDiscoveryView.contentWidth)
            .frame(maxWidth: .infinity),
            layout: layout,
            named: "pairing-not-ready"
        )
    }
}
