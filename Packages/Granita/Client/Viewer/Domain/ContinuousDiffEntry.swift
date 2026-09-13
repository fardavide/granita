import CoreDiffDomain

/// Whether a file's diff has arrived yet.
///
/// **The first two cases are on screen at once, always.** The change set names every changed file
/// before a single diff is fetched, so the scroll draws all of them from the first frame and fills
/// them in five ahead of the reader. A file waiting for its diff is not a loading state the reader
/// is blocked by — it is a stretch of scroll with a reserved height, and reserving that height
/// correctly enough is the whole of what keeps the content below it from jumping.
public enum ContinuousDiffContent: Hashable, Sendable {

    /// Named, measured and not yet fetched. Carries the estimate the scroll reserves space from.
    case awaiting(FileChange)

    /// Fetched, and from here its real height is sticky for the session — a file that has been
    /// drawn never reverts to its estimate, so scrolling back up cannot reflow.
    case ready(FileDiff)

    /// Asked for, refused, and not coming back until the reader asks again.
    ///
    /// **The third case exists because there was nowhere for a refusal to go.** The model held an
    /// `ApiFailure` and dropped it, so a file whose batch failed stayed `awaiting` — which is to say
    /// a blank card, for the life of the screen, with nothing anywhere saying so. Design §9 makes
    /// *still coming*, *arrived empty* and *failed and never coming* three pictures rather than one,
    /// and this is the case that lets the screen tell the third from the first.
    ///
    /// It carries the `FileChange` rather than the failure. The failure belongs to the **request**,
    /// which carried five files, so it is held once by the model and printed once in the bar.
    case failed(FileChange)

    public var file: FileChange {
        switch self {
        case .awaiting(let file): file
        case .ready(let diff): diff.file
        case .failed(let file): file
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

    /// Asked for and refused.
    public static func failed(_ file: FileChange) -> ContinuousDiffEntry {
        ContinuousDiffEntry(content: .failed(file), openedByTheReader: nil)
    }

    public var file: FileChange { content.file }

    public var id: FileID { file.id }

    /// Whether the diff is in hand, which is what the loader asks before spending a batch slot.
    public var isReady: Bool {
        switch content {
        case .awaiting, .failed: false
        case .ready: true
        }
    }

    /// Whether the last thing this file heard from the Mac was a refusal.
    ///
    /// Read by the screen, which draws a stopped block instead of a sweeping one, and by the model,
    /// which keeps these out of `ContinuousDiffLoading`'s reach until the reader presses *Try
    /// Again*. Without the second, a failed file leaving `inFlight` is eligible again on the very
    /// next position update — so a reader nudging the scroll would re-ask a dead Mac every frame and
    /// the rows would flicker between the two sentences.
    public var isFailed: Bool {
        switch content {
        case .awaiting, .ready: false
        case .failed: true
        }
    }

    public var collapse: FileCollapse {
        FileCollapsing.state(of: file, openedByTheReader: openedByTheReader)
    }

    /// The tallest a skeleton is allowed to be, however many lines the file says it has.
    ///
    /// **Four rows, because the estimate cannot be right and a tall wrong box is worse than a short
    /// honest one.** `estimatedLineCount` counts *diff lines*, and a drawn file is diff lines **plus
    /// a torn expander wherever the diff skipped something** — 44pt each, about two and a half rows,
    /// and there is one above the first hunk, one below the last and one between every pair. Nothing
    /// on the wire says how many, so a box sized from the line count alone is short by an amount
    /// nobody can compute. It was reserving hundreds of points to land in the wrong place anyway.
    public static let skeletonRows = 4

    /// How many rows a file nobody has seen yet draws into.
    ///
    /// **A short skeleton rather than the file's own height**, which reverses design §9's opening
    /// premise on Davide's call: the box no longer pretends to be the file that is coming, so the
    /// content that arrives is free to be whatever height it is. What keeps that from being the
    /// reflow `SPEC.md` §10 forbids is the rule that was always underneath it — loading runs strictly
    /// forward, so a file whose height changes is at or below the reader, never above them — and the
    /// growth is animated rather than snapped, so what they see is a file arriving rather than the
    /// screen jumping.
    ///
    /// Capped rather than fixed, so a one-line file still draws one row: a skeleton taller than the
    /// file it stands for is the same lie in the other direction.
    ///
    /// **A refused file answers exactly as a waiting one does**, which is design §9's one hard
    /// requirement of the third case: the box a failed file draws into is the box it was already
    /// drawing into, so the treatment that says it failed cannot change the height on the way in.
    public var reservedRows: Int {
        switch content {
        case .awaiting(let file), .failed(let file):
            min(max(1, file.estimatedLineCount), Self.skeletonRows)
        case .ready(let diff):
            diff.hunks.reduce(0) { $0 + $1.lines.count }
        }
    }

    /// The same entry with its batch's refusal recorded against it.
    ///
    /// **A file already in hand keeps its diff**, which is the branch that must never be taken
    /// rather than the one that is: a batch never carries a file the loader is already holding, and
    /// blanking drawn content on a later refusal would take away the thing the reader is reading.
    public func failing() -> ContinuousDiffEntry {
        switch content {
        case .ready:
            self
        case .awaiting(let file), .failed(let file):
            ContinuousDiffEntry(content: .failed(file), openedByTheReader: openedByTheReader)
        }
    }

    /// The same entry put back on its way, which is the whole of what *Try Again* does to a file.
    public func retrying() -> ContinuousDiffEntry {
        switch content {
        case .ready:
            self
        case .awaiting(let file), .failed(let file):
            ContinuousDiffEntry(content: .awaiting(file), openedByTheReader: openedByTheReader)
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
        case .failed(let file):
            .failed(file.viewed(isViewed))
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
