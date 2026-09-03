import Testing

import CoreDiffDomain

@testable import ClientViewerDomain

/// The one piece of text a review becomes, which is the whole point of writing the comments down.
///
/// **Plain text, and that is a reversal of what was built first.** The first version of this was
/// Markdown — `#` headings, `##` per comment, a fenced `diff` block — on the reasoning that the
/// reader was about to paste it into a chat. Design §7 overturned it: the destination is a terminal
/// on the Mac the phone is lying beside, the audience is an agent rather than a renderer, and heading
/// syntax is something that has to be stripped before it can be acted on. What replaced it is the
/// shape the text already had — a path with a line span, the lines, and what the reader said.
///
/// Four decisions the design states and this suite pins: full repository-relative paths, document
/// order, the excerpt quoted with `> ` from a snapshot taken when the comment was written, and no
/// trace at all of a skipped note.
@Suite("Review feedback")
struct ReviewFeedbackTests {

    // MARK: - The document

    @Test
    func `given one comment and a note when the document is built then both are in it`() {
        // given
        let comment = aComment(
            path: "SwiftlyCore/Sources/Common/Test/Turbine.swift",
            lines: CommentedLines(side: .new, first: 41, last: 44),
            quoted: [
                "func awaitItem() async throws -> Element {",
                "  try await withTimeout(.seconds(1)) {",
                "    try await self.awaitNext()",
                "  }"
            ],
            saying: "Take the timeout as a parameter and default it to five. One second is too short for CI."
        )

        // when
        let document = ReviewFeedback.document(
            project: "swiftly",
            worktree: "main",
            fileCount: 12,
            note: "Rename appVersion to version before this lands.",
            comments: [comment]
        )

        // then — the excerpt and the reader's words sit against each other with no blank line
        // between them, because they are one thought. The blank lines separate comments.
        #expect(document == """
            Review of uncommitted changes — swiftly, worktree main, 12 files

            Rename appVersion to version before this lands.

            SwiftlyCore/Sources/Common/Test/Turbine.swift:41-44
            > func awaitItem() async throws -> Element {
            >   try await withTimeout(.seconds(1)) {
            >     try await self.awaitNext()
            >   }
            Take the timeout as a parameter and default it to five. One second is too short for CI.
            """)
    }

    @Test
    func `given the note was skipped when the document is built then nothing stands in for it`() {
        // given — *Skip* is one of the two answers the flow offers, so an empty heading or a
        // placeholder sentence would be the app inventing something the reader declined to say. An
        // agent reading a placeholder treats it as an instruction to go and find one.
        let comment = aComment(
            path: "Makefile",
            lines: CommentedLines(side: .new, first: 4, last: 4),
            quoted: ["\tswift test"],
            saying: "This wants the package flag."
        )

        // when
        let document = ReviewFeedback.document(
            project: "granita",
            worktree: "bridge-cse",
            fileCount: 3,
            note: nil,
            comments: [comment]
        )

        // then
        #expect(document == """
            Review of uncommitted changes — granita, worktree bridge-cse, 3 files

            Makefile:4
            > \tswift test
            This wants the package flag.
            """)
    }

    @Test
    func `given a note of nothing but spaces when the document is built then it is treated as skipped`() {
        // given — the field was opened, brushed, and left. Same intent as *Skip*, and it must not
        // produce a paragraph made of one space.
        // when
        let document = ReviewFeedback.document(
            project: "granita",
            worktree: "bridge-cse",
            fileCount: 1,
            note: "   \n  ",
            comments: []
        )

        // then
        #expect(document == "Review of uncommitted changes — granita, worktree bridge-cse, 1 file")
    }

    @Test
    func `given a note with room around it when the document is built then the room is dropped`() {
        // given - when
        let document = ReviewFeedback.document(
            project: "granita",
            worktree: "bridge-cse",
            fileCount: 2,
            note: "\n  Ship it.  \n",
            comments: []
        )

        // then
        #expect(document == """
            Review of uncommitted changes — granita, worktree bridge-cse, 2 files

            Ship it.
            """)
    }

    @Test
    func `given one changed file when the document is built then the heading says so in the singular`() {
        // given - when
        let document = ReviewFeedback.document(
            project: "granita",
            worktree: "bridge-cse",
            fileCount: 1,
            note: nil,
            comments: []
        )

        // then
        #expect(document.hasSuffix("worktree bridge-cse, 1 file"))
    }

    @Test
    func `given a comment on one line when the document is built then the span is that line alone`() {
        // given
        let comment = aComment(
            path: "SwiftlyCore/Sources/Common/Utils/Lce.swift",
            lines: CommentedLines(side: .new, first: 8, last: 8),
            quoted: ["extension Lce: Sendable where C: Sendable, E: Sendable {}"],
            saying: "This is unconditional."
        )

        // when
        let document = ReviewFeedback.document(
            project: "swiftly",
            worktree: "main",
            fileCount: 12,
            note: nil,
            comments: [comment]
        )

        // then
        #expect(document.contains("SwiftlyCore/Sources/Common/Utils/Lce.swift:8\n>"))
    }

    @Test
    func `given lines that only exist on the old side when the document is built then it says so`() {
        // given — every row in the run was deleted, so nothing in the working copy sits at these
        // numbers and an agent opening the file there reads whatever now does.
        let comment = aComment(
            path: "Sources/Api.swift",
            lines: CommentedLines(side: .old, first: 40, last: 41),
            quoted: ["    let legacy = true"],
            saying: "Why did this go?"
        )

        // when
        let document = ReviewFeedback.document(
            project: "granita",
            worktree: "main",
            fileCount: 2,
            note: nil,
            comments: [comment]
        )

        // then — a line the returned frames never drew, added for the one case their example could
        // not show. It borrows the idiom the stale line already established rather than inventing a
        // second one.
        #expect(document.contains("""
            Sources/Api.swift:40-41
            (these lines were removed — the numbers are from before the change)
            >     let legacy = true
            Why did this go?
            """))
    }

    @Test
    func `given the lines are gone from the diff when the document is built then it says so instead`() {
        // given — design §7.6's own parenthetical, and what makes a stale comment still worth
        // sending: the agent gets the text the reader was looking at, plus one line saying it moved.
        let comment = aComment(
            path: "SwiftlyCore/Sources/About/Presentation/Models/AboutState.swift",
            lines: CommentedLines(side: .new, first: 6, last: 6),
            quoted: ["public struct AboutUiModel: Equatable, Sendable {"],
            saying: "Sendable here needs a test, not just a conformance."
        )

        // when
        let document = ReviewFeedback.document(
            project: "swiftly",
            worktree: "main",
            fileCount: 12,
            note: nil,
            comments: [ReviewedComment(comment: comment.comment, isStale: true)]
        )

        // then
        #expect(document.contains("""
            SwiftlyCore/Sources/About/Presentation/Models/AboutState.swift:6
            (these lines are no longer in the current diff)
            > public struct AboutUiModel: Equatable, Sendable {
            Sendable here needs a test, not just a conformance.
            """))
    }

    @Test
    func `given a stale comment on the old side when the document is built then staleness is what it says`() {
        // given — both are true and only one line is drawn. Staleness is the stronger statement:
        // lines that are not in the diff at all cannot usefully also be described as removed by it.
        let comment = aComment(
            path: "Sources/Api.swift",
            lines: CommentedLines(side: .old, first: 40, last: 41),
            quoted: ["    let legacy = true"],
            saying: "Why did this go?"
        )

        // when
        let document = ReviewFeedback.document(
            project: "granita",
            worktree: "main",
            fileCount: 2,
            note: nil,
            comments: [ReviewedComment(comment: comment.comment, isStale: true)]
        )

        // then
        #expect(document.contains("(these lines are no longer in the current diff)"))
        #expect(document.contains("(these lines were removed") == false)
    }

    @Test
    func `given several comments when the document is built then each is a block of its own`() {
        // given
        let first = aComment(
            path: "Sources/Api.swift",
            lines: CommentedLines(side: .new, first: 12, last: 12),
            quoted: ["    let a = 1"],
            saying: "One."
        )
        let second = aComment(
            path: "Sources/Store.swift",
            lines: CommentedLines(side: .new, first: 30, last: 30),
            quoted: ["    let b = 2"],
            saying: "Two."
        )

        // when
        let document = ReviewFeedback.document(
            project: "granita",
            worktree: "main",
            fileCount: 2,
            note: nil,
            comments: [first, second]
        )

        // then
        #expect(document == """
            Review of uncommitted changes — granita, worktree main, 2 files

            Sources/Api.swift:12
            >     let a = 1
            One.

            Sources/Store.swift:30
            >     let b = 2
            Two.
            """)
    }

    @Test
    func `given nothing was written when the document is built then it is the heading alone`() {
        // given - when — unreachable from the screen, whose capsule is absent until a comment exists.
        // Answered anyway, because a function that is total has no state a caller has to avoid.
        let document = ReviewFeedback.document(
            project: "granita",
            worktree: "main",
            fileCount: 12,
            note: nil,
            comments: []
        )

        // then
        #expect(document == "Review of uncommitted changes — granita, worktree main, 12 files")
    }

}

// MARK: -

private func comment(
    file: FileID = FileID(rawValue: "the-one-being-read"),
    path: String = "Sources/Api.swift",
    lines: CommentedLines,
    quoted: [String] = ["    let a = 1"],
    saying text: String
) -> ReviewComment {
    ReviewComment(
        anchor: CommentAnchor(
            file: file,
            first: DiffLinePosition(oldNumber: nil, newNumber: lines.first),
            last: DiffLinePosition(oldNumber: nil, newNumber: lines.last)
        ),
        path: path,
        lines: lines,
        quotedLines: quoted,
        text: text
    )
}

/// The document is written from judged comments rather than raw ones, because whether the lines are
/// still there is what decides the parenthetical.
private func aComment(
    file: FileID = FileID(rawValue: "the-one-being-read"),
    path: String = "Sources/Api.swift",
    lines: CommentedLines,
    quoted: [String] = ["    let a = 1"],
    saying text: String
) -> ReviewedComment {
    ReviewedComment(
        comment: comment(file: file, path: path, lines: lines, quoted: quoted, saying: text),
        isStale: false
    )
}
