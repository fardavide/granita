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
/// **Both controls design §4 puts on this line are here now.** The chevron shuts the file, which is
/// what `SPEC.md` §10 means by a file marked viewed rendering collapsed, and the circle writes the
/// mark. §4 is explicit that tapping a header *with a chevron on it* must collapse the file, so the
/// glyph is the control rather than a decoration beside one — pressing the header anywhere along its
/// leading run shuts the file.
///
/// **The toggle is the only writer of the mark, which is the product's one job.** §4 refuses to
/// infer it: an inferred "viewed" that fires on a fast flick is the app lying about the only thing
/// it is for.
public struct DiffFileHeader: View {

    private let file: FileChange
    private let onSetOpen: (Bool, FileID) -> Void
    private let onSetViewed: (Bool, FileID) -> Void

    /// **Both report which file they are about**, rather than being handed closures that already
    /// know. The header has the file; a caller re-attaching its identifier is a wrapper per header
    /// per frame, and one more place for the wrong identifier to be attached.
    public init(
        file: FileChange,
        onSetOpen: @escaping (Bool, FileID) -> Void,
        onSetViewed: @escaping (Bool, FileID) -> Void
    ) {
        self.file = file
        self.onSetOpen = onSetOpen
        self.onSetViewed = onSetViewed
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            shutControl
            Spacer(minLength: 8)
            if file.status == .conflicted {
                badge
            }
            stats
            viewedToggle
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

    /// The chevron, the status letter and the path in one control, because §4 requires that tapping
    /// a header carrying a chevron shuts the file — a glyph the size of a chevron in a 28pt strip is
    /// not a tap target a thumb finds, and one that misses is a control that did nothing.
    ///
    /// The path is head-truncated, which is §3's rule derived from what the string is: a path's tail
    /// is the filename, and the filename is what identifies it.
    private var shutControl: some View {
        Button { onSetOpen(false, file.id) } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                FileStatusLetter(status: file.status)
                Text(verbatim: file.path)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: file.path))
        .accessibilityHint("Collapses this file")
    }

    /// The one status worth a badge, so the reader knows before they scroll into it.
    private var badge: some View {
        Text("CONFLICTED")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.orange)
    }

    private var stats: some View {
        changeStatsText(file.stats)
            .monospacedDigit()
    }

    /// **Tapped, never inferred**, which is design §4's call and the one it argues hardest for: this
    /// app has exactly one job, and an inferred mark is it lying about that job.
    ///
    /// A filled circle rather than a check on its own, so that the unset state is a *control* the
    /// reader can see rather than an empty slot — the selector's row uses the bare check because
    /// there it reports rather than acts.
    private var viewedToggle: some View {
        Button { onSetViewed(file.isViewed == false, file.id) } label: {
            Image(systemName: file.isViewed ? "checkmark.circle.fill" : "circle")
                .font(.footnote)
                .foregroundStyle(file.isViewed ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
                // The header is 28pt and cannot grow without moving every file in the scroll, so
                // the hit area is bought horizontally instead of vertically.
                .padding(.horizontal, 6)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(file.isViewed ? "Viewed" : "Not viewed")
        .accessibilityHint("Marks this file as read")
    }
}
