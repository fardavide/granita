import Testing

import ClientConnectionDomain
import CorePairingDomain

/// Which of the ten states design §5's fourth screen is for.
///
/// Asserted here rather than left to the screen that asks it, because the screen asks it from a
/// closure no test kind this project runs can enter — and the answer decides whether a reader who
/// spent a code is shown what came of it or left looking at a frozen viewfinder.
@Suite("Pairing state")
struct PairingStateTests {

    @Test
    func `given the two ends disagree when the state is read then the outcome is what comes next`() {
        // given - when
        let state = PairingState.finished(.wrongContract(.phoneIsBehind(serving: 9)))

        // then
        #expect(state.needsTheOutcomeScreen)
    }

    @Test
    func `given the Mac refused the code when the state is read then the outcome is what comes next`() {
        // given - when
        let state = PairingState.finished(.refused(.pairingExpired))

        // then
        #expect(state.needsTheOutcomeScreen)
    }

    @Test
    func `given the key could not be written down when the state is read then the outcome is what comes next`() {
        // given — the ending that has to state a fact no other screen states, so it is the last one
        // that could be folded into a state with no screen.
        let state = PairingState.finished(.tokenNotStored(aPairedMac, .refused(status: -25308)))

        // then
        #expect(state.needsTheOutcomeScreen)
    }

    @Test(arguments: [
        ServerAddressResolutionFailure.unreachable(diagnostic: "No such record"),
        .localNetworkDenied
    ])
    func `given six words with nowhere to send them when the state is read then the outcome is what comes next`(
        failure: ServerAddressResolutionFailure
    ) {
        // given - when
        let state = PairingState.notReached(failure)

        // then — both halves, because they do not share a remedy and a screen that showed only one
        // of them would leave the other with no screen at all.
        #expect(state.needsTheOutcomeScreen)
    }

    @Test
    func `given the pairing worked when the state is read then no outcome is shown`() {
        // given — success has no screen. The stack replaces the pairing screens with the worktree
        // list, and a receipt for something the reader has already moved past is the one thing this
        // screen must never be.
        let state = PairingState.finished(.paired(aPairedMac))

        // then
        #expect(state.needsTheOutcomeScreen == false)
    }

    @Test(arguments: [
        PairingState.notStarted,
        .waitingForCameraAccess,
        .cameraRefused,
        .cameraRestricted,
        .looking,
        .sawSomethingElse,
        .spending,
        .savingToken
    ])
    func `given nothing has come back yet when the state is read then no outcome is shown`(
        state: PairingState
    ) {
        // given - when - then — everything before an ending is what the screen the reader is already
        // on is for, and that includes the two waits: a spinner pushed over a spinner says nothing.
        #expect(state.needsTheOutcomeScreen == false)
    }

    @Test(arguments: [
        PairingStall.readingTheContract,
        .spendingTheCode,
        .writingTheKey(aPairedMac)
    ])
    func `given a step that never answered when the state is read then the outcome is what comes next`(
        stall: PairingStall
    ) {
        // given - when
        let state = PairingState.finished(.neverAnswered(stall))

        // then — all three, because the thing this ending replaces is a spinner: an ending that
        // reached the vocabulary and not this predicate would leave the reader exactly where the
        // defect left them. See `.claude/docs/decisions.md`.
        #expect(state.needsTheOutcomeScreen)
    }

    // MARK: - The one ending that is a handover rather than a screen

    @Test
    func `given the pairing worked when the state is read then the Mac is offered to the stack`() {
        // given — success has no screen, so something has to carry it out of this vocabulary, and
        // this is it. **Asserted here because the alternative is asserting it nowhere**: the screens
        // that perform the handover do it from a closure no test kind this project runs can enter.
        let state = PairingState.finished(.paired(aPairedMac))

        // then
        #expect(state.pairedMac == aPairedMac)
    }

    @Test(arguments: [
        PairingState.notStarted,
        .spending,
        .savingToken,
        .finished(.refused(.pairingExpired)),
        .finished(.tokenNotStored(aPairedMac, .refused(status: -25308))),
        .finished(.neverAnswered(.writingTheKey(aPairedMac))),
        .notReached(.localNetworkDenied)
    ])
    func `given anything short of a pairing when the state is read then there is nothing to hand over`(
        state: PairingState
    ) {
        // given - when - then — including the two that carry a `PairedMac` of their own. The Mac is
        // in the payload either way, and handing it to the worktree list would open a list against a
        // token this phone is not holding.
        #expect(state.pairedMac == nil)
    }
}

// MARK: -

private let aPairedMac = PairedMac(
    device: PairedDevice(
        token: PairingToken(rawValue: "1f0e4d7c6b5a49382736251403f2e1d0"),
        deviceId: DeviceId(rawValue: "8C4F2A11-0000-4E5D-9A3B-77F1C0DE0001"),
        serverInstanceId: ServerInstanceId(rawValue: "3B9AC0DE-1111-4A2C-8D6E-55E0B1CAFE22")
    ),
    address: ServerAddress(host: "davides-macbook-pro.local", port: 59_144),
    fingerprint: SpkiFingerprint(rawValue: "cf83e1357eefb8bdf1542850d66d8007")
)
