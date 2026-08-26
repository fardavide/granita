import SwiftUI

import ClientConnectionDomain
import ClientConnectionUi

/// The Mac's own screen, and the parent of the three the pairing spine pushes.
///
/// It owns **the destination for every pairing step**, as one exhaustive switch: the two credentials
/// are linked from here, the outcome from a screen further on, and a step that gained no destination
/// would not compile rather than answering a tap with silence.
///
/// **It does not own what happens when a pairing works, and that is a correction rather than a
/// division of labour.** It used to, on the reasoning that this screen sits under all three of the
/// others and therefore sees every path — and being underneath is precisely what stopped it working,
/// because `onChange` dies at `onDisappear` while the body goes on being evaluated. What it passes
/// down instead is the closure, to the two screens that can be on top when a credential is spent.
/// See `PairedMacHandover` and `.claude/docs/decisions.md`.
struct PairingEntryScreen: View {

    private let model: ClientConnectionModel
    private let server: DiscoveredServer
    private let phone: ThisPhone
    private let onPaired: (PairedMac) -> Void

    @Binding private var path: NavigationPath

    /// Held here rather than on the model, because it belongs to one screen and one Mac: a value
    /// kept a layer up would sit under the *next* Mac's name for as long as its lookup took.
    @State private var address: ServerAddress?

    init(
        model: ClientConnectionModel,
        server: DiscoveredServer,
        phone: ThisPhone,
        path: Binding<NavigationPath>,
        onPaired: @escaping (PairedMac) -> Void
    ) {
        self.model = model
        self.server = server
        self.phone = phone
        _path = path
        self.onPaired = onPaired
    }

    var body: some View {
        PairingEntryView(
            macName: server.name,
            address: address,
            onScanCode: { path.append(PairingStep.scanTheCode) },
            onEnterWords: { path.append(PairingStep.typeTheWords) }
        )
        // **Declared here, beside the two links that reach it**, which is the placement that stops a
        // link and its destination drifting apart in two modules — the exact way this app came to
        // ship a row that did nothing at all. The switch is total over the step, so the third case,
        // which is linked from the two screens below, cannot be forgotten either. See `CLAUDE.md`
        // and `.claude/docs/decisions.md`.
        .navigationDestination(for: PairingStep.self) { step in
            switch step {
            case .scanTheCode:
                PairingScannerScreen(
                    model: model,
                    server: server,
                    phone: phone,
                    path: $path,
                    onPaired: onPaired
                )
            case .typeTheWords:
                PairingWordsScreen(model: model, server: server, phone: phone, path: $path)
            case .theOutcome:
                PairingOutcomeScreen(model: model, server: server, phone: phone, onPaired: onPaired)
            }
        }
        // **Arriving here is what starts an attempt**, and it is the only place that can say so:
        // the model is one instance for the life of the app, this screen sits under all three of
        // the others, and every one of them reads state nothing else clears. Without the first
        // line the viewfinder opens on a spend that finished at another Mac and the six-word
        // screen arrives with that Mac's phrase already typed.
        //
        // The second is the line under the two buttons. A browse result is an identity rather than
        // a location, so the address has to be asked for before it can be drawn — and stays absent
        // when nothing answers, because a Mac that cannot be resolved says so properly one tap
        // later.
        .task {
            model.beginPairing(with: server)
            address = await model.address(of: server)
        }
    }
}
