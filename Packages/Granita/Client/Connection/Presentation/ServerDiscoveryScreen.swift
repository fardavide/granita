import SwiftUI

import ClientConnectionDomain
import ClientConnectionUi

/// Binds the connection model to the discovery view, and is the foot of the pairing spine.
///
/// The screen lives here rather than in `Ui` because it owns state, and owning state is what
/// separates the two layers: `Ui` renders what it is handed, `Presentation` decides what that is.
///
/// **Four of its six parameters are not about discovery at all**, and that is the cost of the rule
/// below: this screen builds the ones it links to, so it carries what they need — what this phone is
/// called and the camera it will draw, the stack the pairing screens move within, where a pairing
/// that worked should land, and what a Mac this phone already knows opens instead of a pairing
/// screen. The last two can only be answered by the composition root.
public struct ServerDiscoveryScreen<RememberedMacScreen: View>: View {

    @State private var model: ClientConnectionModel

    private let phone: ThisPhone
    private let onPaired: (PairedMac) -> Void
    private let readingARememberedMac: (DiscoveredServer) -> RememberedMacScreen

    @Binding private var path: NavigationPath

    public init(
        model: ClientConnectionModel,
        phone: ThisPhone,
        path: Binding<NavigationPath>,
        onPaired: @escaping (PairedMac) -> Void,
        @ViewBuilder readingARememberedMac: @escaping (DiscoveredServer) -> RememberedMacScreen
    ) {
        // Pinned in @State rather than held as a plain `let`: the composition root rebuilds this
        // screen on every parent re-evaluation, and a plain property would swap the displayed model
        // while the running .task kept driving the discarded one.
        _model = State(initialValue: model)
        self.phone = phone
        _path = path
        self.onPaired = onPaired
        self.readingARememberedMac = readingARememberedMac
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
        //
        // **The branch is the whole of what a remembered Mac changes**, and it is here rather than
        // in the row because a row that led somewhere else would need `Ui` to know what a stored
        // pairing is. One value, one destination, and this decides which screen that destination
        // draws: the worktrees for a Mac this phone has paired with, the two credentials for one it
        // has not. Design §5 is explicit that the first is where a paired Mac's row goes; until
        // 0.4.0 both went to the second, so every open of the app asked for a code again. See
        // `.claude/docs/decisions.md`.
        .navigationDestination(for: DiscoveredServer.self) { server in
            ChosenMacScreen(isRemembered: model.isRemembered(server)) {
                readingARememberedMac(server)
            } pairingWithIt: {
                PairingEntryScreen(
                    model: model,
                    server: server,
                    phone: phone,
                    path: $path,
                    onPaired: onPaired
                )
            }
        }
        // Keyed on the attempt so that searching again is a *new browser* rather than a new reading
        // of the dead one: SwiftUI cancels the running task, which tears the browse down, and starts
        // this one over. A dead browser is dead for good, and Search Again is tapped precisely when
        // the reader has one.
        .task(id: model.attempt) { await model.start() }
    }
}

// MARK: -

/// Which of the two screens a tapped Mac leads to, **decided once and then held**.
///
/// A `navigationDestination` closure is re-evaluated whenever anything it reads changes, and what
/// this one reads is a set that grows the instant a pairing succeeds. Asked again at that moment it
/// answers differently — so the reader, mid-flow on the outcome screen, would have the whole pairing
/// stack replaced underneath them by a worktree list. The stack *is* replaced a beat later, on
/// purpose and by the composition root, which is what makes the swap here pure damage: the same
/// destination arriving twice by two different routes, one of them uninvited.
///
/// `@State` is the pin, and its identity is the pushed Mac — so the answer is taken when that Mac's
/// screen is first drawn and survives every later evaluation of it, while a different Mac gets its
/// own. It is the same reason the screen above pins its model and the split view pins its own.
private struct ChosenMacScreen<Remembered: View, Pairing: View>: View {

    @State private var isRemembered: Bool

    private let readingIt: () -> Remembered
    private let pairingWithIt: () -> Pairing

    init(
        isRemembered: Bool,
        @ViewBuilder readingIt: @escaping () -> Remembered,
        @ViewBuilder pairingWithIt: @escaping () -> Pairing
    ) {
        _isRemembered = State(initialValue: isRemembered)
        self.readingIt = readingIt
        self.pairingWithIt = pairingWithIt
    }

    var body: some View {
        if isRemembered {
            readingIt()
        } else {
            pairingWithIt()
        }
    }
}
