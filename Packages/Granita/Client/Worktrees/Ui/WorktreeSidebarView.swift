import SwiftUI

import ClientConnectionDomain
import ClientWorktreesDomain
import CoreDiffDomain

/// The screen this product exists for: which checkouts an agent has been working in, and how big a
/// read each one is.
///
/// Stateless. It renders the state it is handed and reports what the reader asked for, so all five
/// states — including the two nobody can produce on demand — can be put in front of a camera without
/// a Mac, a network or a paired device.
public struct WorktreeSidebarView: View {

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// §2's measure for the sidebar, and it is *narrower* than the phone's 390: "the iPad is the
    /// harder layout for this row, not the easier one, and the drop order above is what saves it."
    ///
    /// Pinned rather than inherited from whatever the system hands a sidebar, so the arithmetic §2
    /// works the row's drop order out against is the arithmetic the baselines assert. It lives on
    /// the view rather than on the split screen that applies it because a generic type may hold no
    /// static stored property — and because it is a fact about this row either way.
    public static let widthInASplitView: CGFloat = 320

    private let macName: String
    private let state: WorktreeSidebarState
    private let readStage: WorktreeReadStage
    private let readTiming: WorktreeReadTiming
    private let readResult: WorktreeReadResult
    private let isRetryingRefresh: Bool
    private let isAutomaticallyRefreshing: Bool
    private let reduceMotion: Bool
    private let now: Date
    private let logCopyState: DiagnosticCopyState
    private let mode: WorktreeListMode
    private let showsQuietWorktrees: Bool
    // Both reach a `Binding`'s setter, which iOS 26 declares `@isolated(any) @Sendable`, so each
    // conversion warns. **Annotating them `@MainActor @Sendable` crashes the compiler** — Swift
    // 6.3.3 aborts in IRGen emitting the reabstraction thunk, `SmallVector unable to grow`. The
    // warning is the lesser of the two, and this module is main-actor by default, so what it warns
    // about cannot happen here.
    private let onChooseMode: (WorktreeListMode) -> Void
    private let onShowQuietWorktrees: (Bool) -> Void
    private let onRename: (WorktreeRenameSubject) -> Void
    private let onSetPinned: (Bool, WorktreeID) -> Void
    private let onDelete: (WorktreeDeletionSubject) -> Void
    private let onRetry: () -> Void
    private let onRefresh: () async -> Void
    private let onPairAgain: () -> Void
    private let onCopyLogs: () -> Void

    /// The rows whose directory is being taken off the Mac right now, dimmed and not operable until
    /// the answer arrives.
    private let removing: Set<WorktreeID>

    public init(
        macName: String,
        state: WorktreeSidebarState,
        readStage: WorktreeReadStage,
        readTiming: WorktreeReadTiming,
        readResult: WorktreeReadResult,
        isRetryingRefresh: Bool,
        isAutomaticallyRefreshing: Bool,
        reduceMotion: Bool,
        now: Date,
        logCopyState: DiagnosticCopyState,
        mode: WorktreeListMode,
        showsQuietWorktrees: Bool,
        removing: Set<WorktreeID>,
        onChooseMode: @escaping (WorktreeListMode) -> Void,
        onShowQuietWorktrees: @escaping (Bool) -> Void,
        onRename: @escaping (WorktreeRenameSubject) -> Void,
        onSetPinned: @escaping (Bool, WorktreeID) -> Void,
        onDelete: @escaping (WorktreeDeletionSubject) -> Void,
        onRetry: @escaping () -> Void,
        onRefresh: @escaping () async -> Void,
        onPairAgain: @escaping () -> Void,
        onCopyLogs: @escaping () -> Void
    ) {
        self.macName = macName
        self.state = state
        self.readStage = readStage
        self.readTiming = readTiming
        self.readResult = readResult
        self.isRetryingRefresh = isRetryingRefresh
        self.isAutomaticallyRefreshing = isAutomaticallyRefreshing
        self.reduceMotion = reduceMotion
        self.now = now
        self.logCopyState = logCopyState
        self.mode = mode
        self.showsQuietWorktrees = showsQuietWorktrees
        self.removing = removing
        self.onChooseMode = onChooseMode
        self.onShowQuietWorktrees = onShowQuietWorktrees
        self.onRename = onRename
        self.onSetPinned = onSetPinned
        self.onDelete = onDelete
        self.onRetry = onRetry
        self.onRefresh = onRefresh
        self.onPairAgain = onPairAgain
        self.onCopyLogs = onCopyLogs
    }

    public var body: some View {
        Group {
            switch state {
            case .loading:
                loading
            case .failed:
                failed
            case .noProjects:
                emptyResult(noProjects)
            case .allQuiet(let worktreeCount, let projectNames):
                emptyResult(allQuiet(worktreeCount: worktreeCount, projectNames: projectNames))
            case .listing(let listing):
                list(listing)
            }
        }
        // **The Mac's name, which design §5 asks for and which has to be set here.** A
        // `.navigationTitle` applied to the container outside this screen does not override one
        // applied inside it — measured, not assumed — so *Worktrees* stood at the top of this list
        // for a release while the pairing that opened it knew perfectly well whose Mac it was.
        // Nothing else on the screen says which machine is being read, and a phone that can reach
        // two of them has no other way to tell.
        .navigationTitle(macName)
        // **Inline, and that is what the name cost.** A large title is 34pt bold, which fits about
        // sixteen characters at 390pt and fewer in the iPad's 320pt sidebar — and it truncates at
        // the tail, so *Davide's 16-inch MacBook Pro* arrived as *Davide's 16-inch Mac…*. Design §1
        // derives the direction from what the string is, and a Bonjour device name differs at its
        // end: tail truncation drops precisely the half that says which Mac. Inline is 17pt
        // semibold, so the whole name fits and the list gets back 52pt of every scroll. Measured,
        // and recorded in `design.md` §2 with the alternative it replaces.
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        // **One modifier holding both, and never one each.** Several modifiers of the same kind on
        // one view is the shape where only one takes effect — the same reason this unit drives two
        // prompts from one `.alert`.
        .toolbar {
            arrangement
            titleWithActivity
        }
        .animation(reduceMotion ? nil : .default, value: logCopyState)
        .animation(reduceMotion ? nil : .default, value: state)
        .animation(reduceMotion ? nil : .default, value: readResult)
        .animation(reduceMotion ? nil : .default, value: isRetryingRefresh)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: state == .loading)
    }

    private var loading: some View {
        let description = WorktreeLoadingDescription(
            stage: readStage, macName: macName, elapsed: readTiming.elapsed(at: now)
        )
        return GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(description.headline).font(.headline)
                        Text(description.sentence).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)

                    if description.isLongWait {
                        elapsed
                        if case .reading = readStage {
                            Text("Your Mac describes every worktree in every enabled project before it answers, so this grows with the number of projects you have enabled.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        copyLogs
                    }
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, geometry.size.width <= Self.widthInASplitView ? 24 : 40)
                .padding(.top, dynamicTypeSize.isAccessibilitySize ? 40 : max(24, geometry.size.height * 0.46))
                .padding(.bottom, 24)
                .animation(reduceMotion ? nil : .default, value: description.isLongWait)
                .animation(reduceMotion ? nil : .default, value: readStage)
            }
        }
    }

    @ViewBuilder private var elapsed: some View {
        switch readTiming {
        case .notStarted:
            EmptyView()
        case .running, .finished:
            let seconds = Int(readTiming.elapsed(at: now))
            Text("\(state == .loading ? "Waiting" : "Waited") \(seconds / 60):\(String(format: "%02d", seconds % 60))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
                .textSelection(.enabled)
        }
    }

    /// One menu holding an inline picker and a toggle, rather than a segmented control.
    ///
    /// A segmented picker is a permanent 32pt band plus 16pt of padding — 48pt of every scroll for a
    /// preference set once — and it lands directly above the Pinned header, so the first thing the
    /// reader sees is two rows of chrome. There is already a second preference beside the mode and
    /// probably a third: three toggles cannot be three segmented controls, but they are three menu
    /// rows without a redesign.
    @ToolbarContentBuilder private var arrangement: some ToolbarContent {
        if state.isArrangeable {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker(
                        "Arrangement",
                        selection: Binding(get: { mode }, set: onChooseMode)
                    ) {
                        Text("Grouped by project").tag(WorktreeListMode.groupedByProject)
                        Text("Most recent first").tag(WorktreeListMode.mostRecentFirst)
                    }
                    .pickerStyle(.inline)

                    Toggle(
                        "Show worktrees with no changes",
                        isOn: Binding(get: { showsQuietWorktrees }, set: onShowQuietWorktrees)
                    )
                } label: {
                    Label("Arrange", systemImage: "ellipsis.circle")
                }
            }
        }
    }

    /// The read nobody pressed, reported where reporting it costs the list nothing.
    ///
    /// **Beside the Mac's name rather than above the rows, and that is the whole point of it.**
    /// Design §8 gives *Try Again* a progress view at the top of the list, which inserts a row and
    /// pushes every worktree down to make space — the right trade when the reader pressed a control
    /// and is waiting on its answer, and an unasked-for shove when the read started merely because
    /// this screen came back. The toolbar has a slot standing empty and nothing in the list moves.
    ///
    /// **`.navigation` rather than `.principal`.** Putting the spinner in the title slot means
    /// drawing the title too, which gives up `.navigationTitle` — and with it the inline treatment
    /// this screen bought the Mac's full name with, and the string the iPad's sidebar column takes
    /// its own header from.
    /// The Mac's name, with the read nobody asked for turning just after it.
    ///
    /// **`.principal`, because the indicator belongs against the name and nothing else in the bar
    /// is.** The leading slot is the back button's side — the far end of the bar from the thing the
    /// spinner is about — and the trailing slot belongs to Arrange. The title slot is the only place
    /// *beside the name* actually is, and reaching it means drawing the title here rather than
    /// leaving it to `.navigationTitle`.
    ///
    /// **`.navigationTitle` stays anyway**, because it is not only what the bar draws: the split
    /// view takes this column's header from it and a pushed screen takes its back-button label from
    /// it, and neither reads a principal item.
    ///
    /// **The item is always here and only the spinner comes and goes**, which is not a style choice:
    /// a `ToolbarItem` that appears and disappears changes what the bar is made of, and a bar
    /// rebuilt while it is being laid out comes back with nothing in it at all. A title that is
    /// always drawn is what keeps the slot occupied between reads.
    ///
    /// Middle truncation, which is design §1's rule for a Bonjour device name and not a default: two
    /// Macs in one house differ at the end of their names, so tail truncation drops precisely the
    /// half that says which one this is.
    private var titleWithActivity: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: 6) {
                Text(macName)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if isAutomaticallyRefreshing {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Refreshing worktrees")
                }
            }
        }
    }

    /// No action, and that is the design rather than an omission: there is nothing on this phone to
    /// tap. The description names the exact menu instead, so the sentence *is* the instruction — a
    /// disabled button, or one opening a "do this on your Mac" modal, would be a control that cannot
    /// act.
    private var noProjects: some View {
        ContentUnavailableView {
            Label("No projects yet", systemImage: "tray")
        } description: {
            Text(
                """
                Add a repository in Granita's menu bar item on your Mac, under Projects. \
                It will appear here straight away.
                """
            )
        }
    }

    /// Here the action is real, and the count in the description is what makes this state
    /// trustworthy rather than alarming: it says the Mac is serving and there is simply nothing to
    /// read.
    private func allQuiet(worktreeCount: Int, projectNames: [String]) -> some View {
        ContentUnavailableView {
            Label("Nothing to review", systemImage: "checkmark.circle")
        } description: {
            if worktreeCount == 1 {
                Text("The one worktree in \(projectNames, format: .list(type: .and)) is clean.")
            } else {
                Text(
                    """
                    All \(worktreeCount, format: .number) worktrees across \
                    \(projectNames, format: .list(type: .and)) are clean.
                    """
                )
            }
        } actions: {
            Button("Show them anyway") { onShowQuietWorktrees(true) }
                .buttonStyle(.borderedProminent)
        }
    }

    private var failed: some View {
        let unauthorized = state == .failed(.unauthorized)
        let connecting: Bool = switch readStage {
        case .finding, .verifying: true
        case .reading: false
        }
        return GeometryReader { geometry in
            ScrollView {
                ContentUnavailableView {
                    Label(unauthorized ? "Pairing was revoked" : connecting ? "Could not reach \(macName)" : "Could not read your Mac", systemImage: "exclamationmark.triangle")
                } description: {
                    if unauthorized {
                        Text("Pair this device with your Mac again to read its worktrees.")
                    } else if connecting {
                        Text("Check that Granita is running on your Mac and that both devices are on the same network or connected over Tailscale.")
                    } else {
                        Text("Try again. If it still fails, check that Granita is running on your Mac.")
                    }
                } actions: {
                    VStack(spacing: 16) {
                        Button(unauthorized ? "Pair Again" : "Try Again", action: unauthorized ? onPairAgain : onRetry)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        if !unauthorized {
                            if case .failed(let failure) = state, let diagnostic = failure.diagnostic {
                                Text(diagnostic)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.tertiary)
                                    .textSelection(.enabled)
                            }
                            elapsed
                            copyLogs
                        }
                    }
                }
                .frame(minHeight: geometry.size.height)
            }
        }
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

    private func list(_ listing: WorktreeListing) -> some View {
        List {
            if isRetryingRefresh {
                Section {
                } header: {
                    ProgressView().frame(maxWidth: .infinity)
                        .accessibilityLabel("Refreshing worktrees")
                }
            }
            if case .stale = readResult {
                Section {
                } header: {
                    refreshNotice
                }
            }
            ForEach(listing.sections) { section in
                Section {
                    ForEach(section.rows) { row in
                        self.row(row)
                    }
                } header: {
                    switch section.id {
                    case .pinned: Text("Pinned")
                    case .project(_, let name): Text(name)
                    case .everything: EmptyView()
                    }
                }
            }

            if listing.quietCount > 0 {
                Section {
                    // Tappable rather than a caption, because the count is only half of what this
                    // line is for: it also has to be the way back to the rows it is describing.
                    Button { onShowQuietWorktrees(true) } label: {
                        if listing.quietCount == 1 {
                            Text("1 worktree with no changes is hidden. Show it.")
                        } else {
                            Text(
                                """
                                \(listing.quietCount, format: .number) worktrees with no changes \
                                are hidden. Show them.
                                """
                            )
                        }
                    }
                    .font(.footnote)
                }
            }
            if readResult != .notRead {
                Section {
                } footer: {
                    Text(readResult.footer(at: now))
                }
            }
        }
        .refreshable { await onRefresh() }
    }

    private var refreshNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(readResult.refreshNotice(at: now))
            Button("Try Again", action: onRetry).buttonStyle(.borderless)
        }
        .font(.footnote)
        .textCase(nil)
    }

    private func emptyResult(_ content: some View) -> some View {
        content
            .safeAreaInset(edge: .top) {
                if isRetryingRefresh {
                    ProgressView().accessibilityLabel("Refreshing worktrees")
                } else if case .stale = readResult {
                    refreshNotice.padding(24)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if readResult != .notRead {
                    Text(readResult.footer(at: now))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(24)
                }
            }
    }

    /// A value-based navigation link rather than a callback: the link supplies the disclosure
    /// indicator on the phone, and in a split-view sidebar it draws no chevron at all and gives the
    /// selected row a tinted selection instead — which is what the iPad wants and what a hand-rolled
    /// button would have to reproduce twice.
    ///
    /// **A row being removed carries neither gesture**, which is why this branches rather than
    /// applying the modifiers conditionally: while a directory is going away the row must not also
    /// be deletable a second time, renameable, pinnable or openable.
    @ViewBuilder private func row(_ row: WorktreeListRow) -> some View {
        if removing.contains(row.id) {
            NavigationLink(value: row.id) { rowContent(row, isRemoving: true) }
                .disabled(true)
        } else {
            NavigationLink(value: row.id) { rowContent(row, isRemoving: false) }
                .contextMenu { actions(for: row) }
                .swipeActions(edge: .trailing) { pinAndRename(row) }
        }
    }

    /// The two reversible verbs, written once and offered by both gestures.
    ///
    /// They were duplicated byte for byte between the swipe and the menu, which is two places for
    /// one label to drift and two closures where the row has one behaviour.
    @ViewBuilder private func pinAndRename(_ row: WorktreeListRow) -> some View {
        Button { onSetPinned(row.isPinned == false, row.id) } label: {
            Label(row.isPinned ? "Unpin" : "Pin", systemImage: row.isPinned ? "pin.slash" : "pin")
        }
        Button { onRename(row.rename) } label: {
            Label("Rename", systemImage: "pencil")
        }
    }

    /// Every verb a row has, in a long press.
    ///
    /// **Deletion is here and deliberately not in the swipe.** A trailing swipe begins the way an
    /// imprecise vertical scroll does, and iOS gives the *first* trailing action the full swipe — so
    /// a destructive third action there is one over-committed thumb away from destroying work that
    /// was never committed and cannot be recovered. A long press requires the finger to stay still,
    /// which is the one thing scrolling never does. Leaving the swipe alone also keeps its full
    /// swipe meaning Pin, which is reversible in one tap.
    ///
    /// Pin and Rename are repeated here rather than left to the swipe, so a reader who long-presses
    /// finds the two verbs they already know above the one they do not.
    @ViewBuilder private func actions(for row: WorktreeListRow) -> some View {
        pinAndRename(row)

        Divider()

        if case .deletable(let subject) = row.deletion {
            // The ellipsis is the promise that a confirmation follows, which is what makes this item
            // safe to press while finding out what a long press does.
            Button(role: .destructive) { onDelete(subject) } label: {
                Label("Delete Worktree…", systemImage: "trash")
            }
        } else if let refusal = row.deletion.refusal {
            // **A disabled control whose whole job is the sentence it carries**, which is why the
            // action is empty and why that is not an oversight: it exists to answer *why is there no
            // Delete here?* at the moment the question is asked. Omitting it would make a row that
            // cannot be deleted indistinguishable from an app that is broken — and the primary
            // checkout is the row design §2 already calls the most confusing in the list.
            //
            // The reason goes in the menu and never on the row: a menu is drawn over the window, so
            // it spends none of the 320pt the sidebar's drop order has already allocated. The whole
            // sentence is the title rather than a subtitle under a dimmed *Delete*, because a menu
            // item's second line is not a rendering worth assuming and a title wraps.
            Button(action: {}) {
                Label(refusal.sentence, systemImage: refusal.symbol)
            }
            .disabled(true)
        }
    }

    /// The row itself, which is the same two lines and a trailing time whether or not it is going
    /// away.
    ///
    /// **Line one never changes.** The name is what identifies which row this is, and a row that
    /// renamed itself the moment it started being deleted would be the one moment a reader most
    /// needs to be sure what they are looking at.
    private func rowContent(_ row: WorktreeListRow, isRemoving: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    if row.showsPinIndicator {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(row.displayName)
                        .font(.headline)
                        // Two lines is the ceiling: three makes a 90pt row, and five of those
                        // is a wall of prose rather than a list.
                        .lineLimit(2)
                        // Tail, which is the opposite of design §1's Macs and for the opposite
                        // reason — a generated directory name is a mnemonic prefix followed by
                        // a ULID, so the front is the only part carrying meaning.
                        .truncationMode(.tail)
                        .monospaced(row.nameTier == .machineGenerated)
                }

                Group {
                    if isRemoving {
                        // The verb the reader pressed, rather than git's `remove`.
                        Text("Deleting…")
                    } else {
                        // The file count is what goes when the line will not fit — it is fourth in
                        // the drop order and the only field here that another column already implies.
                        ViewThatFits(in: .horizontal) {
                            secondLine(row, includingFileCount: true)
                            secondLine(row, includingFileCount: false)
                        }
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isRemoving {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text(row.age.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    /// Built as one `Text` rather than an `HStack` of them so that it truncates as a sentence, and
    /// so `ViewThatFits` has a single measurable thing to choose between.
    private func secondLine(_ row: WorktreeListRow, includingFileCount: Bool) -> Text {
        // **The stats are what the line is built from, and the rest is folded onto the front.**
        // They are the one field this line never drops — every arm below produces something — so
        // starting the join here makes it total. Collecting every field into one array and reducing
        // from its first element instead needed a fallback for an empty array that no row could
        // produce, which is an unreachable branch sitting in a view body forever.
        let stats: Text = switch row.stats {
        case .noCommitsYet:
            Text("no commits yet")
        case .noChanges:
            Text("no changes")
        case .changed(let filesChanged, let insertions, let deletions):
            numbers(filesChanged: includingFileCount ? filesChanged : nil, insertions, deletions)
        }

        var prefix: [Text] = []
        if let projectName = row.projectName {
            prefix.append(Text(projectName))
        }
        if row.isPrimaryCheckout {
            // The reader's own mental model: this is the one the agent did *not* work in, which is
            // also what explains why the row usually has no changes.
            prefix.append(Text("primary checkout"))
        }
        if row.showsDetached {
            prefix.append(Text("detached"))
        }

        // Interpolating one `Text` into another rather than concatenating with `+`, which iOS 26
        // deprecated. The per-part colours survive interpolation, which is the whole reason this is
        // one `Text` and not an `HStack`: it truncates as a sentence, and `ViewThatFits` has a
        // single measurable thing to choose between. Reversed, because each step puts its part in
        // front of everything built so far.
        return prefix.reversed().reduce(stats) { line, part in
            Text("\(part) · \(line)")
        }
    }

    /// `34 files · +1,204 −318`, or the same without the count when the line will not hold it — the
    /// file count being fourth in design §2's drop order and the only field another column implies.
    private func numbers(filesChanged: Int?, _ insertions: Int, _ deletions: Int) -> Text {
        let added = Text("+\(insertions, format: .number)").foregroundColor(.green)
        let removed = Text("−\(deletions, format: .number)").foregroundColor(.red)
        let changes = Text("\(added) \(removed)")
        guard let filesChanged else { return changes }
        let files = filesChanged == 1 ? Text("1 file") : Text("\(filesChanged, format: .number) files")
        return Text("\(files) · \(changes)")
    }
}
