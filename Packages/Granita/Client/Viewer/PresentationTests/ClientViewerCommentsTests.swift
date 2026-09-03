import Testing

import ClientConnectionDomain
import ClientViewerDomain
import CoreDiffDomain

@testable import ClientViewerPresentation

/// The review half of the viewer's model: what the reader wrote down, where it is kept, and the one
/// piece of text it becomes.
///
/// The rules themselves are asserted a layer down, over pure functions — `CommentSelection` decides
/// what a pair of ends covers and `ReviewFeedback` decides how it reads. What is left here is
/// whether the model spends them correctly: against a file whose diff is in hand, in the scroll's
/// order, written through to the store on every change, and refusing rather than silently dropping
/// a comment it cannot attach.
@Suite("Client viewer comments")
@MainActor
struct ClientViewerCommentsTests {

    // MARK: - Writing one down

    @Test
    func `given a file whose diff arrived when a comment is written then it is held and stored`() async {
        // given
        let scenario = Scenario()
        await scenario.load()

        // when
        scenario.sut.comment(
            on: FileID(rawValue: "file-0"),
            from: DiffLinePosition(oldNumber: nil, newNumber: 2),
            to: DiffLinePosition(oldNumber: nil, newNumber: 2),
            saying: "This wants a name."
        )

        // then — held for the screen and written through in the same gesture, because a review lost
        // to a phone call is an afternoon lost.
        #expect(scenario.sut.comments.map(\.text) == ["This wants a name."])
        #expect(scenario.store.saved.map(\.text) == ["This wants a name."])
    }

    @Test
    func `given a comment on a run of lines when it is written then it carries the path and the span`() async {
        // given
        let scenario = Scenario()
        await scenario.load()

        // when
        scenario.sut.comment(
            on: FileID(rawValue: "file-0"),
            from: DiffLinePosition(oldNumber: 1, newNumber: 1),
            to: DiffLinePosition(oldNumber: nil, newNumber: 2),
            saying: "Pull this out."
        )

        // then
        #expect(scenario.sut.comments.first?.path == "Sources/File0.swift")
        #expect(scenario.sut.comments.first?.lines == CommentedLines(side: .new, first: 1, last: 2))
    }

    @Test
    func `given a comment on a run when a second is written on the same run then it replaces the first`() async {
        // given — the reader tapped a commented line again, which is how a comment is edited. A
        // review is a note for an agent rather than a thread, so two notes on one span would be one
        // thing to read written twice.
        let scenario = Scenario()
        await scenario.load()
        scenario.sut.comment(
            on: FileID(rawValue: "file-0"),
            from: DiffLinePosition(oldNumber: nil, newNumber: 2),
            to: DiffLinePosition(oldNumber: nil, newNumber: 2),
            saying: "First thought."
        )

        // when
        scenario.sut.comment(
            on: FileID(rawValue: "file-0"),
            from: DiffLinePosition(oldNumber: nil, newNumber: 2),
            to: DiffLinePosition(oldNumber: nil, newNumber: 2),
            saying: "Second thought."
        )

        // then
        #expect(scenario.sut.comments.map(\.text) == ["Second thought."])
    }

    @Test
    func `given comments written out of order when they are read back then they follow the scroll`() async {
        // given
        let scenario = Scenario()
        await scenario.load()

        // when — the second file first, which is how a reader who scrolls back works.
        scenario.sut.comment(
            on: FileID(rawValue: "file-1"),
            from: DiffLinePosition(oldNumber: nil, newNumber: 2),
            to: DiffLinePosition(oldNumber: nil, newNumber: 2),
            saying: "Second file."
        )
        scenario.sut.comment(
            on: FileID(rawValue: "file-0"),
            from: DiffLinePosition(oldNumber: nil, newNumber: 2),
            to: DiffLinePosition(oldNumber: nil, newNumber: 2),
            saying: "First file."
        )

        // then — the list on screen and the document that gets copied are one order, decided once.
        #expect(scenario.sut.comments.map(\.text) == ["First file.", "Second file."])
        #expect(scenario.store.saved.map(\.text) == ["First file.", "Second file."])
    }

    // MARK: - The comment that cannot be attached

    @Test
    func `given lines that are not in the diff when a comment is written then the reader is told`() async {
        // given — the ends address rows the screen drew, so reaching this means the diff moved under
        // an open composer. Rare, and answered rather than swallowed: a paragraph typed and lost
        // without a word is the worst version of a control that did nothing.
        let scenario = Scenario()
        await scenario.load()

        // when
        scenario.sut.comment(
            on: FileID(rawValue: "file-0"),
            from: DiffLinePosition(oldNumber: nil, newNumber: 900),
            to: DiffLinePosition(oldNumber: nil, newNumber: 901),
            saying: "Nowhere to put this."
        )

        // then
        #expect(scenario.sut.commentFailure)
        #expect(scenario.sut.comments.isEmpty)
    }

    @Test
    func `given a file whose diff has not arrived when a comment is written then the reader is told`() async {
        // given — nothing on screen to have tapped, since a file that is awaiting has drawn no rows.
        let scenario = Scenario()
        await scenario.load()

        // when — the eighth file, which is beyond the first batch.
        scenario.sut.comment(
            on: FileID(rawValue: "file-7"),
            from: DiffLinePosition(oldNumber: nil, newNumber: 2),
            to: DiffLinePosition(oldNumber: nil, newNumber: 2),
            saying: "Nowhere to put this either."
        )

        // then
        #expect(scenario.sut.commentFailure)
        #expect(scenario.sut.comments.isEmpty)
    }

    @Test
    func `given the reader was told when the refusal is dismissed then it goes`() async {
        // given
        let scenario = Scenario()
        await scenario.load()
        scenario.sut.comment(
            on: FileID(rawValue: "file-0"),
            from: DiffLinePosition(oldNumber: nil, newNumber: 900),
            to: DiffLinePosition(oldNumber: nil, newNumber: 900),
            saying: "Nowhere."
        )

        // when
        scenario.sut.dismissCommentFailure()

        // then
        #expect(scenario.sut.commentFailure == false)
    }

    // MARK: - Taking them back

    @Test
    func `given two comments when one is removed then the other stays and the store agrees`() async {
        // given
        let scenario = Scenario()
        await scenario.load()
        scenario.sut.comment(
            on: FileID(rawValue: "file-0"),
            from: DiffLinePosition(oldNumber: nil, newNumber: 2),
            to: DiffLinePosition(oldNumber: nil, newNumber: 2),
            saying: "Keep me."
        )
        scenario.sut.comment(
            on: FileID(rawValue: "file-1"),
            from: DiffLinePosition(oldNumber: nil, newNumber: 2),
            to: DiffLinePosition(oldNumber: nil, newNumber: 2),
            saying: "Drop me."
        )

        // when
        guard let dropped = scenario.sut.comments.first(where: { $0.text == "Drop me." })?.anchor else {
            Issue.record("the comment that was just written has to be findable")
            return
        }
        scenario.sut.removeComment(dropped)

        // then
        #expect(scenario.sut.comments.map(\.text) == ["Keep me."])
        #expect(scenario.store.saved.map(\.text) == ["Keep me."])
    }

    @Test
    func `given a review when it is cleared then nothing is left anywhere`() async {
        // given — this is the gesture the screen offers after the document has been copied, and the
        // pasteboard is the only other copy there is.
        let scenario = Scenario()
        await scenario.load()
        scenario.sut.comment(
            on: FileID(rawValue: "file-0"),
            from: DiffLinePosition(oldNumber: nil, newNumber: 2),
            to: DiffLinePosition(oldNumber: nil, newNumber: 2),
            saying: "Sent already."
        )

        // when
        scenario.sut.clearComments()

        // then
        #expect(scenario.sut.comments.isEmpty)
        #expect(scenario.store.saved.isEmpty)
    }

    // MARK: - What was left from last time

    @Test
    func `given a review was written before when the model is built then it is already holding it`() {
        // given - when — before any read, because a review outlives the change set that produced it
        // and a phone is backgrounded mid-review far more often than a Mac refuses a request.
        let scenario = Scenario(holding: [aStoredComment(on: "file-1", at: 9, saying: "From yesterday.")])

        // then
        #expect(scenario.sut.comments.map(\.text) == ["From yesterday."])
    }

    @Test
    func `given a stored review out of order when the change set arrives then it is put in the scroll's order`() async {
        // given — the store keeps what it was handed, and what it was handed came from a change set
        // whose order the model has not read yet.
        let scenario = Scenario(holding: [
            aStoredComment(on: "file-2", at: 9, saying: "Third."),
            aStoredComment(on: "file-0", at: 4, saying: "First.")
        ])

        // when
        await scenario.load()

        // then
        #expect(scenario.sut.comments.map(\.text) == ["First.", "Third."])
    }

    // MARK: - The document

    @Test
    func `given a review and a note when the feedback is asked for then both are in it under the worktree's name`() async {
        // given
        let scenario = Scenario()
        await scenario.load()
        scenario.sut.comment(
            on: FileID(rawValue: "file-0"),
            from: DiffLinePosition(oldNumber: nil, newNumber: 2),
            to: DiffLinePosition(oldNumber: nil, newNumber: 2),
            saying: "This wants a name."
        )

        // when
        let document = scenario.sut.feedback(note: "Two small things.")

        // then
        #expect(document == """
            Review of uncommitted changes — granita, worktree TLS pinning, 8 files

            Two small things.

            Sources/File0.swift:2
            > let question = 6 * 9
            This wants a name.
            """)
    }

    @Test
    func `given the note was skipped when the feedback is asked for then nothing stands in for it`() async {
        // given
        let scenario = Scenario()
        await scenario.load()
        scenario.sut.comment(
            on: FileID(rawValue: "file-0"),
            from: DiffLinePosition(oldNumber: nil, newNumber: 2),
            to: DiffLinePosition(oldNumber: nil, newNumber: 2),
            saying: "One thing."
        )

        // when
        let document = scenario.sut.feedback(note: nil)

        // then
        #expect(document.contains("worktree TLS pinning, 8 files\n\nSources/File0.swift:2"))
    }

    // MARK: - The gesture, and what it opens

    @Test
    func `given a diff on screen when the gutter is tapped then the composer opens on that row`() async {
        // given
        let scenario = Scenario()
        await scenario.load()

        // when
        scenario.sut.tappedGutter(anAddition, in: FileID(rawValue: "file-0"))

        // then
        #expect(scenario.sut.sheet == .composer)
        #expect(scenario.sut.composerAnchorLabel == "File0.swift:2")
        #expect(scenario.sut.composerExcerpt == ["let question = 6 * 9"])
        #expect(scenario.sut.composerText.isEmpty)
        #expect(scenario.sut.editingComment == nil)
    }

    @Test
    func `given the file list is up when the gutter is tapped then the composer replaces it`() async {
        // given — design §7.2: one is a list of places to go and the other is a keyboard, so they are
        // mutually exclusive. There is one sheet, which is what makes that a type rather than a rule.
        let scenario = Scenario()
        await scenario.load()
        scenario.sut.showSelector(true)

        // when
        scenario.sut.tappedGutter(anAddition, in: FileID(rawValue: "file-0"))

        // then
        #expect(scenario.sut.sheet == .composer)
    }

    @Test
    func `given a row is long pressed when the screen is read then it is held and no sheet is up`() async {
        // given — what the reader has done is pick one end. The bar over the diff is what says so.
        let scenario = Scenario()
        await scenario.load()

        // when
        scenario.sut.longPressedGutter(aContextRow, in: FileID(rawValue: "file-0"))

        // then
        #expect(scenario.sut.sheet == nil)
        #expect(scenario.sut.draft.heldEnd == aContextRow)
        #expect(scenario.sut.heldRowLabel == "File0.swift:1")
    }

    @Test
    func `given a row is held when a second is tapped then the composer opens on the run`() async {
        // given
        let scenario = Scenario()
        await scenario.load()
        scenario.sut.longPressedGutter(aContextRow, in: FileID(rawValue: "file-0"))

        // when
        scenario.sut.tappedGutter(anAddition, in: FileID(rawValue: "file-0"))

        // then
        #expect(scenario.sut.composerAnchorLabel == "File0.swift:1-2")
        #expect(scenario.sut.composerExcerpt == ["let answer = 42", "let question = 6 * 9"])
    }

    @Test
    func `given the composer is open when the gutter behind it is tapped then what was typed stands`() async {
        // given — **reachable, which is why this is a test rather than a comment.** The composer's
        // own detent enables background interaction so the reader can scroll the diff behind it and
        // check the caller they are about to complain about; that also means a thumb can land on the
        // gutter while the sheet is up. Before this guard, such a tap left the composer open on the
        // same rows and emptied the field — three sentences gone, and nothing to say why.
        let scenario = Scenario()
        await scenario.load()
        scenario.sut.tappedGutter(anAddition, in: FileID(rawValue: "file-0"))
        scenario.sut.composerText = "Three sentences about this line."

        // when
        scenario.sut.tappedGutter(aContextRow, in: FileID(rawValue: "file-0"))

        // then — the run does not move and the words do not go.
        #expect(scenario.sut.composerText == "Three sentences about this line.")
        #expect(scenario.sut.composerAnchorLabel == "File0.swift:2")
    }

    @Test
    func `given a row is held when the draft is cancelled then nothing is held and no sheet opens`() async {
        // given — the instruction bar's Cancel, which is the escape hatch a held row needs.
        let scenario = Scenario()
        await scenario.load()
        scenario.sut.longPressedGutter(aContextRow, in: FileID(rawValue: "file-0"))

        // when
        scenario.sut.cancelDraft()

        // then
        #expect(scenario.sut.draft == .idle)
        #expect(scenario.sut.sheet == nil)
    }

    @Test
    func `given the composer is open when the sheet is dismissed then the run is let go`() async {
        // given — a sheet dragged away rather than cancelled would otherwise leave a run picked out
        // with nothing on screen saying so, and the next tap would extend a selection the reader had
        // already abandoned.
        let scenario = Scenario()
        await scenario.load()
        scenario.sut.tappedGutter(anAddition, in: FileID(rawValue: "file-0"))

        // when
        scenario.sut.dismissSheet()

        // then
        #expect(scenario.sut.draft == .idle)
        #expect(scenario.sut.sheet == nil)
    }

    // MARK: - Writing through the composer

    @Test
    func `given the composer is open when it is saved then the comment is written and the sheet goes`() async {
        // given
        let scenario = Scenario()
        await scenario.load()
        scenario.sut.tappedGutter(anAddition, in: FileID(rawValue: "file-0"))
        scenario.sut.composerText = "This wants a name."

        // when
        scenario.sut.saveComment()

        // then
        #expect(scenario.sut.comments.map(\.text) == ["This wants a name."])
        #expect(scenario.store.saved.map(\.text) == ["This wants a name."])
        #expect(scenario.sut.sheet == nil)
        #expect(scenario.sut.draft == .idle)
    }

    @Test
    func `given the composer is empty when it is saved then nothing is written`() async {
        // given — a reader who opened it and thought better of it. A comment with no words is a rail
        // in the gutter and a line in the document saying nothing.
        let scenario = Scenario()
        await scenario.load()
        scenario.sut.tappedGutter(anAddition, in: FileID(rawValue: "file-0"))
        scenario.sut.composerText = "   \n "

        // when
        scenario.sut.saveComment()

        // then
        #expect(scenario.sut.comments.isEmpty)
        #expect(scenario.sut.sheet == nil)
    }

    @Test
    func `given a commented row when it is tapped again then the composer holds what was written`() async {
        // given — design §7.1: a single tap on a rail opens that comment for editing. No long press,
        // no menu.
        let scenario = Scenario()
        await scenario.load()
        scenario.sut.tappedGutter(anAddition, in: FileID(rawValue: "file-0"))
        scenario.sut.composerText = "First thought."
        scenario.sut.saveComment()

        // when
        scenario.sut.tappedGutter(anAddition, in: FileID(rawValue: "file-0"))

        // then
        #expect(scenario.sut.composerText == "First thought.")
        #expect(scenario.sut.editingComment?.text == "First thought.")
    }

    @Test
    func `given a run held upwards when it is saved then it is the same comment as one held downwards`() async {
        // given — the ends are recorded in the order the reader's thumb touched them and ordered
        // against the diff, which is what stops one run becoming two comments.
        let scenario = Scenario()
        await scenario.load()
        scenario.sut.longPressedGutter(anAddition, in: FileID(rawValue: "file-0"))
        scenario.sut.tappedGutter(aContextRow, in: FileID(rawValue: "file-0"))
        scenario.sut.composerText = "Upwards."
        scenario.sut.saveComment()

        // when — the same run, picked out the other way round.
        scenario.sut.longPressedGutter(aContextRow, in: FileID(rawValue: "file-0"))
        scenario.sut.tappedGutter(anAddition, in: FileID(rawValue: "file-0"))
        scenario.sut.composerText = "Downwards."
        scenario.sut.saveComment()

        // then — one comment, edited.
        #expect(scenario.sut.comments.map(\.text) == ["Downwards."])
    }

    @Test
    func `given a comment is open in the composer when it is deleted then it goes`() async {
        // given
        let scenario = Scenario()
        await scenario.load()
        scenario.sut.tappedGutter(anAddition, in: FileID(rawValue: "file-0"))
        scenario.sut.composerText = "Never mind."
        scenario.sut.saveComment()
        scenario.sut.tappedGutter(anAddition, in: FileID(rawValue: "file-0"))

        // when
        scenario.sut.deleteComposedComment()

        // then
        #expect(scenario.sut.comments.isEmpty)
        #expect(scenario.sut.sheet == nil)
    }

    @Test
    func `given a new comment when delete is reached for then there is nothing to delete`() async {
        // given — the composer draws no Delete row for a comment that does not exist yet, so this is
        // unreachable from the screen. Answered rather than assumed.
        let scenario = Scenario()
        await scenario.load()
        scenario.sut.tappedGutter(anAddition, in: FileID(rawValue: "file-0"))

        // when
        scenario.sut.deleteComposedComment()

        // then
        #expect(scenario.sut.sheet == .composer)
    }

    @Test
    func `given nothing is being composed when a save is attempted then nothing happens`() async {
        // given — unreachable while no sheet is up, and answered because `saveComment` is public.
        let scenario = Scenario()
        await scenario.load()

        // when
        scenario.sut.saveComment()

        // then
        #expect(scenario.sut.comments.isEmpty)
    }

    // MARK: - The review, the copy, and the clear

    @Test
    func `given comments exist when the review is opened then that is the sheet`() async {
        // given
        let scenario = Scenario()
        await scenario.load()

        // when
        scenario.sut.showReview()

        // then
        #expect(scenario.sut.sheet == .review)
    }

    @Test
    func `given a review when it is copied then the document reaches the pasteboard`() async {
        // given
        let scenario = Scenario()
        await scenario.load()
        scenario.sut.tappedGutter(anAddition, in: FileID(rawValue: "file-0"))
        scenario.sut.composerText = "This wants a name."
        scenario.sut.saveComment()
        scenario.sut.noteDraft = "Two small things."

        // when
        scenario.sut.copyReview()

        // then — the string the reader is about to paste, built by the one function asserted to the
        // byte and handed to the one seam that leaves this app.
        #expect(scenario.pasteboard.copied == scenario.sut.feedback(note: "Two small things."))
        #expect(scenario.pasteboard.copied?.contains("This wants a name.") == true)
    }

    @Test
    func `given a review that has not been copied when the screen asks then clearing is not offered`() async {
        // given — design §7.6's sequencing, and it is a safety property: the pasteboard is the only
        // other copy there is, so a control that could destroy the review before it had been pasted
        // can destroy an afternoon.
        let scenario = Scenario()
        await scenario.load()

        // when - then
        #expect(scenario.sut.hasCopied == false)
    }

    @Test
    func `given a review that was copied when it is cleared then the screen goes back to a first run`() async {
        // given
        let scenario = Scenario()
        await scenario.load()
        scenario.sut.tappedGutter(anAddition, in: FileID(rawValue: "file-0"))
        scenario.sut.composerText = "Sent already."
        scenario.sut.saveComment()
        scenario.sut.noteDraft = "And a note."
        scenario.sut.showReview()
        scenario.sut.copyReview()

        // when
        scenario.sut.clearComments()

        // then
        #expect(scenario.sut.comments.isEmpty)
        #expect(scenario.store.saved.isEmpty)
        #expect(scenario.sut.noteDraft.isEmpty)
        #expect(scenario.sut.hasCopied == false)
        #expect(scenario.sut.sheet == nil)
    }

    // MARK: - The note, and its two answers

    @Test
    func `given the note is skipped when the screen asks then it says so and the document does not`() async {
        // given
        let scenario = Scenario()
        await scenario.load()

        // when
        scenario.sut.skipNote()

        // then — said on screen, because *Skip* has no other evidence; and absent from the document,
        // because an agent reading a placeholder treats it as an instruction to find one.
        #expect(scenario.sut.hasSkippedNote)
        #expect(scenario.sut.feedback(note: scenario.sut.noteDraft).contains("Skipped") == false)
    }

    @Test
    func `given the note was skipped when something is typed then it is no longer skipped`() async {
        // given — the two states are the same empty field, and the reader has just said which one
        // they are in.
        let scenario = Scenario()
        await scenario.load()
        scenario.sut.skipNote()

        // when
        scenario.sut.noteDraft = "Actually, one thing."

        // then
        #expect(scenario.sut.hasSkippedNote == false)
    }

    // MARK: - What the diff draws it against

    @Test
    func `given a comment whose lines are gone when the review is read then it is marked stale`() async {
        // given — a comment written in an earlier session against content the agent has since changed.
        let scenario = Scenario(holding: [aStoredComment(on: "file-0", at: 900, saying: "From yesterday.")])

        // when
        await scenario.load()

        // then
        #expect(scenario.sut.reviewed.map(\.isStale) == [true])
        #expect(scenario.sut.feedback(note: nil).contains("(these lines are no longer in the current diff)"))
    }
}

// MARK: -

private let aWorktree = WorktreeID(rawValue: "b7c1e0a4f2d84391")

/// The two rows `aHunk` draws: a context line carrying both numbers, and an addition carrying only
/// the new one.
private let aContextRow = DiffLinePosition(oldNumber: 1, newNumber: 1)
private let anAddition = DiffLinePosition(oldNumber: nil, newNumber: 2)

/// A comment that was written in some earlier session, so the model has one before it reads
/// anything.
private func aStoredComment(on file: String, at line: Int, saying text: String) -> ReviewComment {
    ReviewComment(
        anchor: CommentAnchor(
            file: FileID(rawValue: file),
            first: DiffLinePosition(oldNumber: nil, newNumber: line),
            last: DiffLinePosition(oldNumber: nil, newNumber: line)
        ),
        path: "Sources/\(file).swift",
        lines: CommentedLines(side: .new, first: line, last: line),
        quotedLines: ["+let answer = 42"],
        text: text
    )
}

private let aHunk = Hunk(
    index: 0,
    oldStart: 1,
    oldCount: 1,
    newStart: 1,
    newCount: 2,
    sectionHeading: nil,
    lines: [
        DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "let answer = 42", displayColumns: 15, segments: nil),
        DiffLine(kind: .addition, oldNumber: nil, newNumber: 2, text: "let question = 6 * 9", displayColumns: 20, segments: nil)
    ]
)

/// Files named so a comment landing on the wrong row reads as a mix-up rather than as a match.
private func aChangeSet(of count: Int) -> [FileChange] {
    (0..<count).map { position in
        FileChange(
            id: FileID(rawValue: "file-\(position)"),
            path: "Sources/File\(position).swift",
            oldPath: nil,
            status: .modified,
            isBinary: false,
            isSubmodule: false,
            stats: ChangeStats(filesChanged: 1, insertions: 2, deletions: 0),
            contentHash: String(repeating: "\(position)", count: 64),
            estimatedLineCount: 2,
            isViewed: false,
            isTruncated: false,
            language: "swift"
        )
    }
}

private struct Scenario {

    let sut: ClientViewerModel
    let store: FakeReviewCommentStore
    let pasteboard: FakeReviewPasteboard

    /// Eight files, so the batch of five leaves the eighth still awaiting — which is the file a
    /// comment cannot be attached to and is therefore worth having.
    init(holding comments: [ReviewComment] = []) {
        let files = aChangeSet(of: 8)
        let changes = WorktreeChanges(
            revision: "9d41e0c7",
            stats: ChangeStats(filesChanged: files.count, insertions: 16, deletions: 0),
            files: files,
            isTruncated: false
        )
        store = FakeReviewCommentStore(holding: comments)
        pasteboard = FakeReviewPasteboard()
        sut = ClientViewerModel(
            worktree: aWorktree,
            worktreeName: "TLS pinning",
            projectName: "granita",
            repository: FakeGranitaRepository(
                changeSet: .success(changes),
                hunks: Dictionary(uniqueKeysWithValues: files.map { ($0.id, [aHunk]) }),
                diffFailure: nil,
                viewedFailure: nil,
                linesAnswer: .failure(.fileGone),
                refusesTheFirstRead: nil,
                alsoAnswering: nil
            ),
            commentStore: store,
            pasteboard: pasteboard
        )
    }

    func load() async {
        await sut.load()
        await sut.reading(0)
    }
}
