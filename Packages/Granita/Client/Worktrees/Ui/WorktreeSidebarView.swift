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

    private let macName: String
    private let state: WorktreeSidebarState
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
    private let onRetry: () -> Void

    public init(
        macName: String,
        state: WorktreeSidebarState,
        mode: WorktreeListMode,
        showsQuietWorktrees: Bool,
        onChooseMode: @escaping (WorktreeListMode) -> Void,
        onShowQuietWorktrees: @escaping (Bool) -> Void,
        onRename: @escaping (WorktreeRenameSubject) -> Void,
        onSetPinned: @escaping (Bool, WorktreeID) -> Void,
        onRetry: @escaping () -> Void
    ) {
        self.macName = macName
        self.state = state
        self.mode = mode
        self.showsQuietWorktrees = showsQuietWorktrees
        self.onChooseMode = onChooseMode
        self.onShowQuietWorktrees = onShowQuietWorktrees
        self.onRename = onRename
        self.onSetPinned = onSetPinned
        self.onRetry = onRetry
    }

    public var body: some View {
        Group {
            switch state {
            case .loading:
                // A progress view promises a finish, and unlike a Bonjour browse this one has
                // one — a request either answers or fails. So the spinner discovery refuses is the
                // right control here.
                ProgressView()
            case .failed(let failure):
                failed(failure)
            case .noProjects:
                noProjects
            case .allQuiet(let worktreeCount, let projectNames):
                allQuiet(worktreeCount: worktreeCount, projectNames: projectNames)
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
        .toolbar { arrangement }
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

    /// Three slots, three jobs — the same shape design §1 settled and for the same reasons. The
    /// description is ours; the action retries; the machine's own sentence goes to the bottom in
    /// small print, where it is copyable into a bug report and unmistakably not instructions.
    private func failed(_ failure: ApiFailure) -> some View {
        ContentUnavailableView {
            Label("Could not read your Mac", systemImage: "exclamationmark.triangle")
        } description: {
            Text(
                """
                Something stopped Granita from reading the worktrees on your Mac. Trying again \
                usually works; if it does not, check that Granita is still running there.
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

    private func list(_ listing: WorktreeListing) -> some View {
        List {
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
        }
    }

    /// A value-based navigation link rather than a callback: the link supplies the disclosure
    /// indicator on the phone, and in a split-view sidebar it draws no chevron at all and gives the
    /// selected row a tinted selection instead — which is what the iPad wants and what a hand-rolled
    /// button would have to reproduce twice.
    private func row(_ row: WorktreeListRow) -> some View {
        NavigationLink(value: row.id) {
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

                    // The file count is what goes when the line will not fit — it is fourth in the
                    // drop order and the only field here that another column already implies.
                    ViewThatFits(in: .horizontal) {
                        secondLine(row, includingFileCount: true)
                        secondLine(row, includingFileCount: false)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(row.age.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .swipeActions(edge: .trailing) {
            Button { onSetPinned(row.isPinned == false, row.id) } label: {
                Label(
                    row.isPinned ? "Unpin" : "Pin",
                    systemImage: row.isPinned ? "pin.slash" : "pin"
                )
            }
            Button { onRename(row.rename) } label: {
                Label("Rename", systemImage: "pencil")
            }
        }
    }

    /// Built as one `Text` rather than an `HStack` of them so that it truncates as a sentence, and
    /// so `ViewThatFits` has a single measurable thing to choose between.
    private func secondLine(_ row: WorktreeListRow, includingFileCount: Bool) -> Text {
        var parts: [Text] = []
        if let projectName = row.projectName {
            parts.append(Text(projectName))
        }
        if row.isPrimaryCheckout {
            // The reader's own mental model: this is the one the agent did *not* work in, which is
            // also what explains why the row usually has no changes.
            parts.append(Text("primary checkout"))
        }
        if row.showsDetached {
            parts.append(Text("detached"))
        }
        switch row.stats {
        case .noCommitsYet:
            parts.append(Text("no commits yet"))
        case .noChanges:
            parts.append(Text("no changes"))
        case .changed(let filesChanged, let insertions, let deletions):
            if includingFileCount {
                parts.append(
                    filesChanged == 1
                        ? Text("1 file")
                        : Text("\(filesChanged, format: .number) files")
                )
            }
            let added = Text("+\(insertions, format: .number)").foregroundColor(.green)
            let removed = Text("−\(deletions, format: .number)").foregroundColor(.red)
            parts.append(Text("\(added) \(removed)"))
        }
        // Interpolating one `Text` into another rather than concatenating with `+`, which iOS 26
        // deprecated. The per-part colours survive interpolation, which is the whole reason this is
        // one `Text` and not an `HStack`: it truncates as a sentence, and `ViewThatFits` has a
        // single measurable thing to choose between.
        return parts.dropFirst().reduce(parts.first ?? Text(verbatim: "")) { line, part in
            Text("\(line) · \(part)")
        }
    }
}
