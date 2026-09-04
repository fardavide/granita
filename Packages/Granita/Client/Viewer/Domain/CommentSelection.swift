import CoreDiffDomain

/// What the reader picked out, turned into something that can be written down.
///
/// **The two ends and the run between them are different questions.** An end has to be addressable,
/// because the reader taps a figure in the gutter and the comment has to find that row again after a
/// hunk expansion has moved everything around it. The run does not: it is whatever the diff draws
/// between the two, the no-newline marker included, and dropping that from the quote would hand the
/// agent an excerpt that is not what was on the screen.
/// One row of the excerpt the composer quotes.
///
/// The figure is optional for the row that has none — `\ No newline at end of file`, which can sit
/// inside a run and is not a line of the file.
public struct ExcerptLine: Hashable, Sendable {

    public let number: Int?
    public let text: String

    public init(number: Int?, text: String) {
        self.number = number
        self.text = text
    }
}

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
        // **The ends are the two positions that were handed in, in the order the run found them.**
        // `run(of:from:to:)` located each by matching `DiffLinePosition.of($0)` against them, so
        // reading the addresses back off the rows would be asking the diff a question it has just
        // answered — and the `guard` that unwrapping needs is a branch nothing can enter.
        let all = diff.hunks.flatMap(\.lines)
        return DiffLinePosition.of(all[run.lowerBound]) == from ? (from, to) : (to, from)
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
            quotedLines: quotation(of: rows),
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
    /// The rows the composer quotes, each still carrying the figure the gutter drew beside it.
    ///
    /// **The numbers come with the code, which is what makes the quotation a receipt rather than a
    /// sample.** §7.2's excerpt is there so a reader who landed one row off can see it *before* they
    /// type, and the thing they would recognise is the number they were aiming at — the text alone
    /// looks equally plausible one row up.
    public static func excerpt(of rows: [DiffLine]) -> [ExcerptLine] {
        rows.map { ExcerptLine(number: DiffGutter.number(of: $0), text: quoted($0)) }
    }

    /// The rows as the excerpt carries them, for the composer as well as the document.
    ///
    /// **Public because the composer draws the same excerpt**, and it drew it differently: reading
    /// `\.text` straight off the rows put `No newline at end of file` into the quotation as though it
    /// were a line of the reader's code, while the exported document — which the composer's own doc
    /// comment calls "the same snapshot" — spelled it `\ No newline at end of file`. One run, two
    /// spellings, and only the one the reader could not see was right.
    public static func quotation(of rows: [DiffLine]) -> [String] {
        rows.map(quoted(_:))
    }

    private static func quoted(_ line: DiffLine) -> String {
        line.kind == .noNewlineMarker ? "\\ \(line.text)" : line.text
    }
}
