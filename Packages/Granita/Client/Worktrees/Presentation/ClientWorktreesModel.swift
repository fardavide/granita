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
    public private(set) var readStage: WorktreeReadStage = .finding(.unknown)
    public private(set) var readTiming: WorktreeReadTiming = .notStarted
    public private(set) var readResult: WorktreeReadResult = .notRead
    public private(set) var logCopyState: DiagnosticCopyState = .ready
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

    public var currentTime: Date { now() }

    public var isRetryingRefresh: Bool {
        switch reading {
        case .idle: false
        case .running: readTrigger == .retry && readResult != .notRead
        }
    }

    /// Whether a read **nobody asked for** is running over worktrees already on screen.
    ///
    /// **The one refresh with nowhere to report itself.** A pull carries the list's own indicator
    /// and *Try Again* puts design §8's progress view above the rows, so both of those are already
    /// visible where the reader's attention is. An appearance read has neither: a `.task` re-runs
    /// every time this screen comes back, the rows it is about to replace stay exactly where they
    /// are, and the whole Mac is re-read — 5.843 seconds on the profiled five projects — with
    /// nothing anywhere saying so.
    ///
    /// **`readResult` is what separates it from the first read**, rather than the trigger: until one
    /// read has landed the screen is the full loading state, which is already a spinner and a
    /// sentence, and a second spinner in the toolbar beside it would be the app saying one thing
    /// twice.
    /// **Stored rather than derived, because a threshold is a fact about time passing** and a
    /// computed property has nothing to observe. `UnaskedForRefresh.announcementDelay` carries why
    /// there is a threshold at all.
    public private(set) var isAutomaticallyRefreshing = false

    private var worktrees: [Worktree] = []
    private var reading: ReadTask = .idle
    private var announcingRefresh: Task<Void, Never>?
    private let announcementDelay: Duration
    private var announcedPhase: ReadPhase = .notAnnounced
    private var readTrigger: WorktreeReadTrigger = .appearance
    private let repository: any GranitaRepository
    private let preferences: any WorktreeListPreferences
    private let copyingLogs: any DiagnosticLogsCopying
    private let announcing: any WorktreeReadAnnouncing
    private let now: @Sendable () -> Date

    public init(
        macName: String,
        repository: any GranitaRepository,
        preferences: any WorktreeListPreferences,
        copyingLogs: any DiagnosticLogsCopying,
        announcing: any WorktreeReadAnnouncing,
        announcementDelay: Duration = UnaskedForRefresh.announcementDelay,
        now: @escaping @Sendable () -> Date
    ) {
        self.announcementDelay = announcementDelay
        self.macName = macName
        self.repository = repository
        self.preferences = preferences
        self.copyingLogs = copyingLogs
        self.announcing = announcing
        self.now = now
        mode = preferences.mode()
        showsQuietWorktrees = preferences.showsQuietWorktrees()
    }

    public func copyLogs() async {
        logCopyState = .copying
        let failure: ApiFailure?
        switch state {
        case .failed(let error): failure = error
        case .loading, .noProjects, .allQuiet, .listing: failure = nil
        }
        do {
            try await copyingLogs.copy(context: .worktrees(failure))
            logCopyState = .copied
        } catch {
            logCopyState = .failed
        }
    }

    /// Reads every worktree the Mac is serving, across all enabled projects.
    ///
    /// One request rather than one per project: the grouping is this side's arrangement of a single
    /// answer, and asking per project would make the order the list is drawn in depend on which
    /// request finished first.
    /// First reads and retries from a failed screen show observed stages and elapsed time. Refresh
    /// keeps the previous answer visible, with its receipt distinguishing a fresh read from a
    /// refused refresh. Cancellation restores the retained arrangement, and each attempt owns its
    /// updates so a late completion cannot replace a newer answer.
    public func load() async {
        await load(trigger: .appearance)
    }

    public func load(trigger: WorktreeReadTrigger) async {
        cancelLoading()
        readTrigger = trigger
        let attempt = UUID()
        let started = now()
        if case .stale(let at, let route, _) = readResult {
            readResult = .read(at: at, route: route)
        }
        readStage = .finding(.unknown)
        announcedPhase = .notAnnounced
        readTiming = .running(started: started)
        // **Only a read nobody asked for, and only over worktrees already on screen.** A pull
        // carries the list's own indicator and a retry puts design §8's progress view above the
        // rows; the first read has the whole screen. Decided after the line above that ages a stale
        // receipt, so what is tested is whether anything has ever been read rather than whether the
        // last attempt failed.
        //
        // Coming back to the app is on the same side of this as coming back to the screen: the
        // reader did not press anything either time, so both get the one indicator design §8 gives
        // a read nobody asked for.
        let isUnaskedFor = switch trigger {
        case .appearance, .returnToForeground: true
        case .pullToRefresh, .retry: false
        }
        if isUnaskedFor, readResult != .notRead {
            announcingRefresh = sayingTheRefreshIsWorthShowing(attempt: attempt)
        }
        let task = Task { await performLoad(attempt: attempt) }
        reading = .running(attempt, task)
        defer {
            if ownsRead(attempt) {
                reading = .idle
                readTiming = .finished(started: started, ended: now())
                stopAnnouncingTheRefresh()
            }
        }
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    /// Re-reads a list that went stale while the app was somewhere else, and does nothing otherwise.
    ///
    /// **The screen's `.task` cannot cover this.** It re-runs each time the view appears, and a view
    /// that was on screen when the app went to the background never went away — so it never appears
    /// again, and until 0.14.0 the only thing that said the rows were old was the age in the footer.
    ///
    /// Three ways it declines, and each is a read that would be wrong rather than merely wasteful:
    ///
    /// - **A read is already running.** `load(trigger:)` cancels whatever is in flight before it
    ///   starts, so a return that did not check would tear down a read most of the way through
    ///   answering the same question, with the reader having done nothing but come back.
    /// - **Nothing has ever been read.** That screen is showing its failure and its *Try Again*, and
    ///   a read starting under it would be a control pressing itself. A refused *refresh* is the
    ///   opposite case and does re-read: those rows are on screen with an age against them, and
    ///   settling that age is the whole point.
    /// - **The answer is still fresh.** `UnaskedForRefresh.staleAfter` carries why there is a
    ///   threshold at all, and why it is measured against the answer rather than the time away.
    /// **The phase arrives as a fact rather than being tested in the view.** A `guard` inside an
    /// `onChange` is a branch nothing in this repository can drive — no Ui target exists, and a
    /// snapshot renders a screen without ever changing its scene phase — so it lives here, where the
    /// Unit row judges it and a test names it.
    public func sceneBecame(active: Bool) async {
        guard active else { return }
        guard case .idle = reading else { return }
        let readAt: Date
        switch readResult {
        case .notRead: return
        case .read(let at, _), .stale(let at, _, _): readAt = at
        }
        guard Duration.seconds(now().timeIntervalSince(readAt)) >= UnaskedForRefresh.staleAfter else { return }
        await load(trigger: .returnToForeground)
    }

    public func cancelLoading() {
        stopAnnouncingTheRefresh()
        switch reading {
        case .idle: break
        case .running(_, let task): task.cancel()
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
    ///
    /// **The sheet goes down before the request goes out, not after the answer comes back.** It used
    /// to await the round trip first, which left a modal sitting over a list the reader could not see
    /// for however long the Mac took — and the Mac's answer to a rename used to be a rebuild of every
    /// worktree of every enabled project. Saving is the reader's last word on this sheet either way:
    /// there is no second question it could ask, so nothing is gained by keeping it up, and what a
    /// refusal has to say is said by the alert underneath rather than by the sheet.
    public func rename(_ worktree: WorktreeID, to alias: String) async {
        let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        renaming = nil
        await write(WorktreePatch(alias: trimmed.isEmpty ? .cleared : .set(trimmed), isPinned: nil), to: worktree)
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

    private func performLoad(attempt: UUID) async {
        // **Only a failure goes back to the spinner**, and the snapshot suites are what settled
        // that: blanking on every read photographed a spinner on screens that had already loaded,
        // because a screen re-runs its `.task` every time it appears — so coming back to the
        // worktree list would have emptied it and started again under the reader. Content on screen
        // stays on screen while it is re-read; a failure has nothing to keep.
        if case .failed = state {
            state = .loading
        }
        do {
            let answer = try await repository.worktrees(inProject: nil, reporting: { stage in
                await self.record(stage, attempt: attempt)
            })
            guard ownsRead(attempt) else { return }
            guard Task.isCancelled == false else {
                state = arrangement
                return
            }
            worktrees = answer
            let route: WorktreeConnectionRoute = switch readStage {
            case .finding, .verifying: .unknown
            case .reading(let route): route
            }
            readResult = .read(at: now(), route: route)
            state = arrangement
            announcing.announce(.arrived(worktreeCount: answer.count))
        } catch .cancelled {
            guard ownsRead(attempt) else { return }
            state = arrangement
        } catch .unauthorized {
            guard ownsRead(attempt) else { return }
            guard !Task.isCancelled else {
                state = arrangement
                return
            }
            readResult = .notRead
            state = .failed(.unauthorized)
        } catch {
            guard ownsRead(attempt) else { return }
            guard !Task.isCancelled else {
                state = arrangement
                return
            }
            switch readResult {
            case .notRead:
                state = .failed(error)
            case .read(let at, let route), .stale(let at, let route, _):
                readResult = .stale(at: at, route: route, failure: error)
                state = arrangement
                announcing.announce(.refreshFailed)
            }
        }
    }

    /// Puts the change in the list at once, then replaces it with the Mac's own answer.
    ///
    /// **Optimistic, and it is the two writes that touch no git state that get to be.** An alias and
    /// a pin are entries in the Mac's own JSON document, so the only question a request can answer is
    /// whether it was written down — and holding a row still until it comes back makes both controls
    /// do nothing for the length of a round trip. Deleting is the opposite case and stays pessimistic
    /// for the reason recorded on `confirmDeletion(of:)`.
    ///
    /// **The Mac's answer still replaces the phone's guess**, because the display name is resolved
    /// over there and this side resolves it by the same rule rather than by the same code. A row left
    /// on the guess would be a row that agrees with the Mac only for as long as the two spellings do.
    ///
    /// **A refusal puts back exactly what was there**, which is what the refusal alert already
    /// promises in as many words — *the row is still as it was*.
    private func write(_ patch: WorktreePatch, to worktree: WorktreeID) async {
        guard let index = worktrees.firstIndex(where: { $0.id == worktree }) else {
            // The row was read, swiped, and written to after it stopped being in the list — an agent
            // removes a worktree every day. There is nothing to draw the change on, and nothing this
            // phone could do with the answer that would not put a row on screen that the last read
            // said is gone.
            writeFailure = .edit(.worktreeGone)
            return
        }
        let before = worktrees[index]
        worktrees[index] = before.applying(patch)
        rearrange()

        do {
            let updated = try await repository.update(worktree, with: patch)
            replace(worktree, with: updated)
        } catch {
            replace(worktree, with: before)
            writeFailure = .edit(error)
        }
    }

    /// Puts a worktree back in the list under its own identifier, and does nothing where it has since
    /// left — a deletion confirmed while this was in flight, which appending to would undo.
    private func replace(_ worktree: WorktreeID, with value: Worktree) {
        guard let index = worktrees.firstIndex(where: { $0.id == worktree }) else { return }
        worktrees[index] = value
        rearrange()
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

    private func record(_ stage: WorktreeReadStage, attempt: UUID) {
        guard ownsRead(attempt), !Task.isCancelled else { return }
        if case .reading = readStage { return }
        if case .verifying = readStage, case .finding = stage { return }
        readStage = stage
        let phase: ReadPhase = switch stage {
        case .finding: .finding
        case .verifying: .verifying
        case .reading: .reading
        }
        if phase != announcedPhase {
            announcedPhase = phase
            announcing.announce(.stage(stage, macName: macName))
        }
    }

    /// Waits out the threshold and then, if this read is still the current one and still running,
    /// puts the spinner beside the title.
    ///
    /// **The attempt is checked on the far side of the sleep**, because half a second is long enough
    /// for the reader to leave and come back: without it a replaced read's timer would announce a
    /// refresh that belongs to nothing.
    private func sayingTheRefreshIsWorthShowing(attempt: UUID) -> Task<Void, Never> {
        Task { [weak self, announcementDelay] in
            try? await Task.sleep(for: announcementDelay)
            guard Task.isCancelled == false, let self, ownsRead(attempt) else { return }
            isAutomaticallyRefreshing = true
        }
    }

    private func stopAnnouncingTheRefresh() {
        announcingRefresh?.cancel()
        announcingRefresh = nil
        isAutomaticallyRefreshing = false
    }

    private func ownsRead(_ attempt: UUID) -> Bool {
        switch reading {
        case .idle: false
        case .running(let active, _): active == attempt
        }
    }

    /// The clock is read once per arrangement rather than per row, so every age on screen is
    /// measured against the same instant — a list whose rows each read their own `Date()` would
    /// show two worktrees touched together as a minute apart.
    private var arrangement: WorktreeSidebarState {
        WorktreeSidebarState(of: worktrees, mode: mode, showingQuiet: showsQuietWorktrees, now: now())
    }

    private enum ReadTask {
        case idle
        case running(UUID, Task<Void, Never>)
    }

    private enum ReadPhase {
        case notAnnounced
        case finding
        case verifying
        case reading
    }
}
