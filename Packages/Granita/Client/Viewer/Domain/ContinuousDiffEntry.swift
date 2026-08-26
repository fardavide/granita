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
}
