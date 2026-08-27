import CoreDiffDomain

/// Whether a file's diff has arrived yet.
///
/// **Both cases are on screen at once, always.** The change set names every changed file before a
/// single diff is fetched, so the scroll draws all of them from the first frame and fills them in
/// five ahead of the reader. A file waiting for its diff is not a loading state the reader is
/// blocked by — it is a stretch of scroll with a reserved height, and reserving that height
/// correctly enough is the whole of what keeps the content below it from jumping.
public enum ContinuousDiffContent: Hashable, Sendable {

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
}

/// One file's place in the continuous scroll: what there is of it, and whether it is drawn.
///
/// **The collapse is computed rather than stored**, which is what keeps it from disagreeing with the
/// file it describes. A mark arriving, a diff arriving and the reader pressing a chevron all change
/// the answer, and three writers of one stored `Bool` is how a file ends up drawn shut while its
/// header says it is open.
public struct ContinuousDiffEntry: Hashable, Sendable, Identifiable {

    public let content: ContinuousDiffContent

    /// The reader's own answer about whether this file is open, where they have given one.
    ///
    /// `nil` is not "shut" — it is *nobody has said*, and the difference is what lets marking a file
    /// read shut it again after the reader had opened it by hand.
    public let openedByTheReader: Bool?

    public init(content: ContinuousDiffContent, openedByTheReader: Bool?) {
        self.content = content
        self.openedByTheReader = openedByTheReader
    }

    /// Named, measured and not yet fetched.
    public static func awaiting(_ file: FileChange) -> ContinuousDiffEntry {
        ContinuousDiffEntry(content: .awaiting(file), openedByTheReader: nil)
    }

    /// Fetched, and sticky from here.
    public static func ready(_ diff: FileDiff) -> ContinuousDiffEntry {
        ContinuousDiffEntry(content: .ready(diff), openedByTheReader: nil)
    }

    public var file: FileChange { content.file }

    public var id: FileID { file.id }

    /// Whether the diff is in hand, which is what the loader asks before spending a batch slot.
    public var isReady: Bool {
        switch content {
        case .awaiting: false
        case .ready: true
        }
    }

    public var collapse: FileCollapse {
        FileCollapsing.state(of: file, openedByTheReader: openedByTheReader)
    }

    /// How many rows to reserve for a file nobody has seen yet.
    ///
    /// `estimatedLineCount` comes from the server, which counted it while it had the comparison
    /// open. Being wrong here is cheap in one direction and not in the other: an estimate that is
    /// too small or too large only matters *below* the viewport, where nothing the reader is
    /// looking at moves when it is corrected — which is why loading runs strictly forward and why
    /// the estimate needs to be reasonable rather than exact.
    public var reservedRows: Int {
        switch content {
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
    /// **The reader's chevron is forgotten here, deliberately.** `SPEC.md` §10 says a file marked
    /// viewed renders collapsed, and the frame says the same in one sentence — tapping the circle
    /// marks the file and shuts it. A mark that left an earlier *open* standing would be the one
    /// gesture in this app that does half of what it says.
    public func viewed(_ isViewed: Bool) -> ContinuousDiffEntry {
        ContinuousDiffEntry(content: content.viewed(isViewed), openedByTheReader: nil)
    }

    /// The same entry with the reader's chevron pressed.
    public func opened(_ isOpen: Bool) -> ContinuousDiffEntry {
        ContinuousDiffEntry(content: content, openedByTheReader: isOpen)
    }

    /// The same entry with its diff arrived, keeping what the reader has said about it.
    ///
    /// A diff is the Mac answering a question asked before the reader touched anything, so a batch
    /// landing must not take back a mark they set or a file they opened while it was in flight.
    public func arrived(_ diff: FileDiff) -> ContinuousDiffEntry {
        ContinuousDiffEntry(
            content: ContinuousDiffContent.ready(diff).viewed(file.isViewed),
            openedByTheReader: openedByTheReader
        )
    }
}

// MARK: -

private extension ContinuousDiffContent {

    func viewed(_ isViewed: Bool) -> ContinuousDiffContent {
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
