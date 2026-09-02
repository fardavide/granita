import SwiftUI

import ClientViewerDomain
import CoreDiffDomain

/// Design §3: which files changed, where they sit, and how much of the read is left.
///
/// **Its job is to jump**, and its second job is to be the only place a reader can see how much of a
/// change set they have got through. That second job is why it is a list rather than the menu the
/// review rejected: a menu cannot indent, cannot be scrolled to three hundred items, and cannot show
/// *viewed* across the whole set.
///
/// Stateless. It draws the listing it is handed and reports what was pressed, so every state — the
/// tree, the flat list, a shut directory, a truncated change set, a finished one — can be put in
/// front of a camera without a Mac.
public struct FileSelectorView: View {

    /// §3's iPad measure, and the same 320 the worktree sidebar takes: three columns at
    /// 320 / 320 / 554 is where design §4 says this product is pleasant to use.
    ///
    /// It lives on the view because it is a fact about this list rather than about whatever is
    /// beside it, which is where `WorktreeSidebarView` keeps its own for the same reason.
    public static let widthBesideTheDiff: CGFloat = 320

    /// §3's rows are 32pt and 34pt, which the list's own insets are roughly twice. A selector is
    /// worth having because it shows a whole change set at once, and default insets cost a third of
    /// the rows on screen.
    ///
    /// **Applied inside the row rather than as `listRowInsets`, so the press highlight reaches the
    /// bezel.** A row's own tap feedback is the thing that says the tap was received, and one that
    /// stops 12pt short at each end reads as a chip floating in a list rather than as the row being
    /// pressed. The insets are stated once here and spent in two places: zero given to the list, and
    /// this given to each row's label.
    /// `nonisolated` because the list's separator guide is a `Sendable` closure and this is the one
    /// number it needs.
    private nonisolated static let rowInsets = EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)

    private let listing: FileSelectorListing
    private let onChoose: (FileID) -> Void
    private let onToggleDirectory: (String) -> Void
    private let onChooseMode: (FileSelectorMode) -> Void

    public init(
        listing: FileSelectorListing,
        onChoose: @escaping (FileID) -> Void,
        onToggleDirectory: @escaping (String) -> Void,
        onChooseMode: @escaping (FileSelectorMode) -> Void
    ) {
        self.listing = listing
        self.onChoose = onChoose
        self.onToggleDirectory = onToggleDirectory
        self.onChooseMode = onChooseMode
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            title
            List {
                ForEach(listing.rows) { row in
                    Group {
                        switch row {
                        case .directory(let directory): self.directory(directory)
                        case .file(let file): self.file(file)
                        }
                    }
                    // Nothing, because the row's own label carries them — see `rowInsets`. The
                    // separator takes its leading edge from the row's content, which is now the list's
                    // own edge, so it is put back where the insets used to put it: past the margin and
                    // past this row's indent, which is what makes a run of separators read the tree.
                    .listRowInsets(EdgeInsets())
                    .alignmentGuide(.listRowSeparatorLeading) { _ in
                        Self.rowInsets.leading + Self.indent(atDepth: row.depth)
                    }
                }
                if let footer = listing.footer {
                    self.footer(footer)
                }
            }
            .listStyle(.plain)
            // **Pinned, because the row here is width-critical and the list's own margin is not
            // stable.** §3's label is a head-truncated path at the edge of what fits, so four points
            // of margin is one character of directory — and inside the iPad's split view that margin
            // was measured arriving at two different values for the same layout, which moved the
            // truncation between two renders of an unchanged screen. The inset the rows want is
            // stated above; this stops a second one being added underneath it.
            .contentMargins(.horizontal, 0, for: .scrollContent)
            // **Shutting a directory takes its children out from under the reader's finger**, and
            // the row they were about to tap is wherever the list settles. Keyed on the rows
            // themselves, so the chevron turning, the stats a shut row gains and the children
            // leaving are one movement rather than three things that happen to change together.
            .animation(.disclosure, value: listing.rows)
        }
    }

    /// The sheet's own heading, drawn here rather than by whatever presents it — a drawer on the
    /// phone and a column on the iPad are two presentations of one list, and a title supplied twice
    /// is a title that can differ.
    private var title: some View {
        HStack {
            Text("Files")
                .font(.headline)
            Spacer()
            // **Absent rather than disabled** when a tree would say nothing the flat list does not:
            // over three files, or over a change set that is all one directory, there is no second
            // arrangement to offer and a greyed control would be asking about one.
            if listing.offersModeToggle {
                Menu {
                    Picker(
                        "Arrangement",
                        selection: Binding(get: { listing.mode }, set: onChooseMode)
                    ) {
                        Text("Grouped by folder").tag(FileSelectorMode.tree)
                        Text("Full paths").tag(FileSelectorMode.flat)
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("Arrange", systemImage: "ellipsis.circle")
                        // The glyph alone, with the word left for the accessibility label: this
                        // heading is 44pt of a sheet whose whole job is the list under it.
                        .labelStyle(.iconOnly)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func directory(_ directory: FileSelectorDirectory) -> some View {
        Button { onToggleDirectory(directory.path) } label: {
            HStack(spacing: 6) {
                Image(systemName: directory.isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 12)
                Text(verbatim: directory.name)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    // Head, which design §3 derives from what the string is: a compacted chain's
                    // tail is the directory that identifies it, and its head is the part every
                    // sibling shares.
                    .truncationMode(.head)
                Spacer(minLength: 8)
                // Only while it is shut. Open, its children are right there with their own numbers.
                if let stats = directory.stats {
                    changeStatsText(stats)
                        .font(.caption)
                        .monospacedDigit()
                }
                viewedMark(isViewed: directory.isEntirelyViewed)
            }
            .padding(.leading, Self.indent(atDepth: directory.depth))
            .padding(Self.rowInsets)
            .contentShape(.rect)
        }
        .buttonStyle(.pressedRow)
        .accessibilityLabel(
            directory.isExpanded
                ? "\(directory.name), expanded"
                : "\(directory.name), collapsed"
        )
    }

    /// **The row's whole job is to jump**, which is why the viewed mark beside it is a report and
    /// never a control: a 32pt row inside a sheet cannot hold two tap targets without generating
    /// mis-taps. The toggle lives in the diff's file header, where the reader is when they finish.
    ///
    /// **And a row whose job is to jump has to say it was pressed.** What the tap does is scroll a
    /// diff the reader may not be able to see — behind the drawer at its full height, or off the top
    /// of a long change set — so without a press highlight the only feedback for the one control on
    /// this screen is a change somewhere else. `.plain` draws none inside a `List`, which is what
    /// this style replaces.
    private func file(_ file: FileSelectorFile) -> some View {
        Button { onChoose(file.id) } label: {
            // Design §3's drop order, as the two things that can go: the stats first, because the
            // file header repeats them 200ms after the jump, and then the check — a dimmed filename
            // already means "done" and needs no glyph beside it.
            ViewThatFits(in: .horizontal) {
                row(file, showingStats: true, showingMark: true)
                row(file, showingStats: false, showingMark: true)
                row(file, showingStats: false, showingMark: false)
            }
            .padding(Self.rowInsets)
            .contentShape(.rect)
        }
        .buttonStyle(.pressedRow)
    }

    private func row(_ file: FileSelectorFile, showingStats: Bool, showingMark: Bool) -> some View {
        HStack(spacing: 8) {
            // Status leads, because it is part of the file's identity and it aligns into a column
            // the eye can scan down. Viewed trails. Both on the trailing edge is the
            // two-checkboxes problem.
            FileStatusLetter(status: file.status)
                .frame(width: 11, alignment: .leading)
            name(of: file)
            Spacer(minLength: 8)
            if showingStats {
                changeStatsText(file.stats)
                    .font(.caption)
                    .monospacedDigit()
            }
            if showingMark {
                viewedMark(isViewed: file.isViewed)
            }
        }
        .padding(.leading, Self.indent(atDepth: file.depth))
    }

    /// One text view holding one or two runs, which is design §3's "same row, different label".
    ///
    /// **The prefix belongs to flat mode and to nothing else.** In a tree the directories above the
    /// file are rows of their own, right there and indented — repeating them on the row is the same
    /// path said twice, and the first render of this view did exactly that: every filename arrived
    /// behind a prefix that then squeezed the stats and the viewed mark out of the row entirely.
    ///
    /// Two runs rather than two views is what makes flat's truncation right: the prefix erodes from
    /// its head and the filename never does, and a `Text` interpolated into a `Text` truncates as one
    /// string while keeping each run's own font.
    private func name(of file: FileSelectorFile) -> some View {
        let filename = Text(verbatim: file.name)
            .font(.subheadline)
        let label = listing.mode == .tree || file.directoryPrefix.isEmpty
            ? filename
            : Text("\(Text(verbatim: file.directoryPrefix).font(.footnote).foregroundColor(.secondary))\(filename)")
        return label
            .lineLimit(1)
            .truncationMode(.head)
            // A dimmed filename is what "done" reads as, and it is the half of the viewed state that
            // survives the row running out of width.
            .foregroundStyle(file.isViewed ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
    }

    /// Kept in the layout at either state so the column of names ends where it ends: a mark that
    /// takes its width back when it is absent moves every name on the screen as files are read.
    private func viewedMark(isViewed: Bool) -> some View {
        Image(systemName: "checkmark")
            .font(.caption)
            .foregroundStyle(isViewed ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.clear))
            .frame(width: 14)
            .accessibilityLabel(isViewed ? "Viewed" : "Not viewed")
    }

    /// A sentence rather than a control, in both cases and for the same reason: neither says
    /// anything the reader can act on from this phone.
    private func footer(_ footer: FileSelectorFooter) -> some View {
        Group {
            switch footer {
            case .notAllServed(let shown):
                // "Not served" rather than "load more": the Mac's limits will not serve them, and a
                // button that cannot succeed is worse than a sentence that explains.
                Text(
                    """
                    Showing the first \(shown, format: .number) changed files. \
                    Your Mac does not serve more than that at once.
                    """
                )
            case .everythingViewed(let count):
                // Not an unavailable-content view: the files are still there and still openable, and
                // the reader's next move is to leave rather than to be congratulated.
                Text(
                    count == 1
                        ? "The 1 file here is viewed."
                        : "All \(count, format: .number) files viewed."
                )
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .listRowSeparator(.hidden)
    }

    /// `nonisolated` and `static` because the separator's own guide is a `Sendable` closure, and the
    /// separator has to start where the row's content does or a run of them stops reading as a tree.
    private nonisolated static func indent(atDepth depth: Int) -> CGFloat {
        CGFloat(FileSelectorRow.indentLevel(atDepth: depth)) * CGFloat(FileSelectorRow.indentPerLevel)
    }
}
