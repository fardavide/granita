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
/// they are given now. See `.ai/docs/decisions.md`.
///
/// The two destinations past the spine are handed in, because both are built over a session pinned
/// to one Mac and neither may be seen from here: a `Presentation` target sees its own `Ui` and any
/// `Domain`, never a sibling `Presentation`. What this screen contributes is that they are the *same*
/// two — the only two ways out of the spine — declared within a dozen lines of each other.
///
/// **Three declarations for those two**, because a launch resuming onto a Mac and a row tapped for
/// one reach the same screen by different values, and the value is what decides which of them a
/// branch is asked about. `ResumedMac` is not asked, which is its whole purpose.
public struct PairingSpineScreen<Remembered: View, JustPaired: View>: View {

    /// Where the stack is. Pinned here because the container is.
    @State private var navigation: PairingSpineNavigation

    private let model: ClientConnectionModel
    private let phone: ThisPhone
    private let readingARememberedMac: (DiscoveredServer, @escaping () -> Void) -> Remembered
    private let readingAJustPairedMac: (PairedMac, @escaping () -> Void) -> JustPaired

    /// - Parameter path: where the stack opens when there is nothing to resume. The app passes an
    ///   empty one; the snapshot suite passes whichever push it is photographing, which is what lets
    ///   a baseline assert that a value put on this path comes back as a screen.
    public init(
        model: ClientConnectionModel,
        phone: ThisPhone,
        startingAt path: NavigationPath,
        remembering lastOpened: any LastOpenedMacPreference,
        @ViewBuilder readingARememberedMac: @escaping (DiscoveredServer, @escaping () -> Void) -> Remembered,
        @ViewBuilder readingAJustPairedMac: @escaping (PairedMac, @escaping () -> Void) -> JustPaired
    ) {
        _navigation = State(initialValue: PairingSpineNavigation(startingAt: path, remembering: lastOpened))
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
                readingARememberedMac: { server in
                    readingARememberedMac(server, { navigation.pairAgain(with: server) })
                        // **Written down where the worktrees actually appear, rather than where the
                        // row is tapped.** This closure is drawn only in the remembered branch, so
                        // nothing a pairing screen reaches can be recorded as a Mac the next launch
                        // may open — which is what keeps a resume from landing somewhere that can
                        // only ask for a code.
                        .onAppear { navigation.opened(server) }
                }
            )
            // **Where a launch opens, and the only destination whose value nothing ever pushes.** It
            // is on the path before the first frame, put there by the rule in `PairingSpineNavigation`
            // — and it is a value of its own rather than the Mac itself for the reason `ResumedMac`
            // carries: a browsed Mac's destination branches against a set that is empty this early.
            .navigationDestination(for: ResumedMac.self) { resumed in
                readingARememberedMac(resumed.server, { navigation.pairAgain(with: resumed.server) })
            }
            // **The one destination the discovery screen does not declare for itself**, because the
            // value on the path is not one of its rows: it is the Mac a pairing just produced.
            .navigationDestination(for: PairedMac.self) { mac in
                readingAJustPairedMac(mac, {
                    navigation.pairAgain(with: DiscoveredServer(id: mac.instance, name: mac.name))
                })
            }
            .navigationDestination(for: PairingAgain.self) { destination in
                PairingEntryScreen(
                    model: model, server: destination.server, phone: phone,
                    path: $navigation.path, onPaired: navigation.paired(with:)
                )
            }
        }
    }
}
