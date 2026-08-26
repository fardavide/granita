import SwiftUI

import ClientConnectionDomain
import CoreBrandingDomain

/// What a spent credential came to: one destination, and a button only where the phone can act.
///
/// **Three of the endings carry no action at all, and that is precisely what makes the other two
/// believable.** Nothing on this phone updates a Mac, and nothing on it shortens a minute of rate
/// limiting, so those screens say what happened and stop.
///
/// Stateless, and it renders `PairingState` rather than only the outcome because two of the things a
/// reader can land here with are not outcomes: the Keychain write being retried, and six typed words
/// that never found an address.
///
/// **Success has no screen.** A `.success` haptic, and the stack replaces the pairing screens with
/// the worktree list titled by the Mac's name — silence reads as nothing having happened only when
/// the destination resembles the origin, and here a frozen viewfinder becomes a populated list.
public struct PairingOutcomeView: View {

    private let macName: String
    private let state: PairingState
    private let canOpenTestFlight: Bool
    private let onTryAgain: () -> Void
    private let onSaveTokenAgain: () -> Void
    private let onOpenTestFlight: () -> Void
    private let onOpenSettings: () -> Void

    /// `canOpenTestFlight` is handed in rather than asked here: whether that URL opens anything is a
    /// question only a device can answer, and asking the system is I/O, which a view does not do.
    ///
    /// Two retries rather than one, because they are not the same act: one re-runs the health probe
    /// and the spend, and the other writes down a token that was already bought.
    public init(
        macName: String,
        state: PairingState,
        canOpenTestFlight: Bool,
        onTryAgain: @escaping () -> Void,
        onSaveTokenAgain: @escaping () -> Void,
        onOpenTestFlight: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.macName = macName
        self.state = state
        self.canOpenTestFlight = canOpenTestFlight
        self.onTryAgain = onTryAgain
        self.onSaveTokenAgain = onSaveTokenAgain
        self.onOpenTestFlight = onOpenTestFlight
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        Group {
            switch state {
            case .finished(.wrongContract(let compatibility)):
                contract(compatibility)
            case .finished(.refused(let failure)):
                refused(failure)
            case .finished(.tokenNotStored(_, let failure)):
                keyNotSaved(failure)
            case .finished(.neverAnswered(let stall)):
                neverAnswered(stall)
            case .notReached(.unreachable(let diagnostic)):
                unreachable(diagnostic: diagnostic)
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
        case .macIsBehind(let serving):
            // No action: nothing on the phone helps, and the fix is on the other machine.
            ContentUnavailableView {
                Label("Your Mac needs a newer Granita", systemImage: "laptopcomputer.and.arrow.down")
            } description: {
                Text(
                    """
                    \(macName) is running an older version than this iPhone can talk to. \
                    Update Granita on the Mac, then pair again. The code was not used.
                    """
                )
            } actions: {
                diagnostic("/v1/health · contract: Mac offers \(serving), this build requires \(Branding.apiVersion)")
            }

        case .phoneIsBehind(let serving):
            ContentUnavailableView {
                Label("This iPhone needs a newer Granita", systemImage: "arrow.down.app")
            } description: {
                Text(
                    """
                    \(macName) is running a newer version than this build can talk to. \
                    Install the latest Granita from TestFlight, then pair again. The code was not used.
                    """
                )
            } actions: {
                // It leaves the app, so it appears only where there is an app to leave for.
                // Absent is a legitimate state, and the sentence above already says what to do.
                if canOpenTestFlight {
                    Button("Open TestFlight", action: onOpenTestFlight)
                        .buttonStyle(.borderedProminent)
                }
                diagnostic("/v1/health · contract: Mac offers \(serving), this build speaks \(Branding.apiVersion)")
            }

        case .sameContract:
            // A mismatch that is not one, which is this app's own bug rather than anything the
            // reader did. It gets the failure idiom and the machine's words rather than a sentence
            // invented for a state nothing can produce.
            couldNotPair(diagnostic: "the Mac and this build agree on the contract, and the handshake refused anyway")
        }
    }

    @ViewBuilder private func refused(_ failure: ApiFailure) -> some View {
        switch failure {
        case .rateLimited:
            // No action, no countdown and no diagnostic: waiting is the whole remedy, and the
            // limiter counts per source address, so the kinder sentence is the true one.
            ContentUnavailableView {
                Label("Too many attempts", systemImage: "clock.badge.exclamationmark")
            } description: {
                Text(
                    """
                    \(macName) has stopped taking pairing codes from this iPhone for a minute. \
                    Wait, then ask your Mac for a new code.
                    """
                )
            }

        case .pairingExpired:
            // One sentence covers expired and never-existed and names neither, because the Mac
            // refuses to say which and this must not invent the distinction back. No action: the
            // remedy is a new code, and that is minted on the other machine.
            ContentUnavailableView {
                Label("That code is no longer valid", systemImage: "clock.badge.xmark")
            } description: {
                Text("On your Mac, choose “Pair a device” for a new one.")
            }

        case .unreachable(let diagnostic):
            unreachable(diagnostic: diagnostic)

        case .unauthorized, .projectNotVisible, .worktreeGone, .fileGone, .staleContentHash,
             .gitFailure, .tooLarge, .badRequest, .unsupportedApiVersion, .requestNotBuildable,
             .notUnderstood:
            // Everything a Mac can answer that is not one of the three above. They share a remedy
            // and a sentence, and what tells them apart is the small print — which is what the
            // small print is for.
            couldNotPair(diagnostic: failure.diagnostic)
        }
    }

    /// The Mac was there a moment ago. Trying again re-runs the health probe and the spend.
    private func unreachable(diagnostic: String) -> some View {
        ContentUnavailableView {
            Label("Could not reach \(macName)", systemImage: "wifi.exclamationmark")
        } description: {
            Text("It was on the network a moment ago but did not answer. Trying again usually works.")
        } actions: {
            Button("Try Again", action: onTryAgain)
                .buttonStyle(.borderedProminent)
            self.diagnostic(diagnostic)
        }
    }

    private func couldNotPair(diagnostic: String?) -> some View {
        ContentUnavailableView {
            Label("Could not pair with \(macName)", systemImage: "exclamationmark.triangle")
        } description: {
            Text(
                """
                Something stopped Granita from pairing with this Mac. Trying again usually works; \
                if it does not, ask your Mac for a new code.
                """
            )
        } actions: {
            Button("Try Again", action: onTryAgain)
                .buttonStyle(.borderedProminent)
            if let diagnostic {
                self.diagnostic(diagnostic)
            }
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
    private func keyNotSaved(_ failure: PairingTokenStoreFailure) -> some View {
        ContentUnavailableView {
            Label("Paired, but the key was not saved", systemImage: "key.slash")
        } description: {
            Text(
                """
                \(macName) now lists this iPhone, but this iPhone could not store the key it was \
                given — so every request it makes will be refused.

                On the Mac, open Granita ▸ Settings ▸ Devices, remove this iPhone, then pair again.
                """
            )
        } actions: {
            Button("Try Again", action: onSaveTokenAgain)
                .buttonStyle(.borderedProminent)
            diagnostic(keychainDiagnostic(failure))
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
                    Granita was checking your Mac and no answer came back. The code was not used, \
                    so trying again costs nothing.
                    """
                )
            } actions: {
                Button("Try Again", action: onTryAgain)
                    .buttonStyle(.borderedProminent)
                diagnostic("/v1/health · no answer, and the step was given the whole of its patience")
            }

        case .spendingTheCode:
            // No action, and the absence is the point: the phone cannot learn whether the Mac took
            // the code, so *Try Again* would offer to spend a credential that may already be gone.
            ContentUnavailableView {
                Label("The code was sent and nothing came back", systemImage: "clock.badge.questionmark")
            } description: {
                Text(
                    """
                    \(macName) took the code and never answered, so Granita cannot tell whether it \
                    was used.

                    On the Mac, open Granita ▸ Settings ▸ Devices. If this iPhone is listed, \
                    remove it — then ask for a new code and pair again.
                    """
                )
            } actions: {
                diagnostic("/v1/pair · no answer, and the step was given the whole of its patience")
            }

        case .writingTheKey:
            // It gets the write on its own for the same reason a refused write does: the token
            // survives in the outcome, and the code that bought it is spent either way.
            ContentUnavailableView {
                Label("Paired, and the key is still not saved", systemImage: "key.slash")
            } description: {
                Text(
                    """
                    \(macName) now lists this iPhone, and the Keychain took the key without ever \
                    saying whether it kept it — so every request this iPhone makes may be refused.

                    Try again. If it does not answer this time either, open Granita ▸ Settings ▸ \
                    Devices on the Mac, remove this iPhone, then pair again.
                    """
                )
            } actions: {
                Button("Try Again", action: onSaveTokenAgain)
                    .buttonStyle(.borderedProminent)
                diagnostic("Keychain · no answer, and the write was given the whole of its patience")
            }
        }
    }

    private var localNetworkDenied: some View {
        ContentUnavailableView {
            Label("Local network access is off", systemImage: "wifi.exclamationmark")
        } description: {
            Text("Granita finds your Mac over the local network. Without permission it cannot see it at all.")
        } actions: {
            Button("Open Settings", action: onOpenSettings)
                .buttonStyle(.borderedProminent)
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

    /// The machine's own words, in the one slot they belong in: small print at the bottom, copyable
    /// into a bug report and unmistakably not instructions. The description slot is ours on every
    /// screen in this app.
    private func diagnostic(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.caption2)
            .monospaced()
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .textSelection(.enabled)
            .padding(.top)
    }

    /// The status code is the whole bug report, and the reader of this app is the developer.
    private func keychainDiagnostic(_ failure: PairingTokenStoreFailure) -> String {
        switch failure {
        case .refused(let status): "Keychain OSStatus \(status)"
        case .unreadable: "Keychain: what is stored for this Mac is not a token"
        }
    }
}
