import CoreDiffDomain

/// One file's place in the continuous scroll, and whether its diff has arrived yet.
///
/// **Both cases are on screen at once, always.** The change set names every changed file before a
/// single diff is fetched, so the scroll draws all of them from the first frame and fills them in
/// five ahead of the reader. A file waiting for its diff is not a loading state the reader is
/// blocked by — it is a stretch of scroll with a reserved height, and reserving that height
/// correctly enough is the whole of what keeps the content below it from jumping.
public enum ContinuousDiffEntry: Hashable, Sendable, Identifiable {

    /// Named, measured and not yet fetched. Carries the estimate the scroll reserves space from.
    case awaiting(FileChange)

    /// Fetched, and from here its real height is sticky for the session — a file that has been
    /// drawn never reverts to its estimate, so scrolling back up cannot reflow.
    case ready(FileDiff)

    public var file: FileChange {
        switch self {
        case .awaiting(let file): file
        case .ready(let diff): diff.file
        }
    }

    public var id: FileID { file.id }

    /// How many rows to reserve for a file nobody has seen yet.
    ///
    /// `estimatedLineCount` comes from the server, which counted it while it had the comparison
    /// open. Being wrong here is cheap in one direction and not in the other: an estimate that is
    /// too small or too large only matters *below* the viewport, where nothing the reader is
    /// looking at moves when it is corrected — which is why loading runs strictly forward and why
    /// the estimate needs to be reasonable rather than exact.
    public var reservedRows: Int {
        switch self {
        case .awaiting(let file): max(1, file.estimatedLineCount)
        case .ready(let diff): diff.hunks.reduce(0) { $0 + $1.lines.count }
        }
    }

    /// The same entry with the reader's mark moved, whichever case it is in.
    ///
    /// The mark is written from the file header, which a reader reaches on a file whose diff has
    /// arrived — but the selector beside it marks a subtree done from the same state, and a file
    /// still on its way is one of the files that subtree contains. Both cases have to answer, or the
    /// mark is a control that works on some rows and not others.
    ///
    /// **The height does not move**, which is what makes this safe under the no-reflow rule: neither
    /// case changes what `reservedRows` answers.
    public func viewed(_ isViewed: Bool) -> ContinuousDiffEntry {
        switch self {
        case .awaiting(let file):
            .awaiting(file.viewed(isViewed))
        case .ready(let diff):
            .ready(FileDiff(
                file: diff.file.viewed(isViewed),
                hunks: diff.hunks,
                oldLineCount: diff.oldLineCount,
                newLineCount: diff.newLineCount,
                isTruncated: diff.isTruncated,
                truncationReason: diff.truncationReason
            ))
        }
    }
}
