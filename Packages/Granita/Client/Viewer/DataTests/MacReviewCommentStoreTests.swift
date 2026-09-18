import Foundation
import Testing

import ClientConnectionDomain
import ClientViewerData
import ClientViewerDomain
import CoreDiffDomain
import CoreReviewDomain

/// The review on the Mac, with this phone keeping a copy that never waits for it.
///
/// The whole subject here is that saving and pushing are different acts: one is this phone keeping a
/// promise it made when the composer's *Done* returned, the other is the Mac accepting it. A closed
/// laptop is the normal condition, so the first must never depend on the second.
@Suite("Mac review comment store")
struct MacReviewCommentStoreTests {

    @Test
    func `given the Mac is unreachable when a review is saved then it is still kept on this phone`() {
        // given — the case this whole shape exists for. A review is written over as long as it takes
        // to read a change set, and iOS ends a backgrounded app whenever it likes.
        let scenario = Scenario(macFailing: .unreachable(diagnostic: "NWError -65563"))

        // when
        scenario.sut.save([scenario.comment], in: scenario.worktree)

        // then — saved locally and synchronously, with no network in the way of it.
        #expect(scenario.local.comments(in: scenario.worktree) == [scenario.comment])
    }

    @Test
    func `given the Mac is unreachable when a review is pushed then it says how much is unsent`(
    ) async {
        // given
        let scenario = Scenario(macFailing: .unreachable(diagnostic: "NWError -65563"))

        // when
        let sync = await scenario.sut.push([scenario.comment], in: scenario.worktree)

        // then — a count rather than a word, because two of five and five of five are different
        // decisions at the moment the reader is about to paste.
        #expect(sync == .pending(count: 1, of: 1))
    }

    @Test
    func `given a Mac too old for reviews when one is pushed then nothing is queued for it`() async {
        // given — an absent route is a Mac that predates the feature rather than one that refused,
        // and there is no addressee to queue for.
        let scenario = Scenario(macFailing: .routeNotServed)

        // when
        let sync = await scenario.sut.push([scenario.comment], in: scenario.worktree)

        // then
        #expect(sync == .notStorable)
    }

    @Test
    func `given a review on this phone when it is read then no network is involved`() {
        // given — reading goes to the local copy always. Through the network it would put an `await`
        // in front of drawing a diff and a spinner in front of a review already on this device.
        let scenario = Scenario(macFailing: .unreachable(diagnostic: "NWError -65563"))
        scenario.sut.save([scenario.comment], in: scenario.worktree)

        // when - then
        #expect(scenario.sut.comments(in: scenario.worktree) == [scenario.comment])
    }

    @Test
    func `given an empty review refused when it is pushed then it reports the refusal rather than a count`(
    ) async {
        // given — clearing a review is a push of nothing, and "0 of 0 comments are only on this
        // phone" is a sentence about a review that does not exist. The refusal is what a reader can
        // act on.
        let scenario = Scenario(macFailing: .badRequest(message: "the document could not be read"))

        // when
        let sync = await scenario.sut.push([], in: scenario.worktree)

        // then
        #expect(sync == .refused(reason: "the document could not be read"))
    }

    @Test
    func `given the Mac accepts a review when it is pushed then nothing is left to say`() async {
        // given
        let scenario = Scenario()

        // when
        let sync = await scenario.sut.push([scenario.comment], in: scenario.worktree)

        // then — the absence of a sentence is the good state everywhere in this feature.
        #expect(sync == .settled)
        #expect(scenario.mac.received == [[scenario.comment]])
    }

    @Test
    func `given the same worktree reviewed on two devices when reconciled then both halves survive`(
    ) async {
        // given — comments are anchored to different lines, so the union is almost always exactly
        // what the reader wants, and swipe-to-delete is already the control for the rest.
        let scenario = Scenario()
        scenario.sut.save([scenario.comment], in: scenario.worktree)
        scenario.mac.stored = [scenario.otherDevicesComment]

        // when
        let merged = await scenario.sut.reconcile(in: scenario.worktree)

        // then — this phone's first, then what it had not seen, and no mark naming which device
        // wrote which: that would start making this a review with two authors.
        #expect(merged == [scenario.comment, scenario.otherDevicesComment])
    }

    @Test
    func `given a comment both devices hold when reconciled then it is not duplicated`() async {
        // given — the anchor is a comment's identity, which is what makes a second tap on a
        // commented row an edit rather than a second comment. The same rule settles this.
        let scenario = Scenario()
        scenario.sut.save([scenario.comment], in: scenario.worktree)
        scenario.mac.stored = [scenario.comment]

        // when
        let merged = await scenario.sut.reconcile(in: scenario.worktree)

        // then
        #expect(merged == [scenario.comment])
    }

    @Test
    func `given the Mac is unreachable when reconciled then this phone's review is what is left`(
    ) async {
        // given — reconciling is an improvement rather than a precondition, so failing to reach the
        // Mac must leave the reader with everything they wrote rather than with nothing.
        let scenario = Scenario(macFailing: .unreachable(diagnostic: "NWError -65563"))
        scenario.sut.save([scenario.comment], in: scenario.worktree)

        // when
        let merged = await scenario.sut.reconcile(in: scenario.worktree)

        // then
        #expect(merged == [scenario.comment])
    }

    @Test
    func `given a union when it is reconciled then it survives the app being ended`() async {
        // given
        let scenario = Scenario()
        scenario.sut.save([scenario.comment], in: scenario.worktree)
        scenario.mac.stored = [scenario.otherDevicesComment]

        // when
        _ = await scenario.sut.reconcile(in: scenario.worktree)

        // then — kept locally, so the count under the copy button is a count of what is actually in
        // the document rather than of what one reconcile happened to return.
        #expect(scenario.local.comments(in: scenario.worktree).count == 2)
    }

    // MARK: - Scenario

    private struct Scenario {

        let sut: MacReviewCommentStore
        let local: ReviewCommentStore
        let mac: FakeReviewRepository
        let worktree = WorktreeID(canonicalPath: "/repo/slice")

        let comment = ReviewComment(
            anchor: CommentAnchor(
                file: FileID(repositoryRelativePath: "src/a.swift"),
                first: DiffLinePosition(oldNumber: nil, newNumber: 12),
                last: DiffLinePosition(oldNumber: nil, newNumber: 14)
            ),
            path: "src/a.swift",
            lines: CommentedLines(side: .new, first: 12, last: 14),
            language: "swift",
            quotedLines: ["+    let a = 1"],
            text: "This should be a constant."
        )

        /// Anchored somewhere else entirely, which is the ordinary case for two readers.
        let otherDevicesComment = ReviewComment(
            anchor: CommentAnchor(
                file: FileID(repositoryRelativePath: "src/b.swift"),
                first: DiffLinePosition(oldNumber: nil, newNumber: 3),
                last: DiffLinePosition(oldNumber: nil, newNumber: 3)
            ),
            path: "src/b.swift",
            lines: CommentedLines(side: .new, first: 3, last: 3),
            language: "swift",
            quotedLines: ["+    let b = 2"],
            text: "Name this."
        )

        init(macFailing failure: ApiFailure? = nil) {
            let defaults = UserDefaults(suiteName: "granita.tests.\(UUID().uuidString)")!
            local = UserDefaultsReviewCommentStore(defaults: defaults)
            mac = FakeReviewRepository(failing: failure)
            sut = MacReviewCommentStore(local: local, repository: mac)
        }
    }
}
