import SwiftUI

import ClientConnectionDomain

/// What a spent credential came to: one destination, and a button only where the phone can act.
///
/// Recovery is offered only where the phone can safely act. Every error can copy local logs without
/// repeating a pairing attempt or a Keychain write.
///
/// Stateless, and it renders `PairingState` rather than only the outcome because two of the things a
/// reader can land here with are not outcomes: the Keychain write being retried, and six typed words
/// that never found an address.
///
/// **Success has no screen.** A `.success` haptic, and the stack replaces the pairing screens with
/// the worktree list titled by the Mac's name — silence reads as nothing having happened only when
/// the destination resembles the origin, and here a frozen viewfinder becomes a populated list.
public struct PairingOutcomeView: View {

    @Environment(\.accessibilityReduceMotion) public var reduceMotion

    private let macName: String
    private let state: PairingState
    private let logCopyState: DiagnosticCopyState
    private let canOpenTestFlight: Bool
    private let onTryAgain: () -> Void
    private let onSaveTokenAgain: () -> Void
    private let onOpenTestFlight: () -> Void
    private let onOpenSettings: () -> Void
    private let onCopyLogs: () -> Void

    /// `canOpenTestFlight` is handed in rather than asked here: whether that URL opens anything is a
    /// question only a device can answer, and asking the system is I/O, which a view does not do.
    ///
    /// Two retries rather than one, because they are not the same act: one re-runs the health probe
    /// and the spend, and the other writes down a token that was already bought.
    public init(
        macName: String,
        state: PairingState,
        logCopyState: DiagnosticCopyState,
        canOpenTestFlight: Bool,
        onTryAgain: @escaping () -> Void,
        onSaveTokenAgain: @escaping () -> Void,
        onOpenTestFlight: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onCopyLogs: @escaping () -> Void
    ) {
        self.macName = macName
        self.state = state
        self.logCopyState = logCopyState
        self.canOpenTestFlight = canOpenTestFlight
        self.onTryAgain = onTryAgain
        self.onSaveTokenAgain = onSaveTokenAgain
        self.onOpenTestFlight = onOpenTestFlight
        self.onOpenSettings = onOpenSettings
        self.onCopyLogs = onCopyLogs
    }

    public var body: some View {
        Group {
            switch state {
            case .finished(.wrongContract(let compatibility)):
                contract(compatibility)
            case .finished(.refused(let failure)):
                refused(failure)
            case .finished(.tokenNotStored):
                keyNotSaved
            case .finished(.neverAnswered(let stall)):
                neverAnswered(stall)
            case .notReached(.unreachable):
                unreachable
            // Six typed words with nowhere to send them, and *Try Again* would be a dead control in
            // front of a permission that will never grant itself. Design §1 owns this state's words
            // and this screen borrows them rather than writing a second set.
            case .notReached(.localNetworkDenied):
                localNetworkDenied
            // Paired, and the stack is being replaced by the worktree list as this draws. The
            // in-flight frame is what shows for that instant, because the one thing this screen must
            // not do is announce a conclusion the flow has already moved past.
            case .spending, .finished(.paired):
                inFlight(
                    title: Text("Pairing with \(macName)"),
                    saying: Text("Checking the Mac, then spending the code.")
                )
            case .savingToken:
                inFlight(title: Text("Saving the key"), saying: Text("Trying the Keychain again."))
            // Not this screen's states. It is pushed by a credential leaving the phone and the model
            // only moves forward, so nothing above the attempt can be handed to it — and what it
            // draws for them is the spinner **without** a sentence, because a claim about an attempt
            // that is not running is the one thing a receipt must never make.
            case .notStarted, .waitingForCameraAccess, .cameraRefused, .cameraRestricted, .looking,
                 .sawSomethingElse:
                ProgressView()
            }
        }
        .navigationTitle(macName)
        .animation(reduceMotion ? nil : .default, value: logCopyState)
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    /// The two ends do not speak the same contract, and **nothing was spent finding that out**.
    ///
    /// That sentence appears twice in this app and nowhere else, because the reader cannot learn it
    /// anywhere else: the handshake reads `/v1/health` before it spends anything, and knowing it is
    /// the difference between walking back to the Mac and simply tapping again.
    @ViewBuilder private func contract(_ compatibility: ApiCompatibility) -> some View {
        switch compatibility {
        case .macIsBehind:
            // No recovery: the update belongs on the other machine.
            ContentUnavailableView {
                Label("Your Mac needs a newer Granita", systemImage: "laptopcomputer.and.arrow.down")
            } description: {
                Text(
                    """
                    Update Granita on \(macName), then pair again. The code was not used.
                    """
                )
            } actions: {
                copyLogs
            }

        case .phoneIsBehind:
            ContentUnavailableView {
                Label("This iPhone needs a newer Granita", systemImage: "arrow.down.app")
            } description: {
                Text(
                    """
                    Install the latest Granita from TestFlight, then pair again. The code was not used.
                    """
                )
            } actions: {
                // It leaves the app, so it appears only where there is an app to leave for.
                // Absent is a legitimate state, and the sentence above already says what to do.
                if canOpenTestFlight {
                    Button("Open TestFlight", action: onOpenTestFlight)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
                copyLogs
            }

        case .sameContract:
            // A mismatch that is not one, which is this app's own bug rather than anything the
            // reader did. It gets the failure idiom and a report, not an invented recovery.
            couldNotPair
        }
    }

    @ViewBuilder private func refused(_ failure: ApiFailure) -> some View {
        switch failure {
        case .rateLimited:
            // No recovery or countdown: waiting is the whole remedy, and the
            // limiter counts per source address, so the kinder sentence is the true one.
            ContentUnavailableView {
                Label("Too many attempts", systemImage: "clock.badge.exclamationmark")
            } description: {
                Text(
                    """
                    Wait a minute, then ask your Mac for a new code.
                    """
                )
            } actions: {
                copyLogs
            }

        case .pairingExpired:
            // One sentence covers expired and never-existed and names neither, because the Mac
            // refuses to say which and this must not invent the distinction back. No recovery: the
            // remedy is a new code, and that is minted on the other machine.
            ContentUnavailableView {
                Label("That code is no longer valid", systemImage: "clock.badge.xmark")
            } description: {
                Text("On your Mac, choose “Pair a device” for a new one.")
            } actions: {
                copyLogs
            }

        case .unreachable:
            unreachable

        case .unauthorized, .projectNotVisible, .worktreeGone, .worktreeNotDeletable, .fileGone,
             .staleContentHash, .gitFailure, .tooLarge, .badRequest, .unsupportedApiVersion,
             .requestNotBuildable, .notUnderstood, .cancelled, .routeNotServed:
            // Everything a Mac can answer that is not one of the three above. They share a remedy
            // and a sentence. The copied report preserves what tells them apart.
            //
            // **`cancelled` is in here rather than given a screen**, and that is deliberate: a
            // pairing is a sequence the reader is watching, so the only way to cancel one is to
            // leave — and a screen nobody is on needs no words. What it must not do is claim the
            // code was spent, so it takes the sentence that offers another attempt.
            couldNotPair
        }
    }

    /// The Mac was there a moment ago. Trying again re-runs the health probe and the spend.
    private var unreachable: some View {
        ContentUnavailableView {
            Label("Could not reach \(macName)", systemImage: "wifi.exclamationmark")
        } description: {
            Text("Check that Granita is running on your Mac, then try again.")
        } actions: {
            Button("Try Again", action: onTryAgain)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            copyLogs
        }
    }

    private var couldNotPair: some View {
        ContentUnavailableView {
            Label("Could not pair with \(macName)", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Try again. If it still fails, ask your Mac for a new code.")
        } actions: {
            Button("Try Again", action: onTryAgain)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            copyLogs
        }
    }

    /// The worst ending there is, and the only screen in this app that asks the reader to repair the
    /// other machine.
    ///
    /// It has to state a fact no other screen states — the Mac now believes this iPhone is paired —
    /// or the advice that follows sounds like superstition. **The retry is the write alone**: the
    /// code that bought this token is spent, so re-running the handshake would ask a Mac to honour a
    /// credential that no longer exists, and `errSecInteractionNotAllowed` is transient far more
    /// often than not. No *Pair Again*, which would leave a second device record beside the orphan.
    private var keyNotSaved: some View {
        ContentUnavailableView {
            Label("Paired, but the key was not saved", systemImage: "key.slash")
        } description: {
            Text(
                """
                \(macName) now lists this iPhone. Try saving the key again first.

                If it still fails, remove this iPhone in Granita ▸ Settings ▸ Devices on the Mac, \
                then pair again.
                """
            )
        } actions: {
            Button("Try Saving Again", action: onSaveTokenAgain)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            copyLogs
        }
    }

    /// A step that took the call and never came back — the thirteenth state, and the one design §5
    /// did not draw because nothing in the flow could produce it until a bound was put under the
    /// sequence.
    ///
    /// **Three sentences rather than one, and the difference between them is whether the code left
    /// the phone.** That is the only fact the reader can act on: before it goes, another tap costs
    /// nothing; after it, the Mac may already list this iPhone and a screen that said "the code was
    /// not used" would be sending them to try a credential that is gone.
    @ViewBuilder private func neverAnswered(_ stall: PairingStall) -> some View {
        switch stall {
        case .readingTheContract:
            // Nothing was spent, so this is the one of the three that may offer a retry — the same
            // sentence and the same button an unreachable Mac gets, because it is the same remedy.
            ContentUnavailableView {
                Label("\(macName) stopped answering", systemImage: "clock.badge.exclamationmark")
            } description: {
                Text(
                    """
                    The code was not used. Try checking your Mac again.
                    """
                )
            } actions: {
                Button("Try Again", action: onTryAgain)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                copyLogs
            }

        case .spendingTheCode:
            // No retry, and the absence is the point: the phone cannot learn whether the Mac took
            // the code, so *Try Again* would offer to spend a credential that may already be gone.
            ContentUnavailableView {
                Label("The code was sent and nothing came back", systemImage: "clock.badge.questionmark")
            } description: {
                Text(
                    """
                    The code may have been used, but \(macName) did not answer.

                    In Granita ▸ Settings ▸ Devices on the Mac, remove this iPhone if listed. \
                    Then ask for a new code and pair again.
                    """
                )
            } actions: {
                copyLogs
            }

        case .writingTheKey:
            // It gets the write on its own for the same reason a refused write does: the token
            // survives in the outcome, and the code that bought it is spent either way.
            ContentUnavailableView {
                Label("Paired, and the key is still not saved", systemImage: "key.slash")
            } description: {
                Text(
                    """
                    \(macName) now lists this iPhone. Saving the key did not finish; try saving it again.

                    If it still fails, remove this iPhone in Granita ▸ Settings ▸ Devices on the Mac, \
                    then pair again.
                    """
                )
            } actions: {
                Button("Try Saving Again", action: onSaveTokenAgain)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                copyLogs
            }
        }
    }

    private var localNetworkDenied: some View {
        ContentUnavailableView {
            Label("Local network access is off", systemImage: "wifi.exclamationmark")
        } description: {
            Text("Allow Local Network access in Settings so Granita can find your Mac.")
        } actions: {
            Button("Open Settings", action: onOpenSettings)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            copyLogs
        }
    }

    /// A spinner is honest here where it would not be over a Bonjour browse: this request finishes.
    private func inFlight(title: Text, saying line: Text) -> some View {
        VStack(spacing: 16) {
            ProgressView()
            VStack(spacing: 4) {
                title
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                line
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var copyLogs: some View {
        VStack(spacing: 8) {
            Button(action: onCopyLogs) {
                switch logCopyState {
                case .ready: Text("Copy Logs")
                case .copying: Text("Copying Logs…")
                case .copied: Text("Copy Logs Again")
                case .failed: Text("Try Copying Again")
                }
            }
            .buttonStyle(.borderless)
            .controlSize(.large)
            .disabled(logCopyState == .copying)

            switch logCopyState {
            case .ready, .copying:
                EmptyView()
            case .copied:
                Text("Logs copied. Paste them into your message.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .failed:
                Text("Couldn’t copy logs. Please try again.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
    }
}
