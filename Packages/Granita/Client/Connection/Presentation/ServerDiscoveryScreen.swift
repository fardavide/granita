import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

import ClientConnectionDomain
import ClientConnectionUi

/// Binds the connection model to the discovery view.
///
/// The screen lives here rather than in `Ui` because it owns state, and owning state is what
/// separates the two layers: `Ui` renders what it is handed, `Presentation` decides what that is.
public struct ServerDiscoveryScreen: View {

    @State private var model: ClientConnectionModel

    public init(model: ClientConnectionModel) {
        // Pinned in @State rather than held as a plain `let`: the composition root rebuilds this
        // screen on every parent re-evaluation, and a plain property would swap the displayed model
        // while the running .task kept driving the discarded one.
        _model = State(initialValue: model)
    }

    public var body: some View {
        ServerDiscoveryView(
            state: model.discovery,
            onSearchAgain: model.searchAgain,
            onOpenSettings: openSettings
        )
        // **Declared here, beside the rows that link to it, and that placement is the fix.** The
        // list offers `NavigationLink(value:)`, and for a while nothing in the app declared a
        // destination for that value — which compiles, draws a chevron, and does nothing at all
        // when tapped. It shipped that way. A link and its destination living in two modules is
        // what let them drift apart silently; in one file, adding the first without the second is
        // visible. See `CLAUDE.md` and `.claude/docs/decisions.md`.
        .navigationDestination(for: DiscoveredServer.self) { server in
            PairingNotReadyView(server: server)
        }
        // Keyed on the attempt so that searching again is a *new browser* rather than a new reading
        // of the dead one: SwiftUI cancels the running task, which tears the browse down, and starts
        // this one over. A dead browser is dead for good, and Search Again is tapped precisely when
        // the reader has one.
        .task(id: model.attempt) { await model.start() }
    }

    private func openSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }
}
