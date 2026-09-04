import Observation
import SwiftUI

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

    /// Everything the reader has said about this worktree, in the order the scroll draws it.
    ///
    /// **Read from the store when the model is built rather than when the screen loads**, because a
    /// review outlives the read that produced it: the phone is backgrounded mid-review far more
    /// often than a change set fails, and comments that arrived a beat after the diff would flicker
    /// onto a screen the reader was already using.
    public private(set) var comments: [ReviewComment] = []

    /// Set when a comment could not be attached to the lines it was written against.
    ///
    /// **It exists so that Save can never be a control that did nothing.** The ends of a selection
    /// are addresses into the diff that was on screen, and a diff that moved under an open composer
    /// leaves them addressing nothing — rare, because a file already fetched is never re-fetched and
    /// the reader cannot press anything behind a sheet, and reachable enough that swallowing it
    /// would mean typing a paragraph and watching it evaporate.
    public private(set) var commentFailure = false

    /// The refusal the Mac gave the last time a hunk was expanded, if it gave one.
    ///
    /// **Reported rather than swallowed, unlike a refused batch of diffs**, and the difference is
    /// what the reader did: a batch is fetched on their behalf while they scroll, and losing one
    /// leaves placeholders the next scroll asks about again. An expansion is a control they pressed,
    /// and a press that leaves the hunk exactly as it was is a control that did nothing.
    public private(set) var expansionFailure: ApiFailure?

    /// Which of the three sheets is up, if any.
    ///
    /// **One value rather than three flags, and one `.sheet` rather than three.** Only one of them
    /// can ever present — the sidebar screen made the same call for its two alerts, on the grounds
    /// that several modifiers of the same kind on one view is the shape where only one ever fires —
    /// and it is also design §7.2's rule expressed as a type rather than as bookkeeping: opening the
    /// composer dismisses the file selector, and closing the composer does not bring it back, because
    /// there is one slot and the composer is in it.
    ///
    /// **It is the model's rather than the screen's**, which is a rule this repository wrote down the
    /// day the Mac's Devices tab needed opening from a menu: a control whose only effect is a
    /// `@State` two layers up is a control nothing can be asked about. Here it also decides what a
    /// baseline can see — a presented state no test can set is a screen photographed with its main
    /// affordance shut.
    public private(set) var sheet: ViewerSheet?

    /// The gesture design §7.1 draws, as the state machine `Domain` owns.
    ///
    /// Read by the diff for its pending rail and by the screen for the instruction bar, and written
    /// only through the four entry points below.
    public private(set) var draft: CommentDraft = .idle

    /// What the composer's field holds, seeded when it opens.
    ///
    /// A plain `var` because a `TextField` binds to it directly, which is the one place in this model
    /// where the view writes rather than reports — a keystroke is not a decision, and routing every
    /// one of them through a method would be a write per character with nothing to assert about it.
    public var composerText = ""

    /// What the review sheet's note field holds. A `var` for the reason `composerText` is one.
    ///
    /// Typing into it un-skips it, because the two states are the same empty field and the reader has
    /// just said which one they are in.
    public var noteDraft = "" {
        didSet {
            if noteDraft.isEmpty == false {
                hasSkippedNote = false
            }
        }
    }

    /// Whether the review is showing the text it is about to copy.
    ///
    /// **On the model rather than in the sheet, for the reason every other presentation flag here
    /// is**: a `@State` inside the view is a state no baseline can set and no test can ask about, so
    /// *Show text* would be a control whose entire effect is invisible to everything this repository
    /// can run. The Snapshot row said so before this moved — the branch that draws the document was
    /// the one thing on that screen no picture reached.
    public private(set) var isShowingDocument = false

    /// Whether the reader pressed *Skip* rather than leaving the note field alone.
    ///
    /// **The two look identical and mean the same thing to the document**, which says nothing either
    /// way — an agent reading a placeholder treats it as an instruction to go and find the note. What
    /// it changes is the screen: a reader who skipped and then wondered whether it took has nothing
    /// else to read, so §7.5 says it out loud.
    public private(set) var hasSkippedNote = false

    /// Whether this review has been put on the pasteboard yet.
    ///
    /// **It is what gates *Clear*, which is design §7.6's sequencing and a safety property rather
    /// than a nicety**: the pasteboard is the only other copy of a review that lives nowhere but this
    /// phone, so a control that could destroy it before it had been pasted is a control that can
    /// destroy an afternoon. There is no path to Clear that does not go through Copy.
    ///
    /// It survives for the rest of the session rather than for the two seconds the button says
    /// *Copied*, because a reader who copies, scrolls back to check one thing and returns has still
    /// copied it.
    public private(set) var hasCopied = false

    /// How much of the phone that drawer takes.
    ///
    /// **The model's for the reason `sheet` is**: choosing a file has to be able to move it, and a
    /// height that lived in the screen's `@State` would be one no test could ask about. The sheet's
    /// own drag writes it back through `drawerDetent`, so this is where the reader's gesture and the
    /// jump's requirement meet rather than two answers to one question.
    public private(set) var drawer: FileSelectorDrawer = .half

    /// The same height as the sheet's own detent, so the sheet can be handed a binding rather than a
    /// pair of closures.
    ///
    /// **It is here rather than in the screen, and that is a testing decision as much as a layering
    /// one.** Written at the call site it is two closures inside a `.sheet` builder — a `get` and a
    /// `set` that no rendered baseline invokes and no host test can reach, which is to say a rule
    /// about which height means what, living in the one place nothing in this repository can ask
    /// about it. Here it is two lines a unit test drives directly, and the screen is left holding
    /// `$model.drawerDetent`, which is the framework's own projection and no code at all.
    ///
    /// `FileSelectorDrawer` stays the stored truth. This is the translation, and it goes one way per
    /// accessor so the two cannot drift.
    public var drawerDetent: PresentationDetent {
        get { drawer == .whole ? .large : .medium }
        set { drawer = newValue == .large ? .whole : .half }
    }

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

    /// What the review calls the worktree it is of, which is the only thing in the exported document
    /// that is not one of the comments.
    ///
    /// Held here rather than passed to the call that builds the document: the model is per worktree
    /// and this is a fact about that worktree, so a screen handing it back on every invocation would
    /// be a second copy of something already decided.
    private let worktreeName: String

    /// The repository this checkout is of, which the exported review names and nothing else here
    /// does.
    ///
    /// **Handed in rather than looked up**, because it is not on the wire this screen reads: a change
    /// set carries a revision, stats and files and no project, so the only source is the worktree the
    /// reader tapped — which is the sidebar's to resolve, beside the display name, for the reason its
    /// own doc comment gives.
    private let projectName: String

    private let repository: any GranitaRepository
    private let commentStore: any ReviewCommentStore
    private let pasteboard: any ReviewPasteboard

    public init(
        worktree: WorktreeID,
        worktreeName: String,
        projectName: String,
        repository: any GranitaRepository,
        commentStore: any ReviewCommentStore,
        pasteboard: any ReviewPasteboard
    ) {
        self.worktree = worktree
        self.worktreeName = worktreeName
        self.projectName = projectName
        self.repository = repository
        self.commentStore = commentStore
        self.pasteboard = pasteboard
        comments = commentStore.comments(in: worktree)
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
            // The comments were read before any file was named, so until now they have been in the
            // order they were written in. This is the first moment the scroll's order exists.
            comments = ReviewedComment.ordered(comments, against: entries)
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
            inFlight: inFlight,
            // **A file drawn shut is not fetched.** `SPEC.md` §10 puts a *Load diff* affordance on
            // the big ones, and a phone that had already spent a batch slot on 1,558 lines nobody
            // asked to see would be offering to do what it had done.
            deferred: Set(entries.filter { $0.collapse.isCollapsed }.map(\.id))
        )
        await fetch(wanted)
    }

    /// **Both of these drop the draft, and that is the fix for a screen that could get stuck.** The
    /// toolbar is live behind the composer's detent, so *12 files* and the review chip can each
    /// replace the composer without going through `dismissSheet` — and the run stayed `.composing`
    /// with no composer over it, a square-capped rail in the gutter, no instruction bar, and every
    /// further gutter gesture a no-op for the life of the screen, because a composing draft ignores
    /// them all.
    public func showSelector(_ isShowing: Bool) {
        draft = draft.cancelled()
        sheet = isShowing ? .selector : nil
    }

    /// Opens the review, which is design §7.4's capsule and the iPad's toolbar toggle.
    public func showReview() {
        draft = draft.cancelled()
        sheet = .review
    }

    /// Puts whichever sheet is up away.
    ///
    /// **It drops the draft with it**, because the composer *is* the draft's third state: a sheet
    /// dismissed by a drag rather than by Cancel would otherwise leave a run picked out with nothing
    /// on screen saying so, and the next tap would extend a selection the reader had abandoned.
    public func dismissSheet() {
        if sheet == .composer {
            draft = draft.cancelled()
        }
        sheet = nil
    }

    /// Asks the scroll to go to a file, which is the selector's entire job.
    ///
    /// **The drawer stays up but comes down to half**, which is design §3's argument for a drawer
    /// over a modal followed to where it actually holds. The reader walking a change set file by
    /// file without a dismiss-present cycle only works while the diff is on screen behind the list —
    /// and it is not, at the whole-screen height, which is also the one height background
    /// interaction is off at. A jump under a full-screen sheet scrolls a diff nobody can see, and a
    /// jump nobody can see is a row that did nothing.
    ///
    /// **Halved rather than dismissed**, which is Davide's own preference and the weaker of the two
    /// interventions: shutting the drawer would cost the reader the list they are working down, and
    /// the sheet is a drawer precisely so it does not have to be reopened between files.
    public func choose(_ file: FileID) {
        jumpTarget = file
        drawer = .half
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

    /// Opens a file the scroll is drawing shut, or shuts one it is drawing.
    ///
    /// **Opening one that never arrived fetches it**, which is what makes the bar's *Load diff* a
    /// control rather than a label: the loader steps over shut files, so without this a reader would
    /// press a bar and get a header over a blank stretch that nothing ever fills.
    public func setOpen(_ isOpen: Bool, on file: FileID) async {
        guard let position = entries.firstIndex(where: { $0.id == file }) else { return }
        guard entries[position].collapse.isCollapsible else { return }
        entries[position] = entries[position].opened(isOpen)
        state = .reading(entries)
        guard isOpen, entries[position].isReady == false else { return }
        await fetch([file])
    }

    /// Shows the lines a hunk skipped, on the side the reader pressed.
    ///
    /// **The lines go into the diff rather than beside it**, so a hunk that has grown carries its
    /// own new bounds and the control disappears the moment the gap it opens is closed. Expansion
    /// state kept in a second structure is a second answer to a question the hunk can already give.
    ///
    /// **Two presses inside one round trip would splice one window twice**, because both compute
    /// their window before either lands. Not guarded here, deliberately: the guard is a branch no
    /// test kind in this repository can drive — it needs two calls genuinely overlapping, which
    /// needs a fake that holds a request open — and an untested branch is worse than a defect whose
    /// symptom is twenty context lines appearing twice with the gutter numbers saying so. It is on
    /// the device afternoon's list, which is where it can be seen.
    public func expand(_ direction: ContextDirection, hunk index: Int, in file: FileID) async {
        guard let position = entries.firstIndex(where: { $0.id == file }),
              case .ready(let diff) = entries[position].content,
              let hunkPosition = diff.hunks.firstIndex(where: { $0.index == index }) else { return }
        let hunk = diff.hunks[hunkPosition]
        let window = switch direction {
        case .above:
            ContextExpansion.above(hunk, after: hunkPosition > 0 ? diff.hunks[hunkPosition - 1] : nil)
        case .below:
            ContextExpansion.below(
                hunk,
                before: hunkPosition + 1 < diff.hunks.count ? diff.hunks[hunkPosition + 1] : nil,
                endingAt: diff.newLineCount
            )
        }
        // The control is absent when there is no window, so reaching this means the file changed
        // under a press. Nothing to fetch and nothing to report — the next batch redraws it.
        guard let window else { return }

        do {
            let read = try await repository.lines(
                of: file,
                in: worktree,
                side: window.side,
                start: window.start,
                count: window.count
            )
            // Found again rather than reused: a batch may have replaced this file while the lines
            // were in flight, and splicing into the copy taken before the request would drop it.
            guard let now = entries.firstIndex(where: { $0.id == file }),
                  case .ready(let diff) = entries[now].content,
                  let hunkPosition = diff.hunks.firstIndex(where: { $0.index == index }) else { return }
            var hunks = diff.hunks
            hunks[hunkPosition] = switch direction {
            case .above: ContextExpansion.expanded(hunks[hunkPosition], above: read.lines)
            case .below: ContextExpansion.expanded(hunks[hunkPosition], below: read.lines)
            }
            entries[now] = entries[now].arrived(
                FileDiff(
                    file: diff.file,
                    hunks: hunks,
                    oldLineCount: diff.oldLineCount,
                    newLineCount: diff.newLineCount,
                    isTruncated: diff.isTruncated,
                    truncationReason: diff.truncationReason
                )
            )
            state = .reading(entries)
        } catch {
            expansionFailure = error
        }
    }

    public func dismissExpansionFailure() {
        expansionFailure = nil
    }

    /// A tap on a file's gutter, which is either a comment on one row or the second end of a run.
    ///
    /// **The composer opens on whatever it produces**, and if that run already carries a comment it
    /// opens holding it — design §7.1's "a single tap on a rail opens that comment for editing, no
    /// long press, no menu". The file selector goes with it, because there is one sheet.
    /// **A tap that changes nothing writes nothing**, and that guard is load-bearing rather than
    /// defensive. The composer's own detent enables background interaction, which is what lets a
    /// reader scroll the diff behind it to check the caller they are about to complain about — and it
    /// also means a thumb can land on the gutter while the sheet is up. Without this, that tap left
    /// the composer open on the same rows and emptied the field: three sentences gone, and nothing on
    /// screen to say why.
    public func tappedGutter(_ end: DiffLinePosition, in file: FileID) {
        let next = draft.tapped(end, in: file)
        guard next != draft else { return }
        draft = next
        composerText = editingComment?.text ?? ""
        sheet = .composer
    }

    /// A long press on a file's gutter, which begins a run and raises the instruction bar.
    ///
    /// It opens no sheet: what the reader has done is pick one end, and the bar over the diff is what
    /// says so and what offers the way out.
    public func longPressedGutter(_ end: DiffLinePosition, in file: FileID) {
        draft = draft.longPressed(end, in: file)
    }

    /// The instruction bar's Cancel.
    public func cancelDraft() {
        draft = draft.cancelled()
    }

    /// The composer's Save.
    ///
    /// **Nothing is written for an empty field.** A reader who opens the composer and thinks better
    /// of it gets the same outcome as Cancel rather than a comment with no words in it, which would
    /// be a rail in the gutter and a line in the document saying nothing.
    public func saveComment() {
        guard let pending = draft.pending else { return }
        let written = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        if written.isEmpty {
            dismissSheet()
            return
        }
        comment(on: pending.file, from: pending.from, to: pending.to, saying: written)
        dismissSheet()
    }

    /// The composer's Delete, which design §7.2 gives only to a comment that already exists.
    public func deleteComposedComment() {
        guard let anchor = editingComment?.anchor else { return }
        removeComment(anchor)
        dismissSheet()
    }

    /// The comment the composer is editing, if the run it is open on already carries one.
    ///
    /// **Resolved against the diff rather than compared as typed**, because the two ends of a pending
    /// run are in the order the reader's thumb touched them and an anchor is in the order the diff
    /// draws them. Comparing the raw pair would make a run held upwards a different run from the same
    /// one held downwards, which is the duplicate `CommentAnchor` exists to prevent.
    public var editingComment: ReviewComment? {
        guard let anchor = anchorOfTheDraft else { return nil }
        return comments.first { $0.anchor == anchor }
    }

    /// The lines the composer quotes above its field, which are the receipt for an 18pt aim.
    ///
    /// Design §7.2: three rows of the anchored code, so a reader never types a paragraph against the
    /// wrong line and finds out on the Mac.
    public var composerExcerpt: [ExcerptLine] {
        guard let pending = draft.pending,
              case .ready(let diff)? = entries.first(where: { $0.id == pending.file })?.content,
              let rows = CommentSelection.rows(of: diff, from: pending.from, to: pending.to) else {
            return []
        }
        // The same spelling the export uses, which is the whole claim the excerpt makes: what the
        // reader is looking at here is what the agent will be handed. With the gutter's own figures
        // beside it, because the number is what a reader who aimed one row off would recognise.
        return CommentSelection.excerpt(of: rows)
    }

    /// What the composer's own header says the comment is about — `Turbine.swift:41-44`.
    public var composerAnchorLabel: String {
        draft.pending.map(label(of:)) ?? ""
    }

    /// The same sentence for the row the reader is holding, because the other end may be a screen
    /// away by the time they go looking for it and scrolling deliberately does not cancel the hold.
    public var heldRowLabel: String {
        draft.held.map(label(of:)) ?? ""
    }

    /// The review's *Show text*, which reveals exactly what the copy will put on the pasteboard.
    public func showDocument(_ isShowing: Bool) {
        isShowingDocument = isShowing
    }

    /// The review sheet's *Skip*, which is one of the two answers §7.5 offers for the note.
    public func skipNote() {
        noteDraft = ""
        hasSkippedNote = true
    }

    /// Puts the review on the pasteboard, which is the only thing this feature does to the outside
    /// world.
    ///
    /// **Only after this can the review be cleared.** See `hasCopied`.
    public func copyReview() {
        pasteboard.copy(feedback(note: noteDraft))
        hasCopied = true
    }

    /// Writes down what the reader had to say about one run of lines, or replaces what they said
    /// before.
    ///
    /// **The anchor is the identity, so a second comment on the same run is an edit.** A review is a
    /// note left for an agent rather than a thread, and two notes on one span would be one thing to
    /// read written twice.
    ///
    /// **Only a file whose diff is in hand can carry one**, which costs nothing: the ends came from
    /// rows the screen drew, and a file that is awaiting or shut has drawn none.
    public func comment(on file: FileID, from: DiffLinePosition, to: DiffLinePosition, saying text: String) {
        guard case .ready(let diff)? = entries.first(where: { $0.id == file })?.content,
              let written = CommentSelection.comment(on: diff, from: from, to: to, saying: text) else {
            commentFailure = true
            return
        }
        comments.removeAll { $0.anchor == written.anchor }
        comments.append(written)
        remember()
    }

    /// Takes one comment back, which is what an empty composer and a delete both come to.
    public func removeComment(_ anchor: CommentAnchor) {
        comments.removeAll { $0.anchor == anchor }
        remember()
    }

    /// Forgets the whole review — the comments, the note, and the fact that it was copied.
    ///
    /// **Offered after the document has been copied and never before**, which is design §7.6's
    /// sequencing: the pasteboard is the only other copy there is, so clearing before it has been
    /// pasted destroys the afternoon. What makes it safe to offer at all is that it follows the copy
    /// rather than sitting beside it.
    ///
    /// It puts the screen back exactly where a first run leaves it, capsule and all, which is what
    /// makes *Clear* a finish rather than a partial one.
    public func clearComments() {
        comments = []
        noteDraft = ""
        hasSkippedNote = false
        hasCopied = false
        sheet = nil
        remember()
    }

    public func dismissCommentFailure() {
        commentFailure = false
    }

    /// Every comment judged against the diff as it stands, which is what the review list draws and
    /// what the document is written from.
    ///
    /// Computed rather than stored: staleness is a fact about a comment *and* a change set, and both
    /// move — a batch lands, a hunk grows, the screen is re-opened. A stored flag would have three
    /// writers and be wrong the first time one of them did not run.
    public var reviewed: [ReviewedComment] {
        ReviewedComment.listing(of: comments, against: entries)
    }

    /// The review as the one piece of text that goes back to the agent.
    ///
    /// `note` absent is the *Skip* the flow offers, and the document leaves nothing standing in for
    /// it.
    public func feedback(note: String?) -> String {
        ReviewFeedback.document(
            project: projectName,
            worktree: worktreeName,
            // What the reader is being asked about, which is the change set rather than the review:
            // "12 files" is the size of the read the comments came out of.
            fileCount: entries.count,
            note: note,
            comments: reviewed
        )
    }

    /// One batch, with the answers spliced back into the files that asked for them.
    ///
    /// A refusal here is deliberately not the screen's failure. The change set arrived, so the
    /// reader has a list of files and their sizes; losing one batch of hunks leaves placeholders
    /// where content would be, and the next thing they scroll to asks again. Replacing the whole
    /// screen with an error because the fourth batch of twenty failed would throw away everything
    /// they had already read.
    private func fetch(_ wanted: [FileID]) async {
        guard wanted.isEmpty == false else { return }
        inFlight.formUnion(wanted)
        defer { inFlight.subtract(wanted) }

        guard let diffs = try? await repository.diffs(of: wanted, in: worktree, contextLines: surroundingContext) else {
            return
        }
        for diff in diffs {
            guard let position = entries.firstIndex(where: { $0.id == diff.file.id }) else { continue }
            // The mark and the chevron are the phone's, and a diff arriving is the Mac answering a
            // question that was asked before either was touched. Keeping what is on screen stops a
            // mark the reader has just set being taken back off by a batch already in flight.
            entries[position] = entries[position].arrived(diff)
        }
        state = .reading(entries)
        // **A batch landing is the moment a comment on that file becomes placeable.** `load()` orders
        // a restored review while every file is still awaiting, so the only key available there is
        // the reported line — the one `ReviewedComment.ordered` documents as wrong across the two
        // sides. Re-ordering here is what settles it, and it costs nothing on the ordinary screen
        // because a review is a handful of comments.
        comments = ReviewedComment.ordered(comments, against: entries)
    }

    /// `Turbine.swift:41-44` — the file's name and the span, resolved against the diff.
    ///
    /// The name rather than the path, because the reader is looking at the file: the full path is
    /// what the exported document carries, where the audience is a shell.
    private func label(of pending: PendingComment) -> String {
        guard case .ready(let diff)? = entries.first(where: { $0.id == pending.file })?.content,
              let rows = CommentSelection.rows(of: diff, from: pending.from, to: pending.to),
              let lines = CommentedLines.of(rows) else {
            return ""
        }
        let name = DiffFilePath.name(of: diff.file.path)
        return lines.first == lines.last
            ? "\(name):\(lines.first)"
            : "\(name):\(lines.first)-\(lines.last)"
    }

    /// The draft's run as an address, in the order the diff draws it.
    private var anchorOfTheDraft: CommentAnchor? {
        guard let pending = draft.pending,
              case .ready(let diff)? = entries.first(where: { $0.id == pending.file })?.content,
              let ends = CommentSelection.ends(of: diff, from: pending.from, to: pending.to) else {
            return nil
        }
        return CommentAnchor(file: pending.file, first: ends.first, last: ends.last)
    }

    /// Puts the review back in the scroll's order and writes it down, in that order, so the list on
    /// screen and the document that gets copied cannot disagree about what comes first.
    private func remember() {
        comments = ReviewedComment.ordered(comments, against: entries)
        commentStore.save(comments, in: worktree)
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

/// Which of the diff screen's three sheets is up.
///
/// **One slot, so the rule design §7.2 asks for is a type rather than bookkeeping**: opening the
/// composer dismisses the file selector, and closing the composer does not bring it back. The reader
/// asked for a comment, not a file.
public enum ViewerSheet: Hashable, Sendable, Identifiable {

    /// Design §3's file list, at the medium and large detents with the diff live behind it.
    case selector

    /// Design §7.2's composer, at one 300pt detent with the diff live behind it.
    case composer

    /// Design §7.6's review, at `.large` with nothing behind it — this one is a destination rather
    /// than a drawer, and the diff is no longer the subject.
    case review

    public var id: Self { self }
}

// MARK: -

/// How much surrounding context each diff is fetched with. Three, which is git's own default and
/// what design §4's collapsed-context rule assumes.
///
/// A constant rather than a parameter: nothing varies it, and a seam no caller turns is API before
/// the reader — which in this repository is also an untested branch, because the initialiser nobody
/// calls with the other value is a region no test enters.
private let surroundingContext = 3
