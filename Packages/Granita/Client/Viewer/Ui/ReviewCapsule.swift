import SwiftUI

/// The way into the review, once there is one.
///
/// **Not in the toolbar, which is design §7.4's call 2 and the reason it is a floating control at
/// all.** The toolbar hides on scroll, and reading is exactly when the count changes — a review
/// button that vanishes while you are reviewing is a bug with a nice animation. `primaryAction` also
/// already holds *12 files*, which is the only place the phone says how big the read is.
///
/// **It appears with the first saved comment and is absent at zero**, which is Davide's "a button
/// will appear" taken literally. Absent rather than disabled: there is nothing to explain, because
/// nothing has been written yet.
///
/// **It shares its position with the instruction bar** and the two can never both be true — one is
/// the state where a run is being picked out, the other the state where comments exist and none is
/// being picked. That is what lets both live in the bottom of the screen without arbitration.
public struct ReviewCapsule: View {

    /// Design §4's figure. This is a target before it is a label.
    public static let height: CGFloat = 44

    private let count: Int
    private let onOpen: () -> Void

    public init(count: Int, onOpen: @escaping () -> Void) {
        self.count = count
        self.onOpen = onOpen
    }

    public var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 6) {
                Text("Review")
                    .font(.subheadline.weight(.medium))
                // **Monospaced, so the word does not move when the count reaches ten.** A label that
                // re-centres itself as you work is a control that looks like it changed.
                Text(count, format: .number)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .frame(minHeight: Self.height)
            // **A word beside the count rather than a glyph and a badge.** A number on its own reads
            // as a status, and a status is not something a reader presses.
            .background(.thinMaterial, in: .capsule)
            .overlay(Capsule().strokeBorder(.separator, lineWidth: 1 / 3))
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(count == 1 ? "Review, 1 comment" : "Review, \(count) comments")
    }
}
