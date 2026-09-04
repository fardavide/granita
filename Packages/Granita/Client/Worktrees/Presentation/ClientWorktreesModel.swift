import Foundation
import Observation

import ClientConnectionDomain
import ClientWorktreesDomain
import CoreDiffDomain

/// What the phone knows about the checkouts on a Mac it has paired with.
///
/// **One model for the unit, not one per screen.** The sidebar, its rename sheet and the two
/// switches in its toolbar menu are all views onto one question — which worktree is being read —
/// so they share this rather than each bringing state of their own.
///
/// The worktrees are held and the arrangement is derived, which is what makes changing mode or
/// showing the quiet ones instant: the same answer from the Mac serves every arrangement, and a
/// round trip to reorder a list already on screen would be a spinner in exchange for nothing.
@Observable
public final class ClientWorktreesModel {

    /// What the reader calls the Mac these worktrees are on, which design §5 makes the list's title.
    ///
    /// It sits on the model rather than being threaded through the split view into the sidebar,
    /// because it is a fact about the Mac this model reads from — the same reason the repository
    /// under it is per Mac — and because the detail column will want the same string once §3 gives
    /// it something to show.
    public let macName: String

    public private(set) var state: WorktreeSidebarState = .loading
    public private(set) var mode: WorktreeListMode
    public private(set) var showsQuietWorktrees: Bool

    /// The subject of the open rename sheet, and `nil` when there is none. The row resolves it, so
    /// the sheet and the row it came from cannot spell the same fallback two ways.
    public private(set) var renaming: WorktreeRenameSubject?

    /// The worktree a confirmation is currently up for, and `nil` when there is none.
    ///
    /// The subject is resolved by the row, the way the rename sheet's is, so the dialog and the row
    /// it was opened from cannot name the worktree — or what is in it — two different ways.
    public private(set) var deleting: WorktreeDeletionSubject?

    /// The worktrees this Mac is being asked to destroy right now.
    ///
    /// **A set rather than one identifier**, because confirming one, swiping a second and confirming
    /// that too is reachable at LAN speed: an optional would let the second deletion's completion
    /// clear the first one's mark and put a row back in the list that is still being removed.
    ///
    /// A row in here is dimmed, says so, and is not operable — it cannot be deleted twice, renamed,
    /// pinned or opened while the directory behind it is going away.
    public private(set) var removing: Set<WorktreeID> = []

    /// A write the Mac refused, carrying **which** write it was.
    ///
    /// Renaming and pinning both leave the row exactly where it was on failure, and without this
    /// that is a swipe that appears to have done nothing. A refused deletion is a different
    /// sentence, which is what the operation travels for.
    public private(set) var writeFailure: WorktreeWriteRefusal?

    private var worktrees: [Worktree] = []
    private let repository: any GranitaRepository
    private let preferences: any WorktreeListPreferences
    private let now: @Sendable () -> Date

    public init(
        macName: String,
        repository: any GranitaRepository,
        preferences: any WorktreeListPreferences,
        now: @escaping @Sendable () -> Date
    ) {
        self.macName = macName
        self.repository = repository
        self.preferences = preferences
        self.now = now
        mode = preferences.mode()
        showsQuietWorktrees = preferences.showsQuietWorktrees()
    }

    /// Reads every worktree the Mac is serving, across all enabled projects.
    ///
    /// One request rather than one per project: the grouping is this side's arrangement of a single
    /// answer, and asking per project would make the order the list is drawn in depend on which
    /// request finished first.
    /// Reads the Mac's worktrees, and says it is doing so.
    ///
    /// **The spinner is the retry's only feedback.** `/v1/worktrees` builds a change set for every
    /// worktree of every enabled project, which on ten real repositories has been measured at over
    /// two minutes — so a *Try Again* that left the failure on screen was indistinguishable from a
    /// button with nothing behind it, and was reported as one. Going back to `loading` costs nothing
    /// on the first read, where that is already the state.
    ///
    /// **A cancelled read is not a failure.** A `.task` is torn down whenever its view goes away, so
    /// opening a worktree while this is still loading cancels it — and reporting that as *Could not
    /// read your Mac* is the app blaming the Mac for something the app did.
    public func load() async {
        // **Only a failure goes back to the spinner**, and the snapshot suites are what settled
        // that: blanking on every read photographed a spinner on screens that had already loaded,
        // because a screen re-runs its `.task` every time it appears — so coming back to the
        // worktree list would have emptied it and started again under the reader. Content on screen
        // stays on screen while it is re-read; a failure has nothing to keep.
        if case .failed = state {
            state = .loading
        }
        do {
            worktrees = try await repository.worktrees(inProject: nil)
            state = arrangement
        } catch .cancelled {
            state = arrangement
        } catch {
            state = .failed(error)
        }
    }

    public func show(_ mode: WorktreeListMode) {
        self.mode = mode
        preferences.remember(mode)
        rearrange()
    }

    public func showQuietWorktrees(_ shows: Bool) {
        showsQuietWorktrees = shows
        preferences.rememberShowingQuietWorktrees(shows)
        rearrange()
    }

    public func beginRenaming(_ subject: WorktreeRenameSubject) {
        renaming = subject
    }

    public func cancelRenaming() {
        renaming = nil
    }

    /// Writes an alias and nothing else. **Never touches git** — the name is this reader's word for
    /// a checkout, not a branch, and renaming one on a phone must not rewrite anything on the Mac
    /// that an agent is working in.
    ///
    /// Whitespace alone clears it rather than storing it. An alias of three spaces would draw a row
    /// with no name at all, and the patch has a case for absence precisely so it need not be faked
    /// with an empty string.
    public func rename(_ worktree: WorktreeID, to alias: String) async {
        let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        await write(WorktreePatch(alias: trimmed.isEmpty ? .cleared : .set(trimmed), isPinned: nil), to: worktree)
        renaming = nil
    }

    public func setPinned(_ pinned: Bool, on worktree: WorktreeID) async {
        await write(WorktreePatch(alias: .unchanged, isPinned: pinned), to: worktree)
    }

    public func beginDeleting(_ subject: WorktreeDeletionSubject) {
        deleting = subject
    }

    public func cancelDeleting() {
        deleting = nil
    }

    /// Asks the Mac to take the confirmed worktree away, and drops the row once it has.
    ///
    /// **The subject is a parameter and that is load-bearing rather than tidy.** It used to be read
    /// back off `deleting`, and that made this a silent no-op: dismissing an alert writes `false`
    /// through its `isPresented` binding, which clears `deleting` synchronously, while the button's
    /// own `Task` body does not run until a later turn on the main actor. By then there was nothing
    /// left to delete and the control did nothing at all — with every baseline still green, because
    /// a raster does not include an alert and cannot press a button. Passing the value the
    /// confirmation was presented with also makes the guarantee the stronger one: what is destroyed
    /// is what was confirmed, never whatever the model happens to hold when the tap lands.
    ///
    /// **The row goes only once the Mac says it is gone.** Dropping it optimistically the way a
    /// rename does is wrong here for a reason renaming does not have — a rename that silently failed
    /// shows the wrong name until the next read, and a deletion that silently failed shows a
    /// worktree that still exists as destroyed, which nobody goes looking for.
    ///
    /// A worktree the Mac says it no longer has is a success rather than a failure. The reader asked
    /// for it gone and it is gone; the only difference is who removed it, and there is nothing to do
    /// about that.
    public func confirmDeletion(of subject: WorktreeDeletionSubject) async {
        deleting = nil
        removing.insert(subject.worktree)
        // On every path, including the two failures. A `defer` that fired on only one would leave a
        // row dimmed and inoperable for the rest of the session with nothing to un-dim it.
        defer { removing.remove(subject.worktree) }

        do {
            try await repository.delete(subject.worktree)
        } catch .worktreeGone {
            // An agent removes one every day, so the read this row came from can be out of date by
            // the time the reader confirms.
        } catch {
            writeFailure = .deletion(error)
            return
        }
        worktrees.removeAll { $0.id == subject.worktree }
        rearrange()
    }

    public func dismissWriteFailure() {
        writeFailure = nil
    }

    /// Puts down whatever the one alert was showing.
    ///
    /// **A decision rather than a convenience**, which is why it is here and not in the binding that
    /// calls it: one modifier serves a confirmation and a refusal, so dismissing it means two
    /// different things, and getting that wrong leaves a refusal on screen that cannot be closed or
    /// silently arms a deletion. A rule in a view's setter closure is a rule no test here can reach.
    ///
    /// The order matches the prompt's: a refusal wins where both are somehow set.
    public func dismissPrompt() {
        if writeFailure != nil {
            dismissWriteFailure()
        } else {
            cancelDeleting()
        }
    }

    /// What the row was showing for this worktree, so the screen it opens is titled the thing that
    /// was tapped.
    ///
    /// Read off the arranged rows rather than off the raw worktrees, because the display name is
    /// the Mac's resolution of four fields and the row is the only place that resolution lands.
    ///
    /// The fallback is a word rather than an empty title: an agent removes a worktree every day, so
    /// one can stop being in the list between the tap and the push, and every state that is not a
    /// listing holds no rows at all.
    public func displayName(of worktree: WorktreeID) -> String {
        guard case .listing(let listing) = state else { return "This worktree" }
        return listing.sections.flatMap(\.rows).first { $0.id == worktree }?.displayName ?? "This worktree"
    }

    /// Which repository this worktree is a checkout of, for the one place the phone has to name it.
    ///
    /// **Read off the worktrees rather than off the rows, which is the opposite of `displayName`.**
    /// A row's `projectName` is deliberately absent whenever the list is grouped by project — the
    /// section heading is already saying it, and §2 drops the field from the row rather than printing
    /// it twice. The raw worktree always carries it, and this is a fact about the checkout rather than
    /// about how the list happens to be arranged.
    ///
    /// A word rather than an empty string when the worktree is not in hand, for the reason
    /// `displayName` has one: an agent removes a worktree every day, so one can stop being in the
    /// list between the tap and the push.
    public func projectName(of worktree: WorktreeID) -> String {
        worktrees.first { $0.id == worktree }?.projectName ?? "this project"
    }

    /// Puts the Mac's own answer back in the list rather than the patch that was sent, because the
    /// display name is resolved over there: a row updated from the request would show the alias
    /// while the Mac had decided something else was the name.
    private func write(_ patch: WorktreePatch, to worktree: WorktreeID) async {
        do {
            let updated = try await repository.update(worktree, with: patch)
            guard let index = worktrees.firstIndex(where: { $0.id == worktree }) else {
                // The row was read, swiped, and answered for after it stopped being in the list —
                // an agent removes a worktree every day. Appending the answer would put a row on
                // screen that the last read said is gone.
                writeFailure = .edit(.worktreeGone)
                return
            }
            worktrees[index] = updated
            rearrange()
        } catch {
            writeFailure = .edit(error)
        }
    }

    /// Rearranges a list that is on screen and leaves every other state alone.
    ///
    /// The guard is what stops the toolbar menu from answering a question nothing has asked yet:
    /// the menu is reachable while the first request is in flight, and an empty list arranged
    /// before the Mac replied would put "No projects yet" on screen over a request still running.
    private func rearrange() {
        guard state.isArrangeable else { return }
        state = arrangement
    }

    /// The clock is read once per arrangement rather than per row, so every age on screen is
    /// measured against the same instant — a list whose rows each read their own `Date()` would
    /// show two worktrees touched together as a minute apart.
    private var arrangement: WorktreeSidebarState {
        WorktreeSidebarState(of: worktrees, mode: mode, showingQuiet: showsQuietWorktrees, now: now())
    }
}
