import SwiftUI

import ClientConnectionDomain
import ClientConnectionUi

/// Binds the connection model to the discovery view, and is the foot of the pairing spine.
///
/// The screen lives here rather than in `Ui` because it owns state, and owning state is what
/// separates the two layers: `Ui` renders what it is handed, `Presentation` decides what that is.
///
/// **Three of its five parameters are not about discovery at all**, and that is the cost of the rule
/// below: this screen builds the one it links to, so it carries what that screen needs — what this
/// phone is called and the camera it will draw, the stack the pairing screens move within, and where
/// a pairing that worked should land, which only the composition root can answer.
public struct ServerDiscoveryScreen: View {

    @State private var model: ClientConnectionModel

    private let phone: ThisPhone
    private let onPaired: (PairedMac) -> Void

    @Binding private var path: NavigationPath

    public init(
        model: ClientConnectionModel,
        phone: ThisPhone,
        path: Binding<NavigationPath>,
        onPaired: @escaping (PairedMac) -> Void
    ) {
        // Pinned in @State rather than held as a plain `let`: the composition root rebuilds this
        // screen on every parent re-evaluation, and a plain property would swap the displayed model
        // while the running .task kept driving the discarded one.
        _model = State(initialValue: model)
        self.phone = phone
        _path = path
        self.onPaired = onPaired
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
            PairingEntryScreen(
                model: model,
                server: server,
                phone: phone,
                path: $path,
                onPaired: onPaired
            )
        }
        // Keyed on the attempt so that searching again is a *new browser* rather than a new reading
        // of the dead one: SwiftUI cancels the running task, which tears the browse down, and starts
        // this one over. A dead browser is dead for good, and Search Again is tapped precisely when
        // the reader has one.
        .task(id: model.attempt) { await model.start() }
    }
}
