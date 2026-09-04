import ClientConnectionDomain
import ClientConnectionUi
import SwiftUI
import Testing

/// Every ending a spent credential can have, in every layout it has to survive.
///
/// **The five design §5 tabulates, and ten more that the switch behind them is total over.** The
/// table is a list of the endings a reader is meant to understand; the enumeration is a list of the
/// ones a Mac can produce, and the difference between the two is where a receipt quietly says the
/// wrong thing. So each branch is a subject here, including the three that carry no action at all —
/// which are precisely what make the other two believable, and which no assertion but a picture can
/// tell apart from a screen whose button failed to render.
///
/// Two subjects differ only in the small print, and both are kept: an ending with a diagnostic and
/// one without are the same sentence with a slot filled or empty, and an empty slot that still takes
/// space is the sort of thing only a baseline notices.
///
/// Main-actor isolated, and it must be. Swift Testing runs `@Test` functions off the main actor by
/// default, and rendering touches UIKit view properties — which trap with
/// `_raiseExceptionForBackgroundThreadLayerPropertyModification`. That trap is worse than a plain
/// failure: the crash restarts the test host, and the retry then reports "0 tests passed", so the
/// suite goes green having rendered nothing.
@Suite("Pairing outcome screen", .serialized)
@MainActor
struct PairingOutcomeViewSnapshotTests {

    @Test(arguments: OutcomeCase.all, SnapshotLayout.all)
    func `given an ending when rendering then it matches its baseline`(
        subject: OutcomeCase,
        layout: SnapshotLayout
    ) {
        // given - when - then
        //
        // Clamped outside the navigation container like every screen before a paired Mac: this is
        // the last of the four, and a receipt that spread across an iPad would be the one screen in
        // the flow that left the column.
        assertScreenSnapshot(
            NavigationStack {
                PairingOutcomeView(
                    macName: aMacName,
                    state: subject.state,
                    canOpenTestFlight: subject.canOpenTestFlight,
                    onTryAgain: {},
                    onSaveTokenAgain: {},
                    onOpenTestFlight: {},
                    onOpenSettings: {}
                )
            }
            .frame(maxWidth: ServerDiscoveryView.contentWidth)
            .frame(maxWidth: .infinity),
            layout: layout,
            named: subject.name
        )
    }
}

// MARK: -

/// Named so the baseline filename says which state it captures, and so a failure names it too.
///
/// `canOpenTestFlight` is part of the subject rather than a constant, because it is the only thing
/// in this view that removes a control: on a phone without TestFlight the button is absent and the
/// sentence above it still says what to do, which is this project's own rule about a control that
/// cannot work.
struct OutcomeCase: Sendable, CustomTestStringConvertible {

    let name: String
    let state: PairingState
    let canOpenTestFlight: Bool

    var testDescription: String { name }

    static let all: [OutcomeCase] = [
        // Nothing on the phone helps, so there is no action at all — and the sentence carries the one
        // fact the reader cannot learn anywhere else: the code was not used.
        OutcomeCase(
            name: "mac-behind",
            state: .finished(.wrongContract(.macIsBehind(serving: 0))),
            canOpenTestFlight: false
        ),

        // The same ending from the other side, on a phone that has somewhere to go.
        OutcomeCase(
            name: "phone-behind",
            state: .finished(.wrongContract(.phoneIsBehind(serving: 2))),
            canOpenTestFlight: true
        ),

        // And on one that does not. The button leaves the app, so it appears only where there is an
        // app to leave for — absent rather than dead, which is a layout of its own.
        OutcomeCase(
            name: "phone-behind-without-testflight",
            state: .finished(.wrongContract(.phoneIsBehind(serving: 2))),
            canOpenTestFlight: false
        ),

        // A mismatch that is not one, which is this app's bug rather than anything the reader did. It
        // gets the failure idiom and the machine's words rather than a sentence invented for a state
        // nothing can produce.
        OutcomeCase(
            name: "contract-agreed-and-refused-anyway",
            state: .finished(.wrongContract(.sameContract)),
            canOpenTestFlight: false
        ),

        // Waiting is the whole remedy: no action, no countdown and no diagnostic. The limiter counts
        // per source address, so the sentence names this iPhone rather than the network.
        OutcomeCase(name: "rate-limited", state: .finished(.refused(.rateLimited)), canOpenTestFlight: false),

        // One sentence for expired and never-existed both, naming neither, because the Mac refuses to
        // say which. The remedy is a new code and that is minted on the other machine, so no action.
        OutcomeCase(name: "code-expired", state: .finished(.refused(.pairingExpired)), canOpenTestFlight: false),

        // A refusal the Mac spells deliberately, which carries no small print at all — the state that
        // would otherwise leave an empty caption slot nobody had photographed.
        OutcomeCase(name: "refused-plainly", state: .finished(.refused(.unauthorized)), canOpenTestFlight: false),

        // And one that does carry it. Two lines of it, because that is what a Mac answering something
        // this build cannot read actually produces.
        OutcomeCase(
            name: "refused-with-small-print",
            state: .finished(.refused(.notUnderstood(diagnostic: "POST /v1/pair\nunknown error code: device_quota"))),
            canOpenTestFlight: false
        ),

        // The Mac was there a moment ago. Trying again re-runs the health probe and the spend, which
        // is the one retry on this screen that is a whole attempt.
        OutcomeCase(
            name: "unreachable",
            state: .notReached(.unreachable(diagnostic: "The operation couldn’t be completed.\nNWError -65563")),
            canOpenTestFlight: false
        ),

        // The worst ending there is, and the only screen in this app that asks the reader to repair
        // the other machine. `Try Again` is the write alone and it is the primary action.
        OutcomeCase(
            name: "key-not-saved",
            state: .finished(.tokenNotStored(aPairedMac, .refused(status: -25_308))),
            canOpenTestFlight: false
        ),

        // The same screen with the other Keychain answer under it. The status code is the whole bug
        // report, and this is the branch that has no status code to print.
        OutcomeCase(
            name: "key-not-a-token",
            state: .finished(.tokenNotStored(aPairedMac, .unreadable)),
            canOpenTestFlight: false
        ),

        // Six typed words with nowhere to send them, and *Try Again* would be a dead control in front
        // of a permission that will never grant itself. Design §1 owns these words and this screen
        // borrows them rather than writing a second set — which is only checkable by looking.
        OutcomeCase(name: "local-network-denied", state: .notReached(.localNetworkDenied), canOpenTestFlight: false),

        // The words path spends its code on this screen, so the in-flight frame is one a reader
        // genuinely sits in front of rather than a frame between two others.
        OutcomeCase(name: "spending", state: .spending, canOpenTestFlight: false),

        // The moment the retry button bought. Without a state of its own, a write that fails a second
        // time redraws the screen the reader was already looking at.
        OutcomeCase(name: "saving-the-key", state: .savingToken, canOpenTestFlight: false),

        // Not this screen's state, and what it draws for one is the spinner **without** a sentence: a
        // claim about an attempt that is not running is the one thing a receipt must never make.
        OutcomeCase(name: "before-anything-was-spent", state: .notStarted, canOpenTestFlight: false),

        // The thirteenth state, in the three appearances that are not one screen with a variable in
        // it: what separates them is whether the code left the phone, which is the only fact the
        // reader can act on. Photographed because the sentences are the whole of what they are.
        //
        // Nothing was spent, so this is the one of the three that may offer a retry.
        OutcomeCase(
            name: "never-answered-reading-the-contract",
            state: .finished(.neverAnswered(.readingTheContract)),
            canOpenTestFlight: false
        ),

        // The code left the phone and no answer came back, so no action: the remedy is on the Mac,
        // and a button offering to spend a credential that may already be gone would be worse than
        // none. The longest description on this screen, and the one most likely to crowd 390pt.
        OutcomeCase(
            name: "never-answered-spending-the-code",
            state: .finished(.neverAnswered(.spendingTheCode)),
            canOpenTestFlight: false
        ),

        // Paired for certain, with the write unanswered. It earns the retry that the state above
        // cannot have, because the token survives in the outcome.
        OutcomeCase(
            name: "never-answered-writing-the-key",
            state: .finished(.neverAnswered(.writingTheKey(aPairedMac))),
            canOpenTestFlight: false
        )
    ]
}
