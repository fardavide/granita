import SwiftUI

import ClientConnectionDomain
import ClientViewerDomain
import CoreDiffDomain

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
    private let showsOldNumber: Bool

    /// The file §3's selector asked this scroll to go to, and nothing about how far it got.
    private let jumpTarget: FileID?

    private let onReading: (Int) -> Void
    private let onJumped: () -> Void
    private let onSetViewed: (Bool, FileID) -> Void
    private let onSetOpen: (Bool, FileID) -> Void
    private let onExpand: (ContextDirection, Int, FileID) -> Void
    private let onRetry: () -> Void

    public init(
        state: ContinuousDiffState,
        showsOldNumber: Bool,
        jumpTarget: FileID?,
        onReading: @escaping (Int) -> Void,
        onJumped: @escaping () -> Void,
        onSetViewed: @escaping (Bool, FileID) -> Void,
        onSetOpen: @escaping (Bool, FileID) -> Void,
        onExpand: @escaping (ContextDirection, Int, FileID) -> Void,
        onRetry: @escaping () -> Void
    ) {
        self.state = state
        self.showsOldNumber = showsOldNumber
        self.jumpTarget = jumpTarget
        // Seeded with the jump when there is one and with the first file otherwise, so the position
        // is a value this view stated rather than one the scroll settled on by itself.
        _scrolledTo = State(initialValue: jumpTarget ?? state.firstFile)
        self.onReading = onReading
        self.onJumped = onJumped
        self.onSetViewed = onSetViewed
        self.onSetOpen = onSetOpen
        self.onExpand = onExpand
        self.onRetry = onRetry
    }

    public var body: some View {
        switch state {
        case .loading:
            // A progress view promises a finish and this one has it: a request either answers or
            // fails. The spinner design §1 refuses for a Bonjour browse is the right control here.
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let failure):
            failed(failure)
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
            // two. Keyed on nothing but the collapse flags, so a diff arriving still lands without
            // dragging the scroll around. The curve is stated once, in `Animation.disclosure`.
            //
            // Under `.scrollTargetLayout()` rather than over it: the marker wants the stack itself,
            // and a jump landing on a file is a different gesture from a file opening under a thumb.
            .animation(.disclosure, value: entries.map(\.collapse.isCollapsed))
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
        // real thumb. See `.claude/docs/status.md`.
        .scrollPosition(id: $scrolledTo, anchor: .top)
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
            DiffCollapsedFileBar(file: entry.file, collapse: entry.collapse, onSetOpen: onSetOpen)
        } else {
            DiffFileHeader(file: entry.file, onSetOpen: onSetOpen, onSetViewed: onSetViewed)
        }
    }

    @ViewBuilder private func content(of entry: ContinuousDiffEntry) -> some View {
        if entry.collapse.isCollapsed {
            // Nothing at all, which is the whole point of a bar: the height a shut file takes is
            // the 44pt its bar takes and not one row more.
            EmptyView()
        } else {
            switch entry.content {
            case .awaiting:
                // Deliberately empty rather than a spinner. There is no per-file progress worth
                // reporting — five files are in flight at once and the reader is not waiting on any
                // of them — and a row of spinners scrolling past would be the app describing its own
                // plumbing.
                Color.clear
                    .frame(height: reservedHeight(of: entry))
            case .ready(let diff):
                DiffFileContent(diff: diff, showsOldNumber: showsOldNumber, onExpand: onExpand)
            }
        }
    }

    /// Three slots, three jobs — the shape design §1 settled and every empty state in this app has
    /// used since. The description is ours; the action retries; the machine's own sentence goes to
    /// the bottom in small print, where it is copyable into a bug report and unmistakably not
    /// instructions.
    private func failed(_ failure: ApiFailure) -> some View {
        ContentUnavailableView {
            Label("Could not read this worktree", systemImage: "exclamationmark.triangle")
        } description: {
            Text(
                """
                Something stopped Granita from reading what changed here. Trying again usually \
                works; if it does not, check that Granita is still running on your Mac.
                """
            )
        } actions: {
            Button("Try Again", action: onRetry)
                .buttonStyle(.borderedProminent)
            if let diagnostic = failure.diagnostic {
                Text(diagnostic)
                    .font(.caption2)
                    .monospaced()
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .padding(.top)
            }
        }
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

    private func reservedHeight(of entry: ContinuousDiffEntry) -> CGFloat {
        CGFloat(entry.reservedRows) * DiffLineHeight.at(pointSize: DiffFileLines.codePointSize)
    }
}
