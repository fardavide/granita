import Foundation
import Testing

import ClientConnectionDomain
import CoreDiffDomain
@testable import ClientViewerDomain

/// What the phone has of a changed picture, and what it still has to ask for.
@Suite("Diff image")
struct DiffImageTests {

    // MARK: - What a changed file becomes

    @Test
    func `given a replaced picture when it is named then both sides are on their way`() throws {
        // given - when
        let image = try #require(DiffImage.awaiting(file(at: "Apps/Snapshots/home.png", status: .modified)))

        // then
        #expect(image.format == .png)
        #expect(image.sides == .both)
        #expect(image.old == .awaiting)
        #expect(image.new == .awaiting)
    }

    @Test
    func `given a picture an agent has just written when it is named then only the working copy is asked for`(
    ) throws {
        // given — untracked, which is the case git never reports as binary and the case this feature
        // exists for: a screenshot test that has just been re-recorded.
        let image = try #require(DiffImage.awaiting(file(at: "Apps/Snapshots/new.png", status: .untracked)))

        // then
        #expect(image.sides == .onlyNew)
        #expect(image.old == nil)
        #expect(image.new == .awaiting)
    }

    @Test
    func `given a deleted picture when it is named then only the committed side is asked for`() throws {
        // given - when
        let image = try #require(DiffImage.awaiting(file(at: "art/old.png", status: .deleted)))

        // then
        #expect(image.sides == .onlyOld)
        #expect(image.old == .awaiting)
        #expect(image.new == nil)
    }

    @Test
    func `given a file that is not a picture when it is named then there is nothing to draw`() {
        // given - when - then — the card falls back to the diff it already had.
        #expect(DiffImage.awaiting(file(at: "Sources/App/main.swift", status: .modified)) == nil)
    }

    // MARK: - Answers landing

    @Test
    func `given a side on its way when its bytes land then that side has them and the other is untouched`(
    ) throws {
        // given
        let image = try #require(DiffImage.awaiting(file(at: "art/logo.png", status: .modified)))
        let bytes = Data([0x89, 0x50, 0x4E, 0x47])

        // when
        let answered = image.replacing(.new, with: .arrived(bytes))

        // then
        #expect(answered.new == .arrived(bytes))
        #expect(answered.old == .awaiting)
    }

    @Test
    func `given a side the file does not have when an answer is written to it then nothing changes`(
    ) throws {
        // given — a card with one frame must not grow a second one because a request nobody should
        // have made came back.
        let image = try #require(DiffImage.awaiting(file(at: "art/new.png", status: .added)))

        // when
        let answered = image.replacing(.old, with: .arrived(Data([0x01])))

        // then
        #expect(answered.old == nil)
        #expect(answered == image)
    }

    @Test
    func `given a refused side when the reader is asked what is left then it is not offered again`(
    ) throws {
        // given — a refused side left the request that failed, and re-asking on the next scroll
        // frame would be a dead Mac asked once per frame.
        let image = try #require(DiffImage.awaiting(file(at: "art/logo.png", status: .modified)))

        // when
        let answered = image
            .replacing(.old, with: .refused(.gitFailure(message: "git exited 128")))
            .replacing(.new, with: .arrived(Data([0x01])))

        // then
        #expect(answered.pending.isEmpty)
    }

    @Test
    func `given a picture nobody has asked for yet when the sides left are read then both are there`(
    ) throws {
        // given - when
        let image = try #require(DiffImage.awaiting(file(at: "art/logo.png", status: .modified)))

        // then — committed first, which is the order the card draws them in.
        #expect(image.pending == [.old, .new])
    }

    @Test
    func `given a replaced picture when the card asks what to draw then it gets two frames in order`(
    ) throws {
        // given
        let image = try #require(DiffImage.awaiting(file(at: "art/logo.png", status: .modified)))
        let bytes = Data([0x89])

        // when
        let frames = image.replacing(.new, with: .arrived(bytes)).frames

        // then — committed first, each carrying its own state, so the card needs no case for a side
        // that does not exist.
        #expect(frames.map(\.side) == [.old, .new])
        #expect(frames.map(\.state) == [.awaiting, .arrived(bytes)])
    }

    @Test
    func `given a one-sided picture when the card asks what to draw then it gets one frame`() throws {
        // given - when
        let image = try #require(DiffImage.awaiting(file(at: "art/gone.png", status: .deleted)))

        // then — two frames with one of them empty is a card claiming the picture failed to arrive.
        #expect(image.frames.map(\.side) == [.old])
    }

    @Test
    func `given a picture spelled with a side it does not have when the card asks then that frame is absent`(
    ) {
        // given — the type can spell it, so the card must not have to draw it: an empty rectangle is
        // indistinguishable from a picture that failed to paint.
        let image = DiffImage(format: .png, sides: .both, old: nil, new: .awaiting)

        // when - then
        #expect(image.frames.map(\.side) == [.new])
    }

    // MARK: - Why a frame is empty

    @Test
    func `given a Mac too old to serve pictures when a frame says why then it names the version`() {
        // given — the release this rule exists for. The two halves ship separately, so a phone
        // newer than its Mac is ordinary, and on a route the older Mac never had the answer is a 404
        // carrying no refusal body — which is exactly `notUnderstood`.
        let failure = ApiFailure.notUnderstood(diagnostic: "the Mac refused with 404")

        // when - then
        #expect(DiffImageRefusal.sentence(for: failure) == "your Mac is too old to send pictures")
        // **And no Try Again.** Pressing re-asks a route that does not exist and fails instantly,
        // which is a control that does nothing under the one label promising it does something.
        #expect(DiffImageRefusal.isWorthRetrying(failure) == false)
    }

    @Test
    func `given a Mac that is merely out of reach when a frame says why then pressing again is offered`() {
        // given — the case that reads identically to the one above on screen unless the frame says
        // which it is, and the two have opposite remedies.
        let failure = ApiFailure.unreachable(diagnostic: "timed out")

        // when - then
        #expect(DiffImageRefusal.sentence(for: failure) == "your Mac is out of reach")
        #expect(DiffImageRefusal.isWorthRetrying(failure))
    }

    @Test
    func `given each way a picture can be refused when a frame says why then every one has words`() {
        // given - when - then — spelled out rather than looped, so a case added to `ApiFailure`
        // fails the switch at compile time and fails here if it is folded in wrongly.
        #expect(DiffImageRefusal.sentence(for: .pairingExpired) == "this device is no longer paired")
        #expect(DiffImageRefusal.sentence(for: .unauthorized) == "this device is no longer paired")
        #expect(DiffImageRefusal.sentence(for: .fileGone) == "this picture is gone")
        #expect(DiffImageRefusal.sentence(for: .worktreeGone) == "this picture is gone")
        #expect(DiffImageRefusal.sentence(for: .tooLarge) == "too big to send")
        #expect(DiffImageRefusal.sentence(for: .gitFailure(message: "exit 128")) == "your Mac couldn’t read it")
        #expect(DiffImageRefusal.sentence(for: .rateLimited) == "your Mac couldn’t read it")
    }

    @Test
    func `given a refusal pressing cannot mend when it is judged then no control is offered`() {
        // given - when - then — the rule is that a control which cannot help is absent rather than
        // disabled, so this is the list that decides whether a button is drawn at all.
        #expect(DiffImageRefusal.isWorthRetrying(.pairingExpired) == false)
        #expect(DiffImageRefusal.isWorthRetrying(.unsupportedApiVersion) == false)
        #expect(DiffImageRefusal.isWorthRetrying(.tooLarge) == false)
        #expect(DiffImageRefusal.isWorthRetrying(.fileGone) == false)
        #expect(DiffImageRefusal.isWorthRetrying(.gitFailure(message: "exit 128")))
        #expect(DiffImageRefusal.isWorthRetrying(.rateLimited))
    }

    // MARK: - What the full screen draws

    @Test
    func `given a picture with both sides when the reader holds it then the other side is drawn`() throws {
        // given
        let image = try #require(DiffImage.awaiting(file(at: "art/logo.png", status: .modified)))

        // when - then
        #expect(image.shownSide(opened: .new, isComparing: true) == .old)
        #expect(image.shownSide(opened: .old, isComparing: true) == .new)
    }

    @Test
    func `given a picture with both sides when nothing is held then the side they opened is drawn`(
    ) throws {
        // given - when - then
        let image = try #require(DiffImage.awaiting(file(at: "art/logo.png", status: .modified)))
        #expect(image.shownSide(opened: .new, isComparing: false) == .new)
    }

    @Test
    func `given a one-sided picture when the reader holds it then nothing swaps`() throws {
        // given — there is nothing to swap to, which is why the hint is absent on this screen: a
        // gesture that does nothing has nowhere to put the explanation.
        let image = try #require(DiffImage.awaiting(file(at: "art/new.png", status: .added)))

        // when - then
        #expect(image.shownSide(opened: .new, isComparing: true) == .new)
    }

    @Test
    func `given a picture when one side is read back by name then it answers for that side alone`(
    ) throws {
        // given
        let image = try #require(DiffImage.awaiting(file(at: "art/logo.png", status: .deleted)))

        // when - then
        #expect(image.side(.old) == .awaiting)
        #expect(image.side(.new) == nil)
    }
}

private func file(at path: String, status: FileStatus) -> FileChange {
    FileChange(
        id: FileID(repositoryRelativePath: path),
        path: path,
        oldPath: nil,
        status: status,
        // Whatever git said: the card decides from the path, so a test that set this to match would
        // be asserting the flag it is the point of this rule to stop reading.
        isBinary: status != .untracked,
        isSubmodule: false,
        stats: ChangeStats(filesChanged: 1, insertions: 0, deletions: 0),
        contentHash: String(repeating: "a", count: 64),
        estimatedLineCount: 0,
        isViewed: false,
        isTruncated: false,
        language: nil
    )
}
