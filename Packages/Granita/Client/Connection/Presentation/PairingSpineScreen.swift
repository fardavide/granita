import SwiftUI

import ClientConnectionDomain

/// The one navigation container this app has, and the two ways out of it.
///
/// **It is a screen rather than three lines in the composition root** because the path it drives
/// carries a rule — a pairing that worked replaces the screens that produced it — and a rule left in
/// a `Main` module is untested code that no longer looks untested. The rule itself is not here: it is
/// `PairingSpineNavigation`, which is where a host test can walk a sequence a rendered baseline can
/// only photograph one frame of. What is left in this body is declaration: the container and the two
/// destinations.
///
/// **Nothing here clamps how wide the app may draw.** Through 0.7.0 everything before a paired Mac
/// was held in a 420pt centred column, which put the large title and the rows in the middle of an
/// iPad and left the window white either side of them. The screens use stock SwiftUI at the width
/// they are given now. See `.claude/docs/decisions.md`.
///
/// The two destinations past the spine are handed in, because both are built over a session pinned
/// to one Mac and neither may be seen from here: a `Presentation` target sees its own `Ui` and any
/// `Domain`, never a sibling `Presentation`. What this screen contributes is that they are the *same*
/// two — the only two ways out of the spine — declared within four lines of each other.
public struct PairingSpineScreen<Remembered: View, JustPaired: View>: View {

    /// Where the stack is. Pinned here because the container is.
    @State private var navigation: PairingSpineNavigation

    private let model: ClientConnectionModel
    private let phone: ThisPhone
    private let readingARememberedMac: (DiscoveredServer) -> Remembered
    private let readingAJustPairedMac: (PairedMac) -> JustPaired

    /// - Parameter path: where the stack opens. The app opens at the Mac list; the snapshot suite
    ///   opens at whichever push it is photographing, which is what lets a baseline assert that a
    ///   value put on this path comes back as a screen.
    public init(
        model: ClientConnectionModel,
        phone: ThisPhone,
        startingAt path: NavigationPath,
        @ViewBuilder readingARememberedMac: @escaping (DiscoveredServer) -> Remembered,
        @ViewBuilder readingAJustPairedMac: @escaping (PairedMac) -> JustPaired
    ) {
        _navigation = State(initialValue: PairingSpineNavigation(startingAt: path))
        self.model = model
        self.phone = phone
        self.readingARememberedMac = readingARememberedMac
        self.readingAJustPairedMac = readingAJustPairedMac
    }

    public var body: some View {
        NavigationStack(path: $navigation.path) {
            ServerDiscoveryScreen(
                model: model,
                phone: phone,
                path: $navigation.path,
                onPaired: navigation.paired(with:),
                // A Mac this phone has paired with before opens its worktrees, and nothing in
                // between: the Keychain read, the Bonjour lookup and the pinned session all happen
                // behind the list's own loading state.
                readingARememberedMac: readingARememberedMac
            )
            // **The one destination the discovery screen does not declare for itself**, because the
            // value on the path is not one of its rows: it is the Mac a pairing just produced.
            .navigationDestination(for: PairedMac.self, destination: readingAJustPairedMac)
        }
    }
}
