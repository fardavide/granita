import ClientViewerDomain
import ClientViewerUi
import CoreDiffDomain
import CoreReviewDomain
import SwiftUI
import Testing

/// Design §7.5 and §7.6 — the note, the list, the copy, and the clear that only follows it.
///
/// **The state that matters most here is the one that is absent.** `before-the-copy` has no Clear on
/// it anywhere, and `after-the-copy` does: that is the sequencing Davide asked for, drawn literally,
/// and a baseline is the only thing that can hold "this control is not on this screen".
@Suite("Review sheet", .serialized)
@MainActor
struct ReviewSheetViewSnapshotTests {

    @Test(arguments: ReviewCase.all, SnapshotLayout.all)
    func `given a review state when it renders then it matches its baseline`(
        subject: ReviewCase,
        layout: SnapshotLayout
    ) {
        // given - when - then
        assertScreenSnapshot(
            ReviewSheetView(
                presentation: subject.presentation,
                comments: subject.comments,
                note: .constant(subject.note),
                hasSkippedNote: subject.hasSkippedNote,
                hasCopied: subject.hasCopied,
                caption: subject.caption,
                document: subject.document,
                showsDocument: subject.showsDocument,
                onShowDocument: { _ in },
                onClose: {},
                onSkipNote: {},
                onCopy: {},
                onClear: {},
                onDelete: { _ in }
            ),
            layout: layout,
            named: subject.name
        )
    }
}

// MARK: -

struct ReviewCase: Sendable, CustomTestStringConvertible {

    let name: String
    let comments: [ReviewedComment]
    let note: String
    var hasSkippedNote = false
    var hasCopied = false
    var presentation: ReviewSheetView.Presentation = .sheet
    var showsDocument = false

    /// Absent on every state that predates the Mac holding a review, which is how the shipped
    /// baselines stay byte-identical: the good state draws no sentence at all.
    var caption: ReviewSyncCaption?

    let document: String

    var testDescription: String { name }

    static let all: [ReviewCase] = [
        // The ordinary state: a note written, four comments, nothing copied yet. **No Clear on it.**
        ReviewCase(
            name: "before-the-copy",
            comments: aReview,
            note: "Rename appVersion to version before this lands. The About screen is the only caller.",
            document: aDocument
        ),

        // **Skip said out loud**, because it has no other evidence: the field is empty either way,
        // and a reader who skipped and then wondered whether it took has nothing else to read.
        ReviewCase(
            name: "the-note-skipped",
            comments: aReview,
            note: "",
            hasSkippedNote: true,
            document: aDocument
        ),

        // **After the copy, and this is the only state Clear appears in.** The footer says what
        // clearing costs, which is the sentence the whole sequencing exists to make true.
        //
        // **One comment rather than four, and that is the difference between a baseline and a
        // decoration.** With the full review in the list, Clear sits below the fold and the picture
        // named for it cannot see it — which would make this the same photograph as `before-the-copy`
        // and assert nothing at all. The pair that carries the rule is this one against
        // `one-comment`: same list, and a Clear row on exactly one of them.
        ReviewCase(
            name: "after-the-copy",
            comments: [aReview[0]],
            note: "",
            hasSkippedNote: true,
            hasCopied: true,
            document: aDocument
        ),

        // One comment, so the list is not the thing being read and the note is. **It is also the
        // pair `after-the-copy` is read against**: the same list, and a Clear row on exactly one.
        ReviewCase(
            name: "one-comment",
            comments: [aReview[0]],
            note: "",
            document: aDocument
        ),

        // **The column form, which brings no navigation stack of its own.** Rendered with one, this
        // view's title and its Close were drawn into the *screen's* navigation bar — the iPad
        // baseline caught it, and this is the subject that keeps it caught.
        ReviewCase(
            name: "as-a-column",
            comments: aReview,
            note: "",
            presentation: .column,
            document: aDocument
        ),

        // **What *Show text* reveals, which is the whole point of offering it**: the reader gets to
        // see the exact bytes before they go on the pasteboard. It was drawn by nothing until the
        // flag moved onto the model — a `@State` inside the sheet is a state no baseline can set,
        // and the Snapshot row is what said so.
        ReviewCase(
            name: "the-text-shown",
            comments: [aReview[0]],
            note: "",
            showsDocument: true,
            document: aDocument
        ),

        // MARK: - Where the review is, which is said in one place and only here

        // **Written while the laptop was shut.** The count is the assertion: two of four and four of
        // four are different decisions at the moment the reader is about to paste, and a word would
        // collapse them. The amber dot is the same figure the stale comment row uses.
        ReviewCase(
            name: "some-of-it-unsent",
            comments: aReview,
            note: "",
            caption: ReviewSyncCaption(
                sentence: "2 of 4 comments are only on this phone.",
                reason: nil,
                isUnsettled: true
            ),
            document: aDocument
        ),

        // **The push is running and there is no dot**, because the amber was reporting a
        // disagreement and there is no longer one to report. Nothing asks the reader to wait.
        ReviewCase(
            name: "reconciling",
            comments: aReview,
            note: "",
            caption: ReviewSyncCaption(
                sentence: "Sending to MacBook Pro…",
                reason: nil,
                isUnsettled: false
            ),
            document: aDocument
        ),

        // **The Mac refused, and the copy button is untouched by it.** That is the state this
        // baseline exists to hold: a review that was never pushed and gets pasted anyway is a
        // complete review in the reader's hand, so nothing here is disabled and nothing is gated.
        ReviewCase(
            name: "the-mac-refused",
            comments: aReview,
            note: "",
            caption: ReviewSyncCaption(
                sentence: "MacBook Pro cannot store this review.",
                reason: "the document on disk could not be read, so it was left as it is",
                isUnsettled: true
            ),
            document: aDocument
        ),

        // **A Mac too old to hold a review, which is not a failure.** No dot, no small print: the
        // sentence states where the review lives rather than reporting that something went wrong.
        ReviewCase(
            name: "kept-on-this-phone",
            comments: aReview,
            note: "",
            caption: ReviewSyncCaption(
                sentence: "This review is kept on this phone.",
                reason: nil,
                isUnsettled: false
            ),
            document: aDocument
        )
    ]
}

/// Four comments, one of which the diff can no longer place — which is the row the amber `· stale`
/// belongs to and the only one whose export carries a parenthetical.
private let aReview: [ReviewedComment] = [
    reviewed(
        path: "SwiftlyCore/Sources/Common/Test/Turbine.swift",
        first: 41,
        last: 44,
        text: "Take the timeout as a parameter and default it to five. One second is too short for CI."
    ),
    reviewed(
        path: "SwiftlyCore/Sources/Common/Test/Turbine.swift",
        first: 47,
        last: 47,
        text: "Deleted with no replacement. Is that intentional, or did the rewrite lose it?"
    ),
    reviewed(
        path: "SwiftlyCore/Sources/Common/Utils/Lce.swift",
        first: 8,
        last: 8,
        text: "This is unconditional. C and E are already constrained, so drop the where clause."
    ),
    reviewed(
        path: "SwiftlyCore/Sources/About/Presentation/Models/AboutState.swift",
        first: 6,
        last: 6,
        text: "Sendable here needs a test, not just a conformance.",
        isStale: true
    )
]

private func reviewed(
    path: String,
    first: Int,
    last: Int,
    text: String,
    isStale: Bool = false
) -> ReviewedComment {
    ReviewedComment(
        comment: ReviewComment(
            anchor: CommentAnchor(
                file: FileID(repositoryRelativePath: path),
                first: DiffLinePosition(oldNumber: nil, newNumber: first),
                last: DiffLinePosition(oldNumber: nil, newNumber: last)
            ),
            path: path,
            lines: CommentedLines(side: .new, first: first, last: last),
            language: "swift",
            quotedLines: ["func awaitItem() async throws -> Element {"],
            text: text
        ),
        isStale: isStale
    )
}

/// Written out rather than produced by `ReviewFeedback`, because what this baseline photographs is
/// the exact bytes the pasteboard will get: a fixture the exporter builds would photograph whatever
/// the exporter does today, which is the one thing *Show text* exists to let a reader check.
private let aDocument = """
    Review of uncommitted changes

    ---

    A. SwiftlyCore/Sources/About/Presentation/Models/AboutState.swift:6
    (these lines are no longer in the current diff)
    ```swift
    public struct AboutUiModel: Equatable, Sendable {
    ```
    Sendable here needs a test, not just a conformance.
    """
