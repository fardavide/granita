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

    public private(set) var state: WorktreeSidebarState = .loading
    public private(set) var mode: WorktreeListMode
    public private(set) var showsQuietWorktrees: Bool

    /// The subject of the open rename sheet, and `nil` when there is none. The row resolves it, so
    /// the sheet and the row it came from cannot spell the same fallback two ways.
    public private(set) var renaming: WorktreeRenameSubject?

    /// A write the Mac refused. Renaming and pinning both leave the row exactly where it was on
    /// failure, and without this that is a swipe that appears to have done nothing.
    public private(set) var writeFailure: ApiFailure?

    private var worktrees: [Worktree] = []
    private let repository: any GranitaRepository
    private let preferences: any WorktreeListPreferences
    private let now: @Sendable () -> Date

    public init(
        repository: any GranitaRepository,
        preferences: any WorktreeListPreferences,
        now: @escaping @Sendable () -> Date
    ) {
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
    public func load() async {
        do {
            worktrees = try await repository.worktrees(inProject: nil)
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

    public func dismissWriteFailure() {
        writeFailure = nil
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
                writeFailure = .worktreeGone
                return
            }
            worktrees[index] = updated
            rearrange()
        } catch {
            writeFailure = error
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
