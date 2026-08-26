/// How far an attempt to join a Mac has got, in the vocabulary design §5's four screens are drawn
/// in.
///
/// **Twelve states across four screens, and this is the list of them.** It sits beside
/// `DiscoveryState` rather than inside the model for the same reason that one does: the views that
/// render it are in `Ui`, which may see a `Domain` type and may not see a `Presentation` one.
///
/// The camera's three pre-viewfinder answers are here rather than left as a second property beside
/// this one, because a screen that had to read two enumerations to decide what to draw would have
/// combinations neither of them means — looking, with the camera refused.
public enum PairingState: Hashable, Sendable {

    /// The entry screen: the one sentence in this flow that concerns the other machine, and the two
    /// credentials under it.
    case notStarted

    /// The system alert is up over this, and the reader is deciding. It holds the viewfinder symbol,
    /// one line, and — already — the six-word button, because whichever way they answer, the answer
    /// was behind the alert.
    case waitingForCameraAccess

    /// The reader said no, which is a preference rather than a fault: the six words become the
    /// primary action and *Turn the Camera On in Settings* drops to a plain button beneath them.
    case cameraRefused

    /// Something that is not the reader is holding the camera shut. The same screen as a refusal,
    /// minus the one control that cannot work — under a policy there is no switch behind it.
    case cameraRestricted

    /// The viewfinder is open and the hint is under the reticle.
    case looking

    /// A QR that is not ours, said as a line rather than as an interruption.
    ///
    /// **Transient, and the camera keeps running.** It replaces the hint for two seconds and is
    /// throttled to one appearance in the same two seconds, because a phone drifting over a sticker
    /// on a laptop lid reads one several times a second. It never says *which* code it found:
    /// nothing on this phone reads a stranger's QR back to them.
    case sawSomethingElse

    /// A credential was found and is being spent. The frame is frozen, the preview dims and going
    /// back is refused until the outcome lands — a code that works once must not be abandonable
    /// halfway.
    case spending

    /// The Keychain write is being retried on its own, from the outcome screen.
    ///
    /// It earns a state because that screen gained a button, and with it the moment between the tap
    /// and the answer: without one, a write that fails a second time redraws the screen the reader
    /// was already looking at, which is a control that appears to do nothing.
    case savingToken

    /// The credential was spent and this is what came of it — one destination with five appearances,
    /// three of which carry no action at all.
    case finished(PairingOutcome)

    /// Six typed words with nowhere to send them: the words carry no address, so a Mac that slept
    /// between the browse and the typing ends the attempt before anything is spent.
    ///
    /// It carries the failure rather than a sentence because the two halves do not share a remedy —
    /// one is *Try Again*, and the other is a switch in Settings that no retry will ever flip.
    case notReached(ServerAddressResolutionFailure)

    /// Whether design §5's fourth screen is what the reader should be looking at.
    ///
    /// **Success is not one of them, and that is the whole of why this is a property rather than a
    /// pattern match at the one call site.** A pairing that worked replaces the stack with the
    /// worktree list, so a receipt pushed for it would be a screen about something the reader has
    /// already moved past — and the difference between the two endings that pair and the three that
    /// do not is the sort of thing a screen gets subtly wrong once and nothing catches.
    public var needsTheOutcomeScreen: Bool {
        switch self {
        case .finished(.wrongContract), .finished(.refused), .finished(.tokenNotStored),
             .finished(.neverAnswered), .notReached:
            true
        // Everything before an ending is what the screen the reader is already on is for: the
        // viewfinder draws its own frozen frame while a code is spent, and the outcome screen draws
        // its own spinner while a key is written down.
        case .finished(.paired), .notStarted, .waitingForCameraAccess, .cameraRefused,
             .cameraRestricted, .looking, .sawSomethingElse, .spending, .savingToken:
            false
        }
    }

    /// The Mac to hand to the stack, for the one ending that has no screen of its own.
    ///
    /// **The other half of `needsTheOutcomeScreen`, and it exists because leaving it implicit is
    /// what shipped the defect.** Success is the only ending that has to be *carried* somewhere
    /// rather than drawn, so the question "is there a Mac to hand over" is asked of this vocabulary
    /// rather than pattern-matched at whichever screen happens to be on top — which is a switch that
    /// can be forgotten in one place and written in another, and was.
    ///
    /// Nothing else answers it, including the two endings that carry a `PairedMac` of their own: the
    /// Mac is in their payload so that the *write* can be retried, and a worktree list opened against
    /// a token this phone never stored is a screen where every request is refused.
    public var pairedMac: PairedMac? {
        switch self {
        case .finished(.paired(let mac)):
            mac
        case .finished(.wrongContract), .finished(.refused), .finished(.tokenNotStored),
             .finished(.neverAnswered), .notReached, .notStarted, .waitingForCameraAccess,
             .cameraRefused, .cameraRestricted, .looking, .sawSomethingElse, .spending, .savingToken:
            nil
        }
    }
}
