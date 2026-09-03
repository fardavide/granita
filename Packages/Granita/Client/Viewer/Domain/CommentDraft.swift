import CoreDiffDomain

/// A run the reader has picked out and not yet said anything about.
///
/// **The two ends are in the order they were touched, not in the order they are drawn.** Ordering
/// them needs the diff — a deletion carries only an old number and an addition only a new one, so for
/// that pair no arithmetic says which comes first — and `CommentSelection.ends(of:from:to:)` is where
/// that happens. Until then this is a record of a gesture rather than an address.
public struct PendingComment: Hashable, Sendable {

    public let file: FileID
    public let from: DiffLinePosition
    public let to: DiffLinePosition

    public init(file: FileID, from: DiffLinePosition, to: DiffLinePosition) {
        self.file = file
        self.from = from
        self.to = to
    }
}

/// Tap, long press, tap — design §7.1's gesture, as the three states it actually is.
///
/// **A state machine in `Domain` rather than a pair of closures on a view**, which is this
/// repository's rule for any gesture that decides something: a `Ui` view reports what happened and
/// something a test can reach decides what it meant. What it decides here is not trivial — a held row
/// that scrolling must not cancel, a second tap that may land above the first or in another file, and
/// a tap that means *edit this comment* rather than *start one*.
///
/// **The held state exists because the gesture leaves the reader somewhere iOS has no convention
/// for**: one row is marked and the app is waiting for a second tap that may never come. Nothing in
/// the scroll can explain that, because every pixel of it is code — so §7.1 puts a sentence and a
/// Cancel in a bar at the bottom of the screen, and `heldEnd` is what raises it.
public enum CommentDraft: Hashable, Sendable {

    /// Nothing picked out. The capsule has this half of the screen.
    case idle

    /// One row held, waiting for the row that ends the run.
    ///
    /// **Scrolling does not leave this state**, which is design §7.1's rule and the reason the bar is
    /// needed at all: the other end may be off screen, and a selection that died when the reader went
    /// looking for it would be unusable.
    case holding(file: FileID, end: DiffLinePosition)

    /// A run picked out, with the composer over it.
    case composing(PendingComment)

    /// The row the reader is holding, if they are holding one.
    ///
    /// **Never true at the same time as `pending`.** The instruction bar and the review capsule share
    /// one position on screen, which is what design §7.4 spends to keep the capsule out of a toolbar
    /// that hides on scroll.
    public var heldEnd: DiffLinePosition? {
        switch self {
        case .holding(_, let end): end
        case .idle, .composing: nil
        }
    }

    /// The run the composer is open on, if it is open.
    public var pending: PendingComment? {
        switch self {
        case .composing(let pending): pending
        case .idle, .holding: nil
        }
    }

    /// The held row as a run of one, so the instruction bar can name it through the same resolution
    /// the composer's own header uses rather than a second spelling of it.
    public var held: PendingComment? {
        switch self {
        case .holding(let file, let end): PendingComment(file: file, from: end, to: end)
        case .idle, .composing: nil
        }
    }

    /// A tap on the gutter.
    ///
    /// From `idle` it is a comment on one row. From `holding` it is the second end — **and the hold
    /// is abandoned if the tap is in another file**, because a run cannot cross one and the next file
    /// is a few points down the same scroll. Refusing outright would leave the reader holding a row
    /// that a tap appeared to do nothing to, which is the dead control this project will not ship.
    public func tapped(_ end: DiffLinePosition, in file: FileID) -> CommentDraft {
        switch self {
        case .idle:
            .composing(PendingComment(file: file, from: end, to: end))
        case .holding(let held, let start):
            held == file
                ? .composing(PendingComment(file: file, from: start, to: end))
                : .composing(PendingComment(file: file, from: end, to: end))
        // Unreachable while the sheet is up — the diff behind it takes no gestures at the composer's
        // own detent. Answered rather than assumed: a tap that quietly replaced an open composer
        // would discard a paragraph without asking.
        case .composing:
            self
        }
    }

    /// A long press on the gutter, which begins a run.
    public func longPressed(_ end: DiffLinePosition, in file: FileID) -> CommentDraft {
        switch self {
        case .idle, .holding:
            .holding(file: file, end: end)
        case .composing:
            self
        }
    }

    /// The bar's Cancel, and the only way out of a hold that is not a second tap.
    public func cancelled() -> CommentDraft {
        .idle
    }
}
