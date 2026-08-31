import SwiftUI

import ClientConnectionDomain
import ClientConnectionUi

/// The one navigation container this app has, and design §5's 420pt measure around it.
///
/// **It is a screen rather than four lines in the composition root, and that placement is the fix
/// rather than tidying.** The measure is conditional — everything before a paired Mac lives in a
/// 420pt centred column, and the worktree list past it is a split view that must have the whole
/// window — so the container carries a *decision*, and a decision left in a `Main` module is untested
/// code that no longer looks untested. It was left there, the condition was wrong for the route
/// every reader actually takes, and it shipped: an iPad opening a Mac it had already paired with drew
/// a 320pt sidebar and a 100pt detail column inside a 420pt slot, with white either side. See
/// `.claude/docs/decisions.md`.
///
/// **The rule itself is not here** — it is `PairingSpineNavigation`, which is where a host test can
/// walk the sequence a rendered baseline can only photograph one frame of. What is left in this body
/// is declaration: the container, the measure read off that object, and the two destinations.
///
/// The two destinations past the spine are handed in, because both are built over a session pinned
/// to one Mac and neither may be seen from here: a `Presentation` target sees its own `Ui` and any
/// `Domain`, never a sibling `Presentation`. What this screen contributes is that they are the *same*
/// two — the only two ways out of the spine — and that each is marked as such in the same three lines.
public struct PairingSpineScreen<Remembered: View, JustPaired: View>: View {

    /// Where the stack is, and how wide it may draw. Pinned here because the container is.
    @State private var navigation: PairingSpineNavigation

    private let model: ClientConnectionModel
    private let phone: ThisPhone
    private let readingARememberedMac: (DiscoveredServer) -> Remembered
    private let readingAJustPairedMac: (PairedMac) -> JustPaired

    /// - Parameter path: where the stack opens. The app opens at the Mac list; the snapshot suite
    ///   opens at whichever push it is photographing, which is what lets a baseline assert that a
    ///   value put on this path comes back as a screen — and now, at what width.
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
                readingARememberedMac: { pastTheSpine(readingARememberedMac($0)) }
            )
            // **The one destination the discovery screen does not declare for itself**, because the
            // value on the path is not one of its rows: it is the Mac a pairing just produced.
            .navigationDestination(for: PairedMac.self) { pastTheSpine(readingAJustPairedMac($0)) }
        }
        .frame(maxWidth: navigation.contentWidth)
        .frame(maxWidth: .infinity)
    }

    /// Marks a destination as the far side of the pairing spine, which is what releases the measure.
    ///
    /// **Written once and applied to both destinations in adjacent lines**, which is the only part of
    /// this that is load-bearing: the defect was not the flag but that one route set it and the other
    /// did not, in two modules, where nothing made the omission visible. A destination added here
    /// without this call is a destination in the wrong measure — and it is now a three-word omission
    /// on the line above its neighbour rather than a missing assignment a module away.
    private func pastTheSpine(_ screen: some View) -> some View {
        screen.onAppear(perform: navigation.openedAWorktreeList)
    }
}
