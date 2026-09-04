import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

import ClientConnectionData
import ClientConnectionDomain
import ClientConnectionPresentation
import ClientViewerData
import ClientViewerPresentation
import ClientViewerUi
import ClientWorktreesData
import ClientWorktreesPresentation

/// Composition root for the phone and the iPad: the one Client target that may see a `Data`
/// target, because wiring implementations into the protocols every other target depends on is
/// its entire job.
///
/// The Xcode target is a thin `@main` shell over this scene, so nothing a test would want to reach
/// lives in the app bundle.
public struct GranitaMobileScene: Scene {

    public init() {}

    public var body: some Scene {
        WindowGroup {
            // The stack, the measure around it and where its two exits lead all belong to
            // `PairingSpineScreen`, and what is left here is the wiring that only a composition root
            // can do: which implementation answers each protocol, and which session each of the two
            // worktree lists speaks over. **The container moved out because it holds a decision** —
            // the measure is released past the pairing spine and not before — and a decision left in
            // a `Main` module is untested code that no longer looks untested. This one was wrong for
            // the route every reader takes and shipped that way; see `.claude/docs/decisions.md`.
            PairingSpineScreen(
                model: ClientConnectionModel(
                    browsing: BonjourServerDiscovery(),
                    joining: MacPairing(macs: Self.rememberedMacStore, handshake: Self.handshake),
                    camera: CaptureDeviceCameraAuthorization(),
                    scanner: Self.scanner,
                    addresses: BonjourServerAddressResolver()
                ),
                phone: Self.phone,
                startingAt: NavigationPath(),
                // A Mac this phone has paired with before looks its address and its key up on the
                // first request, behind the list's own loading state.
                readingARememberedMac: { server in
                    Self.worktrees(
                        of: server.name,
                        over: RememberedMacRepository(reading: server, through: Self.rememberedMacs)
                    )
                },
                // A Mac just paired with brings both in hand.
                readingAJustPairedMac: { mac in
                    Self.worktrees(of: mac.name, over: Self.repository(of: mac))
                }
            )
        }
    }

    /// The camera, made once for the life of the app.
    ///
    /// A `static let` rather than a property, because this scene's body is re-evaluated and the
    /// viewfinder draws *this* scanner's session: a second one built halfway through would put a
    /// preview over a camera nobody is reading. The model pins its own copy in `@State`, so a
    /// second scanner would be exactly that.
    private static let scanner = CaptureSessionCodeScanner()

    /// The one lexer, made once for the life of the app.
    ///
    /// A `static let` for a stronger reason than the camera's: building it evaluates the whole
    /// highlight.js bundle — about 100ms — and its `JSContext` cannot be shared across threads, so
    /// `SPEC.md` §2 asks for exactly one instance per background actor for the app's lifetime. A
    /// second one per worktree would pay that cost every time a reader opened a diff.
    private static let highlighter = HighlightrSyntaxHighlighter()

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

    /// The Keychain, made once, because two of its readers exist: the pairing sequence writes to it
    /// and the reconnection below reads from it, and a store is a fact about this device rather than
    /// about either of them.
    private static let rememberedMacStore = KeychainRememberedMacStore()

    /// **Every Mac this phone can open without pairing, and the one live connection to each** — made
    /// once for the life of the app rather than per screen, which is the whole of what it buys. A
    /// `navigationDestination` closure is re-evaluated on every pass, so a reconnection built inside
    /// one would re-read the Keychain, re-resolve the Bonjour name and open a second `URLSession`
    /// each time; held here, the sidebar and an open diff share one.
    private static let rememberedMacs = RememberedMacs(
        store: rememberedMacStore,
        addresses: BonjourServerAddressResolver(),
        connect: { repository(of: $0) }
    )

    /// The list this product exists for, over a repository that can reach exactly one Mac.
    ///
    /// **Two destinations arrive here and they differ only in that repository**: a Mac just paired
    /// with brings its address and its key in hand, and a remembered one looks both up on its first
    /// request. Everything after that is the same screen, which is why it is written once — the
    /// alternative is two copies of a split view, and the one thing this app has proved it can do is
    /// let two declarations of the same destination drift apart.
    ///
    /// The repository is built by the caller and shared by both screens, so the diff a reader opens
    /// speaks over the session the list was read through rather than opening a second one.
    @ViewBuilder
    private static func worktrees(of macName: String, over repository: any GranitaRepository) -> some View {
        WorktreeSplitScreen(
            model: ClientWorktreesModel(
                macName: macName,
                repository: repository,
                preferences: UserDefaultsWorktreeListPreferences(defaults: .standard),
                now: Date.init
            )
        ) { worktree, displayName, projectName in
            // **The second link in this app whose destination is a module away**, and it is here for
            // the same reason the first is: `ClientWorktreesPresentation` may see any `Domain` and
            // its own `Ui`, never a sibling `Presentation`. The sidebar declares the destination — it
            // has to, because a split view keeps what its own columns declare — and this supplies
            // what it builds. The parameter is required, so the row cannot go quiet the way it did
            // for eight releases; what it opens is the only part that could ever be wrong.
            // **The name arrives with the identifier rather than being resolved here**, and that is
            // 0.1.0's iPad defect not happening twice: this closure runs on every evaluation and
            // each one builds a worktrees model that has read nothing, so a name looked up here
            // would be the fallback word on every worktree there is. The screen that pins the loaded
            // model resolves it.
            WorktreeDiffScreen(
                worktreeName: displayName,
                model: ClientViewerModel(
                    worktree: worktree,
                    worktreeName: displayName,
                    // Resolved beside the display name for the same reason: this closure runs on
                    // every evaluation over a worktrees model that has read nothing, so a name looked
                    // up here would be the fallback word on every worktree there is.
                    projectName: projectName,
                    repository: repository,
                    commentStore: UserDefaultsReviewCommentStore(defaults: .standard),
                    pasteboard: UiKitReviewPasteboard(),
                    // **One lexer for the app, not one per worktree.** Building it loads and
                    // evaluates the whole highlight.js bundle, and its `JSContext` cannot be shared
                    // across threads — so it is an actor held here for the process's lifetime, the
                    // way `SPEC.md` §2's trap paragraph requires.
                    highlighter: highlighter
                )
            )
        }
    }

    /// A session that can reach exactly one Mac, which is what makes the pin worth having: the
    /// token, the address and the fingerprint all came from the same pairing, so a request cannot
    /// leave for a machine nobody vouched for.
    private static func repository(of mac: PairedMac) -> HttpGranitaRepository {
        HttpGranitaRepository(mac: mac, transport: UrlSessionHttpTransport(pinnedTo: mac.fingerprint))
    }
}
