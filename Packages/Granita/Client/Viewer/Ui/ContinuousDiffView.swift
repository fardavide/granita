import SwiftUI

import ClientConnectionDomain
import ClientViewerDomain
import CoreDiffDomain
import CoreReviewDomain

/// Every changed file in one scroll, which is `SPEC.md` §10's locked decision and the screen this
/// product exists for.
///
/// **One section per file in a lazy stack with pinned headers**, which is design §4's own
/// implementation note and the shape that keeps the no-reflow rule intact: pinning is a rendering
/// position rather than a layout change, so nothing above the reader's finger moves when a header
/// sticks.
///
/// **A file that has not arrived reserves its height rather than collapsing.** The change set names
/// every file before any diff is fetched, so all of them are drawn from the first frame and the
/// estimate holds the space. Correcting an estimate is invisible below the viewport and is the
/// defect above it, which is why `ContinuousDiffLoading` never fetches backwards.
///
/// It renders the state it is handed and reports what the reader reached, so every state can be put
/// in front of a camera without a Mac, a network or a paired device. **The one thing it keeps for
/// itself is where the scroll is**, which is not the model's business: a position is what this view
/// is, and a model that held it would be written to on every frame of an ordinary scroll.
public struct ContinuousDiffView: View {

    @Environment(\.accessibilityReduceMotion) public var reduceMotion

    /// Where the scroll is, as the scroll's own state rather than the model's.
    ///
    /// This and the model's `jumpTarget` answer different questions: the model says *go here*, once,
    /// and this says *here is where we are* for as long as the reader keeps scrolling. Feeding the
    /// second back into the model would make every frame of an ordinary scroll a write.
    ///
    /// Seeded from the target so the **first** layout is already in the right place. A view built
    /// holding a jump has nothing to animate towards, and in the app that seed is always absent
    /// because a screen is opened before a file is chosen in it.
    @State private var scrolledTo: FileID?

    private let state: ContinuousDiffState
    private let logCopyState: DiagnosticCopyState
    private let pointSize: CGFloat

    /// Whether a paired run opens into two columns, which the reader sets from the toolbar and this
    /// screen only carries. Design §4.5's call 6 keeps it global and device-local, so it arrives the
    /// same way the code theme does and no file holds one of its own.
    private let isSplit: Bool

    /// The file §3's selector asked this scroll to go to, and nothing about how far it got.
    private let jumpTarget: FileID?

    /// The whole review, judged against this change set. Each file takes what is its own: the runs
    /// that still resolve become rails, and the ones that do not become a row under its header.
    private let comments: [ReviewedComment]

    /// The run being picked out, if one is.
    private let pending: PendingComment?

    /// Every file's lexed code, filed by the file it belongs to.
    ///
    /// **Handed in rather than fetched here, and that is what makes highlighting photographable.**
    /// A `.task` inside this view would colour the screen in the app and nothing at all in a
    /// baseline, so the one treatment that changes every row of every file would be the one thing
    /// the snapshot suite could not see.
    private let highlighted: [FileID: HighlightedFile]

    /// Every changed picture's two sides, filed by the file they belong to.
    ///
    /// **Handed in for the reason `highlighted` is, and it matters more here**: a `.task` inside the
    /// card would fetch in the app and fetch nothing in a baseline, so the one file kind whose whole
    /// content is what arrived over the network would be the one kind the snapshot suite photographs
    /// empty. A file that is not a picture has no entry.
    private let images: [FileID: DiffImage]

    /// Whether the gutter takes gestures. False while a sheet is up — see `DiffFileLines`.
    private let acceptsTargeting: Bool

    /// Whether the batch in flight has been in flight long enough for its rows to add a word.
    ///
    /// **One flag rather than a clock**, which is design §9 reversing its own last round: an elapsed
    /// stopwatch was right on the loading screen, where there was one wait and one spinner, and here
    /// it would be five stopwatches ticking in a scroll. One word changes, once, and then nothing
    /// moves.
    private let isWaitingLong: Bool

    private let onReading: (Int) -> Void
    private let onJumped: () -> Void
    private let onSetViewed: (Bool, FileID) -> Void
    private let onSetOpen: (Bool, FileID) -> Void
    private let onExpand: (ContextDirection, Int, FileID) -> Void
    private let onTapGutter: (DiffLinePosition, FileID) -> Void
    private let onLongPressGutter: (DiffLinePosition, FileID) -> Void
    private let onOpenImage: (DiffSide, FileID) -> Void
    private let onRetryImage: (DiffSide, FileID) -> Void
    private let onOpenReview: () -> Void
    private let onRetry: () -> Void

    /// What a pull on the scroll asks for, awaited so the indicator turns until the answer lands.
    private let onRefresh: () async -> Void

    private let onCopyLogs: () -> Void

    public init(
        state: ContinuousDiffState,
        logCopyState: DiagnosticCopyState,
        pointSize: CGFloat,
        isSplit: Bool = false,
        jumpTarget: FileID?,
        comments: [ReviewedComment] = [],
        pending: PendingComment? = nil,
        highlighted: [FileID: HighlightedFile] = [:],
        images: [FileID: DiffImage] = [:],
        acceptsTargeting: Bool = true,
        isWaitingLong: Bool = false,
        onReading: @escaping (Int) -> Void,
        onJumped: @escaping () -> Void,
        onSetViewed: @escaping (Bool, FileID) -> Void,
        onSetOpen: @escaping (Bool, FileID) -> Void,
        onExpand: @escaping (ContextDirection, Int, FileID) -> Void,
        onTapGutter: @escaping (DiffLinePosition, FileID) -> Void = { _, _ in },
        onLongPressGutter: @escaping (DiffLinePosition, FileID) -> Void = { _, _ in },
        // **No default, unlike the two gutter gestures above.** A no-op default on a callback that
        // is the whole of what a control does is a dead control with a place to hide: a caller that
        // forgets one ships a picture you can tap and a *Try Again* you can press, both of which
        // answer with silence, and nothing anywhere would say so. The gutter's two are a different
        // shape — a scroll with no comments in it genuinely has nothing to report.
        onOpenImage: @escaping (DiffSide, FileID) -> Void,
        onRetryImage: @escaping (DiffSide, FileID) -> Void,
        onOpenReview: @escaping () -> Void = {},
        onRetry: @escaping () -> Void,
        // No default, for the reason `onOpenImage` carries: a pull that resolves to nothing is a
        // gesture the reader makes, watches spin and gets no answer from.
        onRefresh: @escaping () async -> Void,
        onCopyLogs: @escaping () -> Void
    ) {
        self.state = state
        self.logCopyState = logCopyState
        self.pointSize = pointSize
        self.isSplit = isSplit
        self.jumpTarget = jumpTarget
        self.comments = comments
        self.pending = pending
        self.highlighted = highlighted
        self.images = images
        self.acceptsTargeting = acceptsTargeting
        self.isWaitingLong = isWaitingLong
        // **Seeded with the jump, and with nothing at all when there is no jump.** Seeding the first
        // file instead asked `scrollPosition` to align it to the top of the scroll view's *frame*,
        // which begins under the navigation bar while the content is already inset by that same safe
        // area — so the file the reader opens on sat 92pt down a page of empty grey, on every phone
        // and every iPad. Nothing asked for that position: it was stated in order not to be settled,
        // and the settled one was right.
        _scrolledTo = State(initialValue: jumpTarget)
        self.onReading = onReading
        self.onJumped = onJumped
        self.onSetViewed = onSetViewed
        self.onSetOpen = onSetOpen
        self.onExpand = onExpand
        self.onTapGutter = onTapGutter
        self.onLongPressGutter = onLongPressGutter
        self.onOpenImage = onOpenImage
        self.onRetryImage = onRetryImage
        self.onOpenReview = onOpenReview
        self.onRetry = onRetry
        self.onRefresh = onRefresh
        self.onCopyLogs = onCopyLogs
    }

    public var body: some View {
        switch state {
        case .loading:
            // A progress view promises a finish and this one has it: a request either answers or
            // fails. The spinner design §1 refuses for a Bonjour browse is the right control here.
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            failed
        case .nothingChanged:
            nothingChanged
        case .reading(let entries):
            scroll(of: entries)
        }
    }

    private func scroll(of entries: [ContinuousDiffEntry]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { position, entry in
                    Section {
                        content(of: entry)
                            // **The position is reported on appearance rather than from a scroll
                            // offset.** `SPEC.md` §10 says to track this with visibility and never
                            // with `contentOffset`, and the reason is the same one the whole screen
                            // turns on: an offset is a number about a layout that is allowed to be
                            // wrong below the fold, and a file appearing is a fact.
                            .onAppear { onReading(position) }
                    } header: {
                        header(of: entry)
                    }
                }
            }
            .scrollTargetLayout()
            // **Shutting and opening a file is animated here, on the stack, and not on the two
            // halves inside it.** What has to travel when a file shuts is every *other* file below
            // it, and their positions belong to this stack — an animation attached inside a section
            // scopes to that section, so 0.5.2 cross-faded the bar into the header while the rest of
            // the scroll snapped to its new place, which is the jump wearing a fade. One scope over
            // the whole stack is also what makes the two halves of the swap one gesture rather than
            // two. The curve is stated once, in `Animation.disclosure`.
            //
            // **A diff arriving is keyed here too now, and it used to be deliberately excluded.** The
            // old comment read "so a diff arriving still lands without dragging the scroll around",
            // which was right while a file reserved its own height and the swap moved nothing. It
            // reserves four rows now, so the real content *does* change the height — and a height
            // that changes without moving is the jump this whole section exists to prevent, arriving
            // from the one direction that used to be exempt.
            //
            // Under `.scrollTargetLayout()` rather than over it: the marker wants the stack itself,
            // and a jump landing on a file is a different gesture from a file opening under a thumb.
            .animation(.disclosure, value: entries.map(\.collapse.isCollapsed))
            .animation(.disclosure, value: entries.map(\.isReady))
        }
        // **A scroll position by identity, and a `ScrollViewReader` is what it replaces.** The first
        // build called `proxy.scrollTo` from a watch on the target, and the baseline came back with
        // the *first* file still at the top: the stack is lazy, so at the moment that watch fires
        // the row being scrolled to has not been created and there is nothing to scroll to. A
        // position applies during layout instead, which is the one place the answer exists.
        //
        // Still identity rather than an offset, which is `SPEC.md` §10's rule and not a detail: an
        // offset is a number about a layout that is allowed to be wrong below the fold.
        //
        // **It lands about 120pt short of the file's top, measured rather than assumed**, and the
        // baseline is what says so: the chosen file's header sits near the top of the screen with
        // the tail of the file above it still showing, rather than pinned at the top. Anchoring, the
        // explicit section identity and the target layout were each tried and none of them moves it,
        // so it is `scrollPosition` and pinned section headers interacting — the reader gets the file
        // they tapped either way, and closing the last 120pt is a question for a real scroll under a
        // real thumb. See `.ai/docs/status.md`.
        .scrollPosition(id: $scrolledTo, anchor: .top)
        // **The one gesture that re-reads this screen, and the only place a reader can make it is the
        // top of the scroll.** That is what settles it against `SPEC.md` §10: a read replaces every
        // entry, drops what has been lexed and re-fetches every batch, and the rule forbids that
        // happening *under* a reader — which a pull cannot do, because the pull is the top of the
        // page. It is also what keeps a stale comment's row legal, since staleness still becomes true
        // only across a read that re-measures from there.
        //
        // **Stock, and the indicator is the scroll's own** — nothing is drawn beside the name while
        // it runs, because this read is one the reader can already see themselves asking for.
        .refreshable { await onRefresh() }
        // **`initial: true`, and that is what makes the jump photographable.** A jump target handed
        // to a freshly-built view is a value that has already stopped changing, so a watch that only
        // fires on a *change* would never run — which is true of a snapshot and would be true of any
        // caller that restores a reading position. It costs nothing in the app, where the target
        // starts absent.
        .onChange(of: jumpTarget, initial: true) { _, target in
            guard let target else { return }
            // **Nothing to animate when the scroll is already there**, which is the seeded first
            // layout and is also a reader tapping the file they are looking at. Animating it anyway
            // re-ran the transition from where it had already landed, and the baseline caught the
            // scroll mid-flight at a different offset on each run.
            if scrolledTo != target {
                withAnimation(.easeInOut(duration: 0.2)) {
                    scrolledTo = target
                }
            }
            // Reported back so the same row can be tapped twice: held as the value alone, a second
            // tap would be a change from a value to itself, and the row would go quiet.
            onJumped()
        }
        // **The page, and it is what makes design §4's 10pt separation visible.** The gap was built
        // in 0.6.0 and could not be seen: it was left clear over a screen whose background is the
        // same white as the rows, so 10pt of white sat between two white files. Colouring the page
        // once and giving each file an opaque card is one answer for every boundary — between two
        // bars, between a bar and a header, and under the last file — where a rule per boundary
        // would be four.
        .background(Color.diffPage)
    }

    /// **A shut file is a bar in the header's slot with nothing under it**, rather than a header
    /// over an empty section. The bar is what design §4 draws, it is what carries the reason, and
    /// putting it where the header goes is what makes shutting a file a change the reader can see
    /// happen in one place.
    /// **The three callbacks go straight through** rather than through a closure that re-attaches
    /// the file's identifier: each of those views holds the file already, so a wrapper here would be
    /// one per row per frame and one more place for the wrong identifier to be attached.
    @ViewBuilder private func header(of entry: ContinuousDiffEntry) -> some View {
        if entry.collapse.isCollapsed {
            DiffCollapsedFileBar(
                file: entry.file,
                collapse: entry.collapse,
                commentCount: count(in: entry.id),
                onSetOpen: onSetOpen
            )
        } else {
            DiffFileHeader(
                file: entry.file,
                commentCount: count(in: entry.id),
                onSetOpen: onSetOpen,
                onSetViewed: onSetViewed
            )
        }
    }

    /// Every comment on this file, whether or not its lines are still there — the chip counts what
    /// the reader wrote, and a stale one is still in the review and still in the document.
    private func count(in file: FileID) -> Int {
        comments.count { $0.comment.anchor.file == file }
    }

    /// How many comments this file can no longer draw a rail for, and the earliest line one of them
    /// named — or nothing at all, which is every file in an ordinary change set.
    private func stale(of entry: ContinuousDiffEntry) -> (count: Int, firstLine: Int)? {
        let gone = comments.filter { $0.isStale && $0.comment.anchor.file == entry.id }
        guard let first = gone.map(\.comment.lines.first).min() else { return nil }
        return (gone.count, first)
    }

    /// **The gap between two files, and the review's seventh fault.** Without it a collapsed bar
    /// floats in the same 8pt of white as the closing brace of the file above it, and twice on the
    /// photographed screen a file header sat directly under a code row — so the code above read as
    /// belonging to the file below.
    ///
    /// It goes at the *foot* of a section rather than the head of the next one, because the head of a
    /// section is the pinned header: a gap there would either travel up with the pin or be left
    /// behind by it, and both are the header changing height while it floats.
    static let betweenFiles: CGFloat = 10

    @ViewBuilder private func content(of entry: ContinuousDiffEntry) -> some View {
        // **The card**, opaque and full width, so the page only shows where the gap is. A file's
        // lines draw their own tints and nothing behind them, which over a coloured page would tint
        // every context row.
        fileBody(of: entry)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.diffCard)
        // A shut file gets the gap too — the bars are what a reader scans down when most of a change
        // set is reviewed, and bars with nothing between them are one bar with several names.
        Color.clear
            .frame(height: Self.betweenFiles)
    }

    @ViewBuilder private func fileBody(of entry: ContinuousDiffEntry) -> some View {
        if entry.collapse.isCollapsed {
            // Nothing at all, which is the whole point of a bar: the height a shut file takes is
            // the 44pt its bar takes and not one row more.
            EmptyView()
        } else {
            // **Under the header and above the code**, which is the only place left for a comment
            // whose rows are gone. See `StaleCommentRow` for why inserting 44pt here does not break
            // the no-reflow rule, and for what would make it start breaking it.
            //
            // **One row for the file rather than one per comment.** Two of them stacked would be 88pt
            // of chrome saying the same sentence twice, and the second one's line number is a handle
            // on something the reader has to open the review to see anyway.
            if let stale = stale(of: entry) {
                StaleCommentRow(count: stale.count, line: stale.firstLine, onOpenReview: onOpenReview)
            }
            switch entry.content {
            case .awaiting(let file):
                // **Still no spinner, and still for the reason that kept one off this screen**: five
                // files are in flight at once, the reader is waiting on none of them, and there is no
                // per-file measurement the Mac could report. What replaced the blank is not an
                // instrument — it is the rows the file has not sent yet, under one sentence saying
                // who is being asked. Design §9.
                DiffAwaitingBody(
                    file: file,
                    wait: isWaitingLong ? .stillReading : .reading,
                    rows: entry.reservedRows,
                    pointSize: pointSize
                )
                // **The skeleton fades out where the code fades in**, rather than one replacing the
                // other in a frame. Paired with the height animation on the stack above, what the
                // reader sees is a file arriving; without it, the same two facts arrive as a flicker
                // and a jump.
                .transition(.opacity)
            case .failed(let file):
                // The same block with the sweep stopped and the bars at half weight, which on a
                // screen where four other cards are moving makes the one that has stopped visible
                // from across the room. The sentence is there for the reader who arrives after
                // everything has stopped.
                DiffAwaitingBody(
                    file: file,
                    wait: .failed,
                    rows: entry.reservedRows,
                    pointSize: pointSize
                )
            case .ready(let diff):
                // **A picture draws pictures where a file draws hunks, and it has none to draw.**
                // Git answers `Binary files … differ` for a PNG, so this card's `FileDiff` is a real
                // answer with an empty body — before this existed the whole file was a collapsed bar
                // reading `binary · no diff to show` with no chevron on it, which is the smallest
                // possible lie about a file with two pictures behind it. The bytes arrive beside the
                // diff rather than inside it, which is why the branch is a lookup here rather than a
                // case on the content.
                if let image = images[entry.id] {
                    DiffImageBody(
                        file: diff.file,
                        image: image,
                        onOpen: onOpenImage,
                        onRetry: onRetryImage
                    )
                    .transition(.opacity)
                } else {
                    DiffFileContent(
                        diff: diff,
                        pointSize: pointSize,
                        isSplit: isSplit,
                        // The rails are drawn from the comments that still resolve; a stale one has
                        // the row above instead. Handed the raw comments because `CommentRail` is
                        // what decides which of them this file's hunks can place.
                        comments: comments.filter { $0.isStale == false }.map(\.comment),
                        pending: pending,
                        // Nothing at all until this file's first side lands, which is every file for
                        // the first beat and a refused one forever.
                        highlighted: highlighted[entry.id] ?? .none,
                        acceptsTargeting: acceptsTargeting,
                        onExpand: onExpand,
                        onTapGutter: onTapGutter,
                        onLongPressGutter: onLongPressGutter
                    )
                    .transition(.opacity)
                }
            }
        }
    }

    private var failed: some View {
        ContentUnavailableView {
            Label("Could not read this worktree", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Try again. If it still fails, check that Granita is running on your Mac.")
        } actions: {
            Button("Try Again", action: onRetry)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            copyLogs
        }
        .animation(reduceMotion ? nil : .default, value: logCopyState)
    }

    private var copyLogs: some View {
        VStack(spacing: 8) {
            Button(action: onCopyLogs) {
                switch logCopyState {
                case .ready: Text("Copy Logs")
                case .copying: Text("Copying Logs…")
                case .copied: Text("Copy Logs Again")
                case .failed: Text("Try Copying Again")
                }
            }
            .buttonStyle(.borderless)
            .controlSize(.large)
            .disabled(logCopyState == .copying)

            switch logCopyState {
            case .ready, .copying:
                EmptyView()
            case .copied:
                Text("Logs copied. Paste them into your message.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .failed:
                Text("Couldn’t copy logs. Please try again.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
    }

    /// **No action, and that is the design rather than an omission.** A reader reaches this by
    /// choosing *Show them anyway* in the sidebar and then opening a worktree they were told was
    /// clean, so the screen owes them a confirmation rather than something to press.
    private var nothingChanged: some View {
        ContentUnavailableView {
            Label("Nothing to review", systemImage: "checkmark.circle")
        } description: {
            Text("This worktree has no uncommitted changes.")
        }
    }
}
