import CoreDiffDomain

/// What the reader picked out, turned into something that can be written down.
///
/// **The two ends and the run between them are different questions.** An end has to be addressable,
/// because the reader taps a figure in the gutter and the comment has to find that row again after a
/// hunk expansion has moved everything around it. The run does not: it is whatever the diff draws
/// between the two, the no-newline marker included, and dropping that from the quote would hand the
/// agent an excerpt that is not what was on the screen.
public enum CommentSelection {

    /// The rows between two ends, in the order the diff draws them.
    ///
    /// Absent when either end is no longer in this diff, which is what the reader gets when the
    /// agent has changed the file under a comment they wrote against the old content.
    ///
    /// **The ends are ordered here rather than at the call site.** A reader long-presses one row and
    /// then taps another, and nothing about that gesture says the second is below the first.
    public static func rows(of diff: FileDiff, from: DiffLinePosition, to: DiffLinePosition) -> [DiffLine]? {
        guard let run = run(of: diff, from: from, to: to) else { return nil }
        return Array(diff.hunks.flatMap(\.lines)[run])
    }

    /// The two ends put in the order the diff draws them.
    ///
    /// **This is what makes the anchor an identity rather than a description of a gesture.** A reader
    /// who holds row 14 and taps row 11 has picked the same run as one who holds 11 and taps 14, and
    /// an anchor that recorded the order of their thumbs would file those as two comments on one run
    /// — which is the duplicate the "second tap on a commented run is an edit" rule exists to prevent.
    ///
    /// It cannot be done by comparing the numbers. Within a file both sides run non-decreasing, but a
    /// deletion carries only an old number and an addition only a new one, so for that pair there is
    /// no arithmetic that says which is drawn first. The diff is the only thing that knows.
    public static func ends(
        of diff: FileDiff,
        from: DiffLinePosition,
        to: DiffLinePosition
    ) -> (first: DiffLinePosition, last: DiffLinePosition)? {
        guard let run = run(of: diff, from: from, to: to) else { return nil }
        let all = diff.hunks.flatMap(\.lines)
        guard let first = DiffLinePosition.of(all[run.lowerBound]),
              let last = DiffLinePosition.of(all[run.upperBound - 1]) else {
            return nil
        }
        return (first, last)
    }

    /// The span the two ends cover, as indices into the file's drawn rows.
    ///
    /// Flattened across hunks, because a selection is allowed to run from the foot of one hunk into
    /// the head of the next — they are adjacent on screen whatever the file does between them, and
    /// the quote is what has to be honest about the gap rather than the range.
    private static func run(of diff: FileDiff, from: DiffLinePosition, to: DiffLinePosition) -> Range<Int>? {
        let all = diff.hunks.flatMap(\.lines)
        guard let start = all.firstIndex(where: { DiffLinePosition.of($0) == from }),
              let end = all.firstIndex(where: { DiffLinePosition.of($0) == to }) else {
            return nil
        }
        return min(start, end)..<(max(start, end) + 1)
    }

    /// The comment those two ends and those words make, with everything the document will need
    /// already in it.
    public static func comment(
        on diff: FileDiff,
        from: DiffLinePosition,
        to: DiffLinePosition,
        saying text: String
    ) -> ReviewComment? {
        guard let rows = rows(of: diff, from: from, to: to),
              let ends = ends(of: diff, from: from, to: to),
              let lines = CommentedLines.of(rows) else {
            return nil
        }
        return ReviewComment(
            anchor: CommentAnchor(file: diff.file.id, first: ends.first, last: ends.last),
            path: diff.file.path,
            lines: lines,
            quotedLines: rows.map(quoted(_:)),
            text: text
        )
    }

    /// One row as the excerpt carries it.
    ///
    /// **The diff's own `+`/`−` markers are not here, which is design §7's call and not an
    /// omission.** The excerpt is quoted with `> ` in the exported document and shown as code in the
    /// composer, and in both places what it is for is *the lines this comment is about* rather than
    /// *the change they are part of* — the change is what the reader already read, and the line
    /// numbers beside the path say which side they are on. Keeping the text unprefixed is also what
    /// lets an agent search the file for it; a `+` in front makes every quoted line a string that
    /// appears nowhere.
    ///
    /// **The one row that keeps a prefix is the one that is not a line of the file.**
    /// `\ No newline at end of file` is git's own annotation, and the parser strips the two
    /// characters it arrives behind — so quoted bare it reads as a line of English in the middle of
    /// some code. It goes back the way git wrote it.
    private static func quoted(_ line: DiffLine) -> String {
        line.kind == .noNewlineMarker ? "\\ \(line.text)" : line.text
    }
}
