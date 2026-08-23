import Foundation

import CoreDiffDomain

/// A project as the Projects tab sees it: what the store remembers, and what this Mac can still find
/// behind it.
///
/// Distinct from the `Project` the API serves, and the difference is the point of design §4. The API
/// answers a phone and therefore describes only what is switched **on**; this tab is the switch, so
/// it describes everything a reader added — including the two states a phone must never be shown,
/// which are a project switched off and a project whose folder has gone.
public struct ManagedProject: Hashable, Sendable, Identifiable {

    public let id: ProjectID

    public let name: String

    /// The last known path, kept even after the folder has gone. It is where `Locate…` starts from,
    /// and it is the only thing that tells two projects sharing a name apart — which is why the row
    /// prints it under the name rather than behind a disclosure.
    public let path: String

    public let isVisible: Bool

    public let contents: ProjectContents

    /// How many of this project's worktrees have uncommitted work, or that nobody has counted yet.
    ///
    /// Separate from ``contents`` because the two are learned at different prices. The worktree
    /// count is one git invocation for the whole project; this is one **per worktree**, and the row
    /// draws long before it can be known.
    ///
    /// The one field here that is not a `let`, and the exception is what the two prices buy: it is
    /// assigned once, into a row that is already on screen, by whoever went and found out.
    public var worktreesWithChanges: WorktreesWithChanges

    public init(
        id: ProjectID,
        name: String,
        path: String,
        isVisible: Bool,
        contents: ProjectContents,
        worktreesWithChanges: WorktreesWithChanges
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.isVisible = isVisible
        self.contents = contents
        self.worktreesWithChanges = worktreesWithChanges
    }
}

/// What is behind a project's switch, as far as this Mac can tell.
///
/// The two failures are kept apart because only one of them is recoverable in this window: a folder
/// that moved is what `Locate…` exists for, and a folder that stopped being a checkout is not
/// something a folder picker fixes.
public enum ProjectContents: Hashable, Sendable {

    case worktrees(count: Int)

    /// Nothing is at the path any more.
    ///
    /// Today such a project still passes `isVisible`, so the API serves it with zero worktrees —
    /// which on a phone is indistinguishable from a project with nothing to read.
    case folderNotFound

    /// The folder is there and git will not call it a checkout.
    case notARepository
}

/// The count of worktrees with uncommitted work, which arrives after the row does.
public enum WorktreesWithChanges: Hashable, Sendable {

    /// Nobody has asked yet.
    ///
    /// Drawn rather than hidden, for the reason `GitInstallation.checking` is: a line that appears a
    /// moment after the row does makes the whole list jump. What it costs to leave `.counting` is
    /// one line of small print; what hiding it costs is every row below it moving.
    case counting

    case counted(Int)
}

/// A git repository a folder scan found, offered and not yet chosen.
///
/// A candidate is **not** a project. Design §4's whole argument is that a scan can only ever do the
/// first of this tab's two verbs, and this type is what carries the difference: it has no
/// identifier, no visibility and no place in the list until a reader has said so.
public struct RepositoryCandidate: Hashable, Sendable, Identifiable {

    /// The canonical path, which is both what identifies it and what would be added.
    public let path: String

    public let name: String

    /// Where it sits under the folder that was scanned.
    ///
    /// What tells `swift-nio` from `experiments/swift-nio` when one scan turns up two repositories
    /// with the same directory name, which is ordinary in a folder somebody has been working in for
    /// a year.
    public let relativePath: String

    public var id: String { path }

    public init(path: String, name: String, relativePath: String) {
        self.path = path
        self.name = name
        self.relativePath = relativePath
    }
}

/// Why something this tab was asked to do did not happen.
///
/// Two fields rather than one string, because this product's failure idiom is our sentence with the
/// system's demoted to small print — the same shape General's refused login item and the phone's
/// discovery failure already use. A store that refuses says `No space left on device`, which is true
/// and is not a sentence anybody wrote for a reader.
public struct ProjectsFailure: Hashable, Sendable {

    /// Ours, and always present.
    public let sentence: String

    /// The system's, when there is one. Absent where the refusal was ours to word in the first
    /// place, because repeating our own sentence in small print underneath it says nothing twice.
    public let reason: String?

    public init(sentence: String, reason: String?) {
        self.sentence = sentence
        self.reason = reason
    }
}

/// A folder scan, from the moment it is asked for to the moment a reader chooses.
///
/// There is no failed case, and that is deliberate rather than optimistic: a scan reports what it
/// found, and a directory somewhere under a home folder that could not be read is not a reason to
/// refuse a reader the thirty repositories that could.
public enum FolderScan: Hashable, Sendable {

    /// Drawn rather than waited on. A tree of a few thousand directories is fast and a home
    /// directory is not, and the difference is not something to find out with a frozen sheet.
    case scanning(root: URL)

    case found(root: URL, candidates: [RepositoryCandidate])

    /// The folder that was scanned, which the sheet names in both states so the count it reports is
    /// a scan's report rather than a surprise.
    public var root: URL {
        switch self {
        case .scanning(let root): root
        case .found(let root, _): root
        }
    }
}

/// What a folder scan refuses to look inside, and how far it goes.
///
/// Policy rather than walking, so it is here and asserted rather than buried in an enumerator. SPEC
/// §9 names the directories, and every one of them holds other people's checkouts in numbers that
/// would bury the repositories a reader filed on purpose.
public enum RepositoryScan {

    /// The specification's list, spelled exactly as SPEC §9 spells it.
    ///
    /// The §4 frames show `vendor/swift-nio` as a candidate, which this list makes impossible. The
    /// disagreement was put to Davide on 23 August 2026 and settled toward the specification: the
    /// drawing's row reads as an illustration of a nested path rather than as a call about vendored
    /// checkouts. See `design-mac.md`.
    public static let skippedDirectoryNames: Set<String> = [
        "node_modules",
        ".build",
        "DerivedData",
        "Pods",
        "vendor",
        "target"
    ]

    /// How far below the folder it was handed a scan goes.
    ///
    /// A scan is a person pointing at where they keep their work, not a search of the disk. Four
    /// covers the way development folders are actually arranged — a client, a year, a project — and
    /// refuses to turn a mis-aimed pick of the home directory into minutes of I/O.
    public static let maximumDepth = 4

    /// Whether a scan looks inside a directory with this name.
    ///
    /// Hidden directories are refused wholesale rather than named one at a time. Everything under a
    /// leading dot is a cache, a trash can or an agent's scratch space — including every worktree
    /// Claude Code creates, which lives under `.claude/worktrees` and is a checkout of a repository
    /// the reader already has.
    public static func descends(into directoryName: String) -> Bool {
        directoryName.hasPrefix(".") == false && skippedDirectoryNames.contains(directoryName) == false
    }
}

/// What this Mac can find on its own disk, behind a protocol like every other edge that leaves this
/// process.
///
/// Split from ``Store`` deliberately: the store owns what a reader **decided**, and this owns what
/// is still true of the disk they decided it about. The two disagree exactly when the interesting
/// states happen.
public protocol ProjectFolders: Sendable {

    /// What is behind one project's folder, at the price of a single git invocation.
    ///
    /// Deliberately does not count what has changed. That question costs an invocation per worktree
    /// and is answered separately, so that a reader opening this tab sees their list rather than a
    /// spinner.
    func contents(ofFolderAt path: String) async -> ProjectContents

    /// How many of a project's worktrees have uncommitted work.
    ///
    /// The expensive half, and the reason it is its own call. Measured at roughly a second per
    /// worktree on a large repository — sixteen worktrees of one Android monorepo took 16.7 — so
    /// whoever calls this has already drawn something.
    func worktreesWithChanges(inFolderAt path: String) async -> Int

    /// The git repositories under a folder, as candidates and nothing more.
    func repositories(under root: URL) async -> [RepositoryCandidate]
}
