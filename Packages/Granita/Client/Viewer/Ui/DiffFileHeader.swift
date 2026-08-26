import SwiftUI

import CoreDiffDomain

/// The line that answers "where am I" after thirty seconds of scrolling.
///
/// Design §4 makes it sticky and argues the case: reading the path off the nearest hunk band is not
/// an answer, because hunk bands carry function names and function names repeat.
///
/// **One form rather than §4's two, and the reason is the rule the whole screen is built on.** The
/// review draws two lines in flow — path, then status, stats, language and hunk count — collapsing
/// to a single 28pt line once pinned. A section header in a `LazyVStack(pinnedViews:)` keeps its
/// slot in the layout while a copy floats at the top, so a header that is shorter when pinned is a
/// slot that changes height *above the viewport* — and everything below it, the reader's own
/// content included, moves. That is precisely the reflow `SPEC.md` §10 exists to forbid.
///
/// So this is the pinned form, always. What it costs is the second line, which §4 itself calls
/// "orientation for arriving, not for staying" — and arriving is what §3's file selector is for.
/// **It is provisional**: whether a two-form header can be made to keep one slot height is a
/// question about a real scroll under a real thumb, and it goes with the rest of §4's device
/// questions. See `.claude/docs/decisions.md`.
///
/// **No collapse chevron and no viewed toggle.** Both are controls in §4 and neither has anything
/// behind it yet — collapse state and the viewed write are the model's, and the model is not built.
/// A control that looks operable and does nothing is the worst thing this product can ship.
public struct DiffFileHeader: View {

    private let file: FileChange

    public init(file: FileChange) {
        self.file = file
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            statusLetter
            path
            Spacer(minLength: 8)
            if file.status == .conflicted {
                badge
            }
            stats
        }
        .font(.footnote)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Opaque rather than a material: this floats over code while the code scrolls under it, and
        // anything translucent turns the line the reader is orienting by into a blur of the line
        // they have already read.
        .background(.background)
        .overlay(alignment: .bottom) { Divider() }
    }

    /// Design §3's palette, and its argument holds here for the same reason: **modified gets no
    /// colour at all.** Four rows in five are modified, and colouring the default case spends the
    /// palette on the field that carries no information.
    private var statusLetter: some View {
        Text(verbatim: letter)
            .font(.footnote.monospaced().weight(.semibold))
            .foregroundStyle(colour)
            .accessibilityLabel(spelledOut)
    }

    /// Head-truncated, which is §3's rule derived from what the string is: a path's tail is the
    /// filename, and the filename is what identifies it.
    private var path: some View {
        Text(verbatim: file.path)
            .lineLimit(1)
            .truncationMode(.head)
    }

    /// The one status worth a badge, so the reader knows before they scroll into it.
    private var badge: some View {
        Text("CONFLICTED")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.orange)
    }

    private var stats: some View {
        Text("\(added) \(removed)")
            .monospacedDigit()
    }

    private var added: Text {
        Text("+\(file.stats.insertions, format: .number)").foregroundColor(.green)
    }

    private var removed: Text {
        Text("−\(file.stats.deletions, format: .number)").foregroundColor(.red)
    }

    private var letter: String {
        switch file.status {
        case .added: "A"
        case .modified: "M"
        case .deleted: "D"
        case .renamed: "R"
        case .typeChanged: "T"
        case .untracked: "U"
        case .conflicted: "C"
        }
    }

    /// Green for both of the two statuses that mean "this is new code", because to a reader of
    /// uncommitted work the difference between added and untracked is git bookkeeping — and the
    /// accessibility label below is where the distinction survives.
    private var colour: Color {
        switch file.status {
        case .added, .untracked: .green
        case .deleted: .red
        // Not green. A rename adds no code, and reading it as an addition is the mistake this
        // letter exists to prevent.
        case .renamed: .indigo
        case .conflicted: .orange
        case .modified, .typeChanged: .secondary
        }
    }

    private var spelledOut: String {
        switch file.status {
        case .added: "Added"
        case .modified: "Modified"
        case .deleted: "Deleted"
        case .renamed: "Renamed"
        case .typeChanged: "Type changed"
        case .untracked: "Untracked"
        case .conflicted: "Conflicted"
        }
    }
}
