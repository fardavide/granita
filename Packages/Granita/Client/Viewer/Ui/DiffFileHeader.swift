import SwiftUI

import ClientViewerDomain
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

    /// The review's rule 3 and rule 5 together: 46pt stated rather than grown out of its contents,
    /// because a pinned section header whose height depends on what is in it changes the height of a
    /// slot above the viewport, and everything below it — the reader's own content included — moves.
    /// That is the reflow `SPEC.md` §10 forbids. Two lines fit inside it; the conflicted badge and
    /// the stats do not add a third.
    public static let height: CGFloat = 46

    /// The slot the chevron sits in, and it is a slot rather than a glyph on purpose.
    ///
    /// **`chevron.down` and `chevron.right` do not measure the same**, so a header and the bar that
    /// replaces it when the file shuts put their status bars, their filenames and their paths in two
    /// different columns — about 4pt apart, which is enough to see down a change set and impossible
    /// to attribute to anything. Stating the width makes the two rows one column, and it is also
    /// what the bar's chevron-less rows reserve so their names line up with everything else.
    ///
    /// Wide enough for the larger of the two at `.caption2`, which is the size both draw at.
    public static let chevronWidth: CGFloat = 12

    /// **One spacing for the whole row, which is the other half of the same alignment.** The bar
    /// spaces its row at 8 throughout; a header that spaced its own at 0 and made up the difference
    /// inside a nested stack put its stats and its toggle 8pt off the bar's.
    static let rowSpacing: CGFloat = 8

    /// After the 44pt slot, which is the four points design §4's frame draws there. Small, and it is
    /// the difference between a row that ends and a row that runs out of the screen.
    static let rowTrailingInset: CGFloat = 4

    public var body: some View {
        HStack(spacing: Self.rowSpacing) {
            // **The dim covers what the row says and not what it does.** Rule 5 drops a reviewed
            // file to 45%, and a toggle dropped with it is the control for undoing that state made
            // hardest to see and hardest to hit exactly when the reader wants it.
            Group {
                shutControl
                Spacer(minLength: 8)
                // Spaced rather than butted: the badge is a word and the stats are numbers, and with
                // no gap between them the baseline read `CONFLICTED+4 −2` as one token — which the
                // row's own spacing now gives them.
                if file.status == .conflicted {
                    badge
                }
                stats
            }
            .opacity(file.isViewed ? Self.viewedOpacity : 1)
            viewedToggle
        }
        .font(.footnote)
        .padding(.leading, 12)
        .padding(.trailing, Self.rowTrailingInset)
        .frame(maxWidth: .infinity, minHeight: Self.height, maxHeight: Self.height, alignment: .leading)
        // Opaque rather than a material: this floats over code while the code scrolls under it, and
        // anything translucent turns the line the reader is orienting by into a blur of the line
        // they have already read. The card's own colour rather than the window's, so a pinned header
        // is the same surface as the file under it — see `Color.diffCard`.
        .background(Color.diffCard)
        .overlay(alignment: .bottom) { Divider() }
    }

    /// **Reviewed means quiet**, which is rule 5's second half. On an eleven-file pass the question
    /// the reader asks repeatedly is "where was I", and a trail of dimmed rows answers it — the
    /// unreviewed files become the loud ones without anything having to be added to them.
    static let viewedOpacity: Double = 0.45

    /// The chevron, the status letter and the path in one control, because §4 requires that tapping
    /// a header carrying a chevron shuts the file — a glyph the size of a chevron in a 28pt strip is
    /// not a tap target a thumb finds, and one that misses is a control that did nothing.
    ///
    /// The path is head-truncated, which is §3's rule derived from what the string is: a path's tail
    /// is the filename, and the filename is what identifies it.
    private var shutControl: some View {
        Button { onSetOpen(false, file.id) } label: {
            HStack(spacing: Self.rowSpacing) {
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: Self.chevronWidth)
                FileStatusBar(status: file.status)
                VStack(alignment: .leading, spacing: 1) {
                    // **Never truncated.** It is the shortest of the two strings and the one that
                    // identifies the file; giving it a line of its own is what lets the directory
                    // below truncate somewhere useful.
                    Text(verbatim: DiffFilePath.name(of: file.path))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if directory.isEmpty == false {
                        // **Truncated in the middle, which is this string's own answer rather than
                        // §3's.** Head-truncation deletes the module, and the module is what tells
                        // eleven files apart when three of them live in a folder called `Models`.
                        // Both ends of a directory carry information; only a path's tail does.
                        Text(verbatim: directory)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: file.path))
        .accessibilityHint("Collapses this file")
    }

    private var directory: String {
        DiffFilePath.directory(of: file.path)
    }

    /// The one status worth a badge, so the reader knows before they scroll into it.
    private var badge: some View {
        Text("CONFLICTED")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.orange)
    }

    /// Kept at its own width, with the path below the name giving way instead — the bar this header
    /// swaps with carries the argument, and the two have to agree or the counts step sideways when a
    /// file shuts.
    private var stats: some View {
        changeStatsText(file.stats)
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(1)
    }

    /// **Tapped, never inferred**, which is design §4's call and the one it argues hardest for: this
    /// app has exactly one job, and an inferred mark is it lying about that job.
    ///
    /// A filled circle rather than a check on its own, so that the unset state is a *control* the
    /// reader can see rather than an empty slot — the selector's row uses the bare check because
    /// there it reports rather than acts.
    /// **44pt square, which is the review's eighth fault answered.** It was a 21pt ring hard against
    /// the right bezel — well under the minimum, and identical on every row — on the one control a
    /// reader presses once per file.
    ///
    /// Green when set rather than the accent colour: it agrees with the `+` in the gutter and with
    /// the added-line tint, and it says *done* in the same hue the whole screen uses for *new*.
    private var viewedToggle: some View {
        Button { onSetViewed(file.isViewed == false, file.id) } label: {
            Image(systemName: file.isViewed ? "checkmark.circle.fill" : "circle")
                .font(.body)
                .foregroundStyle(file.isViewed ? AnyShapeStyle(Color.green) : AnyShapeStyle(.tertiary))
                .frame(width: Self.height, height: Self.height)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(file.isViewed ? "Viewed" : "Not viewed")
        .accessibilityHint("Marks this file as read")
    }
}
