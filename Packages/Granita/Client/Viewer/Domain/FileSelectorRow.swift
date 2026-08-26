import CoreDiffDomain

/// One row of design §3's file selector, flattened out of the tree with the collapse state applied.
///
/// **The tree's shape and a file's state are joined here rather than in `Core`.** `FileTreeEntry`
/// carries an identifier and a path and deliberately nothing else, because the structure of a change
/// set is stable while status, stats and viewed churn under the reader — so the join happens one
/// layer up, which is this one.
public enum FileSelectorRow: Hashable, Sendable, Identifiable {

    case directory(FileSelectorDirectory)
    case file(FileSelectorFile)

    public var id: FileSelectorRowID {
        switch self {
        case .directory(let directory): .directory(directory.path)
        case .file(let file): .file(file.id)
        }
    }

    /// How many directories deep the row sits. The indent it earns is clamped; this is not.
    public var depth: Int {
        switch self {
        case .directory(let directory): directory.depth
        case .file(let file): file.depth
        }
    }

    public var directory: FileSelectorDirectory? {
        switch self {
        case .directory(let directory): directory
        case .file: nil
        }
    }

    public var file: FileSelectorFile? {
        switch self {
        case .directory: nil
        case .file(let file): file
        }
    }

    /// What one level of nesting costs, which design §3 derives rather than picks: at the clamp the
    /// indent is 56pt, the disclosure triangle takes 22, and about 284pt is left for the name — 33
    /// characters, head-truncated.
    public static let indentPerLevel: Double = 14

    /// Design §3's clamp. Past the fourth level the tree would be spending the row's only useful
    /// width on saying how deep it is, and a 77-character compacted path already shows its last 32.
    public static func indentLevel(atDepth depth: Int) -> Int {
        min(max(0, depth), 4)
    }
}

/// Identity for a row, and typed so that the two kinds cannot be confused for one another by a
/// `ForEach` — a file and the directory holding it are different rows with different jobs.
public enum FileSelectorRowID: Hashable, Sendable {
    case directory(String)
    case file(FileID)
}

/// A directory row, which may stand for a whole compacted chain rather than one directory.
public struct FileSelectorDirectory: Hashable, Sendable {

    /// Repo-relative path of the **deepest** directory the row stands for. Its identity, and what
    /// collapse state is remembered against.
    public let path: String

    /// What the row reads. A compacted chain keeps its separators, so `app/src/main/kotlin/com` is
    /// one row rather than four.
    public let name: String

    public let depth: Int

    public let isExpanded: Bool

    /// Summed over every descendant, and **only while the row is shut**.
    ///
    /// Design §3: an expanded directory carries none, because its children are right there with
    /// their own numbers and the parent's total becomes noise the reader has to subtract.
    public let stats: ChangeStats?

    /// Whether every file beneath this row — not merely every child — has been read.
    ///
    /// Unlike the total, this survives the row being open: "this whole subtree is done" is the most
    /// useful thing the tree can say, and it is as true expanded as it is shut.
    public let isEntirelyViewed: Bool

    public init(
        path: String,
        name: String,
        depth: Int,
        isExpanded: Bool,
        stats: ChangeStats?,
        isEntirelyViewed: Bool
    ) {
        self.path = path
        self.name = name
        self.depth = depth
        self.isExpanded = isExpanded
        self.stats = stats
        self.isEntirelyViewed = isEntirelyViewed
    }
}

/// A file row — the thing the reader taps to jump the scroll.
public struct FileSelectorFile: Hashable, Sendable {

    public let id: FileID

    /// Repo-relative, POSIX separators. Content, never an input to the API.
    public let path: String

    /// The directories above the file, separator included, or empty for a file at the root.
    ///
    /// **Flat mode's second run**, and the reason it is a field rather than something the label
    /// derives: design §3 makes flat "the same row with a different label", with the prefix
    /// secondary and the filename primary so that truncation erodes the prefix and never the name.
    /// Two runs in one text view is the only way that holds, and two runs need two strings.
    public let directoryPrefix: String

    /// The last path component, which is what the row reads in either mode.
    public let name: String

    public let depth: Int

    public let status: FileStatus

    public let stats: ChangeStats

    public let isViewed: Bool

    public init(
        id: FileID,
        path: String,
        directoryPrefix: String,
        name: String,
        depth: Int,
        status: FileStatus,
        stats: ChangeStats,
        isViewed: Bool
    ) {
        self.id = id
        self.path = path
        self.directoryPrefix = directoryPrefix
        self.name = name
        self.depth = depth
        self.status = status
        self.stats = stats
        self.isViewed = isViewed
    }
}

/// Which of design §3's two labels the list is drawing.
///
/// Not a second shape the domain owes: one row implementation, two labels, and the rows are in the
/// same order either way so that toggling does not reshuffle a list somebody was reading.
public enum FileSelectorMode: String, Hashable, Sendable, CaseIterable {
    case tree
    case flat
}

/// The one line under the list, and only when there is something true to put there.
public enum FileSelectorFooter: Hashable, Sendable {

    /// More files changed than this Mac serves at once.
    ///
    /// **It carries what was shown rather than what exists**, because what exists is not on the
    /// wire: the change set's own stats are summed over the files that were kept, so the total the
    /// design's frame prints is a number this client would have to invent. A sentence that is true
    /// beats a sentence that matches a drawing.
    case notAllServed(shown: Int)

    /// Every file this worktree served has been read.
    case everythingViewed(count: Int)
}

/// What the selector draws, in the arrangement it decided on.
public struct FileSelectorListing: Hashable, Sendable {

    /// The arrangement actually used, which is not always the one asked for: design §3 renders flat
    /// over three files or fewer, and over a change set that is all one directory.
    public let mode: FileSelectorMode

    public let rows: [FileSelectorRow]

    /// Whether a tree would say anything the flat list does not. When it would not, the control is
    /// **absent** rather than disabled — there is no second arrangement to offer.
    public let offersModeToggle: Bool

    public let footer: FileSelectorFooter?

    public init(
        mode: FileSelectorMode,
        rows: [FileSelectorRow],
        offersModeToggle: Bool,
        footer: FileSelectorFooter?
    ) {
        self.mode = mode
        self.rows = rows
        self.offersModeToggle = offersModeToggle
        self.footer = footer
    }
}
