import SwiftUI

/// How many comments a file carries, on its header and on the bar that replaces it.
///
/// **It is what the rail cannot cover.** A rail sits beside the rows it is about, so it says nothing
/// about a file whose rows are all off screen — and nothing at all about a file the reader has shut,
/// which draws as a 44pt bar with no rows under it. Design §7.3 gives that case the chip, and the
/// chip then earns its place on the open header too: two comments a screen apart in one file are two
/// rails a reader never sees together.
///
/// **A numeral beside a glyph, which is the second non-colour channel.** The rail carries its meaning
/// in position and length; this carries it in a digit. Neither needs the reader to tell indigo from
/// blue.
public struct CommentCountChip: View {

    private let count: Int

    public init(count: Int) {
        self.count = count
    }

    /// **Absent at zero rather than drawn empty**, which is the same rule the review capsule follows
    /// and the one this project applies to every control: a chip saying nothing is a mark a reader
    /// has to learn to ignore.
    @ViewBuilder public var body: some View {
        if count > 0 {
            HStack(spacing: 2) {
                Image(systemName: "bubble.left.fill")
                // Monospaced so a file going from 9 to 10 does not move the glyph beside it, which is
                // the same reason the capsule's own count is monospaced.
                Text(count, format: .number)
                    .monospacedDigit()
            }
            .font(.caption2)
            .foregroundStyle(Color.diffCommentRail)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(count == 1 ? "1 comment" : "\(count) comments")
        }
    }
}
