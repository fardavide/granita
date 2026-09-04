import CoreDiffDomain

/// One comment as the review shows it: what the reader wrote, and whether the diff still has the
/// lines it was written against.
///
/// **One type for two surfaces**, because design §7 asks the same question in both: the list row
/// draws an amber `· stale` and the exported document writes one parenthetical, and two answers to
/// one question is how a screen and the text it produces start disagreeing.
///
/// **Computed rather than stored on the comment.** An anchor is an address into a diff, and a diff
/// arrives in batches, grows when a hunk is expanded, and is replaced when the screen is re-opened.
/// A stored flag would have three writers and would be wrong the first time one of them did not run.
public struct ReviewedComment: Hashable, Sendable, Identifiable {

    public let comment: ReviewComment

    /// Whether the rows this was written against are gone.
    ///
    /// A stale comment is still sent — it is still what the reader said, and the excerpt it carries
    /// is still the code they were looking at. What it has lost is a place to sit in the scroll.
    public let isStale: Bool

    public init(comment: ReviewComment, isStale: Bool) {
        self.comment = comment
        self.isStale = isStale
    }

    public var id: CommentAnchor { comment.anchor }

    /// Every comment judged against the change set as it stands, in the order it was given.
    ///
    /// **The distinction the whole function exists for is *gone* versus *not here yet*.** The scroll
    /// names every changed file before it fetches any of their diffs, so a file with no hunks in hand
    /// is the ordinary state of everything below the viewport — calling that stale would put an amber
    /// row under most of a change set the moment it opened, and take them all back again as the
    /// batches landed. Only a file whose diff is in hand can be said to have lost a line.
    ///
    /// A file that has left the change set entirely is the other way round: there is nothing left to
    /// arrive, so it is gone rather than pending.
    public static func listing(
        of comments: [ReviewComment],
        against entries: [ContinuousDiffEntry]
    ) -> [ReviewedComment] {
        comments.map { comment in
            guard let entry = entries.first(where: { $0.id == comment.anchor.file }) else {
                return ReviewedComment(comment: comment, isStale: true)
            }
            guard case .ready(let diff) = entry.content else {
                return ReviewedComment(comment: comment, isStale: false)
            }
            let rows = CommentSelection.rows(of: diff, from: comment.anchor.first, to: comment.anchor.last)
            return ReviewedComment(comment: comment, isStale: rows == nil)
        }
    }

    /// The comments in the order the reader meets them scrolling, which is what both the review list
    /// and the exported document call *document order*.
    ///
    /// **Ordered by where each run is drawn, not by the number it reports.** The obvious key — the
    /// file's position, then `lines.first` — is wrong, and wrong in a way no test using one side would
    /// catch: `CommentedLines.first` is an *old*-side number for a run that is entirely deletions and
    /// a *new*-side number for everything else, and those two counters diverge the moment a file
    /// deletes more than it adds. A file that drops a hundred lines early on can hand a deletion at
    /// old 105 and an addition at new 50 to the same comparison, and put the second one first.
    ///
    /// The diff is the only thing that knows what is above what, so it is what is asked. A comment
    /// whose file is not in the change set, or whose diff has not arrived, has no position to be
    /// ordered by and goes last — the same fallback, for the same reason, as a file that has gone.
    public static func ordered(
        _ comments: [ReviewComment],
        against entries: [ContinuousDiffEntry]
    ) -> [ReviewComment] {
        let files = entries.map(\.id)
        return comments.sorted { left, right in
            (place(of: left, in: entries, files: files)) < (place(of: right, in: entries, files: files))
        }
    }

    /// Where a comment sits: which file, then which row of it.
    private static func place(
        of comment: ReviewComment,
        in entries: [ContinuousDiffEntry],
        files: [FileID]
    ) -> (Int, Int, Int) {
        let file = files.firstIndex(of: comment.anchor.file) ?? files.count
        guard case .ready(let diff)? = entries.first(where: { $0.id == comment.anchor.file })?.content,
              let row = diff.hunks.flatMap(\.lines)
                  .firstIndex(where: { DiffLinePosition.of($0) == comment.anchor.first }) else {
            // No rows to be placed among. Last within its file, and stably among its own kind — the
            // reported span is the only thing left to tell two of them apart, and both are on the
            // same side of the comparison because neither could be resolved.
            return (file, Int.max, comment.lines.first)
        }
        return (file, row, comment.lines.last)
    }
}
