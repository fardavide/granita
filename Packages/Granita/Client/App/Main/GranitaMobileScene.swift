import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

import ClientConnectionData
import ClientConnectionDomain
import ClientConnectionPresentation
import ClientConnectionUi
import ClientViewerPresentation
import ClientWorktreesData
import ClientWorktreesPresentation

/// Composition root for the phone and the iPad: the one Client target that may see a `Data`
/// target, because wiring implementations into the protocols every other target depends on is
/// its entire job.
///
/// The Xcode target is a thin `@main` shell over this scene, so nothing a test would want to reach
/// lives in the app bundle.
public struct GranitaMobileScene: Scene {

    /// The stack's path, held here because the stack is.
    ///
    /// It exists rather than being left implicit for one reason: **a pairing that works replaces
    /// the pairing screens instead of pushing over them**, and only a path a screen can assign to
    /// makes that expressible. Back then returns to the Mac list, never to a viewfinder holding a
    /// code that has already been spent.
    @State private var path = NavigationPath()

    /// Whether the reader is past the Macs and into a worktree list, which is the only thing in
    /// this app that changes the measure.
    ///
    /// It is navigation state and belongs beside the path for the same reason the path does — the
    /// container is the root's, so what the container is showing is too. It cannot be *read* off
    /// the path: `NavigationPath` is type-erased on purpose, so that each destination is declared
    /// beside the link that reaches it, and a paired Mac and a Mac about to be paired with both sit
    /// at depth one.
    @State private var isReadingAPairedMac = false

    public init() {}

    public var body: some Scene {
        WindowGroup {
            // The stack, and nothing about where its rows lead — `ServerDiscoveryScreen` declares
            // that itself, because the module that offers a link is the one that must know where it
            // goes. This root used to be where the destination would have gone, and the destination
            // was simply absent: tapping the Mac a reader opened the app to read answered with
            // silence, and it shipped. See `CLAUDE.md` and `.claude/docs/decisions.md`.
            NavigationStack(path: $path) {
                ServerDiscoveryScreen(
                    model: ClientConnectionModel(
                        browsing: BonjourServerDiscovery(),
                        joining: MacPairing(tokens: KeychainPairingTokenStore(), handshake: Self.handshake),
                        camera: CaptureDeviceCameraAuthorization(),
                        scanner: Self.scanner,
                        addresses: BonjourServerAddressResolver()
                    ),
                    phone: Self.phone,
                    path: $path,
                    // **The one link in the app whose destination is a module away**, so the two
                    // are written together: this closure is what a paired Mac lands on, and the
                    // modifier below is where it lands. Everything the pairing screens push
                    // declares its own destination beside its own link.
                    //
                    // Assigned rather than appended, which is the whole of design §5's success:
                    // the pairing screens are replaced, so back returns to the Mac list and never
                    // to a viewfinder holding a code that has already been spent.
                    onPaired: { mac in
                        isReadingAPairedMac = true
                        path = NavigationPath([mac])
                    }
                )
                // The list this product exists for, in design §2's own container: one sidebar and
                // one detail column, which the phone collapses back to the list alone. It titles
                // itself after the Mac, which §5 asks for — and which is set inside that screen
                // rather than out here, because a title applied to a container does not override
                // one applied within it. See `.claude/docs/decisions.md`.
                .navigationDestination(for: PairedMac.self) { mac in
                    WorktreeSplitScreen(model: Self.worktrees(of: mac)) { worktree, displayName in
                        // **The second link in this app whose destination is a module away**, and
                        // it is here for the same reason the first is: `ClientWorktreesPresentation`
                        // may see any `Domain` and its own `Ui`, never a sibling `Presentation`. The
                        // sidebar declares the destination — it has to, because a split view keeps
                        // what its own columns declare — and this supplies what it builds. The
                        // parameter is required, so the row cannot go quiet the way it did for eight
                        // releases; what it opens is the only part that could ever be wrong.
                        // **The name arrives with the identifier rather than being resolved here**,
                        // and that is 0.1.0's iPad defect not happening twice: this closure runs on
                        // every evaluation and each one builds a worktrees model that has read
                        // nothing, so a name looked up here would be the fallback word on every
                        // worktree there is. The screen that pins the loaded model resolves it.
                        WorktreeDiffScreen(
                            worktreeName: displayName,
                            model: ClientViewerModel(worktree: worktree, repository: Self.repository(of: mac))
                        )
                    }
                }
            }
            // The measure goes around the stack rather than around the screen, because iOS draws a
            // large title in the navigation bar and not in the content: framing the content alone
            // centres the rows under a title still pinned to the window's leading edge, which is the
            // misalignment this is here to remove.
            //
            // **It stops at the paired Mac**, which is the one place two designs meet: §5 puts
            // "everything before a paired Mac in a 420pt column, title included", and §2 puts the
            // list itself in a split view whose sidebar is 320. A 420pt cap around a two-column
            // split view would leave the iPad reading its worktrees through a phone-shaped slot.
            .frame(maxWidth: isReadingAPairedMac ? .infinity : ServerDiscoveryView.contentWidth)
            .frame(maxWidth: .infinity)
            // Back out of the worktree list is the only way off it, and it puts the measure back.
            // Watched on the path rather than set by the screen, because the button that performs it
            // is the system's and nothing of ours is told it was pressed.
            .onChange(of: path.isEmpty) { _, isAtTheMacList in
                if isAtTheMacList { isReadingAPairedMac = false }
            }
        }
    }

    /// The camera, made once for the life of the app.
    ///
    /// A `static let` rather than a property, because this scene's body is re-evaluated and the
    /// viewfinder draws *this* scanner's session: a second one built halfway through would put a
    /// preview over a camera nobody is reading. The model pins its own copy in `@State`, so a
    /// second scanner would be exactly that.
    private static let scanner = CaptureSessionCodeScanner()

    /// What only this machine can answer, read once for the same reason.
    private static let phone = ThisPhone(device: thisDevice, cameraSession: scanner.session)

    /// One session per attempt, built around whichever credential the reader offered.
    ///
    /// **The two are not peers and this is where that shows.** A scanned link arrived over a channel
    /// nobody on the network can write to, so its session is pinned before a byte is sent; six words
    /// carry a code and nothing else, so theirs trusts whatever answers and the pairing reads back
    /// what it ended up trusting. See `.claude/docs/decisions.md`.
    private static let handshake: @Sendable (PairingAttempt) -> any ServerPairing = { attempt in
        // Spelled as two branches rather than collapsed into a `??`, and the label is written out
        // rather than left to its default: which side an attempt falls on is the whole of what the
        // two credentials do not share, and it is the one line in this file where getting it wrong
        // would pin nothing and look identical.
        if let pin = attempt.pin {
            HttpServerPairing(mac: attempt, transport: UrlSessionHttpTransport(pinnedTo: pin))
        } else {
            HttpServerPairing(mac: attempt, transport: UrlSessionHttpTransport(trustingFirstAnswer: ()))
        }
    }

    /// How this phone introduces itself, which the Mac renders in its Devices tab.
    private static var thisDevice: PairingDevice {
        #if canImport(UIKit)
        PairingDevice(name: UIDevice.current.name, platform: "iOS")
        #else
        // The package builds for the host so `make test` can run there, and nothing in that build
        // ever pairs. Named for what it is rather than left to look like a device.
        PairingDevice(name: "This Mac", platform: "macOS")
        #endif
    }

    /// The list this product exists for, over a session pinned to the Mac that was just paired
    /// with — which is what makes the pin worth having: the token, the address and the fingerprint
    /// come from the same pairing, so a request cannot leave for a machine nobody vouched for.
    private static func worktrees(of mac: PairedMac) -> ClientWorktreesModel {
        ClientWorktreesModel(
            macName: mac.name,
            repository: repository(of: mac),
            preferences: UserDefaultsWorktreeListPreferences(defaults: .standard),
            now: Date.init
        )
    }

    /// A session that can reach exactly one Mac, which is what makes the pin worth having: the
    /// token, the address and the fingerprint all came from the same pairing, so a request cannot
    /// leave for a machine nobody vouched for.
    private static func repository(of mac: PairedMac) -> HttpGranitaRepository {
        HttpGranitaRepository(mac: mac, transport: UrlSessionHttpTransport(pinnedTo: mac.fingerprint))
    }
}
