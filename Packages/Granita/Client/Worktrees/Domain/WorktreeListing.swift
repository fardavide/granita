import Foundation

import ClientConnectionDomain
import CoreDiffDomain

/// How the sidebar arranges itself.
///
/// A preference rather than a filter, which is why it is two cases and not a predicate: the same
/// worktrees are in both, in a different order and under different headers.
public enum WorktreeListMode: String, CaseIterable, Codable, Hashable, Sendable {
    case groupedByProject
    case mostRecentFirst
}

/// Whether the row's name can be trusted to say what the agent did.
///
/// Four fields resolve into the display name and the reader does not need to know which one won.
/// They need to know one thing, and this is it: an alias can say what happened here, a session
/// summary can, a branch name usually can, and a generated directory name never can.
public enum WorktreeNameTier: Hashable, Sendable {
    case named
    case machineGenerated
}

/// What goes where `+n −m` would.
///
/// An enum rather than three integers and two booleans, because two of the three cases are the
/// *absence* of numbers and one of those absences means something quite different from zero.
public enum WorktreeRowStats: Hashable, Sendable {

    /// HEAD names no commit, so everything compares against the empty tree and the real figures are
    /// the whole repository — a lie about what changed here.
    case noCommitsYet

    case noChanges
    case changed(filesChanged: Int, insertions: Int, deletions: Int)
}

/// How long ago the worktree last moved, coarse enough to fit the two or three characters the row
/// can spare for it.
///
/// Coarse on purpose: the question this column answers is whether the agent finished a moment ago
/// or yesterday, and a minute of precision on a three-day-old worktree is noise.
public enum WorktreeAge: Hashable, Sendable {

    case underAMinute
    case minutes(Int)
    case hours(Int)
    case days(Int)

    /// Built from a plain interpolation rather than a format style, so the string is the same on
    /// every machine that renders a baseline. A locale reaches a picture through number formatting,
    /// and this column is the one place a phone would otherwise disagree with a runner.
    public var label: String {
        switch self {
        case .underAMinute: "now"
        case .minutes(let minutes): "\(minutes)m"
        case .hours(let hours): "\(hours)h"
        case .days(let days): "\(days)d"
        }
    }

    /// Both clocks here are real and nothing keeps them together — the moment comes from a Mac and
    /// `now` from this phone — so a worktree touched in this phone's future is ordinary rather than
    /// impossible, and it reads as "now" rather than as a negative count.
    public init(of moment: Date, at now: Date) {
        let seconds = max(0, Int(now.timeIntervalSince(moment)))
        self = switch seconds {
        case ..<60: .underAMinute
        case ..<3_600: .minutes(seconds / 60)
        case ..<86_400: .hours(seconds / 3_600)
        default: .days(seconds / 86_400)
        }
    }
}

/// Where a worktree's name comes from once the alias is taken out of it.
///
/// The rename sheet needs this and the row does not: with no suggestion to offer, the sheet's
/// section is absent and the footer has to say *why* in the reader's terms — which is what turns an
/// empty sheet into an explanation rather than a blank.
public enum WorktreeDerivedNameSource: Hashable, Sendable {
    case sessionSuggestion
    case branch
    case directory
}

/// Everything the rename sheet needs, resolved once so the sheet and the row it was opened from
/// cannot spell the same fallback two ways.
public struct WorktreeRenameSubject: Identifiable, Hashable, Sendable {

    /// The worktree being renamed is already the identity, so a presented sheet keyed on this cannot
    /// stay up over a different row than the one it was opened from.
    public var id: WorktreeID { worktree }

    public let worktree: WorktreeID
    public let alias: String?
    public let suggestedAlias: String?

    /// What the row will read once the alias is cleared — the server's own resolution with the
    /// alias taken out of it. The sheet's footer states this out loud before the reader saves, so
    /// anything else here would be a sentence that turns out to be untrue one tap later.
    ///
    /// It follows the suggestion where there is one, which is the one place this repository reads
    /// design §2's drawings as sample data rather than as the call: the frames preview the branch
    /// while a suggestion is on screen, and the row would not read that.
    public let derivedName: String

    public let derivedNameSource: WorktreeDerivedNameSource

    public init(
        worktree: WorktreeID,
        alias: String?,
        suggestedAlias: String?,
        derivedName: String,
        derivedNameSource: WorktreeDerivedNameSource
    ) {
        self.worktree = worktree
        self.alias = alias
        self.suggestedAlias = suggestedAlias
        self.derivedName = derivedName
        self.derivedNameSource = derivedNameSource
    }
}

/// Everything the confirmation needs before a checkout is taken off the Mac.
///
/// Resolved on the row for the same reason the rename sheet's subject is: the display name is the
/// Mac's resolution of four fields and the row is where that lands, so a confirmation naming the
/// worktree a second way is a confirmation that can name a different one.
public struct WorktreeDeletionSubject: Identifiable, Hashable, Sendable {

    /// The worktree is the identity, so a dialog keyed on this cannot stay up over a different row
    /// than the one it was opened from.
    public var id: WorktreeID { worktree }

    public let worktree: WorktreeID
    public let displayName: String

    /// What is about to be lost, in the row's own words.
    ///
    /// **The confirmation is the only place the cost is stated**, because the removal is forced: the
    /// uncommitted work this whole app exists to show is what goes with the directory. A dialog that
    /// only named the worktree would be asking the reader to agree to something it had not said.
    public let stats: WorktreeRowStats

    /// Whether the Mac holds a lock on this checkout, which the deletion overrides.
    ///
    /// **Carried so the confirmation can say it, which is the whole of what a lock now does.** It
    /// used to refuse the deletion outright. It does not, because Claude Code locks every worktree it
    /// creates and refusing there is refusing on every row — so what is left is telling the reader
    /// before they agree, in the one dialog that states everything else this destroys.
    public let isLocked: Bool

    public init(worktree: WorktreeID, displayName: String, stats: WorktreeRowStats, isLocked: Bool) {
        self.worktree = worktree
        self.displayName = displayName
        self.stats = stats
        self.isLocked = isLocked
    }
}

/// Whether this worktree can be taken off the Mac, and when it cannot, why.
///
/// A reason rather than a boolean, because a control that is **absent** and a control that is
/// **disabled and says why** are different answers to "why can I not do this here" — and a boolean
/// has already thrown away the half that lets the screen give either.
public enum WorktreeDeletability: Hashable, Sendable {

    case deletable(WorktreeDeletionSubject)

    /// The repository itself rather than a checkout of it. Git refuses outright and so does the Mac.
    ///
    /// **The only one of these left, and it was two.** A locked worktree used to be the other, on the
    /// grounds that a lock a phone can wave through is not a lock. Nobody sets one by hand and Claude
    /// Code sets one on every worktree it creates, so that rule refused the control on essentially
    /// every row in the list — and a control refused everywhere it is offered is the thing forcing
    /// the removal was chosen to avoid. A lock is now said in the confirmation instead of enforced
    /// here.
    case primaryCheckout

    /// Why this worktree cannot be deleted, said to the reader asking, and `nil` where it can be.
    ///
    /// **Here rather than in the control that draws it**, and for the reason that decides everything
    /// else on this row: what a screen puts in front of a reader is asserted without a renderer. A
    /// context menu is presented by the system into an overlay no snapshot includes, so a sentence
    /// written inside that closure is a sentence nothing in this repository can hold to its words —
    /// and these two exist precisely to stop a row that will not delete reading as an app that does
    /// not work. `WorktreeAge.label` is the precedent for a reader-facing string resolved here.
    ///
    /// The sentence and its symbol come back together rather than from two properties, so there is
    /// no arrangement in which one is present and the other is not.
    public var refusal: (sentence: String, symbol: String)? {
        switch self {
        case .deletable: nil
        case .primaryCheckout: ("The project’s own checkout can’t be deleted", "house")
        }
    }
}

/// One row of the sidebar, with every drop and flag decision already made.
///
/// Decided here rather than in a view body, which is what lets design §2's ordering and drop rules
/// be asserted without a renderer.
public struct WorktreeListRow: Identifiable, Hashable, Sendable {

    public let id: WorktreeID
    public let displayName: String
    public let nameTier: WorktreeNameTier

    /// Present in flat mode, where no header carries it, and on a pinned row in grouped mode, which
    /// sits above its own project's section and would otherwise read as orphaned rather than as
    /// annotated.
    public let projectName: String?

    /// Earns a word: it is the checkout the agent did *not* work in, which also explains why that
    /// row usually has no changes — otherwise the most confusing row in the list.
    public let isPrimaryCheckout: Bool

    /// Earns a word only when the name fell through to the directory. Then it is not a flag, it is
    /// the answer to "why is this row a random string?".
    public let showsDetached: Bool

    public let stats: WorktreeRowStats
    public let age: WorktreeAge

    /// Flat mode has no section header to carry the pin, so the row draws it there and only there.
    /// One or the other, never both.
    public let showsPinIndicator: Bool

    public let isPinned: Bool
    public let rename: WorktreeRenameSubject

    /// Whether this row may offer to destroy what it names, and what the confirmation says if it
    /// does.
    ///
    /// Decided here rather than in a view body for the reason every other rule on this row is: the
    /// worktree that must never be offered is one a rendered screen would not tell you about, and
    /// design §2's row does not draw it differently.
    public let deletion: WorktreeDeletability

    public init(of worktree: Worktree, mode: WorktreeListMode, now: Date) {
        // `isLocked` was read nowhere for a recorded reason: v1 could not prune worktrees, which was
        // the only operation the flag blocked. It can now, so the flag travels into the confirmation
        // below — it says what the deletion is overriding, and no longer refuses it.
        let isNamed = worktree.alias != nil || worktree.suggestedAlias != nil || worktree.branch != nil
        id = worktree.id
        displayName = worktree.displayName
        nameTier = isNamed ? .named : .machineGenerated
        projectName = switch mode {
        case .mostRecentFirst: worktree.projectName
        case .groupedByProject: worktree.isPinned ? worktree.projectName : nil
        }
        isPrimaryCheckout = worktree.isPrimary
        showsDetached = worktree.isDetached && isNamed == false
        stats = if worktree.hasUnbornHead {
            .noCommitsYet
        } else if worktree.stats.filesChanged == 0 {
            .noChanges
        } else {
            .changed(
                filesChanged: worktree.stats.filesChanged,
                insertions: worktree.stats.insertions,
                deletions: worktree.stats.deletions
            )
        }
        age = WorktreeAge(of: worktree.lastModified, at: now)
        showsPinIndicator = worktree.isPinned && mode == .mostRecentFirst
        isPinned = worktree.isPinned
        let derived: (name: String, source: WorktreeDerivedNameSource) = if let suggested = worktree.suggestedAlias {
            (suggested, .sessionSuggestion)
        } else if let branch = worktree.branch {
            (branch, .branch)
        } else {
            (worktree.directoryName, .directory)
        }
        rename = WorktreeRenameSubject(
            worktree: worktree.id,
            alias: worktree.alias,
            suggestedAlias: worktree.suggestedAlias,
            derivedName: derived.name,
            derivedNameSource: derived.source
        )
        // A lock no longer decides this — it travels into the confirmation instead, so the reader is
        // told rather than refused.
        deletion = if worktree.isPrimary {
            .primaryCheckout
        } else {
            .deletable(WorktreeDeletionSubject(
                worktree: worktree.id,
                displayName: worktree.displayName,
                stats: stats,
                isLocked: worktree.isLocked
            ))
        }
    }
}

/// One run of rows under one header, or under none.
public struct WorktreeListSection: Identifiable, Hashable, Sendable {

    /// Also the identity, because there is exactly one section per kind and a project cannot appear
    /// twice. Two projects may share a name — two folders both called `granita` — so the identifier
    /// is what separates them and the name is only what is drawn.
    public enum Kind: Hashable, Sendable {
        case pinned
        case project(ProjectID, name: String)
        case everything
    }

    public let id: Kind
    public let rows: [WorktreeListRow]

    public init(id: Kind, rows: [WorktreeListRow]) {
        self.id = id
        self.rows = rows
    }
}

/// The sidebar's rows, arranged.
public struct WorktreeListing: Hashable, Sendable {

    public let sections: [WorktreeListSection]

    /// How many worktrees with no changes were left out.
    ///
    /// Carried rather than left to a reader to notice, because it is what reconciles this list with
    /// the count on the Mac: the list *states* what it is hiding, so the two cannot silently
    /// contradict each other.
    public let quietCount: Int

    public init(sections: [WorktreeListSection], quietCount: Int) {
        self.sections = sections
        self.quietCount = quietCount
    }

    public init(of worktrees: [Worktree], mode: WorktreeListMode, showingQuiet: Bool, now: Date) {
        let shown = showingQuiet ? worktrees : worktrees.filter { $0.stats.filesChanged > 0 }
        quietCount = worktrees.count - shown.count
        sections = switch mode {
        case .mostRecentFirst:
            shown.isEmpty ? [] : [
                WorktreeListSection(
                    id: .everything,
                    rows: WorktreeListing.mostRecentFirst(shown).map {
                        WorktreeListRow(of: $0, mode: mode, now: now)
                    }
                )
            ]
        case .groupedByProject:
            WorktreeListing.grouped(shown, now: now)
        }
    }

    /// Pinned above everything, and only then most recently changed first. Pinning is the reader
    /// saying "keep this in front of me", which outranks what an agent happened to touch last.
    private static func mostRecentFirst(_ worktrees: [Worktree]) -> [Worktree] {
        worktrees.sorted { first, second in
            if first.isPinned != second.isPinned {
                return first.isPinned
            }
            if first.lastModified != second.lastModified {
                return first.lastModified > second.lastModified
            }
            return first.displayName < second.displayName
        }
    }

    private static func grouped(_ worktrees: [Worktree], now: Date) -> [WorktreeListSection] {
        // A pinned row is *lifted* into the Pinned section rather than copied into it: a row that
        // appears twice is a worse bug than a row that appears once in a surprising place, which is
        // exactly what the project name on line two is there to explain.
        let pinned = worktrees.filter(\.isPinned)
        let byProject = Dictionary(grouping: worktrees.filter { $0.isPinned == false }) { $0.projectId }

        // Activity, not the alphabet: the project the agent was in five minutes ago is the one
        // being opened. The name only breaks a tie, so that two identical reads cannot reshuffle.
        let projects = byProject.keys.sorted { first, second in
            let left = byProject[first] ?? []
            let right = byProject[second] ?? []
            let leftLatest = left.map(\.lastModified).max() ?? .distantPast
            let rightLatest = right.map(\.lastModified).max() ?? .distantPast
            if leftLatest != rightLatest {
                return leftLatest > rightLatest
            }
            return (left.first?.projectName ?? "") < (right.first?.projectName ?? "")
        }

        let pinnedSection = pinned.isEmpty ? [] : [
            WorktreeListSection(
                id: .pinned,
                rows: mostRecentFirst(pinned).map {
                    WorktreeListRow(of: $0, mode: .groupedByProject, now: now)
                }
            )
        ]
        return pinnedSection + projects.compactMap { project in
            guard let members = byProject[project], let name = members.first?.projectName else { return nil }
            return WorktreeListSection(
                id: .project(project, name: name),
                rows: mostRecentFirst(members).map {
                    WorktreeListRow(of: $0, mode: .groupedByProject, now: now)
                }
            )
        }
    }
}

/// What the sidebar has to draw, which is not always a list.
///
/// Flat rather than a loaded case wrapping an empty case, because the view switches over it once
/// and every one of these is a different sentence rather than a different amount of the same one.
///
/// The two empty cases are told apart without asking the Mac a second question: a project always
/// has at least its primary checkout, so no worktrees at all means nothing is enabled over there,
/// while worktrees that are all clean means the Mac is serving and there is simply nothing to read.
public enum WorktreeSidebarState: Hashable, Sendable {

    case loading
    case failed(ApiFailure)
    case noProjects
    case allQuiet(worktreeCount: Int, projectNames: [String])
    case listing(WorktreeListing)

    /// Whether the toolbar menu has anything to offer.
    ///
    /// Absent rather than disabled on the three states where it has not: a menu over a screen that
    /// says no repository is enabled offers to rearrange nothing, and design §2's own frame for that
    /// state draws no control in the bar at all.
    public var isArrangeable: Bool {
        switch self {
        case .loading, .failed, .noProjects: false
        case .allQuiet, .listing: true
        }
    }

    public init(of worktrees: [Worktree], mode: WorktreeListMode, showingQuiet: Bool, now: Date) {
        let listing = WorktreeListing(of: worktrees, mode: mode, showingQuiet: showingQuiet, now: now)
        if worktrees.isEmpty {
            self = .noProjects
        } else if listing.sections.isEmpty {
            self = .allQuiet(
                worktreeCount: worktrees.count,
                projectNames: Set(worktrees.map(\.projectName)).sorted()
            )
        } else {
            self = .listing(listing)
        }
    }
}
