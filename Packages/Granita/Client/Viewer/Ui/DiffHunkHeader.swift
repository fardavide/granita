import SwiftUI

import CoreDiffDomain

/// The band between two hunks, carrying git's own section heading.
///
/// Design §4: that string is the most useful free thing in the whole diff — it is usually the
/// enclosing function — and it is also the reason the band does not read as content. Proportional
/// rather than monospaced, secondary, on `quaternarySystemFill`: everything about it says *this is
/// not code*, which is what lets the eye skip it while scrolling and find it when lost.
///
/// **No expand control yet, and that is the rule rather than an omission.** §4 puts one at the
/// trailing edge in a 44pt hit area, and context expansion is not built — the client owns that
/// state, and the state does not exist. A chevron that discloses nothing is the smallest possible
/// lie, so the control is absent until the thing behind it works.
public struct DiffHunkHeader: View {

    private let hunk: Hunk

    public init(hunk: Hunk) {
        self.hunk = hunk
    }

    public var body: some View {
        HStack(spacing: 0) {
            heading
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary)
    }

    /// **A hunk with no heading still gets its band**, because the band's other job is structural:
    /// it says the diff jumped, and without it two hunks read as one run of lines whose numbers
    /// happen to skip. git omits the heading often — a change at the top of a file has nothing
    /// enclosing it — so this is the ordinary case rather than the odd one, and design §4 draws
    /// only the case where a heading exists.
    @ViewBuilder private var heading: some View {
        if let sectionHeading = hunk.sectionHeading {
            Text(verbatim: sectionHeading)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                // The heading is a fragment of a declaration, so its end is where the arguments are
                // and its start is the keyword. The start is what identifies it.
                .truncationMode(.tail)
        }
    }
}
