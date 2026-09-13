import Testing

import ClientConnectionDomain

@testable import ClientViewerDomain

/// What the bar at the bottom of the diff says, and which control it offers.
///
/// **The control is chosen by the failure rather than offered regardless**, which is design §9's
/// call 6.4 and a safety property rather than a nicety: a revoked pairing makes every later request
/// fail too, so *Try Again* there is a control that cannot work — and with a per-file retry it would
/// have been that dead control drawn five times.
@Suite("Diff batch failure")
struct DiffBatchFailureTests {

    // MARK: - What it says

    @Test
    func `given several files refused when the bar speaks then it counts them and names the Mac's own trouble`() {
        // given
        let bar = DiffBatchFailure(failure: .gitFailure(message: "fatal: unable to read index.lock"), files: ["A.swift", "B.swift", "C.swift", "D.swift", "E.swift"], isRetrying: false, hasBeenTried: false)

        // when - then
        #expect(bar.headline == "Couldn’t read 5 files.")
        #expect(bar.detail == "Your Mac couldn’t read them.")
        #expect(bar.remedy == .tryAgain)
    }

    @Test
    func `given one file refused when the bar speaks then it names the file rather than counting it`() {
        // given — the reader has one blank card, so the sentence tells them which. From two upwards
        // naming them all is a paragraph and naming one of them is arbitrary.
        let bar = DiffBatchFailure(failure: .gitFailure(message: "fatal: bad object"), files: ["ContinuousDiffView.swift"], isRetrying: false, hasBeenTried: false)

        // when - then
        #expect(bar.headline == "Couldn’t read ContinuousDiffView.swift.")
        #expect(bar.detail == "Your Mac couldn’t read it.")
    }

    @Test
    func `given a Mac out of reach when the bar speaks then it says so rather than blaming git`() {
        // given — the reader can do something about a Mac that is asleep or off the network, and
        // nothing at all about a git failure. Two sentences because they lead to two actions.
        let bar = DiffBatchFailure(failure: .unreachable(diagnostic: "NSURLErrorDomain -1004"), files: ["A.swift", "B.swift"], isRetrying: false, hasBeenTried: false)

        // when - then
        #expect(bar.headline == "Couldn’t read 2 files.")
        #expect(bar.detail == "Your Mac is out of reach.")
        #expect(bar.remedy == .tryAgain)
    }

    @Test
    func `given the reader pressed when the bar speaks then it says what it is doing`() {
        // given — the press has to be perceivable in the region it is about, and the control's own
        // slot is taken by the stock indicator while it runs.
        let bar = DiffBatchFailure(failure: .unreachable(diagnostic: "NSURLErrorDomain -1004"), files: ["A.swift", "B.swift", "C.swift", "D.swift", "E.swift"], isRetrying: true, hasBeenTried: true)

        // when - then
        #expect(bar.headline == "Trying 5 files again…")
        #expect(bar.detail == "Your Mac is out of reach.")
    }

    @Test
    func `given one file and a retry running when the bar speaks then it names that file`() {
        // given — the single-file wording holds through the retry, or the bar changes register
        // halfway through one interaction.
        let bar = DiffBatchFailure(failure: .unreachable(diagnostic: "-1004"), files: ["Viewer.swift"], isRetrying: true, hasBeenTried: true)

        // when - then
        #expect(bar.headline == "Trying Viewer.swift again…")
    }

    @Test
    func `given a second refusal when the bar speaks then it stops naming the reason and names the remedy`() {
        // given — the obvious thing has already been tried, so repeating why is worth less than
        // saying what to go and do. This is the whole-screen failure's own sentence, arriving here
        // only on the second attempt.
        let bar = DiffBatchFailure(failure: .unreachable(diagnostic: "-1004"), files: ["A.swift", "B.swift", "C.swift"], isRetrying: false, hasBeenTried: true)

        // when - then
        #expect(bar.headline == "Still couldn’t read them.")
        #expect(bar.detail == "Check that Granita is running on your Mac.")
    }

    @Test
    func `given a second refusal of one file when the bar speaks then it says it rather than them`() {
        // given - when
        let bar = DiffBatchFailure(failure: .unreachable(diagnostic: "-1004"), files: ["Viewer.swift"], isRetrying: false, hasBeenTried: true)

        // then
        #expect(bar.headline == "Still couldn’t read it.")
    }

    // MARK: - Which control

    @Test
    func `given the worktree is gone when the bar speaks then trying again is not what it offers`() {
        // given — nothing on this screen will ever answer again, so a *Try Again* here is a control
        // that cannot work. The only move left is out.
        let bar = DiffBatchFailure(failure: .worktreeGone, files: ["A.swift", "B.swift"], isRetrying: false, hasBeenTried: false)

        // when - then
        #expect(bar.headline == "This worktree is gone.")
        #expect(bar.detail == "It was removed while you were reading it.")
        #expect(bar.remedy == .backToWorktrees)
    }

    @Test
    func `given the pairing was revoked when the bar speaks then it offers pairing rather than retrying`() {
        // given — every later request fails too, so this is the case design §9 names as the reason
        // the bar exists in one place at all.
        let bar = DiffBatchFailure(failure: .unauthorized, files: ["A.swift"], isRetrying: false, hasBeenTried: false)

        // when - then
        #expect(bar.headline == "This iPhone is no longer paired.")
        #expect(bar.detail == "Pair again to keep reading.")
        #expect(bar.remedy == .pairAgain)
    }

    @Test
    func `given a pairing that expired when the bar speaks then it reads as the revoked one does`() {
        // given — the reader can tell no difference and can do nothing different, so two sentences
        // for one situation would be two things to learn.
        let bar = DiffBatchFailure(failure: .pairingExpired, files: ["A.swift"], isRetrying: false, hasBeenTried: false)

        // when - then
        #expect(bar.remedy == .pairAgain)
        #expect(bar.headline == "This iPhone is no longer paired.")
    }

    @Test
    func `given a gone worktree that was already tried when the bar speaks then it keeps its own sentence`() {
        // given — *Still couldn’t read them* is the second attempt of something retryable, and this
        // one was never retryable. Its sentences hold whatever has been pressed.
        let bar = DiffBatchFailure(failure: .worktreeGone, files: ["A.swift"], isRetrying: false, hasBeenTried: true)

        // when - then
        #expect(bar.headline == "This worktree is gone.")
        #expect(bar.detail == "It was removed while you were reading it.")
    }

    @Test
    func `given every other refusal when the bar speaks then it offers a retry over the Mac's own trouble`() {
        // given — the design named four failures and `ApiFailure` has sixteen. The rest fold into
        // the nearest of the four by what the reader can do about them, which is the only axis the
        // bar has: a rate limit, a stale hash and a request this app could not build are all *your
        // Mac would not answer that*, and all of them are worth pressing again.
        let refusals: [ApiFailure] = [
            .rateLimited,
            .projectNotVisible,
            .fileGone,
            .staleContentHash,
            .tooLarge,
            .badRequest(message: "bad"),
            .unsupportedApiVersion,
            .notUnderstood(diagnostic: "…"),
            .worktreeNotDeletable(message: "locked"),
            .cancelled
        ]

        // when - then
        for refusal in refusals {
            let bar = DiffBatchFailure(failure: refusal, files: ["A.swift", "B.swift"], isRetrying: false, hasBeenTried: false)
            #expect(bar.remedy == .tryAgain)
            #expect(bar.detail == "Your Mac couldn’t read them.")
        }
    }

    @Test
    func `given a request this phone could not build when the bar speaks then it reads as unreachable`() {
        // given — an address that will not make a URL is the Mac being unreachable as far as anyone
        // holding the phone is concerned, and it is the one non-network failure whose remedy is the
        // network's.
        let bar = DiffBatchFailure(failure: .requestNotBuildable(diagnostic: "no host"), files: ["A.swift", "B.swift"], isRetrying: false, hasBeenTried: false)

        // when - then
        #expect(bar.detail == "Your Mac is out of reach.")
    }

    // MARK: - What VoiceOver is told

    @Test
    func `given a batch that failed when VoiceOver is told then it says where the control is`() {
        // given — this is the one thing on the screen the reader could not have caused and cannot
        // discover by scrolling, and the control is chrome at the far end of it.
        let bar = DiffBatchFailure(failure: .gitFailure(message: "…"), files: ["A.swift", "B.swift", "C.swift", "D.swift", "E.swift"], isRetrying: false, hasBeenTried: false)

        // when - then
        #expect(bar.announcement == "Couldn’t read 5 files. Try Again is at the bottom of the screen.")
    }

    @Test
    func `given a batch whose remedy is not a retry when VoiceOver is told then it names the control it has`() {
        // given — announcing a button that is not there is the dead control in the one modality
        // where the reader cannot look and check.
        let revoked = DiffBatchFailure(failure: .unauthorized, files: ["A.swift"], isRetrying: false, hasBeenTried: false)
        let gone = DiffBatchFailure(failure: .worktreeGone, files: ["A.swift"], isRetrying: false, hasBeenTried: false)

        // when - then
        #expect(revoked.announcement == "This iPhone is no longer paired. Pair Again is at the bottom of the screen.")
        #expect(gone.announcement == "This worktree is gone. Back to Worktrees is at the bottom of the screen.")
    }
}
