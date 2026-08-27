import Observation

import ClientConnectionDomain
import ClientViewerDomain
import CoreDiffDomain

/// What the phone knows about one worktree's changes, and which of them it has fetched.
///
/// **One model for the unit.** The continuous scroll, the file header and §3's selector are views
/// onto one question: what changed here and how much of it has the reader seen. The selector is not
/// a second list — it is the same change set, arranged.
///
/// It holds outcomes and two rules, and both live in `Domain` rather than here because each is the
/// thing a specification section is about and a policy buried in a model is a policy nobody tests
/// directly: fetching runs strictly forward (`ContinuousDiffLoading`), and §3's arrangement,
/// aggregation and footer are one pure function (`FileSelector`).
@Observable
public final class ClientViewerModel {

    public private(set) var state: ContinuousDiffState = .loading

    /// The file selector's rows, in the arrangement it settled on.
    public private(set) var selector = FileSelectorListing(
        mode: .tree,
        rows: [],
        offersModeToggle: false,
        footer: nil
    )

    /// Which file the scroll has been asked to jump to, and nothing about how far it got.
    ///
    /// **Cleared by the screen once it has scrolled**, which is what makes tapping the same row
    /// twice work. Held as the value alone, a second tap on a file the reader has since scrolled
    /// away from would be a change from a value to itself — no change, no scroll, and a row that
    /// did nothing.
    public private(set) var jumpTarget: FileID?

    /// The refusal the Mac gave the last time a mark was written, if it gave one.
    public private(set) var viewedFailure: ApiFailure?

    /// Whether §3's drawer is up.
    ///
    /// **It is the model's rather than the screen's**, which is a rule this repository wrote down
    /// the day the Mac's Devices tab needed opening from a menu: a control whose only effect is a
    /// `@State` two layers up is a control nothing can be asked about. Here it also decides what a
    /// baseline can see — the drawer is the phone's only way to the file list, and a presented state
    /// no test can set is a screen photographed with its main affordance shut.
    ///
    /// Only the phone has one. In a regular width the selector is a column and this is never read.
    public private(set) var isShowingSelector = false

    /// The arrangement the reader asked for, which is not always the one they get: over three files,
    /// or over a change set that is all one directory, `FileSelector` answers flat regardless.
    private var mode: FileSelectorMode = .tree

    /// Directory rows the reader has shut, by the path that identifies them. Seeded from the change
    /// set, because design §3 arrives with a crowded directory already closed.
    private var collapsed: Set<String> = []

    /// The files this worktree changed, in the order the scroll draws them. Empty until the change
    /// set arrives.
    private var entries: [ContinuousDiffEntry] = []

    /// Whether more files changed than this Mac serves at once, which the footer says and nothing
    /// else does.
    private var isTruncated = false

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
    /// **A cancelled read leaves the screen alone**, for the reason the worktree list does: a
    /// `.task` is torn down whenever its view goes away, and reporting that as the Mac's failure is
    /// the app blaming the Mac for something the app did.
    public func load() async {
        // Only a failure goes back to the spinner — a screen re-runs its `.task` every time it
        // appears, and blanking a diff that is already drawn would restart it under the reader. See
        // `ClientWorktreesModel`, which carries the argument and the baselines that settled it.
        if case .failed = state {
            state = .loading
        }
        do {
            let changes = try await repository.changes(in: worktree)
            entries = changes.files.map(ContinuousDiffEntry.awaiting)
            isTruncated = changes.isTruncated
            collapsed = FileSelector.initiallyCollapsed(in: changes.files)
            state = entries.isEmpty ? .nothingChanged : .reading(entries)
            rearrange()
        } catch .cancelled {
            state = entries.isEmpty ? .loading : .reading(entries)
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
            // The mark is the phone's, and a diff arriving is the Mac answering a question that was
            // asked before it was written. Keeping what is on screen stops a mark the reader has
            // just set being taken back off by a batch that was already in flight.
            entries[position] = .ready(diff).viewed(entries[position].file.isViewed)
        }
        state = .reading(entries)
    }

    public func showSelector(_ isShowing: Bool) {
        isShowingSelector = isShowing
    }

    /// Asks the scroll to go to a file, which is the selector's entire job.
    ///
    /// **The drawer stays up**, which is the whole of design §3's argument for a drawer over a
    /// modal: the reader walks a change set file by file without a dismiss-present cycle between
    /// each one, and the diff scrolls behind the list while they do.
    public func choose(_ file: FileID) {
        jumpTarget = file
    }

    /// Reported by the screen once it has scrolled, so the next tap on the same row is a change
    /// again rather than a silent no-op.
    public func didJump() {
        jumpTarget = nil
    }

    public func show(_ mode: FileSelectorMode) {
        self.mode = mode
        rearrange()
    }

    public func toggle(_ directory: String) {
        if collapsed.remove(directory) == nil {
            collapsed.insert(directory)
        }
        rearrange()
    }

    /// Marks a file read, or unread, against the content that was read.
    ///
    /// **Written optimistically and taken back on a refusal**, which is the shape every write in
    /// this app uses: the row has to change under the finger, and the Mac is a network away. What
    /// makes taking it back honest rather than confusing is that the reader is told — a mark that
    /// silently reverted would be the app disagreeing with them about the one thing it is for.
    public func setViewed(_ isViewed: Bool, on file: FileID) async {
        guard let position = entries.firstIndex(where: { $0.id == file }) else { return }
        let before = entries[position]
        entries[position] = before.viewed(isViewed)
        state = .reading(entries)
        rearrange()

        do {
            try await repository.markViewed(
                isViewed,
                file: file,
                // The file's own hash rather than the worktree's revision: the Mac refuses a mark
                // applied to content nobody saw, and refusing it is better than applying it.
                contentHash: before.file.contentHash,
                in: worktree
            )
        } catch .cancelled {
            // The reader left; the mark they set stands. Taking it back and telling them the Mac
            // refused would be the app inventing a refusal nobody made.
            return
        } catch {
            // Found again rather than reused, because the batch loader may have replaced this entry
            // while the write was in flight — and putting the stale one back would drop a diff.
            if let now = entries.firstIndex(where: { $0.id == file }) {
                entries[now] = entries[now].viewed(before.file.isViewed)
                state = .reading(entries)
                rearrange()
            }
            viewedFailure = error
        }
    }

    public func dismissViewedFailure() {
        viewedFailure = nil
    }

    private func rearrange() {
        selector = FileSelector.listing(
            of: entries.map(\.file),
            mode: mode,
            collapsed: collapsed,
            isTruncated: isTruncated
        )
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

private extension ContinuousDiffEntry {

    var isReady: Bool {
        switch self {
        case .awaiting: false
        case .ready: true
        }
    }
}
