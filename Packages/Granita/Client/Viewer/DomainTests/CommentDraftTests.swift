import Testing

import CoreDiffDomain

@testable import ClientViewerDomain

/// Tap, long press, tap — design §7.1's gesture, as the three states it actually is.
///
/// **It is a state machine and not a pair of closures on a view**, which is the rule this repository
/// applies to every gesture that decides something: a `Ui` view reports what happened and something a
/// test can reach decides what it meant. What it decides here is genuinely hard — a held row that
/// scrolling must not cancel, a second tap that may land above the first or in another file, and a
/// held state that no iOS convention explains and that therefore needs a way out.
///
/// **The two ends stay in the order they were touched.** Putting them in the order they are drawn
/// needs the diff, because a deletion carries only an old number and an addition only a new one — see
/// `CommentSelection.ends(of:from:to:)`, which is where an anchor becomes an identity.
@Suite("Comment draft")
struct CommentDraftTests {

    // MARK: - A plain tap

    @Test
    func `given nothing held when a row is tapped then the composer opens on that row alone`() {
        // given
        let draft = CommentDraft.idle

        // when
        let next = draft.tapped(aRow(11), in: aFile)

        // then — one row is a run of one, so everything downstream has one shape to handle.
        #expect(next == .composing(PendingComment(file: aFile, from: aRow(11), to: aRow(11))))
    }

    @Test
    func `given nothing held when a row is long pressed then it is held and nothing is composed`() {
        // given
        let draft = CommentDraft.idle

        // when
        let next = draft.longPressed(aRow(11), in: aFile)

        // then
        #expect(next == .holding(file: aFile, end: aRow(11)))
    }

    // MARK: - The second tap

    @Test
    func `given a held row when another is tapped then the run reaches from one to the other`() {
        // given
        let draft = CommentDraft.holding(file: aFile, end: aRow(11))

        // when
        let next = draft.tapped(aRow(14), in: aFile)

        // then
        #expect(next == .composing(PendingComment(file: aFile, from: aRow(11), to: aRow(14))))
    }

    @Test
    func `given a held row when a row above is tapped then both ends are kept as they were touched`() {
        // given — a reader holds a row and then reaches upwards for its other end, which the gesture
        // cannot forbid.
        let draft = CommentDraft.holding(file: aFile, end: aRow(14))

        // when
        let next = draft.tapped(aRow(11), in: aFile)

        // then — unordered on purpose. Ordering needs the diff, and doing it twice in two places is
        // how two spellings of one run become two comments on it.
        #expect(next == .composing(PendingComment(file: aFile, from: aRow(14), to: aRow(11))))
    }

    @Test
    func `given a held row when the same row is tapped again then the run is that row alone`() {
        // given — the reader changed their mind about extending. It has to mean something, and the
        // only thing it can mean is the row they are still touching.
        let draft = CommentDraft.holding(file: aFile, end: aRow(11))

        // when
        let next = draft.tapped(aRow(11), in: aFile)

        // then
        #expect(next == .composing(PendingComment(file: aFile, from: aRow(11), to: aRow(11))))
    }

    @Test
    func `given a held row when a row in another file is tapped then the hold is abandoned for it`() {
        // given — a run cannot cross a file, and the next file is a few points down the same scroll.
        // Refusing outright would leave the reader holding a row that a tap appeared to do nothing
        // to, which is the dead control this project will not ship.
        let draft = CommentDraft.holding(file: aFile, end: aRow(11))

        // when
        let next = draft.tapped(aRow(4), in: anotherFile)

        // then
        #expect(next == .composing(PendingComment(file: anotherFile, from: aRow(4), to: aRow(4))))
    }

    @Test
    func `given a row is held when another is long pressed then the newer hold replaces it`() {
        // given
        let draft = CommentDraft.holding(file: aFile, end: aRow(11))

        // when
        let next = draft.longPressed(aRow(20), in: aFile)

        // then
        #expect(next == .holding(file: aFile, end: aRow(20)))
    }

    // MARK: - Getting out

    @Test
    func `given a held row when it is cancelled then nothing is held`() {
        // given — the escape hatch design §7.1 puts in the instruction bar, because a held row is a
        // state no iOS convention explains and every pixel of the scroll behind it is code.
        let draft = CommentDraft.holding(file: aFile, end: aRow(11))

        // when - then
        #expect(draft.cancelled() == .idle)
    }

    @Test
    func `given a composer is open when it is cancelled then nothing is held`() {
        // given
        let draft = CommentDraft.composing(PendingComment(file: aFile, from: aRow(11), to: aRow(14)))

        // when - then
        #expect(draft.cancelled() == .idle)
    }

    @Test
    func `given nothing held when it is cancelled then nothing happens`() {
        // given - when - then
        #expect(CommentDraft.idle.cancelled() == .idle)
    }

    @Test
    func `given a composer is open when the gutter is touched then the composer stands`() {
        // given — unreachable while the sheet is up, because the diff behind it takes no gestures at
        // the composer's own detent. Answered rather than assumed: a touch that quietly replaced an
        // open composer would discard a paragraph without asking.
        let composing = CommentDraft.composing(PendingComment(file: aFile, from: aRow(11), to: aRow(14)))

        // when - then
        #expect(composing.longPressed(aRow(20), in: aFile) == composing)
        #expect(composing.tapped(aRow(20), in: aFile) == composing)
    }

    // MARK: - What the screen reads off it

    @Test
    func `given a held row when the screen asks then it has an end and no pending run`() {
        // given
        let draft = CommentDraft.holding(file: aFile, end: aRow(11))

        // when - then
        #expect(draft.heldEnd == aRow(11))
        #expect(draft.pending == nil)
    }

    @Test
    func `given a composer is open when the screen asks then it has a run and nothing held`() {
        // given — the bar and the capsule share one position on screen and can never both be true,
        // which is what design §7.4 spends to keep the capsule out of a toolbar that hides on scroll.
        let pending = PendingComment(file: aFile, from: aRow(11), to: aRow(14))

        // when - then
        #expect(CommentDraft.composing(pending).heldEnd == nil)
        #expect(CommentDraft.composing(pending).pending == pending)
    }

    @Test
    func `given nothing held when the screen asks then both are absent`() {
        // given - when - then
        #expect(CommentDraft.idle.heldEnd == nil)
        #expect(CommentDraft.idle.pending == nil)
    }
}

// MARK: -

private let aFile = FileID(rawValue: "the-one-being-read")
private let anotherFile = FileID(rawValue: "the-next-one-down")

private func aRow(_ number: Int) -> DiffLinePosition {
    DiffLinePosition(oldNumber: nil, newNumber: number)
}
