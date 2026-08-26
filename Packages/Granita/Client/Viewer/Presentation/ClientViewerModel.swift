import Observation

import ClientConnectionDomain
import ClientViewerDomain
import CoreDiffDomain

/// What the phone knows about one worktree's changes, and which of them it has fetched.
///
/// **One model for the unit.** The continuous scroll, the file header and — when §3 arrives — the
/// selector are views onto one question: what changed here and how much of it has the reader seen.
///
/// It holds outcomes and one rule. The rule is that fetching runs strictly forward, and it lives in
/// `ContinuousDiffLoading` in `Domain` rather than here, because it is the thing `SPEC.md` §10 is
/// about and a policy buried in a model is a policy nobody tests directly.
@Observable
public final class ClientViewerModel {

    public private(set) var state: ContinuousDiffState = .loading

    /// The files this worktree changed, in the order the scroll draws them. Empty until the change
    /// set arrives.
    private var entries: [ContinuousDiffEntry] = []

    /// What has been asked for and not answered. Scrolling reports a position per file appearing,
    /// so without this the same five files would be re-requested on every one of them.
    private var inFlight: Set<FileID> = []

    private let worktree: WorktreeID
    private let repository: any GranitaRepository

    public init(worktree: WorktreeID, repository: any GranitaRepository) {
        self.worktree = worktree
        self.repository = repository
    }

    /// Reads what changed, which is the file list and the stats and never the hunks.
    ///
    /// The diffs follow, five at a time, driven by what the reader is looking at — because a
    /// forty-file worktree fetched in one request is a request that either times out or arrives
    /// long after the reader has read the first file.
    public func load() async {
        do {
            let changes = try await repository.changes(in: worktree)
            entries = changes.files.map(ContinuousDiffEntry.awaiting)
            state = entries.isEmpty ? .nothingChanged : .reading(entries)
        } catch {
            state = .failed(error)
        }
    }

    /// Says which file the reader has reached, and fetches ahead of them.
    ///
    /// **Nothing behind them is ever fetched**, which is `ContinuousDiffLoading`'s rule and the
    /// whole of §10's no-reflow trap: a file whose placeholder becomes real content above the
    /// viewport moves everything below it, the reader's own screen included.
    public func reading(_ position: Int) async {
        let wanted = ContinuousDiffLoading.next(
            from: position,
            of: entries.map(\.id),
            held: Set(entries.filter(\.isReady).map(\.id)),
            inFlight: inFlight
        )
        guard wanted.isEmpty == false else { return }
        inFlight.formUnion(wanted)
        defer { inFlight.subtract(wanted) }

        // A refusal here is deliberately not the screen's failure. The change set arrived, so the
        // reader has a list of files and their sizes; losing one batch of hunks leaves placeholders
        // where content would be, and the next thing they scroll to asks again. Replacing the whole
        // screen with an error because the fourth batch of twenty failed would throw away
        // everything they had already read.
        guard let diffs = try? await repository.diffs(of: wanted, in: worktree, contextLines: surroundingContext) else {
            return
        }
        for diff in diffs {
            guard let position = entries.firstIndex(where: { $0.id == diff.file.id }) else { continue }
            entries[position] = .ready(diff)
        }
        state = .reading(entries)
    }
}

// MARK: -

/// How much surrounding context each diff is fetched with. Three, which is git's own default and
/// what design §4's collapsed-context rule assumes.
///
/// A constant rather than a parameter: nothing varies it, and a seam no caller turns is API before
/// the reader — which in this repository is also an untested branch, because the initialiser nobody
/// calls with the other value is a region no test enters.
private let surroundingContext = 3

/// What the diff screen shows.
public enum ContinuousDiffState: Hashable, Sendable {

    case loading

    case failed(ApiFailure)

    /// The worktree is clean. Reachable from the sidebar's own "show them anyway", which is exactly
    /// how a reader gets to a quiet worktree on purpose.
    case nothingChanged

    case reading([ContinuousDiffEntry])
}

private extension ContinuousDiffEntry {

    var isReady: Bool {
        switch self {
        case .awaiting: false
        case .ready: true
        }
    }
}
