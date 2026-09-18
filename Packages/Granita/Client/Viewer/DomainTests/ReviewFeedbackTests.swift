import Testing

import CoreDiffDomain
import CoreReviewDomain

@testable import ClientViewerDomain

/// The one piece of text a review becomes, which is the whole point of writing the comments down.
///
/// **Markdown, and that is a reversal of design §7's reversal.** The first version was Markdown, §7
/// overturned it for plain text on the grounds that the audience is an agent rather than a renderer,
/// and Davide overturned that again on 16 September 2026: *"I want to use a proper code block instead
/// of a quote block"*, with the language named the way Markdown names it, and a rule between comments
/// because *"otherwise it's a little bit difficult to read the prompt"*. The excerpt is code, a fence
/// is what says so, and the agents this is pasted to read both natively. Recorded in
/// `.ai/docs/decisions.md`.
///
/// **The heading names nothing, which is the same conversation's other call.** It used to carry the
/// project, the worktree and the size of the read; Davide's answer is that *"they are contexts that
/// the session already has"*, and a line restating them to an agent already sitting in the checkout
/// is a line it has to read past.
///
/// What survives every reversal is the shape: a path with a line span, the lines, and what the reader
/// said about them. Full repository-relative paths, document order, an excerpt snapshotted when the
/// comment was written, and no trace at all of a skipped note.
@Suite("Review feedback")
struct ReviewFeedbackTests {

    // MARK: - The document

    @Test
    func `given one comment and a note when the document is built then both are in it`() {
        // given
        let comment = aComment(
            path: "SwiftlyCore/Sources/Common/Test/Turbine.swift",
            lines: CommentedLines(side: .new, first: 41, last: 44),
            language: "swift",
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
            note: "Rename appVersion to version before this lands.",
            settings: .unset,
            comments: [comment]
        )

        // then — the fence and the reader's words sit against each other with no blank line between
        // them, because they are one thought. The rule is what separates one comment from the next.
        #expect(document == """
            Review of uncommitted changes

            Rename appVersion to version before this lands.

            ---

            A. SwiftlyCore/Sources/Common/Test/Turbine.swift:41-44
            ```swift
            func awaitItem() async throws -> Element {
              try await withTimeout(.seconds(1)) {
                try await self.awaitNext()
              }
            ```
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
            language: "makefile",
            quoted: ["\tswift test"],
            saying: "This wants the package flag."
        )

        // when
        let document = ReviewFeedback.document(note: nil, settings: .unset, comments: [comment])

        // then
        #expect(document == """
            Review of uncommitted changes

            ---

            A. Makefile:4
            ```makefile
            \tswift test
            ```
            This wants the package flag.
            """)
    }

    @Test
    func `given a note of nothing but spaces when the document is built then it is treated as skipped`() {
        // given — the field was opened, brushed, and left. Same intent as *Skip*, and it must not
        // produce a paragraph made of one space.
        // when
        let document = ReviewFeedback.document(note: "   \n  ", settings: .unset, comments: [])

        // then
        #expect(document == "Review of uncommitted changes")
    }

    @Test
    func `given a note with room around it when the document is built then the room is dropped`() {
        // given - when
        let document = ReviewFeedback.document(
            note: "\n  Ship it.  \n",
            settings: .unset,
            comments: []
        )

        // then
        #expect(document == """
            Review of uncommitted changes

            Ship it.
            """)
    }

    @Test
    func `given nothing was written when the document is built then it is the heading alone`() {
        // given - when — unreachable from the screen, whose capsule is absent until a comment exists.
        // Answered anyway, because a function that is total has no state a caller has to avoid.
        let document = ReviewFeedback.document(note: nil, settings: .unset, comments: [])

        // then — and nothing about the project, the worktree or the size of the read, which the
        // session being pasted into already knows.
        #expect(document == "Review of uncommitted changes")
    }

    @Test
    func `given a comment on one line when the document is built then the span is that line alone`() {
        // given
        let comment = aComment(
            path: "SwiftlyCore/Sources/Common/Utils/Lce.swift",
            lines: CommentedLines(side: .new, first: 8, last: 8),
            language: "swift",
            quoted: ["extension Lce: Sendable where C: Sendable, E: Sendable {}"],
            saying: "This is unconditional."
        )

        // when
        let document = ReviewFeedback.document(note: nil, settings: .unset, comments: [comment])

        // then
        #expect(document.contains("A. SwiftlyCore/Sources/Common/Utils/Lce.swift:8\n```swift"))
    }

    // MARK: - The rules between comments

    @Test
    func `given several comments when the document is built then a rule stands between them`() {
        // given — Davide's own reason: four comments with nothing but a blank line between them read
        // as one wall of text, and the thing he most needs to see at a glance is where one ends.
        let first = aComment(
            path: "Sources/Api.swift",
            lines: CommentedLines(side: .new, first: 12, last: 12),
            language: "swift",
            quoted: ["    let a = 1"],
            saying: "One."
        )
        let second = aComment(
            path: "Sources/Store.swift",
            lines: CommentedLines(side: .new, first: 30, last: 30),
            language: "swift",
            quoted: ["    let b = 2"],
            saying: "Two."
        )

        // when
        let document = ReviewFeedback.document(
            note: nil,
            settings: .unset,
            comments: [first, second]
        )

        // then
        #expect(document == """
            Review of uncommitted changes

            ---

            A. Sources/Api.swift:12
            ```swift
                let a = 1
            ```
            One.

            ---

            B. Sources/Store.swift:30
            ```swift
                let b = 2
            ```
            Two.
            """)
    }

    @Test
    func `given a note and comments when the document is built then a rule separates the note from the first`() {
        // given — the note is about the change as a whole and the comments are about lines, so the
        // first rule earns its place for the same reason every later one does.
        let comment = aComment(
            path: "Sources/Api.swift",
            lines: CommentedLines(side: .new, first: 12, last: 12),
            language: "swift",
            quoted: ["    let a = 1"],
            saying: "One."
        )

        // when
        let document = ReviewFeedback.document(
            note: "Ship it.",
            settings: .unset,
            comments: [comment]
        )

        // then
        #expect(document.contains("Ship it.\n\n---\n\nA. Sources/Api.swift:12"))
    }

    // MARK: - The fence

    @Test
    func `given a file the server claimed no language for when the document is built then the fence is bare`() {
        // given — `LanguageHint` is absent rather than guessed when the extension says nothing, and a
        // fence tagged with a language the file is not colours it worse than an untagged one does.
        let comment = aComment(
            path: "LICENSE",
            lines: CommentedLines(side: .new, first: 1, last: 1),
            language: nil,
            quoted: ["Copyright (c) 2026 Davide Farella"],
            saying: "The year is wrong."
        )

        // when
        let document = ReviewFeedback.document(note: nil, settings: .unset, comments: [comment])

        // then
        #expect(document.contains("""
            A. LICENSE:1
            ```
            Copyright (c) 2026 Davide Farella
            ```
            The year is wrong.
            """))
    }

    @Test
    func `given the excerpt holds a fence of its own when the document is built then the outer one is longer`() {
        // given — the case a three-backtick fence cannot survive, and the reader most likely to hit it
        // is one reviewing a change to this repository's own Markdown. A closing fence inside the
        // excerpt ends the block early, and everything after it — including the reader's comment —
        // reads to the agent as prose about code rather than the code itself.
        let comment = aComment(
            path: ".ai/docs/design.md",
            lines: CommentedLines(side: .new, first: 2022, last: 2024),
            language: "markdown",
            quoted: ["```", "Review of uncommitted changes", "```"],
            saying: "This example is stale."
        )

        // when
        let document = ReviewFeedback.document(note: nil, settings: .unset, comments: [comment])

        // then
        #expect(document.contains("""
            A. .ai/docs/design.md:2022-2024
            ````markdown
            ```
            Review of uncommitted changes
            ```
            ````
            This example is stale.
            """))
    }

    @Test
    func `given the excerpt holds a long run of backticks when the document is built then the fence clears it`() {
        // given — the run is counted wherever it sits on the line, not only at the start: a fence is
        // measured by the longest run the block contains, and one line short is one line too few.
        let comment = aComment(
            path: "README.md",
            lines: CommentedLines(side: .new, first: 3, last: 3),
            language: "markdown",
            quoted: ["Write it as `````swift, not ```swift."],
            saying: "Explain why."
        )

        // when
        let document = ReviewFeedback.document(note: nil, settings: .unset, comments: [comment])

        // then
        #expect(document.contains("""
            ``````markdown
            Write it as `````swift, not ```swift.
            ``````
            """))
    }

    // MARK: - The identifiers

    @Test
    func `given letters when several comments are exported then each is labelled in document order`() {
        // given
        let comments = (0..<3).map { index in
            aComment(
                path: "Sources/File\(index).swift",
                lines: CommentedLines(side: .new, first: index, last: index),
                language: "swift",
                quoted: ["    let a = \(index)"],
                saying: "Number \(index)."
            )
        }

        // when
        let document = ReviewFeedback.document(note: nil, settings: .unset, comments: comments)

        // then
        #expect(document.contains("A. Sources/File0.swift:0"))
        #expect(document.contains("B. Sources/File1.swift:1"))
        #expect(document.contains("C. Sources/File2.swift:2"))
    }

    @Test
    func `given numbers when several comments are exported then each is labelled in document order`() {
        // given
        let comments = (0..<3).map { index in
            aComment(
                path: "Sources/File\(index).swift",
                lines: CommentedLines(side: .new, first: index, last: index),
                language: "swift",
                quoted: ["    let a = \(index)"],
                saying: "Number \(index)."
            )
        }

        // when
        let document = ReviewFeedback.document(
            note: nil,
            settings: ReviewSettings(openingLine: nil, identifier: .numbers),
            comments: comments
        )

        // then
        #expect(document.contains("1. Sources/File0.swift:0"))
        #expect(document.contains("2. Sources/File1.swift:1"))
        #expect(document.contains("3. Sources/File2.swift:2"))
    }

    // MARK: - The caveats

    @Test
    func `given lines that only exist on the old side when the document is built then it says so`() {
        // given — every row in the run was deleted, so nothing in the working copy sits at these
        // numbers and an agent opening the file there reads whatever now does.
        let comment = aComment(
            path: "Sources/Api.swift",
            lines: CommentedLines(side: .old, first: 40, last: 41),
            language: "swift",
            quoted: ["    let legacy = true"],
            saying: "Why did this go?"
        )

        // when
        let document = ReviewFeedback.document(note: nil, settings: .unset, comments: [comment])

        // then — a line the returned frames never drew, added for the one case their example could
        // not show. It borrows the idiom the stale line already established rather than inventing a
        // second one, and it stays outside the fence because it is not part of the code.
        #expect(document.contains("""
            A. Sources/Api.swift:40-41
            (these lines were removed — the numbers are from before the change)
            ```swift
                let legacy = true
            ```
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
            language: "swift",
            quoted: ["public struct AboutUiModel: Equatable, Sendable {"],
            saying: "Sendable here needs a test, not just a conformance."
        )

        // when
        let document = ReviewFeedback.document(
            note: nil,
            settings: .unset,
            comments: [ReviewedComment(comment: comment.comment, isStale: true)]
        )

        // then
        #expect(document.contains("""
            A. SwiftlyCore/Sources/About/Presentation/Models/AboutState.swift:6
            (these lines are no longer in the current diff)
            ```swift
            public struct AboutUiModel: Equatable, Sendable {
            ```
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
            language: "swift",
            quoted: ["    let legacy = true"],
            saying: "Why did this go?"
        )

        // when
        let document = ReviewFeedback.document(
            note: nil,
            settings: .unset,
            comments: [ReviewedComment(comment: comment.comment, isStale: true)]
        )

        // then
        #expect(document.contains("(these lines are no longer in the current diff)"))
        #expect(document.contains("(these lines were removed") == false)
    }
}

// MARK: -

private func comment(
    file: FileID = FileID(rawValue: "the-one-being-read"),
    path: String = "Sources/Api.swift",
    lines: CommentedLines,
    language: String? = "swift",
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
        language: language,
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
    language: String? = "swift",
    quoted: [String] = ["    let a = 1"],
    saying text: String
) -> ReviewedComment {
    ReviewedComment(
        comment: comment(file: file, path: path, lines: lines, language: language, quoted: quoted, saying: text),
        isStale: false
    )
}
